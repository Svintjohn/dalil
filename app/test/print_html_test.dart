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
}
