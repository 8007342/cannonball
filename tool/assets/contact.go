package main

import (
	"fmt"
	"image"
	"os"
	"path/filepath"
)

type sheetCell struct {
	img   *image.NRGBA
	label string
	first bool
}

// layoutSheet draws cells on a light/dark checker so soft alpha edges show;
// textures are tiled 2x2 inside the cell to expose seams.
func layoutSheet(cells []sheetCell, cols, cell int, tile bool) *image.NRGBA {
	rows := (len(cells) + cols - 1) / cols
	lab := 14
	W, H := cols*cell, rows*(cell+lab)
	out := image.NewNRGBA(image.Rect(0, 0, max(W, 1), max(H, 1)))
	for y := 0; y < H; y++ {
		for x := 0; x < W; x++ {
			v := uint8(196)
			if ((x/12)+(y/12))%2 == 0 {
				v = 150
			}
			o := out.PixOffset(x, y)
			out.Pix[o], out.Pix[o+1], out.Pix[o+2], out.Pix[o+3] = v, v+8, v, 255
		}
	}
	for i, c := range cells {
		cx, cy := (i%cols)*cell, (i/cols)*(cell+lab)
		for y := cy + cell; y < cy+cell+lab; y++ {
			for x := cx; x < cx+cell; x++ {
				o := out.PixOffset(x, y)
				out.Pix[o], out.Pix[o+1], out.Pix[o+2] = 32, 32, 40
			}
		}
		if c.img == nil {
			continue
		}
		drawText(out, cx+3, cy+cell+4, c.label, cell-6)
		src := toF(c.img)
		if tile {
			src = tile2(src)
		}
		f := fitWithin(src, cell-8, cell-8).toN()
		ox := cx + (cell-f.Rect.Dx())/2
		oy := cy + cell - 4 - f.Rect.Dy()
		for y := 0; y < f.Rect.Dy(); y++ {
			for x := 0; x < f.Rect.Dx(); x++ {
				so := f.PixOffset(x, y)
				a := float64(f.Pix[so+3]) / 255
				do := out.PixOffset(ox+x, oy+y)
				for k := 0; k < 3; k++ {
					out.Pix[do+k] = uint8(float64(f.Pix[so+k])*a + float64(out.Pix[do+k])*(1-a) + 0.5)
				}
			}
		}
	}
	return out
}

func tile2(f *fimg) *fimg {
	o := newF(f.w*2, f.h*2)
	for y := 0; y < o.h; y++ {
		for x := 0; x < o.w; x++ {
			copy(o.p[(y*o.w+x)*4:(y*o.w+x)*4+4], f.p[((y%f.h)*f.w+x%f.w)*4:((y%f.h)*f.w+x%f.w)*4+4])
		}
	}
	return o
}

// cmdContact writes art/contact/<family>.png: every committed pick of the
// family as packed (band height), labelled with its id.
func cmdContact(root string, args []string) {
	fs := flags("contact", args)
	for _, f := range selectFamilies(mustFamilies(root), fs.pos(0, "all")) {
		var cells []sheetCell
		for i := range f.Items {
			it := &f.Items[i]
			src := sourcePath(root, f, it)
			if _, err := os.Stat(src); err != nil {
				continue
			}
			label := it.ID
			if f.Type == "sprite" {
				label = fmt.Sprintf("%s %s %gm", it.ID, it.Band, it.WorldWidthM)
			}
			cells = append(cells, sheetCell{loadPNG(src), label, false})
		}
		if len(cells) == 0 {
			continue
		}
		cols := 6
		if len(cells) < cols {
			cols = len(cells)
		}
		p := filepath.Join(root, "art/contact", f.Family+".png")
		savePNG(p, layoutSheet(cells, cols, 200, f.Type == "texture"))
		fmt.Printf("contact %s (%d)\n", p, len(cells))
	}
}
