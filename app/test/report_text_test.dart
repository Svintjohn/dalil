import 'dart:convert';

import 'package:dalil_app/models.dart';
import 'package:dalil_app/report_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('share text keeps a short report whole and adds the Dalil note', () {
    final r = Report.fromJson({'summary': 'Pay by Friday.'});
    final t = shareText(r);
    expect(t, contains('Pay by Friday.'));
    expect(t, endsWith('Made with Dalil: https://dalil-rouge.vercel.app'));
  });

  test('share text is cut at a line break when it is long, and says so', () {
    final r = Report.fromJson({
      'summary': 'Short summary.',
      'points': [for (var i = 0; i < 120; i++) {'original': 'o$i', 'plain': 'Plain point number $i that goes on for a while.'}],
    });
    final t = shareText(r, maxChars: 400);
    expect(t.length, lessThan(560));
    expect(t, contains('\n...'));
    expect(t, contains('Short summary.'));
    expect(t, endsWith('https://dalil-rouge.vercel.app'));
  });

  test('share text never splits an emoji, wherever the cut falls', () {
    for (var n = 80; n < 120; n++) {
      final r = Report.fromJson({'summary': '${'a' * n}\u{1F600}${'b' * 50}'});
      final t = shareText(r, maxChars: 100);
      expect(utf8.decode(utf8.encode(t)), t, reason: 'n=$n'); // a lone half of an emoji would change on the way through UTF-8
    }
  });
}
