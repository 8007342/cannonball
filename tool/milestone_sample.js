// Evaluate in a foreground ?proof=1 page. To sample an already reached section:
// window.CannonballMilestoneSampleOptions={start:false,sampleMs:4000,label:'crest'};
// Start this expression asynchronously and poll its result; no screenshots run.
(async () => {
  const proof = window.CannonballProof;
  const options = window.CannonballMilestoneSampleOptions || {};
  const milliseconds = (value, fallback, min, max) => value == null || !Number.isFinite(Number(value))
    ? fallback : Math.max(min, Math.min(max, Number(value)));
  const sampleMs = milliseconds(options.sampleMs, 4000, 500, 30000);
  const warmupMs = milliseconds(options.warmupMs, 1000, 0, 5000);
  if (!proof?.snapshot().assetsReady) return {error: 'Proof artwork is not ready'};
  if (options.start !== false) { proof.reset(); proof.start(); }
  if (proof.snapshot().state !== 'driving') return {error: 'Start or resume driving before sampling'};
  return new Promise(resolve => {
    let sampleStart = null, before = null, previous = null, done = false;
    const started = performance.now(), intervals = [];
    const timeout = setTimeout(() => finish('Timed out: inspect visibility, pause and window state'), warmupMs + sampleMs + 5000);
    function onVisibility() { if (document.hidden) finish('Tab became hidden'); }
    document.addEventListener('visibilitychange', onVisibility);
    function finish(error = null) {
      if (done) return;
      done = true;
      clearTimeout(timeout);
      document.removeEventListener('visibilitychange', onVisibility);
      const after = proof.snapshot();
      const wallMs = sampleStart === null ? 0 : performance.now() - sampleStart;
      const sorted = [...intervals].sort((a,b) => a-b);
      const percentile = p => sorted.length ? sorted[Math.min(sorted.length-1,Math.floor(sorted.length*p))] : null;
      const renders = before ? after.renderCount-before.renderCount : 0;
      const simulationSeconds = before ? after.simClock-before.simClock : 0;
      const sectionBefore = before?.courseSection ?? null, sectionAfter = after.courseSection ?? null;
      const renderedMs = before ? (after.renderCommandCpuMicros-before.renderCommandCpuMicros)/1000 : null;
      resolve({error, label: options.label ?? null,
        measurement:'Render calls and rAF scheduling, not presented-frame FPS or physical input latency',
        wallMs, simulationSeconds, simulationToWallRatio: wallMs > 0 ? simulationSeconds*1000/wallMs : null,
        renders, renderCallsPerSecond: wallMs > 0 ? renders*1000/wallMs : null,
        rafCallbacks: intervals.length, p50IntervalMs:percentile(.5),p95IntervalMs:percentile(.95),p99IntervalMs:percentile(.99),
        maxIntervalMs:sorted.at(-1) ?? null, renderCommandCpuMs:renderedMs,
        meanRenderCommandCpuMs:renders > 0 ? renderedMs/renders : null,
        sectionBefore,sectionAfter,sameSection:sectionBefore === null || sectionAfter === null ? null : sectionBefore === sectionAfter,
        viewportStable:before ? JSON.stringify(before.browser?.viewport) === JSON.stringify(after.browser?.viewport) : null,
        before,after,userAgent:navigator.userAgent,crossOriginIsolated,
      });
    }
    function frame(now) {
      if (done) return;
      if (now-started >= warmupMs) {
        if (before === null) { before=proof.snapshot();sampleStart=now; }
        else intervals.push(now-previous);
      }
      previous=now;
      if (sampleStart !== null && now-sampleStart >= sampleMs) finish();
      else requestAnimationFrame(frame);
    }
    requestAnimationFrame(frame);
  });
})()
