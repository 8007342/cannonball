package main

import (
	"fmt"
	"math"
	"sort"
	"strings"
)

// Metrics are numeric listening proxies. They catch broken takes (silence,
// dropouts, heavy clipping, collapsed dynamics); they do not replace listening.
type Metrics struct {
	Duration    float64 `json:"duration"`
	LUFS        float64 `json:"lufs"`
	LRA         float64 `json:"lra"`
	TruePeak    float64 `json:"true_peak_db"`
	ClippedRuns int     `json:"clipped_runs"`
	LeadSilence float64 `json:"lead_silence_s"`
	TailSilence float64 `json:"tail_silence_s"`
	MaxDropout  float64 `json:"max_dropout_s"`
	EnergyCV    float64 `json:"energy_cv"`
	QuietShare  float64 `json:"quiet_share"`
	StereoWidth float64 `json:"stereo_width"`
	Brightness  float64 `json:"brightness"`
}

const analysisRate = 48000

// Analyse decodes a stereo file and computes Metrics.
func Analyse(path string) (*Metrics, error) {
	pcm, err := Decode(path, analysisRate, 2)
	if err != nil {
		return nil, err
	}
	m := analysePCM(pcm, analysisRate)
	l, err := Measure(path)
	if err != nil {
		return nil, err
	}
	m.LUFS, m.LRA, m.TruePeak = l.I, l.LRA, l.TruePeak
	r3 := func(x *float64) { *x = math.Round(*x*1000) / 1000 }
	for _, x := range []*float64{&m.Duration, &m.LeadSilence, &m.TailSilence, &m.MaxDropout, &m.EnergyCV, &m.QuietShare, &m.StereoWidth, &m.Brightness} {
		r3(x)
	}
	return m, nil
}

func dbfs(x float64) float64 {
	if x <= 1e-12 {
		return -240
	}
	return 20 * math.Log10(x)
}

func analysePCM(pcm []float32, rate int) *Metrics {
	frames := len(pcm) / 2
	m := &Metrics{Duration: float64(frames) / float64(rate)}
	// A clipped run is >= 3 consecutive samples at digital full scale.
	run := 0
	for i := 0; i < len(pcm); i++ {
		if math.Abs(float64(pcm[i])) >= 0.9999 {
			run++
			if run == 3 {
				m.ClippedRuns++
			}
		} else {
			run = 0
		}
	}
	win := rate / 20 // 50 ms windows
	var rms []float64
	var side, mid, hi, all float64
	prev := 0.0
	for w := 0; w+win <= frames; w += win {
		var e float64
		for i := w; i < w+win; i++ {
			l, r := float64(pcm[2*i]), float64(pcm[2*i+1])
			e += (l*l + r*r) / 2
			s, md := (l-r)/2, (l+r)/2
			side += s * s
			mid += md * md
			d := md - prev // first difference: crude high-frequency share
			prev = md
			hi += d * d
			all += md * md
		}
		rms = append(rms, math.Sqrt(e/float64(win)))
	}
	if mid > 0 {
		m.StereoWidth = side / mid
	}
	if all > 0 {
		m.Brightness = hi / all
	}
	quiet := func(x float64) bool { return dbfs(x) < -45 }
	for _, x := range rms {
		if !quiet(x) {
			break
		}
		m.LeadSilence += 0.05
	}
	for i := len(rms) - 1; i >= 0 && quiet(rms[i]); i-- {
		m.TailSilence += 0.05
	}
	// Dropouts and energy consistency inside the body (skip 4 s each end).
	lo, hiIdx := 80, len(rms)-80
	cur, quietCount := 0.0, 0
	var body []float64
	for i := lo; i < hiIdx; i++ {
		if dbfs(rms[i]) < -38 {
			cur += 0.05
			quietCount++
			m.MaxDropout = math.Max(m.MaxDropout, cur)
		} else {
			cur = 0
		}
		body = append(body, rms[i])
	}
	if len(body) > 0 {
		m.QuietShare = float64(quietCount) / float64(len(body))
		// Coefficient of variation of 3 s mean levels.
		var blocks []float64
		for i := 0; i+60 <= len(body); i += 60 {
			var s float64
			for _, x := range body[i : i+60] {
				s += x
			}
			blocks = append(blocks, s/60)
		}
		if len(blocks) > 1 {
			var mean, v float64
			for _, b := range blocks {
				mean += b
			}
			mean /= float64(len(blocks))
			for _, b := range blocks {
				v += (b - mean) * (b - mean)
			}
			m.EnergyCV = math.Sqrt(v/float64(len(blocks))) / mean
		}
	}
	return m
}

// Score: lower is better. Each term is a documented penalty.
func Score(m *Metrics, target float64) (float64, []string) {
	var s float64
	var notes []string
	add := func(v float64, why string) {
		if v > 0.005 {
			s += v
			notes = append(notes, fmt.Sprintf("%s +%.2f", why, v))
		}
	}
	add(float64(m.ClippedRuns)/40, fmt.Sprintf("%d clipped runs", m.ClippedRuns))
	add(math.Max(0, m.LeadSilence-0.3)*2, fmt.Sprintf("lead silence %.2fs", m.LeadSilence))
	add(math.Max(0, m.MaxDropout-0.4)*3, fmt.Sprintf("dropout %.2fs", m.MaxDropout))
	add(m.QuietShare*10, fmt.Sprintf("quiet share %.1f%%", m.QuietShare*100))
	add(math.Max(0, m.EnergyCV-0.25)*4, fmt.Sprintf("energy cv %.2f", m.EnergyCV))
	add(math.Max(0, 2-m.LRA)*0.5, fmt.Sprintf("squashed LRA %.1f", m.LRA))
	add(math.Max(0, m.LRA-12)*0.3, fmt.Sprintf("wide LRA %.1f", m.LRA))
	add(math.Abs(m.Duration-target)/10, fmt.Sprintf("duration %.1fs vs %.0fs", m.Duration, target))
	return s, notes
}

// PickReason compares the winner with the other candidates.
func PickReason(cands []Candidate, pick int, notes map[int][]string) string {
	sort.SliceStable(cands, func(i, j int) bool { return cands[i].Seed < cands[j].Seed })
	var parts []string
	for _, c := range cands {
		label := "kept"
		if c.Seed != pick {
			label = "rejected"
		}
		n := strings.Join(notes[c.Seed], ", ")
		if n == "" {
			n = "no penalties"
		}
		parts = append(parts, fmt.Sprintf("seed %d %s (score %.2f: %s)", c.Seed, label, c.Score, n))
	}
	return "metric pick, listening pending; " + strings.Join(parts, "; ")
}
