// Evaluate in a foreground ?proof=1 page after artwork is ready.
// No screenshot work runs during the sample. Counts are NOT presented-frame FPS.
(async () => {
  const proof = window.CannonballProof;
  if (!proof || !proof.snapshot().assetsReady) return {error: 'Proof artwork is not ready'};
  proof.reset();
  proof.start();
  return new Promise(resolve => {
    const warmupMs = 1500, sampleMs = 8000;
    const started = performance.now();
    const intervals = [];
    let before = null, sampleStart = null, last = null, finished = false;
    const timeout = setTimeout(() => finish('Timed out; inspect tab visibility and pause state'), 20000);
    function finish(error = null) {
      if (finished) return;
      finished = true;
      clearTimeout(timeout);
      const after = proof.snapshot();
      const wallMs = sampleStart === null ? 0 : performance.now() - sampleStart;
      const sorted = [...intervals].sort((a, b) => a - b);
      const percentile = p => sorted.length ? sorted[Math.min(sorted.length - 1, Math.floor(sorted.length * p))] : null;
      const renders = before ? after.renderCount - before.renderCount : 0;
      resolve({
        error, measurement: 'Render invocations and browser scheduling; not presented-frame FPS',
        wallMs, renders, renderCallsPerSecond: wallMs > 0 ? renders * 1000 / wallMs : 0,
        updates: before ? after.updateCount - before.updateCount : 0,
        simulationSeconds: before ? after.simClock - before.simClock : 0,
        rafCallbacks: intervals.length, rafCallbacksPerSecond: wallMs > 0 ? intervals.length * 1000 / wallMs : 0,
        p50IntervalMs: percentile(.5), p95IntervalMs: percentile(.95), p99IntervalMs: percentile(.99),
        maxIntervalMs: sorted.at(-1) ?? null,
        renderCommandCpuMs: before ? (after.renderCommandCpuMicros - before.renderCommandCpuMicros) / 1000 : null,
        updateCpuMs: before ? (after.updateCpuMicros - before.updateCpuMicros) / 1000 : null,
        before, after,
        crossOriginIsolated, userAgent: navigator.userAgent,
      });
    }
    function frame(time) {
      if (finished) return;
      if (time - started >= warmupMs) {
        if (before === null) {
          before = proof.snapshot();
          sampleStart = time;
        } else {
          intervals.push(time - last);
        }
      }
      last = time;
      if (sampleStart !== null && time - sampleStart >= sampleMs) finish();
      else requestAnimationFrame(frame);
    }
    requestAnimationFrame(frame);
  });
})()
