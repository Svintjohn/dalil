import 'package:dalil_app/api.dart';
import 'package:dalil_app/fonts.dart';
import 'package:dalil_app/main.dart';
import 'package:dalil_app/models.dart';
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
}
