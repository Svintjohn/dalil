import 'dart:io';

import 'package:dalil_app/fonts.dart';
import 'package:dalil_app/motion.dart';
import 'package:dalil_app/sfx.dart';
import 'package:dalil_app/sound_pill.dart';
import 'package:dalil_app/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  group('sound presets', () {
    test('ids are unique, grouped, and placed inside the matrix', () {
      final ids = sfxPresets.map((p) => p.id).toList();
      expect(ids.toSet().length, ids.length);
      for (final p in sfxPresets) {
        expect(sfxGroups, contains(p.group), reason: p.id);
        expect(p.x, inInclusiveRange(0, 1), reason: p.id);
        expect(p.y, inInclusiveRange(0, 1), reason: p.id);
        expect(p.name.trim(), isNotEmpty);
      }
      for (final g in sfxGroups) {
        expect(sfxPresets.any((p) => p.group == g), isTrue, reason: g);
      }
    });

    test('every preset and ambient sound exists in the engine script', () {
      final js = File('web/dalil_sfx.js').readAsStringSync();
      for (final p in sfxPresets) {
        expect(js.contains('    ${p.id}: ['), isTrue, reason: 'missing preset ${p.id} in dalil_sfx.js');
      }
      for (final a in ambientSounds) {
        expect(js.contains("id === '${a.id}'"), isTrue, reason: 'missing ambient ${a.id} in dalil_sfx.js');
      }
    });
  });

  group('Sfx settings', () {
    test('sound is off by default and sounds do nothing while off', () {
      final s = Sfx(storageKey: 'test.sfx.default');
      expect(s.enabled, isFalse);
      s.tap();
      s.key(LogicalKeyboardKey.keyA);
      s.event('done');
      expect(s.ambient, isEmpty);
    });

    test('settings are saved and loaded again', () {
      final a = Sfx(storageKey: 'test.sfx.roundtrip');
      a.setEnabled(true);
      a.setVolume(0.3);
      a.selectPreset('thock');
      a.movePuck(0.2, 0.9);
      a.setTune(pitch: 3, decay: 1.5, reverb: 0.4);
      a.setToggles(typing: false);
      final b = Sfx(storageKey: 'test.sfx.roundtrip')..load();
      expect(b.enabled, isTrue);
      expect(b.volume, closeTo(0.3, 1e-9));
      expect(b.presetId, 'thock');
      expect(b.customX, closeTo(0.2, 1e-9));
      expect(b.customY, closeTo(0.9, 1e-9));
      expect(b.pitch, 3);
      expect(b.decay, 1.5);
      expect(b.reverb, 0.4);
      expect(b.typing, isFalse);
      expect(b.clicks, isTrue);
    });

    test('damaged or odd saved data falls back to safe values', () {
      for (final raw in ['not json', '[]', '{"vol": "loud", "preset": "nope", "pitch": 99, "cx": 0.5}']) {
        LocalStoreHelper.put('test.sfx.bad', raw);
        final s = Sfx(storageKey: 'test.sfx.bad')..load();
        expect(s.presetId, 'cream', reason: raw);
        expect(s.volume, inInclusiveRange(0, 1));
        expect(s.pitch, inInclusiveRange(-12, 12));
        expect(s.customX, isNull, reason: 'a lone x without y is ignored');
      }
    });

    test('values are kept in range', () {
      final s = Sfx(storageKey: 'test.sfx.range');
      s.setVolume(7);
      s.setTune(pitch: -50, decay: 0, bright: 5, reverb: -1, human: 9, pan: 9);
      s.movePuck(-3, 4);
      expect(s.volume, 1);
      expect(s.pitch, -12);
      expect(s.decay, 0.4);
      expect(s.bright, 1);
      expect(s.reverb, 0);
      expect(s.human, 1);
      expect(s.customX, 0);
      expect(s.customY, 1);
    });

    test('ambient sounds turn the sound on, and turning it off stops them', () {
      final s = Sfx(storageKey: 'test.sfx.ambient');
      s.toggleAmbient('rain');
      expect(s.enabled, isTrue);
      expect(s.ambient, {'rain'});
      s.toggleAmbient('rain');
      expect(s.ambient, isEmpty);
      s.toggleAmbient('wind');
      s.toggleAmbient('nonsense');
      expect(s.ambient, {'wind'});
      s.setEnabled(false);
      expect(s.ambient, isEmpty);
    });

    test('reset restores the defaults but leaves the sound switch alone', () {
      final s = Sfx(storageKey: 'test.sfx.reset');
      s.setEnabled(true);
      s.selectPreset('blue');
      s.setTune(pitch: 5);
      s.reset();
      expect(s.presetId, 'cream');
      expect(s.pitch, 0);
      expect(s.enabled, isTrue);
    });
  });

  group('sound studio', () {
    Future<Sfx> open(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final s = Sfx(storageKey: 'test.sfx.ui.${DateTime.now().microsecondsSinceEpoch}');
      await tester.pumpWidget(MaterialApp(theme: buildTheme(Brightness.light), home: Scaffold(body: Center(child: SoundPill(sfx: s)))));
      await tester.tap(find.byKey(const ValueKey('sound-pill')));
      await tester.pumpAndSettle();
      return s;
    }

    testWidgets('opens from the pill, turns on, and picks a sound', (tester) async {
      final s = await open(tester);
      expect(find.text('Sound studio'), findsOneWidget);
      expect(find.text('Sound off'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('sfx-master')));
      await tester.pumpAndSettle();
      expect(s.enabled, isTrue);
      expect(find.text('Sound on'), findsOneWidget);
      await reveal(tester, find.byKey(const ValueKey('preset-thock')));
      await tester.tap(find.byKey(const ValueKey('preset-thock')));
      await tester.pumpAndSettle();
      expect(s.presetId, 'thock');
    });

    testWidgets('the matrix picks a preset by its dot and mixes by dragging', (tester) async {
      final s = await open(tester);
      await tester.tap(find.text('Matrix'));
      await tester.pumpAndSettle();
      final pad = find.byKey(const ValueKey('matrix-pad'));
      expect(pad, findsOneWidget);
      final box = tester.getRect(pad);
      // the "Deep thock" dot
      final t = sfxPresets.firstWhere((p) => p.id == 'thock');
      await tester.tapAt(Offset(box.left + 18 + t.x * (box.width - 36), box.top + 18 + (1 - t.y) * (box.height - 36)));
      await tester.pumpAndSettle();
      expect(s.presetId, 'thock');
      expect(s.customX, isNull);
      await tester.dragFrom(box.center, const Offset(60, -40));
      await tester.pumpAndSettle();
      expect(s.customX, isNotNull);
      expect(find.textContaining('mixed'), findsOneWidget);
    });

    testWidgets('ambient tiles and tuning switches work', (tester) async {
      final s = await open(tester);
      await tester.tap(find.text('Ambient'));
      await tester.pumpAndSettle();
      await reveal(tester, find.byKey(const ValueKey('ambient-rain')));
      await tester.tap(find.byKey(const ValueKey('ambient-rain')));
      await tester.pumpAndSettle();
      expect(s.ambient, {'rain'});
      expect(s.enabled, isTrue);

      await tester.tap(find.text('Tuning'));
      await tester.pumpAndSettle();
      await reveal(tester, find.byKey(const ValueKey('sfx-typing')));
      await tester.tap(find.byKey(const ValueKey('sfx-typing')));
      await tester.pumpAndSettle();
      expect(s.typing, isFalse);
      await reveal(tester, find.byKey(const ValueKey('sfx-test')));
      await tester.tap(find.byKey(const ValueKey('sfx-test')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('sfx-reset')));
      await tester.pumpAndSettle();
      expect(s.typing, isTrue);
      expect(s.ambient, isEmpty);
    });
  });
}

/// Writes a raw value where [Sfx] reads its settings from.
class LocalStoreHelper {
  static void put(String key, String value) => Sfx(storageKey: key).writeRaw(value);
}
