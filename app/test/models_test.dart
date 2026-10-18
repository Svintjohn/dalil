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

  test('Report parser reads the scam verdict and ignores bad values', () {
    expect(Report.fromJson({'summary': 's'}).scam.shown, isFalse);
    final r = Report.fromJson({
      'summary': 's',
      'scam': {'level': 'stop', 'reasons': ['Pays to a personal account', '', 3]},
    });
    expect(r.scam.stop, isTrue);
    expect(r.scam.shown, isTrue);
    expect(r.scam.reasons.first, 'Pays to a personal account');
    expect(Report.fromJson({'summary': 's', 'scam': {'level': 'maybe'}}).scam.shown, isFalse);
    expect(Report.fromJson({'summary': 's', 'scam': 'stop'}).scam.shown, isFalse);
    expect(Report.fromJson({'summary': 's', 'scam': {'level': 'caution'}}).scam.stop, isFalse);
  });

  test('Report parser reads what happens if you do nothing', () {
    expect(Report.fromJson({'summary': 's'}).ifIgnored, isEmpty);
    final r = Report.fromJson({
      'summary': 's',
      'if_ignored': [
        {'action': 'Pay the fee', 'consequence': 'A late charge of AED 150.', 'source': 'document'},
        {
          'action': 'Register',
          'consequence': 'Not valid in a dispute.',
          'source': 'rule',
          'sources': [
            {'ref': 'AE:tenancy:x', 'statement': 'st', 'url': 'https://u.ae', 'verified_on': '2026-10-01'}
          ]
        },
        {'action': '', 'consequence': 'no action'},
        {'action': 'No consequence', 'consequence': ''},
        'junk',
      ],
    });
    expect(r.ifIgnored.length, 2);
    expect(r.ifIgnored[0].source, 'document');
    expect(r.ifIgnored[1].source, 'rule');
    expect(r.ifIgnored[1].sources.first.url, 'https://u.ae');
    expect(Report.fromJson({'summary': 's', 'if_ignored': 'x'}).ifIgnored, isEmpty);
  });
}
