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
test('default app gets the same bounded backing pixels as the proof link',()=>{
  const w=browser('');assert.equal(w.devicePixelRatio,.5625);assert.equal(w.CannonballProofBootstrap.snapshot().pixelBudget,720*405);
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

test('surface diagnostics distinguish displayed extent from capped backing pixels',()=>{
  const w=browser();
  let cssWidth=1280,cssHeight=720;
  const canvas={tagName:'CANVAS',width:720,height:405,
    getBoundingClientRect:()=>({width:cssWidth,height:cssHeight,left:0,top:0})};
  w.document.querySelectorAll=()=>[canvas];
  let s=w.CannonballProofBootstrap.snapshot();
  assert.equal(s.surfaceCoverage.sizeMatchesLayout,true);
  assert.equal(s.surfaceCoverage.layoutAreaRatio,1);
  w.innerWidth=1920;w.innerHeight=1080;
  s=w.CannonballProofBootstrap.snapshot();
  assert.equal(s.surfaceCoverage.sizeMatchesLayout,false);
  assert.equal(s.surfaceCoverage.layoutAreaRatio,4/9);
  cssWidth=1920;cssHeight=1080;
  s=w.CannonballProofBootstrap.snapshot();
  assert.equal(s.surfaceCoverage.sizeMatchesLayout,true);
  assert.equal(s.largestCanvasPixels,720*405);
  assert.equal(canvas.width,720); // Diagnostics must not mutate the engine surface.
});
test('surface offset and visual pinch viewport remain separately observable',()=>{
  const w=browser();
  w.outerWidth=1440;w.outerHeight=900;
  w.visualViewport={scale:2,width:640,height:360,offsetLeft:30,offsetTop:10};
  w.document.documentElement={clientWidth:1280,clientHeight:720};
  w.document.querySelectorAll=()=>[{tagName:'CANVAS',width:720,height:405,
    getBoundingClientRect:()=>({width:1280,height:720,left:100,top:0})}];
  const s=w.CannonballProofBootstrap.snapshot();
  assert.equal(s.surfaceCoverage.sizeMatchesLayout,true);
  assert.equal(s.surfaceCoverage.originMatchesLayout,false);
  assert.equal(s.surfaceCoverage.layoutAreaRatio,1180/1280);
  assert.equal(s.visualViewport.width,640);
  assert.equal(s.viewport.width,1280);
  assert.equal(s.outerWindow.width,1440);
  assert.equal(s.documentClient.width,1280);
});
test('invalid native metrics do not poison the proof pixel budget',()=>{
  const w=browser('?proof=1',NaN);
  assert.equal(w.CannonballProofBootstrap.snapshot().nativeDpr,1);
  w.visualViewport.scale=Infinity;
  assert.equal(w.devicePixelRatio,.5625);
  w.innerWidth=0;w.innerHeight=0;
  assert.equal(w.devicePixelRatio,1);
});
