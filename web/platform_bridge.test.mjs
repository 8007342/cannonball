import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import test from 'node:test';
import vm from 'node:vm';

const source = readFileSync(new URL('./platform_bridge.js', import.meta.url), 'utf8');
const flush = async () => { for (let i = 0; i < 6; i++) await Promise.resolve(); };

function harness({prepared = false} = {}) {
  let time = 0, timerId = 0;
  const timers = new Map(), listeners = new Map(), docListeners = new Map();
  const spoken = [], oscillatorNotes = [], scripts = [], preparedReports = [], snippetCalls = [];
  let cancelled = 0;
  const add = (map) => (name, callback) => map.set(name, callback);
  const remove = (map) => (name, callback) => { if (map.get(name) === callback) map.delete(name); };
  const parameter = () => ({value: 0, events: [],
    setValueAtTime(value, at) { this.value = value; this.events.push({method: 'set', value, at}); },
    linearRampToValueAtTime(value, at) { this.events.push({method: 'linear', value, at}); },
    exponentialRampToValueAtTime(value, at) { this.events.push({method: 'exponential', value, at}); },
    setTargetAtTime(value, at) { this.events.push({method: 'target', value, at}); },
    cancelScheduledValues() {}});
  const node = () => ({connect() { return this; }, disconnect() {},
    start(when) { this.started = when; },
    stop(when) { this.stopped = when; if (when == null || when <= audio.currentTime) this.onended?.(); }});
  const audio = {state: 'running', currentTime: 0, destination: {},
    createGain() { return {...node(), gain: parameter()}; },
    createOscillator() { const oscillator = {...node(), frequency: parameter()}; oscillatorNotes.push(oscillator); return oscillator; },
    createBiquadFilter() { return {...node(), frequency: parameter()}; },
    async resume() { this.state = 'running'; }, async close() { this.state = 'closed'; },
  };
  const document = {hidden: false, fullscreenElement: null, documentElement: {},
    addEventListener: add(docListeners), removeEventListener: remove(docListeners),
    createElement() { return {remove() { this.removed = true; }}; },
    head: {appendChild(script) { scripts.push(script); }},
  };
  const sandbox = {module: {exports: {}}, document, performance: {now: () => time},
    innerWidth: 900, innerHeight: 500, isSecureContext: true,
    DeviceOrientationEvent: {}, screen: {orientation: {angle: 90,
      addEventListener() {}, removeEventListener() {}}},
    addEventListener: add(listeners), removeEventListener: remove(listeners),
    setTimeout(fn, delay) { const id = ++timerId; timers.set(id, {fn, at: time + delay}); return id; },
    clearTimeout(id) { timers.delete(id); },
    setInterval(fn, delay) { const id = ++timerId; timers.set(id, {fn, at: time + delay, delay}); return id; },
    clearInterval(id) { timers.delete(id); },
    AudioContext: function () { return audio; },
    SpeechSynthesisUtterance: function (text) { this.text = text; },
    speechSynthesis: {cancel() { cancelled++; }, speak(value) { spoken.push(value); },
      getVoices() { return []; }, addEventListener() {}, removeEventListener() {}},
  };
  if (prepared) {
    audio.decodeAudioData = async () => ({});
    sandbox.fetch = async () => ({});
    sandbox.CannonballScorePlayer = function () {
      this.state = 'idle';
      this.prepare = async () => true;
      this.play = async () => false;
      this.stopMusic = () => {};
      this.stopVoice = () => {};
      this.playSnippet = station => {snippetCalls.push(station); return true;};
      this.report = async (text, complete) => {preparedReports.push({text, complete}); return true;};
      this.snapshot = () => ({});
      this.dispose = () => {};
    };
  }
  vm.createContext(sandbox);
  vm.runInContext(source, sandbox);
  const tilt = [], statuses = [], hidden = [], orientations = [];
  const bridge = sandbox.CannonballPlatform;
  bridge.initialize((value) => tilt.push(value), (value) => hidden.push(value),
    (value) => orientations.push(value), (value) => statuses.push(value));
  function advance(ms) {
    const end = time + ms;
    for (;;) {
      const next = [...timers].filter(([, value]) => value.at <= end)
        .sort((a, b) => a[1].at - b[1].at)[0];
      if (!next) break;
      const [id, timer] = next;
      time = timer.at;
      audio.currentTime = time / 1000;
      if (timer.delay) timer.at += timer.delay;
      else timers.delete(id);
      timer.fn();
    }
    time = end;
    audio.currentTime = time / 1000;
  }
  return {bridge, sandbox, math: sandbox.module.exports, tilt, statuses, hidden,
    orientations, spoken, scripts, oscillatorNotes, audio, timers, advance, preparedReports, snippetCalls,
    get cancelled() { return cancelled; },
    emit(name, event = {}) { listeners.get(name)?.(event); docListeners.get(name)?.(event); }};
}

async function calibrate(h) {
  const enabled = h.bridge.enableTilt();
  h.emit('deviceorientation', {beta: 0, gamma: 45});
  h.advance(150);
  h.emit('deviceorientation', {beta: 0, gamma: 45});
  h.advance(150);
  h.emit('deviceorientation', {beta: 0, gamma: 45});
  assert.equal(await enabled, true);
}

test('roll uses screen gravity axes and rejects missing/flat readings', () => {
  const {math} = harness();
  assert.equal(math.screenRoll(null, 40, 90), null);
  assert.equal(math.screenRoll(0, 0, 90), null);
  assert.ok(Math.abs(math.screenRoll(0, 45, 90)) < 1e-8);
  const right = math.screenRoll(-10, 45, 90);
  const reversedRight = math.screenRoll(10, -45, 270);
  assert.ok(right > 0);
  assert.ok(Math.abs(right - reversedRight) < 1e-8);
  assert.equal(math.signedAngle(359), -1);
});

test('calibration needs readings; smoothing and stalled sensors restore touch', async () => {
  const h = harness();
  await calibrate(h);
  h.advance(100);
  h.emit('deviceorientation', {beta: -15, gamma: 45});
  assert.ok(h.tilt.at(-1) > 0 && h.tilt.at(-1) < 1);
  h.advance(2000);
  assert.equal(h.statuses.at(-1), false);
  assert.equal(h.tilt.at(-1), 0);
  h.bridge.dispose();
});

test('denied permission and absent events fail without leaving listeners', async () => {
  const h = harness();
  h.sandbox.DeviceOrientationEvent.requestPermission = async () => 'denied';
  assert.equal(await h.bridge.enableTilt(), false);
  h.sandbox.DeviceOrientationEvent.requestPermission = async () => 'granted';
  const pending = h.bridge.enableTilt();
  await flush();
  h.advance(1800);
  assert.equal(await pending, false);
  assert.equal(h.statuses.at(-1), false);
  h.bridge.dispose();
});

test('turning tilt off while permission is pending cannot re-enable it', async () => {
  const h = harness();
  let grant;
  h.sandbox.DeviceOrientationEvent.requestPermission = () => new Promise((resolve) => { grant = resolve; });
  const pending = h.bridge.enableTilt();
  h.bridge.disableTilt();
  grant('granted');
  assert.equal(await pending, false);
  assert.equal(h.timers.size, 0);
});

test('orientation changes and hidden tabs stop tilt and report lifecycle state', async () => {
  const h = harness();
  await calibrate(h);
  h.sandbox.screen.orientation.angle = 270;
  h.emit('orientationchange');
  assert.equal(h.statuses.at(-1), false);
  assert.equal(h.orientations.at(-1), true);
  h.sandbox.document.hidden = true;
  h.emit('visibilitychange');
  assert.equal(h.hidden.at(-1), true);
  h.bridge.dispose();
});

test('audio uses the gesture, queues notes, and mute/pause cancel speech', async () => {
  const h = harness();
  assert.equal(h.oscillatorNotes.length, 0);
  assert.equal(await h.bridge.beginAudio(), true);
  h.bridge.pause(false);
  await flush();
  h.bridge.setAudioState(0.7, 0.8, 'Rockies');
  h.advance(500);
  assert.ok(h.oscillatorNotes.length > 3);
  h.bridge.say('Snow on the next pass.');
  assert.equal(h.spoken.length, 1);
  h.bridge.setMuted(true);
  const cancellations = h.cancelled;
  h.bridge.say('This must remain caption-only.');
  assert.equal(h.spoken.length, 1);
  h.bridge.setMuted(false);
  h.bridge.pause(true);
  assert.ok(h.cancelled > cancellations);
  h.bridge.say('Paused caption.');
  assert.equal(h.spoken.length, 1);
  h.bridge.dispose();
  assert.equal(h.timers.size, 0);
});

test('audio and speech failures remain nonblocking', async () => {
  const h = harness();
  delete h.sandbox.AudioContext;
  assert.equal(await h.bridge.beginAudio(), false);
  h.bridge.pause(false);
  h.sandbox.speechSynthesis.speak = () => { throw new Error('unavailable'); };
  assert.doesNotThrow(() => h.bridge.say('Caption still works.'));
  h.bridge.dispose();
});

test('official Google button carries nonce and returns credential without storing it', async () => {
  const h = harness();
  let config, rendered, credential;
  const errors = [];
  const element = {isConnected: true, replaceChildren() {}};
  h.bridge.renderGoogleButton(element, 'public-client', 'browser-nonce',
    (value) => { credential = value; }, (value) => errors.push(value));
  assert.equal(h.scripts[0].src, 'https://accounts.google.com/gsi/client');
  h.sandbox.google = {accounts: {id: {
    initialize(value) { config = value; },
    renderButton(target, options) { rendered = {target, options}; },
  }}};
  h.scripts[0].onload();
  await flush();
  assert.equal(config.nonce, 'browser-nonce');
  assert.equal(config.client_id, 'public-client');
  assert.equal(rendered.target, element);
  config.callback({credential: 'opaque-id-token'});
  assert.equal(credential, 'opaque-id-token');
  assert.equal(errors.length, 0);
  h.bridge.dispose();
});

test('Google load failure reports a retryable error and detaches failed script', async () => {
  const h = harness();
  const errors = [], element = {isConnected: true};
  h.bridge.renderGoogleButton(element, 'client', 'nonce', () => {}, (error) => errors.push(error));
  h.advance(12000);
  await flush();
  assert.equal(errors.length, 1);
  assert.equal(h.scripts[0].removed, true);
  h.bridge.renderGoogleButton(element, 'client', 'nonce2', () => {}, (error) => errors.push(error));
  assert.equal(h.scripts.length, 2);
  h.bridge.dispose();
});

test('cached Google script waits for Flutter to attach the platform-view host', async () => {
  const h = harness();
  let renders = 0;
  const element = {isConnected: false, replaceChildren() {}};
  h.sandbox.google = {accounts: {id: {
    initialize() {}, renderButton() { renders++; },
  }}};
  h.bridge.renderGoogleButton(element, 'client', 'nonce', () => {}, assert.fail);
  await flush();
  assert.equal(renders, 0);
  element.isConnected = true;
  h.advance(30);
  await flush();
  assert.equal(renders, 1);
  h.bridge.dispose();
});

test('proof station break cuts music, tunes, reports, then resumes a new arrangement', async () => {
  const h = harness();
  h.bridge.setProofAudio(true);
  await h.bridge.beginAudio();
  h.bridge.pause(false);
  await flush();
  h.bridge.setAudioState(.8, .8, 'City');
  h.advance(400);
  h.bridge.radioBreak('A clear road and a little local humor.', 'Forest');
  assert.equal(h.bridge.audioSnapshot().phase, 'tuning');
  assert.equal(h.spoken.length, 0);
  h.advance(230);
  assert.equal(h.spoken.length, 1);
  assert.equal(h.bridge.audioSnapshot().phase, 'report');
  const duringReport = h.oscillatorNotes.length;
  h.advance(400);
  assert.equal(h.oscillatorNotes.length, duringReport);
  h.spoken[0].onend();
  assert.equal(h.bridge.audioSnapshot().phase, 'music');
  h.advance(200);
  assert.equal(h.bridge.audioSnapshot().trackStyle, 'country');
  assert.ok(h.oscillatorNotes.length > duringReport);
  h.bridge.dispose();
  assert.equal(h.timers.size, 0);
});

test('proof radio is cancellable and missing speech resumes music without blocking', async () => {
  const h = harness();
  h.bridge.setProofAudio(true);
  await h.bridge.beginAudio();
  h.bridge.pause(false);
  await flush();
  h.bridge.radioBreak('This report will be cancelled.', 'City');
  h.bridge.setMuted(true);
  h.advance(500);
  assert.equal(h.spoken.length, 0);
  assert.equal(h.bridge.audioSnapshot().phase, 'music');
  h.bridge.setMuted(false);
  delete h.sandbox.speechSynthesis;
  h.bridge.radioBreak('Caption remains available.', 'Mountain');
  h.advance(300);
  assert.equal(h.bridge.audioSnapshot().phase, 'music');
  assert.equal(h.bridge.audioSnapshot().trackStyle, 'metal');
  h.bridge.dispose();
  assert.equal(h.timers.size, 0);
});

test('garage Foley obeys mute while its race remains paused', async () => {
  const h = harness();
  await h.bridge.beginAudio();
  const initial = h.oscillatorNotes.length;
  h.bridge.garageCue('keys');
  assert.equal(h.oscillatorNotes.length, initial + 3);
  h.bridge.setMuted(true);
  h.bridge.garageCue('door');
  assert.equal(h.oscillatorNotes.length, initial + 3);
  h.bridge.dispose();
});


test('ignition prelap and launch rev use bounded audio-clock envelopes', async () => {
  const h = harness();
  h.bridge.pause(true);
  h.bridge.setMuted(false);
  await h.bridge.beginAudio();
  const first = h.oscillatorNotes.length;
  h.bridge.garageCue('cabin');
  const starter = h.oscillatorNotes.slice(first);
  assert.equal(starter.length, 5);
  assert.ok(starter.every(node => node.stopped > node.started && node.stopped - node.started <= 1.1));
  h.bridge.garageCue('cabin');
  assert.equal(h.oscillatorNotes.length, first + 5, 'duplicate shot notification is bounded');
  h.advance(300);
  const next = h.oscillatorNotes.length;
  h.bridge.garageCue('launch');
  const rev = h.oscillatorNotes.slice(next);
  assert.equal(rev.length, 2);
  assert.ok(rev[0].frequency.events.some(event => event.method === 'exponential' && event.value === 220));
  assert.ok(rev.every(node => node.started >= h.audio.currentTime && node.stopped - node.started <= 1));
  h.bridge.setMuted(true);
  assert.ok(rev.every(node => node.stopped === undefined), 'mute immediately stops the separate garage bus');
  h.bridge.dispose();
});

test('hidden departure and disposal cancel prelap instead of leaving a rev behind', async () => {
  const h = harness();
  await h.bridge.beginAudio();
  h.bridge.pause(true);
  h.bridge.setMuted(false);
  const first = h.oscillatorNotes.length;
  h.bridge.garageCue('launch');
  const rev = h.oscillatorNotes.slice(first);
  h.sandbox.document.hidden = true;
  h.emit('visibilitychange');
  assert.ok(rev.every(node => node.stopped === undefined));
  h.sandbox.document.hidden = false;
  h.bridge.garageCue('cabin');
  const last = h.oscillatorNotes.slice(first + 2);
  h.bridge.dispose();
  assert.ok(last.every(node => node.stopped === undefined));
});

test('occasional station surfing is bounded and sandwiches a short report with noise', async () => {
  const h = harness({prepared: true});
  h.bridge.setProofAudio(true); await h.bridge.beginAudio(); h.bridge.pause(false);
  h.bridge.radioBreak('Clear roads!', 'City'); h.advance(180); await flush();
  assert.equal(h.bridge.audioSnapshot().phase, 'report');
  h.preparedReports.at(-1).complete();
  h.bridge.radioBreak('Rain ahead!', 'Forest'); h.advance(180); await flush();
  assert.equal(h.bridge.audioSnapshot().phase, 'surf-song');
  assert.deepEqual(h.snippetCalls, ['Forest']);
  h.advance(680); assert.equal(h.bridge.audioSnapshot().phase, 'tuning');
  h.advance(180); await flush(); assert.equal(h.bridge.audioSnapshot().phase, 'report');
  h.preparedReports.at(-1).complete(); assert.equal(h.bridge.audioSnapshot().phase, 'tuning');
  h.advance(180); assert.equal(h.bridge.audioSnapshot().phase, 'music');
  h.bridge.radioBreak('Snow ahead!', 'Mountain'); h.advance(180); await flush();
  assert.equal(h.bridge.audioSnapshot().radioVariant, 'direct');
  assert.equal(h.bridge.audioSnapshot().surfCount, 1);
});

test('mute during surfing cancels every pending report and station-resume timer', async () => {
  const h = harness({prepared: true});
  h.bridge.setProofAudio(true); await h.bridge.beginAudio(); h.bridge.pause(false);
  h.bridge.radioBreak('Clear roads!', 'City'); h.advance(180); await flush();
  h.preparedReports.at(-1).complete();
  h.bridge.radioBreak('Rain ahead!', 'Forest'); h.advance(180); await flush();
  assert.equal(h.bridge.audioSnapshot().phase, 'surf-song');
  h.bridge.setMuted(true); const reports = h.preparedReports.length;
  h.advance(10000); await flush();
  assert.equal(h.preparedReports.length, reports);
  assert.equal(h.bridge.audioSnapshot().phase, 'music');
});
