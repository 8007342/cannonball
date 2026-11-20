/* Cannonball radio programme: wordless songs joined by hard radio cuts.
 * song -> tuning buzz -> interjection (DJ line or state-derived report) ->
 * tuning buzz -> another song. Songs stream through one reused media element
 * (never fully decoded, one download at a time); buzz and presenter clips are
 * tiny decoded buffers scheduled on the audio clock. No network service. */
(function (root) {
  'use strict';

  // THE cadence knob (documented in art/music/README.md): a station visit
  // plays 1..STATION_CADENCE songs before the programme tunes elsewhere, so
  // the dial moves roughly every 1-2 songs. 1 = new station at every break.
  const STATION_CADENCE = 2;
  const REPORT_TTL = 100; // seconds a queued report stays relevant (< one 120 s level)
  const DEFAULT_RULES = {recentSongs: 10, recentLines: 8, identEvery: 2,
    maxSongsPerStation: STATION_CADENCE,
    maxSongSeconds: 150, // longer songs fade into the buzz at a phrase boundary
    minSongSeconds: 60, trimFade: 1.5,
    preloadSeconds: 20}; // the next song starts buffering this long before the break

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
      this.run = 0; this.runLength = 1; // songs played / allowed on this station visit
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
      if (!change && current && this.run < this.runLength && this.freshSongs(current.id).length) return current.id;
      let pool = eligible.filter(s => s.id !== this.station);
      // The only local station is the current one: stay unless the listener
      // asked for a change (then any other station is better than a refusal).
      if (!pool.length) pool = change ? this.stations.filter(s => s.id !== this.station) : eligible;
      if (!pool.length) pool = eligible;
      const fresh = pool.filter(s => this.freshSongs(s.id).length);
      if (fresh.length) return this.pick(fresh).id;
      // Nothing fresh elsewhere: avoiding a repeat beats the cadence, so a
      // current station with fresh songs may keep the dial (not on a skip).
      if (!change && current && this.freshSongs(current.id).length) return current.id;
      // Still nothing: the station owning the least recently played song.
      const ids = new Set(pool.map(s => s.id));
      if (!change && current) ids.add(current.id);
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
      if (plan.station !== this.station) {
        this.run = 0;
        const most = Math.max(1, Math.floor(this.rules.maxSongsPerStation) || 1);
        this.runLength = 1 + Math.min(most - 1, Math.floor(this.random() * most));
      }
      this.run++;
      this.station = plan.station; this.song = plan.song; this.transitions++;
      this.remember(this.recentSongs, plan.song?.id, Math.min(this.rules.recentSongs, Math.max(1, this.songs.length - 2)));
      this.remember(this.recentLines, plan.line?.id, Math.min(this.rules.recentLines, Math.max(1, this.lines.length - 2)));
    }
    stationInfo(id) { return this.stations.find(s => s.id === id) || null; }
    /** Seconds after which `song` fades into the next break: its full length,
     * or for long songs the last 8-bar phrase boundary under maxSongSeconds. */
    playLength(song, duration = song?.duration) {
      const length = Number.isFinite(duration) && duration > 0 ? duration : song?.duration || 0;
      const limit = Math.max(this.rules.minSongSeconds, this.rules.maxSongSeconds);
      if (!(length > limit)) return length;
      const phrase = song?.bpm > 0 ? 32 * 60 / song.bpm : 8;
      const cut = Math.floor(limit / phrase) * phrase;
      return Math.min(length, cut >= this.rules.minSongSeconds ? cut : Math.ceil(this.rules.minSongSeconds / phrase) * phrase);
    }
  }

  /** One continuous programme for the whole demo. Level changes, restarts and
   * replays never touch it: only mute, station skip, pause/hidden and urgent
   * gameplay bulletins do, and a bulletin returns to the same song position.
   * Two reused media elements alternate: the current song plays on one while
   * the next song buffers on the other during its last `preloadSeconds`. */
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
      this.timer = null; this.pauseTimer = null; this.unlocked = false;
      this.element = null; this.spare = null; this.gains = new Map(); this.mediaSources = [];
      this.plan = null; this.next = null; this.queuedReport = null; this.queuedAt = 0; this.caption = '';
      this.skips = 0; this.lastSkipAt = -1; this.songFailures = 0; this.disposed = false;
      this.preloaded = null; this.fading = false; this.bulletins = 0; this.log = [];
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

    note(event, extra = {}) {
      this.log.push({t: Math.round((this.context.currentTime || 0) * 100) / 100, event,
        station: this.sequencer?.station ?? null, song: this.sequencer?.song?.id ?? null, ...extra});
      if (this.log.length > 60) this.log.shift();
    }

    /** Must run inside a user gesture: unlocks both reused media elements. */
    unlock() {
      if (this.disposed || this.unlocked) return;
      const elements = [this.mediaElement(), this.spareElement()].filter(Boolean);
      if (!elements.length) return;
      this.unlocked = true;
      for (const element of elements) {
        try {
          element.muted = true;
          Promise.resolve(element.play()).then(() => {
            if (element !== this.element || this.state !== 'song' || this.paused) element.pause();
            element.muted = false;
          }).catch(() => { element.muted = false; });
        } catch (_) { element.muted = false; }
      }
    }

    createElement() {
      if (this.disposed) return null;
      const element = this.createAudio();
      if (!element) return null;
      element.preload = 'auto';
      element.crossOrigin = 'anonymous';
      element.setAttribute?.('playsinline', '');
      element.addEventListener('ended', () => {
        if (element === this.element && this.state === 'song') this.transition();
      });
      element.addEventListener('error', () => {
        if (element === this.element && this.state === 'song') this.songError();
        else if (element === this.spare) { this.preloaded = null; if (this.state === 'loading') this.songError(); }
      });
      element.addEventListener('timeupdate', () => { if (element === this.element) this.tick(); });
      try {
        if (this.context.createMediaElementSource) {
          const source = this.context.createMediaElementSource(element);
          let node = source;
          if (this.context.createGain) {
            const gain = this.context.createGain(); gain.gain.value = 1;
            source.connect(gain); node = gain; this.gains.set(element, gain);
          }
          node.connect(this.output);
          this.mediaSources.push(source, node);
        }
      } catch (_) { /* Element plays straight to the output device. */ }
      return element;
    }

    mediaElement() { if (!this.element) this.element = this.createElement(); return this.element; }
    spareElement() {
      if (!this.spare) this.spare = this.createElement();
      // Hosts that hand back one shared element still work, without preload.
      return this.spare && this.spare !== this.element ? this.spare : this.mediaElement();
    }

    setGain(element, value, seconds = 0) {
      const gain = this.gains.get(element)?.gain;
      if (!gain) return;
      const now = this.context.currentTime;
      if (seconds > 0 && gain.linearRampToValueAtTime) {
        gain.cancelScheduledValues?.(now); gain.setValueAtTime?.(gain.value, now);
        gain.linearRampToValueAtTime(value, now + seconds);
      } else { gain.cancelScheduledValues?.(now); gain.value = value; }
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
            while (this.buffers.size >= 16) this.buffers.delete(this.buffers.keys().next().value);
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

    /** Starts the programme once; later calls (level changes) are no-ops. */
    play(region) {
      this.setRegion(region);
      if (!this.ready || this.paused || this.started) return this.ready;
      this.started = true;
      for (const buzz of this.sequencer.buzz) this.buffer(buzz.src); // every dial sweep, ahead of time
      this.note('on', {region: this.region});
      // Turning the radio on: buzz, station ident (or a queued report), song.
      this.transition({cut: false});
      return true;
    }

    /** The region only steers the station choice at the next natural break. */
    setRegion(region) { if (typeof region === 'string' && region) this.region = region; }

    takeReport() {
      const fresh = this.queuedReport && this.context.currentTime - this.queuedAt <= REPORT_TTL;
      const report = fresh ? this.queuedReport : null;
      this.queuedReport = null;
      return report;
    }

    /** State-derived report. Urgent ones cut in now and return to the same
     * song position; others wait for the next break (latest wins, expires). */
    interject(text, region, urgent = true) {
      this.setRegion(region);
      if (!this.ready || typeof text !== 'string' || !text.trim()) return false;
      this.queuedReport = text;
      this.queuedAt = this.context.currentTime;
      if (!urgent || !this.started || this.paused) return true;
      if (this.state === 'song' && !this.fading) this.bulletin();
      else if (['line', 'report', 'buzz-out', 'loading'].includes(this.state) && this.plan) {
        // Mid-break: the newest report replaces whatever is being said.
        this.epoch++; this.timers.clear(this.timer); this.stopSources();
        this.stageVoice(this.plan);
      }
      // 'buzz-in' picks the report up when its buzz ends.
      return true;
    }

    /** Urgent cut-in: pause the stream in place, buzz, report, buzz, resume. */
    bulletin() {
      const s = this.sequencer;
      this.epoch++; this.timers.clear(this.timer); this.stopSources();
      this.cutSong();
      this.bulletins++;
      this.plan = {resume: true, station: s.station, song: s.song, line: null,
        buzzIn: s.chooseBuzz(), buzzOut: s.chooseBuzz()};
      this.note('bulletin', {at: this.position()});
      this.stageBuzzIn(this.plan);
    }

    /** User station skip: hard cut to a different station with its ident. */
    skip() {
      if (!this.ready || this.paused || !this.started) return false;
      const now = this.context.currentTime;
      if (now - this.lastSkipAt < .35) return false;
      this.lastSkipAt = now; this.skips++;
      this.note('skip');
      this.transition({change: true});
      return true;
    }

    cutSong() {
      const element = this.element;
      if (element) { try { element.pause(); } catch (_) {} }
    }

    position() { const t = this.element?.currentTime; return Number.isFinite(t) ? Math.round(t * 10) / 10 : 0; }

    /** Natural break: song ended (or was trimmed), skip, or a failed stream. */
    transition({change = false, cut = true} = {}) {
      if (!this.ready) return;
      this.epoch++; this.timers.clear(this.timer); this.stopSources();
      if (cut) this.cutSong();
      this.fading = false;
      // Reuse the plan whose clips (and song) were precached during the song,
      // unless the listener skipped or the region no longer suits that station.
      const eligible = this.sequencer.stationsFor(this.region).some(s => s.id === this.next?.station);
      const plan = !change && this.next && eligible ? this.next : this.sequencer.plan(this.region, {change});
      this.next = null;
      this.plan = plan;
      this.prefetch(plan);
      this.loadIncoming(plan);
      this.note('break', {next: plan.song.id, nextStation: plan.station, change: plan.changed});
      this.stageBuzzIn(plan);
    }

    /** Put `plan`'s song on the spare element unless it is already buffering there. */
    loadIncoming(plan) {
      const element = this.spareElement();
      if (!element) return;
      const src = this.url(plan.song.src);
      if (this.preloaded === src && element.src === src) return;
      if (element === this.element) this.cutSong();
      element.src = src;
      try { element.load(); } catch (_) {}
      this.preloaded = src;
    }

    /** Media-clock tick (timeupdate): preload the next song and trim long ones. */
    tick() {
      if (this.state !== 'song' || this.paused || !this.ready) return;
      const element = this.element;
      const song = this.sequencer.song;
      const length = this.sequencer.playLength(song, element.duration);
      const left = length - (element.currentTime || 0);
      if (!this.next) { this.next = this.sequencer.plan(this.region); this.prefetch(this.next); }
      if (left <= this.sequencer.rules.preloadSeconds && this.spare && this.spare !== this.element &&
          this.preloaded !== this.url(this.next.song.src)) {
        this.loadIncoming(this.next);
        this.note('preload', {next: this.next.song.id, left: Math.round(left)});
      }
      const fullLength = Number.isFinite(element.duration) && element.duration > 0 ? element.duration : song?.duration;
      if (!this.fading && length < fullLength - .5 && left <= this.sequencer.rules.trimFade) {
        // Long song: fade into the buzz at the phrase boundary.
        this.fading = true;
        this.setGain(element, 0, Math.max(.05, left));
        this.note('trim', {at: Math.round(length)});
        this.later(Math.max(0, left), () => this.transition());
      }
    }

    stageBuzzIn(plan) {
      this.state = 'buzz-in'; this.caption = '';
      this.playClip(plan.buzzIn, () => this.stageVoice(plan));
    }

    stageVoice(plan) {
      const epoch = this.epoch;
      const report = this.takeReport();
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
      if (this.paused) return;
      this.epoch++; this.timers.clear(this.timer); this.stopSources();
      this.state = 'buzz-out';
      if (plan.line && this.caption === (plan.line.caption || plan.line.text)) this.caption = '';
      const duration = this.playClip(plan.buzzOut, () => {});
      // Start (or resume) the stream just before the buzz ends: a hard radio cut.
      this.later(Math.max(0, duration - .08), () => plan.resume ? this.resumeSong(plan) : this.startSong(plan));
    }

    /** Back from a bulletin (or a pause): same song, same position. */
    resumeSong(plan) {
      const element = this.element;
      if (!element || plan.song?.id !== this.sequencer.song?.id) { this.transition({cut: false}); return; }
      this.stopSources();
      this.state = 'song'; this.caption = ''; this.plan = plan;
      this.setGain(element, 1);
      Promise.resolve(element.play()).catch(() => this.songError());
      this.note('resume', {at: this.position()});
    }

    startSong(plan, waited = 0) {
      const element = this.spareElement();
      if (!element) { this.failed = true; this.state = 'failed'; return; }
      if ((element.readyState ?? 4) < 3 && waited < 8) {
        // Still buffering: hold the dial on quiet static instead of silence.
        if (this.state !== 'loading') {
          this.state = 'loading'; this.note('static-hold');
          this.playClip(plan.buzzOut, () => {}, {loop: true, gain: .35});
        }
        this.later(.25, () => this.startSong(plan, waited + .25));
        return;
      }
      if (waited >= 8) { this.songError(); return; }
      this.stopSources();
      const previous = this.element;
      if (previous && previous !== element) { try { previous.pause(); } catch (_) {} }
      this.element = element; this.spare = previous && previous !== element ? previous : this.spare;
      this.preloaded = null; this.fading = false;
      this.sequencer.commit(plan);
      this.state = 'song'; this.caption = ''; this.songFailures = 0;
      this.setGain(element, 1);
      try { element.currentTime = 0; } catch (_) {}
      Promise.resolve(element.play()).catch(() => this.songError());
      this.note('song', {title: plan.song.title});
      // Plan the next break now and precache its tiny clips while the song plays.
      this.next = this.sequencer.plan(this.region);
      this.prefetch(this.next);
    }

    songError() {
      if (!this.ready) return;
      this.songFailures++;
      this.note('error', {failures: this.songFailures});
      this.preloaded = null;
      if (this.songFailures >= 3) { this.failed = true; this.stopSources(); this.cutSong(); this.state = 'failed'; return; }
      this.next = null;
      this.transition();
    }

    /** Pause/mute/hidden. Deferred briefly so a pause/resume pair in one task
     * never interrupts the song; resume continues the same song in place. */
    setPaused(value) {
      value = Boolean(value);
      if (value === this.paused && !this.pauseTimer) return;
      if (!value) {
        if (this.pauseTimer) { this.timers.clear(this.pauseTimer); this.pauseTimer = null; this.paused = false; return; }
        this.paused = false;
        if (!this.started || !this.ready) return;
        this.note('unpause', {at: this.position()});
        if (this.state === 'song' && this.fading) this.transition();
        else if (this.state === 'song') Promise.resolve(this.element?.play()).catch(() => this.songError());
        else if (this.state === 'buzz-in' && this.plan) this.stageBuzzIn(this.plan);
        else if (this.plan) this.stageBuzzOut(this.plan);
        return;
      }
      if (this.pauseTimer) return;
      this.pauseTimer = this.timers.set(() => { this.pauseTimer = null; this.stopNow(); }, 60);
    }

    stopNow() {
      this.paused = true;
      this.epoch++; this.timers.clear(this.timer); this.stopSources();
      this.cutSong();
      if (this.started) this.note('pause', {at: this.position()});
      this.onHalt();
    }

    /** Hard stop now (mute, proof audio off). Resume continues in place. */
    halt() {
      if (this.pauseTimer) { this.timers.clear(this.pauseTimer); this.pauseTimer = null; }
      this.stopNow();
    }

    reset() {
      this.halt();
      this.started = false; this.state = 'idle'; this.caption = ''; this.plan = null; this.next = null;
      this.queuedReport = null; this.preloaded = null; this.fading = false;
      if (this.sequencer) this.sequencer = new RadioSequencer(this.sequencer.programme, this.random);
    }

    snapshot() {
      const s = this.sequencer;
      const station = s?.stationInfo(this.state === 'song' ? s.station : this.plan?.station ?? s?.station);
      const song = this.state === 'song' ? s?.song : null;
      return {state: this.state, ready: this.ready, failed: this.failed, paused: this.paused,
        station: station?.id || null, stationName: station ? `${station.name} ${station.frequency}` : null,
        title: song?.title || null, genre: song?.genre || null, caption: this.caption,
        songId: s?.song?.id || null, position: this.position(), src: this.element?.src || null,
        nextSong: this.next?.song?.id || null, preloaded: this.preloaded,
        stationRun: s?.run || 0, stationRunLength: s?.runLength || 0, cadence: s?.rules.maxSongsPerStation,
        transitions: s?.transitions || 0, skips: this.skips, bulletins: this.bulletins,
        cachedClips: this.buffers.size, recentSongs: s ? [...s.recentSongs] : [], log: this.log.slice(-25)};
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
      for (const element of new Set([this.element, this.spare])) {
        if (element) { try { element.removeAttribute?.('src'); element.load?.(); } catch (_) {} }
      }
      for (const node of this.mediaSources) node.disconnect?.();
      this.buffers.clear();
    }
  }

  RadioSequencer.CADENCE = STATION_CADENCE;
  CannonballRadioProgramme.Sequencer = RadioSequencer;
  root.CannonballRadioProgramme = CannonballRadioProgramme;
  if (typeof module !== 'undefined') module.exports = {CannonballRadioProgramme, RadioSequencer};
})(typeof window !== 'undefined' ? window : globalThis);
