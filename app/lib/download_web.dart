import 'package:web/web.dart' as web;

bool saveTextFile(String filename, String mime, String text) {
  try {
    final a = web.document.createElement('a') as web.HTMLAnchorElement;
    a.href = 'data:$mime;charset=utf-8,${Uri.encodeComponent(text)}';
    a.download = filename;
    web.document.body?.append(a);
    a.click();
    a.remove();
    return true;
  } catch (_) {
    return false;
  }
}
