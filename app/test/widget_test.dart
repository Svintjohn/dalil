import 'package:dalil_app/api.dart';
import 'package:dalil_app/cases.dart';
import 'package:dalil_app/deadlines.dart';
import 'package:dalil_app/fonts.dart';
import 'package:dalil_app/home.dart';
import 'package:dalil_app/speech.dart';
import 'package:dalil_app/theme.dart';
import 'package:dalil_app/widgets.dart';
import 'package:dalil_app/main.dart';
import 'package:dalil_app/models.dart';
import 'package:dalil_app/report_text.dart';
import 'package:dalil_app/report_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeApi implements DalilApi {
  @override
  Future<Meta> meta() async => Meta.fromJson({
        'version': 't',
        'languages': [
          {'code': 'en', 'name': 'English', 'native': 'English', 'tier': 'high', 'featured': true},
          {'code': 'ar', 'name': 'Arabic', 'native': 'العربية', 'rtl': true, 'tier': 'high', 'featured': true},
        ],
        'countries': [
          {'code': 'AE', 'name': 'United Arab Emirates', 'facts': 43}
        ],
        'samples': [
          {'id': 'rent', 'title': 'Rental contract', 'text': 'A made-up rental contract text that is long enough.'}
        ],
        'photo_tips': ['Lay the page flat.'],
        'privacy': {'headline': 'Your document is not saved', 'points': ['Nothing is stored.']},
      });
  @override
  Future<QualityResult> photoCheck(String b) async => QualityResult(true, []);
  @override
  Future<Report> review({required List<String> images, String? text, required String language, String? country, String? sampleId}) async =>
      Report.fromJson({
        'summary': 'Two things to check.',
        'doc_type': 'Rental contract',
        'findings': [
          {'severity': 'high', 'why': 'Deposit is too high.', 'verified': true}
        ],
        'next_steps': [
          {'action': 'Register the contract.'}
        ],
      });
  @override
  Future<AskAnswer> ask({required String question, required Map<String, dynamic> report, required String language, required List<Map<String, String>> history}) async =>
      AskAnswer('An answer.', [], []);
  @override
  Future<Letter> letter({required Map<String, dynamic> report, required String language, required String recipient, required String note}) async =>
      Letter.fromJson({'letter_en': 'Dear landlord'});
}

class FakeSpeaker implements Speaker {
  final spoken = <String>[];
  @override
  Future<bool> speak(String text, String languageCode, {void Function()? onDone}) async {
    spoken.add(text);
    return true;
  }

  @override
  Future<void> stop() async {}
}

class FakeDictation implements Dictation {
  void Function(String text)? onText;
  void Function()? onEnd;
  @override
  Future<bool> start(String languageCode, {required void Function(String text) onText, required void Function() onEnd}) async {
    this.onText = onText;
    this.onEnd = onEnd;
    return true;
  }

  @override
  Future<void> stop() async {}
}

/// Scrolls a widget to the middle of the screen, so the sticky header does not cover it.
Future<void> reveal(WidgetTester tester, Finder f) async {
  await Scrollable.ensureVisible(tester.element(f), alignment: 0.4, duration: Duration.zero);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => Fonts.web = false);

  testWidgets('sample text can be reviewed and the result appears', (tester) async {
    tester.view.physicalSize = const Size(1400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(DalilApp(api: FakeApi()));
    await tester.pumpAndSettle();
    await reveal(tester, find.text('Explain this'));
    expect(find.text('Explain this'), findsOneWidget);

    await reveal(tester, find.text('Paste text'));
    await tester.tap(find.text('Paste text'));
    await tester.pumpAndSettle();
    await reveal(tester, find.text('Rental contract'));
    await tester.tap(find.text('Rental contract'));
    await tester.pumpAndSettle();
    await reveal(tester, find.text('Explain this'));
    await tester.tap(find.text('Explain this'));
    await tester.pumpAndSettle();

    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.text('Two things to check.'), findsOneWidget);
    expect(find.text('Deposit is too high.'), findsOneWidget);
    expect(find.text('Register the contract.'), findsOneWidget);
  });

  testWidgets('scam shield shows a calm warning only when there are warning signs', (tester) async {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    Future<void> show(Map<String, dynamic> scam) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ReportView(report: Report.fromJson({'summary': 'A fine notice.', 'scam': scam}), onOpen: (_) {}),
          ),
        ),
      ));
      await tester.pumpAndSettle();
    }

    await show({'level': 'stop', 'reasons': ['Pay into a personal account']});
    expect(find.byKey(const ValueKey('scam-shield')), findsOneWidget);
    expect(find.text('Stop. Do not pay or reply yet'), findsOneWidget);
    expect(find.text('Pay into a personal account'), findsOneWidget);

    await show({'level': 'caution', 'reasons': ['Link is not official']});
    expect(find.text('Be careful with this one'), findsOneWidget);

    await show({'level': 'none'});
    expect(find.byKey(const ValueKey('scam-shield')), findsNothing);
  });

  test('copy and speech lead with the scam warning', () {
    final r = Report.fromJson({
      'summary': 'A fine notice.',
      'scam': {'level': 'stop', 'reasons': ['Pay into a personal account']},
    });
    expect(reportToText(r).startsWith('Stop. Do not pay or reply yet'), isTrue);
    expect(reportToText(r), contains('Pay into a personal account'));
    expect(reportToSpeech(r).startsWith('Stop. Do not pay or reply yet'), isTrue);
    final ok = Report.fromJson({'summary': 'A school notice.'});
    expect(reportToText(ok).startsWith('A school notice.'), isTrue);
  });

  testWidgets('if you do nothing shows stated consequences, or says it is not stated', (tester) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    Future<void> show(Map<String, dynamic> extra) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ReportView(report: Report.fromJson({'summary': 'A school notice.', ...extra}), onOpen: (_) {}),
          ),
        ),
      ));
      await tester.pumpAndSettle();
    }

    await show({
      'if_ignored': [
        {'action': 'Pay the Term 2 fee', 'consequence': 'A late charge of AED 150 will be added.', 'source': 'document'},
      ],
    });
    expect(find.text('If you do nothing'), findsOneWidget);
    expect(find.text('A late charge of AED 150 will be added.'), findsOneWidget);
    expect(find.text('The document says'), findsOneWidget);

    await show({
      'deadlines': [
        {'label': 'Pay the fee', 'within_days': 14},
      ],
    });
    expect(find.byKey(const ValueKey('if-ignored-unstated')), findsOneWidget);

    await show({});
    expect(find.text('If you do nothing'), findsNothing);

    await show({
      'scam': {'level': 'stop', 'reasons': ['Pay into a personal account']},
      'deadlines': [
        {'label': 'Pay now', 'within_days': 1},
      ],
    });
    expect(find.text('If you do nothing'), findsNothing);
  });

  testWidgets('before you go shows what to bring and ask, and bring items can be ticked', (tester) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    Future<void> show(Map<String, dynamic> extra) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ReportView(report: Report.fromJson({'summary': 'A school notice.', ...extra}), onOpen: (_) {}),
          ),
        ),
      ));
      await tester.pumpAndSettle();
    }

    await show({
      'prep': {
        'office': 'School accounts office',
        'bring': [
          {'item': 'The invoice', 'required': true},
          {'item': 'Your ID', 'required': false},
        ],
        'questions': ['Can I pay in two parts?'],
      },
    });
    expect(find.byKey(const ValueKey('prep')), findsOneWidget);
    expect(find.text('Before you go'), findsOneWidget);
    expect(find.text('School accounts office'), findsOneWidget);
    expect(find.text('The document asks for this'), findsOneWidget);
    expect(find.text('Suggested'), findsOneWidget);
    expect(find.text('Can I pay in two parts?'), findsOneWidget);
    expect(find.byIcon(Icons.radio_button_unchecked), findsNWidgets(2));
    await tester.tap(find.text('The invoice'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);

    await show({});
    expect(find.byKey(const ValueKey('prep')), findsNothing);
    expect(find.text('Before you go'), findsNothing);

    final r = Report.fromJson({
      'summary': 'A school notice.',
      'prep': {'office': 'School accounts office', 'bring': [{'item': 'The invoice'}], 'questions': ['Can I pay in two parts?']},
    });
    expect(reportToText(r), contains('The invoice'));
    expect(reportToText(r), contains('1. Can I pay in two parts?'));
  });

  testWidgets('a spoken question is sent when speaking stops and the answer is read aloud', (tester) async {
    tester.view.physicalSize = const Size(1400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final speaker = FakeSpeaker();
    final dictation = FakeDictation();

    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(Brightness.light),
      home: HomePage(api: FakeApi(), speaker: speaker, dictation: dictation),
    ));
    await tester.pumpAndSettle();
    await reveal(tester, find.text('Paste text'));
    await tester.tap(find.text('Paste text'));
    await tester.pumpAndSettle();
    await reveal(tester, find.text('Rental contract'));
    await tester.tap(find.text('Rental contract'));
    await tester.pumpAndSettle();
    await reveal(tester, find.text('Explain this'));
    await tester.tap(find.text('Explain this'));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.text('Two things to check.'), findsOneWidget);

    final askField = find.byWidgetPredicate((w) => w is TextField && (w.decoration?.hintText ?? '').contains('mic'));

    // A typed question gets a silent answer.
    await reveal(tester, askField);
    await tester.enterText(askField, 'Can they keep my passport?');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('An answer.'), findsOneWidget);
    expect(speaker.spoken, isEmpty);

    // Any answer can be read on request.
    await reveal(tester, find.byKey(const ValueKey('listen-answer-0')));
    await tester.tap(find.byKey(const ValueKey('listen-answer-0')));
    await tester.pumpAndSettle();
    expect(speaker.spoken, ['An answer.']);

    // A spoken question is sent by itself when the microphone stops, and the answer is read aloud.
    await reveal(tester, find.byIcon(Icons.mic_none_rounded));
    await tester.tap(find.byIcon(Icons.mic_none_rounded));
    await tester.pumpAndSettle();
    dictation.onText!('Do I have to pay now?');
    dictation.onEnd!();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Do I have to pay now?'), findsOneWidget);
    expect(speaker.spoken, ['An answer.', 'An answer.']);
  });

  testWidgets('the privacy dialog can delete every saved case and deadline', (tester) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final cases = CaseStore(storageKey: 'test.privacy.cases');
    final deadlines = DeadlineStore(storageKey: 'test.privacy.deadlines');
    final r = Report.fromJson({
      'summary': 'A fine notice.',
      'doc_type': 'Fine notice',
      'deadlines': [
        {'label': 'Pay the fine', 'within_days': 14},
      ],
    });
    cases.addDocument(r);
    deadlines.addAll('Fine notice', r.deadlines);
    expect(cases.cases.value, isNotEmpty);
    expect(deadlines.items.value, isNotEmpty);

    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(Brightness.light),
      home: Scaffold(body: PrivacyDialog(headline: 'Your document is not saved', points: const ['Nothing is stored.'], cases: cases, deadlines: deadlines)),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('Saved on this device: 1 case and 1 deadline'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('delete-saved')));
    await tester.pumpAndSettle();
    expect(find.text('Delete all saved data?'), findsOneWidget);

    await tester.tap(find.text('Keep it')); // cancelling changes nothing
    await tester.pumpAndSettle();
    expect(cases.cases.value, isNotEmpty);

    await tester.tap(find.byKey(const ValueKey('delete-saved')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-delete')));
    await tester.pumpAndSettle();
    expect(cases.cases.value, isEmpty);
    expect(deadlines.items.value, isEmpty);
    expect(find.text('Nothing is saved on this device.'), findsOneWidget);
    expect(find.byKey(const ValueKey('delete-saved')), findsNothing);

    final again = CaseStore(storageKey: 'test.privacy.cases')..load(); // nothing comes back after a reload
    expect(again.cases.value, isEmpty);
    final againD = DeadlineStore(storageKey: 'test.privacy.deadlines')..load();
    expect(againD.items.value, isEmpty);
  });

  testWidgets('number check shows a match calmly and a mismatch with the figures', (tester) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    Future<void> show(Map<String, dynamic> extra) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ReportView(report: Report.fromJson({'summary': 'A bill.', ...extra}), onOpen: (_) {}),
          ),
        ),
      ));
      await tester.pumpAndSettle();
    }

    final lines = [
      {'label': 'Electricity', 'amount': 320, 'role': 'item'},
      {'label': 'Water', 'amount': 85.5, 'role': 'item'},
      {'label': 'Total to pay', 'amount': 720, 'role': 'total'},
    ];

    await show({
      'number_check': {
        'status': 'mismatch',
        'currency': 'AED',
        'lines': lines,
        'issues': [
          {'code': 'total_mismatch', 'stated': 720, 'computed': 405.5, 'difference': 314.5},
        ],
      },
    });
    expect(find.byKey(const ValueKey('number-check')), findsOneWidget);
    expect(find.text('Number check'), findsOneWidget);
    expect(find.text('The amounts shown do not add up to the total on the document.'), findsOneWidget);
    expect(find.text('AED 85.50'), findsOneWidget);
    expect(find.textContaining('On the document: AED 720.00'), findsOneWidget);
    expect(find.textContaining('Added up: AED 405.50'), findsOneWidget);
    expect(find.textContaining('Difference: AED 314.50'), findsOneWidget);

    await show({
      'number_check': {'status': 'ok', 'currency': 'AED', 'lines': lines},
    });
    expect(find.text('The amounts shown add up to the total on the document.'), findsOneWidget);
    expect(find.textContaining('Difference'), findsNothing);

    await show({});
    expect(find.byKey(const ValueKey('number-check')), findsNothing);

    final bad = Report.fromJson({
      'summary': 'A bill.',
      'number_check': {
        'status': 'mismatch',
        'currency': 'AED',
        'lines': lines,
        'issues': [
          {'code': 'total_mismatch', 'stated': 720, 'computed': 405.5, 'difference': 314.5},
        ],
      },
    });
    expect(reportToText(bad), contains('Number check'));
    expect(reportToText(bad), contains('AED 720.00'));
    expect(reportToSpeech(bad), contains('AED 405.50'));
  });
}
