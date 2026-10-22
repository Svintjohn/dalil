import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class Fonts {
  static bool web = true;

  /// The easy-read option: one wide, open font (Lexend) everywhere, with no tight letter spacing.
  static bool easy = false;

  static TextStyle _easy(TextStyle s) => GoogleFonts.lexend(textStyle: s.copyWith(letterSpacing: 0));

  /// Reading text for quoted documents and letters.
  static TextStyle doc(TextStyle s) => web ? (easy ? _easy(s) : GoogleFonts.sourceSerif4(textStyle: s)) : s.copyWith(fontFamily: 'serif');

  /// The Arabic wordmark.
  static TextStyle mark(TextStyle s) => web ? GoogleFonts.reemKufi(textStyle: s) : s;

  /// Headlines: a warm, high-contrast serif that does not look like a template.
  static TextStyle display(TextStyle s) => web ? (easy ? _easy(s) : GoogleFonts.fraunces(textStyle: s)) : s.copyWith(fontFamily: 'serif');

  /// Everything else.
  static TextTheme body(TextTheme t) => web ? (easy ? GoogleFonts.lexendTextTheme(t) : GoogleFonts.dmSansTextTheme(t)) : t;
}
