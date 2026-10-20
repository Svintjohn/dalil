/// Outside the browser (for example in tests) there is no sound: every call does nothing.
bool sfxAvailable() => false;
void sfxEnable(bool on) {}
void sfxVolume(double v) {}
void sfxPreset(String id) {}
void sfxMatrix(double x, double y) {}
void sfxTune(double pitch, double decay, double bright, double reverb, double human, double pan) {}
void sfxPlay(String kind) {}
void sfxAmbient(String id, bool on) {}
void sfxAmbientVolume(double v) {}
void sfxStopAll() {}
List<double> sfxBands(int n) => List<double>.filled(n, 0);
