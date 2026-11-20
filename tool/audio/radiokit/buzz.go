package main

import "math"

// Tuning-buzz synthesis: a deterministic model of turning an analogue dial
// between stations. Each clip starts at full level (it masks a hard cut),
// sweeps a resonant band through hiss, adds heterodyne whistles, static
// crackle and, optionally, short band-limited fragments of other stations.

type BuzzSpec struct {
	ID        string  `json:"id"`
	Seed      uint64  `json:"seed"`
	Seconds   float64 `json:"seconds"`
	SweepFrom float64 `json:"sweep_from_hz"`
	SweepTo   float64 `json:"sweep_to_hz"`
	Whistles  int     `json:"whistles"`
	Crackle   float64 `json:"crackle"`
	Fragments int     `json:"fragments"`
}

var buzzBank = []BuzzSpec{
	{ID: "buzz-1", Seed: 11, Seconds: 0.85, SweepFrom: 600, SweepTo: 3400, Whistles: 1, Crackle: 0.6, Fragments: 1},
	{ID: "buzz-2", Seed: 23, Seconds: 1.10, SweepFrom: 3200, SweepTo: 500, Whistles: 2, Crackle: 0.4, Fragments: 2},
	{ID: "buzz-3", Seed: 37, Seconds: 0.70, SweepFrom: 900, SweepTo: 2500, Whistles: 1, Crackle: 1.0, Fragments: 0},
	{ID: "buzz-4", Seed: 41, Seconds: 1.35, SweepFrom: 450, SweepTo: 4200, Whistles: 3, Crackle: 0.5, Fragments: 2},
	{ID: "buzz-5", Seed: 59, Seconds: 0.95, SweepFrom: 2800, SweepTo: 800, Whistles: 1, Crackle: 0.8, Fragments: 1},
	{ID: "buzz-6", Seed: 67, Seconds: 1.20, SweepFrom: 700, SweepTo: 1900, Whistles: 2, Crackle: 0.3, Fragments: 3},
	{ID: "buzz-7", Seed: 73, Seconds: 0.80, SweepFrom: 4000, SweepTo: 1200, Whistles: 0, Crackle: 1.2, Fragments: 1},
	{ID: "buzz-8", Seed: 89, Seconds: 1.50, SweepFrom: 500, SweepTo: 3000, Whistles: 2, Crackle: 0.6, Fragments: 3},
}

type rng struct{ s uint64 }

func (r *rng) next() uint64 { // splitmix64
	r.s += 0x9e3779b97f4a7c15
	z := r.s
	z = (z ^ (z >> 30)) * 0xbf58476d1ce4e5b9
	z = (z ^ (z >> 27)) * 0x94d049bb133111eb
	return z ^ (z >> 31)
}
func (r *rng) float() float64  { return float64(r.next()>>11) / (1 << 53) }
func (r *rng) signed() float64 { return r.float()*2 - 1 }

// svf is a Chamberlin state-variable band-pass filter.
type svf struct{ low, band float64 }

func (f *svf) bandpass(x, fc, q float64, rate int) float64 {
	k := 2 * math.Sin(math.Pi*math.Min(fc, float64(rate)/6)/float64(rate))
	high := x - f.low - f.band/q
	f.band += k * high
	f.low += k * f.band
	return f.band
}

// Fragment is a mono source for "passing station" snippets.
type Fragment []float32

// SynthBuzz renders a stereo clip. fragments may be empty.
func SynthBuzz(spec BuzzSpec, rate int, fragments []Fragment) []float32 {
	r := &rng{s: spec.Seed}
	n := int(spec.Seconds * float64(rate))
	out := make([]float32, 2*n)
	var fl, fr svf
	pinkL, pinkR := [3]float64{}, [3]float64{}
	pink := func(p *[3]float64, w float64) float64 { // 3-pole pinkish noise
		p[0] = 0.997*p[0] + 0.029591*w
		p[1] = 0.985*p[1] + 0.032534*w
		p[2] = 0.950*p[2] + 0.048056*w
		return p[0] + p[1] + p[2] + 0.1848*w
	}
	type whistle struct{ at, dur, f0, f1, amp float64 }
	var ws []whistle
	for i := 0; i < spec.Whistles; i++ {
		at := 0.1 + r.float()*0.6
		ws = append(ws, whistle{at * spec.Seconds, 0.12 + r.float()*0.25, 900 + r.float()*2600, 300 + r.float()*1500, 0.10 + r.float()*0.08})
	}
	type frag struct {
		at, dur float64
		src     Fragment
		off     int
		fc      float64
	}
	var fs []frag
	for i := 0; i < spec.Fragments && len(fragments) > 0; i++ {
		src := fragments[int(r.next()%uint64(len(fragments)))]
		dur := 0.09 + r.float()*0.16
		need := int(dur * float64(rate))
		if len(src) <= need {
			continue
		}
		fs = append(fs, frag{(0.15 + r.float()*0.65) * spec.Seconds, dur, src, int(r.next() % uint64(len(src)-need)), 900 + r.float()*900})
	}
	var fragFilt svf
	crackleLeft := 0
	crackleAmp := 0.0
	for i := 0; i < n; i++ {
		t := float64(i) / float64(rate)
		p := t / spec.Seconds
		// Exponential dial sweep with a slight wobble from an unsteady hand.
		fc := spec.SweepFrom * math.Pow(spec.SweepTo/spec.SweepFrom, p) * (1 + 0.06*math.Sin(2*math.Pi*3.1*t))
		wl, wr := r.signed(), r.signed()
		nl := pink(&pinkL, wl)*0.55 + fl.bandpass(wl, fc, 3.5, rate)*0.9
		nr := pink(&pinkR, wr)*0.55 + fr.bandpass(wr, fc*1.03, 3.5, rate)*0.9
		// Envelope: full level at sample 0 masks the hard cut; short tail fade.
		env := 1.0
		if rem := spec.Seconds - t; rem < 0.04 {
			env = rem / 0.04
		}
		env *= 0.85 + 0.15*math.Sin(2*math.Pi*7.3*t+1.1)
		l, rr := nl*0.45*env, nr*0.45*env
		for _, w := range ws {
			if t >= w.at && t < w.at+w.dur {
				q := (t - w.at) / w.dur
				f := w.f0 * math.Pow(w.f1/w.f0, q)
				a := w.amp * math.Sin(math.Pi*q)
				v := a * math.Sin(2*math.Pi*f*t+0.3*math.Sin(2*math.Pi*60*t))
				l += v
				rr += v * 0.8
			}
		}
		if crackleLeft == 0 && r.float() < spec.Crackle*0.0009 {
			crackleLeft = 20 + int(r.next()%120)
			crackleAmp = 0.25 + r.float()*0.35
		}
		if crackleLeft > 0 {
			c := crackleAmp * r.signed()
			l += c
			rr += c * 0.7
			crackleLeft--
		}
		for _, f := range fs {
			if t >= f.at && t < f.at+f.dur {
				k := i - int(f.at*float64(rate))
				q := (t - f.at) / f.dur
				g := math.Min(1, math.Min(q, 1-q)*8) * 0.9
				v := fragFilt.bandpass(float64(f.src[f.off+k]), f.fc, 1.2, rate) * g
				l += v
				rr += v
			}
		}
		out[2*i] = float32(math.Tanh(l*1.2) * 0.8)
		out[2*i+1] = float32(math.Tanh(rr*1.2) * 0.8)
	}
	return out
}
