/* Dalil sound engine. Every sound is made in the browser with the Web Audio API:
   no audio files, no network, no account. The Flutter app calls it through window.dalilSfx. */
(function () {
  'use strict';

  var AC = window.AudioContext || window.webkitAudioContext;
  var S = {
    ctx: null, master: null, dry: null, wet: null, verb: null, analyser: null, bus: null,
    on: false, volume: 0.6, preset: 'cream', custom: null,
    tune: { pitch: 0, decay: 1, bright: 0.5, reverb: 0.15, human: 0.25, pan: 0.2 },
    ambVol: 0.5, amb: {}, noiseBuf: null, last: 0,
  };

  /* A layer is one part of a click.
     k: 'o' oscillator, 'n' filtered noise.   f -> f2: pitch glide (Hz).   g: loudness.   d: decay (s).
     ft/ff/q: filter type, frequency, resonance.   at: delay before the layer starts (s). */
  var P = {
    cream: [{ k: 'o', t: 'sine', f: 170, f2: 95, g: 0.9, d: 0.09 }, { k: 'n', g: 0.22, d: 0.03, ft: 'bandpass', ff: 1800, q: 0.9 }],
    thock: [{ k: 'o', t: 'sine', f: 120, f2: 58, g: 1.0, d: 0.15 }, { k: 'o', t: 'triangle', f: 240, f2: 130, g: 0.35, d: 0.07 }, { k: 'n', g: 0.12, d: 0.02, ft: 'lowpass', ff: 1400, q: 0.7 }],
    butter: [{ k: 'o', t: 'sine', f: 320, f2: 210, g: 0.7, d: 0.07 }, { k: 'n', g: 0.1, d: 0.04, ft: 'lowpass', ff: 900, q: 0.6 }],
    bubble: [{ k: 'o', t: 'sine', f: 480, f2: 980, g: 0.8, d: 0.08 }, { k: 'o', t: 'sine', f: 960, f2: 1500, g: 0.18, d: 0.05 }],
    bump: [{ k: 'o', t: 'sine', f: 230, f2: 110, g: 0.85, d: 0.1 }, { k: 'n', g: 0.5, d: 0.012, ft: 'bandpass', ff: 2600, q: 1.8 }],
    wood: [{ k: 'o', t: 'triangle', f: 420, f2: 250, g: 0.8, d: 0.07 }, { k: 'n', g: 0.3, d: 0.025, ft: 'bandpass', ff: 1300, q: 1.2 }],
    glass: [{ k: 'o', t: 'sine', f: 1850, f2: 1800, g: 0.5, d: 0.14 }, { k: 'o', t: 'sine', f: 2790, f2: 2760, g: 0.28, d: 0.1 }, { k: 'n', g: 0.06, d: 0.01, ft: 'highpass', ff: 5000, q: 0.7 }],
    blue: [{ k: 'n', g: 0.9, d: 0.014, ft: 'bandpass', ff: 4200, q: 5 }, { k: 'o', t: 'square', f: 2400, f2: 1900, g: 0.16, d: 0.02 }, { k: 'o', t: 'sine', f: 190, f2: 110, g: 0.5, d: 0.06 }, { k: 'n', g: 0.6, d: 0.012, ft: 'bandpass', ff: 3600, q: 4, at: 0.045 }],
    typewriter: [{ k: 'n', g: 0.8, d: 0.02, ft: 'highpass', ff: 3000, q: 0.8 }, { k: 'o', t: 'sawtooth', f: 900, f2: 480, g: 0.14, d: 0.04 }, { k: 'o', t: 'sine', f: 140, f2: 80, g: 0.6, d: 0.08 }, { k: 'n', g: 0.4, d: 0.015, ft: 'bandpass', ff: 2200, q: 2, at: 0.07 }],
    chime: [{ k: 'o', t: 'sine', f: 2093, f2: 2093, g: 0.5, d: 0.32 }, { k: 'o', t: 'sine', f: 3136, f2: 3136, g: 0.3, d: 0.24 }],
    ghost: [{ k: 'n', g: 0.07, d: 0.035, ft: 'lowpass', ff: 900, q: 0.5 }, { k: 'o', t: 'sine', f: 200, f2: 150, g: 0.12, d: 0.05 }],
    oud: [{ k: 'o', t: 'triangle', f: 196, f2: 194, g: 0.7, d: 0.5 }, { k: 'o', t: 'sine', f: 392, f2: 390, g: 0.35, d: 0.34 }, { k: 'o', t: 'sine', f: 588, f2: 586, g: 0.12, d: 0.2 }, { k: 'n', g: 0.18, d: 0.02, ft: 'bandpass', ff: 1500, q: 1.4 }],
    arcade: [{ k: 'o', t: 'square', f: 880, f2: 1320, g: 0.22, d: 0.07 }, { k: 'o', t: 'square', f: 1320, f2: 1760, g: 0.14, d: 0.06, at: 0.05 }],
    drop: [{ k: 'o', t: 'sine', f: 950, f2: 320, g: 0.8, d: 0.12 }, { k: 'n', g: 0.05, d: 0.01, ft: 'highpass', ff: 4000, q: 0.7 }],
    marimba: [{ k: 'o', t: 'sine', f: 523, f2: 521, g: 0.8, d: 0.3 }, { k: 'o', t: 'sine', f: 1568, f2: 1560, g: 0.22, d: 0.09 }],
  };

  function clamp(v, a, b) { v = Number(v); if (!isFinite(v)) v = a; return Math.max(a, Math.min(b, v)); }

  function ensure() {
    if (!AC) return false;
    if (!S.ctx) {
      var c = new AC();
      S.ctx = c;
      S.master = c.createGain();
      S.analyser = c.createAnalyser();
      S.analyser.fftSize = 256;
      S.analyser.smoothingTimeConstant = 0.78;
      var comp = c.createDynamicsCompressor();
      S.bus = c.createGain();            // all sounds go in here
      S.dry = c.createGain();
      S.wet = c.createGain();
      S.verb = c.createConvolver();
      S.verb.buffer = impulse(c, 1.3);
      S.bus.connect(S.dry); S.bus.connect(S.verb); S.verb.connect(S.wet);
      S.dry.connect(comp); S.wet.connect(comp);
      comp.connect(S.master); S.master.connect(S.analyser); S.analyser.connect(c.destination);
      S.noiseBuf = noise(c, 4);
      apply();
    }
    if (S.ctx.state === 'suspended') { try { S.ctx.resume(); } catch (e) {} }
    return true;
  }

  function impulse(c, secs) {
    var n = Math.floor(c.sampleRate * secs), b = c.createBuffer(2, n, c.sampleRate);
    for (var ch = 0; ch < 2; ch++) {
      var d = b.getChannelData(ch);
      for (var i = 0; i < n; i++) d[i] = (Math.random() * 2 - 1) * Math.pow(1 - i / n, 2.6);
    }
    return b;
  }

  function noise(c, secs) {
    var n = Math.floor(c.sampleRate * secs), b = c.createBuffer(1, n, c.sampleRate), d = b.getChannelData(0);
    for (var i = 0; i < n; i++) d[i] = Math.random() * 2 - 1;
    return b;
  }

  function apply() {
    if (!S.ctx) return;
    var t = S.ctx.currentTime;
    S.master.gain.setTargetAtTime(S.on ? S.volume : 0, t, 0.02);
    S.dry.gain.setTargetAtTime(1 - S.tune.reverb * 0.35, t, 0.02);
    S.wet.gain.setTargetAtTime(S.tune.reverb * 0.9, t, 0.02);
  }

  function params() {
    // custom (from the matrix) or a named preset
    if (S.custom) return S.custom;
    return { layers: P[S.preset] || P.cream, pitch: 1, weight: 0.5 };
  }

  function layer(L, base, pm, wt, hum, pan) {
    var c = S.ctx, t0 = c.currentTime + (L.at || 0);
    var dec = Math.max(0.01, L.d * (0.7 + 0.8 * wt) * S.tune.decay);
    var g = c.createGain();
    var low = L.f ? L.f < 400 : false;
    var amp = L.g * (low ? (0.5 + wt) : (1.3 - 0.6 * wt)) * base;
    g.gain.setValueAtTime(0.0001, t0);
    g.gain.exponentialRampToValueAtTime(Math.max(0.0002, amp), t0 + 0.002);
    g.gain.exponentialRampToValueAtTime(0.0001, t0 + dec);
    var src;
    if (L.k === 'o') {
      src = c.createOscillator();
      src.type = L.t;
      var semi = (S.tune.pitch + (hum ? (Math.random() * 2 - 1) * 1.2 * S.tune.human : 0));
      var k = pm * Math.pow(2, semi / 12);
      src.frequency.setValueAtTime(L.f * k, t0);
      src.frequency.exponentialRampToValueAtTime(Math.max(20, L.f2 * k), t0 + dec);
    } else {
      src = c.createBufferSource();
      src.buffer = S.noiseBuf;
    }
    var node = src, f = null;
    if (L.ft) {
      f = c.createBiquadFilter();
      f.type = L.ft;
      var bright = Math.pow(2, (S.tune.bright - 0.5) * 2); // 0.5x .. 2x
      f.frequency.value = Math.min(18000, L.ff * pm * bright);
      f.Q.value = L.q || 0.8;
      src.connect(f); node = f;
    } else if (L.k === 'o') {
      // oscillators: a gentle low-pass that the brightness control moves
      f = c.createBiquadFilter(); f.type = 'lowpass';
      f.frequency.value = Math.min(18000, 1500 * Math.pow(2, (S.tune.bright - 0.5) * 6));
      src.connect(f); node = f;
    }
    node.connect(g);
    var out = g;
    if (c.createStereoPanner) {
      var p = c.createStereoPanner();
      p.pan.value = (Math.random() * 2 - 1) * S.tune.pan * pan;
      g.connect(p); out = p;
    }
    out.connect(S.bus);
    if (L.k === 'n') src.start(t0, Math.random() * 3, dec + 0.05); else { src.start(t0); src.stop(t0 + dec + 0.05); }
  }

  function playLayers(layers, base, pm, wt, hum, pan) {
    for (var i = 0; i < layers.length; i++) layer(layers[i], base, pm, wt, hum, pan);
  }

  var api = {
    available: function () { return !!AC; },
    enable: function (on) { S.on = !!on; if (S.on) ensure(); apply(); },
    volume: function (v) { S.volume = clamp(v, 0, 1); apply(); },
    preset: function (id) { if (P[id]) { S.preset = id; S.custom = null; } },
    matrix: function (x, y) {
      // x: pitch (0 deep .. 1 high), y: weight (0 light .. 1 heavy); morphs the current preset
      var base = P[S.preset] || P.cream;
      S.custom = { layers: base, pitch: Math.pow(2, (clamp(x, 0, 1) - 0.5) * 2), weight: clamp(y, 0, 1) };
    },
    tune: function (pitch, decay, bright, reverb, human, pan) {
      S.tune = { pitch: clamp(pitch, -12, 12), decay: clamp(decay, 0.4, 2.5), bright: clamp(bright, 0, 1), reverb: clamp(reverb, 0, 1), human: clamp(human, 0, 1), pan: clamp(pan, 0, 1) };
      apply();
    },
    play: function (kind) {
      if (!S.on || !ensure()) return;
      var now = performance.now();
      if (now - S.last < 12) return; // never stack two sounds in the same instant
      S.last = now;
      var p = params(), tune = S.tune;
      switch (kind) {
        case 'space': playLayers(p.layers, 1.05, p.pitch * 0.78, Math.min(1, p.weight + 0.15), true, 1); break;
        case 'enter': playLayers(p.layers, 1.15, p.pitch * 0.62, Math.min(1, p.weight + 0.25), true, 1); break;
        case 'key': playLayers(p.layers, 0.9, p.pitch, p.weight, true, 1); break;
        case 'done': chord([523.25, 659.25, 783.99], 0.11, 0.32); break;
        case 'warn': chord([330, 247], 0.16, 0.45, 'triangle'); break;
        case 'error': chord([220, 196], 0.12, 0.3, 'triangle'); break;
        default: playLayers(p.layers, 1, p.pitch, p.weight, true, 1);
      }
    },
    preview: function () { api.play('tap'); },

    ambient: function (id, on) {
      if (!ensure()) return;
      if (on) startAmb(id); else stopAmb(id);
    },
    ambientVolume: function (v) {
      S.ambVol = clamp(v, 0, 1);
      for (var id in S.amb) if (S.amb[id]) S.amb[id].out.gain.setTargetAtTime(ambGain(id), S.ctx.currentTime, 0.05);
    },
    stopAll: function () { for (var id in S.amb) stopAmb(id); },

    bands: function (n) {
      n = Math.max(4, Math.min(64, n | 0));
      var out = [];
      if (!S.analyser || !S.on) { for (var z = 0; z < n; z++) out.push('0'); return out.join(','); }
      var d = new Uint8Array(S.analyser.frequencyBinCount);
      S.analyser.getByteFrequencyData(d);
      var usable = Math.floor(d.length * 0.8);
      for (var i = 0; i < n; i++) {
        var a = Math.floor(Math.pow(i / n, 1.7) * usable), b = Math.max(a + 1, Math.floor(Math.pow((i + 1) / n, 1.7) * usable)), s = 0;
        for (var j = a; j < b; j++) s += d[j];
        out.push(((s / (b - a)) / 255).toFixed(3));
      }
      return out.join(',');
    },
  };

  function chord(freqs, gap, dec, type) {
    var c = S.ctx;
    for (var i = 0; i < freqs.length; i++) {
      var t0 = c.currentTime + i * gap, o = c.createOscillator(), g = c.createGain();
      o.type = type || 'sine';
      o.frequency.value = freqs[i] * Math.pow(2, S.tune.pitch / 12);
      g.gain.setValueAtTime(0.0001, t0);
      g.gain.exponentialRampToValueAtTime(0.32, t0 + 0.01);
      g.gain.exponentialRampToValueAtTime(0.0001, t0 + dec * S.tune.decay);
      o.connect(g); g.connect(S.bus);
      o.start(t0); o.stop(t0 + dec * S.tune.decay + 0.05);
    }
  }

  /* ----- ambient soundscapes: all made from noise and slow oscillators ----- */
  function ambGain(id) { return S.ambVol * ({ rain: 0.55, brown: 0.7, white: 0.22, wind: 0.5, cafe: 0.4, night: 0.3 }[id] || 0.4); }

  function loopNoise(kind) {
    var c = S.ctx, src = c.createBufferSource();
    if (kind === 'brown') {
      var n = c.sampleRate * 4, b = c.createBuffer(1, n, c.sampleRate), d = b.getChannelData(0), last = 0;
      for (var i = 0; i < n; i++) { var w = Math.random() * 2 - 1; last = (last + 0.02 * w) / 1.02; d[i] = last * 3.5; }
      src.buffer = b;
    } else src.buffer = S.noiseBuf;
    src.loop = true;
    return src;
  }

  function startAmb(id) {
    if (S.amb[id]) return;
    var c = S.ctx, out = c.createGain(), nodes = [], timers = [], t = c.currentTime;
    out.gain.setValueAtTime(0.0001, t);
    out.gain.linearRampToValueAtTime(ambGain(id), t + 1.2);
    out.connect(S.bus);
    function chain(src, specs) {
      var n = src;
      for (var i = 0; i < specs.length; i++) {
        var f = c.createBiquadFilter(); f.type = specs[i][0]; f.frequency.value = specs[i][1]; f.Q.value = specs[i][2] || 0.7;
        n.connect(f); n = f; nodes.push(f);
      }
      n.connect(out); return n;
    }
    function lfo(rate, depth, param) {
      var o = c.createOscillator(), g = c.createGain();
      o.frequency.value = rate; g.gain.value = depth; o.connect(g); g.connect(param); o.start(); nodes.push(o, g);
    }
    function sprinkle(minMs, maxMs, fn) {
      (function next() {
        var id2 = setTimeout(function () { if (S.amb[id]) { fn(); next(); } }, minMs + Math.random() * (maxMs - minMs));
        timers.push(id2);
      })();
    }
    var src;
    if (id === 'rain') {
      src = loopNoise('white'); src.start(); nodes.push(src);
      chain(src, [['highpass', 700], ['lowpass', 7500]]);
      sprinkle(60, 260, function () { drip(out, 2500 + Math.random() * 3000, 0.05); });
    } else if (id === 'brown') {
      src = loopNoise('brown'); src.start(); nodes.push(src); chain(src, [['lowpass', 500]]);
    } else if (id === 'white') {
      src = loopNoise('white'); src.start(); nodes.push(src); chain(src, [['lowpass', 9000]]);
    } else if (id === 'wind') {
      src = loopNoise('white'); src.start(); nodes.push(src);
      var bp = chain(src, [['bandpass', 420, 0.8]]);
      var f = nodes[nodes.length - 1];
      lfo(0.11, 260, f.frequency); lfo(0.07, 0.25, out.gain);
    } else if (id === 'cafe') {
      src = loopNoise('white'); src.start(); nodes.push(src);
      chain(src, [['bandpass', 1100, 0.45], ['lowpass', 2600]]);
      sprinkle(900, 3200, function () { drip(out, 1800 + Math.random() * 1600, 0.12); });
    } else if (id === 'night') {
      [110, 165, 220.5].forEach(function (fq, i) {
        var o = c.createOscillator(), g = c.createGain();
        o.type = 'sine'; o.frequency.value = fq; g.gain.value = 0.25 / (i + 1);
        o.connect(g); g.connect(out); o.start(); nodes.push(o, g);
        lfo(0.05 + i * 0.03, 0.08, g.gain);
      });
    } else { out.disconnect(); return; }
    S.amb[id] = { out: out, nodes: nodes, timers: timers };
  }

  function drip(dest, freq, dur) {
    var c = S.ctx, t = c.currentTime, s = c.createBufferSource(), f = c.createBiquadFilter(), g = c.createGain();
    s.buffer = S.noiseBuf; f.type = 'bandpass'; f.frequency.value = freq; f.Q.value = 6;
    g.gain.setValueAtTime(0.5, t); g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
    s.connect(f); f.connect(g); g.connect(dest); s.start(t, Math.random() * 3, dur + 0.02);
  }

  function stopAmb(id) {
    var a = S.amb[id];
    if (!a) return;
    S.amb[id] = null;
    a.timers.forEach(clearTimeout);
    var t = S.ctx.currentTime;
    a.out.gain.cancelScheduledValues(t);
    a.out.gain.setTargetAtTime(0.0001, t, 0.25);
    setTimeout(function () {
      a.nodes.forEach(function (n) { try { if (n.stop) n.stop(); } catch (e) {} try { n.disconnect(); } catch (e) {} });
      try { a.out.disconnect(); } catch (e) {}
    }, 1400);
  }

  api._presets = Object.keys(P);
  window.dalilSfx = api;
})();
