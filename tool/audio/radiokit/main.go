// Command radiokit builds and verifies the Cannonball radio programme:
// ACE-Step song candidates -> metric pick -> mastered MP3, Kokoro presenter
// lines -> radio-band MP3, synthesized tuning buzz, catalog and verification.
// It shells out to ffmpeg; nothing here loads a model or touches the network.
package main

import (
	"encoding/json"
	"fmt"
	"math"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

var (
	root  = findRoot()
	cache = func() string {
		if v := os.Getenv("CANNONBALL_AUDIO_CACHE"); v != "" {
			return v
		}
		h, _ := os.UserHomeDir()
		return filepath.Join(h, ".cache/tillandsias-project/cannonball-audio")
	}()
	songSpecPath = filepath.Join(root, "art/music/radio-songs.json")
	lineSpecPath = filepath.Join(root, "art/music/radio-interjections.json")
	rendersPath  = filepath.Join(root, "art/music/radio-renders.json")
	musicDir     = filepath.Join(root, "assets/audio/music")
	catalogPath  = filepath.Join(root, "assets/audio/catalog.json")
	verifyPath   = filepath.Join(root, "assets/audio/radio-verification.json")
)

func findRoot() string {
	d, _ := os.Getwd()
	for p := d; p != "/"; p = filepath.Dir(p) {
		if _, err := os.Stat(filepath.Join(p, "pubspec.yaml")); err == nil {
			return p
		}
	}
	return d
}

const usage = `radiokit <command>
  jobs                 print one studio.run_workflow request per song
  ingest ID JOB_DIR    copy a studio job's FLAC candidates into the cache
  batch [N]            write N-song batch workflows; print one request per batch
  ingest-batch JOB ID.. copy a batch job's FLACs (songs in slot order) into the cache
  analyse [ID...]      measure candidates, pick one per song, log reasons
  master [ID...]       master picked songs to assets/audio/music/<id>.mp3
  voices               radio-band + master Kokoro lines to dj-<id>.mp3
  buzz                 synthesize tuning buzz clips to buzz-<n>.mp3
  catalog              write the programme block of assets/audio/catalog.json
  verify               decode every programme file and check the targets
  all                  analyse master voices buzz catalog verify`

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintln(os.Stderr, usage)
		os.Exit(2)
	}
	args := os.Args[2:]
	var err error
	switch os.Args[1] {
	case "jobs":
		err = cmdJobs()
	case "ingest":
		if len(args) != 2 {
			err = fmt.Errorf("ingest ID JOB_DIR")
		} else {
			err = cmdIngest(args[0], args[1])
		}
	case "batch":
		n := 6
		if len(args) > 0 {
			fmt.Sscan(args[0], &n)
		}
		err = cmdBatch(n)
	case "ingest-batch":
		if len(args) < 2 {
			err = fmt.Errorf("ingest-batch JOB_DIR SONG_ID... (slot order)")
		} else {
			err = cmdIngestBatch(args[0], args[1:])
		}
	case "analyse":
		err = cmdAnalyse(args)
	case "master":
		err = cmdMaster(args)
	case "voices":
		err = cmdVoices()
	case "buzz":
		err = cmdBuzz()
	case "catalog":
		err = cmdCatalog()
	case "verify":
		err = cmdVerify()
	case "all":
		for _, f := range []func() error{func() error { return cmdAnalyse(nil) }, func() error { return cmdMaster(nil) }, cmdVoices, cmdBuzz, cmdCatalog, cmdVerify} {
			if err = f(); err != nil {
				break
			}
		}
	default:
		err = fmt.Errorf("unknown command %q\n%s", os.Args[1], usage)
	}
	if err != nil {
		fmt.Fprintln(os.Stderr, "radiokit:", err)
		os.Exit(1)
	}
}

func loadSongs() (SongSpec, error) {
	var s SongSpec
	err := readJSON(songSpecPath, &s)
	return s, err
}

func loadRenders() *Renders {
	r := &Renders{}
	if readJSON(rendersPath, r) != nil || r.Songs == nil {
		r = &Renders{Songs: map[string]*SongRender{}}
	}
	r.Schema = "cannonball.radio-renders/v1"
	r.About = "Render, pick and master log for art/music/radio-songs.json. Candidate FLACs live in the forge cache (raw/<song>/<seed>.flac) and are identified by sha256; picks are metric-based until a listening pass pins `pick` in the song spec."
	return r
}

func selected(ids []string, id string) bool {
	if len(ids) == 0 {
		return true
	}
	for _, x := range ids {
		if x == id {
			return true
		}
	}
	return false
}

func cmdJobs() error {
	s, err := loadSongs()
	if err != nil {
		return err
	}
	for _, song := range s.Songs {
		b, _ := json.Marshal(map[string]any{"song": song.ID, "workflow": s.Workflow, "count": s.Candidates, "overrides": s.Overrides(song)})
		fmt.Println(string(b))
	}
	return nil
}

func cmdIngest(id, job string) error { return ingestDir(id, job, filepath.Base(job), "") }

func ingestDir(id, job, jobName, workflow string) error {
	s, err := loadSongs()
	if err != nil {
		return err
	}
	var song *Song
	for i := range s.Songs {
		if s.Songs[i].ID == id {
			song = &s.Songs[i]
		}
	}
	if song == nil {
		return fmt.Errorf("unknown song %s", id)
	}
	files, _ := filepath.Glob(filepath.Join(job, "*.flac"))
	sort.Strings(files)
	if len(files) == 0 {
		return fmt.Errorf("no FLAC outputs in %s", job)
	}
	dst := filepath.Join(cache, "raw", id)
	if err := os.MkdirAll(dst, 0o755); err != nil {
		return err
	}
	r := loadRenders()
	if workflow == "" {
		workflow = s.Workflow
	}
	wf, _, _ := fileSHA(filepath.Join(root, workflow))
	rec := &SongRender{Job: jobName, Workflow: workflow, WorkflowSHA: wf, Prompt: s.Prompt(*song), Key: song.Key, BPM: song.BPM, Duration: song.Duration}
	for i, f := range files {
		seed := song.Seed + i
		var prov struct {
			Seed int `json:"seed"`
		}
		// Single-song jobs record the $seed in provenance (seed, seed+1, ...);
		// batch jobs set seeds through node overrides and use slot order.
		if readJSON(f+".provenance.json", &prov) == nil && prov.Seed >= song.Seed && prov.Seed < song.Seed+10 {
			seed = prov.Seed
		}
		b, err := os.ReadFile(f)
		if err != nil {
			return err
		}
		out := filepath.Join(dst, fmt.Sprintf("%d.flac", seed))
		if err := os.WriteFile(out, b, 0o644); err != nil {
			return err
		}
		if p, err := os.ReadFile(f + ".provenance.json"); err == nil {
			os.WriteFile(out+".provenance.json", p, 0o644)
			var prov struct {
				Engine map[string]any `json:"engine"`
				Models []ModelRef     `json:"models"`
			}
			if json.Unmarshal(p, &prov) == nil && len(prov.Models) > 0 {
				r.Models = prov.Models
				r.Engine = map[string]any{"name": prov.Engine["name"], "ref": prov.Engine["ref"], "sha": prov.Engine["sha"]}
			}
		}
		sum, _, _ := fileSHA(out)
		rec.Candidates = append(rec.Candidates, Candidate{Seed: seed, SHA256: sum})
		fmt.Println(id, seed, sum[:12])
	}
	// A later job for the same song (extra seeds) adds candidates.
	if old := r.Songs[id]; old != nil {
		for _, c := range old.Candidates {
			dup := false
			for _, n := range rec.Candidates {
				dup = dup || n.Seed == c.Seed
			}
			if !dup {
				rec.Candidates = append(rec.Candidates, c)
			}
		}
		if old.Job != rec.Job {
			rec.Job = old.Job + "+" + rec.Job
		}
	}
	r.Songs[id] = rec
	return writeJSON(rendersPath, r)
}

func cmdAnalyse(ids []string) error {
	s, err := loadSongs()
	if err != nil {
		return err
	}
	r := loadRenders()
	for _, song := range s.Songs {
		rec := r.Songs[song.ID]
		if rec == nil || !selected(ids, song.ID) {
			continue
		}
		notes := map[int][]string{}
		best, bestScore := -1, math.Inf(1)
		for i := range rec.Candidates {
			c := &rec.Candidates[i]
			path := filepath.Join(cache, "raw", song.ID, fmt.Sprintf("%d.flac", c.Seed))
			if sum, _, err := fileSHA(path); err == nil && sum != c.SHA256 {
				return fmt.Errorf("%s: candidate %d changed since ingest", song.ID, c.Seed)
			} else if err != nil {
				if c.Metrics == nil {
					return fmt.Errorf("%s: candidate %d missing from cache: %w", song.ID, c.Seed, err)
				}
			} else if m, err := Analyse(path); err != nil {
				return err
			} else {
				c.Metrics = m
			}
			c.Score, notes[c.Seed] = Score(c.Metrics, song.Duration)
			c.Score = math.Round(c.Score*1000) / 1000
			if c.Score < bestScore {
				best, bestScore = c.Seed, c.Score
			}
		}
		rec.Pick, rec.Reason = best, PickReason(rec.Candidates, best, notes)
		if song.Pick != nil {
			rec.Pick = *song.Pick
			rec.Reason = fmt.Sprintf("pinned by listening decision in radio-songs.json; metrics: %s", rec.Reason)
		}
		fmt.Printf("%-24s pick %d  %s\n", song.ID, rec.Pick, rec.Reason)
	}
	return writeJSON(rendersPath, r)
}

func cmdMaster(ids []string) error {
	s, err := loadSongs()
	if err != nil {
		return err
	}
	r := loadRenders()
	if err := os.MkdirAll(musicDir, 0o755); err != nil {
		return err
	}
	for _, song := range s.Songs {
		rec := r.Songs[song.ID]
		if rec == nil || rec.Pick == 0 || !selected(ids, song.ID) {
			continue
		}
		var cand *Candidate
		for i := range rec.Candidates {
			if rec.Candidates[i].Seed == rec.Pick {
				cand = &rec.Candidates[i]
			}
		}
		if cand == nil || cand.Metrics == nil {
			return fmt.Errorf("%s: picked seed %d not analysed", song.ID, rec.Pick)
		}
		in := filepath.Join(cache, "raw", song.ID, fmt.Sprintf("%d.flac", rec.Pick))
		out := filepath.Join(musicDir, song.ID+".mp3")
		m := s.Master
		trim := math.Max(0, cand.Metrics.LeadSilence-0.05)
		length := cand.Metrics.Duration - trim - math.Max(0, cand.Metrics.TailSilence-0.1)
		pre := fmt.Sprintf("atrim=start=%.3f:end=%.3f,asetpts=PTS-STARTPTS,afade=t=in:d=%.3f,afade=t=out:st=%.3f:d=%.3f",
			trim, trim+length, m.FadeIn, length-m.FadeOut, m.FadeOut)
		if err := Loudnorm(in, out, pre, m.LUFS, m.TruePeakDB, m.LRA, m.SampleRate, 2, mp3Args(m.Bitrate)); err != nil {
			return err
		}
		enc, err := encoded(out, "music/"+song.ID+".mp3", 2)
		if err != nil {
			return err
		}
		enc.Trim = math.Round(trim*1000) / 1000
		rec.Master = enc
		fmt.Printf("%-24s %.1fs %.2f LUFS %.2f dBTP %d KB\n", song.ID, enc.Duration, enc.LUFS, enc.TruePeak, enc.Bytes/1024)
	}
	return writeJSON(rendersPath, r)
}

func encoded(path, src string, channels int) (*Encoded, error) {
	sum, size, err := fileSHA(path)
	if err != nil {
		return nil, err
	}
	l, err := Measure(path)
	if err != nil {
		return nil, err
	}
	pcm, err := Decode(path, analysisRate, channels)
	if err != nil {
		return nil, err
	}
	d := float64(len(pcm)/channels) / analysisRate
	return &Encoded{Src: src, Bytes: size, SHA256: sum, Duration: math.Round(d*1000) / 1000, LUFS: l.I, TruePeak: l.TruePeak}, nil
}

// Radio-band presenter chain: telephone-ish band, presence lift, firm
// compression, soft saturation and short pre/post roll for buzz cuts.
const voiceChain = "aresample=48000,adelay=80,apad=pad_dur=0.18,highpass=f=210:p=2,lowpass=f=5200:p=2," +
	"equalizer=f=1900:t=q:w=1.1:g=3.5,acompressor=threshold=-24dB:ratio=5:attack=4:release=90:makeup=7dB," +
	"asoftclip=type=tanh:output=0.95"

type VoiceOut struct {
	Line
	Src      string  `json:"src"`
	Duration float64 `json:"duration"`
	SHA256   string  `json:"sha256"`
	Bytes    int64   `json:"bytes"`
	LUFS     float64 `json:"lufs"`
	TruePeak float64 `json:"true_peak_db"`
	Raw      string  `json:"raw"`
}

func cmdVoices() error {
	var spec LineSpec
	if err := readJSON(lineSpecPath, &spec); err != nil {
		return err
	}
	var outs []VoiceOut
	for _, line := range spec.Lines {
		raws, _ := filepath.Glob(filepath.Join(cache, "voice-raw", line.ID+"-*.wav"))
		if len(raws) == 0 {
			return fmt.Errorf("%s: no Kokoro render; run tool/audio/interjections.py", line.ID)
		}
		raw := newest(raws)
		out := filepath.Join(musicDir, "dj-"+line.ID+".mp3")
		if err := Loudnorm(raw, out, voiceChain, -16, -1.5, 7, 48000, 1, mp3Args(96)); err != nil {
			return err
		}
		enc, err := encoded(out, "music/dj-"+line.ID+".mp3", 1)
		if err != nil {
			return err
		}
		outs = append(outs, VoiceOut{Line: line, Src: enc.Src, Duration: enc.Duration, SHA256: enc.SHA256, Bytes: enc.Bytes, LUFS: enc.LUFS, TruePeak: enc.TruePeak, Raw: filepath.Base(raw)})
		fmt.Printf("%-20s %.2fs %.1f LUFS %.1f dBTP\n", line.ID, enc.Duration, enc.LUFS, enc.TruePeak)
	}
	return writeJSON(filepath.Join(cache, "voices.json"), outs)
}

func newest(paths []string) string {
	sort.Slice(paths, func(i, j int) bool {
		a, _ := os.Stat(paths[i])
		b, _ := os.Stat(paths[j])
		return a.ModTime().After(b.ModTime())
	})
	return paths[0]
}

type BuzzOut struct {
	BuzzSpec
	Src       string   `json:"src"`
	Duration  float64  `json:"duration"`
	SHA256    string   `json:"sha256"`
	Bytes     int64    `json:"bytes"`
	LUFS      float64  `json:"lufs"`
	TruePeak  float64  `json:"true_peak_db"`
	Fragments []string `json:"fragment_sources"`
}

func cmdBuzz() error {
	s, err := loadSongs()
	if err != nil {
		return err
	}
	// Passing-station fragments come from our own mastered songs (one per
	// station where available), so the dial only ever passes Cannonball audio.
	var frags []Fragment
	var names []string
	seen := map[string]bool{}
	for _, song := range s.Songs {
		p := filepath.Join(musicDir, song.ID+".mp3")
		if seen[song.Station] {
			continue
		}
		if _, err := os.Stat(p); err != nil {
			continue
		}
		pcm, err := Decode(p, 48000, 1)
		if err != nil {
			return err
		}
		if len(pcm) > 48000*40 {
			frags = append(frags, Fragment(pcm[48000*25:48000*40]))
			names = append(names, song.ID)
			seen[song.Station] = true
		}
	}
	tmp := filepath.Join(cache, "buzz")
	os.MkdirAll(tmp, 0o755)
	var outs []BuzzOut
	for _, b := range buzzBank {
		pcm := SynthBuzz(b, 48000, frags)
		wav := filepath.Join(tmp, b.ID+".wav")
		if err := WriteWAV(wav, pcm, 48000, 2); err != nil {
			return err
		}
		out := filepath.Join(musicDir, b.ID+".mp3")
		if err := Loudnorm(wav, out, "", -18, -2, 7, 48000, 2, mp3Args(160)); err != nil {
			return err
		}
		enc, err := encoded(out, "music/"+b.ID+".mp3", 2)
		if err != nil {
			return err
		}
		outs = append(outs, BuzzOut{BuzzSpec: b, Src: enc.Src, Duration: enc.Duration, SHA256: enc.SHA256, Bytes: enc.Bytes, LUFS: enc.LUFS, TruePeak: enc.TruePeak, Fragments: names})
		fmt.Printf("%-8s %.2fs %.1f LUFS %.1f dBTP\n", b.ID, enc.Duration, enc.LUFS, enc.TruePeak)
	}
	return writeJSON(filepath.Join(cache, "buzz.json"), outs)
}

func cmdCatalog() error {
	s, err := loadSongs()
	if err != nil {
		return err
	}
	r := loadRenders()
	var voices []VoiceOut
	var buzz []BuzzOut
	if err := readJSON(filepath.Join(cache, "voices.json"), &voices); err != nil {
		return fmt.Errorf("run voices first: %w", err)
	}
	if err := readJSON(filepath.Join(cache, "buzz.json"), &buzz); err != nil {
		return fmt.Errorf("run buzz first: %w", err)
	}
	var songs []map[string]any
	for _, song := range s.Songs {
		rec := r.Songs[song.ID]
		if rec == nil || rec.Master == nil {
			continue
		}
		songs = append(songs, map[string]any{"id": song.ID, "title": song.Title, "genre": song.Genre, "station": song.Station,
			"bpm": song.BPM, "key": song.Key, "mood": song.Mood, "src": rec.Master.Src, "duration": rec.Master.Duration,
			"lufs": rec.Master.LUFS, "seed": rec.Pick})
	}
	var lines []map[string]any
	for _, v := range voices {
		caption := v.Caption
		if caption == "" {
			caption = v.Text
		}
		lines = append(lines, map[string]any{"id": v.ID, "station": v.Station, "kind": v.Kind, "text": v.Text, "caption": caption,
			"lang": v.Lang, "voice": v.Voice, "src": v.Src, "duration": v.Duration})
	}
	var buzzes []map[string]any
	for _, b := range buzz {
		buzzes = append(buzzes, map[string]any{"id": b.ID, "src": b.Src, "duration": b.Duration})
	}
	var stations []map[string]any
	for _, st := range s.Stations {
		stations = append(stations, map[string]any{"id": st.ID, "name": st.Name, "frequency": st.Frequency, "genres": st.Genres, "regions": st.Regions})
	}
	programme := map[string]any{
		"version": 1, "about": "Wordless ACE-Step radio songs joined by hard radio cuts: song -> buzz -> interjection -> buzz -> another song. See art/music/README.md.",
		"rules":    map[string]any{"recentSongs": 10, "recentLines": 8, "stayOnStation": 0.55, "identEvery": 2},
		"stations": stations, "songs": songs, "buzz": buzzes, "interjections": lines,
	}
	var cat map[string]json.RawMessage
	if err := readJSON(catalogPath, &cat); err != nil {
		return err
	}
	b, _ := json.Marshal(programme)
	cat["programme"] = b
	if err := writeJSON(catalogPath, orderedCatalog(cat)); err != nil {
		return err
	}
	fmt.Printf("catalog: %d stations, %d songs, %d buzz, %d interjections\n", len(stations), len(songs), len(buzzes), len(lines))
	return nil
}

// orderedCatalog keeps the historical keys first for readable diffs.
type orderedCatalog map[string]json.RawMessage

func (o orderedCatalog) MarshalJSON() ([]byte, error) {
	order := []string{"version", "tracks", "radio", "surf", "programme"}
	var keys []string
	keys = append(keys, order...)
	var extra []string
	for k := range o {
		if !contains(order, k) {
			extra = append(extra, k)
		}
	}
	sort.Strings(extra)
	keys = append(keys, extra...)
	var parts []string
	for _, k := range keys {
		v, ok := o[k]
		if !ok {
			continue
		}
		kb, _ := json.Marshal(k)
		parts = append(parts, string(kb)+":"+string(v))
	}
	return []byte("{" + strings.Join(parts, ",") + "}"), nil
}

func contains(xs []string, x string) bool {
	for _, y := range xs {
		if y == x {
			return true
		}
	}
	return false
}
