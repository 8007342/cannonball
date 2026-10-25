#!/usr/bin/env python3
"""Measure encoded deliverables, check voice coverage and record provenance."""
import hashlib,json,pathlib,re,subprocess
import imageio_ffmpeg
ROOT=pathlib.Path(__file__).resolve().parents[2]; out=ROOT/'assets/audio';catalog=json.loads((out/'catalog.json').read_text())
expected=set(re.findall(r"^        '([^']+)',",(ROOT/'lib/platform/proof_radio.dart').read_text(),re.M))
assert {r['text'] for r in catalog['radio']} == expected
results=[]
for entry in catalog['tracks']+catalog['radio']+catalog.get('surf', []):
 p=out/entry['src'];assert p.stat().st_size>1000
 run=subprocess.run([imageio_ffmpeg.get_ffmpeg_exe(),'-hide_banner','-i',str(p),'-af','loudnorm=I=-16:TP=-1.5:LRA=9:print_format=json','-f','null','-'],capture_output=True,text=True,check=True)
 stats=json.JSONDecoder().raw_decode(run.stderr[run.stderr.rfind('{'):])[0]; peak=float(stats['input_tp']); loud=float(stats['input_i'])
 assert peak<0,(p.name,peak)
 assert -19<loud<-13,(p.name,loud)
 results.append(dict(src=p.name,bytes=p.stat().st_size,sha256=hashlib.sha256(p.read_bytes()).hexdigest(),lufs=loud,truePeakDb=peak))
 print(p.name,loud,peak,flush=True)
models={}
for name in ['kokoro-v1.0.onnx','voices-v1.0.bin']:
 p=pathlib.Path.home()/'.cache/cannonball-audio'/name
 models[name]=hashlib.sha256(p.read_bytes()).hexdigest()
(out/'verification.json').write_text(json.dumps(dict(modelSha256=models,radioScripts=len(expected),encodedFiles=results),indent=2)+'\n')
