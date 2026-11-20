package main

// Batch painting with art/rigs/workflows/structure-paint-qwen-batch4.json: four items x two
// seeds per studio job (one job in flight; fewer model reloads than 4 single jobs).
//
//	rigfinish batch -ids a,b,c,d -name NAME [-seed-offset 0]   stage + print queue_workflow args
//	rigfinish collect-batch -name NAME -job /work/tmp/imagegen/studio/<job>
//	    copy outputs to $CACHE/paints/<id>/<seed>.png with a per-output provenance sidecar
//	    (the studio sidecar with this chain's prompt/seed patched in), review sheet
//	    $CACHE/batches/NAME.png (row per item, two candidates).

import (
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// batch4 / batch8: 4 or 8 items x 2 seeds per job (8 when the shared GPU queue is long:
// fewer queue turns). Chain i uses nodes i*20+100 ...; outputs are named by SaveImage id.
func batchWorkflow(n int) string {
	return fmt.Sprintf("art/rigs/workflows/structure-paint-qwen-batch%d.json", n)
}

type chain struct {
	ID       string  `json:"id"`
	Seeds    [2]int  `json:"seeds"`
	Prompt   string  `json:"prompt"`
	Negative string  `json:"negative"`
	Denoise  float64 `json:"denoise"`
}

func promptFor(s spec, it specItem) string {
	suffix := s.Paint.Suffix
	if strings.Contains(it.Notes, "text-ok") { // signs whose legend is generic road text
		suffix = strings.ReplaceAll(suffix, "no text, ", "")
	}
	return strings.TrimSpace(s.Paint.Prefix + " " + it.Prompt + ". " + suffix)
}

func batch(args []string) {
	fs := flag.NewFlagSet("batch", flag.ExitOnError)
	ids := fs.String("ids", "", "up to 4 ids")
	name := fs.String("name", "", "batch name")
	off := fs.Int("seed-offset", 0, "seed offset")
	must(fs.Parse(args))
	s := loadSpec()
	items := selectItems(s, *ids)
	if len(items) == 0 || len(items) > 8 || *name == "" {
		must(fmt.Errorf("batch: need -name and 1..8 ids"))
	}
	width := 4
	if len(items) > 4 {
		width = 8
	}
	must(os.MkdirAll(stageDir, 0o755))
	inputs := map[string]string{}
	ov := map[string]any{}
	var chains []chain
	for i := 0; i < width; i++ {
		it := items[min(i, len(items)-1)]
		shade := filepath.Join(cacheDir(), "rigs", it.ID, "shade.png")
		in := filepath.Join(stageDir, it.ID+".png")
		copyFile(shade, in)
		dn := s.Paint.Denoise
		if it.Denoise > 0 {
			dn = it.Denoise
		}
		seed := baseSeed(it) + *off
		neg := s.Paint.Negative
		if strings.Contains(it.Notes, "text-ok") {
			neg = strings.ReplaceAll(neg, "text, letters, ", "")
		}
		c := chain{ID: it.ID, Seeds: [2]int{seed, seed + 1}, Prompt: promptFor(s, it), Negative: neg, Denoise: dn}
		b := i*20 + 100
		inputs[fmt.Sprintf("in%d", i)] = in
		ov[fmt.Sprintf("$node:%d.prompt", b+2)] = c.Prompt
		ov[fmt.Sprintf("$node:%d.prompt", b+3)] = c.Negative
		for j := 0; j < 2; j++ {
			ov[fmt.Sprintf("$node:%d.seed", b+5+j)] = c.Seeds[j]
			ov[fmt.Sprintf("$node:%d.denoise", b+5+j)] = dn
		}
		if i < len(items) {
			chains = append(chains, c)
		} else {
			chains = append(chains, chain{}) // padding chain: output ignored
		}
	}
	dir := filepath.Join(cacheDir(), "batches")
	must(os.MkdirAll(dir, 0o755))
	writeJSON(filepath.Join(dir, *name+".json"), chains)
	j, _ := json.Marshal(map[string]any{"workflow": batchWorkflow(width), "inputs": inputs, "overrides": ov})
	fmt.Println(string(j))
}

func collectBatch(args []string) {
	fs := flag.NewFlagSet("collect-batch", flag.ExitOnError)
	name := fs.String("name", "", "batch name")
	job := fs.String("job", "", "studio job dir")
	must(fs.Parse(args))
	var chains []chain
	must(readJSON(filepath.Join(cacheDir(), "batches", *name+".json"), &chains))
	var cells []string
	for i, c := range chains {
		if c.ID == "" {
			continue
		}
		for j := 0; j < 2; j++ {
			// the studio names outputs by SaveImage node id, possibly inside a 0000/ folder
			pat := fmt.Sprintf("%d_*.png", i*20+100+9+j)
			m, _ := filepath.Glob(filepath.Join(*job, pat))
			if len(m) == 0 {
				m, _ = filepath.Glob(filepath.Join(*job, "*", pat))
			}
			if len(m) == 0 {
				fmt.Fprintf(os.Stderr, "collect-batch: no output for chain %d seed %d (%s)\n", i, j, c.ID)
				continue
			}
			dst := filepath.Join(cacheDir(), "paints", c.ID)
			must(os.MkdirAll(dst, 0o755))
			out := filepath.Join(dst, fmt.Sprintf("%d.png", c.Seeds[j]))
			copyFile(m[0], out)
			pv := map[string]any{}
			_ = readJSON(m[0]+".provenance.json", &pv)
			pv["seed"], pv["prompt"], pv["negative_prompt"] = c.Seeds[j], c.Prompt, c.Negative
			pv["denoise"], pv["chain"] = c.Denoise, fmt.Sprintf("b%ds%d", i, j)
			writeJSON(out+".provenance.json", pv)
			cells = append(cells, out)
			fmt.Println(out)
		}
	}
	sheetOut := filepath.Join(cacheDir(), "batches", *name+".png")
	sheet(append([]string{"-cell", "320", "-cols", "4", sheetOut}, cells...))
}
