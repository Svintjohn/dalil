import 'dart:convert';

import 'package:dalil_app/cases.dart';
import 'package:dalil_app/cases_ui.dart';
import 'package:dalil_app/deadlines.dart';
import 'package:dalil_app/local_store.dart';
import 'package:dalil_app/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Report report(String docType, {String summary = 'A short summary.'}) => Report.fromJson({
      'doc_type': docType,
      'summary': summary,
      'key_facts': [
        {'label': 'Fee', 'value': 'AED 4,200'},
        {'label': '', 'value': 'ignored'},
      ],
      'next_steps': [
        {'action': 'Pay the fee', 'deadline': '5 Nov 2026'},
        {'action': 'Sign the slip'},
      ],
      'findings': [
        {'severity': 'low', 'why': 'x'},
        {'severity': 'low', 'why': 'y'},
      ],
    });

void main() {
  setUp(() => LocalStore.clearAll());

  test('a new document starts a case with a short summary only', () {
    final s = CaseStore(storageKey: 'c1');
    final id = s.addDocument(report('School fee notice'), now: DateTime(2026, 10, 16));
    expect(id, isNotNull);
    final c = s.cases.value.single;
    expect(c.title, 'School fee notice');
    expect(c.closed, isFalse);
    final e = c.entries.single;
    expect(e.isNote, isFalse);
    expect(e.date, DateTime(2026, 10, 16));
    expect(e.facts, ['Fee: AED 4,200']);
    expect(e.steps, ['Pay the fee (5 Nov 2026)', 'Sign the slip']);
    expect(e.watchCount, 2);
  });

  test('a second document goes into the chosen case and reopens it', () {
    final s = CaseStore(storageKey: 'c2');
    final id = s.addDocument(report('Fine notice'), now: DateTime(2026, 10, 1))!;
    s.setClosed(id, true);
    expect(s.cases.value.single.closed, isTrue);
    final again = s.addDocument(report('Reminder'), caseId: id, now: DateTime(2026, 10, 20));
    expect(again, id);
    expect(s.cases.value.length, 1);
    expect(s.cases.value.single.entries.length, 2);
    expect(s.cases.value.single.closed, isFalse);
    expect(s.cases.value.single.lastUpdate, DateTime(2026, 10, 20));
  });

  test('an unknown case id starts a new case instead of failing', () {
    final s = CaseStore(storageKey: 'c3');
    final id = s.addDocument(report('Bill'), caseId: 'missing', now: DateTime(2026, 10, 16));
    expect(id, isNotNull);
    expect(s.cases.value.length, 1);
  });

  test('notes are added, trimmed, and empty notes are refused', () {
    final s = CaseStore(storageKey: 'c4');
    final id = s.addDocument(report('Bill'), now: DateTime(2026, 10, 16))!;
    expect(s.addNote(id, '   ', now: DateTime(2026, 10, 17)), isFalse);
    expect(s.addNote('nope', 'x'), isFalse);
    expect(s.addNote(id, '  I paid on 5 November.  ', now: DateTime(2026, 10, 17)), isTrue);
    final note = s.cases.value.single.entries.last;
    expect(note.isNote, isTrue);
    expect(note.summary, 'I paid on 5 November.');
    s.removeEntry(id, note.id);
    expect(s.cases.value.single.entries.length, 1);
    s.removeCase(id);
    expect(s.cases.value, isEmpty);
  });

  test('cases survive a reload and damaged data is ignored', () {
    final a = CaseStore(storageKey: 'c5');
    final id = a.addDocument(report('Contract'), now: DateTime(2026, 10, 16))!;
    a.addNote(id, 'Asked the landlord', now: DateTime(2026, 10, 17));
    final b = CaseStore(storageKey: 'c5')..load();
    expect(b.cases.value.single.entries.length, 2);
    expect(b.cases.value.single.entries.last.summary, 'Asked the landlord');

    LocalStore.write('c6', '[1,2');
    expect((CaseStore(storageKey: 'c6')..load()).cases.value, isEmpty);
    LocalStore.write(
      'c7',
      jsonEncode({
        'v': 1,
        'cases': [
          5,
          {'id': 'a', 'title': '  '},
          {
            'id': 'b',
            'title': 'Good',
            'entries': [
              {'id': 'e1', 'title': 'ok', 'date': '2026-10-16'},
              {'id': 'e2', 'title': 'bad date', 'date': 'nope'},
            ],
          },
        ],
      }),
    );
    final c = (CaseStore(storageKey: 'c7')..load()).cases.value;
    expect(c.length, 1);
    expect(c.single.entries.length, 1);
  });

  test('limits stop the lists from growing without end', () {
    final s = CaseStore(storageKey: 'c8');
    for (var i = 0; i < CaseStore.maxCases; i++) {
      expect(s.addDocument(report('Doc $i'), now: DateTime(2026, 10, 16)), isNotNull);
    }
    expect(s.addDocument(report('One too many'), now: DateTime(2026, 10, 16)), isNull);
    expect(s.cases.value.length, CaseStore.maxCases);
  });

  test('long text is cut safely', () {
    final s = CaseStore(storageKey: 'c9');
    s.addDocument(report('T' * 300, summary: 'ä' * 2000), now: DateTime(2026, 10, 16));
    final c = s.cases.value.single;
    expect(c.title.length, 80);
    expect(c.entries.single.title.length, 120);
    expect(c.entries.single.summary.length, 700);
  });

  test('open cases come first, newest update on top', () {
    CaseFile f(String id, DateTime d, {bool closed = false}) =>
        CaseFile(id: id, title: id, createdOn: d, closed: closed, entries: [CaseEntry(id: 'e$id', kind: 'document', date: d, title: 't')]);
    final out = sortedCases([f('old', DateTime(2026, 9, 1)), f('closed', DateTime(2026, 10, 30), closed: true), f('new', DateTime(2026, 10, 10))]);
    expect(out.map((c) => c.id).toList(), ['new', 'old', 'closed']);
  });

  test('deadlines remember their case and can be removed with it', () {
    final d = DeadlineStore(storageKey: 'd1');
    final found = [ReportDeadline(label: 'Pay', date: '2026-11-05', dateText: '5 Nov 2026')];
    expect(d.addAll('Notice', found, now: DateTime(2026, 10, 16), caseId: 'case-1'), 1);
    expect(DeadlineStore(storageKey: 'd1').items.value, isEmpty);
    final reloaded = DeadlineStore(storageKey: 'd1')..load();
    expect(reloaded.items.value.single.caseId, 'case-1');
    d.addAll('Other', [ReportDeadline(label: 'Reply', date: '', dateText: '', withinDays: 5)], now: DateTime(2026, 10, 16));
    d.removeForCase('case-1');
    expect(d.items.value.single.label, 'Reply');
    expect(d.items.value.single.caseId, '');
  });

  testWidgets('TrackCard saves the reading and links its deadlines to the case', (tester) async {
    final cases = CaseStore(storageKey: 'w1');
    final dl = DeadlineStore(storageKey: 'w1');
    final r = Report.fromJson({
      'doc_type': 'School fee notice',
      'summary': 'Pay the fee.',
      'deadlines': [
        {'label': 'Pay the fee', 'date': '2026-11-05', 'date_text': '5 Nov 2026'},
      ],
    });
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: TrackCard(report: r, cases: cases, deadlines: dl)))));
    expect(find.text('Pay the fee'), findsOneWidget);
    await tester.ensureVisible(find.text('Save and track deadlines'));
    await tester.tap(find.text('Save and track deadlines'));
    await tester.pump();
    expect(cases.cases.value.length, 1);
    expect(dl.items.value.single.caseId, cases.cases.value.single.id);
    expect(find.text('Saved to My cases'), findsOneWidget);
  });

  group('what changed', () {
    Report withFacts(List<List<String>> facts, {int findings = 0}) => Report.fromJson({
          'summary': 's',
          'key_facts': [for (final f in facts) {'label': f[0], 'value': f[1]}],
          'findings': [for (var i = 0; i < findings; i++) {'why': 'w$i'}],
        });
    CaseEntry earlierOf(Report r) {
      final store = CaseStore(storageKey: 'test.what.changed');
      store.addDocument(r, now: DateTime(2026, 10, 1));
      return store.cases.value.first.entries.first;
    }

    test('flags a changed amount, a new fact and a missing one', () {
      final old = earlierOf(withFacts([['Amount due', 'AED 4,500'], ['Due date', '15 Nov'], ['Reference', 'A-1']]));
      final d = compareWithEntry(withFacts([['Amount due', 'AED 5,000'], ['Due date', '15 Nov'], ['Late fee', 'AED 200']]), old);
      expect(d.comparable, isTrue);
      expect(d.changed.single.label, 'Amount due');
      expect(d.changed.single.before, 'AED 4,500');
      expect(d.changed.single.after, 'AED 5,000');
      expect(d.added, ['Late fee: AED 200']);
      expect(d.removed, ['Reference: A-1']);
      expect(d.same, 1);
      expect(d.anyChange, isTrue);
    });

    test('ignores case, spacing and thousands commas, so the same fact is not reported as a change', () {
      final old = earlierOf(withFacts([['Amount due', 'AED 4,500'], ['Due date', '15 Nov']]));
      final d = compareWithEntry(withFacts([['amount due', 'aed 4500'], ['Due date', '15  nov']]), old);
      expect(d.anyChange, isFalse);
      expect(d.same, 2);
    });

    test('says it cannot compare when one side has no key facts', () {
      final old = earlierOf(withFacts([]));
      expect(compareWithEntry(withFacts([['Amount due', 'AED 1']]), old).comparable, isFalse);
      final old2 = earlierOf(withFacts([['Amount due', 'AED 1']]));
      expect(compareWithEntry(withFacts([]), old2).comparable, isFalse);
    });
  });
}
