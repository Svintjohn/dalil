import 'dart:js_interop';

/// The sound engine lives in web/dalil_sfx.js (Web Audio, no files, no network).
/// Every call is wrapped so a missing script or a blocked audio device never breaks the app.
@JS('dalilSfx.available')
external bool _available();
@JS('dalilSfx.enable')
external void _enable(bool on);
@JS('dalilSfx.volume')
external void _volume(double v);
@JS('dalilSfx.preset')
external void _preset(String id);
@JS('dalilSfx.matrix')
external void _matrix(double x, double y);
@JS('dalilSfx.tune')
external void _tune(double pitch, double decay, double bright, double reverb, double human, double pan);
@JS('dalilSfx.play')
external void _play(String kind);
@JS('dalilSfx.ambient')
external void _ambient(String id, bool on);
@JS('dalilSfx.ambientVolume')
external void _ambientVolume(double v);
@JS('dalilSfx.stopAll')
external void _stopAll();
@JS('dalilSfx.bands')
external String _bands(int n);

bool sfxAvailable() {
  try {
    return _available();
  } catch (_) {
    return false;
  }
}

void sfxEnable(bool on) {
  try {
    _enable(on);
  } catch (_) {}
}

void sfxVolume(double v) {
  try {
    _volume(v);
  } catch (_) {}
}

void sfxPreset(String id) {
  try {
    _preset(id);
  } catch (_) {}
}

void sfxMatrix(double x, double y) {
  try {
    _matrix(x, y);
  } catch (_) {}
}

void sfxTune(double pitch, double decay, double bright, double reverb, double human, double pan) {
  try {
    _tune(pitch, decay, bright, reverb, human, pan);
  } catch (_) {}
}

void sfxPlay(String kind) {
  try {
    _play(kind);
  } catch (_) {}
}

void sfxAmbient(String id, bool on) {
  try {
    _ambient(id, on);
  } catch (_) {}
}

void sfxAmbientVolume(double v) {
  try {
    _ambientVolume(v);
  } catch (_) {}
}

void sfxStopAll() {
  try {
    _stopAll();
  } catch (_) {}
}

List<double> sfxBands(int n) {
  try {
    return _bands(n).split(',').map((s) => double.tryParse(s) ?? 0).toList();
  } catch (_) {
    return List<double>.filled(n, 0);
  }
}
