import 'package:dalil_app/models.dart';
import 'package:dalil_app/report_view.dart';
import 'package:dalil_app/scam_report.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Report rep({Map<String, dynamic>? pack, Map<String, dynamic> labels = const {}, String level = 'stop'}) => Report.fromJson({
      'summary': 'This asks you to pay AED 500 into a personal account.',
      'doc_type': 'Fine notice',
      'scam': {'level': level, 'reasons': ['Pay into a personal account']},
      'labels': labels,
      if (pack != null) 'scam_report': pack,
    });

const dubaiPack = {
  'country': 'AE',
  'country_name': 'United Arab Emirates',
  'authorities': [
    {'ref': 'AE:police', 'name': 'Dubai Police eCrime', 'url': 'https://www.dubaipolice.gov.ae/', 'phone': '901', 'phone_source': 'https://www.dubaipolice.gov.ae/'}
  ],
  'signs_en': ['It asks you to pay into a personal account.', 'It gives a very short deadline to make you act fast.'],
};

Future<void> show(WidgetTester tester, Report r) async {
  tester.view.physicalSize = const Size(1000, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: ReportView(report: r, onOpen: (_) {})))));
  await tester.pumpAndSettle();
}

void main() {
  test('the report message holds the signs and blanks, but nothing from the document', () {
    final m = scamReportMessage(rep(pack: dubaiPack));
    expect(m, contains('suspected scam'));
    expect(m, contains('a fine notice that looks like a scam'));
    expect(m, contains('- It asks you to pay into a personal account.'));
    expect(m, contains('- It gives a very short deadline'));
    expect(m, contains('[SMS / email / phone call / WhatsApp / letter]'));
    expect(m, contains('[Your name]'));
    expect(m, isNot(contains('AED 500'))); // no amounts, names or numbers from the paper
  });

  test('without any signs the message still has a blank to fill in', () {
    final m = scamReportMessage(rep(pack: {'authorities': [], 'signs_en': []}));
    expect(m, contains('- [what made you worried]'));
    expect(scamReportMessage(Report.fromJson({'summary': 'x'})), contains('a message that looks like a scam'));
  });

  test('the pack is read safely from odd data', () {
    expect(Report.fromJson({'summary': 'x', 'scam_report': 'nope'}).scamReport, isNull);
    final p = Report.fromJson({'summary': 'x', 'scam_report': {'authorities': [5, {'name': ''}, {'name': 'Police', 'url': 'https://x.gov'}], 'signs_en': [null, ' a ']}}).scamReport!;
    expect(p.authorities.map((a) => a.name), ['Police']);
    expect(p.signsEn, ['a']);
  });

  testWidgets('the shield offers the offices and a message that can be copied', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String?;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

    await show(tester, rep(pack: dubaiPack));
    expect(find.text('Report this scam'), findsOneWidget);
    expect(find.text('Dubai Police eCrime'), findsNothing); // closed until opened
    await tester.tap(find.text('Report this scam'));
    await tester.pumpAndSettle();
    expect(find.text('Dubai Police eCrime'), findsOneWidget);
    expect(find.text('Phone 901'), findsOneWidget);
    expect(find.byKey(const ValueKey('scam-report-text')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('scam-report-copy')));
    await tester.pump();
    expect(copied, contains('suspected scam'));
    expect(find.text('Copied. Fill in the brackets, then send it.'), findsOneWidget);
  });

  testWidgets('with no office for the country the general advice is shown', (tester) async {
    await show(tester, rep(level: 'caution', pack: {'authorities': [], 'signs_en': []}));
    await tester.tap(find.text('Report this scam'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Report it to the police or the cyber-crime unit'), findsOneWidget);
  });

  testWidgets('the headings follow the reply language when the report has them', (tester) async {
    await show(tester, rep(pack: dubaiPack, labels: {'report_scam': 'I-report ang scam', 'report_where': 'Saan i-report', 'report_msg': 'Mensaheng puwedeng ipadala'}));
    expect(find.text('I-report ang scam'), findsOneWidget);
    await tester.tap(find.text('I-report ang scam'));
    await tester.pumpAndSettle();
    expect(find.text('Saan i-report'), findsOneWidget);
    expect(find.text('Mensaheng puwedeng ipadala'), findsOneWidget);
  });

  testWidgets('no report box without a pack, and none for an ordinary document', (tester) async {
    await show(tester, rep());
    expect(find.byKey(const ValueKey('scam-shield')), findsOneWidget);
    expect(find.byKey(const ValueKey('scam-report')), findsNothing);
    await show(tester, rep(level: 'none', pack: dubaiPack));
    expect(find.byKey(const ValueKey('scam-shield')), findsNothing);
    expect(find.byKey(const ValueKey('scam-report')), findsNothing);
  });
}
