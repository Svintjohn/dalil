import 'package:flutter/material.dart';

import 'fonts.dart';

@immutable
class Palette {
  const Palette({
    required this.bg,
    required this.surface,
    required this.inset,
    required this.ink,
    required this.inkSoft,
    required this.line,
    required this.accent,
    required this.onAccent,
    required this.accentTint,
    required this.marker,
    required this.high,
    required this.highTint,
    required this.mid,
    required this.midTint,
    required this.low,
    required this.lowTint,
    required this.ok,
    required this.okTint,
    required this.shadow,
    required this.sign,
    required this.signInk,
    required this.wall,
    required this.wallInk,
    required this.markSolid,
  });

  final Color bg, surface, inset, ink, inkSoft, line, accent, onAccent, accentTint, marker;
  final Color high, highTint, mid, midTint, low, lowTint, ok, okTint, shadow;
  final Color sign, signInk, wall, wallInk, markSolid;

  static const light = Palette(
    bg: Color(0xFFF3F5F5),
    surface: Color(0xFFFFFFFF),
    inset: Color(0xFFEAEEEE),
    ink: Color(0xFF0B1B1E),
    inkSoft: Color(0xFF55646A),
    line: Color(0xFFDCE2E3),
    accent: Color(0xFF0A6B6F),
    onAccent: Color(0xFFFFFFFF),
    accentTint: Color(0xFFDDEEEE),
    marker: Color(0xE6FFD84A),
    high: Color(0xFFB3261E),
    highTint: Color(0xFFFCECEA),
    mid: Color(0xFF935000),
    midTint: Color(0xFFFBF0DC),
    low: Color(0xFF4A5568),
    lowTint: Color(0xFFECEFF3),
    ok: Color(0xFF1E6B47),
    okTint: Color(0xFFE3F2EA),
    shadow: Color(0x330B1B1E),
    sign: Color(0xFF0A5A5E),
    signInk: Color(0xFFFFFFFF),
    wall: Color(0xFF0B1B1E),
    wallInk: Color(0xFFEAF2F2),
    markSolid: Color(0xFFFFD84A),
  );

  static const dark = Palette(
    bg: Color(0xFF071013),
    surface: Color(0xFF0E1A1E),
    inset: Color(0xFF142329),
    ink: Color(0xFFEAF2F2),
    inkSoft: Color(0xFF93A5AA),
    line: Color(0xFF1F3037),
    accent: Color(0xFF58C7CB),
    onAccent: Color(0xFF04282A),
    accentTint: Color(0xFF0F3236),
    marker: Color(0x57FFD84A),
    high: Color(0xFFFF8A80),
    highTint: Color(0xFF3A1A18),
    mid: Color(0xFFF0B35E),
    midTint: Color(0xFF38290F),
    low: Color(0xFFA9B8CC),
    lowTint: Color(0xFF1D2634),
    ok: Color(0xFF6FD0A0),
    okTint: Color(0xFF123327),
    shadow: Color(0x66000000),
    sign: Color(0xFF0C2F33),
    signInk: Color(0xFFEAF2F2),
    wall: Color(0xFF0E1A1E),
    wallInk: Color(0xFFEAF2F2),
    markSolid: Color(0xFFFFD84A),
  );

  static Palette of(BuildContext c) => Theme.of(c).brightness == Brightness.dark ? dark : light;

  Color sev(String s) {
    switch (s) {
      case 'high':
        return high;
      case 'low':
        return low;
      case 'ok':
        return ok;
      default:
        return mid;
    }
  }

  Color sevTint(String s) {
    switch (s) {
      case 'high':
        return highTint;
      case 'low':
        return lowTint;
      case 'ok':
        return okTint;
      default:
        return midTint;
    }
  }
}

ThemeData buildTheme(Brightness b) {
  final p = b == Brightness.dark ? Palette.dark : Palette.light;
  final scheme = ColorScheme.fromSeed(seedColor: p.accent, brightness: b).copyWith(
    primary: p.accent,
    onPrimary: p.onAccent,
    surface: p.surface,
    onSurface: p.ink,
    onSurfaceVariant: p.inkSoft,
    outline: p.inkSoft,
    outlineVariant: p.line,
    error: p.high,
    surfaceContainerHighest: p.inset,
  );
  final base = ThemeData(useMaterial3: true, brightness: b, colorScheme: scheme);
  final text = Fonts.body(base.textTheme).apply(bodyColor: p.ink, displayColor: p.ink);
  return base.copyWith(
    scaffoldBackgroundColor: p.bg,
    textTheme: text,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    hoverColor: p.ink.withAlpha(10),
    dividerColor: p.line,
    focusColor: p.accent.withAlpha(40),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.inset,
      hintStyle: TextStyle(color: p.inkSoft),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: p.accent, width: 2)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    ),
    scrollbarTheme: ScrollbarThemeData(thumbColor: WidgetStatePropertyAll(p.inkSoft.withAlpha(90))),
  );
}
