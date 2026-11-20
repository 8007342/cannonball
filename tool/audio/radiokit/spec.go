package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
)

// SongSpec mirrors art/music/radio-songs.json.
type SongSpec struct {
	Schema     string    `json:"schema"`
	Workflow   string    `json:"workflow"`
	Models     []string  `json:"models"`
	CommonTags string    `json:"common_tags"`
	Lyrics     string    `json:"lyrics"`
	Candidates int       `json:"candidates"`
	Master     Master    `json:"master"`
	Stations   []Station `json:"stations"`
	Songs      []Song    `json:"songs"`
}

type Master struct {
	LUFS       float64 `json:"lufs"`
	TruePeakDB float64 `json:"true_peak_db"`
	LRA        float64 `json:"lra"`
	Bitrate    int     `json:"bitrate_kbps"`
	SampleRate int     `json:"sample_rate"`
	FadeIn     float64 `json:"fade_in_s"`
	FadeOut    float64 `json:"fade_out_s"`
}

type Station struct {
	ID        string   `json:"id"`
	Name      string   `json:"name"`
	Frequency string   `json:"frequency"`
	Genres    []string `json:"genres"`
	Regions   []string `json:"regions"`
	Voice     string   `json:"voice"`
}

type Song struct {
	ID       string  `json:"id"`
	Title    string  `json:"title"`
	Genre    string  `json:"genre"`
	Station  string  `json:"station"`
	BPM      int     `json:"bpm"`
	Key      string  `json:"key"`
	Duration float64 `json:"duration"`
	Seed     int     `json:"seed"`
	Mood     string  `json:"mood"`
	Tags     string  `json:"tags"`
	Pick     *int    `json:"pick,omitempty"` // a listening decision overrides the metric pick
}

// Prompt is the exact text sent to the ACE-Step text encoder.
func (s SongSpec) Prompt(song Song) string {
	return fmt.Sprintf("%s, %s, %s, %d bpm", s.CommonTags, song.Tags, song.Mood, song.BPM)
}

// Overrides is the studio.run_workflow `overrides` object for one song.
func (s SongSpec) Overrides(song Song) map[string]any {
	return map[string]any{
		"seed":             song.Seed,
		"$node:5.tags":     s.Prompt(song),
		"$node:5.bpm":      song.BPM,
		"$node:5.keyscale": song.Key,
		"$node:5.duration": song.Duration,
		"$node:7.seconds":  song.Duration,
	}
}

type LineSpec struct {
	Model string  `json:"model"`
	Speed float64 `json:"speed"`
	Lines []Line  `json:"lines"`
}

type Line struct {
	ID      string `json:"id"`
	Station string `json:"station"`
	Kind    string `json:"kind"`
	Voice   string `json:"voice"`
	Lang    string `json:"lang"`
	Text    string `json:"text"`
	Caption string `json:"caption,omitempty"`
}

type ModelRef struct {
	File     string `json:"file"`
	Repo     string `json:"repo"`
	Revision string `json:"revision"`
	SHA256   string `json:"sha256"`
	Licence  string `json:"licence"`
}

// Renders is the committed render/pick log, art/music/radio-renders.json.
type Renders struct {
	Schema string                 `json:"schema"`
	About  string                 `json:"about"`
	Models []ModelRef             `json:"models,omitempty"`
	Engine map[string]any         `json:"engine,omitempty"`
	Songs  map[string]*SongRender `json:"songs"`
}

type SongRender struct {
	Job         string      `json:"job"`
	Workflow    string      `json:"workflow"`
	WorkflowSHA string      `json:"workflow_sha256,omitempty"`
	Prompt      string      `json:"prompt"`
	Key         string      `json:"key"`
	BPM         int         `json:"bpm"`
	Duration    float64     `json:"duration"`
	Candidates  []Candidate `json:"candidates"`
	Pick        int         `json:"pick"`
	Reason      string      `json:"reason"`
	Master      *Encoded    `json:"master,omitempty"`
}

type Candidate struct {
	Seed    int      `json:"seed"`
	SHA256  string   `json:"sha256"`
	Metrics *Metrics `json:"metrics,omitempty"`
	Score   float64  `json:"score"`
}

type Encoded struct {
	Src      string  `json:"src"`
	Bytes    int64   `json:"bytes"`
	SHA256   string  `json:"sha256"`
	Duration float64 `json:"duration"`
	LUFS     float64 `json:"lufs"`
	TruePeak float64 `json:"true_peak_db"`
	Trim     float64 `json:"lead_trim_s,omitempty"`
}

func readJSON(path string, v any) error {
	b, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	if err := json.Unmarshal(b, v); err != nil {
		return fmt.Errorf("%s: %w", path, err)
	}
	return nil
}

func writeJSON(path string, v any) error {
	b, err := json.MarshalIndent(v, "", "  ")
	if err != nil {
		return err
	}
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	return os.WriteFile(path, append(b, '\n'), 0o644)
}
