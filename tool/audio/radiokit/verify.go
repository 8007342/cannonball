package main

import (
	"encoding/json"
	"fmt"
	"math"
	"os"
	"path/filepath"
	"strings"
)

// Targets checked on the decoded, encoded deliverables (not the masters).
type target struct {
	minLUFS, maxLUFS, maxTP float64
	minDur, maxDur          float64
	channels                int
	minKbps, maxKbps        float64
}

var targets = map[string]target{
	"song":         {-17, -15, -1.0, 60, 120, 2, 176, 208},
	"interjection": {-17.5, -14.5, -1.0, 1.2, 8, 1, 80, 112},
	"buzz":         {-21, -15, -1.0, 0.5, 2, 2, 120, 200},
}

const budgetBytes = 120 << 20

type Check struct {
	Kind     string   `json:"kind"`
	Src      string   `json:"src"`
	Bytes    int64    `json:"bytes"`
	SHA256   string   `json:"sha256"`
	Duration float64  `json:"duration"`
	Kbps     float64  `json:"kbps"`
	LUFS     float64  `json:"lufs"`
	TruePeak float64  `json:"true_peak_db"`
	Rate     int      `json:"sample_rate"`
	Channels int      `json:"channels"`
	Problems []string `json:"problems,omitempty"`
}

type programmeJSON struct {
	Stations []struct {
		ID      string   `json:"id"`
		Regions []string `json:"regions"`
	} `json:"stations"`
	Songs []struct {
		ID, Src, Station, Genre string
		Duration                float64
	} `json:"songs"`
	Buzz []struct {
		ID, Src string
	} `json:"buzz"`
	Interjections []struct {
		ID, Src, Station, Kind, Text, Caption string
	} `json:"interjections"`
}

func checkFile(kind, src string) Check {
	c := Check{Kind: kind, Src: src}
	t := targets[kind]
	path := filepath.Join(root, "assets/audio", src)
	bad := func(f string, a ...any) { c.Problems = append(c.Problems, fmt.Sprintf(f, a...)) }
	var err error
	if c.SHA256, c.Bytes, err = fileSHA(path); err != nil {
		bad("missing: %v", err)
		return c
	}
	codec, rate, ch, err := Probe(path)
	if err != nil {
		bad("probe: %v", err)
		return c
	}
	c.Rate, c.Channels = rate, ch
	if codec != "mp3" && codec != "mp3float" {
		bad("codec %s, want mp3", codec)
	}
	if rate != 48000 && rate != 44100 {
		bad("sample rate %d", rate)
	}
	if ch != t.channels {
		bad("channels %d, want %d", ch, t.channels)
	}
	pcm, err := Decode(path, 48000, ch)
	if err != nil {
		bad("decode: %v", err)
		return c
	}
	for _, x := range pcm {
		if math.IsNaN(float64(x)) || math.IsInf(float64(x), 0) {
			bad("non-finite samples")
			break
		}
	}
	c.Duration = math.Round(float64(len(pcm)/ch)/48000*1000) / 1000
	c.Kbps = math.Round(float64(c.Bytes)*8/c.Duration/100) / 10
	l, err := Measure(path)
	if err != nil {
		bad("loudness: %v", err)
		return c
	}
	c.LUFS, c.TruePeak = l.I, l.TruePeak
	if l.I < t.minLUFS || l.I > t.maxLUFS {
		bad("loudness %.2f LUFS outside [%.1f, %.1f]", l.I, t.minLUFS, t.maxLUFS)
	}
	if l.TruePeak > t.maxTP {
		bad("true peak %.2f dBTP above %.1f", l.TruePeak, t.maxTP)
	}
	if c.Duration < t.minDur || c.Duration > t.maxDur {
		bad("duration %.2fs outside [%.1f, %.1f]", c.Duration, t.minDur, t.maxDur)
	}
	if c.Kbps < t.minKbps || c.Kbps > t.maxKbps {
		bad("bitrate %.1f kbps outside [%.0f, %.0f]", c.Kbps, t.minKbps, t.maxKbps)
	}
	return c
}

func cmdVerify() error {
	var cat struct {
		Programme *programmeJSON `json:"programme"`
	}
	if err := readJSON(catalogPath, &cat); err != nil {
		return err
	}
	p := cat.Programme
	if p == nil {
		return fmt.Errorf("catalog has no programme")
	}
	var checks []Check
	var problems []string
	stations := map[string]bool{}
	for _, st := range p.Stations {
		stations[st.ID] = true
	}
	perStation := map[string]int{}
	perGenre := map[string]int{}
	linesPer := map[string]int{}
	for _, s := range p.Songs {
		if !stations[s.Station] {
			problems = append(problems, s.ID+": unknown station "+s.Station)
		}
		perStation[s.Station]++
		perGenre[s.Genre]++
		checks = append(checks, checkFile("song", s.Src))
	}
	for _, b := range p.Buzz {
		checks = append(checks, checkFile("buzz", b.Src))
	}
	for _, l := range p.Interjections {
		if l.Station != "*" && !stations[l.Station] {
			problems = append(problems, l.ID+": unknown station "+l.Station)
		}
		if strings.TrimSpace(l.Caption) == "" {
			problems = append(problems, l.ID+": no caption")
		}
		linesPer[l.Station]++
		checks = append(checks, checkFile("interjection", l.Src))
	}
	for id := range stations {
		if perStation[id] < 2 {
			problems = append(problems, fmt.Sprintf("station %s has %d songs (need 2 to avoid repeats)", id, perStation[id]))
		}
		if linesPer[id] < 2 {
			problems = append(problems, fmt.Sprintf("station %s has %d interjections", id, linesPer[id]))
		}
	}
	if len(p.Buzz) < 2 {
		problems = append(problems, "need at least two buzz clips")
	}
	for _, c := range checks {
		for _, pr := range c.Problems {
			problems = append(problems, c.Src+": "+pr)
		}
		fmt.Printf("%-40s %6.2fs %6.1f kbps %6.2f LUFS %6.2f dBTP %s\n", c.Src, c.Duration, c.Kbps, c.LUFS, c.TruePeak, strings.Join(c.Problems, "; "))
	}
	// Whole audio tree against the committed-audio budget.
	var total int64
	filepath.Walk(filepath.Join(root, "assets/audio"), func(path string, info os.FileInfo, err error) error {
		if err == nil && !info.IsDir() {
			total += info.Size()
		}
		return nil
	})
	if total > budgetBytes {
		problems = append(problems, fmt.Sprintf("assets/audio is %d bytes, budget %d", total, budgetBytes))
	}
	report := map[string]any{
		"schema": "cannonball.radio-verification/v1", "tool": "tool/audio/radiokit verify",
		"targets":       map[string]any{"song": "-16 LUFS ±1, <= -1.0 dBTP, 60-120 s, stereo MP3 192 kbps", "interjection": "-16 LUFS ±1.5, <= -1.0 dBTP, mono MP3 96 kbps", "buzz": "-18 LUFS ±3, <= -1.0 dBTP, stereo MP3 160 kbps"},
		"songsPerGenre": perGenre, "songsPerStation": perStation, "audioTreeBytes": total, "budgetBytes": budgetBytes,
		"ok": len(problems) == 0, "problems": problems, "files": checks,
	}
	b, _ := json.MarshalIndent(report, "", "  ")
	if err := os.WriteFile(verifyPath, append(b, '\n'), 0o644); err != nil {
		return err
	}
	fmt.Printf("audio tree %.1f MB of %.0f MB; %d files checked; %d problems\n", float64(total)/1e6, float64(budgetBytes)/1e6, len(checks), len(problems))
	if len(problems) > 0 {
		return fmt.Errorf("verification failed:\n  %s", strings.Join(problems, "\n  "))
	}
	return nil
}
