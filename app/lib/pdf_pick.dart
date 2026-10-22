import 'dart:typed_data';

/// What came out of a PDF the person chose. It is read in the browser, so nothing has been uploaded yet.
class PdfPick {
  const PdfPick.text(this.name, this.total, String this.text, {this.truncated = false})
      : pages = const [],
        error = null;
  const PdfPick.pages(this.name, this.total, this.pages)
      : text = null,
        truncated = false,
        error = null;
  const PdfPick.failed(this.name, String this.error)
      : total = 0,
        text = null,
        truncated = false,
        pages = const [];

  final String name;
  final int total;
  final String? text; // a PDF with real text: the words
  final bool truncated; // the text was cut at the limit
  final List<Uint8List> pages; // a scan, or a PDF in Arabic script: one JPEG per page
  final String? error; // 'bad', 'locked', 'empty' or 'unsupported'

  bool get ok => error == null;
  bool get isText => text != null;
}

/// A calm sentence for a PDF that could not be used.
String pdfProblem(String? code) {
  switch (code) {
    case 'locked':
      return 'That PDF is locked with a password. Open it, save an unlocked copy, or take photos of the pages.';
    case 'empty':
      return 'That PDF has no pages Dalil can read. Try photos of the pages instead.';
    case 'unsupported':
      return 'This browser could not open the PDF reader. Try Chrome, Edge or Safari, or take photos of the pages.';
    default:
      return 'That file could not be read as a PDF. Try photos of the pages instead.';
  }
}
