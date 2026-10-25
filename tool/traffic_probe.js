// Evaluate in an initialized foreground ?proof=1 page. This is a smoke driver,
// not player AI or traffic injection. It only calls the public proof inputs.
(async () => {
  const proof = window.CannonballProof;
  if (!proof?.snapshot().assetsReady) return {error: 'Artwork not ready'};
  proof.reset();
  proof.start();
  const trace = [];
  let lastRecorded = -1;
  return new Promise(resolve => {
    const timer = setInterval(() => {
      const s = proof.snapshot();
      const ahead = s.traffic.filter(t => t.distance > -20 && t.distance < 550)
        .sort((a, b) => a.distance - b.distance)[0];
      const target = Math.max(-.82, Math.min(.82, ahead ? ahead.x + (ahead.x > 0 ? -.4 : .4) : 0));
      proof.drive(Math.max(-1, Math.min(1, (target - s.playerX) * 3 + s.roadCurve * .14)), false);
      if (s.simClock - lastRecorded >= 1) {
        lastRecorded = s.simClock;
        trace.push({time: s.simClock, speed: s.speedMph, playerX: s.playerX,
          cars: s.traffic.length, reactions: s.trafficReactions,
          incidents: s.trafficIncidents, nearest: ahead?.distance});
      }
      if (s.simClock >= 65 || s.state === 'complete') {
        clearInterval(timer);
        clearTimeout(timeout);
        proof.pause(true);
        resolve({trace, final: s});
      }
    }, 50);
    const timeout = setTimeout(() => {
      clearInterval(timer);
      proof.pause(true);
      resolve({error: 'No 65-second foreground completion within 100 wall seconds', trace});
    }, 100000);
  });
})()
