// rigfinish: deterministic CPU finishing for Blender-guided structure sprites.
//
//	go run ./tool/rigs finish PAINT.png RIGDIR OUT.png [-max 512] [-erode 1] [-feather 1]
//	    alpha = the rig silhouette (RIGDIR/clay.png alpha), eroded/feathered; colour = the
//	    painted image resized to the rig frame; trimmed to the silhouette, area-downscaled so
//	    the sprite is at most -max px tall (and 2x that wide). Prints a JSON record:
//	    {size, anchor (ground contact in output px), worldWidthM, worldHeightM, sha256}.
//	go run ./tool/rigs sheet OUT.png [-cell 256] [-cols 8] A.png B.png ...
//	    contact sheet on a light checkerboard, row-major in argument order.
//
// Go (not Python) per the forge tooling rule; standard library only.
package main

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"flag"
	"fmt"
	"image"

	"image/png"
	"math"
	"os"
)

type rgbaf struct {
	w, h int
	p    []float64
} // premultiplied RGBA, 0..1

func load(path string) image.Image {
	f, err := os.Open(path)
	must(err)
	defer f.Close()
	im, err := png.Decode(f)
	must(err)
	return im
}

func must(err error) {
	if err != nil {
		fmt.Fprintln(os.Stderr, "rigfinish:", err)
		os.Exit(1)
	}
}

func toF(im image.Image) *rgbaf {
	b := im.Bounds()
	o := &rgbaf{b.Dx(), b.Dy(), make([]float64, 4*b.Dx()*b.Dy())}
	for y := 0; y < o.h; y++ {
		for x := 0; x < o.w; x++ {
			r, g, bb, a := im.At(b.Min.X+x, b.Min.Y+y).RGBA() // premultiplied 16-bit
			i := 4 * (y*o.w + x)
			o.p[i], o.p[i+1], o.p[i+2], o.p[i+3] = float64(r)/65535, float64(g)/65535, float64(bb)/65535, float64(a)/65535
		}
	}
	return o
}

// resample: separable area (box-coverage) filter for downscaling, bilinear-ish for upscaling.
func resample(s *rgbaf, w, h int) *rgbaf {
	tmp := &rgbaf{w, s.h, make([]float64, 4*w*s.h)}
	axis(s.p, tmp.p, s.w, w, s.h, func(x, y, c int) int { return 4*(y*s.w+x) + c }, func(x, y, c int) int { return 4*(y*w+x) + c })
	o := &rgbaf{w, h, make([]float64, 4*w*h)}
	axis(tmp.p, o.p, s.h, h, w, func(y, x, c int) int { return 4*(y*w+x) + c }, func(y, x, c int) int { return 4*(y*w+x) + c })
	return o
}

func axis(src, dst []float64, n, m, other int, si, di func(int, int, int) int) {
	scale := float64(n) / float64(m)
	for j := 0; j < m; j++ {
		lo, hi := float64(j)*scale, float64(j+1)*scale
		if scale < 1 { // upscale: tent around the source position
			c := (float64(j)+0.5)*scale - 0.5
			lo, hi = c, c+1
		}
		for k := 0; k < other; k++ {
			var acc [4]float64
			wsum := 0.0
			if scale < 1 {
				i0 := int(math.Floor(lo))
				t := lo - float64(i0)
				for d, wt := range []float64{1 - t, t} {
					i := clamp(i0+d, 0, n-1)
					for c := 0; c < 4; c++ {
						acc[c] += wt * src[si(i, k, c)]
					}
					wsum += wt
				}
			} else {
				for i := int(lo); i < int(math.Ceil(hi)) && i < n; i++ {
					wt := math.Min(hi, float64(i+1)) - math.Max(lo, float64(i))
					if wt <= 0 {
						continue
					}
					for c := 0; c < 4; c++ {
						acc[c] += wt * src[si(i, k, c)]
					}
					wsum += wt
				}
			}
			for c := 0; c < 4; c++ {
				dst[di(j, k, c)] = acc[c] / wsum
			}
		}
	}
}

func clamp(v, lo, hi int) int {
	if v < lo {
		return lo
	}
	if v > hi {
		return hi
	}
	return v
}

func alphaOf(s *rgbaf) []float64 {
	a := make([]float64, s.w*s.h)
	for i := range a {
		a[i] = s.p[4*i+3]
	}
	return a
}

func morph(a []float64, w, h, r int, erode bool) []float64 {
	o := make([]float64, len(a))
	for y := 0; y < h; y++ {
		for x := 0; x < w; x++ {
			v := a[y*w+x]
			for dy := -r; dy <= r; dy++ {
				for dx := -r; dx <= r; dx++ {
					q := a[clamp(y+dy, 0, h-1)*w+clamp(x+dx, 0, w-1)]
					if erode && q < v || !erode && q > v {
						v = q
					}
				}
			}
			o[y*w+x] = v
		}
	}
	return o
}

func blur(a []float64, w, h, r int) []float64 {
	o := make([]float64, len(a))
	for y := 0; y < h; y++ {
		for x := 0; x < w; x++ {
			s, n := 0.0, 0.0
			for dy := -r; dy <= r; dy++ {
				for dx := -r; dx <= r; dx++ {
					s += a[clamp(y+dy, 0, h-1)*w+clamp(x+dx, 0, w-1)]
					n++
				}
			}
			o[y*w+x] = s / n
		}
	}
	return o
}

func save(path string, s *rgbaf) string {
	im := image.NewNRGBA(image.Rect(0, 0, s.w, s.h))
	for i := 0; i < s.w*s.h; i++ {
		a := s.p[4*i+3]
		if a <= 1.0/512 {
			continue
		}
		for c := 0; c < 3; c++ {
			im.Pix[4*i+c] = uint8(math.Round(math.Min(1, s.p[4*i+c]/a) * 255))
		}
		im.Pix[4*i+3] = uint8(math.Round(a * 255))
	}
	f, err := os.Create(path)
	must(err)
	enc := png.Encoder{CompressionLevel: png.BestCompression}
	must(enc.Encode(f, im))
	must(f.Close())
	b, err := os.ReadFile(path)
	must(err)
	sum := sha256.Sum256(b)
	return hex.EncodeToString(sum[:])
}

type rig struct {
	Size   [2]int     `json:"size"`
	MPP    float64    `json:"metres_per_px"`
	Anchor [2]float64 `json:"anchor_px"`
}

func finish(args []string) {
	fs := flag.NewFlagSet("finish", flag.ExitOnError)
	maxH := fs.Int("max", 512, "max output longest side px")
	erode := fs.Int("erode", 1, "silhouette erosion px at render size (hides background bleed)")
	feather := fs.Int("feather", 1, "edge feather px at render size")
	must(fs.Parse(args))
	if fs.NArg() != 3 {
		must(fmt.Errorf("finish PAINT.png RIGDIR OUT.png"))
	}
	rec := finishCore(fs.Arg(0), fs.Arg(1), fs.Arg(2), *maxH, *erode, *feather)
	j, _ := json.Marshal(rec)
	fmt.Println(string(j))
}

// finishCore: rig silhouette alpha + painted colour -> trimmed, downscaled sprite. Returns the record.
func finishCore(paint, dir, out string, maxH, erode, feather int) map[string]any {
	var r rig
	b, err := os.ReadFile(dir + "/rig.json")
	must(err)
	must(json.Unmarshal(b, &r))
	clay := toF(load(dir + "/clay.png"))
	W, H := clay.w, clay.h
	col := toF(load(paint))
	if col.w != W || col.h != H {
		col = resample(col, W, H)
	}
	a := alphaOf(clay)
	if erode > 0 {
		a = morph(a, W, H, erode, true)
	}
	if feather > 0 {
		a = blur(a, W, H, feather)
	}
	// trim box
	x0, y0, x1, y1 := W, H, -1, -1
	for y := 0; y < H; y++ {
		for x := 0; x < W; x++ {
			if a[y*W+x] > 0.01 {
				x0, y0 = min(x0, x), min(y0, y)
				x1, y1 = max(x1, x), max(y1, y)
			}
		}
	}
	if x1 < 0 {
		must(fmt.Errorf("empty silhouette"))
	}
	// keep the anchor (ground contact) inside the trimmed frame
	ay := int(math.Ceil(r.Anchor[1]))
	if ay > y1 && ay < H {
		y1 = ay
	}
	x0, y0, x1, y1 = max(0, x0-2), max(0, y0-2), min(W-1, x1+2), min(H-1, y1+2)
	cw, ch := x1-x0+1, y1-y0+1
	crop := &rgbaf{cw, ch, make([]float64, 4*cw*ch)}
	for y := 0; y < ch; y++ {
		for x := 0; x < cw; x++ {
			si, di := (y+y0)*W+x+x0, 4*(y*cw+x)
			al := a[si]
			oa := col.p[4*si+3]
			if oa <= 0 {
				oa = 1
			}
			for c := 0; c < 3; c++ {
				crop.p[di+c] = col.p[4*si+c] / oa * al
			}
			crop.p[di+3] = al
		}
	}
	s := math.Min(1, math.Min(float64(maxH)/float64(ch), float64(maxH)/float64(cw)))
	ow, oh := max(1, int(math.Round(float64(cw)*s))), max(1, int(math.Round(float64(ch)*s)))
	res := crop
	if ow != cw || oh != ch {
		res = resample(crop, ow, oh)
	}
	sx, sy := float64(ow)/float64(cw), float64(oh)/float64(ch)
	sum := save(out, res)
	rec := map[string]any{
		"size":         []int{ow, oh},
		"anchor":       []float64{math.Round((r.Anchor[0]-float64(x0))*sx*10) / 10, math.Round((r.Anchor[1]-float64(y0))*sy*10) / 10},
		"worldWidthM":  math.Round(float64(cw)*r.MPP*100) / 100,
		"worldHeightM": math.Round(float64(ch)*r.MPP*100) / 100,
		"sha256":       sum,
	}
	return rec
}

func sheet(args []string) {
	fs := flag.NewFlagSet("sheet", flag.ExitOnError)
	cell := fs.Int("cell", 256, "cell px")
	cols := fs.Int("cols", 8, "columns")
	must(fs.Parse(args))
	out, files := fs.Arg(0), fs.Args()[1:]
	rows := (len(files) + *cols - 1) / *cols
	W, H := *cols**cell, rows**cell
	bg := &rgbaf{W, H, make([]float64, 4*W*H)}
	for y := 0; y < H; y++ {
		for x := 0; x < W; x++ {
			v := 0.86
			if (x/16+y/16)%2 == 0 {
				v = 0.94
			}
			i := 4 * (y*W + x)
			bg.p[i], bg.p[i+1], bg.p[i+2], bg.p[i+3] = v, v, v*1.02, 1
		}
	}
	for n, f := range files {
		im := toF(load(f))
		s := math.Min(float64(*cell-8)/float64(im.w), float64(*cell-8)/float64(im.h))
		w, h := max(1, int(float64(im.w)*s)), max(1, int(float64(im.h)*s))
		im = resample(im, w, h)
		ox, oy := (n%*cols)**cell+(*cell-w)/2, (n / *cols)**cell+(*cell-h)-4
		for y := 0; y < h; y++ {
			for x := 0; x < w; x++ {
				si, di := 4*(y*w+x), 4*((oy+y)*W+ox+x)
				a := im.p[si+3]
				for c := 0; c < 3; c++ {
					bg.p[di+c] = im.p[si+c] + bg.p[di+c]*(1-a)
				}
			}
		}
	}
	fmt.Println(save(out, bg))

}

func main() {
	if len(os.Args) < 2 {
		must(fmt.Errorf("usage: rigfinish finish|sheet ..."))
	}
	switch os.Args[1] {
	case "finish":
		finish(os.Args[2:])
	case "sheet":
		sheet(os.Args[2:])
	case "plan":
		plan(os.Args[2:])
	case "ingest":
		ingest(os.Args[2:])
	case "batch":
		batch(os.Args[2:])
	case "collect-batch":
		collectBatch(os.Args[2:])
	case "pack-sheet":
		packSheet(os.Args[2:])
	default:
		must(fmt.Errorf("unknown verb %q", os.Args[1]))
	}
}
