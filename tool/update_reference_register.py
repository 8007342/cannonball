#!/usr/bin/env python3
"""Build/check the spec-linked inventory of project research and evidence."""
import argparse,pathlib,re
ROOT=pathlib.Path(__file__).resolve().parents[1]
DEST=ROOT/'docs/research/reference-register.md'
paths=sorted(set((ROOT/'docs').rglob('*.md'))|set((ROOT/'assets').rglob('*.md')))
paths=[p for p in paths if p!=DEST]
rows=[]
for p in paths:
 text=p.read_text();title=next((l.lstrip('# ').strip() for l in text.splitlines() if l.startswith('# ')),p.stem)
 urls=set(re.findall(r'https?://[^\s<>\)\]"`]+',text))
 rel=p.relative_to(ROOT).as_posix()
 kind='Research / source interpretation' if rel.startswith('docs/research/') else 'Asset provenance' if rel.startswith('assets/') else 'Design / implementation / validation'
 rows.append(f'| [{title.replace("|","/")}]({pathlib.PurePosixPath("../..")/rel}) | {kind} | {len(urls)} |')
content='''# Research and reference register

This is the shared source index linked from every main and active-change spec.
It inventories every Markdown research, design, architecture, validation and asset
provenance document under `docs/` and `assets/`. Follow each document for its exact
external source links, publication context and project interpretation. A source
count is an inventory, not a quality score or a claim that a link is live.

Requirements express desired behavior. Historical reports describe their own
builds; they do not override newer user decisions or establish production/device
acceptance. Original artwork prompts and score sources are project provenance,
not scientific evidence. Prior prototype choices are recorded rather than erased.

**Authorship:** GameFlow (2005) is by Penelope Sweetser and Peta Wyeth. Valve's
AI Director, playtesting and art-direction publications are separate references.
SDT work by Ryan, Rigby and Przybylski supplies a complementary motivation lens.
None specifies Cannonball's camera height, contact margin, assist threshold or
roadside repetition rate. Those remain explicit hypotheses and playtest criteria.

Regenerate with `python3 tool/update_reference_register.py`; use `--check` during
local verification. New research documents must appear here before claiming the
spec reference audit is complete. External citations remain in their original
context, avoiding detached or misleading authority claims.

| Document | Role | External source URLs |
| --- | --- | ---: |
'''+ '\n'.join(rows)+'\n'
parser=argparse.ArgumentParser();parser.add_argument('--check',action='store_true');args=parser.parse_args()
if args.check:
 assert DEST.exists() and DEST.read_text()==content,'Reference register stale; regenerate it.'
 print(f'Reference coverage current: {len(paths)} documents.')
else:
 DEST.write_text(content);print(f'Indexed {len(paths)} documents.')
