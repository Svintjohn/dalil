import 'pdf_pick.dart';

/// Outside the browser there is no PDF reader, so the person is told to use photos.
Future<PdfPick?> pickPdf({int maxPages = 6, int maxChars = 30000}) async => const PdfPick.failed('', 'unsupported');
