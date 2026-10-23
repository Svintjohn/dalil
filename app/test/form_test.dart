import 'package:dalil_app/accuracy_dialog.dart';
import 'package:dalil_app/api.dart';
import 'package:dalil_app/form_view.dart';
import 'package:dalil_app/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

FormHelp help({Map<String, dynamic> extra = const {}, List<Map<String, dynamic>>? fields}) => FormHelp.fromJson({
      'is_form': true,
      'form_name': 'Visa renewal form',
      'purpose': 'To renew a residence visa.',
      'fields': fields ??
          [
            {'label': 'Full name', 'meaning': 'Your name.', 'how_to_fill': 'As written in your passport.', 'kind': 'text', 'required': 'yes'},
            {'label': 'Passport number', 'meaning': 'The number on your passport.', 'how_to_fill': 'MUST-NOT-SHOW', 'kind': 'private', 'required': 'yes'},
            {'label': 'Marital status', 'meaning': 'Single, married or other.', 'kind': 'choice', 'required': 'no'},
          ],
      'warnings': ['Do not sign with empty boxes.'],
      'before_submit': ['Check every box.', 'Keep a copy.'],
      ...extra,
    });

Future<void> show(WidgetTester tester, FormHelp h) async {
  tester.view.physicalSize = const Size(1000, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: FormView(help: h)))));
  await tester.pumpAndSettle();
}

class _Api implements DalilApi {
  _Api({this.data, this.fail = false});
  final Accuracy? data;
  final bool fail;
  @override
  Future<Accuracy> accuracy() async {
    if (fail) throw ApiException('network', 'Could not reach Dalil.');
    return data!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Map<String, dynamic> part(int sn, int sw, int ln, int fa, int nn, int nc) => {
      'scam': {'n': sn, 'scored': sn, 'detected': sw},
      'legit': {'n': ln, 'scored': ln, 'false_alarms': fa, 'false_stops': 0},
      'numbers': {'n': nn, 'scored': nn, 'correct': nc},
    };

void main() {
  group('FormHelp', () {
    test('is read safely from odd data', () {
      final h = FormHelp.fromJson({'is_form': true, 'fields': [5, null, {'label': '', 'meaning': ''}, {'label': 'A', 'meaning': 'B', 'kind': 'weird', 'required': 'maybe'}], 'warnings': [null, ' w '], 'labels': 'nope'});
      expect(h.fields, hasLength(1));
      expect(h.fields.first.kind, 'text');
      expect(h.fields.first.required, 'unclear');
      expect(h.warnings, ['w']);
      expect(FormHelp.fromJson({'is_form': true, 'fields': []}).isForm, isFalse); // a "form" with no usable boxes is not a form
      expect(FormHelp.fromJson({'is_form': false, 'fields': [{'label': 'A', 'meaning': 'B'}]}).isForm, isFalse);
    });

    test('copy text keeps the boxes, hides tips for private boxes and uses the translated headings', () {
      final t = formToText(help(extra: {'secret_field': true, 'labels': {'form_fields': 'Ano ang ibig sabihin', 'form_warnings': 'Mag-ingat'}}));
      expect(t, contains('Visa renewal form'));
      expect(t, contains('Ano ang ibig sabihin'));
      expect(t, contains('1. Full name: Your name.'));
      expect(t, contains('As written in your passport.'));
      expect(t, isNot(contains('MUST-NOT-SHOW'))); // no tip is ever printed for a private box
      expect(t, contains('Mag-ingat'));
      expect(t, contains('password, PIN or one-time code'));
      expect(t, contains('- Check every box.'));
    });
  });

  group('FormView', () {
    testWidgets('shows each box, marks private boxes and never shows a tip for them', (tester) async {
      await show(tester, help());
      expect(find.text('Visa renewal form'), findsOneWidget);
      expect(find.text('Full name'), findsOneWidget);
      expect(find.text('As written in your passport.'), findsOneWidget);
      expect(find.byKey(const ValueKey('private-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('private-0')), findsNothing);
      expect(find.text('MUST-NOT-SHOW'), findsNothing);
      expect(find.text('Choose one'), findsOneWidget);
      expect(find.text('Required'), findsNWidgets(2));
      expect(find.byKey(const ValueKey('form-warnings')), findsOneWidget);
      expect(find.text('Do not sign with empty boxes.'), findsOneWidget);
    });

    testWidgets('a box asking for a PIN or code gets the strong warning even if the model gave none', (tester) async {
      await show(tester, help(extra: {'secret_field': true, 'warnings': []}));
      expect(find.byKey(const ValueKey('form-warnings')), findsOneWidget);
      expect(find.textContaining('A real office never needs these on a form'), findsOneWidget);
    });

    testWidgets('no warnings box when there is nothing to warn about', (tester) async {
      await show(tester, help(extra: {'warnings': []}));
      expect(find.byKey(const ValueKey('form-warnings')), findsNothing);
    });

    testWidgets('the checklist can be ticked', (tester) async {
      await show(tester, help());
      final box = find.byKey(const ValueKey('submit-0'));
      await tester.ensureVisible(box);
      await tester.tap(box);
      await tester.pump();
      expect(tester.widget<CheckboxListTile>(box).value, isTrue);
      expect(tester.widget<CheckboxListTile>(find.byKey(const ValueKey('submit-1'))).value, isFalse);
    });

    testWidgets('something that is not a form says so kindly', (tester) async {
      await show(tester, help(extra: {'is_form': false, 'purpose': 'This is a letter.'}, fields: []));
      expect(find.byKey(const ValueKey('form-not-form')), findsOneWidget);
      expect(find.textContaining('does not look like a form'), findsOneWidget);
      expect(find.text('This is a letter.'), findsOneWidget);
      expect(find.byKey(const ValueKey('form-box-0')), findsNothing);
    });

    testWidgets('an Arabic form reads right to left', (tester) async {
      await show(tester, help(extra: {'rtl': true}));
      final dir = Directionality.of(tester.element(find.text('Full name')));
      expect(dir, TextDirection.rtl);
    });
  });

  group('AccuracyDialog', () {
    Future<void> open(WidgetTester tester, DalilApi api) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: AccuracyDialog(api: api))));
      await tester.pumpAndSettle();
    }

    testWidgets('shows the offline numbers and says the AI run is not published yet', (tester) async {
      await open(tester, _Api(data: Accuracy.fromJson({'offline': part(30, 30, 34, 0, 10, 10), 'live': null, 'caveat': 'Written by the developers. Not proof.'})));
      expect(find.text('30 of 30'), findsOneWidget);
      expect(find.text('0 of 34'), findsOneWidget);
      expect(find.text('10 of 10'), findsOneWidget);
      expect(find.byKey(const ValueKey('live-missing')), findsOneWidget);
      expect(find.text('Written by the developers. Not proof.'), findsOneWidget);
      expect(find.text('What these numbers do not show'), findsOneWidget);
    });

    testWidgets('shows the AI-model run when one was saved, with its failures', (tester) async {
      final live = {...part(30, 27, 34, 2, 10, 9), 'model': 'gemini-test', 'avg_seconds': 12.4, 'errors': {'a-1': 'ModelOutputError'}};
      await open(tester, _Api(data: Accuracy.fromJson({'offline': part(30, 30, 34, 0, 10, 10), 'live': live, 'caveat': 'x'})));
      expect(find.text('27 of 30'), findsOneWidget);
      expect(find.text('2 of 34'), findsOneWidget);
      expect(find.byKey(const ValueKey('live-missing')), findsNothing);
      expect(find.textContaining('gemini-test'), findsOneWidget);
      expect(find.textContaining('1 did not run'), findsOneWidget);
    });

    testWidgets('an empty or broken live file is treated as not published', (tester) async {
      await open(tester, _Api(data: Accuracy.fromJson({'offline': part(30, 30, 34, 0, 10, 10), 'live': {}, 'caveat': ''})));
      expect(find.byKey(const ValueKey('live-missing')), findsOneWidget);
      expect(find.textContaining('not proof of accuracy on real documents'), findsOneWidget); // the built-in caveat
    });

    testWidgets('a failed load shows a calm message', (tester) async {
      await open(tester, _Api(fail: true));
      expect(find.byKey(const ValueKey('accuracy-error')), findsOneWidget);
      expect(find.text('Could not reach Dalil.'), findsOneWidget);
    });
  });
}
