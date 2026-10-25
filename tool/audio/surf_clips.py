#!/usr/bin/env python3
"""Build tiny original-score excerpts for bounded radio dial surfing."""
import json,pathlib,subprocess
import imageio_ffmpeg
ROOT=pathlib.Path(__file__).resolve().parents[2];OUT=ROOT/'assets/audio'
p=OUT/'catalog.json';data=json.loads(p.read_text());data['surf']=[]
for track in data['tracks']:
 filename='surf-'+track['id']+'.mp3'
 subprocess.run([imageio_ffmpeg.get_ffmpeg_exe(),'-v','error','-y','-ss','29','-i',str(OUT/track['src']),'-t','0.68','-ar','32000','-c:a','libmp3lame','-b:a','96k',str(OUT/filename)],check=True)
 data['surf'].append(dict(src=filename,station=track['station'],title=track['title']+' — dial fragment',duration=.68))
p.write_text(json.dumps(data,indent=2)+'\n')
# Old prepared reports no longer referenced by exact text are not shipped.
keep={r['src'] for r in data['radio']}
for clip in OUT.glob('radio-*.mp3'):
 if clip.name not in keep: clip.unlink()
