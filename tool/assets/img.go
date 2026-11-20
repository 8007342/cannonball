package main

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"image"
	"image/draw"
	"image/png"
	"io"
	"math"
	"os"
	"path/filepath"
)

// fimg is a premultiplied float RGBA image (0..1).
type fimg struct {
	w, h int
	p    []float64 // r,g,b,a premultiplied
}

func newF(w, h int) *fimg { return &fimg{w, h, make([]float64, w*h*4)} }

func loadPNG(path string) *image.NRGBA {
	f, err := os.Open(path)
	if err != nil {
		fatalf("open %s: %v", path, err)
	}
	defer f.Close()
	im, err := png.Decode(f)
	if err != nil {
		fatalf("decode %s: %v", path, err)
	}
	n := image.NewNRGBA(im.Bounds().Sub(im.Bounds().Min))
	draw.Draw(n, n.Bounds(), im, im.Bounds().Min, draw.Src)
	return n
}

func encodePNG(im image.Image) []byte {
	var buf bytes.Buffer
	enc := png.Encoder{CompressionLevel: png.BestCompression}
	if err := enc.Encode(&buf, im); err != nil {
		fatalf("png: %v", err)
	}
	return buf.Bytes()
}

func savePNG(path string, im image.Image) string {
	b := encodePNG(im)
	os.MkdirAll(filepath.Dir(path), 0o755)
	if err := os.WriteFile(path, b, 0o644); err != nil {
		fatalf("write %s: %v", path, err)
	}
	return shaBytes(b)
}

func shaBytes(b []byte) string { s := sha256.Sum256(b); return hex.EncodeToString(s[:]) }

func shaFile(path string) string {
	f, err := os.Open(path)
	if err != nil {
		return ""
	}
	defer f.Close()
	h := sha256.New()
	io.Copy(h, f)
	return hex.EncodeToString(h.Sum(nil))
}

func copyFile(src, dst string) {
	b, err := os.ReadFile(src)
	if err != nil {
		fatalf("read %s: %v", src, err)
	}
	os.MkdirAll(filepath.Dir(dst), 0o755)
	if err := os.WriteFile(dst, b, 0o644); err != nil {
		fatalf("write %s: %v", dst, err)
	}
}

func toF(n *image.NRGBA) *fimg {
	f := newF(n.Rect.Dx(), n.Rect.Dy())
	for y := 0; y < f.h; y++ {
		for x := 0; x < f.w; x++ {
			o := n.PixOffset(x, y)
			a := float64(n.Pix[o+3]) / 255
			i := (y*f.w + x) * 4
			f.p[i] = float64(n.Pix[o]) / 255 * a
			f.p[i+1] = float64(n.Pix[o+1]) / 255 * a
			f.p[i+2] = float64(n.Pix[o+2]) / 255 * a
			f.p[i+3] = a
		}
	}
	return f
}

func q8(v float64) uint8 {
	v = math.Round(v * 255)
	if v < 0 {
		return 0
	}
	if v > 255 {
		return 255
	}
	return uint8(v)
}

func (f *fimg) toN() *image.NRGBA {
	n := image.NewNRGBA(image.Rect(0, 0, f.w, f.h))
	for i := 0; i < f.w*f.h; i++ {
		a := f.p[i*4+3]
		o := i * 4
		if a <= 0 {
			continue
		}
		n.Pix[o] = q8(f.p[i*4] / a)
		n.Pix[o+1] = q8(f.p[i*4+1] / a)
		n.Pix[o+2] = q8(f.p[i*4+2] / a)
		n.Pix[o+3] = q8(a)
	}
	return n
}

// resizeArea box-filters (exact area coverage) to w x h in premultiplied space.
func resizeArea(src *fimg, w, h int) *fimg {
	if w == src.w && h == src.h {
		c := newF(w, h)
		copy(c.p, src.p)
		return c
	}
	tmp := newF(w, src.h)
	sx := float64(src.w) / float64(w)
	for x := 0; x < w; x++ {
		x0, x1 := float64(x)*sx, float64(x+1)*sx
		for y := 0; y < src.h; y++ {
			var acc [4]float64
			for k := int(x0); k < int(math.Ceil(x1)) && k < src.w; k++ {
				cov := math.Min(x1, float64(k+1)) - math.Max(x0, float64(k))
				if cov <= 0 {
					continue
				}
				i := (y*src.w + k) * 4
				for c := 0; c < 4; c++ {
					acc[c] += src.p[i+c] * cov
				}
			}
			o := (y*w + x) * 4
			for c := 0; c < 4; c++ {
				tmp.p[o+c] = acc[c] / sx
			}
		}
	}
	out := newF(w, h)
	sy := float64(src.h) / float64(h)
	for y := 0; y < h; y++ {
		y0, y1 := float64(y)*sy, float64(y+1)*sy
		for x := 0; x < w; x++ {
			var acc [4]float64
			for k := int(y0); k < int(math.Ceil(y1)) && k < src.h; k++ {
				cov := math.Min(y1, float64(k+1)) - math.Max(y0, float64(k))
				if cov <= 0 {
					continue
				}
				i := (k*w + x) * 4
				for c := 0; c < 4; c++ {
					acc[c] += tmp.p[i+c] * cov
				}
			}
			o := (y*w + x) * 4
			for c := 0; c < 4; c++ {
				out.p[o+c] = acc[c] / sy
			}
		}
	}
	return out
}

// fitWithin scales down (never up) so w<=maxW and h<=maxH.
func fitWithin(src *fimg, maxW, maxH int) *fimg {
	s := math.Min(float64(maxW)/float64(src.w), float64(maxH)/float64(src.h))
	if s >= 1 {
		return src
	}
	w := int(math.Max(1, math.Round(float64(src.w)*s)))
	h := int(math.Max(1, math.Round(float64(src.h)*s)))
	return resizeArea(src, w, h)
}

// bbox of pixels with alpha >= thr.
func (f *fimg) bbox(thr float64) (x0, y0, x1, y1 int, ok bool) {
	x0, y0, x1, y1 = f.w, f.h, -1, -1
	for y := 0; y < f.h; y++ {
		for x := 0; x < f.w; x++ {
			if f.p[(y*f.w+x)*4+3] >= thr {
				if x < x0 {
					x0 = x
				}
				if x > x1 {
					x1 = x
				}
				if y < y0 {
					y0 = y
				}
				if y > y1 {
					y1 = y
				}
			}
		}
	}
	return x0, y0, x1 + 1, y1 + 1, x1 >= 0
}

func (f *fimg) crop(x0, y0, x1, y1 int) *fimg {
	o := newF(x1-x0, y1-y0)
	for y := y0; y < y1; y++ {
		copy(o.p[((y-y0)*o.w)*4:((y-y0)*o.w+o.w)*4], f.p[(y*f.w+x0)*4:(y*f.w+x1)*4])
	}
	return o
}

// cutout applies a matte to an RGB render over a flat key colour and removes
// the key colour from partially transparent edge pixels.
func cutout(rgb, matte *image.NRGBA, key [3]float64, defringe bool) *fimg {
	w, h := rgb.Rect.Dx(), rgb.Rect.Dy()
	f := newF(w, h)
	mw, mh := matte.Rect.Dx(), matte.Rect.Dy()
	for y := 0; y < h; y++ {
		for x := 0; x < w; x++ {
			mo := matte.PixOffset(x*mw/w, y*mh/h)
			a := float64(matte.Pix[mo]) / 255
			if a < 0.03 {
				continue
			}
			o := rgb.PixOffset(x, y)
			i := (y*w + x) * 4
			for c := 0; c < 3; c++ {
				v := float64(rgb.Pix[o+c])
				if defringe && a < 0.98 {
					v = (v - (1-a)*key[c]) / a
				}
				f.p[i+c] = math.Max(0, math.Min(255, v)) / 255 * a
			}
			f.p[i+3] = a
		}
	}
	return f
}

// cleanAlpha snaps near-empty and near-solid alpha so edges stay soft but
// atlases do not carry invisible noise.
// vistaFeather is the fraction of a vista's width faded out at each side.
const vistaFeather = 0.14

// farFootFeather / farSideFeather: fraction of a far sprite's height faded
// at the bottom, and of its width faded at the lower corners.
const farFootFeather, farSideFeather = 0.10, 0.10

// featherFoot fades the bottom rows (frac of the height) to transparent and
// the left/right edges (side of the width) progressively from mid-height
// down, so a painted ground slab has no hard bottom corners while the
// upper subject keeps its silhouette.
func (f *fimg) featherFoot(frac, side float64) {
	ramp := func(d float64) float64 {
		if d >= 1 {
			return 1
		}
		if d <= 0 {
			return 0
		}
		return d * d * (3 - 2*d)
	}
	foot := frac * float64(f.h)
	sideW := side * float64(f.w)
	for y := 0; y < f.h; y++ {
		fromBottom := float64(f.h-y) - 0.5
		b := 1.0
		if foot >= 1 {
			b = ramp(fromBottom / foot)
		}
		// 0 above mid-height, 1 at the bottom row.
		w := ramp((float64(y)+0.5)/float64(f.h)*2 - 1)
		for x := 0; x < f.w; x++ {
			k := b
			if sideW >= 1 && w > 0 {
				d := math.Min(float64(x)+0.5, float64(f.w-x)-0.5) / sideW
				k *= 1 - (1-ramp(d))*w
			}
			if k >= 1 {
				continue
			}
			i := (y*f.w + x) * 4
			for c := 0; c < 4; c++ {
				f.p[i+c] *= k
			}
		}
	}
}

// featherX fades premultiplied pixels to transparent over frac of the width
// at the left and right edges (smoothstep ramp).
func (f *fimg) featherX(frac float64) {
	ramp := frac * float64(f.w)
	if ramp < 1 {
		return
	}
	for x := 0; x < f.w; x++ {
		d := math.Min(float64(x)+0.5, float64(f.w-x)-0.5) / ramp
		if d >= 1 {
			continue
		}
		k := d * d * (3 - 2*d)
		for y := 0; y < f.h; y++ {
			i := (y*f.w + x) * 4
			for c := 0; c < 4; c++ {
				f.p[i+c] *= k
			}
		}
	}
}

func (f *fimg) cleanAlpha(lo, hi float64) {
	for i := 0; i < f.w*f.h; i++ {
		a := f.p[i*4+3]
		switch {
		case a < lo:
			f.p[i*4], f.p[i*4+1], f.p[i*4+2], f.p[i*4+3] = 0, 0, 0, 0
		case a > hi:
			s := 1 / a
			for c := 0; c < 4; c++ {
				f.p[i*4+c] *= s
			}
		}
	}
}

// posterize quantizes straight colour to n levels per channel.
func (f *fimg) posterize(n int) {
	if n < 2 {
		return
	}
	l := float64(n - 1)
	for i := 0; i < f.w*f.h; i++ {
		a := f.p[i*4+3]
		if a <= 0 {
			continue
		}
		for c := 0; c < 3; c++ {
			v := f.p[i*4+c] / a
			f.p[i*4+c] = math.Round(v*l) / l * a
		}
	}
}

// crossfadeX makes a strip tile horizontally: the last `ov` columns are
// blended into the first `ov` and then dropped.
func crossfadeX(f *fimg, ov int) *fimg {
	if ov <= 0 || ov*2 >= f.w {
		return f
	}
	w := f.w - ov
	o := newF(w, f.h)
	for y := 0; y < f.h; y++ {
		for x := 0; x < w; x++ {
			i := (y*w + x) * 4
			s := (y*f.w + x) * 4
			if x < ov {
				t := (float64(x) + 0.5) / float64(ov) // 0 -> tail, 1 -> head
				e := (y*f.w + w + x) * 4
				for c := 0; c < 4; c++ {
					o.p[i+c] = f.p[s+c]*t + f.p[e+c]*(1-t)
				}
			} else {
				copy(o.p[i:i+4], f.p[s:s+4])
			}
		}
	}
	return o
}

// tileSeamError: mean abs difference across the wrap edges vs interior (0..1).
func tileSeamError(f *fimg) (edge, interior float64) {
	n := 0
	for y := 0; y < f.h; y++ {
		a := (y*f.w + f.w - 1) * 4
		b := (y * f.w) * 4
		m := (y*f.w + f.w/2) * 4
		for c := 0; c < 3; c++ {
			edge += math.Abs(f.p[a+c] - f.p[b+c])
			interior += math.Abs(f.p[m+c] - f.p[m-4+c])
		}
		n += 3
	}
	return edge / float64(n), interior / float64(n)
}

// wrapSmooth blends a band of b pixels at opposite edges toward each other so
// the wrap is exactly continuous (safety net after the in-graph seam repaint).
func wrapSmooth(f *fimg, b int) {
	px := func(x, y int) []float64 { i := (y*f.w + x) * 4; return f.p[i : i+4] }
	for y := 0; y < f.h; y++ {
		for k := 0; k < b; k++ {
			t := 0.5 * (1 - float64(k)/float64(b))
			l, r := px(k, y), px(f.w-1-k, y)
			for c := 0; c < 4; c++ {
				lv, rv := l[c], r[c]
				l[c], r[c] = lv*(1-t)+rv*t, rv*(1-t)+lv*t
			}
		}
	}
	for x := 0; x < f.w; x++ {
		for k := 0; k < b; k++ {
			t := 0.5 * (1 - float64(k)/float64(b))
			u, d := px(x, k), px(x, f.h-1-k)
			for c := 0; c < 4; c++ {
				uv, dv := u[c], d[c]
				u[c], d[c] = uv*(1-t)+dv*t, dv*(1-t)+uv*t
			}
		}
	}
}

// skylineCut keys a horizon strip painted over a flat key colour: in each
// column everything below the first run of 3 non-key pixels is land (opaque);
// the boundary pixel gets alpha from its distance to the key, so the ridge
// edge stays soft. Pale land inside the silhouette is never keyed out.
func skylineCut(rgb *image.NRGBA, key [3]float64) *fimg {
	w, h := rgb.Rect.Dx(), rgb.Rect.Dy()
	f := newF(w, h)
	dist := func(x, y int) float64 {
		o := rgb.PixOffset(x, y)
		d := 0.0
		for c := 0; c < 3; c++ {
			d += math.Abs(float64(rgb.Pix[o+c]) - key[c])
		}
		return d
	}
	const thr = 36.0
	for x := 0; x < w; x++ {
		top := h
		for y := 0; y+2 < h; y++ {
			if dist(x, y) > thr && dist(x, y+1) > thr && dist(x, y+2) > thr {
				top = y
				break
			}
		}
		for y := max(0, top-2); y < h; y++ {
			a := 1.0
			if y < top+1 {
				a = math.Min(1, dist(x, y)/120)
			}
			if a <= 0 {
				continue
			}
			o := rgb.PixOffset(x, y)
			i := (y*w + x) * 4
			for c := 0; c < 3; c++ {
				v := float64(rgb.Pix[o+c])
				if a < 0.98 {
					v = (v - (1-a)*key[c]) / a
				}
				f.p[i+c] = math.Max(0, math.Min(255, v)) / 255 * a
			}
			f.p[i+3] = a
		}
	}
	return f
}

// blendTile makes an untiled render seamless: roll it by half in x and y (so
// its own seams sit on the centre lines and its edges wrap continuously), then
// cross-fade a band of width b around those centre lines back to the unrolled
// image, which is clean there. Only the band can ghost; edges always wrap.
func blendTile(src *fimg, b int) *fimg {
	w, h := src.w, src.h
	o := newF(w, h)
	for y := 0; y < h; y++ {
		for x := 0; x < w; x++ {
			dx := math.Abs(float64(x) + 0.5 - float64(w)/2)
			dy := math.Abs(float64(y) + 0.5 - float64(h)/2)
			wx := math.Max(0, 1-dx/float64(b))
			wy := math.Max(0, 1-dy/float64(b))
			t := math.Max(wx, wy)
			t = t * t * (3 - 2*t) // smoothstep
			ri := (((y+h/2)%h)*w + (x+w/2)%w) * 4
			ui := (y*w + x) * 4
			for c := 0; c < 4; c++ {
				o.p[ui+c] = src.p[ri+c]*(1-t) + src.p[ui+c]*t
			}
		}
	}
	return o
}
