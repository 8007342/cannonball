/* Cannonball radio programme: wordless songs joined by hard radio cuts.
 * song -> tuning buzz -> interjection (DJ line or state-derived report) ->
 * tuning buzz -> another song. Songs stream through one reused media element
 * (never fully decoded, one download at a time); buzz and presenter clips are
 * tiny decoded buffers scheduled on the audio clock. No network service. */
(function (root) {
  'use strict';

  const REPORT_TTL = 45; // seconds a queued, non-urgent report stays relevant
  const DEFAULT_RULES = {recentSongs: 10, recentLines: 8, stayOnStation: 0.55, identEvery: 2};

  /** Pure, deterministic-under-injected-random programme selection. */
  class RadioSequencer {
    constructor(programme, random = Math.random) {
      this.programme = programme;
      this.random = random;
      this.rules = {...DEFAULT_RULES, ...(programme.rules || {})};
      this.songs = programme.songs || [];
      this.lines = programme.interjections || [];
      this.buzz = programme.buzz || [];
      this.stations = (programme.stations || []).filter(s => this.songs.some(song => song.station === s.id));
      this.recentSongs = []; this.recentLines = [];
      this.station = null; this.song = null; this.lastBuzz = null; this.transitions = 0;
    }
    get valid() { return this.stations.length > 0 && this.songs.length > 1 && this.buzz.length > 0; }
    pick(list) { return list[Math.min(list.length - 1, Math.floor(this.random() * list.length))]; }
    stationsFor(region) {
      const local = this.stations.filter(s => (s.regions || []).includes(region));
      return local.length ? local : this.stations;
    }
    freshSongs(station) {
      return this.songs.filter(s => s.station === station && !this.recentSongs.includes(s.id) && s.id !== this.song?.id);
    }
    chooseStation(region, change = false) {
      const eligible = this.stationsFor(region);
      const current = eligible.find(s => s.id === this.station);
      if (!change && current && this.freshSongs(current.id).length && this.random() < this.rules.stayOnStation) return current.id;
      let pool = eligible.filter(s => s.id !== this.station);
      // The only local station is the current one: stay unless the listener
      // asked for a change (then any other station is better than a refusal).
      if (!pool.length) pool = change ? this.stations.filter(s => s.id !== this.station) : eligible;
      if (!pool.length) pool = eligible;
      const fresh = pool.filter(s => this.freshSongs(s.id).length);
      if (fresh.length) return this.pick(fresh).id;
      // Nothing fresh: the station owning the least recently played song.
      const ids = new Set(pool.map(s => s.id));
      const oldest = this.recentSongs.map(id => this.songs.find(s => s.id === id))
        .find(s => s && ids.has(s.station) && s.id !== this.song?.id);
      return oldest ? oldest.station : this.pick(pool).id;
    }
    chooseSong(station) {
      const fresh = this.freshSongs(station);
      if (fresh.length) return this.pick(fresh);
      // Everything recent: the least recently played song that is not current.
      const own = this.songs.filter(s => s.station === station && s.id !== this.song?.id);
      const pool = own.length ? own : this.songs.filter(s => s.id !== this.song?.id);
      return pool.sort((a, b) => this.recentSongs.indexOf(a.id) - this.recentSongs.indexOf(b.id))[0] || this.songs[0];
    }
    chooseLine(station, changed) {
      const ident = changed || this.transitions % this.rules.identEvery === 0;
      const own = this.lines.filter(l => l.station === station);
      const preferred = own.filter(l => ident ? l.kind === 'ident' : l.kind !== 'ident')
        .concat(ident ? [] : this.lines.filter(l => l.station === '*'));
      for (const pool of [preferred, own, this.lines.filter(l => l.station === '*')]) {
        const fresh = pool.filter(l => !this.recentLines.includes(l.id));
        if (fresh.length) return this.pick(fresh);
      }
      return own.length ? this.pick(own) : null;
    }
    chooseBuzz() {
      const pool = this.buzz.length > 1 ? this.buzz.filter(b => b.id !== this.lastBuzz) : this.buzz;
      const buzz = this.pick(pool);
      this.lastBuzz = buzz?.id ?? null;
      return buzz;
    }
    /** Plan one transition. `change` forces a different station (user skip). */
    plan(region, {change = false, line = true} = {}) {
      const station = this.chooseStation(region, change);
      const changed = station !== this.station;
      return {station, changed, song: this.chooseSong(station),
        line: line ? this.chooseLine(station, changed) : null,
        buzzIn: this.chooseBuzz(), buzzOut: this.chooseBuzz()};
    }
    remember(list, id, size) {
      if (!id) return;
      const at = list.indexOf(id);
      if (at >= 0) list.splice(at, 1);
      list.push(id);
      while (list.length > size) list.shift();
    }
    commit(plan) {
      this.station = plan.station; this.song = plan.song; this.transitions++;
      this.remember(this.recentSongs, plan.song?.id, Math.min(this.rules.recentSongs, Math.max(1, this.songs.length - 2)));
      this.remember(this.recentLines, plan.line?.id, Math.min(this.rules.recentLines, Math.max(1, this.lines.length - 2)));
    }
    stationInfo(id) { return this.stations.find(s => s.id === id) || null; }
  }

  class CannonballRadioProgramme {
    constructor(context, output, options = {}) {
      this.context = context; this.output = output;
      this.fetch = options.fetch || root.fetch?.bind(root);
      this.base = options.base || (() => {
        try { return new URL('assets/assets/audio/', root.document.baseURI).href; } catch (_) { return 'assets/assets/audio/'; }
      })();
      this.loadCatalog = options.loadCatalog || null;
      this.createAudio = options.createAudio || (() => new root.Audio());
      this.speak = options.speak || ((text, done) => done());
      this.onHalt = options.onHalt || (() => {});
      this.random = options.random || Math.random;
      this.timers = {set: options.setTimeout || root.setTimeout.bind(root), clear: options.clearTimeout || root.clearTimeout.bind(root)};
      this.sequencer = null; this.state = 'idle'; this.failed = false; this.pending = false;
      this.region = 'City'; this.epoch = 0; this.paused = true; this.started = false;
      this.buffers = new Map(); this.loading = new Map(); this.sources = new Set();
      this.timer = null; this.pauseTimer = null; this.element = null; this.unlocked = false;
      this.plan = null; this.queuedReport = null; this.caption = ''; this.skips = 0; this.lastSkipAt = -1;
      this.resumeStage = null; this.songFailures = 0; this.disposed = false;
    }

    get ready() { return Boolean(this.sequencer) && !this.failed && !this.disposed; }

    async prepare() {
      if (this.preparing) return this.preparing;
      this.pending = true;
      const load = this.loadCatalog ? this.loadCatalog() :
        this.fetch(this.url('catalog.json')).then(r => { if (!r.ok) throw Error('catalog'); return r.json(); });
      this.preparing = Promise.resolve(load).then(catalog => {
        const sequencer = catalog?.programme ? new RadioSequencer(catalog.programme, this.random) : null;
        if (!sequencer?.valid || this.disposed) { this.failed = true; return false; }
        this.sequencer = sequencer;
        return true;
      }).catch(() => { this.failed = true; return false; }).finally(() => { this.pending = false; });
      return this.preparing;
    }

    url(src) { try { return new URL(src, this.base).href; } catch (_) { return this.base + src; } }

    /** Must run inside a user gesture: unlocks the one reused media element. */
    unlock() {
      if (this.disposed) return;
      const element = this.mediaElement();
      if (this.unlocked || !element) return;
      this.unlocked = true;
      try {
        element.muted = true;
        const attempt = element.play();
        Promise.resolve(attempt).then(() => {
          if (this.state !== 'song' || this.paused) element.pause();
          element.muted = false;
        }).catch(() => { element.muted = false; });
      } catch (_) { element.muted = false; }
    }

    mediaElement() {
      if (this.element || this.disposed) return this.element;
      const element = this.createAudio();
      if (!element) return null;
      element.preload = 'auto';
      element.crossOrigin = 'anonymous';
      element.setAttribute?.('playsinline', '');
      element.addEventListener('ended', () => { if (this.state === 'song') this.transition(); });
      element.addEventListener('error', () => { if (this.state === 'song' || this.state === 'loading') this.songError(); });
      try {
        if (this.context.createMediaElementSource) {
          this.mediaSource = this.context.createMediaElementSource(element);
          this.mediaSource.connect(this.output);
        }
      } catch (_) { this.mediaSource = null; }
      this.element = element;
      return element;
    }

    async buffer(src) {
      if (this.buffers.has(src)) return this.buffers.get(src);
      if (!this.loading.has(src)) {
        const promise = this.fetch(this.url(src))
          .then(r => { if (!r.ok) throw Error('audio'); return r.arrayBuffer(); })
          .then(data => this.context.decodeAudioData(data))
          .then(buffer => {
            if (this.disposed) return null;
            // Clips are a few hundred kB decoded; keep a small LRU.
            while (this.buffers.size >= 10) this.buffers.delete(this.buffers.keys().next().value);
            this.buffers.set(src, buffer);
            return buffer;
          }).catch(() => null).finally(() => this.loading.delete(src));
        this.loading.set(src, promise);
      }
      return this.loading.get(src);
    }

    prefetch(plan) {
      for (const clip of [plan?.buzzIn, plan?.line, plan?.buzzOut]) if (clip) this.buffer(clip.src);
    }

    later(seconds, action) {
      this.timers.clear(this.timer);
      const epoch = this.epoch;
      this.timer = this.timers.set(() => { this.timer = null; if (epoch === this.epoch && !this.paused) action(); },
        Math.max(0, seconds * 1000));
    }

    stopSources() {
      for (const source of this.sources) { source.onended = null; try { source.stop(); } catch (_) {} source.disconnect?.(); }
      this.sources.clear();
    }

    /** Plays a cached buffer at once; a cold buzz falls back to synthetic hiss. */
    playClip(clip, done, {loop = false, gain = 1} = {}) {
      const buffer = clip && this.buffers.get(clip.src);
      const epoch = this.epoch;
      let audio = buffer;
      if (!audio && this.context.createBuffer) {
        const length = Math.floor(this.context.sampleRate * .45);
        audio = this.context.createBuffer(1, length, this.context.sampleRate);
        const data = audio.getChannelData(0);
        let state = 911;
        for (let i = 0; i < length; i++) { state = (state * 48271) % 2147483647; data[i] = (state / 2147483647 * 2 - 1) * .12; }
      }
      if (!audio) { this.later(.2, done); return .2; }
      const source = this.context.createBufferSource();
      source.buffer = audio; source.loop = loop;
      let node = source;
      if (gain !== 1 && this.context.createGain) {
        const g = this.context.createGain(); g.gain.value = gain; source.connect(g); node = g;
      }
      node.connect(this.output);
      this.sources.add(source);
      source.onended = () => {
        source.onended = null;
        this.sources.delete(source); source.disconnect?.();
        if (epoch === this.epoch && !this.paused && !loop) done();
      };
      source.start(this.context.currentTime);
      return audio.duration;
    }

    /** Starts the programme if idle; called from the music scheduler. */
    play(region) {
      if (typeof region === 'string') this.region = region;
      if (!this.ready || this.paused || this.started) return this.ready;
      this.started = true;
      // Turning the radio on: buzz, station ident (or a queued report), song.
      this.transition({cut: false});
      return true;
    }

    setRegion(region) { if (typeof region === 'string' && region) this.region = region; }

    /** State-derived report. Urgent ones cut in now; others wait for the next break. */
    interject(text, region, urgent = true) {
      this.setRegion(region);
      if (!this.ready || typeof text !== 'string' || !text.trim()) return false;
      // Latest state wins; a non-urgent report waits for the next break and
      // expires so a stale traffic quip never plays a minute later.
      this.queuedReport = text;
      this.queuedAt = this.context.currentTime;
      if (urgent && this.started) this.transition();
      return true;
    }

    /** User station skip: hard cut to a different station with its ident. */
    skip() {
      if (!this.ready || this.paused || !this.started) return false;
      const now = this.context.currentTime;
      if (now - this.lastSkipAt < .35) return false;
      this.lastSkipAt = now; this.skips++;
      this.transition({change: true});
      return true;
    }

    cutSong() {
      const element = this.element;
      if (element) { try { element.pause(); } catch (_) {} }
    }

    transition({change = false, cut = true} = {}) {
      if (!this.ready) return;
      this.epoch++; this.timers.clear(this.timer); this.stopSources();
      if (cut) this.cutSong();
      // Reuse the plan whose clips were precached during the song, unless the
      // listener skipped or the region no longer suits that station.
      const eligible = this.sequencer.stationsFor(this.region).some(s => s.id === this.next?.station);
      const plan = !change && this.next && eligible ? this.next : this.sequencer.plan(this.region, {change});
      this.next = null;
      this.plan = plan;
      const fresh = this.context.currentTime - (this.queuedAt ?? 0) <= REPORT_TTL;
      const report = fresh ? this.queuedReport : null; this.queuedReport = null;
      this.prefetch(plan);
      // Load the next song during the break: one stream, no second download.
      const element = this.mediaElement();
      if (element) { element.src = this.url(plan.song.src); try { element.load(); } catch (_) {} }
      this.stageBuzzIn(plan, report);
    }

    stageBuzzIn(plan, report) {
      this.state = 'buzz-in'; this.caption = ''; this.resumeStage = 'buzz-out';
      this.playClip(plan.buzzIn, () => this.stageVoice(plan, report));
    }

    stageVoice(plan, report) {
      const epoch = this.epoch;
      if (report) {
        this.state = 'report'; this.caption = report;
        let finished = false;
        const done = () => { if (finished || epoch !== this.epoch) return; finished = true; this.stageBuzzOut(plan); };
        this.later(12, done); // A stuck speech engine never blocks the programme.
        try { this.speak(report, done); } catch (_) { done(); }
        return;
      }
      if (!plan.line) { this.stageBuzzOut(plan); return; }
      const start = () => {
        if (epoch !== this.epoch || this.paused) return;
        this.state = 'line'; this.caption = plan.line.caption || plan.line.text;
        this.playClip(plan.line, () => this.stageBuzzOut(plan));
      };
      if (this.buffers.has(plan.line.src)) { start(); return; }
      // A cold presenter clip gets a short grace period, then is skipped.
      let settled = false;
      this.buffer(plan.line.src).then(buffer => { if (settled) return; settled = true; buffer ? start() : this.stageBuzzOut(plan); });
      this.later(1.5, () => { if (settled) return; settled = true; this.stageBuzzOut(plan); });
    }

    stageBuzzOut(plan) {
      if (this.paused) { this.resumeStage = 'buzz-out'; return; }
      this.epoch++; this.timers.clear(this.timer);
      this.state = 'buzz-out'; this.resumeStage = 'buzz-out';
      if (plan.line && this.caption === (plan.line.caption || plan.line.text)) this.caption = '';
      const duration = this.playClip(plan.buzzOut, () => {});
      // Start the stream just before the buzz ends: a hard radio cut.
      this.later(Math.max(0, duration - .08), () => this.startSong(plan));
    }

    startSong(plan, waited = 0) {
      const element = this.mediaElement();
      if (!element) { this.failed = true; this.state = 'failed'; return; }
      if ((element.readyState ?? 4) < 3 && waited < 8) {
        // Still buffering: hold the dial on quiet static instead of silence.
        if (this.state !== 'loading') { this.state = 'loading'; this.playClip(plan.buzzOut, () => {}, {loop: true, gain: .35}); }
        this.later(.25, () => this.startSong(plan, waited + .25));
        return;
      }
      if (waited >= 8) { this.songError(); return; }
      this.stopSources();
      this.sequencer.commit(plan);
      this.state = 'song'; this.caption = ''; this.resumeStage = null; this.songFailures = 0;
      try { element.currentTime = 0; } catch (_) {}
      Promise.resolve(element.play()).catch(() => this.songError());
      // Precache the next break's tiny clips while the song plays.
      this.next = this.sequencer.plan(this.region);
      this.prefetch(this.next);
    }

    songError() {
      if (!this.ready) return;
      this.songFailures++;
      if (this.songFailures >= 3) { this.failed = true; this.stopSources(); this.cutSong(); this.state = 'failed'; return; }
      this.transition();
    }

    /** Pause/mute/hidden. Deferred briefly so pause(true); pause(false) in one
     * task (level changes) keeps the song running with no gap. */
    setPaused(value) {
      value = Boolean(value);
      if (value === this.paused && !this.pauseTimer) return;
      if (!value) {
        if (this.pauseTimer) { this.timers.clear(this.pauseTimer); this.pauseTimer = null; this.paused = false; return; }
        this.paused = false;
        if (!this.started || !this.ready) return;
        if (this.state === 'song') Promise.resolve(this.element?.play()).catch(() => this.songError());
        else if (this.plan) this.stageBuzzOut(this.plan);
        return;
      }
      if (this.pauseTimer) return;
      this.pauseTimer = this.timers.set(() => {
        this.pauseTimer = null;
        this.paused = true;
        this.epoch++; this.timers.clear(this.timer); this.stopSources();
        this.cutSong();
        if (this.state !== 'song') this.resumeStage = 'buzz-out';
        this.onHalt();
      }, 60);
    }

    /** Hard stop now (mute, proof audio off). */
    halt() {
      if (this.pauseTimer) { this.timers.clear(this.pauseTimer); this.pauseTimer = null; }
      this.paused = true; this.epoch++; this.timers.clear(this.timer); this.stopSources(); this.cutSong();
      if (this.state !== 'song') this.resumeStage = 'buzz-out';
      this.onHalt();
    }

    reset() {
      this.halt();
      this.started = false; this.state = 'idle'; this.caption = ''; this.plan = null; this.queuedReport = null;
      if (this.sequencer) this.sequencer = new RadioSequencer(this.sequencer.programme, this.random);
    }

    snapshot() {
      const s = this.sequencer;
      const station = s?.stationInfo(this.state === 'song' ? s.station : this.plan?.station ?? s?.station);
      const song = this.state === 'song' ? s?.song : null;
      return {state: this.state, ready: this.ready, failed: this.failed, paused: this.paused,
        station: station?.id || null, stationName: station ? `${station.name} ${station.frequency}` : null,
        title: song?.title || null, genre: song?.genre || null, caption: this.caption,
        transitions: s?.transitions || 0, skips: this.skips, cachedClips: this.buffers.size,
        recentSongs: s ? [...s.recentSongs] : []};
    }

    /** One short human-readable line for captions / now playing. */
    label() {
      const snap = this.snapshot();
      if (snap.caption) return snap.caption;
      if (snap.title) return `${snap.stationName} · ${snap.title}`;
      return '';
    }

    dispose() {
      this.halt();
      this.disposed = true;
      if (this.element) { try { this.element.removeAttribute?.('src'); this.element.load?.(); } catch (_) {} }
      this.mediaSource?.disconnect?.();
      this.buffers.clear();
    }
  }

  CannonballRadioProgramme.Sequencer = RadioSequencer;
  root.CannonballRadioProgramme = CannonballRadioProgramme;
  if (typeof module !== 'undefined') module.exports = {CannonballRadioProgramme, RadioSequencer};
})(typeof window !== 'undefined' ? window : globalThis);
