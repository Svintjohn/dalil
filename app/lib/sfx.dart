import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

import 'local_store.dart';
import 'sfx_engine.dart';

/// One click sound. [x] is its pitch and [y] its weight on the acoustic matrix (both 0 to 1, y = 1 is heavy).
class SfxPreset {
  const SfxPreset(this.id, this.name, this.group, this.hint, this.x, this.y);
  final String id, name, group, hint;
  final double x, y;
}

const sfxGroups = ['Linear', 'Tactile', 'Clicky', 'Silent', 'Special'];

/// The ids must match the sounds defined in web/dalil_sfx.js.
const sfxPresets = <SfxPreset>[
  SfxPreset('cream', 'Soft cream', 'Linear', 'Round and quiet', 0.30, 0.60),
  SfxPreset('thock', 'Deep thock', 'Linear', 'Low and full', 0.12, 0.88),
  SfxPreset('bubble', 'Bubble', 'Linear', 'A small rising pop', 0.55, 0.30),
  SfxPreset('bump', 'Tactile bump', 'Tactile', 'A soft bump, then a tick', 0.35, 0.75),
  SfxPreset('wood', 'Wood block', 'Tactile', 'Warm and hollow', 0.50, 0.55),
  SfxPreset('glass', 'Glass tap', 'Tactile', 'Bright and short', 0.85, 0.20),
  SfxPreset('blue', 'Blue click', 'Clicky', 'A sharp double click', 0.80, 0.80),
  SfxPreset('typewriter', 'Typewriter', 'Clicky', 'Strike and return', 0.70, 0.90),
  SfxPreset('butter', 'Butter', 'Silent', 'Smooth and muted', 0.40, 0.35),
  SfxPreset('ghost', 'Ghost', 'Silent', 'Barely there', 0.30, 0.08),
  SfxPreset('oud', 'Oud pluck', 'Special', 'A plucked string', 0.25, 0.70),
  SfxPreset('marimba', 'Marimba', 'Special', 'Wooden bell', 0.65, 0.40),
  SfxPreset('drop', 'Water drop', 'Special', 'Falls as it rings', 0.60, 0.25),
  SfxPreset('arcade', 'Arcade', 'Special', 'Two quick beeps', 0.75, 0.45),
  SfxPreset('chime', 'Chime', 'Special', 'High and ringing', 0.95, 0.15),
];

class AmbientSound {
  const AmbientSound(this.id, this.name, this.hint, this.icon);
  final String id, name, hint;
  final IconData icon;
}

const ambientSounds = <AmbientSound>[
  AmbientSound('rain', 'Rain', 'Steady rain with drops', Icons.water_drop_outlined),
  AmbientSound('brown', 'Brown noise', 'Deep and calm', Icons.waves),
  AmbientSound('white', 'White noise', 'Even and soft', Icons.grain),
  AmbientSound('wind', 'Wind', 'Slow gusts', Icons.air),
  AmbientSound('cafe', 'Café', 'Low voices, soft clinks', Icons.local_cafe_outlined),
  AmbientSound('night', 'Night hum', 'A slow low drone', Icons.nightlight_outlined),
];

/// The sound settings and the one place that talks to the sound engine. Sound is off until the person turns it on.
class Sfx extends ChangeNotifier {
  Sfx({String storageKey = 'dalil.sfx.v1'}) : _key = storageKey;
  static final Sfx instance = Sfx();

  final String _key;

  bool enabled = false;
  double volume = 0.6;
  String presetId = 'cream';
  double? customX; // set while the person has moved the puck away from the preset
  double? customY;
  double pitch = 0; // semitones
  double decay = 1;
  double bright = 0.5;
  double reverb = 0.15;
  double human = 0.25;
  double pan = 0.2;
  bool clicks = true; // a sound for each tap
  bool typing = true; // a sound for each key in a text box
  bool chimes = true; // a sound when a result is ready or a scam is flagged
  double ambientVolume = 0.5;
  final Set<String> ambient = {};

  SfxPreset get preset => sfxPresets.firstWhere((p) => p.id == presetId, orElse: () => sfxPresets.first);
  double get puckX => customX ?? preset.x;
  double get puckY => customY ?? preset.y;
  bool get available => sfxAvailable();

  static double _c(double v, double a, double b) => v < a ? a : (v > b ? b : v);

  double _num(Object? v, double fallback, double min, double max) => v is num && v.isFinite ? _c(v.toDouble(), min, max) : fallback;

  void load() {
    try {
      final raw = LocalStore.read(_key);
      if (raw != null) {
        final j = jsonDecode(raw);
        if (j is Map) {
          enabled = j['on'] == true;
          volume = _num(j['vol'], 0.6, 0, 1);
          final id = j['preset'];
          presetId = id is String && sfxPresets.any((p) => p.id == id) ? id : 'cream';
          customX = j['cx'] is num ? _num(j['cx'], 0.5, 0, 1) : null;
          customY = j['cy'] is num ? _num(j['cy'], 0.5, 0, 1) : null;
          if (customX == null || customY == null) {
            customX = null;
            customY = null;
          }
          pitch = _num(j['pitch'], 0, -12, 12);
          decay = _num(j['decay'], 1, 0.4, 2.5);
          bright = _num(j['bright'], 0.5, 0, 1);
          reverb = _num(j['reverb'], 0.15, 0, 1);
          human = _num(j['human'], 0.25, 0, 1);
          pan = _num(j['pan'], 0.2, 0, 1);
          clicks = j['clicks'] != false;
          typing = j['typing'] != false;
          chimes = j['chimes'] != false;
          ambientVolume = _num(j['amb'], 0.5, 0, 1);
        }
      }
    } catch (_) {}
    _push();
    notifyListeners();
  }

  /// Used by tests to plant saved data.
  @visibleForTesting
  void writeRaw(String value) => LocalStore.write(_key, value);

  void _save() {
    LocalStore.write(
      _key,
      jsonEncode({
        'on': enabled,
        'vol': volume,
        'preset': presetId,
        if (customX != null && customY != null) ...{'cx': customX, 'cy': customY},
        'pitch': pitch,
        'decay': decay,
        'bright': bright,
        'reverb': reverb,
        'human': human,
        'pan': pan,
        'clicks': clicks,
        'typing': typing,
        'chimes': chimes,
        'amb': ambientVolume,
      }),
    );
  }

  void _pushPreset() {
    sfxPreset(presetId);
    if (customX != null && customY != null) {
      // the engine morphs the preset, so it gets the distance from where the preset sits
      sfxMatrix(_c(0.5 + customX! - preset.x, 0, 1), _c(0.5 + customY! - preset.y, 0, 1));
    }
  }

  void _push() {
    sfxEnable(enabled);
    sfxVolume(volume);
    _pushPreset();
    sfxTune(pitch, decay, bright, reverb, human, pan);
    sfxAmbientVolume(ambientVolume);
  }

  void _changed({bool preview = false}) {
    _save();
    notifyListeners();
    if (preview) sfxPlay('tap');
  }

  void setEnabled(bool on) {
    enabled = on;
    sfxEnable(on);
    if (!on) {
      ambient.clear();
      sfxStopAll();
    }
    _changed(preview: on);
  }

  void setVolume(double v) {
    volume = _c(v, 0, 1);
    sfxVolume(volume);
    _changed();
  }

  void selectPreset(String id) {
    if (!sfxPresets.any((p) => p.id == id)) return;
    presetId = id;
    customX = null;
    customY = null;
    _pushPreset();
    _changed(preview: true);
  }

  void movePuck(double x, double y, {bool preview = false}) {
    customX = _c(x, 0, 1);
    customY = _c(y, 0, 1);
    _pushPreset();
    _changed(preview: preview);
  }

  void setTune({double? pitch, double? decay, double? bright, double? reverb, double? human, double? pan}) {
    this.pitch = _c(pitch ?? this.pitch, -12.0, 12.0);
    this.decay = _c(decay ?? this.decay, 0.4, 2.5);
    this.bright = _c(bright ?? this.bright, 0.0, 1.0);
    this.reverb = _c(reverb ?? this.reverb, 0.0, 1.0);
    this.human = _c(human ?? this.human, 0.0, 1.0);
    this.pan = _c(pan ?? this.pan, 0.0, 1.0);
    sfxTune(this.pitch, this.decay, this.bright, this.reverb, this.human, this.pan);
    _changed();
  }

  void setToggles({bool? clicks, bool? typing, bool? chimes}) {
    this.clicks = clicks ?? this.clicks;
    this.typing = typing ?? this.typing;
    this.chimes = chimes ?? this.chimes;
    _changed();
  }

  void toggleAmbient(String id) {
    if (!ambientSounds.any((a) => a.id == id)) return;
    if (!enabled) setEnabled(true);
    final on = !ambient.contains(id);
    if (on) {
      ambient.add(id);
    } else {
      ambient.remove(id);
    }
    sfxAmbient(id, on);
    _changed();
  }

  void setAmbientVolume(double v) {
    ambientVolume = _c(v, 0, 1);
    sfxAmbientVolume(ambientVolume);
    _changed();
  }

  void reset() {
    final keepOn = enabled;
    sfxStopAll();
    ambient.clear();
    volume = 0.6;
    presetId = 'cream';
    customX = null;
    customY = null;
    pitch = 0;
    decay = 1;
    bright = 0.5;
    reverb = 0.15;
    human = 0.25;
    pan = 0.2;
    clicks = true;
    typing = true;
    chimes = true;
    ambientVolume = 0.5;
    enabled = keepOn;
    _push();
    _changed(preview: keepOn);
  }

  /// Forgets everything: back to the defaults, sound off, nothing left in the browser.
  void wipe() {
    enabled = false; // so the reset below does not play a sound
    reset();
    sfxEnable(false);
    LocalStore.remove(_key);
    notifyListeners();
  }

  void preview() => sfxPlay('tap');

  /// A tap or click on the page.
  void tap() {
    if (enabled && clicks) sfxPlay('tap');
  }

  /// A key pressed while typing in a text box.
  void key(LogicalKeyboardKey k) {
    if (!enabled || !typing) return;
    sfxPlay(k == LogicalKeyboardKey.space ? 'space' : (k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.numpadEnter) ? 'enter' : 'key');
  }

  /// 'done' when a result is ready, 'warn' for a scam warning, 'error' when something failed.
  void event(String name) {
    if (enabled && chimes) sfxPlay(name);
  }

  bool _attached = false;

  /// Starts listening for typing. Called once from main().
  void attach() {
    if (_attached) return;
    _attached = true;
    HardwareKeyboard.instance.addHandler((KeyEvent e) {
      if (e is KeyDownEvent && enabled && typing) {
        final ctx = FocusManager.instance.primaryFocus?.context;
        if (ctx != null && ctx.findAncestorWidgetOfExactType<EditableText>() != null) key(e.logicalKey);
      }
      return false; // never swallow a key
    });
  }
}
