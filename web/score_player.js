/* Original prepared scores and synthetic radio; no network service during play. */
(function(root) {
  'use strict';
  class CannonballScorePlayer {
    constructor(context, output, options = {}) {
      this.context = context; this.output = output;
      this.fetch = options.fetch || root.fetch?.bind(root);
      this.base = options.base || new URL('assets/assets/audio/', root.document.baseURI).href;
      this.cache = new Map(); this.pending = new Map(); this.catalog = null;
      this.music = null; this.voice = null; this.track = null;
      this.epoch = 0; this.voiceEpoch = 0; this.disposed = false;
      this.snippets = new Map(); this.warming = new Map();
      this.state = 'idle'; this.voiceMode = 'device fallback'; this.failedAt = 0;
    }
    async prepare() {
      if (!this.catalogPromise) {
        this.catalogPromise = this.fetch(new URL('catalog.json', this.base).href,
          {signal: AbortSignal.timeout(8000)})
          .then(r => {if (!r.ok) throw Error('catalog'); return r.json();})
          .then(data => this.catalog = data).catch(() => null);
      }
      return this.catalogPromise;
    }
    async buffer(src) {
      if (this.cache.has(src)) return this.cache.get(src);
      if (!this.pending.has(src)) {
        const promise = this.fetch(new URL(src, this.base).href,
          {signal: AbortSignal.timeout(12000)})
          .then(r => {if (!r.ok) throw Error('audio'); return r.arrayBuffer();})
          .then(data => this.context.decodeAudioData(data))
          .then(buffer => {
            if (this.disposed) return null;
            // At most one long score plus two short reports (~45 MB at 48 kHz).
            const isMusic = this.catalog?.tracks.some(t => t.src === src);
            if (isMusic) for (const key of this.cache.keys()) {
              if (this.catalog.tracks.some(t => t.src === key)) this.cache.delete(key);
            }
            while (this.cache.size >= 3) this.cache.delete(this.cache.keys().next().value);
            this.cache.set(src, buffer); return buffer;
          }).catch(() => null).finally(() => this.pending.delete(src));
        this.pending.set(src, promise);
      }
      return this.pending.get(src);
    }
    snippetEntry(station, cachedOnly = false) {
      return this.catalog?.surf?.find(entry => entry.station !== station &&
        (!cachedOnly || this.snippets.has(entry.src))) || null;
    }
    async warmSnippet(station, selectedEntry = null) {
      const catalog = await this.prepare();
      // Two tiny alternatives ensure a changed destination can still find a
      // fragment different from both the old and newly selected station.
      if (catalog && !selectedEntry) {
        const entries = (catalog.surf || []).filter(entry => entry.station !== station).slice(0, 2);
        const ready = await Promise.all(entries.map(entry => this.warmSnippet(station, entry)));
        return ready.some(Boolean);
      }
      const entry = selectedEntry;
      if (!entry || this.disposed) return false;
      if (this.snippets.has(entry.src)) return true;
      if (!this.warming.has(entry.src)) {
        const pending = this.fetch(new URL(entry.src, this.base).href,
          {signal: AbortSignal.timeout(4000)})
          .then(r => {if (!r.ok) throw Error('snippet'); return r.arrayBuffer();})
          .then(data => this.context.decodeAudioData(data))
          .then(buffer => {
            if (this.disposed) return false;
            while (this.snippets.size >= 2) this.snippets.delete(this.snippets.keys().next().value);
            this.snippets.set(entry.src, buffer); return true;
          }).catch(() => false).finally(() => this.warming.delete(entry.src));
        this.warming.set(entry.src, pending);
      }
      return this.warming.get(entry.src);
    }
    playSnippet(station) {
      const entry = this.snippetEntry(station, true);
      const buffer = entry && this.snippets.get(entry.src);
      // A station switch never waits for a download. A cold clip is just skipped.
      if (!buffer || this.disposed) return false;
      this.stopMusic();
      const source = this.context.createBufferSource(); source.buffer = buffer;
      source.connect(this.output);
      source.start(this.context.currentTime, 0, Math.min(.68, buffer.duration));
      this.music = source; this.track = entry; this.state = 'snippet';
      source.onended = () => {
        source.disconnect();
        if (this.music === source) {this.music = null; this.state = 'idle';}
      };
      return true;
    }
    stopMusic() {
      ++this.epoch;
      if (this.music) {this.music.onended = null; try {this.music.stop();} catch (_) {} this.music.disconnect();}
      this.music = null; this.track = null; this.state = 'idle';
    }
    async play(station) {
      if (this.disposed || Date.now() < this.failedAt + 5000) return false;
      if (this.track?.station === station && ['loading','playing'].includes(this.state)) return this.state === 'playing';
      this.stopMusic(); const epoch = this.epoch;
      this.track = {station}; this.state = 'loading';
      const catalog = await this.prepare();
      if (epoch !== this.epoch || this.disposed) return false;
      if (!catalog) {this.state = 'failed'; this.failedAt = Date.now(); return false;}
      const track = catalog.tracks.find(t => t.station === station) || catalog.tracks[0];
      this.track = track; this.state = 'loading';
      this.warmSnippet(station);
      const buffer = await this.buffer(track.src);
      if (epoch !== this.epoch || this.disposed) return false;
      if (!buffer) {this.state = 'failed'; this.failedAt = Date.now(); return false;}
      const source = this.context.createBufferSource(); source.buffer = buffer;
      source.loop = true; source.connect(this.output); source.start(this.context.currentTime + .025);
      this.music = source; this.state = 'playing'; return true;
    }
    stopVoice() {
      ++this.voiceEpoch;
      if (this.voice) {this.voice.onended = null; try {this.voice.stop();} catch (_) {} this.voice.disconnect();}
      this.voice = null;
    }
    async report(text, complete) {
      this.stopVoice(); const epoch = this.voiceEpoch;
      const catalog = await this.prepare();
      const entry = catalog?.radio.find(r => r.text === text);
      if (!entry || this.disposed || epoch !== this.voiceEpoch) return false;
      const buffer = await this.buffer(entry.src);
      if (!buffer || this.disposed || epoch !== this.voiceEpoch) return false;
      const source = this.context.createBufferSource(); source.buffer = buffer;
      source.connect(this.output); this.voice = source; this.voiceMode = entry.voice;
      source.onended = () => {
        source.onended = null; source.disconnect();
        if (epoch === this.voiceEpoch && !this.disposed) {this.voice = null; complete();}
      };
      source.start(); return true;
    }
    snapshot() {return {state: this.state, title: this.track?.title || null,
      voice: this.voiceMode, cachedBuffers: this.cache.size, cachedSnippets: this.snippets.size};}
    dispose() {this.disposed = true; this.stopMusic(); this.stopVoice(); this.cache.clear(); this.snippets.clear();}
  }
  root.CannonballScorePlayer = CannonballScorePlayer;
  if (typeof module !== 'undefined') module.exports = CannonballScorePlayer;
})(typeof window !== 'undefined' ? window : globalThis);
