package main

// Pipeline driver verbs over art/rigs/structures-rigs.json (run from the repo root):
//
//	rigfinish plan   [-ids a,b|prefix*] [-seed-offset 0]   stage paint inputs, print one job per item
//	rigfinish ingest -id X -paint OUT.png [-pick "reason"]  finish + record item and provenance
//	rigfinish pack-sheet                                    art/contact/structures.png from the picks
//
// The studio jobs themselves are MCP tool calls (studio.queue_workflow); `plan` prints their
// exact arguments as JSON lines so an agent (or a person in ComfyUI) can submit them one by one.

import (
	"encoding/json"
	"flag"
	"fmt"
	"hash/fnv"
	"io"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

type paintCfg struct {
	Workflow string  `json:"workflow"`
	Denoise  float64 `json:"denoise"`
	Count    int     `json:"count"`
	Prefix   string  `json:"prefix"`
	Suffix   string  `json:"suffix"`
	Negative string  `json:"negative"`
}

type specItem struct {
	ID       string         `json:"id"`
	Template string         `json:"template"`
	Params   map[string]any `json:"params"`
	Kind     string         `json:"kind"`
	Band     string         `json:"band"`
	Biomes   []string       `json:"biomes"`
	Prompt   string         `json:"prompt"`
	Mirror   *bool          `json:"mirror"`
	Collides *bool          `json:"collides"`
	Sway     float64        `json:"sway"`
	MaxPx    int            `json:"maxPx"`
	Seed     int            `json:"seed"`
	Denoise  float64        `json:"denoise"`
	Notes    string         `json:"notes"`
}

type spec struct {
	Paint paintCfg   `json:"paint"`
	Items []specItem `json:"items"`
}

const (
	specPath  = "art/rigs/structures-rigs.json"
	famPath   = "art/families/structures.json"
	runsPath  = "art/families/structures-runs.json"
	srcDir    = "art/sources/structures"
	stageDir  = "/work/tmp/imagegen/in/structures"
	sheetPath = "art/contact/structures.png"
)

func cacheDir() string {
	if d := os.Getenv("CANNONBALL_ART"); d != "" {
		return d
	}
	return filepath.Join(os.Getenv("HOME"), ".cache/tillandsias-project/cannonball-art")
}

func readJSON(path string, v any) error {
	b, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	return json.Unmarshal(b, v)
}

func writeJSON(path string, v any) {
	b, err := json.MarshalIndent(v, "", "  ")
	must(err)
	must(os.WriteFile(path, append(b, '\n'), 0o644))
}

func loadSpec() spec {
	var s spec
	must(readJSON(specPath, &s))
	return s
}

func selectItems(s spec, ids string) []specItem {
	if ids == "" {
		return s.Items
	}
	var out []specItem
	for _, it := range s.Items {
		for _, w := range strings.Split(ids, ",") {
			if it.ID == w || strings.HasSuffix(w, "*") && strings.HasPrefix(it.ID, strings.TrimSuffix(w, "*")) {
				out = append(out, it)
				break
			}
		}
	}
	return out
}

func baseSeed(it specItem) int {
	if it.Seed > 0 {
		return it.Seed
	}
	h := fnv.New32a()
	h.Write([]byte(it.ID))
	return int(h.Sum32()%90000) + 10000
}

func copyFile(src, dst string) {
	in, err := os.Open(src)
	must(err)
	defer in.Close()
	out, err := os.Create(dst)
	must(err)
	_, err = io.Copy(out, in)
	must(err)
	must(out.Close())
}

func plan(args []string) {
	fs := flag.NewFlagSet("plan", flag.ExitOnError)
	ids := fs.String("ids", "", "comma list of ids or prefix*")
	off := fs.Int("seed-offset", 0, "add to every seed (new candidates)")
	must(fs.Parse(args))
	s := loadSpec()
	must(os.MkdirAll(stageDir, 0o755))
	for _, it := range selectItems(s, *ids) {
		shade := filepath.Join(cacheDir(), "rigs", it.ID, "shade.png")
		if _, err := os.Stat(shade); err != nil {
			fmt.Fprintf(os.Stderr, "plan: %s has no rig render (lua art/rigs/run.lua render %s)\n", it.ID, it.ID)
			continue
		}
		in := filepath.Join(stageDir, it.ID+".png")
		copyFile(shade, in)
		dn := s.Paint.Denoise
		if it.Denoise > 0 {
			dn = it.Denoise
		}
		job := map[string]any{
			"id": it.ID, "workflow": s.Paint.Workflow, "init_image": in, "count": max(1, s.Paint.Count),
			"overrides": map[string]any{
				"seed":             baseSeed(it) + *off,
				"prompt":           strings.TrimSpace(s.Paint.Prefix + " " + it.Prompt + ". " + s.Paint.Suffix),
				"negative_prompt":  s.Paint.Negative,
				"$node:11.denoise": dn,
			},
		}
		j, _ := json.Marshal(job)
		fmt.Println(string(j))
	}
}

type provenance struct {
	Workflow struct {
		Path   string `json:"path"`
		Sha256 string `json:"sha256"`
	} `json:"workflow"`
	Models []struct {
		File    string `json:"file"`
		Repo    string `json:"repo"`
		Licence string `json:"licence"`
	} `json:"models"`
	Seed     int     `json:"seed"`
	Prompt   string  `json:"prompt"`
	Negative string  `json:"negative_prompt"`
	Output   string  `json:"output_sha256"`
	Denoise  float64 `json:"denoise"`
	At       string  `json:"at"`
}

func defMax(it specItem) int {
	if it.MaxPx > 0 {
		return it.MaxPx
	}
	// longest side; art/families/README.md caps sources at 512 (the packer only downscales)
	if it.Band == "near" {
		return 384
	}
	return 512
}

func ingest(args []string) {
	fs := flag.NewFlagSet("ingest", flag.ExitOnError)
	id := fs.String("id", "", "item id")
	paint := fs.String("paint", "", "painted output PNG (its .provenance.json sidecar is read)")
	pick := fs.String("pick", "", "pick reason")
	must(fs.Parse(args))
	s := loadSpec()
	var it *specItem
	for i := range s.Items {
		if s.Items[i].ID == *id {
			it = &s.Items[i]
		}
	}
	if it == nil {
		must(fmt.Errorf("ingest: no item %q in %s", *id, specPath))
	}
	rigDir := filepath.Join(cacheDir(), "rigs", it.ID)
	must(os.MkdirAll(srcDir, 0o755))
	out := filepath.Join(srcDir, it.ID+".png")
	rec := finishCore(*paint, rigDir, out, defMax(*it), 1, 1, keepColours(it.Template, rigDir)...)
	var pv provenance
	_ = readJSON(*paint+".provenance.json", &pv)
	var rg map[string]any
	must(readJSON(filepath.Join(rigDir, "rig.json"), &rg))
	models := []string{}
	for _, m := range pv.Models {
		models = append(models, m.File)
	}
	mirror := true
	if it.Mirror != nil {
		mirror = *it.Mirror
	}
	collides := it.Kind == "structure" || it.Kind == "vehicle"
	if it.Collides != nil {
		collides = *it.Collides
	}
	dn := s.Paint.Denoise
	if it.Denoise > 0 {
		dn = it.Denoise
	}
	if pv.Denoise > 0 { // what the paint was actually made with (collect-batch sidecar)
		dn = pv.Denoise
	}
	item := map[string]any{
		"id": it.ID, "prompt": it.Prompt, "file": filepath.Join("structures", it.ID+".png"), "kind": it.Kind, "band": it.Band,
		"worldWidthM": rec["worldWidthM"], "worldHeightM": rec["worldHeightM"], "biomes": it.Biomes,
		"size": rec["size"], "anchor": rec["anchor"], "mirror": mirror, "sway": it.Sway, "collides": collides,
		"provenance": map[string]any{
			"rig":      map[string]any{"script": "art/rigs/rig.py", "template": "art/rigs/structures/" + it.Template + ".json", "params": rg["params"], "view": rg["view"]},
			"workflow": pv.Workflow.Path, "workflowSha256": pv.Workflow.Sha256, "models": models,
			"prompt": pv.Prompt, "negativePrompt": pv.Negative, "seed": pv.Seed, "denoise": dn,
			"paintSha256": pv.Output, "sha256": rec["sha256"], "pick_reason": *pick, "at": pv.At,
		},
	}
	// upsert, keeping the spec's item order
	fam := map[string]any{}
	_ = readJSON(famPath, &fam)
	cur := map[string]any{}
	if lst, ok := fam["items"].([]any); ok {
		for _, x := range lst {
			if m, ok := x.(map[string]any); ok {
				cur[m["id"].(string)] = m
			}
		}
	}
	cur[it.ID] = item
	var items []any
	for _, si := range s.Items {
		if v, ok := cur[si.ID]; ok {
			items = append(items, v)
			delete(cur, si.ID)
		}
	}
	rest := []string{}
	for k := range cur {
		rest = append(rest, k)
	}
	sort.Strings(rest)
	for _, k := range rest {
		items = append(items, cur[k])
	}
	fam["family"] = "structures"
	fam["type"] = "sprite"
	fam["atlas"] = "struct"
	fam["workflow"] = s.Paint.Workflow
	fam["notes"] = "Blender-guided structure pack. Generated by `rigfinish ingest` from art/rigs/structures-rigs.json; sprites in art/sources/structures/. anchor = ground contact under the footprint centre, in sprite px. mirror = may be flipped for the left side of the road."
	fam["items"] = items
	writeJSON(famPath, fam)
	runs := map[string]any{}
	_ = readJSON(runsPath, &runs)
	for k, v := range runs { // one selected candidate per item
		if strings.HasPrefix(k, it.ID+"/") {
			if m, ok := v.(map[string]any); ok {
				m["selected"] = false
			}
		}
	}
	runs[fmt.Sprintf("%s/%d", it.ID, pv.Seed)] = map[string]any{"raw": *paint, "paintSha256": pv.Output, "source_sha256": rec["sha256"],
		"source": out, "selected": true, "pick_reason": *pick, "workflow": pv.Workflow.Path, "models": models,
		"prompt": pv.Prompt, "negative": pv.Negative, "seed": pv.Seed, "denoise": dn, "at": pv.At,
		"rig": map[string]any{"template": it.Template, "params": rg["params"], "view": rg["view"]}}
	writeJSON(runsPath, runs)
	j, _ := json.Marshal(map[string]any{"id": it.ID, "out": out, "size": rec["size"], "worldWidthM": rec["worldWidthM"]})
	fmt.Println(string(j))
}

func packSheet(args []string) {
	fam := map[string]any{}
	must(readJSON(famPath, &fam))
	files := []string{"-cell", "200", "-cols", "8", sheetPath}
	for _, x := range fam["items"].([]any) {
		files = append(files, filepath.Join("art/sources", x.(map[string]any)["file"].(string)))
	}
	must(os.MkdirAll(filepath.Dir(sheetPath), 0o755))
	sheet(files)
}

// keepColours: the template's "keep_rig" entries (hex or param names) resolved via rig.json params.
func keepColours(template, rigDir string) []string {
	var t struct {
		Keep []string `json:"keep_rig"`
	}
	_ = readJSON(filepath.Join("art/rigs/structures", template+".json"), &t)
	var rg struct {
		Params map[string]any `json:"params"`
	}
	_ = readJSON(filepath.Join(rigDir, "rig.json"), &rg)
	var out []string
	for _, k := range t.Keep {
		if v, ok := rg.Params[k].(string); ok {
			k = v
		}
		out = append(out, k)
	}
	return out
}
