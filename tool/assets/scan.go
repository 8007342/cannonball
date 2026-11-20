package main

import (
	"fmt"
	"path/filepath"
	"sort"
	"strings"
)

type studioProv struct {
	Workflow struct {
		Path string `json:"path"`
	} `json:"workflow"`
	Seed   int64  `json:"seed"`
	Prompt string `json:"prompt"`
	Models []struct {
		File     string `json:"file"`
		Repo     string `json:"repo"`
		Revision string `json:"revision"`
		Licence  string `json:"licence"`
	} `json:"models"`
	Engine struct {
		Ref string `json:"ref"`
	} `json:"engine"`
}

func provKey(wf, prompt string, seed int64) string {
	return fmt.Sprintf("%s|%d|%s", wf, seed, strings.TrimSpace(prompt))
}

// scanStudio indexes finished studio jobs by (workflow, first seed, prompt)
// from the provenance sidecars studio.run_workflow writes beside outputs, so
// the dispatcher only has to run the call: ingest finds the outputs itself.
func scanStudio() map[string]string {
	idx := map[string]string{}
	var ps []string
	for _, pat := range []string{"*/0000/*.provenance.json", "*/0000_*.provenance.json"} {
		m, _ := filepath.Glob(filepath.Join(imagegenRoot(), "studio", pat))
		ps = append(ps, m...)
	}
	sort.Strings(ps) // later (newer) job ids win on re-runs
	for _, p := range ps {
		var pv studioProv
		if readJSON(p, &pv) != nil {
			continue
		}
		rel, _ := filepath.Rel(filepath.Join(imagegenRoot(), "studio"), p)
		job := strings.SplitN(filepath.ToSlash(rel), "/", 2)[0]
		idx[provKey(pv.Workflow.Path, pv.Prompt, pv.Seed)] = job
	}
	return idx
}

// provModels lists "file (repo@revision, licence)" for the ledger.
func provModels(outPath string) []string {
	var pv studioProv
	if readJSON(outPath+".provenance.json", &pv) != nil {
		return nil
	}
	var out []string
	for _, m := range pv.Models {
		out = append(out, fmt.Sprintf("%s (%s@%.12s, %s)", m.File, m.Repo, m.Revision, m.Licence))
	}
	return out
}
