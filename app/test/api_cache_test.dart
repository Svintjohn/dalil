import 'dart:async';
import 'dart:convert';

import 'package:dalil_app/api.dart';
import 'package:dalil_app/local_store.dart';
import 'package:dalil_app/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> _meta(String version) => {
      'version': version,
      'model_ready': true,
      'languages': [
        {'code': 'en', 'name': 'English', 'native': 'English', 'tier': 'high', 'featured': true}
      ],
      'countries': [],
      'samples': [],
    };

void main() {
  setUp(() => LocalStore.remove(HttpDalilApi.metaKey));

  test('the first visit asks the server and keeps the answer', () async {
    var calls = 0;
    final api = HttpDalilApi(client: MockClient((r) async {
      calls++;
      return http.Response(jsonEncode(_meta('v1')), 200, headers: {'content-type': 'application/json'});
    }));
    final m = await api.meta();
    expect(m.version, 'v1');
    expect(calls, 1);
    expect(LocalStore.read(HttpDalilApi.metaKey), isNotNull);
  });

  test('the next visit answers from the saved copy and refreshes it in the background', () async {
    LocalStore.write(HttpDalilApi.metaKey, jsonEncode(_meta('old')));
    final gate = Completer<void>();
    var calls = 0;
    final api = HttpDalilApi(client: MockClient((r) async {
      calls++;
      await gate.future; // the server is slow: the page must not wait for it
      return http.Response(jsonEncode(_meta('new')), 200, headers: {'content-type': 'application/json'});
    }));
    final m = await api.meta();
    expect(m.version, 'old');
    gate.complete();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(calls, 1);
    expect(jsonDecode(LocalStore.read(HttpDalilApi.metaKey)!)['version'], 'new');
    expect((await api.meta()).version, 'new');
  });

  test('a damaged or empty saved copy is ignored', () async {
    for (final bad in ['not json', '[]', jsonEncode({'languages': []})]) {
      LocalStore.write(HttpDalilApi.metaKey, bad);
      final api = HttpDalilApi(client: MockClient((r) async => http.Response(jsonEncode(_meta('fresh')), 200, headers: {'content-type': 'application/json'})));
      expect((await api.meta()).version, 'fresh', reason: bad);
    }
  });

  test('if the server is down the saved copy still lets the page open', () async {
    LocalStore.write(HttpDalilApi.metaKey, jsonEncode(_meta('kept')));
    final api = HttpDalilApi(client: MockClient((r) async => throw http.ClientException('offline')));
    expect((await api.meta()).version, 'kept');
  });

  test('with nothing saved and the server down the error is shown', () async {
    final api = HttpDalilApi(client: MockClient((r) async => throw http.ClientException('offline')));
    expect(api.meta(), throwsA(isA<ApiException>()));
  });
}