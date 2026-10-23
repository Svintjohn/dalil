import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

abstract class Speaker {
  Future<bool> speak(String text, String languageCode, {void Function()? onDone});
  Future<void> stop();
}

class TtsSpeaker implements Speaker {
  FlutterTts? _tts;
  List<Map<String, String>>? _voices;

  static const _locales = {
    'zh-Hans': 'zh-CN',
    'zh-Hant': 'zh-TW',
    'tl': 'fil-PH',
    'en': 'en-US',
    'ko': 'ko-KR',
    'ja': 'ja-JP',
    'ar': 'ar-SA',
    'hi': 'hi-IN',
    'bn': 'bn-BD',
    'ur': 'ur-PK',
    'ta': 'ta-IN',
    'te': 'te-IN',
    'ml': 'ml-IN',
    'ne': 'ne-NP',
    'th': 'th-TH',
    'vi': 'vi-VN',
    'id': 'id-ID',
    'ms': 'ms-MY',
    'es': 'es-ES',
    'fr': 'fr-FR',
    'de': 'de-DE',
    'it': 'it-IT',
    'pt': 'pt-PT',
    'ru': 'ru-RU',
    'tr': 'tr-TR',
    'fa': 'fa-IR',
    'he': 'he-IL',
    'si': 'si-LK',
  };

  static String _tag(String code) => _locales[code] ?? code;

  Future<List<Map<String, String>>> _loadVoices(FlutterTts tts) async {
    final cached = _voices;
    if (cached != null && cached.isNotEmpty) return cached;
    for (var i = 0; i < 4; i++) {
      try {
        final raw = await tts.getVoices;
        if (raw is List && raw.isNotEmpty) {
          return _voices = [
            for (final v in raw)
              if (v is Map) {for (final e in v.entries) '${e.key}': '${e.value}'},
          ];
        }
      } catch (_) {}
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    return const [];
  }

  Map<String, String>? _pickVoice(List<Map<String, String>> voices, String code) {
    final wanted = _tag(code).toLowerCase().replaceAll('_', '-');
    final base = wanted.split('-').first;
    Map<String, String>? sameBase;
    for (final v in voices) {
      final loc = (v['locale'] ?? '').toLowerCase().replaceAll('_', '-');
      if (loc == wanted) return v;
      if (sameBase == null && loc.split('-').first == base) sameBase = v;
    }
    return sameBase;
  }

  @override
  Future<bool> speak(String text, String languageCode, {void Function()? onDone}) async {
    try {
      final tts = _tts ??= FlutterTts();
      await tts.stop();
      final voices = await _loadVoices(tts);
      final voice = _pickVoice(voices, languageCode);
      if (voices.isNotEmpty && voice == null) return false;
      await tts.setLanguage(voice?['locale'] ?? _tag(languageCode));
      if (voice != null && voice['name'] != null) {
        await tts.setVoice({'name': voice['name']!, 'locale': voice['locale'] ?? _tag(languageCode)});
      }
      await tts.setSpeechRate(0.45);
      tts.setCompletionHandler(() => onDone?.call());
      tts.setCancelHandler(() => onDone?.call());
      tts.setErrorHandler((_) => onDone?.call());
      await tts.speak(text);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _tts?.stop();
    } catch (_) {}
  }
}

abstract class Dictation {
  Future<bool> start(String languageCode, {required void Function(String text) onText, required void Function() onEnd});
  Future<void> stop();
}

class SpeechDictation implements Dictation {
  final stt.SpeechToText _stt = stt.SpeechToText();
  bool _ready = false;
  void Function()? _onEnd;

  static String _tag(String code) {
    switch (code) {
      case 'zh-Hans':
        return 'zh-CN';
      case 'zh-Hant':
        return 'zh-TW';
      case 'tl':
        return 'fil-PH';
      default:
        return code;
    }
  }

  @override
  Future<bool> start(String languageCode, {required void Function(String text) onText, required void Function() onEnd}) async {
    try {
      _onEnd = onEnd;
      if (!_ready) {
        _ready = await _stt.initialize(
          onStatus: (s) {
            if (s == 'done' || s == 'notListening') _onEnd?.call();
          },
          onError: (_) => _onEnd?.call(),
        );
      }
      if (!_ready) return false;
      await _stt.listen(
        listenOptions: stt.SpeechListenOptions(partialResults: true, cancelOnError: true, localeId: _tag(languageCode)),
        onResult: (r) => onText(r.recognizedWords),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _stt.stop();
    } catch (_) {}
  }
}
