import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class Fonts {
  static bool web = true;

  /// Reading text for quoted documents and letters.
  static TextStyle doc(TextStyle s) => web ? GoogleFonts.sourceSerif4(textStyle: s) : s.copyWith(fontFamily: 'serif');

  /// The Arabic wordmark.
  static TextStyle mark(TextStyle s) => web ? GoogleFonts.reemKufi(textStyle: s) : s;

  /// Headlines: a warm, high-contrast serif that does not look like a template.
  static TextStyle display(TextStyle s) => web ? GoogleFonts.fraunces(textStyle: s) : s.copyWith(fontFamily: 'serif');

  /// Everything else.
  static TextTheme body(TextTheme t) => web ? GoogleFonts.dmSansTextTheme(t) : t;
}
