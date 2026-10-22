import 'dart:js_interop';
import 'dart:typed_data';

import 'pdf_pick.dart';

/// web/dalil_pdf.js: opens the file chooser and reads the PDF in the browser. Nothing is uploaded here.
@JS('dalilPdf.pick')
external JSPromise<JSAny?> _pick(JSObject opts);

extension type _PdfResult(JSObject _) implements JSObject {
  external bool get ok;
  external String? get error;
  external String? get name;
  external int? get total;
  external String? get kind;
  external String? get text;
  external bool? get truncated;
  external JSArray<JSUint8Array>? get pages;
}

/// Null when the person closed the chooser. Otherwise the text of the PDF, its pages as pictures, or the reason it failed.
Future<PdfPick?> pickPdf({int maxPages = 6, int maxChars = 30000}) async {
  try {
    final opts = {'maxPages': maxPages, 'maxChars': maxChars}.jsify() as JSObject;
    final raw = await _pick(opts).toDart;
    if (raw == null) return null;
    final r = _PdfResult(raw as JSObject);
    final name = r.name ?? 'document.pdf';
    if (!r.ok) return PdfPick.failed(name, r.error ?? 'bad');
    final total = r.total ?? 0;
    if (r.kind == 'text') return PdfPick.text(name, total, r.text ?? '', truncated: r.truncated ?? false);
    final pages = <Uint8List>[for (final p in r.pages?.toDart ?? const <JSUint8Array>[]) p.toDart];
    if (pages.isEmpty) return PdfPick.failed(name, 'empty');
    return PdfPick.pages(name, total, pages);
  } catch (_) {
    return const PdfPick.failed('', 'unsupported');
  }
}
