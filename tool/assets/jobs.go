package main

import (
	"encoding/json"
	"fmt"
	"image"
	"image/color"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

// Job is one studio.run_workflow / studio.queue_workflow call.
type Job struct {
	ID        string         `json:"id"` // <family>/<item>
	Family    string         `json:"family"`
	Item      string         `json:"item"`
	Args      map[string]any `json:"args"`   // exact studio.queue_workflow arguments
	Status    string         `json:"status"` // pending | done | ingested
	StudioJob string         `json:"studio_job,omitempty"`
}

type wfNode struct {
	Class  string                 `json:"class_type"`
	Meta   struct{ Title string } `json:"_meta"`
	Inputs map[string]any         `json:"inputs"`
}

func loadWorkflow(root, rel string) map[string]wfNode {
	var wf map[string]wfNode
	if err := readJSON(filepath.Join(root, rel), &wf); err != nil {
		fatalf("workflow %s: %v", rel, err)
	}
	return wf
}

func nodeByTitle(wf map[string]wfNode, title string) string {
	for id, n := range wf {
		if n.Meta.Title == title {
			return id
		}
	}
	return ""
}

// saveNodes returns the SaveImage node ids for "rgb" (title "save rgb" or
// "save tile") and "matte" (title "save matte").
func saveNodes(wf map[string]wfNode) (rgb, matte string) {
	for id, n := range wf {
		if n.Class != "SaveImage" {
			continue
		}
		switch n.Meta.Title {
		case "save rgb", "save tile":
			rgb = id
		case "save matte", "save alpha":
			matte = id
		}
	}
	return
}

func wfModels(wf map[string]wfNode) []string {
	var ms []string
	for _, n := range wf {
		for k, v := range n.Inputs {
			if s, ok := v.(string); ok && strings.HasSuffix(s, ".safetensors") && (strings.HasSuffix(k, "_name") || k == "model") {
				ms = append(ms, s)
			}
		}
	}
	sort.Strings(ms)
	return ms
}

func jobsPath(fam string) string { return filepath.Join(cacheRoot(), "jobs", fam+".json") }

func loadJobs(fam string) []*Job {
	var js []*Job
	readJSON(jobsPath(fam), &js)
	return js
}

func inputsDir() string { return filepath.Join(imagegenRoot(), "scenic", "inputs") }

// cmdPlan writes the job list for each family: one job per item still
// lacking a pick (or every item with --all, or the named --item ids).
func cmdPlan(root string, args []string) {
	fs := flags("plan", args)
	famName := fs.pos(0, "all")
	fams := selectFamilies(mustFamilies(root), famName)
	only := fs.list("item")
	for _, f := range fams {
		if f.Workflow == "" {
			continue
		}
		old := map[string]*Job{}
		for _, j := range loadJobs(f.Family) {
			old[j.ID] = j
		}
		var jobs []*Job
		for i := range f.Items {
			it := &f.Items[i]
			if len(only) > 0 && !contains(only, it.ID) {
				if j, ok := old[f.Family+"/"+it.ID]; ok {
					jobs = append(jobs, j) // keep jobs of other items untouched
				}
				continue
			}
			src := sourcePath(root, f, it)
			if _, err := os.Stat(src); err == nil && !fs.bool("all") && len(only) == 0 {
				continue
			}
			id := f.Family + "/" + it.ID
			if j, ok := old[id]; ok && j.Status != "pending" && !fs.bool("redo") {
				jobs = append(jobs, j)
				continue
			}
			j, err := buildJob(root, f, it)
			if err != nil {
				fmt.Fprintf(os.Stderr, "skip %s: %v\n", id, err)
				continue
			}
			jobs = append(jobs, j)
		}
		writeJSON(jobsPath(f.Family), jobs)
		n := 0
		for _, j := range jobs {
			if j.Status == "pending" {
				n++
			}
		}
		fmt.Printf("%s: %d jobs (%d pending) -> %s\n", f.Family, len(jobs), n, jobsPath(f.Family))
	}
}

func buildJob(root string, f *Family, it *Item) (*Job, error) {
	wfRel := f.Workflow
	if it.Derive != nil && it.Derive.Workflow != "" {
		wfRel = it.Derive.Workflow
	}
	wf := loadWorkflow(root, wfRel)
	ov := map[string]any{"prompt": f.prompt(it), "seed": it.seed()}
	if f.Negative != "" && nodeByTitle(wf, "$negative_prompt") != "" {
		ov["negative_prompt"] = f.Negative
	}
	canvas := f.Canvas
	if len(it.Canvas) == 2 {
		canvas = it.Canvas
	}
	if len(canvas) == 2 && it.Derive == nil {
		cid := nodeByTitle(wf, "canvas")
		if cid == "" {
			return nil, fmt.Errorf("workflow %s has no node titled canvas", wfRel)
		}
		ov["$node:"+cid+".width"] = canvas[0]
		ov["$node:"+cid+".height"] = canvas[1]
	}
	args := map[string]any{"workflow": wfRel, "count": f.candidates(), "overrides": ov}
	inputs := map[string]string{}
	for _, n := range wf {
		if n.Class != "LoadImage" {
			continue
		}
		name, _ := n.Inputs["image"].(string)
		switch name {
		case "$mask":
			inputs["mask"] = seamMask(1024, 1024, 96)
		case "$init_image", "$control":
			if it.Derive == nil {
				return nil, fmt.Errorf("workflow needs %s but item has no derive", name)
			}
			p, err := deriveInput(root, f, it)
			if err != nil {
				return nil, err
			}
			inputs[strings.TrimPrefix(name, "$")] = p
		}
	}
	if len(inputs) > 0 {
		args["inputs"] = inputs
	}
	return &Job{ID: f.Family + "/" + it.ID, Family: f.Family, Item: it.ID, Args: args, Status: "pending"}, nil
}

// deriveInput composites the parent's pick onto the family key colour,
// centred on a 1024 canvas, into the imagegen inputs folder.
func deriveInput(root string, f *Family, it *Item) (string, error) {
	pf, pit := findItem(mustFamilies(root), it.Derive.From)
	if pf == nil {
		return "", fmt.Errorf("derive.from %s not found", it.Derive.From)
	}
	src := sourcePath(root, pf, pit)
	if _, err := os.Stat(src); err != nil {
		return "", fmt.Errorf("derive.from %s has no pick yet", it.Derive.From)
	}
	s := loadPNG(src)
	k := f.key()
	W, H := 1024, 1024
	if s.Rect.Dx() > s.Rect.Dy() {
		H = int(1024 * float64(s.Rect.Dy()) / float64(s.Rect.Dx()) * 1.4)
		H = (H + 15) / 16 * 16
		if H > 1024 {
			H = 1024
		}
	}
	canvas := image.NewNRGBA(image.Rect(0, 0, W, H))
	bg := color.NRGBA{uint8(k[0]), uint8(k[1]), uint8(k[2]), 255}
	for i := 0; i < W*H; i++ {
		canvas.Pix[i*4], canvas.Pix[i*4+1], canvas.Pix[i*4+2], canvas.Pix[i*4+3] = bg.R, bg.G, bg.B, 255
	}
	sf := fitWithin(upscaleNearest(toF(s), int(0.8*float64(W)), int(0.8*float64(H))), int(0.8*float64(W)), int(0.8*float64(H)))
	sn := sf.toN()
	ox, oy := (W-sn.Rect.Dx())/2, (H-sn.Rect.Dy())/2
	for y := 0; y < sn.Rect.Dy(); y++ {
		for x := 0; x < sn.Rect.Dx(); x++ {
			so := sn.PixOffset(x, y)
			a := float64(sn.Pix[so+3]) / 255
			do := canvas.PixOffset(ox+x, oy+y)
			for c := 0; c < 3; c++ {
				canvas.Pix[do+c] = uint8(float64(sn.Pix[so+c])*a + float64(canvas.Pix[do+c])*(1-a) + 0.5)
			}
		}
	}
	p := filepath.Join(inputsDir(), it.ID+"-init.png")
	savePNG(p, canvas)
	return p, nil
}

// upscaleNearest enlarges by an integer factor so the box fit can reach the
// target (picks are <=512 px; edit models want ~1 MP).
func upscaleNearest(f *fimg, maxW, maxH int) *fimg {
	k := 1
	for f.w*(k+1) <= maxW && f.h*(k+1) <= maxH {
		k++
	}
	if k == 1 {
		return f
	}
	o := newF(f.w*k, f.h*k)
	for y := 0; y < o.h; y++ {
		for x := 0; x < o.w; x++ {
			copy(o.p[(y*o.w+x)*4:(y*o.w+x)*4+4], f.p[((y/k)*f.w+x/k)*4:((y/k)*f.w+x/k)*4+4])
		}
	}
	return o
}

// seamMask: white cross (repaint) over the centre seams of a half-rolled tile.
func seamMask(w, h, band int) string {
	p := filepath.Join(inputsDir(), fmt.Sprintf("seam-cross-%dx%d-%d.png", w, h, band))
	if _, err := os.Stat(p); err == nil {
		return p
	}
	m := image.NewGray(image.Rect(0, 0, w, h))
	for y := 0; y < h; y++ {
		for x := 0; x < w; x++ {
			dx := abs(x - w/2)
			dy := abs(y - h/2)
			d := dx
			if dy < d {
				d = dy
			}
			v := 0.0
			if d < band/2 {
				v = 1
			} else if d < band {
				v = 1 - float64(d-band/2)/float64(band/2)
			}
			m.Pix[y*w+x] = uint8(v*255 + 0.5)
		}
	}
	savePNG(p, m)
	return p
}

func abs(x int) int {
	if x < 0 {
		return -x
	}
	return x
}

// cmdRun is the serial, resumable dispatcher. GPU work goes through the host's
// studio queue (studio.queue_workflow / studio.run_workflow, an MCP tool), so
// `run --next` prints the next pending call and `run --done` records it.
func cmdRun(root string, args []string) {
	fs := flags("run", args)
	if d := fs.str("done"); d != "" {
		sj := fs.pos(0, "")
		if sj == "" {
			fatalf("run --done <family/item> <studio job id>")
		}
		fam := strings.SplitN(d, "/", 2)[0]
		js := loadJobs(fam)
		hit := false
		for _, j := range js {
			if j.ID == d {
				j.Status, j.StudioJob, hit = "done", sj, true
			}
		}
		if !hit {
			fatalf("no job %s", d)
		}
		writeJSON(jobsPath(fam), js)
		fmt.Printf("%s done (%s)\n", d, sj)
		return
	}
	n := fs.int("next", 1)
	famName := fs.pos(0, "all")
	var out []map[string]any
	pending, done := 0, 0
	for _, f := range selectFamilies(mustFamilies(root), famName) {
		for _, j := range loadJobs(f.Family) {
			if j.Status != "pending" {
				done++
				continue
			}
			pending++
			if len(out) < n {
				out = append(out, map[string]any{"job": j.ID, "studio_args": j.Args})
			}
		}
	}
	b, _ := json.MarshalIndent(out, "", "  ")
	fmt.Println(string(b))
	fmt.Fprintf(os.Stderr, "pending %d, done/ingested %d\n", pending, done)
}

// cmdIngest copies finished studio outputs into the raw cache and records
// provenance in art/families/<family>-runs.json.
func cmdIngest(root string, args []string) {
	fs := flags("ingest", args)
	for _, f := range selectFamilies(mustFamilies(root), fs.pos(0, "all")) {
		js := loadJobs(f.Family)
		if len(js) == 0 {
			continue
		}
		led := loadLedger(root, f.Family)
		changed := false
		if scanIdx == nil {
			scanIdx = scanStudio()
		}
		for _, j := range js {
			if j.Status == "pending" {
				ov := j.Args["overrides"].(map[string]any)
				k := provKey(j.Args["workflow"].(string), fmt.Sprint(ov["prompt"]), int64(ov["seed"].(float64)))
				if sj, ok := scanIdx[k]; ok {
					j.Status, j.StudioJob = "done", sj
				}
			}
			if j.Status != "done" {
				continue
			}
			wfRel := j.Args["workflow"].(string)
			wf := loadWorkflow(root, wfRel)
			rgbID, matteID := saveNodes(wf)
			ov := j.Args["overrides"].(map[string]any)
			seed0 := int64(ov["seed"].(float64))
			dir := filepath.Join(imagegenRoot(), "studio", j.StudioJob)
			// one save node: <dir>/NNNN_00001_.png; several: <dir>/NNNN/<node>_00001_.png
			subs, _ := filepath.Glob(filepath.Join(dir, "[0-9][0-9][0-9][0-9]"))
			flat, _ := filepath.Glob(filepath.Join(dir, "[0-9][0-9][0-9][0-9]_*.png"))
			sort.Strings(subs)
			sort.Strings(flat)
			if len(subs) == 0 {
				subs = flat
			}
			if len(subs) == 0 {
				fmt.Fprintf(os.Stderr, "%s: no outputs in %s\n", j.ID, dir)
				continue
			}
			_, it := findItem([]*Family{f}, j.Item)
			for i, sd := range subs {
				seed := seed0 + int64(i)
				rgb := sd
				if st, err := os.Stat(sd); err == nil && st.IsDir() {
					rgb = firstGlob(filepath.Join(sd, rgbID+"_*.png"))
				}
				if rgb == "" {
					continue
				}
				rawDir := filepath.Join(cacheRoot(), "raw", f.Family, j.Item)
				dstRGB := filepath.Join(rawDir, fmt.Sprintf("%d-rgb.png", seed))
				copyFile(rgb, dstRGB)
				models := provModels(rgb)
				if len(models) == 0 {
					models = wfModels(wf)
				}
				r := &Run{Workflow: wfRel, Models: models, Prompt: fmt.Sprint(ov["prompt"]), Seed: seed,
					StudioJob: j.StudioJob, Raw: dstRGB, SHA256: shaFile(dstRGB)}
				if neg, ok := ov["negative_prompt"].(string); ok {
					r.Negative = neg
				}
				if it != nil && it.Derive != nil {
					r.DerivedFrom = it.Derive.From
				}
				if matteID != "" {
					if m := firstGlob(filepath.Join(sd, matteID+"_*.png")); m != "" {
						dm := filepath.Join(rawDir, fmt.Sprintf("%d-matte.png", seed))
						copyFile(m, dm)
						r.MatteSHA256 = shaFile(dm)
					}
				}
				key := fmt.Sprintf("%s/%d", j.Item, seed)
				if prev, ok := led[key]; ok {
					r.Selected, r.PickReason, r.SourceSHA256 = prev.Selected, prev.PickReason, prev.SourceSHA256
				}
				if prev, ok := led[key]; ok && prev.SHA256 != r.SHA256 {
					os.Remove(candPath(f.Family, j.Item, seed)) // re-roll: drop the stale candidate
				}
				led[key] = r
				changed = true
			}
			j.Status = "ingested"
		}
		if changed {
			saveLedger(root, f.Family, led)
			writeJSON(jobsPath(f.Family), js)
			fmt.Printf("%s: ledger %d runs\n", f.Family, len(led))
		}
	}
}

var scanIdx map[string]string

func firstGlob(p string) string {
	m, _ := filepath.Glob(p)
	sort.Strings(m)
	if len(m) == 0 {
		return ""
	}
	return m[0]
}

func contains(l []string, s string) bool {
	for _, x := range l {
		if x == s {
			return true
		}
	}
	return false
}
