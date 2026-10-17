import 'dart:convert';

import 'package:dalil_app/deadlines.dart';
import 'package:dalil_app/local_store.dart';
import 'package:dalil_app/models.dart';
import 'package:flutter_test/flutter_test.dart';

ReportDeadline dl(String label, {String date = '', String text = '', int? days}) =>
    ReportDeadline(label: label, date: date, dateText: text, withinDays: days);

void main() {
  setUp(() => LocalStore.clearAll());

  test('parseIsoDate accepts real dates only', () {
    expect(parseIsoDate('2026-11-05'), DateTime(2026, 11, 5));
    expect(parseIsoDate('2026-02-30'), isNull);
    expect(parseIsoDate('2026-13-01'), isNull);
    expect(parseIsoDate('5 Nov 2026'), isNull);
    expect(parseIsoDate(''), isNull);
  });

  test('daysBetween counts calendar days', () {
    expect(daysBetween(DateTime(2026, 10, 16, 23, 59), DateTime(2026, 10, 17)), 1);
    expect(daysBetween(DateTime(2026, 10, 16), DateTime(2026, 10, 16)), 0);
    expect(daysBetween(DateTime(2026, 10, 16), DateTime(2026, 10, 14)), -2);
    expect(daysBetween(DateTime(2026, 12, 31), DateTime(2027, 1, 1)), 1);
  });

  test('Report parser reads deadlines and drops ones without a label', () {
    final r = Report.fromJson({
      'summary': 's',
      'deadlines': [
        {'label': 'Pay', 'date': '2026-11-05', 'date_text': '5 Nov 2026'},
        {'label': 'Reply', 'within_days': 14},
        {'label': '  ', 'date': '2026-11-05'},
      ],
    });
    expect(r.deadlines.length, 2);
    expect(r.deadlines[1].withinDays, 14);
    expect(Report.fromJson({'summary': 's'}).deadlines, isEmpty);
  });

  test('describeDeadline says what the document said', () {
    expect(describeDeadline(dl('x', date: '2026-11-05', text: '5 November 2026')), '5 November 2026');
    expect(describeDeadline(dl('x', date: '2026-11-05')), '5 Nov 2026');
    expect(describeDeadline(dl('x', days: 14)), 'Within 14 days of receiving it');
    expect(describeDeadline(dl('x', days: 1)), 'Within 1 day of receiving it');
  });

  test('store adds, skips duplicates, marks done, sets dates and removes', () {
    final s = DeadlineStore(storageKey: 't1');
    final now = DateTime(2026, 10, 16);
    final found = [dl('Pay the fee', date: '2026-11-05', text: '5 Nov 2026'), dl('Return the slip', days: 7)];
    expect(s.addAll('School notice', found, now: now), 2);
    expect(s.addAll('School notice', found, now: now), 0);
    expect(s.items.value.length, 2);

    final slip = s.items.value.firstWhere((e) => e.label == 'Return the slip');
    expect(slip.due, isNull);
    s.setReceived(slip.id, DateTime(2026, 10, 20));
    expect(s.items.value.firstWhere((e) => e.id == slip.id).due, DateTime(2026, 10, 27));

    final pay = s.items.value.firstWhere((e) => e.label == 'Pay the fee');
    expect(pay.due, DateTime(2026, 11, 5));
    s.toggleDone(pay.id);
    expect(s.items.value.firstWhere((e) => e.id == pay.id).done, isTrue);
    s.clearDone();
    expect(s.items.value.length, 1);
    s.remove(slip.id);
    expect(s.items.value, isEmpty);
  });

  test('store keeps deadlines between visits and ignores damaged data', () {
    final a = DeadlineStore(storageKey: 't2');
    a.addAll('Notice', [dl('Pay', date: '2026-11-05')], now: DateTime(2026, 10, 16));
    final b = DeadlineStore(storageKey: 't2')..load();
    expect(b.items.value.single.label, 'Pay');
    expect(b.items.value.single.due, DateTime(2026, 11, 5));

    LocalStore.write('t3', '{not json');
    expect((DeadlineStore(storageKey: 't3')..load()).items.value, isEmpty);
    LocalStore.write('t4', jsonEncode({'v': 1, 'items': [1, 'x', {'id': 'a', 'label': 'Ok'}, {'label': 'no id'}]}));
    expect((DeadlineStore(storageKey: 't4')..load()).items.value.single.label, 'Ok');
  });

  test('status wording and order', () {
    final now = DateTime(2026, 10, 16, 15);
    TrackedDeadline t(String id, DateTime? due, {bool done = false}) =>
        TrackedDeadline(id: id, key: id, label: id, docType: '', addedOn: DateTime(2026, 10, 1), due: due, done: done);
    expect(deadlineStatus(t('a', DateTime(2026, 10, 14)), now).text, 'Overdue by 2 days');
    expect(deadlineStatus(t('a', DateTime(2026, 10, 15)), now).text, 'Overdue by 1 day');
    expect(deadlineStatus(t('a', DateTime(2026, 10, 16)), now).text, 'Today');
    expect(deadlineStatus(t('a', DateTime(2026, 10, 17)), now).text, 'Tomorrow');
    expect(deadlineStatus(t('a', DateTime(2026, 10, 20)), now).level, 'medium');
    expect(deadlineStatus(t('a', DateTime(2026, 12, 1)), now).level, 'low');
    expect(deadlineStatus(t('a', null), now).text, 'No date yet');
    expect(deadlineStatus(t('a', DateTime(2026, 10, 14), done: true), now).text, 'Done');

    final sorted = sortedForDisplay([
      t('done', DateTime(2026, 10, 1), done: true),
      t('none', null),
      t('late', DateTime(2026, 12, 1)),
      t('soon', DateTime(2026, 10, 18)),
    ]);
    expect(sorted.map((e) => e.id).toList(), ['soon', 'late', 'none', 'done']);
  });

  test('calendar file has events, reminders, escaping and short lines', () {
    final now = DateTime.utc(2026, 10, 16, 8, 30, 5);
    final open = TrackedDeadline(id: '1', key: 'k1', label: 'Pay, now; then "reply"\nplease', docType: 'Fine', addedOn: DateTime(2026, 10, 1), due: DateTime(2026, 12, 31));
    final long = TrackedDeadline(id: '2', key: 'k2', label: 'ä' * 80, docType: '', addedOn: DateTime(2026, 10, 1), due: DateTime(2026, 11, 5));
    final done = TrackedDeadline(id: '3', key: 'k3', label: 'Done one', docType: '', addedOn: DateTime(2026, 10, 1), due: DateTime(2026, 11, 6), done: true);
    final undated = TrackedDeadline(id: '4', key: 'k4', label: 'No date', docType: '', addedOn: DateTime(2026, 10, 1));
    final ics = buildIcs([open, long, done, undated], now: now);

    expect(ics.startsWith('BEGIN:VCALENDAR\r\n'), isTrue);
    expect(ics.endsWith('END:VCALENDAR\r\n'), isTrue);
    expect('BEGIN:VEVENT'.allMatches(ics).length, 2);
    expect(ics.contains('DTSTART;VALUE=DATE:20261231'), isTrue);
    expect(ics.contains('DTEND;VALUE=DATE:20270101'), isTrue);
    expect(ics.contains('DTSTAMP:20261016T083005Z'), isTrue);
    expect(ics.contains('SUMMARY:Pay\\, now\\; then "reply"\\nplease'), isTrue);
    expect(ics.contains('TRIGGER:-PT15H'), isTrue);
    expect(ics.contains('TRIGGER:-P2DT15H'), isTrue);
    expect(ics.contains('Done one'), isFalse);
    expect(ics.contains('No date'), isFalse);
    for (final line in ics.split('\r\n')) {
      expect(utf8.encode(line).length <= 75, isTrue, reason: line);
    }
  });
}
