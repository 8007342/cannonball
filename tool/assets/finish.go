package main

import (
	"fmt"
	"math"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
)

func candPath(fam, id string, seed int64) string {
	return filepath.Join(cacheRoot(), "cand", fam, id, fmt.Sprintf("%d.png", seed))
}

// finishSource turns one raw render (+ matte) into a pick-ready source:
// sprites get matte + key de-fringe + trim (+ tileX cross-fade) + downscale to
// sourceMax; textures are box-downscaled to sourceMax.
func finishSource(f *Family, it *Item, r *Run) *fimg {
	rgb := loadPNG(r.Raw)
	if f.Type == "texture" {
		s := toF(rgb)
		m := f.sourceMax(it)
		if !strings.Contains(r.Workflow, "-tile") { // plain render: tile it here
			s = blendTile(s, s.w/6)
		}
		o := resizeArea(s, m, m)
		wrapSmooth(o, m/32)
		return o
	}
	mattePath := strings.TrimSuffix(r.Raw, "-rgb.png") + "-matte.png"
	var s *fimg
	if f.Matte == "skyline" {
		s = skylineCut(rgb, f.key())
	} else if _, err := os.Stat(mattePath); err == nil {
		// LayerDiffuse alpha is native (no key colour behind it): skip de-fringing
		s = cutout(rgb, loadPNG(mattePath), f.key(), !strings.Contains(r.Workflow, "layerdiffuse"))
	} else {
		s = toF(rgb)
	}
	s.cleanAlpha(0.06, 0.97)
	x0, y0, x1, y1, ok := s.bbox(0.06)
	if !ok {
		return nil
	}
	s = s.crop(x0, y0, x1, y1)
	if it.TileX {
		s = crossfadeX(s, s.w/8)
	}
	m := f.sourceMax(it)
	return fitWithin(s, m, m)
}

func cmdFinish(root string, args []string) {
	fs := flags("finish", args)
	only := fs.list("item")
	for _, f := range selectFamilies(mustFamilies(root), fs.pos(0, "all")) {
		led := loadLedger(root, f.Family)
		keys := sortedKeys(led)
		n := 0
		for _, k := range keys {
			r := led[k]
			id := k[:strings.LastIndex(k, "/")]
			if len(only) > 0 && !contains(only, id) {
				continue
			}
			_, it := findItem([]*Family{f}, id)
			if it == nil || r.Raw == "" {
				continue
			}
			if _, err := os.Stat(r.Raw); err != nil {
				continue
			}
			out := candPath(f.Family, id, r.Seed)
			if _, err := os.Stat(out); err == nil && !fs.bool("force") {
				continue
			}
			s := finishSource(f, it, r)
			if s == nil {
				fmt.Fprintf(os.Stderr, "%s: empty matte\n", k)
				continue
			}
			savePNG(out, s.toN())
			if f.Type == "texture" {
				e, in := tileSeamError(s)
				fmt.Printf("%s seam %.3f interior %.3f\n", k, e, in)
			}
			n++
		}
		if n > 0 || fs.bool("sheet") {
			p := candidateSheet(f, led, only)
			fmt.Printf("%s: finished %d candidates; sheet %s\n", f.Family, n, p)
		}
	}
}

func sortedKeys[T any](m map[string]T) []string {
	ks := make([]string, 0, len(m))
	for k := range m {
		ks = append(ks, k)
	}
	sort.Strings(ks)
	return ks
}

// cmdPick records a choice: copies the finished candidate to
// art/sources/<family>/<id>.png and marks it selected with its reason.
func cmdPick(root string, args []string) {
	fs := flags("pick", args)
	id, seedS := fs.pos(0, ""), fs.pos(1, "")
	reason := strings.Join(fs.positional[min(2, len(fs.positional)):], " ")
	if id == "" || seedS == "" || reason == "" {
		fatalf("pick <id> <seed> <reason...>")
	}
	seed, err := strconv.ParseInt(seedS, 10, 64)
	if err != nil {
		fatalf("seed: %v", err)
	}
	f, _ := findItem(mustFamilies(root), id)
	if f == nil {
		fatalf("unknown id %s", id)
	}
	led := loadLedger(root, f.Family)
	key := fmt.Sprintf("%s/%d", id, seed)
	r, ok := led[key]
	if !ok {
		fatalf("no run %s in %s", key, ledgerPath(root, f.Family))
	}
	c := candPath(f.Family, id, seed)
	if _, err := os.Stat(c); err != nil {
		fatalf("not finished: %s (run finish)", c)
	}
	dst := filepath.Join(root, "art/sources", f.Family, id+".png")
	copyFile(c, dst)
	for k, o := range led {
		if strings.HasPrefix(k, id+"/") {
			o.Selected = false
			if k != key {
				o.SourceSHA256 = ""
			}
		}
	}
	r.Selected, r.PickReason, r.SourceSHA256 = true, reason, shaFile(dst)
	r.Source = filepath.ToSlash(filepath.Join("art/sources", f.Family, id+".png"))
	saveLedger(root, f.Family, led)
	fmt.Printf("picked %s -> %s\n", key, dst)
}

// candidateSheet lays every candidate of each item in a row, labelled with
// "<id> <seed>", into the cache (review only; never committed).
func candidateSheet(f *Family, led map[string]*Run, only []string) string {
	type row struct {
		id    string
		seeds []int64
	}
	var rows []row
	for _, it := range f.Items {
		if len(only) > 0 && !contains(only, it.ID) {
			continue
		}
		var ss []int64
		for k, r := range led {
			if strings.HasPrefix(k, it.ID+"/") && !strings.Contains(k[len(it.ID)+1:], "/") {
				if _, err := os.Stat(candPath(f.Family, it.ID, r.Seed)); err == nil {
					ss = append(ss, r.Seed)
				}
			}
		}
		sort.Slice(ss, func(a, b int) bool { return ss[a] < ss[b] })
		if len(ss) > 0 {
			rows = append(rows, row{it.ID, ss})
		}
	}
	cols := 0
	for _, r := range rows {
		cols = max(cols, len(r.seeds))
	}
	var cells []sheetCell
	for _, r := range rows {
		for i, s := range r.seeds {
			cells = append(cells, sheetCell{loadPNG(candPath(f.Family, r.id, s)), fmt.Sprintf("%s %d", r.id, s), i == 0})
		}
		for i := len(r.seeds); i < cols; i++ {
			cells = append(cells, sheetCell{nil, "", false})
		}
	}
	cell := 256
	if f.Type == "texture" {
		cell = 224
	}
	p := filepath.Join(cacheRoot(), "contact", f.Family+"-candidates.png")
	savePNG(p, layoutSheet(cells, max(cols, 1), cell, f.Type == "texture"))
	return p
}

var _ = math.Abs
