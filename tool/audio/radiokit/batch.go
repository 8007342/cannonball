package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strconv"
)

// The shared studio GPU queue can hold a job for many minutes, so songs are
// rendered several at a time: one graph with shared loaders and `slots`
// independent song chains, two candidates (seed, seed+1) per song.

func batchWorkflowPath(slots int) string {
	return fmt.Sprintf("art/music/workflows/acestep15-radio-batch%d.json", slots)
}

func slotNode(slot, cand, part int) string { return strconv.Itoa(100 + slot*20 + cand*10 + part) }

// BatchWorkflow builds the graph from the single-song workflow's settings.
func BatchWorkflow(single map[string]map[string]any, slots int) map[string]any {
	wf := map[string]any{}
	for _, id := range []string{"1", "2", "3", "4"} {
		wf[id] = single[id]
	}
	enc := single["5"]["inputs"].(map[string]any)
	ks := single["8"]["inputs"].(map[string]any)
	for s := 0; s < slots; s++ {
		for c := 0; c < 2; c++ {
			n := func(p int) string { return slotNode(s, c, p) }
			ei := map[string]any{}
			for k, v := range enc {
				ei[k] = v
			}
			ei["clip"] = []any{"2", 0}
			ki := map[string]any{}
			for k, v := range ks {
				ki[k] = v
			}
			ki["model"], ki["positive"], ki["negative"], ki["latent_image"] = []any{"4", 0}, []any{n(0), 0}, []any{n(1), 0}, []any{n(2), 0}
			title := fmt.Sprintf("slot %d candidate %d", s, c)
			wf[n(0)] = map[string]any{"class_type": "TextEncodeAceStepAudio1.5", "_meta": map[string]any{"title": title + " prompt"}, "inputs": ei}
			wf[n(1)] = map[string]any{"class_type": "ConditioningZeroOut", "_meta": map[string]any{"title": title + " negative (zero)"}, "inputs": map[string]any{"conditioning": []any{n(0), 0}}}
			wf[n(2)] = map[string]any{"class_type": "EmptyAceStep1.5LatentAudio", "_meta": map[string]any{"title": title + " latent"}, "inputs": map[string]any{"seconds": 90.0, "batch_size": 1}}
			wf[n(3)] = map[string]any{"class_type": "KSampler", "_meta": map[string]any{"title": title + " sampler"}, "inputs": ki}
			wf[n(4)] = map[string]any{"class_type": "VAEDecodeAudio", "_meta": map[string]any{"title": title + " decode"}, "inputs": map[string]any{"samples": []any{n(3), 0}, "vae": []any{"3", 0}}}
			wf[n(5)] = map[string]any{"class_type": "SaveAudio", "_meta": map[string]any{"title": title + " save"}, "inputs": map[string]any{"audio": []any{n(4), 0}, "filename_prefix": fmt.Sprintf("radio/slot%d-%d", s, c)}}
		}
	}
	return wf
}

// BatchOverrides fills slots with songs; unused slots repeat the last song
// with the same seeds, which the ingest step ignores as duplicates.
func BatchOverrides(s SongSpec, songs []Song, slots int) map[string]any {
	o := map[string]any{}
	for i := 0; i < slots; i++ {
		song := songs[min(i, len(songs)-1)]
		for c := 0; c < 2; c++ {
			n := func(p int) string { return "$node:" + slotNode(i, c, p) }
			seed := song.Seed + c
			o[n(0)+".tags"] = s.Prompt(song)
			o[n(0)+".bpm"] = song.BPM
			o[n(0)+".keyscale"] = song.Key
			o[n(0)+".duration"] = song.Duration
			o[n(0)+".seed"] = seed
			o[n(2)+".seconds"] = song.Duration
			o[n(3)+".seed"] = seed
		}
	}
	return o
}

func cmdBatch(slots int) error {
	s, err := loadSongs()
	if err != nil {
		return err
	}
	var single map[string]map[string]any
	if err := readJSON(filepath.Join(root, s.Workflow), &single); err != nil {
		return err
	}
	var todo []Song
	for _, song := range s.Songs {
		if _, err := os.Stat(filepath.Join(cache, "raw", song.ID, fmt.Sprintf("%d.flac", song.Seed+1))); err != nil {
			todo = append(todo, song)
		}
	}
	for i := 0; i < len(todo); i += slots {
		group := todo[i:min(i+slots, len(todo))]
		path := batchWorkflowPath(len(group))
		if err := writeJSON(filepath.Join(root, path), BatchWorkflow(single, len(group))); err != nil {
			return err
		}
		var ids []string
		for _, g := range group {
			ids = append(ids, g.ID)
		}
		b, _ := json.Marshal(map[string]any{"workflow": path, "slots": ids, "overrides": BatchOverrides(s, group, len(group))})
		fmt.Println(string(b))
	}
	return nil
}

// cmdIngestBatch copies a batch job's outputs. The studio names each file
// after its SaveAudio node id, so songs are given in slot order (as printed
// by `batch`); slot s candidate c is node 100+20s+10c+5, seed song.seed+c.
func cmdIngestBatch(job string, ids []string) error {
	s, err := loadSongs()
	if err != nil {
		return err
	}
	byID := map[string]Song{}
	for _, song := range s.Songs {
		byID[song.ID] = song
	}
	for slot, id := range ids {
		song, ok := byID[id]
		if !ok {
			return fmt.Errorf("unknown song %s", id)
		}
		dir, err := os.MkdirTemp(cache, "batch-")
		if err != nil {
			return err
		}
		for c := 0; c < 2; c++ {
			matches, _ := filepath.Glob(filepath.Join(job, "*", slotNode(slot, c, 5)+"_*.flac"))
			more, _ := filepath.Glob(filepath.Join(job, slotNode(slot, c, 5)+"_*.flac"))
			matches = append(matches, more...)
			if len(matches) == 0 {
				os.RemoveAll(dir)
				return fmt.Errorf("%s: candidate %d missing in %s", song.ID, song.Seed+c, job)
			}
			sort.Strings(matches)
			b, _ := os.ReadFile(matches[0])
			os.WriteFile(filepath.Join(dir, fmt.Sprintf("%04d_00001.flac", c)), b, 0o644)
			if p, err := os.ReadFile(matches[0] + ".provenance.json"); err == nil {
				os.WriteFile(filepath.Join(dir, fmt.Sprintf("%04d_00001.flac.provenance.json", c)), p, 0o644)
			}
		}
		err = ingestDir(song.ID, dir, filepath.Base(job), batchWorkflowPath(len(ids)))
		os.RemoveAll(dir)
		if err != nil {
			return err
		}
	}
	return nil
}
