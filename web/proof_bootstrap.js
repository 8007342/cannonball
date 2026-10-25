/* Painted app browser pixel budget. Load synchronously before Flutter bootstrap.
 * Flutter 3.47 reads window.devicePixelRatio; it has no public loader DPR option.
 * This prototype caps the whole Flutter root, including its HUD. Browser input
 * stays in CSS pixels. The painted prototype is now the default app.
 */
(() => {
  'use strict';
  if (window.CannonballProofBootstrap) return;
  const quality = new URLSearchParams(location.search).get('quality') === 'detail' ? 'detail' : 'smooth';
  const pixelBudget = quality === 'detail' ? 960 * 540 : 720 * 405;
  const original = Object.getOwnPropertyDescriptor(window, 'devicePixelRatio');
  const initialDpr = window.devicePixelRatio || 1;
  const positive = (value, fallback = 1) => Number.isFinite(value) && value > 0 ? value : fallback;
  const nativeDpr = () => positive(original?.get ? original.get.call(window) : initialDpr);
  const requestedDpr = () => {
    const area = positive(innerWidth * innerHeight);
    const viewportScale = positive(window.visualViewport?.scale);
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
          cssLeft: rect.left ?? rect.x ?? 0, cssTop: rect.top ?? rect.y ?? 0,
          pixels: element.width * element.height});
      }
      if (element.shadowRoot) surfaces(element.shadowRoot, result);
    }
    return result;
  }
  window.CannonballProofBootstrap = {
    snapshot() {
      const canvases = surfaces();
      // CSS display extent and backing pixels answer different questions. A
      // fixed low-resolution buffer can correctly fill a resized viewport.
      const largestDisplay = canvases.reduce((best, canvas) =>
        !best || canvas.cssWidth * canvas.cssHeight > best.cssWidth * best.cssHeight ? canvas : best, null);
      let surfaceCoverage = null;
      if (largestDisplay) {
        const surface = largestDisplay;
        const overlapWidth = Math.max(0, Math.min(innerWidth, surface.cssLeft + surface.cssWidth) - Math.max(0, surface.cssLeft));
        const overlapHeight = Math.max(0, Math.min(innerHeight, surface.cssTop + surface.cssHeight) - Math.max(0, surface.cssTop));
        surfaceCoverage = {
          layoutAreaRatio: overlapWidth * overlapHeight / positive(innerWidth * innerHeight),
          sizeMatchesLayout: Math.abs(surface.cssWidth - innerWidth) <= 2 && Math.abs(surface.cssHeight - innerHeight) <= 2,
          originMatchesLayout: Math.abs(surface.cssLeft) <= 2 && Math.abs(surface.cssTop) <= 2,
        };
      }
      const visual = window.visualViewport;
      return {
        pixelBudget, quality, capApplied: applied, capError: error,
        capScope: 'whole Flutter root including HUD',
        nativeDpr: nativeDpr(), effectiveDpr: window.devicePixelRatio,
        viewportScale: positive(visual?.scale),
        viewport: {width: innerWidth, height: innerHeight},
        outerWindow: {width: window.outerWidth ?? null, height: window.outerHeight ?? null},
        visualViewport: visual ? {width: visual.width ?? null, height: visual.height ?? null,
          offsetLeft: visual.offsetLeft ?? 0, offsetTop: visual.offsetTop ?? 0, scale: positive(visual.scale)} : null,
        documentClient: {width: document.documentElement?.clientWidth ?? null,
          height: document.documentElement?.clientHeight ?? null},
        surfaceCoverage,
        canvases,
        largestCanvasPixels: Math.max(0, ...canvases.map(canvas => canvas.pixels)),
        visibility: document.visibilityState, focused: document.hasFocus(),
      };
    },
  };
})();
