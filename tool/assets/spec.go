package main

import (
	"encoding/json"
	"fmt"
	"hash/fnv"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

// Derive generates an item by editing another item's pick.
type Derive struct {
	From     string `json:"from"`
	Workflow string `json:"workflow,omitempty"`
	Prompt   string `json:"prompt,omitempty"`
}

// Item is one sprite or texture in a family spec (art/families/README.md).
type Item struct {
	ID            string    `json:"id"`
	Prompt        string    `json:"prompt,omitempty"`
	Seed          *int64    `json:"seed,omitempty"`
	Band          string    `json:"band,omitempty"`
	Kind          string    `json:"kind"`
	WorldWidthM   float64   `json:"worldWidthM,omitempty"`
	Biomes        []string  `json:"biomes,omitempty"`
	Tags          []string  `json:"tags,omitempty"`
	HeightPx      int       `json:"heightPx,omitempty"`
	Frames        []string  `json:"frames,omitempty"`
	Derive        *Derive   `json:"derive,omitempty"`
	Sway          float64   `json:"sway,omitempty"`
	Collides      bool      `json:"collides,omitempty"`
	NightEmissive any       `json:"nightEmissive,omitempty"`
	TileX         bool      `json:"tileX,omitempty"`
	AnchorX       *float64  `json:"anchorX,omitempty"`
	TileM         []float64 `json:"tileM,omitempty"`
	SizePx        int       `json:"sizePx,omitempty"`
	Canvas        []int     `json:"canvas,omitempty"`
	File          string    `json:"file,omitempty"`   // source under art/sources/ (default <family>/<id>.png)
	Anchor        []float64 `json:"anchor,omitempty"` // ground contact in source pixels (default: detected)
}

func sourcePath(root string, f *Family, it *Item) string {
	if it.File != "" {
		return filepath.Join(root, "art/sources", it.File)
	}
	return filepath.Join(root, "art/sources", f.Family, it.ID+".png")
}

// Family is art/families/<family>.json.
type Family struct {
	Family      string `json:"family"`
	Type        string `json:"type"`
	Atlas       string `json:"atlas,omitempty"`
	Workflow    string `json:"workflow,omitempty"`
	Style       string `json:"style,omitempty"`
	Negative    string `json:"negative,omitempty"`
	Candidates  int    `json:"candidates,omitempty"`
	Canvas      []int  `json:"canvas,omitempty"`
	Key         []int  `json:"key,omitempty"`
	SourceMax   int    `json:"sourceMax,omitempty"`
	ColorLevels int    `json:"colorLevels,omitempty"`
	Matte       string `json:"matte,omitempty"` // "birefnet" (default: the workflow matte) or "skyline" (key cut for horizon strips)
	Items       []Item `json:"items"`
}

func (f *Family) candidates() int {
	if f.Candidates > 0 {
		return f.Candidates
	}
	return 3
}

func (f *Family) key() [3]float64 {
	if len(f.Key) == 3 {
		return [3]float64{float64(f.Key[0]), float64(f.Key[1]), float64(f.Key[2])}
	}
	return [3]float64{255, 255, 255}
}

func (f *Family) sourceMax(it *Item) int {
	if f.SourceMax > 0 {
		return f.SourceMax
	}
	if f.Type == "texture" {
		return 512
	}
	if it.Band == "vista" || it.Band == "far" {
		return 1536
	}
	return 512
}

func (it *Item) seed() int64 {
	if it.Seed != nil {
		return *it.Seed
	}
	h := fnv.New32a()
	h.Write([]byte(it.ID))
	return int64(h.Sum32()%900000)*10 + 1000
}

func (f *Family) prompt(it *Item) string {
	p := strings.TrimSpace(it.Prompt)
	if it.Derive != nil && it.Derive.Prompt != "" {
		return it.Derive.Prompt
	}
	if f.Style != "" {
		p = p + ", " + f.Style
	}
	return p
}

var validBands = map[string]bool{"near": true, "mid": true, "far": true, "vista": true}
var validKinds = map[string]bool{"tree": true, "shrub": true, "grass": true, "crop": true, "structure": true, "animal": true, "furniture": true, "sign": true, "vista": true}
var validTexKinds = map[string]bool{"road": true, "shoulder": true, "sidewalk": true, "ground": true, "bridge-deck": true}
var validBiomes = map[string]bool{"farm": true, "forest": true, "town": true, "city": true, "river": true, "plains": true, "desert": true}

func loadFamilies(root string) ([]*Family, error) {
	paths, _ := filepath.Glob(filepath.Join(root, "art/families/*.json"))
	sort.Strings(paths)
	var fams []*Family
	ids := map[string]string{}
	for _, p := range paths {
		if strings.HasSuffix(p, "-runs.json") {
			continue
		}
		b, err := os.ReadFile(p)
		if err != nil {
			return nil, err
		}
		var probe map[string]any
		if err := json.Unmarshal(b, &probe); err != nil {
			return nil, fmt.Errorf("%s: %v", p, err)
		}
		t, _ := probe["type"].(string)
		if _, hasItems := probe["items"]; t == "" && hasItems && probe["family"] != nil {
			t = "sprite" // externally made picks (e.g. Blender structures) may omit type
		}
		if t != "sprite" && t != "texture" {
			// not a family spec (e.g. art/families/structures-rigs.json, owned by the rig tools)
			continue
		}
		var f Family
		if err := json.Unmarshal(b, &f); err != nil {
			return nil, fmt.Errorf("%s: %v", p, err)
		}
		f.Type = t
		stem := strings.TrimSuffix(filepath.Base(p), ".json")
		if f.Family != stem {
			continue // side files such as <family>-rigs.json
		}
		for i := range f.Items {
			it := &f.Items[i]
			if prev, ok := ids[it.ID]; ok {
				return nil, fmt.Errorf("%s: duplicate id %s (also in %s)", p, it.ID, prev)
			}
			ids[it.ID] = f.Family
			if err := validate(&f, it); err != nil {
				return nil, fmt.Errorf("%s: %s: %v", p, it.ID, err)
			}
		}
		fams = append(fams, &f)
	}
	return fams, nil
}

func validate(f *Family, it *Item) error {
	if it.ID == "" || strings.ToLower(it.ID) != it.ID || strings.ContainsAny(it.ID, " /_") {
		return fmt.Errorf("id must be kebab-case")
	}
	switch f.Type {
	case "sprite":
		if !validBands[it.Band] {
			return fmt.Errorf("bad band %q", it.Band)
		}
		if !validKinds[it.Kind] {
			return fmt.Errorf("bad kind %q", it.Kind)
		}
		if it.WorldWidthM <= 0 {
			return fmt.Errorf("worldWidthM required")
		}
		if it.Biomes == nil {
			return fmt.Errorf("biomes required (use [] for every biome)")
		}
		for _, b := range it.Biomes {
			if !validBiomes[b] {
				return fmt.Errorf("bad biome %q", b)
			}
		}
	case "texture":
		if !validTexKinds[it.Kind] {
			return fmt.Errorf("bad texture kind %q", it.Kind)
		}
		if len(it.TileM) != 2 {
			return fmt.Errorf("tileM [x,y] required")
		}
	default:
		return fmt.Errorf("family type must be sprite or texture")
	}
	return nil
}

func findItem(fams []*Family, id string) (*Family, *Item) {
	for _, f := range fams {
		for i := range f.Items {
			if f.Items[i].ID == id {
				return f, &f.Items[i]
			}
		}
	}
	return nil, nil
}

func selectFamilies(fams []*Family, name string) []*Family {
	if name == "" || name == "all" {
		return fams
	}
	var out []*Family
	for _, f := range fams {
		if f.Family == name {
			out = append(out, f)
		}
	}
	return out
}

// Ledger: art/families/<family>-runs.json keyed "<id>/<seed>".
type Run struct {
	Workflow     string   `json:"workflow"`
	Models       []string `json:"models"`
	Prompt       string   `json:"prompt"`
	Negative     string   `json:"negative,omitempty"`
	Seed         int64    `json:"seed"`
	StudioJob    string   `json:"studio_job,omitempty"`
	DerivedFrom  string   `json:"derived_from,omitempty"`
	Raw          string   `json:"raw"`
	SHA256       string   `json:"sha256"`
	MatteSHA256  string   `json:"matte_sha256,omitempty"`
	Selected     bool     `json:"selected"`
	PickReason   string   `json:"pick_reason,omitempty"`
	SourceSHA256 string   `json:"source_sha256,omitempty"`
	Source       string   `json:"source,omitempty"`
}

func ledgerPath(root, fam string) string {
	return filepath.Join(root, "art/families", fam+"-runs.json")
}

func loadLedger(root, fam string) map[string]*Run {
	m := map[string]*Run{}
	b, err := os.ReadFile(ledgerPath(root, fam))
	if err == nil {
		if err := json.Unmarshal(b, &m); err != nil {
			fatalf("ledger %s: %v", fam, err)
		}
	}
	return m
}

func saveLedger(root, fam string, m map[string]*Run) {
	writeJSON(ledgerPath(root, fam), m)
}

func writeJSON(path string, v any) {
	b, err := json.MarshalIndent(v, "", "  ")
	if err != nil {
		fatalf("json: %v", err)
	}
	b = append(b, '\n')
	os.MkdirAll(filepath.Dir(path), 0o755)
	if err := os.WriteFile(path, b, 0o644); err != nil {
		fatalf("write %s: %v", path, err)
	}
}

func readJSON(path string, v any) error {
	b, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	return json.Unmarshal(b, v)
}
