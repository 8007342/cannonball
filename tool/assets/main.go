// Command assets is Cannonball's scenic asset pipeline:
//
//	plan [family|all] [--item id,...] [--all] [--redo]   write studio jobs (items lacking a pick)
//	run [family|all] [--next N]                          print the next pending studio.queue_workflow calls
//	run --done <family/item> <studio job id>             record a finished studio job
//	ingest [family|all]                                  copy outputs to the raw cache + provenance ledger
//	finish [family|all] [--item ids] [--force]           matte/key/trim/downscale candidates + candidate sheet
//	pick <id> <seed> <reason...>                         commit a candidate to art/sources/<family>/<id>.png
//	pack [--no-contact]                                  atlases, road textures, manifest (byte-identical)
//	contact [family|all]                                 art/contact/<family>.png sheets of the picks
//	check                                                validate specs, picks, ledgers and budgets
//	status [family|all]                                  per-item state
//
// Run from the repo root: go run -C tool/assets . <verb> ... (or build once:
// go build -C tool/assets -o ~/.cache/tillandsias-project/bin/scenic-assets .).
// See art/README.md.
package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"
)

func fatalf(f string, a ...any) {
	if lockHeld {
		os.Remove(filepath.Join(cacheRoot(), "assets.lock"))
	}
	fmt.Fprintf(os.Stderr, "assets: "+f+"\n", a...)
	os.Exit(1)
}

func cacheRoot() string {
	if v := os.Getenv("SCENIC_CACHE"); v != "" {
		return v
	}
	h, _ := os.UserHomeDir()
	return filepath.Join(h, ".cache/tillandsias-project/cannonball-art")
}

func imagegenRoot() string {
	if v := os.Getenv("IMAGEGEN_ROOT"); v != "" {
		return v
	}
	return "/work/tmp/imagegen"
}

func repoRoot() string {
	d, _ := os.Getwd()
	for {
		if _, err := os.Stat(filepath.Join(d, "art/families")); err == nil {
			if _, err := os.Stat(filepath.Join(d, "pubspec.yaml")); err == nil {
				return d
			}
		}
		p := filepath.Dir(d)
		if p == d {
			fatalf("run inside the cannonball checkout (no art/families found)")
		}
		d = p
	}
}

var famCache []*Family

func mustFamilies(root string) []*Family {
	if famCache == nil {
		fs, err := loadFamilies(root)
		if err != nil {
			fatalf("%v", err)
		}
		famCache = fs
	}
	return famCache
}

type flagSet struct {
	positional []string
	named      map[string]string
}

func flags(verb string, args []string) *flagSet {
	fs := &flagSet{named: map[string]string{}}
	for i := 0; i < len(args); i++ {
		a := args[i]
		if strings.HasPrefix(a, "--") {
			k := strings.TrimPrefix(a, "--")
			if eq := strings.Index(k, "="); eq >= 0 {
				fs.named[k[:eq]] = k[eq+1:]
			} else if i+1 < len(args) && !strings.HasPrefix(args[i+1], "--") && takesValue(k) {
				fs.named[k] = args[i+1]
				i++
			} else {
				fs.named[k] = "true"
			}
			continue
		}
		fs.positional = append(fs.positional, a)
	}
	return fs
}

func takesValue(k string) bool { return k == "item" || k == "next" || k == "done" }

func (f *flagSet) pos(i int, def string) string {
	if i < len(f.positional) {
		return f.positional[i]
	}
	return def
}
func (f *flagSet) str(k string) string { return f.named[k] }
func (f *flagSet) bool(k string) bool  { return f.named[k] == "true" }
func (f *flagSet) int(k string, def int) int {
	if v, ok := f.named[k]; ok {
		n, err := strconv.Atoi(v)
		if err == nil {
			return n
		}
	}
	return def
}
func (f *flagSet) list(k string) []string {
	if v := f.named[k]; v != "" {
		return strings.Split(v, ",")
	}
	return nil
}

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintln(os.Stderr, "usage: assets plan|run|ingest|finish|pick|pack|contact|check|status ... (see tool/assets/main.go)")
		os.Exit(2)
	}
	root := repoRoot()
	args := os.Args[2:]
	switch os.Args[1] {
	case "plan", "run", "ingest", "pick":
		unlock := lock()
		defer unlock()
	}
	switch os.Args[1] {
	case "plan":
		cmdPlan(root, args)
	case "run":
		cmdRun(root, args)
	case "ingest":
		cmdIngest(root, args)
	case "finish":
		cmdFinish(root, args)
	case "pick":
		cmdPick(root, args)
	case "pack":
		cmdPack(root, args)
	case "contact":
		cmdContact(root, args)
	case "check":
		cmdCheck(root, args)
	case "status":
		cmdStatus(root, args)
	default:
		fatalf("unknown verb %s", os.Args[1])
	}
}

func cmdStatus(root string, args []string) {
	fs := flags("status", args)
	for _, f := range selectFamilies(mustFamilies(root), fs.pos(0, "all")) {
		led := loadLedger(root, f.Family)
		jobs := map[string]string{}
		for _, j := range loadJobs(f.Family) {
			jobs[j.Item] = j.Status
		}
		picked := 0
		for _, it := range f.Items {
			runs, sel := 0, ""
			for k, r := range led {
				if strings.HasPrefix(k, it.ID+"/") {
					runs++
					if r.Selected {
						sel = strconv.FormatInt(r.Seed, 10)
					}
				}
			}
			_, err := os.Stat(sourcePath(root, f, &it))
			state := "missing"
			if err == nil {
				state = "picked"
				picked++
			}
			if fs.bool("v") {
				fmt.Printf("  %-28s %-7s job=%-9s runs=%d sel=%s\n", it.ID, state, jobs[it.ID], runs, sel)
			}
		}
		fmt.Printf("%s (%s): %d/%d picked\n", f.Family, f.Type, picked, len(f.Items))
	}
}

func cmdCheck(root string, args []string) {
	fams := mustFamilies(root)
	bad := 0
	var srcBytes int64
	for _, f := range fams {
		led := loadLedger(root, f.Family)
		for _, it := range f.Items {
			p := sourcePath(root, f, &it)
			st, err := os.Stat(p)
			if err != nil {
				continue
			}
			srcBytes += st.Size()
			sum := shaFile(p)
			found := false
			for k, r := range led {
				if strings.HasPrefix(k, it.ID+"/") && r.Selected {
					found = true
					if r.SourceSHA256 != "" && r.SourceSHA256 != sum {
						fmt.Printf("%s: source sha differs from ledger %s\n", it.ID, k)
						bad++
					}
				}
			}
			if !found && f.Workflow != "" {
				fmt.Printf("%s: pick has no selected ledger entry\n", it.ID)
				bad++
			}
		}
	}
	var atlasBytes int64
	for _, pat := range []string{"assets/scenic/*.png", "assets/scenic/road/*.png"} {
		ms, _ := filepath.Glob(filepath.Join(root, pat))
		for _, m := range ms {
			st, _ := os.Stat(m)
			atlasBytes += st.Size()
		}
	}
	fmt.Printf("families %d; picks %.1f MB (budget 60); runtime %.1f MB (budget 16)\n", len(fams), float64(srcBytes)/1e6, float64(atlasBytes)/1e6)
	if srcBytes > 60e6 || atlasBytes > 16e6 {
		bad++
		fmt.Println("over budget")
	}
	if bad > 0 {
		os.Exit(1)
	}
}
