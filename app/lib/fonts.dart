import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class Fonts {
  static bool web = true;

  static TextStyle doc(TextStyle s) => web ? GoogleFonts.sourceSerif4(textStyle: s) : s.copyWith(fontFamily: 'serif');
  static TextStyle mark(TextStyle s) => web ? GoogleFonts.reemKufi(textStyle: s) : s;
  static TextTheme body(TextTheme t) => web ? GoogleFonts.publicSansTextTheme(t) : t;
}
