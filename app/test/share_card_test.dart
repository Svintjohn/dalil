import 'package:dalil_app/fonts.dart';
import 'package:dalil_app/models.dart';
import 'package:dalil_app/motion.dart';
import 'package:dalil_app/profile.dart';
import 'package:dalil_app/share_card.dart';
import 'package:dalil_app/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Report sample({Map<String, dynamic> extra = const {}}) => Report.fromJson({
      'doc_type': 'Electricity bill',
      'summary': 'Your bill ref 20240015 is AED 720 and is due on 2026-12-01. Pay it before the date to avoid a fee.',
      'next_steps': [
        {'action': 'Pay AED 720 online', 'deadline': '1 Dec 2026'},
        {'action': 'Keep the receipt'},
        {'action': 'Call the office if it looks wrong'},
        {'action': 'A fourth step'},
      ],
      'findings': [
        {'severity': 'low', 'why': 'a'},
        {'severity': 'high', 'why': 'b'},
      ],
      ...extra,
    });

void main() {
  setUp(() {
    Fonts.web = false;
    Motion.ambient = false;
  });
  tearDown(() => Profile.instance.wipe());

  group('what is taken off the picture', () {
    test('reference, account and phone numbers and emails always go', () {
      final out = redactForCard('Account 1234567890 and REF-2024-0015. Mail ali@mail.com or call +971 50 123 4567.', hideAmounts: false);
      for (final bad in ['1234567890', '0015', '@', '4567']) {
        expect(out, isNot(contains(bad)), reason: bad);
      }
    });

    test('amounts go when asked, and stay when not', () {
      const text = 'Pay AED 2,300 or 450 pesos or \$120 or 300 AED';
      final hidden = redactForCard(text);
      for (final bad in ['2,300', '450', '120', '300']) {
        expect(hidden, isNot(contains(bad)), reason: bad);
      }
      expect(hidden, contains('AED'));
      expect(redactForCard(text, hideAmounts: false), text);
    });

    test('dates, times, percentages, years and small counts stay', () {
      const text = 'Pay by 2026-03-05 or 05/03/2026, at 10:30, within 30 days, VAT 5%, in 2026.';
      expect(redactForCard(text), text);
      expect(redactForCard('From 05-03-2026 - 10-03-2026'), 'From 05-03-2026 - 10-03-2026');
    });

    test('plain text is untouched', () {
      const text = 'Your landlord must give 90 days written notice.';
      expect(redactForCard(text), text);
      expect(redactForCard(''), '');
    });

    test('long text is cut at a sentence, or at a word', () {
      expect(shortenText('Short.', 40), 'Short.');
      expect(shortenText('The bill is due soon. Pay it online or at any office before the date shown.', 30), 'The bill is due soon.');
      expect(shortenText('Pay it online or at any office before the date shown', 20), 'Pay it online or at…');
    });
  });

  group('what the card says', () {
    test('summary and the first three steps, with amounts and numbers hidden', () {
      final d = ShareCardData.fromReport(sample());
      expect(d.kicker, 'Electricity bill');
      expect(d.headline, isNot(contains('20240015')));
      expect(d.headline, isNot(contains('720')));
      expect(d.headline, contains('2026-12-01'));
      expect(d.items.length, 3);
      expect(d.items.first, 'Pay AED ••• online (1 Dec 2026)');
      expect(d.listLabel, 'What to do');
      expect(d.watchCount, 2);
      expect(d.stop, isFalse);
      expect(d.rtl, isFalse);
    });

    test('shows amounts when the person turns hiding off, but never the reference number', () {
      final d = ShareCardData.fromReport(sample(), hideAmounts: false);
      expect(d.headline, contains('AED 720'));
      expect(d.headline, isNot(contains('20240015')));
    });

    test('uses the labels of the report language', () {
      final d = ShareCardData.fromReport(sample(extra: {
        'labels': {'next_steps': 'Mga gagawin', 'watch_out': 'Mag-ingat'},
        'privacy': {},
      }));
      expect(d.listLabel, 'Mga gagawin');
      expect(d.watchLabel, 'Mag-ingat');
    });

    test('a scam warning shows why, and a missing document type is not blank', () {
      final stop = ShareCardData.fromReport(Report.fromJson({
        'summary': 'This message asks for a code.',
        'scam': {'level': 'stop', 'reasons': ['Pays to a personal account', 'Asks for a code', 'Urgent threat', 'Fourth']},
      }));
      expect(stop.stop, isTrue);
      expect(stop.kicker, 'Stop. Do not pay or reply yet');
      expect(stop.items.length, 3);
      expect(stop.watchCount, 0);
      expect(stop.listLabel, 'Watch out');
      final caution = ShareCardData.fromReport(Report.fromJson({'summary': 's', 'scam': {'level': 'caution', 'reasons': ['x']}}));
      expect(caution.stop, isFalse);
      expect(caution.kicker, 'Be careful with this one');
      expect(ShareCardData.fromReport(Report.fromJson({'summary': 's'})).kicker, 'Document');
    });

    test('very long text is shortened', () {
      final long = 'word ' * 200;
      final d = ShareCardData.fromReport(Report.fromJson({'summary': long, 'doc_type': 'x' * 100}));
      expect(d.headline.length, lessThanOrEqualTo(231));
      expect(d.kicker.length, lessThanOrEqualTo(41));
    });
  });

  group('the share dialog', () {
    Future<void> open(WidgetTester tester, Report r) async {
      tester.view.physicalSize = const Size(1000, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: buildTheme(Brightness.light),
        home: Scaffold(
          body: Builder(
            builder: (c) => TextButton(
              key: const ValueKey('open'),
              onPressed: () => showDialog<void>(context: c, builder: (_) => ShareCardDialog(report: r)),
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.byKey(const ValueKey('open')));
      await tester.pumpAndSettle();
    }

    testWidgets('previews the card with amounts hidden, and the switch shows them', (tester) async {
      Profile.instance.setName('Zed');
      await open(tester, sample());
      expect(find.text('Share as a picture'), findsOneWidget);
      expect(find.text('Electricity bill'), findsOneWidget);
      expect(find.text('Explained by Dalil'), findsOneWidget);
      expect(find.textContaining('Your bill'), findsOneWidget);
      expect(find.textContaining('AED 720'), findsNothing);
      expect(find.textContaining('AED •••'), findsWidgets);
      expect(find.textContaining('Zed'), findsNothing); // the name is never on the card
      expect(find.textContaining('20240015'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('card-hide')));
      await tester.pumpAndSettle();
      expect(find.textContaining('AED 720'), findsWidgets);
      expect(find.textContaining('20240015'), findsNothing);
    });

    testWidgets('has a share and a save button, and closes', (tester) async {
      await open(tester, sample());
      expect(tester.widget<FilledButton>(find.byKey(const ValueKey('card-share'))).onPressed, isNotNull);
      expect(tester.widget<OutlinedButton>(find.byKey(const ValueKey('card-save'))).onPressed, isNotNull);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Share as a picture'), findsNothing);
    });

    testWidgets('draws a scam warning and a right-to-left report without errors', (tester) async {
      await open(tester, Report.fromJson({
        'summary': 'رسالة تطلب رمزا.',
        'language': 'ar',
        'rtl': true,
        'scam': {'level': 'stop', 'reasons': ['تطلب رمزا']},
      }));
      expect(find.text('Stop. Do not pay or reply yet'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
