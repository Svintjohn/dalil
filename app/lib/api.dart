import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'local_store.dart';
import 'models.dart';

abstract class DalilApi {
  Future<Meta> meta();
  Future<QualityResult> photoCheck(String imageBase64);
  Future<Report> review({
    required List<String> images,
    String? text,
    required String language,
    String? country,
    String? sampleId,
  });
  Future<AskAnswer> ask({
    required String question,
    required Map<String, dynamic> report,
    required String language,
    required List<Map<String, String>> history,
  });
  Future<Letter> letter({
    required Map<String, dynamic> report,
    required String language,
    required String recipient,
    required String note,
  });
  Future<FormHelp> form({
    required List<String> images,
    String? text,
    required String language,
    String? country,
    String? sampleId,
  });
  Future<Accuracy> accuracy();
}

class HttpDalilApi implements DalilApi {
  HttpDalilApi({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  static const String base = String.fromEnvironment('API_BASE', defaultValue: '');

  static const String token = String.fromEnvironment('DALIL_TOKEN', defaultValue: '');

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token.isNotEmpty) 'X-Dalil-Token': token,
      };

  Future<Map<String, dynamic>> _send(Future<http.Response> Function() call, {Duration timeout = const Duration(seconds: 75)}) async {
    http.Response r;
    try {
      r = await call().timeout(timeout);
    } on TimeoutException {
      throw ApiException('timeout', 'Dalil is taking longer than usual. Please try again in a minute. Your document is still here.');
    } catch (_) {
      throw ApiException('network', 'Could not reach Dalil. Check your connection and try again.');
    }
    dynamic data;
    try {
      data = jsonDecode(utf8.decode(r.bodyBytes));
    } catch (_) {
      throw ApiException('server', 'Dalil had a problem. Try again in a minute.');
    }
    if (r.statusCode >= 400) {
      final e = (data is Map && data['error'] is Map) ? Map<String, dynamic>.from(data['error'] as Map) : <String, dynamic>{};
      throw ApiException(
        (e['code'] ?? 'server').toString(),
        (e['message'] ?? 'Dalil had a problem. Try again in a minute.').toString(),
        e,
      );
    }
    if (data is! Map) throw ApiException('server', 'Dalil sent an answer the app could not read.');
    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) =>
      _send(() => _client.post(Uri.parse('$base$path'), headers: _headers, body: jsonEncode(body)));

  /// Where the page setup data (languages, samples, tips) is kept between visits. It is public data, never a document.
  static const String metaKey = 'dalil.meta.v1';

  Future<Map<String, dynamic>> _fetchMeta() async {
    final j = await _send(() => _client.get(Uri.parse('$base/api/meta'), headers: _headers), timeout: const Duration(seconds: 20));
    LocalStore.write(metaKey, jsonEncode(j));
    return j;
  }

  Future<void> _refreshMeta() async {
    try {
      await _fetchMeta();
    } catch (_) {} // the saved copy keeps working
  }

  /// The saved copy shows the page at once and is refreshed in the background, so the next visit is current.
  @override
  Future<Meta> meta() async {
    final saved = LocalStore.read(metaKey);
    if (saved != null) {
      try {
        final m = Meta.fromJson(Map<String, dynamic>.from(jsonDecode(saved) as Map));
        if (m.languages.isNotEmpty) {
          unawaited(_refreshMeta());
          return m;
        }
      } catch (_) {} // a damaged copy is ignored
    }
    return Meta.fromJson(await _fetchMeta());
  }

  @override
  Future<QualityResult> photoCheck(String imageBase64) async =>
      QualityResult.fromJson(await _post('/api/photo-check', {'image': imageBase64}));

  @override
  Future<Report> review({
    required List<String> images,
    String? text,
    required String language,
    String? country,
    String? sampleId,
  }) async {
    final body = <String, dynamic>{'images': images, 'language': language};
    if (text != null && text.trim().isNotEmpty) body['text'] = text;
    if (country != null && country.isNotEmpty) body['country'] = country;
    if (sampleId != null) body['sample_id'] = sampleId;
    return Report.fromJson(await _post('/api/review', body));
  }

  @override
  Future<AskAnswer> ask({
    required String question,
    required Map<String, dynamic> report,
    required String language,
    required List<Map<String, String>> history,
  }) async =>
      AskAnswer.fromJson(await _post('/api/ask', {'question': question, 'report': report, 'language': language, 'history': history}));

  @override
  Future<Letter> letter({
    required Map<String, dynamic> report,
    required String language,
    required String recipient,
    required String note,
  }) async =>
      Letter.fromJson(await _post('/api/letter', {'report': report, 'language': language, 'recipient': recipient, 'note': note}));

  @override
  Future<FormHelp> form({
    required List<String> images,
    String? text,
    required String language,
    String? country,
    String? sampleId,
  }) async {
    final body = <String, dynamic>{'images': images, 'language': language};
    if (text != null && text.trim().isNotEmpty) body['text'] = text;
    if (country != null && country.isNotEmpty) body['country'] = country;
    if (sampleId != null) body['sample_id'] = sampleId;
    return FormHelp.fromJson(await _post('/api/form', body));
  }

  @override
  Future<Accuracy> accuracy() async =>
      Accuracy.fromJson(await _send(() => _client.get(Uri.parse('$base/api/accuracy'), headers: _headers), timeout: const Duration(seconds: 20)));
}
