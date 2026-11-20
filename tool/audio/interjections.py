#!/usr/bin/env python3
"""Render radio interjection lines (art/music/radio-interjections.json) to raw
WAV with stock Kokoro v1.0 voices. Python only because kokoro-onnx forces it.
Radio-band processing, mastering and encoding happen in tool/audio/radiokit.

Run with `python3 -I tool/audio/interjections.py [--force]` from a venv that
has kokoro-onnx 0.4.7, numpy and soundfile. Model files are read from
$CANNONBALL_AUDIO_CACHE/models (default ~/.cache/tillandsias-project/cannonball-audio).
"""
import hashlib, json, os, pathlib, sys
os.environ.setdefault('OMP_NUM_THREADS', '2')
import numpy as np
import onnxruntime as rt
import soundfile as sf
from kokoro_onnx import Kokoro

ROOT = pathlib.Path(__file__).resolve().parents[2]
CACHE = pathlib.Path(os.environ.get('CANNONBALL_AUDIO_CACHE',
    pathlib.Path.home() / '.cache/tillandsias-project/cannonball-audio'))
MODELS = CACHE / 'models'
OUT = CACHE / 'voice-raw'
spec = json.loads((ROOT / 'art/music/radio-interjections.json').read_text())
speed = float(spec.get('speed', 1.0))

kokoro = Kokoro(str(MODELS / 'kokoro-v1.0.onnx'), str(MODELS / 'voices-v1.0.bin'))

class TypedSession:
    """kokoro-onnx 0.4.7 submits an integer speed to newer exports."""
    def __init__(self, session): self.session = session
    def get_inputs(self): return self.session.get_inputs()
    def run(self, outputs, inputs):
        for item in self.get_inputs():
            if item.name == 'speed' and item.type == 'tensor(float)':
                inputs['speed'] = np.array([speed], dtype=np.float32)
        return self.session.run(outputs, inputs)

options = rt.SessionOptions(); options.intra_op_num_threads = 2; options.inter_op_num_threads = 1
kokoro.sess = TypedSession(rt.InferenceSession(str(MODELS / 'kokoro-v1.0.onnx'),
    sess_options=options, providers=['CPUExecutionProvider']))

OUT.mkdir(parents=True, exist_ok=True)
for i, line in enumerate(spec['lines']):
    key = hashlib.sha256(f"{line['voice']}|{line['lang']}|{speed}|{line['text']}".encode()).hexdigest()[:12]
    wav = OUT / f"{line['id']}-{key}.wav"
    if '--force' in sys.argv or not wav.exists():
        samples, rate = kokoro.create(line['text'], voice=line['voice'], speed=speed, lang=line['lang'])
        sf.write(wav, samples, rate, subtype='FLOAT')
    print(f"{i + 1}/{len(spec['lines'])} {line['id']} {wav.name}", flush=True)
