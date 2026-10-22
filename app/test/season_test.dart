import 'package:dalil_app/api.dart';
import 'package:dalil_app/fonts.dart';
import 'package:dalil_app/landing.dart';
import 'package:dalil_app/local_store.dart';
import 'package:dalil_app/motion.dart';
import 'package:dalil_app/profile.dart';
import 'package:dalil_app/season.dart';
import 'package:dalil_app/season_layer.dart';
import 'package:dalil_app/sfx.dart';
import 'package:dalil_app/theme.dart';
import 'package:dalil_app/tilt.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    Fonts.web = false;
    Motion.ambient = false;
  });

  group('which season is it', () {
    test('dates map to seasons', () {
      expect(seasonFor(DateTime(2026, 10, 23)), Season.none);
      expect(seasonFor(DateTime(2026, 10, 24)), Season.halloween);
      expect(seasonFor(DateTime(2026, 10, 31)), Season.halloween);
      expect(seasonFor(DateTime(2026, 11, 1)), Season.halloween);
      expect(seasonFor(DateTime(2026, 11, 2)), Season.none);
      expect(seasonFor(DateTime(2026, 11, 30)), Season.none);
      expect(seasonFor(DateTime(2026, 12, 1)), Season.christmas);
      expect(seasonFor(DateTime(2026, 12, 26)), Season.christmas);
      expect(seasonFor(DateTime(2026, 12, 27)), Season.none);
      expect(seasonFor(DateTime(2026, 12, 30)), Season.newYear);
      expect(seasonFor(DateTime(2027, 1, 1)), Season.newYear);
      expect(seasonFor(DateTime(2027, 1, 2)), Season.newYear);
      expect(seasonFor(DateTime(2027, 1, 3)), Season.none);
      expect(seasonFor(DateTime(2026, 6, 15)), Season.none);
    });

    test('UAE National Day only shows on Gulf time', () {
      expect(seasonFor(DateTime(2026, 12, 2)), Season.christmas);
      expect(seasonFor(DateTime(2026, 12, 2), gulf: true), Season.uaeDay);
      expect(seasonFor(DateTime(2026, 12, 3), gulf: true), Season.uaeDay);
      expect(seasonFor(DateTime(2026, 12, 4), gulf: true), Season.christmas);
    });

    test('Ramadan and Eid follow the Islamic calendar', () {
      expect(seasonFor(DateTime(2026, 3, 5), hijri: '9-16'), Season.ramadan);
      expect(seasonFor(DateTime(2026, 3, 20), hijri: '10-1'), Season.eid);
      expect(seasonFor(DateTime(2026, 3, 22), hijri: '10-3'), Season.eid);
      expect(seasonFor(DateTime(2026, 3, 23), hijri: '10-4'), Season.none);
      expect(seasonFor(DateTime(2026, 5, 27), hijri: '12-10'), Season.eid);
      expect(seasonFor(DateTime(2026, 5, 31), hijri: '12-14'), Season.none);
      for (final bad in ['', 'x', '9', '9-x', '--']) {
        expect(seasonFor(DateTime(2026, 6, 1), hijri: bad), Season.none, reason: bad);
      }
    });

    test('a link can preview a season', () {
      final d = DateTime(2026, 6, 1);
      expect(currentSeason(now: d, preview: 'christmas'), Season.christmas);
      expect(currentSeason(now: d, preview: 'Halloween'), Season.halloween);
      expect(currentSeason(now: DateTime(2026, 12, 5), preview: 'off'), Season.none);
      expect(currentSeason(now: d, preview: 'nonsense'), Season.none); // an unknown name falls back to the date
      for (final s in Season.values.where((s) => s != Season.none)) {
        expect(seasonName(s), isNotEmpty);
      }
    });
  });

  group('decoration setting', () {
    test('is on by default, is remembered, and can be wiped', () {
      final a = SeasonSettings(storageKey: 'test.season.1');
      expect(a.enabled, isTrue);
      a.setEnabled(false);
      final b = SeasonSettings(storageKey: 'test.season.1')..load();
      expect(b.enabled, isFalse);
      b.wipe();
      final c = SeasonSettings(storageKey: 'test.season.1')..load();
      expect(c.enabled, isTrue);
    });
  });

  group('decorations on screen', () {
    Widget host(Widget child, {bool reduce = false}) => MaterialApp(
          theme: buildTheme(Brightness.light),
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: reduce),
              child: Scaffold(body: Stack(children: [const Positioned.fill(child: ColoredBox(color: Colors.white)), child])),
            ),
          ),
        );

    testWidgets('every season draws without trouble, and never takes a tap', (tester) async {
      for (final s in Season.values.where((s) => s != Season.none)) {
        final settings = SeasonSettings(storageKey: 'test.season.draw.${s.name}');
        await tester.pumpWidget(host(Positioned.fill(child: SeasonLayer(season: s, settings: settings))));
        await tester.pump();
        expect(find.byType(CustomPaint), findsWidgets, reason: s.name);
        expect(find.descendant(of: find.byType(SeasonLayer), matching: find.byType(IgnorePointer)), findsOneWidget, reason: s.name);
        expect(tester.takeException(), isNull, reason: s.name);
      }
    });

    testWidgets('nothing is drawn when there is no season or the person turned them off', (tester) async {
      await tester.pumpWidget(host(const Positioned.fill(child: SeasonLayer(season: Season.none))));
      expect(find.descendant(of: find.byType(SeasonLayer), matching: find.byType(CustomPaint)), findsNothing);

      final off = SeasonSettings(storageKey: 'test.season.off')..setEnabled(false);
      await tester.pumpWidget(host(Positioned.fill(child: SeasonLayer(season: Season.christmas, settings: off))));
      expect(find.descendant(of: find.byType(SeasonLayer), matching: find.byType(CustomPaint)), findsNothing);
      off.setEnabled(true);
      await tester.pump();
      expect(find.descendant(of: find.byType(SeasonLayer), matching: find.byType(CustomPaint)), findsOneWidget);
    });

    testWidgets('nothing is drawn when the device asks for less motion', (tester) async {
      await tester.pumpWidget(host(const Positioned.fill(child: SeasonLayer(season: Season.christmas)), reduce: true));
      expect(find.descendant(of: find.byType(SeasonLayer), matching: find.byType(CustomPaint)), findsNothing);
    });
  });

  group('card tilt', () {
    testWidgets('leans toward the pointer and settles back', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Center(child: TiltOnHover(child: SizedBox(key: ValueKey('card'), width: 200, height: 100))))));
      final box = tester.getRect(find.byKey(const ValueKey('card')));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: box.center);
      addTearDown(mouse.removePointer);
      await tester.pump();
      double lean() => tester
          .widgetList<Transform>(find.descendant(of: find.byType(TiltOnHover), matching: find.byType(Transform)))
          .map((t) => t.transform.storage[8].abs())
          .fold<double>(0, (a, b) => a > b ? a : b);
      expect(lean(), lessThan(0.01));
      await mouse.moveTo(Offset(box.right - 4, box.center.dy));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(lean(), greaterThan(0.01));
      await mouse.moveTo(const Offset(5, 5)); // off the card
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(lean(), lessThan(0.01));
    });

    testWidgets('does not move when the device asks for less motion', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: const Scaffold(body: Center(child: TiltOnHover(child: SizedBox(width: 200, height: 100)))),
          ),
        ),
      ));
      expect(find.byType(TweenAnimationBuilder<Offset>), findsNothing);
    });
  });

  group('clear saved data from the footer', () {
    testWidgets('asks first, then removes sound settings, decorations setting and the saved page data too', (tester) async {
      tester.view.physicalSize = const Size(1000, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      LocalStore.write(HttpDalilApi.metaKey, '{"languages":[1]}');
      Sfx.instance.setEnabled(true);
      SeasonSettings.instance.setEnabled(false);
      Profile.instance.setName('Ana');
      Profile.instance.setAccent(Accent.rose);

      await tester.pumpWidget(MaterialApp(theme: buildTheme(Brightness.light), home: const Scaffold(body: SingleChildScrollView(child: SiteFooter()))));
      await tester.tap(find.byKey(const ValueKey('clear-storage')));
      await tester.pumpAndSettle();
      expect(find.text('Delete all saved data?'), findsOneWidget);
      await tester.tap(find.text('Keep it'));
      await tester.pumpAndSettle();
      expect(LocalStore.read(HttpDalilApi.metaKey), isNotNull); // keeping it changes nothing
      expect(Sfx.instance.enabled, isTrue);
      expect(Profile.instance.name, 'Ana');

      await tester.tap(find.byKey(const ValueKey('clear-storage')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('confirm-delete')));
      await tester.pumpAndSettle();
      expect(LocalStore.read(HttpDalilApi.metaKey), isNull);
      expect(Sfx.instance.enabled, isFalse);
      expect(SeasonSettings.instance.enabled, isTrue);
      expect(Profile.instance.name, '');
      expect(Profile.instance.accent, Accent.teal);
    });
  });
}
