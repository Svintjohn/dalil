import 'package:dalil_app/color_wheel.dart';
import 'package:dalil_app/fonts.dart';
import 'package:dalil_app/local_store.dart';
import 'package:dalil_app/motion.dart';
import 'package:dalil_app/profile.dart';
import 'package:dalil_app/theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    Fonts.web = false;
    Fonts.easy = false;
    Motion.ambient = false;
    LocalStore.clearAll();
  });
  tearDown(() => Profile.instance.wipe());

  group('names and rings', () {
    test('every hue has a name', () {
      expect(hueNames.length, wheelHues);
      expect(hueNames.toSet().length, wheelHues);
      expect(hueName(0), 'Red');
      expect(hueName(240), 'Blue');
      expect(hueName(360), 'Red');
      expect(hueName(-15), 'Crimson');
      expect(hueName(122), 'Green');
    });

    test('a strength belongs to its nearest ring', () {
      expect(ringOfSat(0.80), 0);
      expect(ringOfSat(0.95), 0);
      expect(ringOfSat(0.55), 1);
      expect(ringOfSat(0.32), 2);
      expect(ringOfSat(0.15), 2);
    });
  });

  group('where a point lands on the wheel', () {
    const geo = WheelGeometry(300);

    test('the middle of every cell finds that cell', () {
      for (var ring = 0; ring < wheelSats.length; ring++) {
        for (var h = 0; h < wheelHues; h++) {
          expect(geo.hit(geo.centerOf((ring, h))), (ring, h), reason: 'ring $ring hue $h');
        }
      }
    });

    test('red is at the top and the hues go clockwise', () {
      expect(geo.hit(Offset(geo.c, geo.c - geo.r * 0.9)), (0, 0));
      expect(geo.hit(Offset(geo.c + geo.r * 0.9, geo.c)), (0, 6)); // a quarter turn: yellow-green side, 90 degrees
      expect(geo.hit(Offset(geo.c, geo.c + geo.r * 0.9)), (0, 12));
      expect(geo.hit(Offset(geo.c - geo.r * 0.9, geo.c)), (0, 18));
    });

    test('the hub, the gaps and the outside are not cells', () {
      expect(geo.hit(Offset(geo.c, geo.c)), isNull);
      expect(geo.hit(Offset(geo.c + geo.r * 0.2, geo.c)), isNull);
      expect(geo.hit(Offset(geo.c + geo.r * 0.78, geo.c)), isNull); // between the outer and the middle ring
      expect(geo.hit(Offset(geo.c + geo.r * 1.2, geo.c)), isNull);
      expect(geo.hit(const Offset(0, 0)), isNull);
    });
  });

  group('colours made from the wheel', () {
    test('every cell is readable in light and dark', () {
      for (final dark in [false, true]) {
        for (var ring = 0; ring < wheelSats.length; ring++) {
          for (var h = 0; h < wheelHues; h++) {
            final p = Palette.custom(h * 15.0, wheelSats[ring], dark);
            final tag = 'hue ${h * 15} ring $ring dark=$dark';
            expect(contrastRatio(p.accent, p.bg), greaterThanOrEqualTo(4.5), reason: '$tag on page');
            expect(contrastRatio(p.accent, p.surface), greaterThanOrEqualTo(4.5), reason: '$tag on card');
            expect(contrastRatio(p.accent, p.inset), greaterThanOrEqualTo(4.5), reason: '$tag on inset');
            expect(contrastRatio(p.accent, p.accentTint), greaterThanOrEqualTo(4.5), reason: '$tag on tint');
            expect(contrastRatio(p.accent, p.onAccent), greaterThanOrEqualTo(4.5), reason: '$tag on button');
            expect(p.bg, (dark ? Palette.dark : Palette.light).bg, reason: tag);
          }
        }
      }
    });

    test('the same colour is made once, and turning past 360 wraps round', () {
      expect(identical(Palette.custom(200, 0.55, false), Palette.custom(200, 0.55, false)), isTrue);
      expect(identical(Palette.custom(360, 0.8, false), Palette.custom(0, 0.8, false)), isTrue);
      expect(identical(Palette.custom(-15, 0.8, true), Palette.custom(345, 0.8, true)), isTrue);
      expect(Palette.custom(10, 0.0, false).accent, Palette.custom(10, 0.15, false).accent); // too weak is lifted to the lowest strength
    });

    test('different hues give different colours', () {
      final all = {for (var h = 0; h < wheelHues; h++) Palette.custom(h * 15.0, 0.8, false).accent.toARGB32()};
      expect(all.length, wheelHues);
    });

    test('the theme and Palette.of follow the custom colour', () {
      final t = buildTheme(Brightness.light, accent: Accent.custom, hue: 240, sat: 0.8);
      expect(t.colorScheme.primary, Palette.custom(240, 0.8, false).accent);
      expect(buildTheme(Brightness.dark, accent: Accent.custom, hue: 240, sat: 0.8).colorScheme.primary, Palette.custom(240, 0.8, true).accent);
      expect(Palette.forAccent(Accent.custom, false), Palette.light); // the preset lookup alone falls back to teal
    });
  });

  group('the saved custom colour', () {
    test('is remembered, and brings the whole app to it', () {
      final a = Profile(storageKey: 'test.wheel.1');
      var looks = 0;
      a.look.addListener(() => looks++);
      a.setCustom(240, 0.8);
      expect(a.accent, Accent.custom);
      expect(looks, 1);
      expect(a.look.value, contains('custom'));
      final b = Profile(storageKey: 'test.wheel.1')..load();
      expect(b.accent, Accent.custom);
      expect(b.customHue, 240);
      expect(b.customSat, 0.8);
      a.setCustom(240, 0.8);
      expect(looks, 1); // the same colour again changes nothing
      a.setCustom(255, 0.8);
      expect(looks, 2);
    });

    test('a bad hue or strength is repaired, and wipe goes back to teal', () {
      final p = Profile(storageKey: 'test.wheel.2');
      p.setCustom(725, 5);
      expect(p.customHue, 5);
      expect(p.customSat, 0.95);
      p.setCustom(-30, -1);
      expect(p.customHue, 330);
      expect(p.customSat, 0.15);
      Profile(storageKey: 'test.wheel.3').writeRaw('{"accent":"custom","hue":"red","sat":null}');
      final q = Profile(storageKey: 'test.wheel.3')..load();
      expect(q.accent, Accent.custom);
      expect(q.customHue, 200);
      expect(q.customSat, 0.55);
      p.wipe();
      expect(p.accent, Accent.teal);
      expect(p.customHue, 200);
      expect(p.customSat, 0.55);
    });

    test('choosing a ready-made colour after a custom one works', () {
      final p = Profile(storageKey: 'test.wheel.4');
      p.setCustom(10, 0.8);
      p.setAccent(Accent.indigo);
      expect(p.accent, Accent.indigo);
      expect(p.look.value, 'indigo|false');
    });
  });

  group('the wheel on screen', () {
    Future<(Profile, WheelGeometry, Offset)> show(WidgetTester tester, String key) async {
      tester.view.physicalSize = const Size(1000, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final prof = Profile(storageKey: key);
      await tester.pumpWidget(MaterialApp(
        theme: buildTheme(Brightness.light),
        home: Scaffold(body: Center(child: SizedBox(width: 420, child: ColorStudio(profile: prof)))),
      ));
      await tester.pumpAndSettle();
      final wheel = find.byKey(const ValueKey('color-wheel'));
      return (prof, WheelGeometry(tester.getSize(wheel).width), tester.getTopLeft(wheel));
    }

    testWidgets('shows the colour in use, and a preview', (tester) async {
      await show(tester, 'test.wheel.ui.1');
      expect(find.text('Teal'), findsOneWidget); // the hub names the ready-made colour
      expect(find.text('Preview'), findsOneWidget);
      expect(find.text('Button'), findsOneWidget);
      expect(find.text('Highlight'), findsOneWidget);
    });

    testWidgets('moving the mouse previews a colour without changing the app', (tester) async {
      final (prof, geo, origin) = await show(tester, 'test.wheel.ui.2');
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(1, 1));
      addTearDown(mouse.removePointer);
      await mouse.moveTo(origin + geo.centerOf((0, 16)));
      await tester.pumpAndSettle();
      expect(find.text('Blue'), findsOneWidget);
      expect(find.text('VIVID'), findsOneWidget);
      expect(prof.accent, Accent.teal); // only a preview

      await mouse.moveTo(origin + geo.centerOf((2, 8)));
      await tester.pumpAndSettle();
      expect(find.text('Green'), findsOneWidget);
      expect(find.text('MUTED'), findsOneWidget);

      await mouse.moveTo(const Offset(1, 1)); // away from the wheel
      await tester.pumpAndSettle();
      expect(find.text('Teal'), findsOneWidget);
      expect(find.text('Green'), findsNothing);
    });

    testWidgets('a click chooses the colour', (tester) async {
      final (prof, geo, origin) = await show(tester, 'test.wheel.ui.3');
      await tester.tapAt(origin + geo.centerOf((0, 16)));
      await tester.pumpAndSettle();
      expect(prof.accent, Accent.custom);
      expect(prof.customHue, 240);
      expect(prof.customSat, 0.8);
      expect(find.text('Blue'), findsOneWidget);

      await tester.tapAt(origin + geo.centerOf((1, 2)));
      await tester.pumpAndSettle();
      expect(prof.customHue, 30);
      expect(prof.customSat, 0.55);
      expect(find.text('Orange'), findsOneWidget);
      expect(find.text('SOFT'), findsOneWidget);
    });

    testWidgets('a tap on the hub or between the rings does nothing', (tester) async {
      final (prof, geo, origin) = await show(tester, 'test.wheel.ui.4');
      await tester.tapAt(origin + Offset(geo.c, geo.c));
      await tester.pumpAndSettle();
      await tester.tapAt(origin + Offset(geo.c + geo.r * 0.78, geo.c));
      await tester.pumpAndSettle();
      expect(prof.accent, Accent.teal);
    });

    testWidgets('dragging a finger across the wheel picks where it lifts', (tester) async {
      final (prof, geo, origin) = await show(tester, 'test.wheel.ui.5');
      final from = origin + geo.centerOf((0, 0));
      final to = origin + geo.centerOf((0, 8));
      final g = await tester.startGesture(from);
      for (var i = 1; i <= 6; i++) {
        await g.moveTo(Offset.lerp(from, to, i / 6)!);
        await tester.pump();
      }
      expect(prof.accent, Accent.teal); // still only previewing
      await g.up();
      await tester.pumpAndSettle();
      expect(prof.accent, Accent.custom);
      expect(prof.customHue, 120);
    });

    testWidgets('the arrow keys move and Enter chooses', (tester) async {
      final (prof, geo, origin) = await show(tester, 'test.wheel.ui.6');
      await tester.tapAt(origin + geo.centerOf((0, 16))); // also puts the keyboard on the wheel
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(prof.customHue, 240); // moving only previews
      expect(find.text('Indigo'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(prof.customHue, 255);
      expect(prof.customSat, 0.55);
    });

    testWidgets('draws in dark mode and with the colour already chosen, without errors', (tester) async {
      tester.view.physicalSize = const Size(1000, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final prof = Profile(storageKey: 'test.wheel.ui.7')..setCustom(300, 0.32);
      await tester.pumpWidget(MaterialApp(
        theme: buildTheme(Brightness.dark),
        themeMode: ThemeMode.dark,
        darkTheme: buildTheme(Brightness.dark),
        home: Scaffold(body: Center(child: SizedBox(width: 420, child: ColorStudio(profile: prof)))),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Magenta'), findsOneWidget);
      expect(find.text('MUTED'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
