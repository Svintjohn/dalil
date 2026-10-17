import 'package:dalil_app/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Report parser survives missing fields', () {
    final r = Report.fromJson({'summary': 'Hello'});
    expect(r.summary, 'Hello');
    expect(r.findings, isEmpty);
    expect(r.recognized, isTrue);
    expect(r.label('high', 'High risk'), 'High risk');
  });

  test('Report parser reads findings, sources and authority', () {
    final r = Report.fromJson({
      'summary': 's',
      'labels': {'high': 'Alto'},
      'findings': [
        {
          'severity': 'high',
          'why': 'w',
          'verified': true,
          'sources': [
            {'ref': 'AE:tenancy:x', 'statement': 'st', 'url': 'https://u.ae', 'verified_on': '2026-10-01'}
          ]
        }
      ],
      'next_steps': [
        {'action': 'Call', 'authority': {'name': 'DLD', 'url': 'https://dubailand.gov.ae'}}
      ],
      'privacy': {'hidden_total': 2},
    });
    expect(r.label('high', 'x'), 'Alto');
    expect(r.findings.single.sources.single.verifiedOn, '2026-10-01');
    expect(r.nextSteps.single.authority!.name, 'DLD');
    expect(r.hiddenTotal, 2);
  });

  test('Meta parser uses defaults', () {
    final m = Meta.fromJson({});
    expect(m.maxImages, 6);
    expect(m.languages, isEmpty);
  });
}
