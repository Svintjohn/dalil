String _esc(String s) => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');

/// A plain page that is easy to print or save as PDF. The text is escaped, so nothing in it can run.
String buildPrintHtml(String title, String text, {bool rtl = false}) {
  final t = _esc(title.trim().isEmpty ? 'Dalil' : title.trim());
  return '<!doctype html><html lang="en" dir="${rtl ? 'rtl' : 'ltr'}"><head><meta charset="utf-8">'
      '<meta name="viewport" content="width=device-width, initial-scale=1"><title>$t</title>'
      '<style>body{font-family:system-ui,-apple-system,"Segoe UI",Roboto,"Noto Sans","Noto Sans Arabic",sans-serif;'
      'max-width:720px;margin:32px auto;padding:0 20px;color:#111;line-height:1.55}'
      'h1{font-size:22px;margin:0 0 16px}.body{white-space:pre-wrap;font-size:16px}'
      '.note{margin-top:28px;padding-top:12px;border-top:1px solid #ccc;font-size:12px;color:#555}</style></head><body>'
      '<h1>$t</h1><div class="body">${_esc(text)}</div>'
      '<div class="note">Made with Dalil. This is a guide, not legal, medical or financial advice.</div>'
      '<script>window.addEventListener("load",function(){setTimeout(function(){window.print();},300);});</script>'
      '</body></html>';
}
