import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {readFileSync} from 'node:fs';
import test from 'node:test';

const require = createRequire(import.meta.url);
const {CannonballRadioProgramme, RadioSequencer} = require('./radio_programme.js');
const flush = () => new Promise(resolve => setImmediate(resolve));

function seeded(seed = 7) {
  let s = seed;
  return () => { s = (s * 48271) % 2147483647; return s / 2147483647; };
}

function programme() {
  const stations = [
    {id: 'pop', name: 'Pop', frequency: '1', regions: ['City']},
    {id: 'rock', name: 'Rock', frequency: '2', regions: ['Mountain', 'City']},
    {id: 'folk', name: 'Folk', frequency: '3', regions: ['Forest']},
  ];
  const songs = [];
  for (const st of stations) for (let i = 0; i < 3; i++) {
    songs.push({id: `${st.id}-${i}`, title: `${st.id} ${i}`, genre: st.id, station: st.id, src: `music/${st.id}-${i}.mp3`, duration: 90});
  }
  const interjections = [];
  for (const st of stations) {
    for (const kind of ['ident', 'ident', 'banter', 'banter']) {
      interjections.push({id: `${st.id}-${kind}-${interjections.length}`, station: st.id, kind, text: `${st.id} ${kind}`, src: `music/dj-${st.id}-${interjections.length}.mp3`});
    }
  }
  interjections.push({id: 'net-1', station: '*', kind: 'network', text: 'network', src: 'music/dj-net-1.mp3'});
  const buzz = [1, 2, 3].map(i => ({id: `buzz-${i}`, src: `music/buzz-${i}.mp3`, duration: .8}));
  return {rules: {recentSongs: 6, recentLines: 5, stayOnStation: .5, identEvery: 2}, stations, songs, interjections, buzz};
}

test('sequencer never repeats a recent song and honours regions', () => {
  const s = new RadioSequencer(programme(), seeded(3));
  const history = [];
  for (let i = 0; i < 60; i++) {
    const plan = s.plan('City');
    assert.ok(['pop', 'rock'].includes(plan.station), 'City plays only City-eligible stations');
    assert.ok(!s.recentSongs.slice(-5).includes(plan.song.id), `song ${plan.song.id} repeated too soon`);
    assert.notEqual(plan.buzzIn.id, plan.buzzOut.id);
    s.commit(plan);
    history.push(plan.song.id);
  }
  assert.ok(new Set(history).size === 6, 'every eligible song gets airtime');
  const forest = s.plan('Forest');
  assert.equal(forest.station, 'folk');
  assert.equal(forest.changed, true);
  assert.equal(forest.line.kind, 'ident', 'a station change is announced by that station');
});

test('user skip always changes station; lines rotate without immediate repeats', () => {
  const s = new RadioSequencer(programme(), seeded(11));
  let previous = null;
  const lines = [];
  for (let i = 0; i < 20; i++) {
    const plan = s.plan('City', {change: true});
    if (previous) assert.notEqual(plan.station, previous);
    previous = plan.station;
    assert.ok(!s.recentLines.includes(plan.line.id));
    lines.push(plan.line.id);
    s.commit(plan);
  }
  assert.ok(new Set(lines).size >= 5);
});

test('identical seeds give identical programmes', () => {
  const run = () => { const s = new RadioSequencer(programme(), seeded(5)); return Array.from({length: 12}, () => { const p = s.plan('Mountain'); s.commit(p); return p.song.id + p.line?.id; }); };
  assert.deepEqual(run(), run());
});

test('an invalid or missing programme is not ready', () => {
  assert.equal(new RadioSequencer({stations: [], songs: [], buzz: []}).valid, false);
});

function harness({ready = 3} = {}) {
  let time = 0, id = 0;
  const timers = new Map(), sources = [], fetched = [], spoken = [];
  const context = {currentTime: 0, sampleRate: 48000,
    decodeAudioData: async () => ({duration: .5}),
    createBuffer(ch, length, rate) { const data = new Float32Array(length); return {duration: length / rate, getChannelData: () => data}; },
    createGain() { return {gain: {value: 1}, connect() { return this; }, disconnect() {}}; },
    createBufferSource() {
      const node = {connect() { return this; }, disconnect() {}, start(at) { this.started = at; }, stop() { this.stopped = true; }};
      sources.push(node); return node;
    },
    createMediaElementSource() { return {connect() {}, disconnect() {}}; },
  };
  const listeners = {};
  const element = {readyState: ready, src: '', played: 0, paused: true, currentTime: 0, loads: 0,
    addEventListener(name, fn) { listeners[name] = fn; }, setAttribute() {},
    play() { this.played++; this.paused = false; return Promise.resolve(); },
    pause() { this.paused = true; }, load() { this.loads++; }};
  const options = {
    base: 'https://game.test/audio/',
    fetch: async url => { fetched.push(url); return {ok: true, arrayBuffer: async () => new ArrayBuffer(4)}; },
    loadCatalog: async () => ({programme: programme()}),
    createAudio: () => element,
    speak: (text, done) => spoken.push({text, done}),
    random: seeded(9),
    setTimeout: (fn, ms) => { const t = ++id; timers.set(t, {fn, at: time + ms}); return t; },
    clearTimeout: t => timers.delete(t),
  };
  const p = new CannonballRadioProgramme(context, {}, options);
  function advance(ms) {
    const end = time + ms;
    for (;;) {
      const next = [...timers].filter(([, v]) => v.at <= end).sort((a, b) => a[1].at - b[1].at)[0];
      if (!next) break;
      timers.delete(next[0]); time = next[1].at; context.currentTime = time / 1000; next[1].fn();
    }
    time = end; context.currentTime = time / 1000;
  }
  const endClip = () => { const s = sources.filter(x => x.onended && !x.stopped && !x.loop).at(-1); s?.onended(); return s; };
  return {p, element, sources, fetched, spoken, timers, advance, endClip, listeners, context};
}

test('radio turns on with buzz, a station line, buzz, then a streamed song', async () => {
  const h = harness();
  assert.equal(await h.p.prepare(), true);
  h.p.unlock(); await flush();
  assert.equal(h.element.paused, true, 'unlock does not start music');
  h.p.setPaused(false);
  assert.equal(h.p.play('City'), true);
  assert.equal(h.p.state, 'buzz-in');
  assert.match(h.element.src, /music\/(pop|rock)-\d\.mp3$/, 'next song starts streaming during the break');
  assert.ok(!h.fetched.some(url => url.includes(h.element.src.split('/').pop())), 'songs are never fetched whole');
  await flush();
  h.endClip();
  await flush();
  assert.equal(h.p.state, 'line');
  assert.ok(h.p.snapshot().caption.length > 0);
  h.endClip();
  assert.equal(h.p.state, 'buzz-out');
  h.advance(1000);
  assert.equal(h.p.state, 'song');
  assert.equal(h.element.paused, false);
  assert.ok(h.p.label().includes('·'));
  assert.equal(h.p.snapshot().transitions, 1);
});

test('song end cuts to a different song through buzz -> interjection -> buzz', async () => {
  const h = harness();
  await h.p.prepare(); h.p.setPaused(false); h.p.play('City'); await flush();
  h.endClip(); await flush(); h.endClip(); h.advance(1000);
  const first = h.p.snapshot().title;
  h.listeners.ended();
  assert.equal(h.p.state, 'buzz-in');
  assert.equal(h.element.paused, true, 'hard cut');
  h.endClip(); await flush(); h.endClip(); h.advance(1000);
  assert.equal(h.p.state, 'song');
  assert.notEqual(h.p.snapshot().title, first);
});

test('urgent reports cut in; non-urgent ones wait for the next break', async () => {
  const h = harness();
  await h.p.prepare(); h.p.setPaused(false); h.p.play('City'); await flush();
  h.endClip(); await flush(); h.endClip(); h.advance(1000);
  assert.equal(h.p.state, 'song');
  h.p.interject('Light traffic.', 'City', false);
  assert.equal(h.p.state, 'song', 'banter-grade report does not interrupt');
  h.p.interject('Snow ahead.', 'Mountain', true);
  assert.equal(h.p.state, 'buzz-in');
  h.endClip(); await flush();
  assert.equal(h.p.state, 'report');
  assert.equal(h.spoken.at(-1).text, 'Snow ahead.');
  h.spoken.at(-1).done(); h.spoken.at(-1).done();
  assert.equal(h.p.state, 'buzz-out');
  h.advance(1000);
  assert.equal(h.p.snapshot().station, 'rock', 'Mountain region picks a Mountain station');
});

test('a stuck speech engine cannot hold the programme', async () => {
  const h = harness();
  await h.p.prepare(); h.p.setPaused(false);
  h.p.interject('Rain ahead.', 'City', true); // queued until the radio starts
  h.p.play('City'); await flush(); h.endClip(); await flush();
  assert.equal(h.p.state, 'report');
  h.advance(12100);
  assert.equal(h.p.state, 'buzz-out');
});

test('pause then resume in one task keeps the song running (level change)', async () => {
  const h = harness();
  await h.p.prepare(); h.p.setPaused(false); h.p.play('City'); await flush();
  h.endClip(); await flush(); h.endClip(); h.advance(1000);
  const plays = h.element.played;
  h.p.setPaused(true); h.p.setPaused(false); h.advance(200);
  assert.equal(h.element.paused, false);
  assert.equal(h.element.played, plays);
  h.p.setPaused(true); h.advance(100);
  assert.equal(h.element.paused, true, 'a real pause stops the stream');
  h.p.setPaused(false);
  assert.equal(h.element.paused, false, 'and resumes it in place');
  assert.equal(h.p.state, 'song');
});

test('pause during a break resumes with buzz and the planned song', async () => {
  const h = harness();
  await h.p.prepare(); h.p.setPaused(false); h.p.play('City'); await flush();
  h.p.setPaused(true); h.advance(100);
  const live = h.sources.filter(s => !s.stopped && s.onended);
  assert.equal(live.length, 0, 'pause stops every buffered clip');
  h.advance(5000);
  assert.equal(h.p.state, 'buzz-in');
  h.p.setPaused(false);
  assert.equal(h.p.state, 'buzz-out');
  h.advance(1000);
  assert.equal(h.p.state, 'song');
});

test('station skip is debounced and always changes station', async () => {
  const h = harness();
  await h.p.prepare(); h.p.setPaused(false); h.p.play('City'); await flush();
  h.endClip(); await flush(); h.endClip(); h.advance(1000);
  const station = h.p.snapshot().station;
  assert.equal(h.p.skip(), true);
  assert.equal(h.p.skip(), false, 'second press within 350 ms is ignored');
  h.endClip(); await flush(); h.endClip(); h.advance(1000);
  assert.notEqual(h.p.snapshot().station, station);
  assert.equal(h.p.snapshot().skips, 1);
});

test('a slow stream holds static; repeated failures fall back', async () => {
  const h = harness({ready: 0});
  await h.p.prepare(); h.p.setPaused(false); h.p.play('City'); await flush();
  h.endClip(); await flush(); h.endClip(); h.advance(1000);
  assert.equal(h.p.state, 'loading');
  assert.ok(h.sources.some(s => s.loop && !s.stopped), 'quiet looping static instead of silence');
  h.element.readyState = 4; h.advance(300);
  assert.equal(h.p.state, 'song');
  h.p.songError(); h.p.songError(); h.p.songError();
  assert.equal(h.p.ready, false);
  assert.equal(h.p.state, 'failed');
});

test('missing catalog programme leaves the legacy fallback in charge', async () => {
  const h = harness();
  h.p.loadCatalog = async () => ({tracks: []});
  assert.equal(await h.p.prepare(), false);
  assert.equal(h.p.ready, false);
  assert.equal(h.p.play('City'), false);
});

test('committed catalog programme is coherent with the shipped files', () => {
  const catalog = JSON.parse(readFileSync(new URL('../assets/audio/catalog.json', import.meta.url)));
  const p = catalog.programme;
  assert.ok(p, 'catalog.json has a programme block');
  const s = new RadioSequencer(p, seeded(1));
  assert.equal(s.valid, true);
  assert.ok(p.songs.length >= 24);
  for (const song of p.songs) {
    assert.ok(song.duration >= 60 && song.duration <= 120, `${song.id} duration`);
    readFileSync(new URL(`../assets/audio/${song.src}`, import.meta.url));
  }
  for (const clip of [...p.buzz, ...p.interjections]) readFileSync(new URL(`../assets/audio/${clip.src}`, import.meta.url));
  for (const st of p.stations) {
    assert.ok(p.songs.filter(x => x.station === st.id).length >= 2, `${st.id} songs`);
    assert.ok(p.interjections.some(x => x.station === st.id && x.kind === 'ident'), `${st.id} ident`);
  }
  // Legacy keys stay readable by older players.
  assert.ok(Array.isArray(catalog.tracks) && Array.isArray(catalog.radio));
});

test('a region with one local station stays on it instead of wandering off', () => {
  for (let seed = 1; seed < 200; seed++) {
    const s = new RadioSequencer(programme(), seeded(seed * 7919));
    s.commit(s.plan('Forest'));
    for (let i = 0; i < 6; i++) { const p = s.plan('Forest'); assert.equal(p.station, 'folk'); s.commit(p); }
    assert.notEqual(s.plan('Forest', {change: true}).station, 'folk', 'an explicit skip still changes station');
  }
});
