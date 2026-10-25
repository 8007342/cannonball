import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';
import vm from 'node:vm';

const source=fs.readFileSync(new URL('./proof_bootstrap.js',import.meta.url),'utf8');
function browser(search='?proof=1',native=3){
  const w={innerWidth:1280,innerHeight:720,visualViewport:{scale:1},location:{search},document:{querySelectorAll:()=>[],hasFocus:()=>true,visibilityState:"visible"}};
  Object.defineProperty(w,'devicePixelRatio',{configurable:true,get:()=>native});
  const context={window:w,document:w.document,location:w.location,URLSearchParams,get innerWidth(){return w.innerWidth;},get innerHeight(){return w.innerHeight;}};
  vm.runInNewContext(source,context);
  return w;
}
test('normal game route retains its native pixel ratio',()=>{
  const w=browser('');assert.equal(w.devicePixelRatio,3);assert.equal(w.CannonballProofBootstrap,undefined);
});
test('smooth proof caps reported root pixels even on high DPI',()=>{
  const w=browser();const s=w.CannonballProofBootstrap.snapshot();
  assert.equal(s.quality,'smooth');assert.equal(s.pixelBudget,720*405);
  assert.equal(w.devicePixelRatio,.5625);assert.equal(s.nativeDpr,3);
  assert.equal(w.innerWidth*w.innerHeight*w.devicePixelRatio**2,s.pixelBudget);
  assert.equal(s.largestCanvasPixels,0); // Telemetry must not invent an actual canvas.
});
test('detail preset and resize recompute an aspect-preserving budget',()=>{
  const w=browser('?proof=1&quality=detail');assert.equal(w.devicePixelRatio,.75);
  w.innerWidth=1920;w.innerHeight=1080;assert.equal(w.devicePixelRatio,.5);
  assert.equal(w.innerWidth*w.innerHeight*w.devicePixelRatio**2,960*540);
});
test('pinch scale is compensated rather than increasing raster budget',()=>{
  const w=browser();w.visualViewport.scale=2;
  assert.equal(w.devicePixelRatio,.28125);
  assert.equal(w.innerWidth*w.innerHeight*(w.devicePixelRatio*w.visualViewport.scale)**2,720*405);
});
test('no upsampling on a lower native DPR and safe missing visual viewport',()=>{
  const w=browser('?proof=1',.4);delete w.visualViewport;
  assert.equal(w.devicePixelRatio,.4);assert.equal(w.CannonballProofBootstrap.snapshot().viewportScale,1);
});
