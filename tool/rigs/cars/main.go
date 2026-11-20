// carpack: deterministic CPU assembly of Blender car renders into the game's atlases.
//
//	go run ./cars assemble RENDERS REPO
//
// RENDERS is car_rig.py's output (one dir per car with rig.json). REPO is the checkout root.
// Writes, under REPO:
//
//	assets/cars/<id>-body.png   player sheet: flat, left, right, uphill, downhill, right-skid
//	assets/cars/<id>-turn.png   player turn sheet: gentle/medium/strong x left/right
//	assets/cars/traffic-atlas.png  8 columns of 256 px cells; cell = model*4 + paint
//	assets/cars/keycard.png     garage key-card prop
//	assets/cars/manifest.json   anchors, lamps, cells, provenance (rig params, seeds, sha256)
//	art/contact/cars.png        contact sheet of everything above
//
// Scale contract (same as the hand-painted S2000 atlas): in a 512 px player cell the flat
// pose is `cell.width` px wide (mirrors included), tyres touch y = groundY, centred on x 256.
// Every other pose of that car uses the SAME transform, so pose changes never rescale the car.
// Traffic cells are the player cell at half size (the renderer draws them with anchorScale .5).
//
// Go (not Python) per the forge tooling rule; standard library only.
package main

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"image"
	"image/color"
	"image/png"
	"math"
	"os"
	"path/filepath"
	"sort"
	"time"
)

type pose struct {
	Name  string  `json:"name"`
	Yaw   float64 `json:"yaw"`
	Steer float64 `json:"steer"`
	Roll  float64 `json:"roll"`
	Pitch float64 `json:"pitch"`
}

type posesFile struct {
	Camera map[string]any     `json:"camera"`
	Cell   map[string]float64 `json:"cell"`
	Sheets map[string][]pose  `json:"sheets"`
}

type carSpec struct {
	ID        string   `json:"id"`
	Reference string   `json:"reference"`
	Use       []string `json:"use"`
	Sporty    bool     `json:"sporty"`
	Large     bool     `json:"large"`
	Paints    []string `json:"paints"`
}

type renderRec struct {
	Sheet      string      `json:"sheet"`
	Index      int         `json:"index"`
	Paint      string      `json:"paint"`
	PaintIndex int         `json:"paintIndex"`
	File       string      `json:"file"`
	Lamps      [][]float64 `json:"lamps"`
}

type rigRec struct {
	ID      string         `json:"id"`
	Params  map[string]any `json:"params"`
	Camera  map[string]any `json:"camera"`
	Render  map[string]any `json:"render"`
	Renders []renderRec    `json:"renders"`
}

type rgbaf struct {
	w, h int
	p    []float64 // premultiplied RGBA 0..1
}

func must(err error) {
	if err != nil {
		fmt.Fprintln(os.Stderr, "carpack:", err)
		os.Exit(1)
	}
}

func load(path string) *rgbaf {
	f, err := os.Open(path)
	must(err)
	defer f.Close()
	im, err := png.Decode(f)
	must(err)
	b := im.Bounds()
	out := &rgbaf{b.Dx(), b.Dy(), make([]float64, b.Dx()*b.Dy()*4)}
	for y := 0; y < b.Dy(); y++ {
		for x := 0; x < b.Dx(); x++ {
			r, g, bb, a := im.At(b.Min.X+x, b.Min.Y+y).RGBA() // already premultiplied
			i := (y*out.w + x) * 4
			out.p[i], out.p[i+1], out.p[i+2], out.p[i+3] = float64(r)/65535, float64(g)/65535, float64(bb)/65535, float64(a)/65535
		}
	}
	return out
}

func (im *rgbaf) at(x, y float64) [4]float64 { // bilinear, transparent outside
	x -= .5
	y -= .5
	x0, y0 := int(math.Floor(x)), int(math.Floor(y))
	fx, fy := x-float64(x0), y-float64(y0)
	var out [4]float64
	for _, c := range [][3]float64{{0, 0, (1 - fx) * (1 - fy)}, {1, 0, fx * (1 - fy)}, {0, 1, (1 - fx) * fy}, {1, 1, fx * fy}} {
		xi, yi := x0+int(c[0]), y0+int(c[1])
		if xi < 0 || yi < 0 || xi >= im.w || yi >= im.h || c[2] == 0 {
			continue
		}
		i := (yi*im.w + xi) * 4
		for k := 0; k < 4; k++ {
			out[k] += im.p[i+k] * c[2]
		}
	}
	return out
}

// bbox of alpha >= thr: left, right, bottom (inclusive pixel indices), top.
func bbox(im *rgbaf, thr float64) (l, r, t, b int) {
	l, r, t, b = im.w, -1, im.h, -1
	for y := 0; y < im.h; y++ {
		for x := 0; x < im.w; x++ {
			if im.p[(y*im.w+x)*4+3] >= thr {
				l, r = min(l, x), max(r, x)
				t, b = min(t, y), max(b, y)
			}
		}
	}
	return
}

// xform maps source px to destination px: d = (s - origin)*scale + target.
type xform struct{ ox, oy, s, tx, ty float64 }

// blit resamples src through xf into dst at cell offset (cx, cy) with a box-filtered
// supersample (n x n bilinear taps per destination pixel), clipped to the cell.
func blit(dst *rgbaf, src *rgbaf, xf xform, cx, cy, cell, cellH int) (clipped bool) {
	n := int(math.Ceil(1/xf.s)) + 1
	for y := 0; y < cellH; y++ {
		for x := 0; x < cell; x++ {
			var acc [4]float64
			for j := 0; j < n; j++ {
				for i := 0; i < n; i++ {
					dx := float64(x) + (float64(i)+.5)/float64(n)
					dy := float64(y) + (float64(j)+.5)/float64(n)
					c := src.at((dx-xf.tx)/xf.s+xf.ox, (dy-xf.ty)/xf.s+xf.oy)
					for k := range acc {
						acc[k] += c[k]
					}
				}
			}
			k := ((cy+y)*dst.w + cx + x) * 4
			for c := 0; c < 4; c++ {
				dst.p[k+c] = acc[c] / float64(n*n)
			}
			if (x == 0 || y == 0 || x == cell-1 || y == cellH-1) && dst.p[k+3] > .02 {
				clipped = true
			}
		}
	}
	return
}

func save(im *rgbaf, path string) string {
	out := image.NewNRGBA(image.Rect(0, 0, im.w, im.h))
	for i := 0; i < im.w*im.h; i++ {
		a := im.p[i*4+3]
		px := color.NRGBA{}
		if a > 1e-6 {
			q := func(v float64) uint8 { return uint8(math.Round(math.Min(1, math.Max(0, v/a)) * 255)) }
			px = color.NRGBA{q(im.p[i*4]), q(im.p[i*4+1]), q(im.p[i*4+2]), uint8(math.Round(math.Min(1, a) * 255))}
		}
		out.Pix[i*4], out.Pix[i*4+1], out.Pix[i*4+2], out.Pix[i*4+3] = px.R, px.G, px.B, px.A
	}
	must(os.MkdirAll(filepath.Dir(path), 0o755))
	f, err := os.Create(path)
	must(err)
	enc := png.Encoder{CompressionLevel: png.BestCompression}
	must(enc.Encode(f, out))
	must(f.Close())
	return fileSha(path)
}

func fileSha(path string) string {
	b, err := os.ReadFile(path)
	must(err)
	h := sha256.Sum256(b)
	return hex.EncodeToString(h[:])
}

func readJSON(path string, v any) {
	b, err := os.ReadFile(path)
	must(err)
	must(json.Unmarshal(b, v))
}

// anchors measured exactly like ProofArt._measureAnchors (alpha >= 100/255).
func anchors(atlas *rgbaf, cell, cols, cells int) (ground, centre []float64) {
	for c := 0; c < cells; c++ {
		ox, oy := (c%cols)*cell, (c/cols)*cell
		l, r, b := cell, 0, 0
		for y := 0; y < cell; y++ {
			for x := 0; x < cell; x++ {
				if atlas.p[((oy+y)*atlas.w+ox+x)*4+3]*255 < 100 {
					continue
				}
				l, r, b = min(l, x), max(r, x), max(b, y)
			}
		}
		ground = append(ground, float64(b))
		centre = append(centre, float64(l+r)/2)
	}
	return
}

func round3(v float64) float64 { return math.Round(v*1000) / 1000 }

// lamp offsets in the renderer's units: fraction of the sprite basis width (450 px per
// player cell; 225 per traffic cell), x from the centre line, y above the ground line.
func lampFractions(lamps [][]float64, xf xform, centre, ground, basis float64) map[string]float64 {
	var sx, sy, n float64
	for _, l := range lamps {
		x := (l[0]-xf.ox)*xf.s + xf.tx
		y := (l[1]-xf.oy)*xf.s + xf.ty
		if math.Abs(x-centre) < basis*.08 { // centre bars are not the paired brake lamps
			continue
		}
		sx += math.Abs(x - centre)
		sy += ground - y
		n++
	}
	if n == 0 {
		return map[string]float64{"x": .29, "y": .39}
	}
	return map[string]float64{"x": round3(sx / n / basis), "y": round3(sy / n / basis)}
}

func main() {
	if len(os.Args) != 4 || os.Args[1] != "assemble" {
		fmt.Fprintln(os.Stderr, "usage: carpack assemble RENDERS REPO")
		os.Exit(2)
	}
	renders, repo := os.Args[2], os.Args[3]
	var P posesFile
	readJSON(filepath.Join(repo, "art/rigs/cars/poses.json"), &P)
	var C struct {
		Cars []carSpec `json:"cars"`
	}
	readJSON(filepath.Join(repo, "art/rigs/cars/cars.json"), &C)
	outDir := filepath.Join(repo, "assets/cars")
	cell := int(P.Cell["player"])
	groundY, width := P.Cell["groundY"], P.Cell["width"]
	tcell := int(P.Cell["traffic"])

	manifest := map[string]any{
		"version":   "cars-1",
		"generated": time.Now().UTC().Format("2006-01-02"),
		"status":    "stylised Blender cel renders (no AI paint); see art/rigs/cars/README.md",
		"contract": map[string]any{
			"playerCell": cell, "trafficCell": tcell, "groundY": groundY, "flatWidth": width,
			"basis": "renderer scale = drawWidth / 450 per player cell (225 per traffic cell)",
			"poses": P.Sheets,
		},
	}
	files := map[string]any{}
	players := map[string]any{}
	var traffic []map[string]any
	var sheetCells []*rgbaf
	model := 0
	type tcellRec struct {
		img *rgbaf
		xf  xform
		rec renderRec
		car carSpec
		m   int
	}
	var tcells []tcellRec
	provenance := map[string]any{}
	for _, car := range C.Cars {
		var rig rigRec
		readJSON(filepath.Join(renders, car.ID, "rig.json"), &rig)
		provenance[car.ID] = map[string]any{"params": rig.Params, "render": rig.Render, "camera": rig.Camera}
		bySheet := map[string][]renderRec{}
		for _, r := range rig.Renders {
			bySheet[r.Sheet] = append(bySheet[r.Sheet], r)
		}
		has := func(u string) bool {
			for _, x := range car.Use {
				if x == u {
					return true
				}
			}
			return false
		}
		if has("player") {
			flat := load(filepath.Join(renders, car.ID, bySheet["body"][0].File))
			l, r, _, b := bbox(flat, .5)
			xf := xform{float64(l+r+1) / 2, float64(b + 1), width / float64(r-l+1), float64(cell) / 2, groundY}
			entry := map[string]any{}
			for _, sheet := range []string{"body", "turn"} {
				atlas := &rgbaf{cell * 3, cell * 2, make([]float64, cell*cell*6*4)}
				for i, rec := range bySheet[sheet] {
					src := load(filepath.Join(renders, car.ID, rec.File))
					// same scale and ground line for every pose; each pose is centred on its
					// own silhouette (the renderer re-measures centre anchors per frame)
					pl, pr, _, _ := bbox(src, .5)
					pxf := xf
					pxf.ox = float64(pl+pr+1) / 2
					if blit(atlas, src, pxf, (i%3)*cell, (i/3)*cell, cell, cell) {
						fmt.Fprintf(os.Stderr, "warning: %s %s cell %d touches the cell border\n", car.ID, sheet, i)
					}
				}
				name := fmt.Sprintf("%s-%s.png", car.ID, sheet)
				sha := save(atlas, filepath.Join(outDir, name))
				g, c := anchors(atlas, cell, 3, 6)
				files[name] = map[string]any{"width": atlas.w, "height": atlas.h, "columns": 3, "rows": 2, "sha256": sha}
				entry[sheet] = map[string]any{"file": "assets/cars/" + name, "measuredGroundY": g, "measuredCenterX": c}
				sheetCells = append(sheetCells, atlas)
			}
			entry["lamps"] = lampFractions(bySheet["body"][0].Lamps, xf, float64(cell)/2, groundY, 450)
			players[car.ID] = entry
		}
		if has("traffic") {
			recs := bySheet["traffic"]
			sort.Slice(recs, func(i, j int) bool { return recs[i].PaintIndex < recs[j].PaintIndex })
			first := load(filepath.Join(renders, car.ID, recs[0].File))
			l, r, _, b := bbox(first, .5)
			xf := xform{float64(l+r+1) / 2, float64(b + 1), width / 2 / float64(r-l+1), float64(tcell) / 2, groundY / 2}
			for i, rec := range recs {
				img := first
				if i > 0 {
					img = load(filepath.Join(renders, car.ID, rec.File))
				}
				tcells = append(tcells, tcellRec{img, xf, rec, car, model})
			}
			model++
		}
	}
	// traffic atlas: 8 columns, cell = model*4 + paint (4 paints per model)
	cols := 8
	rows := (model*4 + cols - 1) / cols
	tatlas := &rgbaf{cols * tcell, rows * tcell, make([]float64, cols*tcell*rows*tcell*4)}
	for _, t := range tcells {
		idx := t.m*4 + t.rec.PaintIndex
		if blit(tatlas, t.img, t.xf, (idx%cols)*tcell, (idx/cols)*tcell, tcell, tcell) {
			fmt.Fprintf(os.Stderr, "warning: traffic %s paint %d touches the cell border\n", t.car.ID, t.rec.PaintIndex)
		}
		traffic = append(traffic, map[string]any{
			"cell": idx, "model": t.car.ID, "paint": t.rec.Paint, "paintIndex": t.rec.PaintIndex,
			"sporty": t.car.Sporty, "large": t.car.Large,
			"lamps": lampFractions(t.rec.Lamps, t.xf, float64(tcell)/2, groundY/2, 225),
		})
	}
	sha := save(tatlas, filepath.Join(outDir, "traffic-atlas.png"))
	g, c := anchors(tatlas, tcell, cols, model*4)
	files["traffic-atlas.png"] = map[string]any{"width": tatlas.w, "height": tatlas.h, "columns": cols, "rows": rows, "cellWidth": tcell, "sha256": sha,
		"measuredGroundY": g, "measuredCenterX": c}
	// key card prop: trimmed to its alpha, kept at 256 px tall
	kc := load(filepath.Join(renders, "props/keycard.png"))
	l, r, t, b := bbox(kc, .02)
	s := 240.0 / float64(b-t+1)
	kw := int(math.Ceil(float64(r-l+1)*s)) + 16
	katlas := &rgbaf{kw, 256, make([]float64, kw*256*4)}
	blit(katlas, kc, xform{float64(l+r+1) / 2, float64(t), s, float64(kw) / 2, 8}, 0, 0, kw, 256)
	files["keycard.png"] = map[string]any{"width": kw, "height": 256, "sha256": save(katlas, filepath.Join(outDir, "keycard.png")),
		"hangPoint": []float64{.5, .07}}

	manifest["players"] = players
	manifest["traffic"] = traffic
	manifest["files"] = files
	src := map[string]string{}
	for _, f := range []string{"art/rigs/cars/car_rig.py", "art/rigs/cars/cars.json", "art/rigs/cars/poses.json", "tool/rigs/cars/main.go"} {
		src[f] = fileSha(filepath.Join(repo, f))
	}
	manifest["provenance"] = map[string]any{
		"sources":  src,
		"pipeline": "lua art/rigs/cars/run.lua all: bpy car_rig.py (Cycles CPU, emission cel materials, seed 0) -> carpack assemble",
		"paint":    "none: Qwen-Image-Edit hero paint + projection was evaluated as optional; shipped pixels are the rig's own cel shading",
		"seeds":    map[string]int{"cycles": 0},
		"cars":     provenance,
	}
	b2, err := json.MarshalIndent(manifest, "", " ")
	must(err)
	must(os.WriteFile(filepath.Join(outDir, "manifest.json"), append(b2, '\n'), 0o644))

	// contact sheet: player sheets (halved) then the traffic atlas, on a light checkerboard
	cw := 1536 / 2
	h := len(sheetCells)/2*512 + tatlas.h*3/4 + 8
	sheet := &rgbaf{cw * 2, h, make([]float64, cw*2*h*4)}
	for y := 0; y < h; y++ {
		for x := 0; x < cw*2; x++ {
			v := .86
			if (x/16+y/16)%2 == 0 {
				v = .93
			}
			i := (y*sheet.w + x) * 4
			sheet.p[i], sheet.p[i+1], sheet.p[i+2], sheet.p[i+3] = v, v, v, 1
		}
	}
	over := func(src *rgbaf, ox, oy int, sc float64) {
		for y := 0; y < int(float64(src.h)*sc); y++ {
			for x := 0; x < int(float64(src.w)*sc); x++ {
				var acc [4]float64
				for j := 0; j < 2; j++ {
					for i := 0; i < 2; i++ {
						c := src.at((float64(x)+(float64(i)+.5)/2)/sc, (float64(y)+(float64(j)+.5)/2)/sc)
						for k := range acc {
							acc[k] += c[k] / 4
						}
					}
				}
				d := ((oy+y)*sheet.w + ox + x) * 4
				if ox+x >= sheet.w || oy+y >= sheet.h {
					continue
				}
				for k := 0; k < 3; k++ {
					sheet.p[d+k] = acc[k] + sheet.p[d+k]*(1-acc[3])
				}
			}
		}
	}
	for i, a := range sheetCells {
		over(a, (i%2)*cw, (i/2)*512, .5)
	}
	over(tatlas, 0, len(sheetCells)/2*512+8, .75)
	save(sheet, filepath.Join(repo, "art/contact/cars.png"))
	fmt.Printf("carpack: %d player sheets, %d traffic cells, manifest written\n", len(sheetCells), len(tcells))
}
