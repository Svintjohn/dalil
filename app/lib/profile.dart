import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'fonts.dart';
import 'local_store.dart';

/// The colour the app uses for buttons, links and highlights.
enum Accent { teal, terracotta, indigo, rose, custom }

/// The four ready-made colours. [Accent.custom] comes from the colour wheel.
const presetAccents = <Accent>[Accent.teal, Accent.terracotta, Accent.indigo, Accent.rose];

String accentLabel(Accent a) {
  switch (a) {
    case Accent.teal:
      return 'Teal';
    case Accent.terracotta:
      return 'Terracotta';
    case Accent.indigo:
      return 'Indigo';
    case Accent.rose:
      return 'Rose';
    case Accent.custom:
      return 'Custom';
  }
}

Accent? accentByName(Object? name) {
  if (name is! String) return null;
  for (final a in Accent.values) {
    if (a.name == name) return a;
  }
  return null;
}

/// A name for the greeting: no line breaks or control characters, one space between words, at most 24 characters.
String cleanName(String raw) {
  final t = raw.replaceAll(RegExp(r'[\u0000-\u001F\u007F<>]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  final runes = t.runes.toList();
  if (runes.length <= 24) return t;
  return String.fromCharCodes(runes.take(24)).trimRight();
}

enum DayPart { morning, noon, afternoon, evening, night }

DayPart dayPartOf(DateTime t) {
  final h = t.hour;
  if (h >= 5 && h < 12) return DayPart.morning;
  if (h == 12) return DayPart.noon;
  if (h >= 13 && h < 18) return DayPart.afternoon;
  if (h >= 18) return DayPart.evening;
  return DayPart.night;
}

// morning, noon, afternoon, evening, night
const _greetings = <String, List<String>>{
  'en': ['Good morning', 'Good afternoon', 'Good afternoon', 'Good evening', 'Hello'],
  'tl': ['Magandang umaga', 'Magandang tanghali', 'Magandang hapon', 'Magandang gabi', 'Magandang gabi'],
  'ar': ['صباح الخير', 'أهلاً', 'أهلاً', 'مساء الخير', 'مساء الخير'],
  'hi': ['सुप्रभात', 'नमस्ते', 'नमस्ते', 'शुभ संध्या', 'नमस्ते'],
  'ur': ['صبح بخیر', 'السلام علیکم', 'السلام علیکم', 'شام بخیر', 'السلام علیکم'],
  'bn': ['শুভ সকাল', 'শুভ দুপুর', 'শুভ অপরাহ্ন', 'শুভ সন্ধ্যা', 'শুভ সন্ধ্যা'],
  'ne': ['शुभ प्रभात', 'नमस्ते', 'नमस्ते', 'शुभ सन्ध्या', 'नमस्ते'],
  'fr': ['Bonjour', 'Bonjour', 'Bonjour', 'Bonsoir', 'Bonsoir'],
  'es': ['Buenos días', 'Buenas tardes', 'Buenas tardes', 'Buenas noches', 'Buenas noches'],
  'de': ['Guten Morgen', 'Guten Tag', 'Guten Tag', 'Guten Abend', 'Hallo'],
};

/// A greeting in the person's language for the time of day. Languages without a greeting here use English.
String greetingFor(String languageCode, DateTime now) {
  final list = _greetings[languageCode] ?? _greetings['en']!;
  return list[dayPartOf(now).index];
}

/// What the person told us about themselves, kept in the browser on this device only. Nothing is sent anywhere.
class Profile extends ChangeNotifier {
  Profile({String storageKey = 'dalil.profile.v1'}) : _key = storageKey;
  static final Profile instance = Profile();

  final String _key;

  String name = '';
  bool asked = false; // the name was asked for once (saved or skipped), so it is not asked again
  Accent accent = Accent.teal;
  double customHue = 200; // from the colour wheel, 0 to 360
  double customSat = 0.55; // how strong that colour is
  bool easyRead = false;

  /// Changes only when the colours or the font change, so the whole app does not rebuild while a name is typed.
  final ValueNotifier<String> look = ValueNotifier<String>('teal|false');

  bool get hasName => name.isNotEmpty;
  bool get shouldAsk => !asked && name.isEmpty;

  void _syncLook() {
    Fonts.easy = easyRead;
    look.value = '${accent.name}|$easyRead${accent == Accent.custom ? '|${customHue.round()}|${(customSat * 100).round()}' : ''}';
  }

  void load() {
    try {
      final raw = LocalStore.read(_key);
      if (raw != null) {
        final j = jsonDecode(raw);
        if (j is Map) {
          name = cleanName(j['name'] is String ? j['name'] as String : '');
          asked = j['asked'] == true || name.isNotEmpty;
          accent = accentByName(j['accent']) ?? Accent.teal;
          customHue = j['hue'] is num && (j['hue'] as num).isFinite ? ((j['hue'] as num).toDouble() % 360 + 360) % 360 : 200;
          customSat = j['sat'] is num && (j['sat'] as num).isFinite ? (j['sat'] as num).toDouble().clamp(0.15, 0.95).toDouble() : 0.55;
          easyRead = j['easy'] == true;
        }
      }
    } catch (_) {}
    _syncLook();
    notifyListeners();
  }

  /// Used by tests to plant saved data.
  @visibleForTesting
  void writeRaw(String value) => LocalStore.write(_key, value);

  void _save() {
    LocalStore.write(_key, jsonEncode({'name': name, 'asked': asked, 'accent': accent.name, 'hue': customHue, 'sat': customSat, 'easy': easyRead}));
  }

  void setName(String raw) {
    name = cleanName(raw);
    asked = true;
    _save();
    notifyListeners();
  }

  /// "Not now": the name is not asked for again.
  void skipAsking() {
    asked = true;
    _save();
    notifyListeners();
  }

  void setAccent(Accent a) {
    accent = a;
    _save();
    _syncLook();
    notifyListeners();
  }

  /// A colour picked on the wheel: [hue] 0 to 360, [sat] how strong it is. The app picks the lightness so text stays readable.
  void setCustom(double hue, double sat) {
    customHue = ((hue % 360) + 360) % 360;
    customSat = sat.clamp(0.15, 0.95).toDouble();
    accent = Accent.custom;
    _save();
    _syncLook();
    notifyListeners();
  }

  void setEasyRead(bool on) {
    easyRead = on;
    _save();
    _syncLook();
    notifyListeners();
  }

  /// Forgets everything: no name, the default colour and font, nothing left in the browser.
  void wipe() {
    name = '';
    asked = false;
    accent = Accent.teal;
    customHue = 200;
    customSat = 0.55;
    easyRead = false;
    LocalStore.remove(_key);
    _syncLook();
    notifyListeners();
  }
}
