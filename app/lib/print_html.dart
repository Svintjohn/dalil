import 'deadlines.dart';
import 'models.dart';
import 'report_text.dart';

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

const _css = '@page{size:A4;margin:18mm 17mm 20mm;@bottom-center{content:"Dalil  \\00B7  " counter(page) " / " counter(pages);font:8.5pt system-ui,sans-serif;color:#777}}'
    '*{box-sizing:border-box}html{-webkit-print-color-adjust:exact;print-color-adjust:exact}'
    'body{font-family:system-ui,-apple-system,"Segoe UI",Roboto,"Noto Sans","Noto Sans Arabic",sans-serif;color:#1b1b1f;font-size:10.5pt;line-height:1.55;margin:0;padding:0;orphans:3;widows:3}'
    '.page{max-width:780px;margin:0 auto;padding:28px 22px 40px}'
    '.bar{display:flex;justify-content:flex-end;margin-bottom:14px}.bar button{font:inherit;font-size:10pt;background:#0b6b5d;color:#fff;border:0;border-radius:8px;padding:8px 16px;cursor:pointer}'
    '@media print{.page{max-width:none;padding:0}.bar{display:none}}'
    '.top{display:flex;justify-content:space-between;align-items:baseline;border-bottom:2.5px solid #0b6b5d;padding-bottom:9px;margin-bottom:22px}'
    '.brand{font-weight:700;font-size:13pt;color:#0b6b5d;letter-spacing:.03em}.date{font-size:9pt;color:#666}'
    'h1{font-size:21pt;line-height:1.2;margin:0 0 14px;letter-spacing:-.01em}'
    '.summary{font-size:11.5pt;line-height:1.6;margin:0 0 8px;padding:12px 16px;background:#f0f6f5;border-inline-start:4px solid #0b6b5d;border-radius:4px;break-inside:avoid}'
    'h2{font-size:9.5pt;text-transform:uppercase;letter-spacing:.1em;color:#0b6b5d;margin:28px 0 12px;padding-bottom:5px;border-bottom:1px solid #cfd8d6;break-after:avoid;page-break-after:avoid}'
    'h3{font-size:10pt;margin:0 0 6px;color:#333}'
    'ul,ol{margin:0;padding-inline-start:20px}li{margin:0 0 9px;padding-inline-start:2px;break-inside:avoid;page-break-inside:avoid}li::marker{color:#0b6b5d}'
    'ol.steps{list-style:none;padding:0;counter-reset:s}ol.steps>li{counter-increment:s;display:flex;gap:12px;align-items:flex-start;margin:0 0 12px;padding:0}'
    'ol.steps>li::before{content:counter(s);flex:none;width:22px;height:22px;border-radius:50%;background:#0b6b5d;color:#fff;font-weight:700;font-size:9.5pt;line-height:22px;text-align:center;margin-top:1px}'
    'ol.steps>li>div{flex:1}'
    'ul.check{list-style:none;padding:0}ul.check>li{display:flex;gap:11px;align-items:flex-start;padding:0}'
    'ul.check>li::before{content:"";flex:none;width:12px;height:12px;border:1.5px solid #555;border-radius:3px;margin-top:4px}ul.check>li>div{flex:1}'
    '.alert{border:1.5px solid #b3261e;background:#fdeceb;border-radius:8px;padding:14px 16px;margin:0 0 20px;break-inside:avoid}'
    '.alert.caution{border-color:#b26a00;background:#fff4e0}.alert b{display:block;font-size:12.5pt;color:#8c1d18;margin-bottom:6px}'
    '.alert.caution b{color:#7a4a00}.alert ul{margin:4px 0 10px}.alert p{margin:0;font-size:10pt}'
    '.tag{display:inline-block;font-size:8.5pt;font-weight:600;background:#e3f1ee;color:#0b6b5d;border-radius:10px;padding:1px 9px;margin-inline-start:8px;white-space:nowrap;vertical-align:1px}'
    '.src{display:block;font-size:8.5pt;color:#666;word-break:break-all;margin-top:2px}'
    'table{border-collapse:collapse;width:100%;font-size:10.5pt;break-inside:avoid}td,th{padding:6px 10px;border-bottom:1px solid #e3e7e6;text-align:start}'
    'td.n,th.n{text-align:end;white-space:nowrap;font-variant-numeric:tabular-nums}'
    '.cols{display:flex;gap:28px}.cols>div{flex:1;break-inside:avoid}'
    '.closing{margin-top:22px;font-style:italic;color:#444}'
    '.note{margin-top:30px;padding-top:10px;border-top:1px solid #ccc;font-size:8.5pt;color:#777;break-inside:avoid}';

String _tag(String s) => s.trim().isEmpty ? '' : '<span class="tag">${_esc(s.trim())}</span>';

String _section(String title, String inner) => inner.isEmpty ? '' : '<h2>${_esc(title)}</h2>$inner';

String _list(List<String> items, {bool ordered = false, String cls = ''}) {
  if (items.isEmpty) return '';
  final tag = ordered ? 'ol' : 'ul';
  final wrap = cls.isNotEmpty; // numbered steps and checklists put the text in a block next to the number or box
  return '<$tag${wrap ? ' class="$cls"' : ''}>${items.map((i) => wrap ? '<li><div>$i</div></li>' : '<li>$i</li>').join()}</$tag>';
}

String _two(int n) => n < 10 ? '0$n' : '$n';

/// The report laid out as a clean A4 page: a heading, boxed warning, sections, and tables. All text is escaped.
String buildReportPrintHtml(Report r, {DateTime? now}) {
  final d = now ?? DateTime.now();
  final date = '${d.year}-${_two(d.month)}-${_two(d.day)}';
  final title = _esc(r.docType.trim().isEmpty ? 'Dalil' : r.docType.trim());
  final b = StringBuffer();

  if (r.scam.shown) {
    final stop = r.scam.stop;
    b.write('<div class="alert${stop ? '' : ' caution'}"><b>${_esc(stop ? r.label('scam_stop', 'Stop. Do not pay or reply yet') : r.label('scam_caution', 'Be careful with this one'))}</b>');
    b.write(_list(r.scam.reasons.map(_esc).toList()));
    b.write('<p>${_esc(r.label('scam_steps', 'Do not pay, send any code or open any link in it. Check with the office through its official app or website, typing the address yourself, or call a number you find yourself. Keep the message and ask someone you trust.'))}</p></div>');
  }
  b.write('<p class="summary">${_esc(r.summary)}</p>');

  b.write(_section(
    r.label('next_steps', 'What to do'),
    _list(
      r.nextSteps.map((s) {
        final a = s.authority;
        final src = a == null ? '' : '<span class="src">${_esc(a.name)} ${_esc(a.url)}</span>';
        return '${_esc(s.action)}${_tag(s.deadline)}$src';
      }).toList(),
      ordered: true,
      cls: 'steps',
    ),
  ));
  b.write(_section(r.label('if_ignored', 'If you do nothing'), _list(r.ifIgnored.map((i) => '<b>${_esc(i.action)}:</b> ${_esc(i.consequence)}').toList())));

  final nc = r.numberCheck;
  if (nc != null && !nc.ok) {
    final rows = StringBuffer();
    for (final l in nc.lines) {
      rows.write('<tr><td>${_esc(l.label)}</td><td class="n">${_esc(nc.money(l.amount))}</td></tr>');
    }
    for (final i in nc.issues) {
      rows.write('<tr><td colspan="2"><b>${_esc(numberIssueText(r, i))}</b></td></tr>');
      rows.write('<tr><td>${_esc(r.label('numbers_computed', 'Added up'))}</td><td class="n">${_esc(nc.money(i.computed))}</td></tr>');
      rows.write('<tr><td>${_esc(r.label('numbers_stated', 'On the document'))}</td><td class="n">${_esc(nc.money(i.stated))}</td></tr>');
    }
    b.write(_section(r.label('numbers', 'Number check'), '<table>$rows</table>'));
  }

  final prep = r.prep;
  if (prep != null) {
    final heading = prep.office.isEmpty ? r.label('prep', 'Before you go') : '${r.label('prep', 'Before you go')}: ${prep.office}';
    final bring = prep.bring.isEmpty ? '' : '<div><h3>${_esc(r.label('prep_bring', 'Bring'))}</h3>${_list(prep.bring.map((i) => _esc(i.item)).toList())}</div>';
    final ask = prep.questions.isEmpty ? '' : '<div><h3>${_esc(r.label('prep_ask', 'Ask'))}</h3>${_list(prep.questions.map(_esc).toList(), ordered: true)}</div>';
    b.write(_section(heading, bring.isEmpty && ask.isEmpty ? '' : '<div class="cols">$bring$ask</div>'));
  }

  b.write(_section(
    r.label('deadlines', 'Deadlines'),
    _list(r.deadlines.map((x) => '${_esc(x.label)}${_tag(describeDeadline(x))}').toList()),
  ));
  b.write(_section(r.label('plain_words', 'In plain words'), _list(r.points.map((p) => _esc(p.plain)).toList())));
  b.write(_section(r.label('watch_out', 'Watch out'), _list(r.findings.map((f) => _esc(f.why)).toList())));
  b.write(_section(r.label('checklist', 'Your checklist'), _list(r.checklist.map((c) => '${_esc(c.task)}${_tag(c.due)}').toList(), cls: 'check')));
  if (r.closing.trim().isNotEmpty) b.write('<p class="closing">${_esc(r.closing)}</p>');

  return '<!doctype html><html lang="${_esc(r.language.isEmpty ? 'en' : r.language)}" dir="${r.rtl ? 'rtl' : 'ltr'}"><head><meta charset="utf-8">'
      '<meta name="viewport" content="width=device-width, initial-scale=1"><title>$title</title><style>$_css</style></head><body><div class="page">'
      '<div class="bar"><button onclick="window.print()">Print / Save as PDF</button></div>'
      '<div class="top"><span class="brand">Dalil &middot; \u062f\u0644\u064a\u0644</span><span class="date">$date</span></div>'
      '<h1>$title</h1>$b'
      '<div class="note">Made with Dalil. This is a guide, not legal, medical or financial advice.</div></div>'
      '<script>window.addEventListener("load",function(){setTimeout(function(){window.print();},300);});</script></body></html>';
}
