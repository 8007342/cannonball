/* Proof-only browser pixel budget. Load synchronously before Flutter bootstrap.
 * Flutter 3.47 reads window.devicePixelRatio; it has no public loader DPR option.
 * This prototype caps the whole Flutter root, including its HUD. Browser input
 * stays in CSS pixels. Production gameplay without ?proof=1 is unaffected.
 */
(() => {
  'use strict';
  if (new URLSearchParams(location.search).get('proof') !== '1') return;
  if (window.CannonballProofBootstrap) return;
  const quality = new URLSearchParams(location.search).get('quality') === 'detail' ? 'detail' : 'smooth';
  const pixelBudget = quality === 'detail' ? 960 * 540 : 720 * 405;
  const original = Object.getOwnPropertyDescriptor(window, 'devicePixelRatio');
  const initialDpr = window.devicePixelRatio || 1;
  const nativeDpr = () => original?.get ? original.get.call(window) : initialDpr;
  const requestedDpr = () => {
    const area = Math.max(1, innerWidth * innerHeight);
    const viewportScale = window.visualViewport?.scale || 1;
    return Math.min(nativeDpr(), Math.sqrt(pixelBudget / area) / viewportScale);
  };
  let applied = false, error = null;
  try {
    Object.defineProperty(window, 'devicePixelRatio', {configurable: true, get: requestedDpr});
    applied = true;
  } catch (failure) {
    error = String(failure);
  }
  function surfaces(scope = document, result = []) {
    for (const element of scope.querySelectorAll('*')) {
      if (element.tagName === 'CANVAS') {
        const rect = element.getBoundingClientRect();
        result.push({width: element.width, height: element.height,
          cssWidth: rect.width, cssHeight: rect.height,
          pixels: element.width * element.height});
      }
      if (element.shadowRoot) surfaces(element.shadowRoot, result);
    }
    return result;
  }
  window.CannonballProofBootstrap = {
    snapshot() {
      const canvases = surfaces();
      return {
        pixelBudget, quality, capApplied: applied, capError: error,
        capScope: 'whole Flutter root including HUD',
        nativeDpr: nativeDpr(), effectiveDpr: window.devicePixelRatio,
        viewportScale: window.visualViewport?.scale || 1,
        viewport: {width: innerWidth, height: innerHeight},
        canvases,
        largestCanvasPixels: Math.max(0, ...canvases.map(canvas => canvas.pixels)),
        visibility: document.visibilityState, focused: document.hasFocus(),
      };
    },
  };
})();
