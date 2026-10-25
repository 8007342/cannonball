/* Cannonball browser adapters. Original oscillator score; no Web MIDI hardware. */
(() => {
  'use strict';
  const root = globalThis;
  const radians = Math.PI / 180;
  const clamp = (value, low, high) => Math.min(high, Math.max(low, value));
  const signedAngle = (value) => ((value + 180) % 360 + 360) % 360 - 180;

  // Third row of the W3C device rotation matrix projects world-up into the
  // device frame. Rotate that vector into screen axes before finding roll.
  // This avoids raw beta discontinuities and works in both landscape directions.
  function screenRoll(beta, gamma, angle) {
    if (!Number.isFinite(beta) || !Number.isFinite(gamma)) return null;
    const b = beta * radians, g = gamma * radians, a = angle * radians;
    const x = -Math.cos(b) * Math.sin(g), y = Math.sin(b);
    const screenX = x * Math.cos(a) + y * Math.sin(a);
    const screenY = y * Math.cos(a) - x * Math.sin(a);
    // A face-up device has no useful gravity direction in the screen plane.
    if (Math.hypot(screenX, screenY) < 0.15) return null;
    return -Math.atan2(screenX, screenY) / radians;
  }
  if (typeof module !== 'undefined') module.exports = {screenRoll, signedAngle};
  if (!root.document) return;

  const doc = root.document;
  const now = () => root.performance.now();
  const orientationAngle = () => root.screen?.orientation?.angle ?? root.orientation ?? 0;
  const landscape = () => root.innerWidth >= root.innerHeight;
  let callbacks = {}, listening = false, lastOrientation = orientationAngle();
  let sensorGeneration = 0, sensorTimer = null, sensorWatchdog = null;
  let sensorListener = null, sensorResolve = null, tiltEnabled = false;

  function disableTilt() {
    sensorGeneration++;
    if (sensorListener) root.removeEventListener('deviceorientation', sensorListener);
    root.clearTimeout(sensorTimer);
    root.clearInterval(sensorWatchdog);
    sensorTimer = sensorWatchdog = sensorListener = null;
    if (sensorResolve) sensorResolve(false);
    sensorResolve = null;
    tiltEnabled = false;
    callbacks.tilt?.(0);
    callbacks.tiltStatus?.(false);
  }

  async function enableTilt() {
    disableTilt();
    const generation = sensorGeneration;
    if (!root.isSecureContext || !root.DeviceOrientationEvent || !landscape()) return false;
    try {
      if (typeof root.DeviceOrientationEvent.requestPermission === 'function') {
        const permission = await root.DeviceOrientationEvent.requestPermission();
        if (permission !== 'granted' || generation !== sensorGeneration) return false;
      }
    } catch (_) { return false; }
    if (generation !== sensorGeneration) return false;
    return new Promise((resolve) => {
      sensorResolve = resolve;
      let firstAt = null, lastAt = now(), sinSum = 0, cosSum = 0, samples = 0;
      let neutral = 0, filtered = 0;
      const angle = orientationAngle();
      sensorListener = (event) => {
        if (angle !== orientationAngle()) { disableTilt(); return; }
        const roll = screenRoll(event.beta, event.gamma, angle);
        if (roll === null) return;
        const time = now(), elapsed = Math.max(0.001, (time - lastAt) / 1000);
        lastAt = time;
        if (!tiltEnabled) {
          firstAt ??= time;
          sinSum += Math.sin(roll * radians);
          cosSum += Math.cos(roll * radians);
          samples++;
          if (time - firstAt < 250 || samples < 3) return;
          neutral = Math.atan2(sinSum, cosSum) / radians;
          tiltEnabled = true;
          root.clearTimeout(sensorTimer);
          sensorResolve = null;
          callbacks.tiltStatus?.(true);
          resolve(true);
          return;
        }
        let target = clamp(signedAngle(roll - neutral) / 28, -1, 1);
        target = Math.abs(target) < 0.025 ? 0 : target;
        filtered += (target - filtered) * (1 - Math.exp(-elapsed / 0.09));
        callbacks.tilt?.(filtered);
      };
      root.addEventListener('deviceorientation', sensorListener);
      sensorTimer = root.setTimeout(disableTilt, 1800);
      sensorWatchdog = root.setInterval(() => {
        if (tiltEnabled && now() - lastAt > 1600) disableTilt();
      }, 400);
    });
  }

  let context = null, master = null, engine = null, engineGain = null;
  let audioTimer = null, nextNote = 0, step = 0, muted = false, paused = true;
  let speed = 0, intensity = 0, region = 'Atlantic', activeRegion = '';
  let theme = null, voice = null, speechEpoch = 0, speechTimer = null;
  let proofAudio = false, radioPhase = 'music', radioTimer = null, radioEpoch = 0;
  let radioStation = '', lastRadioText = '', reportCount = 0;
  const proofTracks = {
    City: {root: 57, notes: [0, 7, 12, 11, 7, 4, 2, 7], chords: [0, 5, 9, 7], bpm: 146, style: 'synthpop'},
    Forest: {root: 55, notes: [0, 4, 7, 9, 7, 4, 2, 0], chords: [0, 5, 0, 7], bpm: 138, style: 'country'},
    Mountain: {root: 52, notes: [0, 0, 7, 10, 0, 12, 10, 7], chords: [0, 3, 5, 7], bpm: 154, style: 'metal'},
  };
  const activeNodes = new Set();
  const garageNodes = new Set();
  let lastGarageCue = null, lastGarageAt = -100;
  const themes = [
    {root: 57, notes: [0, 4, 7, 9, 7, 4, 2, 4], chords: [0, 5, 9, 7]},
    {root: 60, notes: [0, 3, 7, 10, 7, 5, 3, 7], chords: [0, 5, 3, 7]},
    {root: 55, notes: [0, 2, 4, 7, 9, 7, 4, 2], chords: [0, 7, 5, 0]},
    {root: 62, notes: [0, 3, 5, 7, 10, 7, 5, 3], chords: [0, 5, 7, 3]},
  ];
  const frequency = (note) => 440 * 2 ** ((note - 69) / 12);

  function selectTheme(name) {
    if (proofAudio) return proofTracks[name] || proofTracks.City;
    const index = Array.from(name).reduce((sum, c) => (sum * 31 + c.charCodeAt(0)) >>> 0, 0);
    return themes[index % themes.length];
  }

  function note(pitch, time, duration, volume, shape = 'triangle') {
    const oscillator = context.createOscillator(), gain = context.createGain();
    oscillator.type = shape;
    oscillator.frequency.value = frequency(pitch);
    gain.gain.setValueAtTime(0, time);
    gain.gain.linearRampToValueAtTime(volume, time + 0.012);
    gain.gain.exponentialRampToValueAtTime(0.0001, time + duration);
    oscillator.connect(gain).connect(master);
    activeNodes.add(oscillator);
    oscillator.onended = () => {
      activeNodes.delete(oscillator);
      oscillator.disconnect();
      gain.disconnect();
    };
    oscillator.start(time);
    oscillator.stop(time + duration + 0.02);
  }

  function kick(time) {
    const oscillator = context.createOscillator(), gain = context.createGain();
    oscillator.frequency.setValueAtTime(135, time);
    oscillator.frequency.exponentialRampToValueAtTime(38, time + 0.13);
    gain.gain.setValueAtTime(0.13, time);
    gain.gain.exponentialRampToValueAtTime(0.0001, time + 0.17);
    oscillator.connect(gain).connect(master);
    activeNodes.add(oscillator);
    oscillator.onended = () => { activeNodes.delete(oscillator); oscillator.disconnect(); gain.disconnect(); };
    oscillator.start(time);
    oscillator.stop(time + 0.19);
  }

  function scheduleMusic() {
    if (!context || paused || muted || doc.hidden || context.state !== 'running' || radioPhase !== 'music') return;
    // Timers only queue a short lookahead; audio nodes use the audio clock.
    if (nextNote < context.currentTime) nextNote = context.currentTime + 0.025;
    while (nextNote < context.currentTime + 0.12) {
      if (step % 16 === 0 && region !== activeRegion) {
        activeRegion = region;
        theme = selectTheme(region);
      }
      theme ??= selectTheme(region);
      const chord = theme.chords[Math.floor(step / 16) % 4];
      if (step % 4 === 0) {
        note(theme.root - 12 + chord, nextNote, 0.25, 0.11, theme.style === 'metal' ? 'sawtooth' : 'triangle');
        kick(nextNote);
      }
      if (step % 2 === 0) {
        note(theme.root + 12 + theme.notes[(step / 2) % 8], nextNote, 0.18,
          0.045 + intensity * 0.025, 'triangle');
      }
      if (intensity > 0.45 && step % 2 === 1) {
        note(theme.root + 24 + theme.notes[Math.floor(step / 2) % 8], nextNote, 0.07, 0.018, 'square');
      }
      if (proofAudio && theme.style === 'country' && step % 4 === 2) {
        note(theme.root + chord + 7, nextNote, 0.10, 0.065, 'triangle');
      }
      if (proofAudio && theme.style === 'metal' && step % 2 === 0) {
        note(theme.root - 12 + chord + 7, nextNote, 0.09, 0.055, 'sawtooth');
      }
      if (step % 16 === 0) {
        for (const interval of [0, 7, 12]) note(theme.root + chord + interval, nextNote, 1.6, 0.026, 'sine');
      }
      nextNote += 60 / (theme.bpm || (116 + intensity * 20)) / 4;
      step = (step + 1) % 64;
    }
  }

  function cancelSpeech() {
    speechEpoch++;
    root.clearTimeout(speechTimer);
    speechTimer = null;
    root.speechSynthesis?.cancel();
  }

  function updateVolume() {
    if (!context || !master) return;
    const silent = muted || paused || doc.hidden;
    master.gain.cancelScheduledValues(context.currentTime);
    master.gain.setTargetAtTime(silent ? 0 : 0.32, context.currentTime, 0.025);
  }

  async function beginAudio() {
    try {
      if (!context) {
        const AudioContext = root.AudioContext || root.webkitAudioContext;
        if (!AudioContext) return false;
        context = new AudioContext();
        master = context.createGain();
        master.gain.value = 0;
        master.connect(context.destination);
        engine = context.createOscillator();
        engine.type = 'sawtooth';
        engine.frequency.value = 38;
        engineGain = context.createGain();
        engineGain.gain.value = 0.025;
        const filter = context.createBiquadFilter();
        filter.type = 'lowpass';
        filter.frequency.value = 420;
        engine.connect(filter).connect(engineGain).connect(master);
        engine.start();
        audioTimer = root.setInterval(scheduleMusic, 25);
      }
      await context.resume();
      nextNote = context.currentTime + 0.035;
      updateVolume();
      return context.state === 'running';
    } catch (_) { return false; }
  }

  function setAudioState(nextSpeed, nextIntensity, nextRegion) {
    speed = Number.isFinite(nextSpeed) ? clamp(nextSpeed, 0, 1) : 0;
    intensity = Number.isFinite(nextIntensity) ? clamp(nextIntensity, 0, 1) : 0;
    region = typeof nextRegion === 'string' ? nextRegion : 'Atlantic';
    if (engine && context) {
      engine.frequency.setTargetAtTime(38 + speed * 130, context.currentTime, 0.09);
      engineGain.gain.setTargetAtTime(0.025 + speed * 0.03, context.currentTime, 0.09);
    }
  }

  function chooseVoice() {
    const voices = root.speechSynthesis?.getVoices() || [];
    voice = voices.find((entry) => entry.lang === 'en-US' && entry.localService) ||
      voices.find((entry) => entry.lang?.startsWith('en')) || null;
  }

  function say(text, complete = () => {}) {
    if (muted || paused || doc.hidden || !root.speechSynthesis || !root.SpeechSynthesisUtterance) { complete(); return; }
    if (typeof text !== 'string' || !text.trim()) { complete(); return; }
    cancelSpeech(); // Latest state-derived instruction wins; no blocking queue.
    chooseVoice(); // Voices may arrive after page initialization.
    const utterance = new root.SpeechSynthesisUtterance(text.slice(0, 320));
    if (voice) utterance.voice = voice;
    utterance.lang = 'en-US';
    utterance.rate = 1.06;
    utterance.volume = 0.8;
    const epoch = speechEpoch;
    let finished = false;
    const finish = () => {
      if (finished || epoch !== speechEpoch) return;
      finished = true;
      root.clearTimeout(speechTimer);
      speechTimer = null;
      complete();
    };
    utterance.onend = utterance.onerror = finish;
    try {
      root.speechSynthesis.speak(utterance);
      speechTimer = root.setTimeout(() => {
        if (epoch === speechEpoch) { finish(); cancelSpeech(); }
      }, 12000);
    } catch (_) { finish(); /* Captions remain authoritative when speech fails. */ }
  }


  function cancelGarage() {
    for (const node of [...garageNodes]) { try { node.stop(); } catch (_) {} }
    garageNodes.clear();
  }

  function garageCue(cue) {
    if (!context || muted || doc.hidden || context.state !== 'running') return;
    if (cue === lastGarageCue && context.currentTime - lastGarageAt < .25) return;
    lastGarageCue = cue;
    lastGarageAt = context.currentTime;
    // The prelap is deliberately outside the paused music bus. Node lifetimes
    // use the audio clock, and mute/hidden/dispose explicitly stop this bus.
    function tone(from, to, delay, duration, volume, shape = 'triangle') {
      const oscillator = context.createOscillator(), gain = context.createGain();
      const at = context.currentTime + delay;
      oscillator.type = shape;
      oscillator.frequency.setValueAtTime(from, at);
      oscillator.frequency.exponentialRampToValueAtTime(to, at + duration * .85);
      gain.gain.setValueAtTime(.0001, at);
      gain.gain.linearRampToValueAtTime(volume, at + .012);
      gain.gain.exponentialRampToValueAtTime(.0001, at + duration);
      oscillator.connect(gain).connect(context.destination);
      garageNodes.add(oscillator);
      oscillator.onended = () => { garageNodes.delete(oscillator); oscillator.disconnect(); gain.disconnect(); };
      oscillator.start(at);
      oscillator.stop(at + duration + .02);
    }
    if (cue === 'keys') {
      [93, 102, 97].forEach((pitch, index) =>
        tone(frequency(pitch), frequency(pitch - 2), index * .04, .13, .022, 'sine'));
    } else if (cue === 'door') {
      tone(115, 43, 0, .17, .04);
      tone(70, 34, .10, .12, .025);
    } else if (cue === 'cabin' || cue === 'ignition') {
      // Three brief starter pulses catch into an idling engine harmonic.
      for (let i = 0; i < 3; i++) tone(52, 66, i * .12, .13, .017, 'sawtooth');
      tone(58, 76, .30, .75, .024, 'sawtooth');
      tone(116, 152, .30, .70, .009, 'triangle');
    } else if (cue === 'rear') {
      tone(76, 88, 0, .65, .018, 'sawtooth');
    } else if (cue === 'launch') {
      tone(82, 220, 0, .90, .033, 'sawtooth');
      tone(164, 440, 0, .78, .011, 'triangle');
    }
  }

  function stopMusic() {
    // Engine oscillator is deliberately outside activeNodes and keeps running.
    for (const node of [...activeNodes]) { try { node.stop(); } catch (_) {} }
    activeNodes.clear();
  }

  function cancelRadio() {
    radioEpoch++;
    root.clearTimeout(radioTimer);
    radioTimer = null;
    radioPhase = 'music';
  }

  function tuningNoise() {
    if (!context || !master || muted || paused) return;
    if (context.createBuffer && context.createBufferSource) {
      const length = Math.floor(context.sampleRate * .18);
      const buffer = context.createBuffer(1, length, context.sampleRate);
      const data = buffer.getChannelData(0);
      let state = 731;
      for (let i = 0; i < data.length; i++) {
        state = (state * 48271) % 2147483647;
        data[i] = (state / 2147483647 * 2 - 1) * .16;
      }
      const source = context.createBufferSource(), filter = context.createBiquadFilter();
      source.buffer = buffer;
      filter.type = 'bandpass';
      filter.frequency.value = 1700;
      source.connect(filter).connect(master);
      activeNodes.add(source);
      source.onended = () => { activeNodes.delete(source); source.disconnect(); filter.disconnect(); };
      source.start();
    } else {
      // Audio test harnesses/older adapters can still produce the tuning chirp.
      note(96, context.currentTime, .045, .03, 'sawtooth');
      note(81, context.currentTime + .07, .05, .025, 'square');
    }
  }

  function radioBreak(text, station) {
    if (!proofAudio || typeof text !== 'string' || !text.trim()) return;
    cancelRadio();
    cancelSpeech();
    lastRadioText = text.slice(0, 320);
    radioStation = typeof station === 'string' ? station : 'City';
    reportCount++;
    region = radioStation;
    if (muted || paused || doc.hidden || !context) return;
    stopMusic();
    radioPhase = 'tuning';
    tuningNoise();
    const epoch = radioEpoch;
    radioTimer = root.setTimeout(() => {
      radioTimer = null;
      if (epoch !== radioEpoch || muted || paused || doc.hidden) return;
      radioPhase = 'report';
      say(lastRadioText, () => {
        if (epoch !== radioEpoch) return;
        radioPhase = 'music';
        activeRegion = region;
        theme = selectTheme(region);
        step = 0;
        if (context) nextNote = context.currentTime + .025;
      });
    }, 230);
  }

  function setProofAudio(value) {
    proofAudio = Boolean(value);
    cancelRadio();
    activeRegion = '';
    theme = null;
    step = 0;
    reportCount = 0;
    lastRadioText = radioStation = '';
  }

  function pause(value) {
    paused = Boolean(value);
    if (paused) { cancelSpeech(); cancelRadio(); cancelGarage(); }
    updateVolume();
    if (context && !paused) {
      // Resume may still be blocked without a gesture; captions remain usable.
      context.resume().then(() => { nextNote = context.currentTime + 0.035; }).catch(() => {});
    }
  }

  function onVisibility() {
    if (doc.hidden) {
      disableTilt();
      pause(true);
    }
    callbacks.visibility?.(Boolean(doc.hidden));
  }
  function onOrientation() {
    const angle = orientationAngle();
    if (angle !== lastOrientation) disableTilt();
    lastOrientation = angle;
    if (!landscape()) pause(true);
    callbacks.orientation?.(landscape());
  }

  let googleLoader = null, googleRenderGeneration = 0;
  function loadGoogle() {
    if (root.google?.accounts?.id) return Promise.resolve();
    if (googleLoader) return googleLoader;
    googleLoader = new Promise((resolve, reject) => {
      const script = doc.createElement('script');
      script.src = 'https://accounts.google.com/gsi/client';
      script.async = true;
      let settled = false;
      const timeout = root.setTimeout(() => finish(false), 12000);
      function finish(success) {
        if (settled) return;
        settled = true;
        root.clearTimeout(timeout);
        script.onload = script.onerror = null;
        if (success && root.google?.accounts?.id) resolve();
        else { script.remove(); reject(new Error('Google sign-in could not load. Check the connection and try again.')); }
      }
      script.onload = () => finish(true);
      script.onerror = () => finish(false);
      doc.head.appendChild(script);
    }).catch((error) => { googleLoader = null; throw error; });
    return googleLoader;
  }

  function renderGoogleButton(element, clientId, nonce, credential, error) {
    const generation = ++googleRenderGeneration;
    if (!element || !clientId || !nonce) { error('Google sign-in is not configured for this site.'); return; }
    const connected = new Promise((resolve) => {
      const deadline = now() + 2000;
      function check() {
        if (generation !== googleRenderGeneration || element.isConnected || now() >= deadline) resolve();
        else root.setTimeout(check, 30);
      }
      check();
    });
    Promise.all([loadGoogle(), connected]).then(() => {
      if (generation !== googleRenderGeneration || !element.isConnected) return;
      root.google.accounts.id.initialize({
        client_id: clientId,
        nonce,
        ux_mode: 'popup',
        auto_select: false,
        callback: (response) => {
          if (generation !== googleRenderGeneration || !element.isConnected) return;
          if (typeof response.credential === 'string' && response.credential) credential(response.credential);
          else error('Google did not return a sign-in credential. Please try again.');
        },
      });
      element.replaceChildren();
      root.google.accounts.id.renderButton(element, {
        type: 'standard', theme: 'outline', size: 'large', text: 'signin_with', width: 280,
      });
    }).catch((failure) => {
      if (generation === googleRenderGeneration && element.isConnected) error(failure.message);
    });
  }

  root.CannonballPlatform = {
    get reducedMotion() { return root.matchMedia?.('(prefers-reduced-motion: reduce)').matches ?? false; },
    initialize(tilt, visibility, orientation, tiltStatus) {
      callbacks = {tilt, visibility, orientation, tiltStatus};
      if (listening) return;
      listening = true;
      doc.addEventListener('visibilitychange', onVisibility);
      root.addEventListener('resize', onOrientation);
      root.addEventListener('orientationchange', onOrientation);
      root.screen?.orientation?.addEventListener('change', onOrientation);
      root.speechSynthesis?.addEventListener('voiceschanged', chooseVoice);
      chooseVoice();
    },
    enableTilt, disableTilt, beginAudio, setAudioState, say, pause, renderGoogleButton,
    setProofAudio, radioBreak, garageCue,
    audioSnapshot() {
      return {proofAudio, phase: radioPhase, station: radioStation, reportCount,
        lastRadioText, trackStyle: theme?.style || 'prototype',
        speechMode: 'device TTS fallback; no regional accent guarantee'};
    },
    setMuted(value) {
      muted = Boolean(value);
      if (muted) { cancelSpeech(); cancelRadio(); cancelGarage(); }
      updateVolume();
    },
    async requestLandscape() {
      try {
        if (!doc.fullscreenElement && doc.documentElement.requestFullscreen) {
          await doc.documentElement.requestFullscreen();
        }
        if (root.screen?.orientation?.lock) await root.screen.orientation.lock('landscape');
      } catch (_) { /* Unsupported orientation locking leaves the rotate prompt. */ }
      return landscape();
    },
    dispose() {
      cancelGarage();
      lastGarageCue = null;
      lastGarageAt = -100;
      disableTilt();
      cancelSpeech();
      cancelRadio();
      proofAudio = false;
      googleRenderGeneration++;
      doc.removeEventListener('visibilitychange', onVisibility);
      root.removeEventListener('resize', onOrientation);
      root.removeEventListener('orientationchange', onOrientation);
      root.screen?.orientation?.removeEventListener('change', onOrientation);
      root.speechSynthesis?.removeEventListener('voiceschanged', chooseVoice);
      root.clearInterval(audioTimer);
      for (const node of activeNodes) { try { node.stop(); } catch (_) {} }
      activeNodes.clear();
      if (engine) { try { engine.stop(); } catch (_) {} }
      if (context) context.close().catch(() => {});
      context = master = engine = engineGain = audioTimer = null;
      paused = true;
      activeRegion = '';
      step = 0;
      listening = false;
      callbacks = {};
    },
  };
})();
