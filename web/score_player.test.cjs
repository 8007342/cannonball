const assert = require('node:assert/strict');
const test = require('node:test');
const Player = require('./score_player.js');
function harness() {
 const sources=[]; let requests=0;
 const catalog={tracks:[{station:'City',title:'City song',src:'city.mp3'},{station:'Forest',title:'Forest song',src:'forest.mp3'}],radio:[{text:'Snow ahead',src:'snow.mp3',voice:'presenter'}]};
 const context={currentTime:10,decodeAudioData:async()=>({duration:100}),createBufferSource(){
  const n={connect(){},disconnect(){this.disconnected=true;},start(at){this.started=at;},stop(){this.stopped=true;}};sources.push(n);return n;
 }};
 let resolve; let delay=false; let fail=false;
 const fetch=async url=>{requests++;if(delay)await new Promise(r=>resolve=r); if(fail)throw Error('offline');return {ok:true,json:async()=>catalog,arrayBuffer:async()=>new ArrayBuffer(8)};};
 const p=new Player(context,{}, {base:'https://game.test/audio/',fetch});
 return {p,sources,get requests(){return requests;},delay(){delay=true;},release(){delay=false;resolve();},fail(){fail=true;}};
}
test('selected score decodes once, loops on audio clock, and is replaced by station',async()=>{
 const h=harness();assert.equal(await h.p.play('City'),true);assert.equal(h.sources[0].loop,true);assert.equal(h.sources[0].started,10.025);
 await h.p.play('City');assert.equal(h.requests,2);assert.equal(h.sources.length,1);
 await h.p.play('Forest');assert.equal(h.sources[0].stopped,true);assert.equal(h.p.snapshot().title,'Forest song');assert.equal(h.p.cache.size,1);
});
test('pause during decode cannot restart a stale score',async()=>{
 const h=harness();await h.p.prepare();h.delay();const playing=h.p.play('City');await new Promise(setImmediate);h.p.stopMusic();h.release();assert.equal(await playing,false);assert.equal(h.sources.length,0);
});
test('reports complete once through buffer playback and can be canceled',async()=>{
 const h=harness();let completed=0;assert.equal(await h.p.report('Snow ahead',()=>completed++),true);h.sources[0].onended();assert.equal(completed,1);
 await h.p.report('Snow ahead',()=>completed++);h.p.stopVoice();assert.equal(h.sources[1].stopped,true);assert.equal(h.sources[1].onended,null);assert.equal(completed,1);
 assert.equal(await h.p.report('Unknown line',()=>{}),false);
});
test('dispose while loading prevents voice playback',async()=>{
 const h=harness();await h.p.prepare();h.delay();const playing=h.p.report('Snow ahead',()=>assert.fail('stale completion'));await new Promise(setImmediate);h.p.dispose();h.release();assert.equal(await playing,false);assert.equal(h.sources.length,0);assert.equal(h.p.cache.size,0);
});
test('network failure returns control to fallback',async()=>{
 const h=harness();h.fail();assert.equal(await h.p.play('City'),false);assert.equal(await h.p.report('Snow ahead',()=>{}),false);
});
