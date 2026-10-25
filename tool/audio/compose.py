#!/usr/bin/env python3
"""Original Cannonball score studies. No samples or existing song transcriptions.
Run with numpy, scipy, soundfile and ffmpeg; emits MIDI plus stereo MP3.
"""
import json, math, pathlib, struct, subprocess, tempfile
import numpy as np
from scipy.signal import butter, sosfilt
import soundfile as sf
import imageio_ffmpeg
FFMPEG=imageio_ffmpeg.get_ffmpeg_exe()
ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/audio'
SR = 32000
# Roots are pitch classes around A minor, D minor and E minor respectively.
SCORES = [
 dict(id='redline-sunrise', title='Redline Sunrise', station='City', style='synthpop', bpm=148, root=45,
      chords=[(0,[0,3,7,10]),(5,[0,3,7,10]),(8,[0,4,7,11]),(7,[0,4,7,10])],
      motif=[(0,12,.5),(.75,19,.25),(1,15,.5),(1.75,14,.25),(2,12,.5),(2.75,10,.25),(3,7,.75)]),
 dict(id='orange-cone-cumbia', title='Orange Cone Cumbia', station='Forest', style='electro-cumbia', bpm=140, root=50,
      chords=[(0,[0,3,7,10]),(0,[0,3,7,10]),(5,[0,3,7,10]),(7,[0,4,7,10])],
      motif=[(0,7,.25),(.5,12,.25),(.75,15,.25),(1.5,14,.5),(2.25,12,.25),(2.75,10,.25),(3,7,.5),(3.75,10,.25)]),
 dict(id='overpass-afterburn', title='Overpass Afterburn', station='Mountain', style='arcade-rock', bpm=156, root=40,
      chords=[(0,[0,3,7,10]),(8,[0,4,7,11]),(3,[0,4,7,10]),(10,[0,4,7,10])],
      motif=[(0,12,.75),(1,15,.25),(1.5,14,.5),(2,12,.5),(2.75,19,.25),(3,17,.5),(3.5,15,.5)])]

def var(n):
 b=[n&127]; n >>=7
 while n: b.insert(0,128|(n&127)); n >>=7
 return bytes(b)

def midi(score, events):
 tracks=[]
 def chunk(data): return b'MTrk'+struct.pack('>I',len(data))+data
 tempo=int(60_000_000/score['bpm'])
 tracks.append(chunk(b'\x00\xff\x51\x03'+tempo.to_bytes(3,'big')+b'\x00\xff\x58\x04\x04\x02\x18\x08\x00\xff\x2f\x00'))
 instruments={'bass':(0,38),'pad':(1,89),'lead':(2,81),'pluck':(3,10),'guitar':(4,30),'drum':(9,0)}
 for name,(ch,program) in instruments.items():
  data=b'\x00\xff\x03'+var(len(name))+name.encode()+b'\x00'+bytes([0xc0|ch,program]); last=0; messages=[]
  for beat,dur,kind,pitch,vel,pan in events:
   if kind != name: continue
   start=round(beat*480); end=round((beat+dur)*480)
   messages.extend([(start,1,bytes([0x90|ch,pitch,max(1,round(vel*127))])),(end,0,bytes([0x80|ch,pitch,0]))])
  for tick,_,message in sorted(messages): data+=var(tick-last)+message; last=tick
  tracks.append(chunk(data+b'\x00\xff\x2f\x00'))
 return b'MThd'+struct.pack('>IHHH',6,1,len(tracks),480)+b''.join(tracks)

def arrange(s):
 events=[]
 def add(beat,dur,kind,pitch,vel,pan=0): events.append((beat,dur,kind,pitch,vel,pan))
 # 64 bars: intro 8 / verse 16 / lift 8 / chorus 16 / breakdown 8 / final hook 8.
 for bar in range(64):
  beat=bar*4; root,intervals=s['chords'][(bar//2)%4]; tonic=s['root']+root
  intro=bar<8; breakdown=48<=bar<56; chorus=32<=bar<48 or bar>=56
  energy=.7 if intro or breakdown else 1
  # Chord inversions follow the nearest middle register, with a stereo pad.
  voicing=[tonic+12+i for i in intervals]
  for i,p in enumerate(voicing):
   while p>77: p-=12
   add(beat,3.85,'pad',p,.22*energy,(-.65,-.2,.2,.65)[i])
  if s['style']=='electro-cumbia':
   bassbeats=[(0,0,.7),(1.5,7,.4),(2,12,.6),(3.5,7,.4)]
   for off in [.5,1.5,2.5,3.5]:
    for i,p in enumerate(voicing[:3]): add(beat+off,.22,'pluck',p,.38,(-.5,0,.5)[i])
  elif s['style']=='arcade-rock':
   bassbeats=[(i*.5,0 if i%4<3 else 7,.35) for i in range(8)]
   if not breakdown:
    for i in range(8):
     for p in [tonic,tonic+7,tonic+12]: add(beat+i*.5,.28 if i%2==0 else .19,'guitar',p,.24,-.6 if i%2==0 else .6)
  else:
   bassbeats=[(0,0,.4),(.75,0,.2),(1.5,12,.3),(2,0,.4),(2.75,7,.2),(3.5,12,.3)]
   if not breakdown:
    for i in range(8): add(beat+i*.5,.23,'pluck',voicing[(i+bar)%4]+12,.24,math.sin(i)*.65)
  for off,p,d in bassbeats: add(beat+off,d,'bass',tonic-12+p,.65*energy)
  if not breakdown or bar>=52:
   for off in ([0,1,2,3] if s['style']=='synthpop' else [0,1.75,2,2.75]): add(beat+off,.25,'drum',36,.85*energy)
   for off in [1,3]: add(beat+off,.22,'drum',38,.7*energy)
   for i in range(8): add(beat+i*.5,.11 if i%2==0 else .18,'drum',42 if i%2==0 else 46,(.26 if i%2==0 else .4)*energy,.3)
   if s['style']=='electro-cumbia':
    for off,p in [(.75,64),(1.25,63),(2.5,64),(3.25,63)]: add(beat+off,.14,'drum',p,.47,-.45)
    for i in range(8): add(beat+i*.5+.25,.09,'drum',56,.24,.5)
  if bar%8==7:
   for i in range(4): add(beat+3+i*.25,.16,'drum',[45,47,48,50][3-i],.48+i*.05,(-.6+i*.4))
  if bar%8==0: add(beat,.9,'drum',49,.43,.5)
  if (bar>=8 and not breakdown) or bar>=54:
   # Two-bar question/answer; chorus rises an octave and adds harmony.
   for off,p,d in s['motif']:
    shift=12 if chorus else 0
    p += s['root']+12+shift
    if bar%2: p += [-2,0,0,2][(bar//2)%4]
    # Resolve final phrase into the current chord rather than random pitches.
    if off>=3 and bar%4==3: p=tonic+24+shift
    add(beat+off,d*.88,'lead',p,.42 if chorus else .36,-.12)
    if chorus and off in [0,2]: add(beat+off,d*.8,'lead',p-12,.18,.35)
 return events

def synth(kind,pitch,duration,rng):
 n=max(8,int(duration*SR)); t=np.arange(n)/SR; f=440*2**((pitch-69)/12)
 if kind=='drum':
  noise=rng.normal(0,1,n)
  if pitch==36:
   phase=2*np.pi*(43*t+100*.032*(1-np.exp(-t/.032)))
   x=np.sin(phase)*np.exp(-t*19)+noise*np.exp(-t*230)*.15
  elif pitch==38:
   x=(noise-np.roll(noise,1))*.32*np.exp(-t*19)+np.sin(2*np.pi*185*t)*np.exp(-t*28)*.35
  elif pitch in [42,46,49]:
   x=(noise-np.roll(noise,1))*.15*np.exp(-t*(45 if pitch==42 else 15 if pitch==46 else 6))
   for freq in [4211,5773,6983]: x+=.035*np.sin(2*np.pi*freq*t)*np.exp(-t*14)
  elif pitch==56: x=(np.sin(2*np.pi*560*t)+np.sin(2*np.pi*845*t))*.2*np.exp(-t*35)
  else:
   freq={63:210,64:175,45:100,47:130,48:155,50:190}.get(pitch,180)
   x=np.sin(2*np.pi*freq*(t+.009*(1-np.exp(-t/.04))))*np.exp(-t*22)+noise*.08*np.exp(-t*55)
 else:
  attack=np.minimum(t/(.08 if kind=='pad' else .008),1)
  release=np.minimum((duration-t)/(.25 if kind=='pad' else .055),1)
  env=attack*np.maximum(release,0)
  if kind=='bass':
   x=np.sin(2*np.pi*f*t)*.75+np.sin(2*np.pi*2*f*t)*.22+np.sin(2*np.pi*3*f*t)*.09
  elif kind=='pluck':
   x=np.sin(2*np.pi*f*t+2.8*np.sin(2*np.pi*f*2*t)*np.exp(-t*15))*np.exp(-t*9)
  elif kind=='guitar':
   x=sum(np.sin(2*np.pi*f*k*t)*np.exp(-t*(4+k)) / k for k in range(1,min(18,int(SR/2/f))))
   x=np.tanh(x*3)*.75
  else:
   # Band-limited additive synth; detuned pairs, vibrato and mellow upper rolloff.
   vibrato=.0025*np.sin(2*np.pi*5.4*t)*(1-np.exp(-t*7))
   x=np.zeros(n)
   for k in range(1,min(14,int(SR/2/f))):
    roll=1/k**(1.65 if kind=='pad' else 1.35)
    x+=roll*(np.sin(2*np.pi*f*k*(t*(1-.0018)+vibrato/40))+
             np.sin(2*np.pi*f*k*t*(1+.0018)))*.32
   if kind=='lead': x*=.8+.2*np.exp(-t*12)
  x*=env
 return x.astype(np.float32)

def render(s,events):
 beatsec=60/s['bpm']; frames=round(256*beatsec*SR)
 mix=np.zeros((frames+SR*3,2),dtype=np.float32); send=np.zeros_like(mix)
 rng=np.random.default_rng(731)
 for beat,dur,kind,pitch,vel,pan in events:
  duration=dur*beatsec+( .8 if kind=='pad' else .2 if kind=='drum' else .04)
  x=synth(kind,pitch,duration,rng)*vel*.22
  start=round(beat*beatsec*SR); end=min(len(mix),start+len(x)); x=x[:end-start]
  stereo=x[:,None]*np.array([math.sqrt((1-pan)/2),math.sqrt((1+pan)/2)])
  mix[start:end]+=stereo
  if kind in ['lead','pluck','pad','guitar']: send[start:end]+=stereo*(.23 if kind=='lead' else .12)
 # Crossed tempo delays and short decorrelated reverb taps; wrap tail for loops.
 for seconds,gain,swap in [(beatsec*.75,.6,True),(beatsec*1.5,.32,False),(.071,.2,True),(.113,.16,False),(.193,.12,True)]:
  offset=round(seconds*SR); wet=send[:-offset,::-1] if swap else send[:-offset]
  mix[offset:]+=wet*gain
 mix[:len(mix)-frames]+=mix[frames:]; mix=mix[:frames]
 # Low cut / soft saturation. Final file normalized consistently by ffmpeg.
 mix=sosfilt(butter(2,32,fs=SR,btype='highpass',output='sos'),mix,axis=0)
 mix=np.tanh(mix*1.5)
 with tempfile.TemporaryDirectory(prefix='cannonball-score-',dir='/home/forge/.cache/cannonball-audio') as folder:
  wav=pathlib.Path(folder)/'mix.wav'; sf.write(wav,mix,SR)
  subprocess.run([FFMPEG,'-v','error','-y','-i',str(wav),'-af','loudnorm=I=-16:TP=-1.5:LRA=9','-ar','32000','-c:a','libmp3lame','-b:a','160k',str(OUT/(s['id']+'.mp3'))],check=True)
 return round(frames/SR,3)

def main():
 OUT.mkdir(parents=True,exist_ok=True); (OUT/'midi').mkdir(exist_ok=True)
 catalog={'version':1,'tracks':[],'radio':[]}
 for s in SCORES:
  events=arrange(s); (OUT/'midi'/(s['id']+'.mid')).write_bytes(midi(s,events))
  duration=render(s,events)
  catalog['tracks'].append({k:s[k] for k in ['id','title','station','style','bpm']}|{'src':s['id']+'.mp3','duration':duration,'bars':64,'events':len(events)})
  print(s['title'],duration,len(events),flush=True)
 old=OUT/'catalog.json'
 if old.exists():
  previous=json.loads(old.read_text())
  catalog['radio']=previous.get('radio',[])
  catalog['surf']=previous.get('surf',[])
 old.write_text(json.dumps(catalog,indent=2)+'\n')
if __name__=='__main__': main()
