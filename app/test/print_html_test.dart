import 'package:dalil_app/models.dart';
import 'package:dalil_app/print_html.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('print page escapes the text so nothing in it can run', () {
    final html = buildPrintHtml('A <b>title</b>', 'Pay <script>alert(1)</script> & "now"');
    expect(html, contains('A &lt;b&gt;title&lt;/b&gt;'));
    expect(html, contains('Pay &lt;script&gt;alert(1)&lt;/script&gt; &amp; &quot;now&quot;'));
    expect(RegExp('<script>').allMatches(html).length, 1); // only Dalil's own print call
  });

  test('print page sets the reading direction and a default title', () {
    expect(buildPrintHtml('', 'x', rtl: true), contains('dir="rtl"'));
    expect(buildPrintHtml('Fine', 'x'), contains('dir="ltr"'));
    expect(buildPrintHtml('  ', 'x'), contains('<title>Dalil</title>'));
    expect(buildPrintHtml('Fine', 'x'), contains('not legal, medical or financial advice'));
  });

  test('report page has numbered steps, a checklist, page numbers and a reprint button, and escapes the text', () {
    final r = Report.fromJson({
      'doc_type': 'School <b>fee</b>',
      'summary': 'Pay by Friday.',
      'next_steps': [
        {'action': 'Pay the fee', 'deadline': '15 Nov'},
        {'action': 'Keep the receipt', 'deadline': ''},
      ],
      'checklist': [
        {'task': 'Pay <script>x</script>', 'due': '15 Nov'},
      ],
    });
    final html = buildReportPrintHtml(r, now: DateTime(2026, 10, 19));
    expect(html, contains('<ol class="steps"><li><div>Pay the fee'));
    expect(html, contains('<ul class="check"><li><div>Pay &lt;script&gt;x&lt;/script&gt;'));
    expect(html, contains('counter(pages)'));
    expect(html, contains('Print / Save as PDF'));
    expect(html, contains('2026-10-19'));
    expect(html, contains('School &lt;b&gt;fee&lt;/b&gt;'));
    expect(html, isNot(contains('<script>x')));
  });
}
