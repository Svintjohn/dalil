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
    bg: Color(0xFFF6F1E7),
    surface: Color(0xFFFFFCF6),
    inset: Color(0xFFEEE7D9),
    ink: Color(0xFF15201E),
    inkSoft: Color(0xFF59625E),
    line: Color(0xFFDED5C3),
    accent: Color(0xFF0B5D56),
    onAccent: Color(0xFFFFFCF6),
    accentTint: Color(0xFFDDEBE3),
    marker: Color(0xE6F5B93A),
    high: Color(0xFFB3261E),
    highTint: Color(0xFFFBE9E3),
    mid: Color(0xFF8A4B00),
    midTint: Color(0xFFF8EBCF),
    low: Color(0xFF4A5568),
    lowTint: Color(0xFFECEAE3),
    ok: Color(0xFF1E6B47),
    okTint: Color(0xFFE1EFE3),
    shadow: Color(0x2A15201E),
    sign: Color(0xFF0B3D39),
    signInk: Color(0xFFFFFCF6),
    wall: Color(0xFF15201E),
    wallInk: Color(0xFFF6F1E7),
    markSolid: Color(0xFFF5B93A),
  );

  static const dark = Palette(
    bg: Color(0xFF0E1513),
    surface: Color(0xFF151F1C),
    inset: Color(0xFF1C2824),
    ink: Color(0xFFF0EBDF),
    inkSoft: Color(0xFFA2AB9F),
    line: Color(0xFF28342F),
    accent: Color(0xFF5CC9AE),
    onAccent: Color(0xFF06231C),
    accentTint: Color(0xFF15332B),
    marker: Color(0x57F5B93A),
    high: Color(0xFFFF8A80),
    highTint: Color(0xFF3A1A18),
    mid: Color(0xFFF0B35E),
    midTint: Color(0xFF38290F),
    low: Color(0xFFA9B8CC),
    lowTint: Color(0xFF1D2634),
    ok: Color(0xFF6FD0A0),
    okTint: Color(0xFF123327),
    shadow: Color(0x66000000),
    sign: Color(0xFF0B2E2A),
    signInk: Color(0xFFF0EBDF),
    wall: Color(0xFF0A100F),
    wallInk: Color(0xFFF0EBDF),
    markSolid: Color(0xFFF5B93A),
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
  final body = Fonts.body(base.textTheme).apply(bodyColor: p.ink, displayColor: p.ink);
  TextStyle? head(TextStyle? t) => t == null ? null : Fonts.display(t.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.4, color: p.ink));
  final text = body.copyWith(
    displayLarge: head(body.displayLarge),
    displayMedium: head(body.displayMedium),
    displaySmall: head(body.displaySmall),
    headlineLarge: head(body.headlineLarge),
    headlineMedium: head(body.headlineMedium),
    headlineSmall: head(body.headlineSmall),
    titleLarge: head(body.titleLarge),
  );
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
  return base.copyWith(
    scaffoldBackgroundColor: p.bg,
    textTheme: text,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    hoverColor: p.ink.withAlpha(10),
    dividerColor: p.line,
    focusColor: p.accent.withAlpha(40),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.accent,
        foregroundColor: p.onAccent,
        elevation: 0,
        minimumSize: const Size(0, 48),
        shape: shape,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.ink,
        minimumSize: const Size(0, 48),
        side: BorderSide(color: p.ink.withAlpha(70), width: 1.2),
        shape: shape,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: p.accent, shape: shape, textStyle: const TextStyle(fontWeight: FontWeight.w700)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: p.ink,
      contentTextStyle: TextStyle(color: p.bg, fontWeight: FontWeight.w600, height: 1.4),
      shape: shape,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: p.ink, borderRadius: BorderRadius.circular(8)),
      textStyle: TextStyle(color: p.bg, fontWeight: FontWeight.w600, fontSize: 13),
    ),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: p.line)),
    ),
    scrollbarTheme: ScrollbarThemeData(thumbColor: WidgetStatePropertyAll(p.inkSoft.withAlpha(90))),
  );
}
