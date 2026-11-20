package main

import (
	"encoding/json"
	"fmt"
	"image"
	"math"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

const atlasSize = 2048
const pad = 2

// targetHeight is the atlas height for a sprite by band and kind; a pick is
// never upscaled. Override per item with heightPx.
func targetHeight(it *Item) (h, maxW int) {
	if it.HeightPx > 0 {
		h = it.HeightPx
	} else {
		switch it.Band {
		case "near":
			h = 160
			if it.Kind == "furniture" || it.Kind == "sign" || it.Kind == "structure" {
				h = 192
			}
		case "mid":
			switch it.Kind {
			case "tree":
				h = 320
			case "structure":
				h = 288
			case "animal":
				h = 128
			case "shrub", "grass", "crop":
				h = 192
			default:
				h = 256
			}
		case "far":
			h = 192
			if it.Kind == "animal" {
				h = 96
			}
		case "vista":
			h = 320
		}
	}
	maxW = 1024
	if it.Band == "vista" {
		maxW = 2048
	}
	return
}

type Sprite struct {
	ID            string   `json:"id"`
	Atlas         string   `json:"atlas"`
	Rect          [4]int   `json:"rect"`
	Anchor        [2]int   `json:"anchor"`
	WorldWidthM   float64  `json:"worldWidthM"`
	Band          string   `json:"band"`
	Kind          string   `json:"kind"`
	Biomes        []string `json:"biomes"`
	Tags          []string `json:"tags"`
	Frames        []string `json:"frames"`
	Sway          float64  `json:"sway"`
	Collides      bool     `json:"collides"`
	NightEmissive any      `json:"nightEmissive"`
}

type AtlasRec struct {
	ID     string `json:"id"`
	File   string `json:"file"`
	Width  int    `json:"width"`
	Height int    `json:"height"`
}

type TextureRec struct {
	ID    string    `json:"id"`
	File  string    `json:"file"`
	Kind  string    `json:"kind"`
	TileM []float64 `json:"tileM"`
}

type Manifest struct {
	Version  string       `json:"version"`
	Atlases  []AtlasRec   `json:"atlases"`
	Sprites  []Sprite     `json:"sprites"`
	Textures []TextureRec `json:"textures"`
}

type packed struct {
	fam  *Family
	it   *Item
	img  *fimg
	ax   int
	ay   int
	x, y int
	page int
}

// prepareSprite: band downscale, alpha/edge clean, optional posterize, trim,
// anchor = centre of the lowest opaque rows (bottom edge of the lowest row).
func prepareSprite(f *Family, it *Item, src *image.NRGBA) (*fimg, int, int) {
	s := toF(src)
	srcW := s.w
	th, maxW := targetHeight(it)
	if s.h > th {
		w := int(math.Max(1, math.Round(float64(s.w)*float64(th)/float64(s.h))))
		s = resizeArea(s, w, th)
	}
	s = fitWithin(s, maxW, atlasSize)
	scale := float64(s.w) / float64(srcW)
	s.cleanAlpha(0.05, 0.96)
	s.posterize(f.ColorLevels)
	x0, y0, x1, y1, ok := s.bbox(0.05)
	if !ok {
		fatalf("%s: empty after finishing", it.ID)
	}
	s = s.crop(x0, y0, x1, y1)
	if len(it.Anchor) == 2 { // supplied anchor in source pixels
		ax := int(math.Round(it.Anchor[0]*scale)) - x0
		ay := int(math.Round(it.Anchor[1]*scale)) - y0
		return s, min(max(ax, 0), s.w), min(max(ay, 0), s.h)
	}
	ay := -1
	for y := s.h - 1; y >= 0 && ay < 0; y-- {
		for x := 0; x < s.w; x++ {
			if s.p[(y*s.w+x)*4+3] >= 0.5 {
				ay = y
				break
			}
		}
	}
	if ay < 0 {
		ay = s.h - 1
	}
	band := max(1, s.h/40)
	minx, maxx := s.w, -1
	for y := max(0, ay-band+1); y <= ay; y++ {
		for x := 0; x < s.w; x++ {
			if s.p[(y*s.w+x)*4+3] >= 0.5 {
				minx = min(minx, x)
				maxx = max(maxx, x)
			}
		}
	}
	ax := s.w / 2
	if maxx >= 0 {
		ax = (minx + maxx + 1) / 2
	}
	if it.AnchorX != nil {
		ax = int(math.Round(*it.AnchorX * float64(s.w)))
	}
	return s, ax, ay + 1
}

func cmdPack(root string, args []string) {
	fs := flags("pack", args)
	_ = fs
	fams := mustFamilies(root)
	outDir := filepath.Join(root, "assets/scenic")
	groups := map[string][]*packed{}
	man := Manifest{Version: "scenic-1", Atlases: []AtlasRec{}, Sprites: []Sprite{}, Textures: []TextureRec{}}
	written := map[string]bool{}
	missing := 0
	for _, f := range fams {
		for i := range f.Items {
			it := &f.Items[i]
			src := sourcePath(root, f, it)
			if _, err := os.Stat(src); err != nil {
				missing++
				continue
			}
			if f.Type == "texture" {
				size := it.SizePx
				if size == 0 {
					size = 256
				}
				t := toF(loadPNG(src))
				t = resizeArea(t, size, size)
				t.posterize(f.ColorLevels)
				n := t.toN()
				for i := 3; i < len(n.Pix); i += 4 {
					n.Pix[i] = 255
				}
				rel := "road/" + it.ID + ".png"
				savePNG(filepath.Join(outDir, rel), n)
				written[rel] = true
				man.Textures = append(man.Textures, TextureRec{it.ID, rel, it.Kind, it.TileM})
				continue
			}
			img, ax, ay := prepareSprite(f, it, loadPNG(src))
			g := f.Atlas
			if g == "" {
				g = f.Family
			}
			groups[g] = append(groups[g], &packed{fam: f, it: it, img: img, ax: ax, ay: ay})
		}
	}
	for _, g := range sortedKeys(groups) {
		ps := groups[g]
		sort.Slice(ps, func(a, b int) bool {
			if ps[a].img.h != ps[b].img.h {
				return ps[a].img.h > ps[b].img.h
			}
			return ps[a].it.ID < ps[b].it.ID
		})
		// shelf pack into pages
		page, x, y, shelf := 0, 0, 0, 0
		var heights []int
		for _, p := range ps {
			w, h := p.img.w+pad, p.img.h+pad
			if x+w > atlasSize {
				x, y, shelf = 0, y+shelf, 0
			}
			if y+h > atlasSize {
				heights = append(heights, y)
				page, x, y, shelf = page+1, 0, 0, 0
			}
			p.x, p.y, p.page = x, y, page
			x += w
			shelf = max(shelf, h)
		}
		heights = append(heights, y+shelf)
		for pg := 0; pg <= page; pg++ {
			hh := (heights[pg] + 15) / 16 * 16
			ww := 0
			for _, p := range ps {
				if p.page == pg {
					ww = max(ww, p.x+p.img.w+pad)
				}
			}
			ww = min(atlasSize, (ww+15)/16*16)
			canvas := image.NewNRGBA(image.Rect(0, 0, ww, hh))
			id := fmt.Sprintf("%s-%c", g, 'a'+pg)
			for _, p := range ps {
				if p.page != pg {
					continue
				}
				n := p.img.toN()
				for yy := 0; yy < n.Rect.Dy(); yy++ {
					copy(canvas.Pix[canvas.PixOffset(p.x, p.y+yy):canvas.PixOffset(p.x+n.Rect.Dx(), p.y+yy)], n.Pix[n.PixOffset(0, yy):n.PixOffset(n.Rect.Dx(), yy)])
				}
				frames := p.it.Frames
				if len(frames) == 0 {
					frames = []string{p.it.ID}
				}
				biomes := append([]string{}, p.it.Biomes...)
				man.Sprites = append(man.Sprites, Sprite{ID: p.it.ID, Atlas: id, Rect: [4]int{p.x, p.y, p.img.w, p.img.h},
					Anchor: [2]int{p.ax, p.ay}, WorldWidthM: p.it.WorldWidthM, Band: p.it.Band, Kind: p.it.Kind,
					Biomes: biomes, Tags: append([]string{}, p.it.Tags...), Frames: frames, Sway: p.it.Sway, Collides: p.it.Collides, NightEmissive: p.it.NightEmissive})
			}
			file := id + ".png"
			savePNG(filepath.Join(outDir, file), canvas)
			written[file] = true
			man.Atlases = append(man.Atlases, AtlasRec{id, file, ww, hh})
		}
	}
	present := map[string]bool{}
	for _, sp := range man.Sprites {
		present[sp.ID] = true
	}
	for i := range man.Sprites { // frames whose pick is missing are dropped
		var fr []string
		for _, f := range man.Sprites[i].Frames {
			if present[f] {
				fr = append(fr, f)
			}
		}
		man.Sprites[i].Frames = fr
	}
	sort.Slice(man.Sprites, func(a, b int) bool { return man.Sprites[a].ID < man.Sprites[b].ID })
	sort.Slice(man.Textures, func(a, b int) bool { return man.Textures[a].ID < man.Textures[b].ID })
	writeManifest(filepath.Join(outDir, "manifest.json"), man)
	// remove stale outputs
	for _, pat := range []string{"*.png", "road/*.png"} {
		ms, _ := filepath.Glob(filepath.Join(outDir, pat))
		for _, m := range ms {
			rel, _ := filepath.Rel(outDir, m)
			if !written[filepath.ToSlash(rel)] {
				os.Remove(m)
				fmt.Printf("removed stale %s\n", rel)
			}
		}
	}
	var total int64
	for k := range written {
		if st, err := os.Stat(filepath.Join(outDir, k)); err == nil {
			total += st.Size()
		}
	}
	fmt.Printf("packed %d sprites in %d atlases, %d textures; %.2f MB; %d items without picks\n",
		len(man.Sprites), len(man.Atlases), len(man.Textures), float64(total)/1e6, missing)
	if !strings.Contains(strings.Join(args, " "), "--no-contact") {
		cmdContact(root, nil)
	}
}

// writeManifest writes one array entry per line so diffs stay readable.
func writeManifest(path string, m Manifest) {
	var b strings.Builder
	b.WriteString("{\n  \"version\": " + mustJSON(m.Version) + ",\n")
	section := func(name string, n int, at func(int) any, last bool) {
		b.WriteString("  \"" + name + "\": [")
		for i := 0; i < n; i++ {
			if i == 0 {
				b.WriteString("\n")
			}
			b.WriteString("    " + mustJSON(at(i)))
			if i < n-1 {
				b.WriteString(",")
			}
			b.WriteString("\n")
		}
		if n > 0 {
			b.WriteString("  ")
		}
		b.WriteString("]")
		if !last {
			b.WriteString(",")
		}
		b.WriteString("\n")
	}
	section("atlases", len(m.Atlases), func(i int) any { return m.Atlases[i] }, false)
	section("sprites", len(m.Sprites), func(i int) any { return m.Sprites[i] }, false)
	section("textures", len(m.Textures), func(i int) any { return m.Textures[i] }, true)
	b.WriteString("}\n")
	if err := os.WriteFile(path, []byte(b.String()), 0o644); err != nil {
		fatalf("write %s: %v", path, err)
	}
}

func mustJSON(v any) string {
	bs, err := json.Marshal(v)
	if err != nil {
		fatalf("json: %v", err)
	}
	return string(bs)
}
