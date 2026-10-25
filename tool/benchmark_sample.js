// Paste/evaluate in a foreground renderer_benchmark.dart browser page.
// Measures 3 seconds after 0.5 second warm-up. No screenshot capture.
(async () => {
  if (typeof window.cannonballReadBenchmarkStats !== 'function') {
    return {error: 'Benchmark Dart entry point is not ready'};
  }
  window.cannonballResetBenchmark();
  return new Promise(resolve => {
    const start = performance.now();
    let last = start, capturedAt = null, before = null;
    const intervals = [];
    function next(t) {
      if (t - start >= 500) {
        if (capturedAt === null) {
          capturedAt = t;
          before = window.cannonballReadBenchmarkStats();
        } else intervals.push(t - last);
      }
      last = t;
      if (capturedAt === null || t - capturedAt < 3000) {
        requestAnimationFrame(next);
        return;
      }
      const after = window.cannonballReadBenchmarkStats();
      const wallMs = t - capturedAt;
      const ordered = intervals.slice().sort((a, b) => a - b);
      const q = p => ordered[Math.min(ordered.length - 1, Math.floor(ordered.length * p))];
      const renders = after.renders - before.renders;
      resolve({
        compiledToWasm: after.compiledToWasm, seed: after.seed,
        cssViewport: [innerWidth, innerHeight], dpr: devicePixelRatio,
        crossOriginIsolated, visibility: document.visibilityState,
        wallMs, rafIntervals: intervals.length,
        rafHz: intervals.length * 1000 / wallMs,
        renders, rendersPerSecond: renders * 1000 / wallMs,
        updates: after.updates - before.updates,
        p50IntervalMs: q(.5), p95IntervalMs: q(.95), p99IntervalMs: q(.99),
        maxIntervalMs: ordered.at(-1),
        simulationSeconds: after.simulationSeconds - before.simulationSeconds,
        updateCpuMs: (after.updateCpuUs - before.updateCpuUs) / 1000,
        renderCommandCpuMs: (after.renderCommandCpuUs - before.renderCommandCpuUs) / 1000,
        before, after,
        wasmResources: performance.getEntriesByType('resource')
          .map(e => e.name).filter(name => /\.wasm(?:\?|$)/.test(name)),
        userAgent: navigator.userAgent,
      });
    }
    requestAnimationFrame(next);
  });
})()
