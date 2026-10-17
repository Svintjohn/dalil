import 'package:flutter/material.dart';

class AppSettings {
  static final ValueNotifier<ThemeMode> themeMode = ValueNotifier<ThemeMode>(ThemeMode.system);
  static final ValueNotifier<double> textScale = ValueNotifier<double>(1.0);

  static void nextTextSize() {
    final v = textScale.value;
    textScale.value = v < 1.1 ? 1.15 : (v < 1.2 ? 1.3 : 1.0);
  }
}
