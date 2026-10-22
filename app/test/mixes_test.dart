import 'package:dalil_app/fonts.dart';
import 'package:dalil_app/motion.dart';
import 'package:dalil_app/sfx.dart';
import 'package:dalil_app/sound_pill.dart';
import 'package:dalil_app/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> reveal(WidgetTester tester, Finder f) async {
  await Scrollable.ensureVisible(tester.element(f), alignment: 0.5, duration: Duration.zero);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    Fonts.web = false;
    Motion.ambient = false;
  });

  group('my mixes', () {
    test('a name is trimmed and kept short', () {
      expect(cleanMixName('  Quiet   desk '), 'Quiet desk');
      expect(cleanMixName('a' * 40).length, 16);
      expect(cleanMixName('   '), '');
    });

    test('saves the sound in use and brings it back', () {
      final s = Sfx(storageKey: 'test.mix.1');
      s.selectPreset('thock');
      s.movePuck(0.4, 0.7);
      s.setTune(pitch: -3, decay: 1.6, bright: 0.2, reverb: 0.5, human: 0.1, pan: 0.9);
      expect(s.saveMix('Quiet desk'), isTrue);
      expect(s.mixes.single.name, 'Quiet desk');

      s.selectPreset('glass');
      s.setTune(pitch: 5, decay: 0.5, bright: 0.9, reverb: 0, human: 0.9, pan: 0);
      expect(s.presetId, 'glass');

      s.applyMix(0);
      expect(s.presetId, 'thock');
      expect(s.customX, closeTo(0.4, 1e-9));
      expect(s.customY, closeTo(0.7, 1e-9));
      expect(s.pitch, -3);
      expect(s.decay, closeTo(1.6, 1e-9));
      expect(s.bright, closeTo(0.2, 1e-9));
      expect(s.reverb, closeTo(0.5, 1e-9));
      expect(s.human, closeTo(0.1, 1e-9));
      expect(s.pan, closeTo(0.9, 1e-9));
    });

    test('a preset that was not moved is saved without a puck position', () {
      final s = Sfx(storageKey: 'test.mix.2');
      s.selectPreset('wood');
      s.saveMix('Plain wood');
      expect(s.mixes.single.cx, isNull);
      s.movePuck(0.9, 0.9);
      s.applyMix(0);
      expect(s.customX, isNull);
      expect(s.presetId, 'wood');
    });

    test('the same name replaces, an empty name gets a number, and the list has a limit', () {
      final s = Sfx(storageKey: 'test.mix.3');
      s.selectPreset('bubble');
      s.saveMix('One');
      s.selectPreset('glass');
      s.saveMix('one'); // same name, any case: replaced
      expect(s.mixes.length, 1);
      expect(s.mixes.single.presetId, 'glass');
      expect(s.saveMix('   '), isTrue);
      expect(s.mixes.last.name, 'My mix 2');
      for (var i = 0; s.mixes.length < Sfx.maxMixes; i++) {
        s.saveMix('Mix $i');
      }
      expect(s.mixes.length, Sfx.maxMixes);
      expect(s.saveMix('One too many'), isFalse);
      expect(s.saveMix('One'), isTrue); // replacing still works when full
      expect(s.mixes.length, Sfx.maxMixes);
    });

    test('deleting and applying a missing one is safe', () {
      final s = Sfx(storageKey: 'test.mix.4');
      s.saveMix('A');
      s.saveMix('B');
      s.applyMix(7);
      s.applyMix(-1);
      s.deleteMix(9);
      s.deleteMix(0);
      expect(s.mixes.single.name, 'B');
    });

    test('mixes are remembered, and bad saved ones are skipped', () {
      final a = Sfx(storageKey: 'test.mix.5');
      a.selectPreset('oud');
      a.saveMix('Evening');
      final b = Sfx(storageKey: 'test.mix.5')..load();
      expect(b.mixes.single.name, 'Evening');
      expect(b.mixes.single.presetId, 'oud');

      Sfx(storageKey: 'test.mix.6').writeRaw('{"mixes":[{"n":"Good","p":"cream"},{"n":"","p":"cream"},{"n":"Bad preset","p":"nope"},5,"x",{"n":"good","p":"wood"},{"n":"Wild","p":"cream","pitch":99,"decay":-4,"cx":3,"cy":0.5}]}');
      final c = Sfx(storageKey: 'test.mix.6')..load();
      expect(c.mixes.map((m) => m.name), ['Good', 'Wild']); // empty, unknown, duplicate and junk entries are dropped
      expect(c.mixes.last.pitch, 12);
      expect(c.mixes.last.decay, 0.4);
      expect(c.mixes.last.cx, 1);
    });

    test('Reset defaults keeps the saved mixes, wipe removes them', () {
      final s = Sfx(storageKey: 'test.mix.7');
      s.saveMix('Keep me');
      s.reset();
      expect(s.mixes.length, 1);
      s.wipe();
      expect(s.mixes, isEmpty);
      final again = Sfx(storageKey: 'test.mix.7')..load();
      expect(again.mixes, isEmpty);
    });
  });

  group('my mixes in the studio', () {
    Future<Sfx> open(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final s = Sfx(storageKey: 'test.mix.ui.${DateTime.now().microsecondsSinceEpoch}');
      await tester.pumpWidget(MaterialApp(theme: buildTheme(Brightness.light), home: Scaffold(body: Center(child: SoundPill(sfx: s)))));
      await tester.tap(find.byKey(const ValueKey('sound-pill')));
      await tester.pumpAndSettle();
      return s;
    }

    testWidgets('names a sound, shows it as a chip, brings it back and deletes it', (tester) async {
      final s = await open(tester);
      expect(find.text('My mixes'), findsOneWidget);
      expect(find.textContaining('then save it here'), findsOneWidget);

      await reveal(tester, find.byKey(const ValueKey('preset-thock')));
      await tester.tap(find.byKey(const ValueKey('preset-thock')));
      await tester.pumpAndSettle();
      await reveal(tester, find.byKey(const ValueKey('mix-save-open')));
      await tester.tap(find.byKey(const ValueKey('mix-save-open')));
      await tester.pumpAndSettle();
      expect(find.text('Name this sound'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('mix-name')), 'Night shift');
      await tester.tap(find.byKey(const ValueKey('mix-save')));
      await tester.pumpAndSettle();
      expect(s.mixes.single.name, 'Night shift');
      expect(find.byKey(const ValueKey('mix-0')), findsOneWidget);

      await reveal(tester, find.byKey(const ValueKey('preset-glass')));
      await tester.tap(find.byKey(const ValueKey('preset-glass')));
      await tester.pumpAndSettle();
      expect(s.presetId, 'glass');
      await reveal(tester, find.byKey(const ValueKey('mix-0')));
      await tester.tap(find.byKey(const ValueKey('mix-0')));
      await tester.pumpAndSettle();
      expect(s.presetId, 'thock');

      await reveal(tester, find.byTooltip('Delete Night shift'));
      await tester.tap(find.byTooltip('Delete Night shift'));
      await tester.pumpAndSettle();
      expect(s.mixes, isEmpty);
      expect(find.byKey(const ValueKey('mix-0')), findsNothing);
    });

    testWidgets('Cancel saves nothing, and the button stops at the limit', (tester) async {
      final s = await open(tester);
      await tester.tap(find.byKey(const ValueKey('mix-save-open')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(s.mixes, isEmpty);

      for (var i = 0; i < Sfx.maxMixes; i++) {
        s.saveMix('Mix $i');
      }
      await tester.pumpAndSettle();
      final button = tester.widget<TextButton>(find.byKey(const ValueKey('mix-save-open')));
      expect(button.onPressed, isNull);
      expect(find.textContaining('Delete one to add another'), findsOneWidget);
    });
  });
}
