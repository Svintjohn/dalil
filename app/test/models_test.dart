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

  test('Report parser reads the prep card and ignores empty or bad prep', () {
    expect(Report.fromJson({'summary': 's'}).prep, isNull);
    expect(Report.fromJson({'summary': 's', 'prep': 'x'}).prep, isNull);
    expect(Report.fromJson({'summary': 's', 'prep': {'office': 'Somewhere'}}).prep, isNull);
    final r = Report.fromJson({
      'summary': 's',
      'prep': {
        'office': 'School accounts office',
        'authority': {'name': 'DLD', 'url': 'https://dubailand.gov.ae'},
        'bring': [
          {'item': 'The invoice', 'required': true},
          {'item': 'Your ID'},
          {'item': ''},
          'junk',
        ],
        'questions': ['Can I pay in two parts?', '', 5],
      },
    });
    final p = r.prep!;
    expect(p.office, 'School accounts office');
    expect(p.authority!.name, 'DLD');
    expect(p.bring.length, 2);
    expect(p.bring[0].required, isTrue);
    expect(p.bring[1].required, isFalse);
    expect(p.questions.first, 'Can I pay in two parts?');
  });

  test('amounts are formatted with grouping and two decimals', () {
    expect(formatAmount(0), '0.00');
    expect(formatAmount(999), '999.00');
    expect(formatAmount(1000), '1,000.00');
    expect(formatAmount(1234567.5), '1,234,567.50');
    expect(formatAmount(-2500), '-2,500.00');
  });

  test('Report parser reads the number check and drops unusable ones', () {
    expect(Report.fromJson({'summary': 's'}).numberCheck, isNull);
    expect(Report.fromJson({'summary': 's', 'number_check': 'x'}).numberCheck, isNull);
    expect(Report.fromJson({'summary': 's', 'number_check': {'status': 'ok', 'lines': []}}).numberCheck, isNull);
    // a mismatch without a stated difference is not shown as a bare warning
    expect(
      Report.fromJson({
        'summary': 's',
        'number_check': {
          'status': 'mismatch',
          'lines': [
            {'label': 'A', 'amount': 1, 'role': 'item'},
            {'label': 'T', 'amount': 2, 'role': 'total'},
          ],
          'issues': [],
        }
      }).numberCheck,
      isNull,
    );
    final r = Report.fromJson({
      'summary': 's',
      'number_check': {
        'status': 'mismatch',
        'currency': 'AED',
        'lines': [
          {'label': 'Electricity', 'amount': 320, 'role': 'item'},
          {'label': 'Total to pay', 'amount': 720.0, 'role': 'total'},
          {'label': 'bad', 'amount': 'x', 'role': 'item'},
        ],
        'issues': [
          {'code': 'total_mismatch', 'stated': 720, 'computed': 661.5, 'difference': 58.5},
        ],
      },
    });
    final n = r.numberCheck!;
    expect(n.ok, isFalse);
    expect(n.lines.length, 2);
    expect(n.money(720), 'AED 720.00');
    expect(n.issues.first.difference, 58.5);
  });

  group('amount due', () {
    test('reads a plausible amount and rejects junk', () {
      final r = Report.fromJson({
        'summary': 's',
        'due': {'amount': 720, 'currency': 'aed', 'label': 'Utility bill', 'date': '2026-12-01', 'date_text': '1 Dec 2026', 'check': true},
      });
      expect(r.due!.money, 'AED 720.00');
      expect(r.due!.check, isTrue);
      expect(r.due!.label, 'Utility bill');
      for (final bad in [null, 'AED 5', 5, {'amount': 0, 'currency': 'AED'}, {'amount': -3, 'currency': 'AED'}, {'amount': 5, 'currency': 'DIRHAM'}, {'amount': 'lots', 'currency': 'AED'}, {'amount': 5}]) {
        expect(Report.fromJson({'summary': 's', 'due': bad}).due, isNull, reason: '$bad');
      }
    });

    test('busy codes are the temporary ones', () {
      for (final c in ['model_busy', 'busy', 'rate_limited', 'timeout', 'network', 'server']) {
        expect(isBusyCode(c), isTrue, reason: c);
      }
      for (final c in ['photo_quality', 'model_unavailable', 'bad_request', 'empty']) {
        expect(isBusyCode(c), isFalse, reason: c);
      }
    });
  });
}
