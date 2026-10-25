#!/usr/bin/env python3
"""Render original report scripts with stock synthetic presenters, no cloning.
Model files live outside the repository; see assets/audio/SCORE_NOTES.md.
"""
import hashlib,json,pathlib,re,subprocess,tempfile,os
os.environ.setdefault('OMP_NUM_THREADS','2')
import soundfile as sf
import imageio_ffmpeg
FFMPEG=imageio_ffmpeg.get_ffmpeg_exe()
import numpy as np
import onnxruntime as rt
from kokoro_onnx import Kokoro
ROOT=pathlib.Path(__file__).resolve().parents[2]; OUT=ROOT/'assets/audio'
CACHE=pathlib.Path.home()/'.cache/cannonball-audio'
k=Kokoro(str(CACHE/'kokoro-v1.0.onnx'),str(CACHE/'voices-v1.0.bin'))
# kokoro-onnx 0.4.7 submits integer speed for newer exports. Match model metadata.
class TypedSession:
 def __init__(self, session): self.session=session
 def get_inputs(self): return self.session.get_inputs()
 def run(self, outputs, inputs):
  for item in self.get_inputs():
   if item.name == 'speed' and item.type == 'tensor(float)':
    inputs['speed']=np.array([1.06],dtype=np.float32)
  return self.session.run(outputs,inputs)
options=rt.SessionOptions(); options.intra_op_num_threads=2; options.inter_op_num_threads=1
k.sess=TypedSession(rt.InferenceSession(str(CACHE/'kokoro-v1.0.onnx'),sess_options=options,providers=['CPUExecutionProvider']))
lines=re.findall(r"^        '([^']+)',",(ROOT/'lib/platform/proof_radio.dart').read_text(),re.M)
reports=[]
for i,text in enumerate(lines):
 voice=['am_michael','af_heart','am_fenrir'][i%3]
 filename='radio-'+hashlib.sha256(text.encode()).hexdigest()[:12]+'.mp3'
 if not (OUT/filename).exists():
  samples,rate=k.create(text,voice=voice,speed=1.06,lang='en-us')
  with tempfile.TemporaryDirectory(dir=CACHE) as folder:
   wav=pathlib.Path(folder)/'voice.wav';sf.write(wav,samples,rate)
   subprocess.run([FFMPEG,'-v','error','-y','-i',str(wav),'-af','highpass=f=140,lowpass=f=6500,loudnorm=I=-16:TP=-2:LRA=7','-c:a','libmp3lame','-b:a','96k',str(OUT/filename)],check=True)
 reports.append(dict(text=text,src=filename,voice=voice,model='Kokoro v1.0'))
 print(i+1,len(lines),voice,filename,flush=True)
catalog=OUT/'catalog.json';data=json.loads(catalog.read_text());data['radio']=reports;catalog.write_text(json.dumps(data,indent=2)+'\n')
