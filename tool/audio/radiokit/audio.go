package main

import (
	"bytes"
	"crypto/sha256"
	"encoding/binary"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"math"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
)

var ffmpegBin = func() string {
	if v := os.Getenv("FFMPEG"); v != "" {
		return v
	}
	return "ffmpeg"
}()

func ffmpeg(args ...string) ([]byte, error) {
	cmd := exec.Command(ffmpegBin, append([]string{"-hide_banner", "-nostats", "-nostdin"}, args...)...)
	var stderr bytes.Buffer
	cmd.Stderr = &stderr
	out, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("ffmpeg %s: %w\n%s", strings.Join(args, " "), err, tail(stderr.String(), 1200))
	}
	return append(out, stderr.Bytes()...), nil
}

// ffmpegLog runs ffmpeg and returns only its stderr log (filters print there).
func ffmpegLog(args ...string) (string, error) {
	cmd := exec.Command(ffmpegBin, append([]string{"-hide_banner", "-nostats", "-nostdin"}, args...)...)
	var stderr bytes.Buffer
	cmd.Stderr = &stderr
	cmd.Stdout = io.Discard
	if err := cmd.Run(); err != nil {
		return "", fmt.Errorf("ffmpeg %s: %w\n%s", strings.Join(args, " "), err, tail(stderr.String(), 1200))
	}
	return stderr.String(), nil
}

func tail(s string, n int) string {
	if len(s) > n {
		return s[len(s)-n:]
	}
	return s
}

// Decode returns interleaved float32 samples at rate/channels.
func Decode(path string, rate, channels int) ([]float32, error) {
	cmd := exec.Command(ffmpegBin, "-hide_banner", "-nostdin", "-v", "error", "-i", path,
		"-f", "f32le", "-ac", strconv.Itoa(channels), "-ar", strconv.Itoa(rate), "-")
	var stderr bytes.Buffer
	cmd.Stderr = &stderr
	raw, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("decode %s: %w %s", path, err, stderr.String())
	}
	out := make([]float32, len(raw)/4)
	for i := range out {
		out[i] = math.Float32frombits(binary.LittleEndian.Uint32(raw[i*4:]))
	}
	return out, nil
}

// WriteWAV writes 32-bit float WAV (lossless intermediate, never committed).
func WriteWAV(path string, samples []float32, rate, channels int) error {
	var b bytes.Buffer
	data := len(samples) * 4
	b.WriteString("RIFF")
	binary.Write(&b, binary.LittleEndian, uint32(36+data))
	b.WriteString("WAVEfmt ")
	binary.Write(&b, binary.LittleEndian, uint32(16))
	binary.Write(&b, binary.LittleEndian, uint16(3)) // IEEE float
	binary.Write(&b, binary.LittleEndian, uint16(channels))
	binary.Write(&b, binary.LittleEndian, uint32(rate))
	binary.Write(&b, binary.LittleEndian, uint32(rate*channels*4))
	binary.Write(&b, binary.LittleEndian, uint16(channels*4))
	binary.Write(&b, binary.LittleEndian, uint16(32))
	b.WriteString("data")
	binary.Write(&b, binary.LittleEndian, uint32(data))
	for _, s := range samples {
		binary.Write(&b, binary.LittleEndian, math.Float32bits(s))
	}
	return os.WriteFile(path, b.Bytes(), 0o644)
}

func fileSHA(path string) (string, int64, error) {
	b, err := os.ReadFile(path)
	if err != nil {
		return "", 0, err
	}
	h := sha256.Sum256(b)
	return hex.EncodeToString(h[:]), int64(len(b)), nil
}

// Loudness is the EBU R128 / BS.1770 summary printed by ffmpeg's ebur128.
type Loudness struct {
	I, LRA, TruePeak float64
}

var (
	reI    = regexp.MustCompile(`(?s)Summary:.*?I:\s+(-?[\d.]+|-inf) LUFS`)
	reLRA  = regexp.MustCompile(`(?s)Summary:.*?LRA:\s+(-?[\d.]+) LU`)
	rePeak = regexp.MustCompile(`(?s)Summary:.*?True peak:\s+Peak:\s+(-?[\d.]+|-inf) dBFS`)
)

func parseFloat(s string) float64 {
	if s == "-inf" {
		return math.Inf(-1)
	}
	f, _ := strconv.ParseFloat(s, 64)
	return f
}

// Measure uses ffmpeg's ebur128 filter with 4x oversampled true peak.
func Measure(path string) (Loudness, error) {
	log, err := ffmpegLog("-i", path, "-af", "ebur128=peak=true:framelog=quiet", "-f", "null", "-")
	if err != nil {
		return Loudness{}, err
	}
	return parseLoudness(log)
}

func parseLoudness(log string) (Loudness, error) {
	i, lra, p := reI.FindStringSubmatch(log), reLRA.FindStringSubmatch(log), rePeak.FindStringSubmatch(log)
	if i == nil || lra == nil || p == nil {
		return Loudness{}, fmt.Errorf("no ebur128 summary in ffmpeg output")
	}
	return Loudness{I: parseFloat(i[1]), LRA: parseFloat(lra[1]), TruePeak: parseFloat(p[1])}, nil
}

type loudnormStats struct {
	InputI      string `json:"input_i"`
	InputTP     string `json:"input_tp"`
	InputLRA    string `json:"input_lra"`
	InputThresh string `json:"input_thresh"`
	Offset      string `json:"target_offset"`
}

// Loudnorm is two-pass EBU R128 normalisation (linear when the gain allows).
// pre is an optional filter chain applied before measurement.
func Loudnorm(in, out, pre string, lufs, tp, lra float64, rate, channels int, encode []string) error {
	target := fmt.Sprintf("I=%.1f:TP=%.1f:LRA=%.0f", lufs, tp, lra)
	chain := func(f string) string {
		if pre == "" {
			return f
		}
		return pre + "," + f
	}
	log, err := ffmpegLog("-i", in, "-af", chain("loudnorm="+target+":print_format=json"), "-f", "null", "-")
	if err != nil {
		return err
	}
	start := strings.LastIndex(log, "{")
	if start < 0 {
		return fmt.Errorf("loudnorm stats missing for %s", in)
	}
	var st loudnormStats
	if err := json.NewDecoder(strings.NewReader(log[start:])).Decode(&st); err != nil {
		return fmt.Errorf("loudnorm stats: %w", err)
	}
	second := fmt.Sprintf("loudnorm=%s:measured_I=%s:measured_TP=%s:measured_LRA=%s:measured_thresh=%s:offset=%s:linear=true,aresample=%d",
		target, st.InputI, st.InputTP, st.InputLRA, st.InputThresh, st.Offset, rate)
	args := []string{"-y", "-v", "error", "-i", in, "-af", chain(second), "-ac", strconv.Itoa(channels), "-ar", strconv.Itoa(rate)}
	args = append(args, encode...)
	args = append(args, out)
	if _, err = ffmpeg(args...); err != nil {
		return err
	}
	// Short clips can leave dynamic loudnorm off target. Re-render with a
	// measured static gain into a peak limiter and keep whichever is closer.
	got, err := Measure(out)
	if err != nil || math.Abs(got.I-lufs) <= 0.5 {
		return err
	}
	raw := out + ".pre.wav"
	defer os.Remove(raw)
	if _, err := ffmpeg("-y", "-v", "error", "-i", in, "-af", chain("aresample="+strconv.Itoa(rate)), "-ac", strconv.Itoa(channels), "-c:a", "pcm_f32le", raw); err != nil {
		return err
	}
	m, err := Measure(raw)
	if err != nil {
		return err
	}
	limit := math.Pow(10, (tp-1)/20) // sample-peak limiter, 1 dB below the true-peak ceiling
	fix := fmt.Sprintf("volume=%.2fdB,alimiter=limit=%.4f:attack=2:release=60:level=false", lufs-m.I, limit)
	alt := out + ".alt" + filepath.Ext(out)
	args = append([]string{"-y", "-v", "error", "-i", raw, "-af", fix, "-ac", strconv.Itoa(channels), "-ar", strconv.Itoa(rate)}, encode...)
	if _, err := ffmpeg(append(args, alt)...); err != nil {
		return err
	}
	if g, err := Measure(alt); err == nil && math.Abs(g.I-lufs) < math.Abs(got.I-lufs) && g.TruePeak <= tp+0.5 {
		return os.Rename(alt, out)
	}
	return os.Remove(alt)
}

func mp3Args(kbps int) []string {
	return []string{"-c:a", "libmp3lame", "-b:a", fmt.Sprintf("%dk", kbps), "-compression_level", "0", "-map_metadata", "-1", "-id3v2_version", "0", "-write_xing", "1"}
}

// Probe returns the stream codec, sample rate and channel count.
func Probe(path string) (codec string, rate, channels int, err error) {
	log, err := ffmpegLog("-i", path, "-t", "0.1", "-f", "null", "-")
	if err != nil {
		return
	}
	m := regexp.MustCompile(`Stream #0:0[^:]*: Audio: (\w+)[^,]*, (\d+) Hz, (mono|stereo)`).FindStringSubmatch(log)
	if m == nil {
		err = fmt.Errorf("no audio stream in %s", path)
		return
	}
	codec = m[1]
	rate, _ = strconv.Atoi(m[2])
	channels = 1
	if m[3] == "stereo" {
		channels = 2
	}
	return
}
