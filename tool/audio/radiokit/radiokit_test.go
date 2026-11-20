package main

import (
	"encoding/json"
	"math"
	"strings"
	"testing"
)

func rmsOf(x []float32) float64 {
	var e float64
	for _, v := range x {
		e += float64(v) * float64(v)
	}
	return math.Sqrt(e / float64(len(x)))
}

func TestBuzzIsDeterministicAndMasksAHardCut(t *testing.T) {
	frag := make(Fragment, 48000*2)
	for i := range frag {
		frag[i] = float32(0.5 * math.Sin(2*math.Pi*440*float64(i)/48000))
	}
	for _, spec := range buzzBank {
		a := SynthBuzz(spec, 48000, []Fragment{frag})
		b := SynthBuzz(spec, 48000, []Fragment{frag})
		if len(a) != 2*int(spec.Seconds*48000) {
			t.Fatalf("%s: %d samples", spec.ID, len(a))
		}
		for i := range a {
			if a[i] != b[i] {
				t.Fatalf("%s not deterministic at %d", spec.ID, i)
			}
			if math.IsNaN(float64(a[i])) || math.Abs(float64(a[i])) > 1 {
				t.Fatalf("%s: sample %d = %v", spec.ID, i, a[i])
			}
		}
		head := rmsOf(a[:2*480])      // first 10 ms
		end := rmsOf(a[len(a)-2*96:]) // last 2 ms
		if dbfs(head) < -30 {
			t.Errorf("%s starts too quietly to mask a cut: %.1f dBFS", spec.ID, dbfs(head))
		}
		if end > head/4 {
			t.Errorf("%s does not fade before the next cut", spec.ID)
		}
	}
}

func TestAnalyseFindsSilenceDropoutsAndClipping(t *testing.T) {
	rate := 48000
	n := rate * 20
	pcm := make([]float32, 2*n)
	for i := 0; i < n; i++ {
		v := float32(0.3 * math.Sin(2*math.Pi*220*float64(i)/float64(rate)))
		sec := float64(i) / float64(rate)
		switch {
		case sec < 1: // lead silence
			v = 0
		case sec >= 9 && sec < 11: // 2 s dropout
			v = 0
		case sec >= 15 && sec < 15.001:
			v = 1
		}
		pcm[2*i], pcm[2*i+1] = v, v
	}
	m := analysePCM(pcm, rate)
	if math.Abs(m.LeadSilence-1) > 0.06 {
		t.Errorf("lead silence %.2f", m.LeadSilence)
	}
	if math.Abs(m.MaxDropout-2) > 0.11 {
		t.Errorf("dropout %.2f", m.MaxDropout)
	}
	if m.ClippedRuns < 1 {
		t.Errorf("clip not found")
	}
	clean, _ := Score(&Metrics{Duration: 90, LRA: 5}, 90)
	broken, notes := Score(m, 90)
	if !(clean < broken) || len(notes) == 0 {
		t.Errorf("score ordering %.2f vs %.2f %v", clean, broken, notes)
	}
}

func TestParseLoudnessSummary(t *testing.T) {
	log := `[Parsed_ebur128_0 @ 0x1] Summary:

  Integrated loudness:
    I:         -16.1 LUFS
    Threshold: -26.4 LUFS

  Loudness range:
    LRA:         5.2 LU

  True peak:
    Peak:       -2.3 dBFS`
	l, err := parseLoudness(log)
	if err != nil || l.I != -16.1 || l.LRA != 5.2 || l.TruePeak != -2.3 {
		t.Fatalf("%+v %v", l, err)
	}
	if _, err := parseLoudness("nothing"); err == nil {
		t.Fatal("expected an error")
	}
}

func TestCatalogKeepsLegacyKeysFirst(t *testing.T) {
	cat := orderedCatalog{"programme": json.RawMessage(`{}`), "tracks": json.RawMessage(`[]`), "version": json.RawMessage(`1`), "zz": json.RawMessage(`0`)}
	b, _ := json.Marshal(cat)
	s := string(b)
	if !(strings.Index(s, "version") < strings.Index(s, "tracks") && strings.Index(s, "tracks") < strings.Index(s, "programme") && strings.Index(s, "programme") < strings.Index(s, "zz")) {
		t.Fatal(s)
	}
}

func TestOverridesReachTheCommittedWorkflowNodes(t *testing.T) {
	s := SongSpec{CommonTags: "instrumental, no vocals"}
	o := s.Overrides(Song{Seed: 9, BPM: 120, Key: "C major", Duration: 90, Tags: "pop", Mood: "sunny"})
	for _, k := range []string{"seed", "$node:5.tags", "$node:5.bpm", "$node:5.keyscale", "$node:5.duration", "$node:7.seconds"} {
		if _, ok := o[k]; !ok {
			t.Fatalf("missing %s", k)
		}
	}
	if !strings.HasPrefix(o["$node:5.tags"].(string), "instrumental, no vocals") {
		t.Fatal(o["$node:5.tags"])
	}
}
