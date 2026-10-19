import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'print_html.dart';

/// Opens the text in a new tab and starts the browser print dialog (where "Save as PDF" is one of the choices).
bool printText(String title, String text, {bool rtl = false}) => printHtml(buildPrintHtml(title, text, rtl: rtl));

/// Opens a finished page (built by print_html.dart) in a new tab; the page starts the print dialog itself.
bool printHtml(String html) {
  try {
    final blob = web.Blob([html.toJS].toJS, web.BlobPropertyBag(type: 'text/html;charset=utf-8'));
    final url = web.URL.createObjectURL(blob);
    return web.window.open(url, '_blank') != null; // null means the browser blocked the new tab
  } catch (_) {
    return false;
  }
}
