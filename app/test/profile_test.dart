import 'dart:math' as math;

import 'package:dalil_app/cases.dart';
import 'package:dalil_app/deadlines.dart';
import 'package:dalil_app/due_soon.dart';
import 'package:dalil_app/fonts.dart';
import 'package:dalil_app/local_store.dart';
import 'package:dalil_app/models.dart';
import 'package:dalil_app/motion.dart';
import 'package:dalil_app/profile.dart';
import 'package:dalil_app/profile_ui.dart';
import 'package:dalil_app/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double contrast(Color a, Color b) {
  final x = a.computeLuminance(), y = b.computeLuminance();
  return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
}

TrackedDeadline dl(String id, DateTime? due, {bool done = false, String caseId = ''}) => TrackedDeadline(
      id: id,
      key: id,
      label: 'Pay $id',
      docType: 'Bill',
      addedOn: DateTime(2026, 10, 1),
      due: due,
      done: done,
      caseId: caseId,
    );

Report bill(String type, num amount, String date) => Report.fromJson({
      'doc_type': type,
      'summary': 's',
      'due': {'amount': amount, 'currency': 'AED', 'label': type, 'date': date},
    });

Widget host(Widget child) => MaterialApp(
      theme: buildTheme(Brightness.light),
      home: Scaffold(body: SingleChildScrollView(child: Padding(padding: const EdgeInsets.all(16), child: child))),
    );

void main() {
  setUp(() {
    Fonts.web = false;
    Fonts.easy = false;
    Motion.ambient = false;
    LocalStore.clearAll();
  });
  tearDown(() {
    Fonts.easy = false;
    Profile.instance.wipe();
  });

  group('greeting', () {
    test('follows the time of day', () {
      expect(greetingFor('en', DateTime(2026, 10, 21, 9)), 'Good morning');
      expect(greetingFor('en', DateTime(2026, 10, 21, 12, 30)), 'Good afternoon');
      expect(greetingFor('en', DateTime(2026, 10, 21, 15)), 'Good afternoon');
      expect(greetingFor('en', DateTime(2026, 10, 21, 19)), 'Good evening');
      expect(greetingFor('en', DateTime(2026, 10, 21, 2)), 'Hello');
    });

    test('speaks Tagalog and Arabic, and falls back to English', () {
      expect(greetingFor('tl', DateTime(2026, 10, 21, 8)), 'Magandang umaga');
      expect(greetingFor('tl', DateTime(2026, 10, 21, 12, 10)), 'Magandang tanghali');
      expect(greetingFor('tl', DateTime(2026, 10, 21, 15)), 'Magandang hapon');
      expect(greetingFor('tl', DateTime(2026, 10, 21, 19)), 'Magandang gabi');
      expect(greetingFor('ar', DateTime(2026, 10, 21, 8)), 'صباح الخير');
      expect(greetingFor('xx', DateTime(2026, 10, 21, 8)), 'Good morning');
      expect(greetingFor('', DateTime(2026, 10, 21, 19)), 'Good evening');
    });

    test('every greeting has all five day parts', () {
      for (final code in ['en', 'tl', 'ar', 'hi', 'ur', 'bn', 'ne', 'fr', 'es', 'de']) {
        for (var h = 0; h < 24; h++) {
          expect(greetingFor(code, DateTime(2026, 10, 21, h)).trim(), isNotEmpty, reason: '$code $h');
        }
      }
    });

    test('a name is cleaned and kept short', () {
      expect(cleanName('  John   Paul \n'), 'John Paul');
      expect(cleanName('<b>Ana</b>'), 'b Ana /b');
      expect(cleanName('x' * 60).length, 24);
      expect(cleanName('   '), '');
      expect(cleanName('Mae\u0000\u0007'), 'Mae');
    });
  });

  group('profile', () {
    test('starts empty and asks once', () {
      final p = Profile(storageKey: 'test.profile.1');
      expect(p.hasName, isFalse);
      expect(p.shouldAsk, isTrue);
      expect(p.accent, Accent.teal);
      expect(p.easyRead, isFalse);
      p.skipAsking();
      expect(p.shouldAsk, isFalse);
      final again = Profile(storageKey: 'test.profile.1')..load();
      expect(again.shouldAsk, isFalse); // "not now" is remembered
      expect(again.hasName, isFalse);
    });

    test('remembers the name, the colour and the font', () {
      final a = Profile(storageKey: 'test.profile.2');
      a.setName('  John ');
      a.setAccent(Accent.rose);
      a.setEasyRead(true);
      expect(Fonts.easy, isTrue);
      Fonts.easy = false;
      final b = Profile(storageKey: 'test.profile.2')..load();
      expect(b.name, 'John');
      expect(b.accent, Accent.rose);
      expect(b.easyRead, isTrue);
      expect(Fonts.easy, isTrue); // loading switches the font on
      expect(b.shouldAsk, isFalse);
    });

    test('bad saved data is ignored', () {
      for (final bad in ['', 'nope', '[]', '{"name": 5, "accent": "purple", "easy": "yes"}']) {
        Profile(storageKey: 'test.profile.bad').writeRaw(bad);
        final p = Profile(storageKey: 'test.profile.bad')..load();
        expect(p.name, '', reason: bad);
        expect(p.accent, Accent.teal, reason: bad);
        expect(p.easyRead, isFalse, reason: bad);
      }
    });

    test('the look signal changes only for colour and font', () {
      final p = Profile(storageKey: 'test.profile.look');
      var n = 0;
      p.look.addListener(() => n++);
      p.setName('Ana');
      expect(n, 0); // typing a name must not rebuild the whole app
      p.setAccent(Accent.indigo);
      expect(n, 1);
      p.setEasyRead(true);
      expect(n, 2);
      p.setEasyRead(true);
      expect(n, 2); // same value, nothing to rebuild
    });

    test('wipe forgets everything', () {
      final p = Profile(storageKey: 'test.profile.wipe');
      p.setName('Ana');
      p.setAccent(Accent.indigo);
      p.setEasyRead(true);
      p.wipe();
      expect(p.name, '');
      expect(p.shouldAsk, isTrue);
      expect(p.accent, Accent.teal);
      expect(p.easyRead, isFalse);
      expect(Fonts.easy, isFalse);
      expect(LocalStore.read('test.profile.wipe'), isNull);
    });
  });

  group('colours', () {
    test('every accent is readable in light and dark', () {
      for (final dark in [false, true]) {
        for (final a in presetAccents) {
          final p = Palette.forAccent(a, dark);
          final tag = '${a.name} dark=$dark';
          expect(contrast(p.accent, p.onAccent), greaterThanOrEqualTo(4.5), reason: '$tag on button');
          expect(contrast(p.accent, p.accentTint), greaterThanOrEqualTo(4.5), reason: '$tag on tint');
          expect(contrast(p.accent, p.bg), greaterThanOrEqualTo(4.5), reason: '$tag on page');
          expect(contrast(p.accent, p.surface), greaterThanOrEqualTo(4.5), reason: '$tag on card');
        }
      }
    });

    test('accents differ, and the rest of the palette stays', () {
      final colours = {for (final a in presetAccents) Palette.forAccent(a, false).accent.toARGB32()};
      expect(colours.length, presetAccents.length);
      expect(Palette.forAccent(Accent.rose, false).bg, Palette.light.bg);
      expect(Palette.forAccent(Accent.rose, true).high, Palette.dark.high);
      expect(identical(Palette.forAccent(Accent.teal, false), Palette.light), isTrue);
    });

    test('the theme uses the chosen accent', () {
      expect(buildTheme(Brightness.light, accent: Accent.indigo).colorScheme.primary, Palette.forAccent(Accent.indigo, false).accent);
      expect(buildTheme(Brightness.dark, accent: Accent.rose).colorScheme.primary, Palette.forAccent(Accent.rose, true).accent);
    });

    testWidgets('widgets pick up a new accent', (tester) async {
      Color? seen;
      await tester.pumpWidget(MaterialApp(
        theme: buildTheme(Brightness.light, accent: Accent.indigo),
        home: Builder(builder: (context) {
          seen = Palette.of(context).accent;
          return const SizedBox();
        }),
      ));
      expect(seen, Palette.forAccent(Accent.teal, false).accent); // Palette.of reads the saved choice
      Profile.instance.setAccent(Accent.indigo);
      await tester.pumpWidget(MaterialApp(
        theme: buildTheme(Brightness.light, accent: Accent.indigo),
        home: Builder(builder: (context) {
          seen = Palette.of(context).accent;
          return const SizedBox();
        }),
      ));
      expect(seen, Palette.forAccent(Accent.indigo, false).accent);
    });
  });

  group('hello at the top of the page', () {
    final evening = DateTime(2026, 10, 21, 19);

    testWidgets('asks for a name once, then says hello', (tester) async {
      final prof = Profile(storageKey: 'test.hello.1');
      await tester.pumpWidget(host(HelloStrip(languageCode: 'en', profile: prof, now: evening)));
      expect(find.text('What should we call you?'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('hello-save'))); // nothing typed: nothing happens
      await tester.pumpAndSettle();
      expect(find.text('What should we call you?'), findsOneWidget);
      expect(prof.shouldAsk, isTrue);

      await tester.enterText(find.byKey(const ValueKey('hello-name')), '  John ');
      await tester.tap(find.byKey(const ValueKey('hello-save')));
      await tester.pumpAndSettle();
      expect(find.text('Good evening, John'), findsOneWidget);
      expect(find.text('What should we call you?'), findsNothing);
      expect(prof.name, 'John');
    });

    testWidgets('"Not now" hides the question for good', (tester) async {
      final prof = Profile(storageKey: 'test.hello.2');
      await tester.pumpWidget(host(HelloStrip(languageCode: 'en', profile: prof, now: evening)));
      await tester.tap(find.byKey(const ValueKey('hello-skip')));
      await tester.pumpAndSettle();
      expect(find.text('What should we call you?'), findsNothing);
      expect(find.byIcon(Icons.waving_hand_outlined), findsNothing);
      // a new visit, same device
      final again = Profile(storageKey: 'test.hello.2')..load();
      await tester.pumpWidget(host(HelloStrip(languageCode: 'en', profile: again, now: evening)));
      await tester.pumpAndSettle();
      expect(find.text('What should we call you?'), findsNothing);
    });

    testWidgets('greets in the chosen language, right to left for Arabic', (tester) async {
      final prof = Profile(storageKey: 'test.hello.3')..setName('Ana');
      await tester.pumpWidget(host(HelloStrip(languageCode: 'tl', profile: prof, now: evening)));
      expect(find.text('Magandang gabi, Ana'), findsOneWidget);
      await tester.pumpWidget(host(HelloStrip(languageCode: 'ar', rtl: true, profile: prof, now: evening)));
      await tester.pumpAndSettle();
      expect(find.text('مساء الخير، Ana'), findsOneWidget);
    });

    testWidgets('Edit opens the personalize dialog', (tester) async {
      final prof = Profile(storageKey: 'test.hello.4')..setName('Ana');
      await tester.pumpWidget(host(HelloStrip(languageCode: 'en', profile: prof, now: evening)));
      await tester.tap(find.byKey(const ValueKey('hello-edit')));
      await tester.pumpAndSettle();
      expect(find.text('Make it yours'), findsOneWidget);
    });
  });

  group('make it yours', () {
    Future<Profile> open(WidgetTester tester, String key) async {
      tester.view.physicalSize = const Size(1000, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final prof = Profile(storageKey: key);
      await tester.pumpWidget(MaterialApp(
        theme: buildTheme(Brightness.light),
        home: Scaffold(body: Builder(builder: (c) => TextButton(key: const ValueKey('open'), onPressed: () => openPersonalize(c, prof), child: const Text('open')))),
      ));
      await tester.tap(find.byKey(const ValueKey('open')));
      await tester.pumpAndSettle();
      return prof;
    }

    testWidgets('picks a colour and switches the easy-read font', (tester) async {
      final prof = await open(tester, 'test.dialog.1');
      expect(prof.accent, Accent.teal);
      await tester.ensureVisible(find.byKey(const ValueKey('accent-indigo')));
      await tester.tap(find.byKey(const ValueKey('accent-indigo')));
      await tester.pumpAndSettle();
      expect(prof.accent, Accent.indigo);
      await tester.ensureVisible(find.byKey(const ValueKey('accent-rose')));
      await tester.tap(find.byKey(const ValueKey('accent-rose')));
      await tester.pumpAndSettle();
      expect(prof.accent, Accent.rose);
      expect(find.byIcon(Icons.check), findsOneWidget); // only the chosen one is ticked

      expect(prof.easyRead, isFalse);
      await tester.ensureVisible(find.byKey(const ValueKey('easy-read')));
      await tester.tap(find.byKey(const ValueKey('easy-read')));
      await tester.pumpAndSettle();
      expect(prof.easyRead, isTrue);
      expect(Fonts.easy, isTrue);
    });

    testWidgets('saves a name with Save, and with Done', (tester) async {
      final prof = await open(tester, 'test.dialog.2');
      await tester.enterText(find.byKey(const ValueKey('profile-name')), 'Mae');
      await tester.tap(find.byKey(const ValueKey('profile-save')));
      await tester.pumpAndSettle();
      expect(prof.name, 'Mae');

      await tester.enterText(find.byKey(const ValueKey('profile-name')), 'Mae Ann');
      await tester.ensureVisible(find.byKey(const ValueKey('profile-done')));
      await tester.tap(find.byKey(const ValueKey('profile-done')));
      await tester.pumpAndSettle();
      expect(prof.name, 'Mae Ann');
      expect(find.text('Make it yours'), findsNothing); // Done closes it
    });

    testWidgets('clearing the name removes it but does not ask again', (tester) async {
      final prof = await open(tester, 'test.dialog.3');
      prof.setName('Mae');
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('profile-name')), '');
      await tester.tap(find.byKey(const ValueKey('profile-save')));
      await tester.pumpAndSettle();
      expect(prof.hasName, isFalse);
      expect(prof.shouldAsk, isFalse);
    });
  });

  group('due this week', () {
    final today = DateTime(2026, 10, 21);

    test('counts what is due within seven days and what is already late', () {
      final r = dueSoon([
        dl('a', DateTime(2026, 10, 21)), // today
        dl('b', DateTime(2026, 10, 28)), // day 7
        dl('c', DateTime(2026, 10, 29)), // day 8: not yet
        dl('d', DateTime(2026, 10, 15)), // late
        dl('e', DateTime(2026, 10, 22), done: true), // done
        dl('f', null), // no date
      ], const [], now: today);
      expect(r.count, 3);
      expect(r.overdue, 1);
      expect(r.label, '3 due this week');
      expect(r.tip, 'Includes 1 that is already late');
    });

    test('says "1 due this week" for one', () {
      expect(dueSoon([dl('a', DateTime(2026, 10, 23))], const [], now: today).label, '1 due this week');
      expect(dueSoon(const [], const [], now: today).count, 0);
    });

    test('an unpaid amount counts, a paid one does not', () {
      final store = CaseStore(storageKey: 'test.due.1');
      final a = store.addDocument(bill('Rent', 3000, '2026-10-25'), now: DateTime(2026, 10, 1))!;
      store.addDocument(bill('Fine', 500, '2026-12-25'), now: DateTime(2026, 10, 2)); // far away
      store.addDocument(bill('No date', 80, ''), now: DateTime(2026, 10, 3));
      expect(dueSoon(const [], store.cases.value, now: today).count, 1);
      store.setPaid(a, store.cases.value.firstWhere((c) => c.id == a).entries.first.id, true);
      expect(dueSoon(const [], store.cases.value, now: today).count, 0);
    });

    test('a bill with a deadline and an amount is counted once', () {
      final store = CaseStore(storageKey: 'test.due.2');
      final id = store.addDocument(bill('Electricity', 720, '2026-10-24'), now: DateTime(2026, 10, 1))!;
      final r = dueSoon([dl('x', DateTime(2026, 10, 24), caseId: id)], store.cases.value, now: today);
      expect(r.count, 1);
      final other = dueSoon([dl('x', DateTime(2026, 10, 24), caseId: 'another')], store.cases.value, now: today);
      expect(other.count, 2); // a different case: both count
    });

    testWidgets('shows a badge only when something is due', (tester) async {
      final ds = ValueNotifier<List<TrackedDeadline>>(const []);
      final cs = ValueNotifier<List<CaseFile>>(const []);
      var taps = 0;
      await tester.pumpWidget(host(DueBadge(onTap: () => taps++, deadlines: ds, cases: cs, now: today)));
      expect(find.byKey(const ValueKey('due-badge')), findsNothing);

      ds.value = [dl('a', DateTime(2026, 10, 23)), dl('b', DateTime(2026, 10, 24))];
      await tester.pump();
      expect(find.text('2 due this week'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('due-badge')));
      expect(taps, 1);

      ds.value = [dl('a', DateTime(2026, 10, 23), done: true)];
      await tester.pump();
      expect(find.byKey(const ValueKey('due-badge')), findsNothing); // ticking it off removes it
    });

    testWidgets('a late item changes the icon, and the narrow version shows only the number', (tester) async {
      final ds = ValueNotifier<List<TrackedDeadline>>([dl('a', DateTime(2026, 10, 1))]);
      final cs = ValueNotifier<List<CaseFile>>(const []);
      await tester.pumpWidget(host(DueBadge(onTap: () {}, compact: true, deadlines: ds, cases: cs, now: today)));
      expect(find.text('1'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('1 due this week'), findsNothing);
    });
  });
}
