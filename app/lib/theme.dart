import 'package:flutter/material.dart';

import 'fonts.dart';
import 'profile.dart';

/// WCAG contrast ratio between two colours, 1 to 21.
double contrastRatio(Color a, Color b) {
  final x = a.computeLuminance(), y = b.computeLuminance();
  final hi = x > y ? x : y, lo = x > y ? y : x;
  return (hi + 0.05) / (lo + 0.05);
}

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

  /// The palette for the current brightness and the accent colour the person picked.
  static Palette of(BuildContext c) {
    final pr = Profile.instance;
    final isDark = Theme.of(c).brightness == Brightness.dark;
    return pr.accent == Accent.custom ? custom(pr.customHue, pr.customSat, isDark) : forAccent(pr.accent, isDark);
  }

  static final Map<Accent, Palette> _lightByAccent = {for (final a in presetAccents) a: _tinted(light, a, false)};
  static final Map<Accent, Palette> _darkByAccent = {for (final a in presetAccents) a: _tinted(dark, a, true)};

  /// One of the ready-made colours. [Accent.custom] needs [custom], so here it falls back to the base teal.
  static Palette forAccent(Accent a, bool isDark) => (isDark ? _darkByAccent : _lightByAccent)[a] ?? (isDark ? dark : light);

  static final Map<String, Palette> _customCache = {};

  /// A palette for any colour of the wheel. Only the hue and the strength are chosen; the lightness is searched for, so the
  /// accent always reads at least 4.5 to 1 on the page, the cards, the insets and its own tint, in light and in dark.
  static Palette custom(double hue, double sat, bool isDark) {
    final h = ((hue % 360) + 360) % 360;
    final s = sat.clamp(0.15, 0.95).toDouble();
    return _customCache.putIfAbsent('${h.round()}|${(s * 100).round()}|$isDark', () => _makeCustom(h.roundToDouble(), (s * 100).round() / 100, isDark));
  }

  static Palette _makeCustom(double h, double s, bool isDark) {
    final b = isDark ? dark : light;
    Color hsl(double sat, double l) => HSLColor.fromAHSL(1, h, sat.clamp(0.0, 1.0).toDouble(), l.clamp(0.0, 1.0).toDouble()).toColor();
    final tint = isDark ? hsl(s * 0.55, 0.16) : hsl(s * 0.8, 0.91);
    bool readable(Color c) => [b.bg, b.surface, b.inset, tint].every((bg) => contrastRatio(c, bg) >= 4.6);
    var accent = hsl(s, isDark ? 0.62 : 0.48);
    for (var i = 0; i < 80; i++) {
      final l = isDark ? 0.62 + i * 0.005 : 0.48 - i * 0.005;
      accent = hsl(s, l);
      if (readable(accent)) break;
    }
    final onAccent = [isDark ? hsl(s * 0.9, 0.08) : b.surface, const Color(0xFFFFFFFF), const Color(0xFF000000)]
        .firstWhere((c) => contrastRatio(accent, c) >= 4.5, orElse: () => contrastRatio(accent, const Color(0xFF000000)) > contrastRatio(accent, const Color(0xFFFFFFFF)) ? const Color(0xFF000000) : const Color(0xFFFFFFFF));
    return Palette(
      bg: b.bg,
      surface: b.surface,
      inset: b.inset,
      ink: b.ink,
      inkSoft: b.inkSoft,
      line: b.line,
      accent: accent,
      onAccent: onAccent,
      accentTint: tint,
      marker: b.marker,
      high: b.high,
      highTint: b.highTint,
      mid: b.mid,
      midTint: b.midTint,
      low: b.low,
      lowTint: b.lowTint,
      ok: b.ok,
      okTint: b.okTint,
      shadow: b.shadow,
      sign: hsl(s * 0.7, isDark ? 0.12 : 0.17),
      signInk: b.signInk,
      wall: b.wall,
      wallInk: b.wallInk,
      markSolid: b.markSolid,
    );
  }

  // accent, text on the accent, soft tint, dark sign panel
  static const _lightAccents = <Accent, List<int>>{
    Accent.terracotta: [0xFFA84A2B, 0xFFFFFCF6, 0xFFF6E3D8, 0xFF4F2112],
    Accent.indigo: [0xFF3B4BA8, 0xFFFFFCF6, 0xFFE1E4F6, 0xFF1D2560],
    Accent.rose: [0xFFB03060, 0xFFFFFCF6, 0xFFF8E1E8, 0xFF561530],
  };
  static const _darkAccents = <Accent, List<int>>{
    Accent.terracotta: [0xFFF09A78, 0xFF3A1507, 0xFF3A2118, 0xFF3A1A10],
    Accent.indigo: [0xFF9FB0FF, 0xFF111A4A, 0xFF1A2145, 0xFF151C45],
    Accent.rose: [0xFFF29AB8, 0xFF3F0F20, 0xFF3C1A27, 0xFF3A1424],
  };

  static Palette _tinted(Palette b, Accent a, bool isDark) {
    final c = (isDark ? _darkAccents : _lightAccents)[a];
    if (c == null) return b; // teal is the base palette
    return Palette(
      bg: b.bg,
      surface: b.surface,
      inset: b.inset,
      ink: b.ink,
      inkSoft: b.inkSoft,
      line: b.line,
      accent: Color(c[0]),
      onAccent: Color(c[1]),
      accentTint: Color(c[2]),
      marker: b.marker,
      high: b.high,
      highTint: b.highTint,
      mid: b.mid,
      midTint: b.midTint,
      low: b.low,
      lowTint: b.lowTint,
      ok: b.ok,
      okTint: b.okTint,
      shadow: b.shadow,
      sign: Color(c[3]),
      signInk: b.signInk,
      wall: b.wall,
      wallInk: b.wallInk,
      markSolid: b.markSolid,
    );
  }

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

ThemeData buildTheme(Brightness b, {Accent accent = Accent.teal, double hue = 200, double sat = 0.55}) {
  final isDark = b == Brightness.dark;
  final p = accent == Accent.custom ? Palette.custom(hue, sat, isDark) : Palette.forAccent(accent, isDark);
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
