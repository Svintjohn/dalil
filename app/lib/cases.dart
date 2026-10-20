import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'deadlines.dart';
import 'local_store.dart';
import 'models.dart';

String _cap(String s, int n) {
  final t = s.trim();
  final runes = t.runes.toList();
  return runes.length <= n ? t : String.fromCharCodes(runes.take(n));
}

List<String> _strings(dynamic v, int maxItems, int maxLen) {
  if (v is! List) return const [];
  final out = <String>[];
  for (final e in v) {
    if (e is String && e.trim().isNotEmpty && out.length < maxItems) out.add(_cap(e, maxLen));
  }
  return out;
}

/// The key facts of a reading as "label: value" lines, the same way they are kept in a case (at most six).
List<String> _factStrings(Report r) {
  final out = <String>[];
  for (final k in r.keyFacts) {
    if (k.label.trim().isNotEmpty && k.value.trim().isNotEmpty && out.length < 6) out.add(_cap('${k.label}: ${k.value}', 200));
  }
  return out;
}

(String, String) _splitFact(String f) {
  final i = f.indexOf(': ');
  return i < 0 ? (f.trim(), '') : (f.substring(0, i).trim(), f.substring(i + 2).trim());
}

String _norm(String s) => s.toLowerCase().replaceAll(RegExp(r'[\s,]+'), '');

class FactChange {
  const FactChange(this.label, this.before, this.after);
  final String label, before, after;
}

/// How a new reading differs from an earlier document in the same case. Only the key facts (amounts, dates,
/// names) are compared, by their label, so Dalil never guesses what a change means.
class WhatChanged {
  const WhatChanged({required this.comparable, this.changed = const [], this.added = const [], this.removed = const [], this.same = 0, this.watchBefore = 0, this.watchAfter = 0});
  final bool comparable; // false when either side has no key facts to compare
  final List<FactChange> changed;
  final List<String> added, removed; // "label: value" lines
  final int same, watchBefore, watchAfter;

  bool get anyChange => changed.isNotEmpty || added.isNotEmpty || removed.isNotEmpty;
}

WhatChanged compareWithEntry(Report r, CaseEntry prev) {
  final now = _factStrings(r).map(_splitFact).toList();
  final before = prev.facts.map(_splitFact).toList();
  if (now.isEmpty || before.isEmpty) return const WhatChanged(comparable: false);
  final beforeBy = {for (final f in before) _norm(f.$1): f};
  final nowBy = {for (final f in now) _norm(f.$1): f};
  final changed = <FactChange>[];
  final added = <String>[];
  var same = 0;
  for (final f in now) {
    final old = beforeBy[_norm(f.$1)];
    if (old == null) {
      added.add('${f.$1}: ${f.$2}');
    } else if (_norm(old.$2) == _norm(f.$2)) {
      same++;
    } else {
      changed.add(FactChange(f.$1, old.$2, f.$2));
    }
  }
  final removed = [for (final f in before) if (!nowBy.containsKey(_norm(f.$1))) '${f.$1}: ${f.$2}'];
  return WhatChanged(comparable: true, changed: changed, added: added, removed: removed, same: same, watchBefore: prev.watchCount, watchAfter: r.findings.length);
}

/// One thing that happened in a case: a document Dalil read, or a note the person wrote.
class CaseEntry {
  CaseEntry({
    required this.id,
    required this.kind,
    required this.date,
    required this.title,
    this.summary = '',
    this.steps = const [],
    this.facts = const [],
    this.watchCount = 0,
    this.due,
    this.paid = false,
  });

  final String id, kind, title, summary; // kind is 'document' or 'note'
  final DateTime date;
  final List<String> steps, facts;
  final int watchCount;
  final DueAmount? due; // the amount this document asks to pay, if any
  final bool paid; // the person marked it as paid

  CaseEntry withPaid(bool value) => CaseEntry(id: id, kind: kind, date: date, title: title, summary: summary, steps: steps, facts: facts, watchCount: watchCount, due: due, paid: value);

  bool get isNote => kind == 'note';

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind,
        'date': isoDate(date),
        'title': title,
        'summary': summary,
        'steps': steps,
        'facts': facts,
        'watch': watchCount,
        if (due != null)
          'due': {'amount': due!.amount, 'currency': due!.currency, 'label': due!.label, 'date': due!.date, 'date_text': due!.dateText, 'check': due!.check},
        if (paid) 'paid': true,
      };

  static CaseEntry? fromJson(dynamic j) {
    if (j is! Map) return null;
    final id = j['id'];
    final title = j['title'];
    if (id is! String || title is! String) return null;
    final date = parseIsoDate(j['date'] is String ? j['date'] as String : '');
    if (date == null) return null;
    return CaseEntry(
      id: id,
      kind: j['kind'] == 'note' ? 'note' : 'document',
      date: date,
      title: _cap(title, 120),
      summary: j['summary'] is String ? _cap(j['summary'] as String, 700) : '',
      steps: _strings(j['steps'], 4, 300),
      facts: _strings(j['facts'], 6, 200),
      watchCount: j['watch'] is int ? j['watch'] as int : 0,
      due: DueAmount.fromJson(j['due']),
      paid: j['paid'] == true,
    );
  }
}

/// A case groups the documents and notes about one matter, oldest first.
class CaseFile {
  CaseFile({required this.id, required this.title, required this.createdOn, this.closed = false, this.entries = const []});

  final String id, title;
  final DateTime createdOn;
  final bool closed;
  final List<CaseEntry> entries;

  DateTime get lastUpdate => entries.isEmpty ? createdOn : entries.last.date;

  CaseFile copyWith({bool? closed, List<CaseEntry>? entries}) =>
      CaseFile(id: id, title: title, createdOn: createdOn, closed: closed ?? this.closed, entries: entries ?? this.entries);

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'created': isoDate(createdOn),
        'closed': closed,
        'entries': entries.map((e) => e.toJson()).toList(),
      };

  static CaseFile? fromJson(dynamic j) {
    if (j is! Map) return null;
    final id = j['id'];
    final title = j['title'];
    if (id is! String || title is! String || title.trim().isEmpty) return null;
    final entries = <CaseEntry>[];
    final raw = j['entries'];
    if (raw is List) {
      for (final e in raw) {
        final entry = CaseEntry.fromJson(e);
        if (entry != null) entries.add(entry);
      }
    }
    return CaseFile(
      id: id,
      title: _cap(title, 80),
      createdOn: parseIsoDate(j['created'] is String ? j['created'] as String : '') ?? dateOnly(DateTime.now()),
      closed: j['closed'] == true,
      entries: entries,
    );
  }
}

/// The person's cases, kept in the browser on this device only. Only a short summary of each
/// document is kept. The photos and the full text are never saved.
class CaseStore {
  CaseStore({this.storageKey = 'dalil.cases.v1'});

  static final CaseStore instance = CaseStore();
  static const maxCases = 50;
  static const maxEntries = 100;

  final String storageKey;
  final ValueNotifier<List<CaseFile>> cases = ValueNotifier<List<CaseFile>>(const []);
  int _counter = 0;

  void load() {
    final raw = LocalStore.read(storageKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final data = jsonDecode(raw);
      final list = data is Map ? data['cases'] : null;
      if (list is! List) return;
      final loaded = <CaseFile>[];
      for (final e in list) {
        final c = CaseFile.fromJson(e);
        if (c != null) loaded.add(c);
      }
      cases.value = loaded;
    } catch (_) {
      // a damaged value is ignored, the list simply starts empty
    }
  }

  /// Deletes every saved case from this device.
  void clearAll() {
    cases.value = const [];
    LocalStore.remove(storageKey);
  }

  void _commit(List<CaseFile> next) {
    cases.value = next;
    LocalStore.write(storageKey, jsonEncode({'v': 1, 'cases': next.map((c) => c.toJson()).toList()}));
  }

  String _newId(DateTime now) => '${now.microsecondsSinceEpoch}-${_counter++}';

  /// Saves a short summary of a reading. With no [caseId] (or an unknown one) it starts a new case.
  /// Returns the id of the case it went into, or null when a limit was reached.
  String? addDocument(Report r, {String? caseId, DateTime? now}) {
    final t = now ?? DateTime.now();
    final facts = _factStrings(r);
    final steps = <String>[];
    for (final s in r.nextSteps) {
      if (s.action.trim().isNotEmpty && steps.length < 4) steps.add(s.deadline.trim().isEmpty ? s.action : '${s.action} (${s.deadline})');
    }
    final title = r.docType.trim().isEmpty ? 'Document' : r.docType;
    final entry = CaseEntry(
      id: _newId(t),
      kind: 'document',
      date: dateOnly(t),
      title: _cap(title, 120),
      summary: _cap(r.summary, 700),
      steps: [for (final s in steps) _cap(s, 300)],
      facts: [for (final f in facts) _cap(f, 200)],
      watchCount: r.findings.length,
      due: r.due,
    );
    final list = [...cases.value];
    final at = caseId == null ? -1 : list.indexWhere((c) => c.id == caseId);
    if (at >= 0) {
      if (list[at].entries.length >= maxEntries) return null;
      list[at] = list[at].copyWith(closed: false, entries: [...list[at].entries, entry]);
      _commit(list);
      return list[at].id;
    }
    if (list.length >= maxCases) return null;
    final created = CaseFile(id: _newId(t), title: _cap(title, 80), createdOn: dateOnly(t), entries: [entry]);
    list.add(created);
    _commit(list);
    return created.id;
  }

  /// Adds something the person did or learned, such as "I paid on 5 November".
  bool addNote(String caseId, String text, {DateTime? now}) {
    final body = _cap(text, 500);
    if (body.isEmpty) return false;
    final t = now ?? DateTime.now();
    final list = [...cases.value];
    final at = list.indexWhere((c) => c.id == caseId);
    if (at < 0 || list[at].entries.length >= maxEntries) return false;
    final entry = CaseEntry(id: _newId(t), kind: 'note', date: dateOnly(t), title: 'Your note', summary: body);
    list[at] = list[at].copyWith(entries: [...list[at].entries, entry]);
    _commit(list);
    return true;
  }

  /// Marks the amount in one entry as paid (or not paid), so it leaves (or returns to) the money due total.
  void setPaid(String caseId, String entryId, bool paid) => _commit([
        for (final c in cases.value)
          if (c.id == caseId) c.copyWith(entries: [for (final e in c.entries) e.id == entryId ? e.withPaid(paid) : e]) else c,
      ]);

  void setClosed(String caseId, bool closed) => _commit([for (final c in cases.value) c.id == caseId ? c.copyWith(closed: closed) : c]);

  void removeEntry(String caseId, String entryId) => _commit([
        for (final c in cases.value)
          if (c.id == caseId) c.copyWith(entries: [for (final e in c.entries) if (e.id != entryId) e]) else c,
      ]);

  void removeCase(String caseId) => _commit([for (final c in cases.value) if (c.id != caseId) c]);
}

/// Open cases first, most recently updated on top. Closed cases go last.
List<CaseFile> sortedCases(List<CaseFile> list) {
  final out = [...list];
  out.sort((a, b) {
    if (a.closed != b.closed) return a.closed ? 1 : -1;
    final byDate = b.lastUpdate.compareTo(a.lastUpdate);
    return byDate != 0 ? byDate : b.id.compareTo(a.id);
  });
  return out;
}

/// One amount that still has to be paid, with the case it belongs to.
class MoneyDueItem {
  const MoneyDueItem({required this.caseId, required this.caseTitle, required this.entryId, required this.due, required this.paid});
  final String caseId, caseTitle, entryId;
  final DueAmount due;
  final bool paid;
}

/// The amounts to pay across open cases. To avoid counting a bill twice, only the latest document with an amount in each
/// case counts (a reminder replaces the first bill). Items marked as paid stay in the list but are not in the totals.
class MoneyDue {
  const MoneyDue({required this.items});
  final List<MoneyDueItem> items;

  List<MoneyDueItem> get unpaid => [for (final i in items) if (!i.paid) i];

  /// Currency code -> total still to pay. Different currencies are never added together.
  Map<String, double> get totals {
    final out = <String, double>{};
    for (final i in unpaid) {
      out[i.due.currency] = (out[i.due.currency] ?? 0) + i.due.amount;
    }
    return out;
  }

  bool get isEmpty => items.isEmpty;
}

MoneyDue moneyDue(List<CaseFile> all) {
  final items = <MoneyDueItem>[];
  for (final c in all) {
    if (c.closed) continue;
    CaseEntry? latest;
    for (final e in c.entries) {
      if (!e.isNote && e.due != null) latest = e;
    }
    if (latest != null) items.add(MoneyDueItem(caseId: c.id, caseTitle: c.title, entryId: latest.id, due: latest.due!, paid: latest.paid));
  }
  // soonest date first; amounts with no date last
  items.sort((a, b) {
    final x = a.due.date.isEmpty ? '9999' : a.due.date;
    final y = b.due.date.isEmpty ? '9999' : b.due.date;
    final c = x.compareTo(y);
    return c != 0 ? c : a.caseTitle.compareTo(b.caseTitle);
  });
  return MoneyDue(items: items);
}
