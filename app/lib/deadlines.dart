import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'local_store.dart';
import 'models.dart';

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Reads YYYY-MM-DD and returns null for anything that is not a real calendar date.
DateTime? parseIsoDate(String s) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(s.trim());
  if (m == null) return null;
  final y = int.parse(m.group(1)!);
  final mo = int.parse(m.group(2)!);
  final d = int.parse(m.group(3)!);
  final dt = DateTime(y, mo, d);
  if (dt.year != y || dt.month != mo || dt.day != d) return null;
  return dt;
}

String two(int n) => n.toString().padLeft(2, '0');

String isoDate(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${two(d.month)}-${two(d.day)}';

String fmtDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

/// Whole calendar days from [today] to [due]. Negative means it has passed.
int daysBetween(DateTime today, DateTime due) =>
    DateTime.utc(due.year, due.month, due.day).difference(DateTime.utc(today.year, today.month, today.day)).inDays;

/// A short line that tells the person what the document said about this deadline.
String describeDeadline(ReportDeadline d) {
  if (d.date.isNotEmpty) {
    final parsed = parseIsoDate(d.date);
    if (d.dateText.isNotEmpty) return d.dateText;
    return parsed == null ? d.date : fmtDate(parsed);
  }
  final n = d.withinDays;
  if (n != null) return n == 1 ? 'Within 1 day of receiving it' : 'Within $n days of receiving it';
  if (d.dateText.isNotEmpty) return '${d.dateText} (the year is not written, check it)';
  return '';
}

class TrackedDeadline {
  TrackedDeadline({
    required this.id,
    required this.key,
    required this.label,
    required this.docType,
    required this.addedOn,
    this.due,
    this.dateText = '',
    this.withinDays,
    this.done = false,
    this.caseId = '',
  });

  final String id, key, label, docType, dateText, caseId;
  final DateTime addedOn;
  final DateTime? due;
  final int? withinDays;
  final bool done;

  TrackedDeadline copyWith({DateTime? due, bool? done}) => TrackedDeadline(
        id: id,
        key: key,
        label: label,
        docType: docType,
        addedOn: addedOn,
        due: due ?? this.due,
        dateText: dateText,
        withinDays: withinDays,
        done: done ?? this.done,
        caseId: caseId,
      );

  int? daysLeft(DateTime now) => due == null ? null : daysBetween(now, due!);

  Map<String, dynamic> toJson() => {
        'id': id,
        'key': key,
        'label': label,
        'doc': docType,
        'added': isoDate(addedOn),
        'due': due == null ? '' : isoDate(due!),
        'text': dateText,
        'within': withinDays,
        'done': done,
        'case': caseId,
      };

  static TrackedDeadline? fromJson(dynamic j) {
    if (j is! Map) return null;
    final id = j['id'];
    final label = j['label'];
    if (id is! String || label is! String || label.trim().isEmpty) return null;
    final within = j['within'];
    return TrackedDeadline(
      id: id,
      key: j['key'] is String ? j['key'] as String : id,
      label: label,
      docType: j['doc'] is String ? j['doc'] as String : '',
      addedOn: parseIsoDate(j['added'] is String ? j['added'] as String : '') ?? dateOnly(DateTime.now()),
      due: parseIsoDate(j['due'] is String ? j['due'] as String : ''),
      dateText: j['text'] is String ? j['text'] as String : '',
      withinDays: within is int ? within : null,
      done: j['done'] == true,
      caseId: j['case'] is String ? j['case'] as String : '',
    );
  }
}

/// How urgent a deadline looks. [level] is one of high, medium, low, none, done.
class DeadlineStatus {
  const DeadlineStatus(this.text, this.level);
  final String text, level;
}

DeadlineStatus deadlineStatus(TrackedDeadline d, DateTime now) {
  if (d.done) return const DeadlineStatus('Done', 'done');
  final n = d.daysLeft(now);
  if (n == null) return const DeadlineStatus('No date yet', 'none');
  if (n < -1) return DeadlineStatus('Overdue by ${-n} days', 'high');
  if (n == -1) return const DeadlineStatus('Overdue by 1 day', 'high');
  if (n == 0) return const DeadlineStatus('Today', 'high');
  if (n == 1) return const DeadlineStatus('Tomorrow', 'high');
  if (n <= 7) return DeadlineStatus('In $n days', 'medium');
  return DeadlineStatus('In $n days', 'low');
}

/// Open items first (soonest on top, undated last), finished items at the bottom.
List<TrackedDeadline> sortedForDisplay(List<TrackedDeadline> list) {
  final out = [...list];
  int byDue(TrackedDeadline a, TrackedDeadline b) {
    if (a.due == null && b.due == null) return a.addedOn.compareTo(b.addedOn);
    if (a.due == null) return 1;
    if (b.due == null) return -1;
    return a.due!.compareTo(b.due!);
  }

  out.sort((a, b) {
    if (a.done != b.done) return a.done ? 1 : -1;
    return byDue(a, b);
  });
  return out;
}

String _icsText(String s) =>
    s.replaceAll('\\', '\\\\').replaceAll(';', '\\;').replaceAll(',', '\\,').replaceAll('\r\n', '\\n').replaceAll('\n', '\\n').replaceAll('\r', '');

/// Calendar lines may not be longer than 75 bytes, so longer ones continue on the next line.
String _fold(String line) {
  final out = StringBuffer();
  var bytes = 0;
  for (final r in line.runes) {
    final ch = String.fromCharCode(r);
    final n = utf8.encode(ch).length;
    if (bytes + n > 73) {
      out.write('\r\n ');
      bytes = 1;
    }
    out.write(ch);
    bytes += n;
  }
  return out.toString();
}

String _icsDay(DateTime d) => '${d.year.toString().padLeft(4, '0')}${two(d.month)}${two(d.day)}';

/// An iCalendar file with one all-day event per open, dated deadline.
/// Each event reminds at 9:00 three days before and at 9:00 the day before.
String buildIcs(List<TrackedDeadline> items, {DateTime? now}) {
  final stamp = (now ?? DateTime.now()).toUtc();
  final stampText = '${_icsDay(stamp)}T${two(stamp.hour)}${two(stamp.minute)}${two(stamp.second)}Z';
  final lines = <String>[
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//Dalil//Deadlines//EN',
    'CALSCALE:GREGORIAN',
    'METHOD:PUBLISH',
  ];
  for (final d in items) {
    final due = d.due;
    if (due == null || d.done) continue;
    final next = DateTime(due.year, due.month, due.day + 1);
    final note = d.docType.isEmpty ? 'Added by Dalil. Check your document before you act.' : 'From: ${d.docType}. Added by Dalil. Check your document before you act.';
    lines.addAll([
      'BEGIN:VEVENT',
      'UID:${d.id}@dalil',
      'DTSTAMP:$stampText',
      'DTSTART;VALUE=DATE:${_icsDay(due)}',
      'DTEND;VALUE=DATE:${_icsDay(next)}',
      'SUMMARY:${_icsText(d.label)}',
      'DESCRIPTION:${_icsText(note)}',
      'BEGIN:VALARM',
      'ACTION:DISPLAY',
      'DESCRIPTION:${_icsText(d.label)}',
      'TRIGGER:-PT15H',
      'END:VALARM',
      'BEGIN:VALARM',
      'ACTION:DISPLAY',
      'DESCRIPTION:${_icsText(d.label)}',
      'TRIGGER:-P2DT15H',
      'END:VALARM',
      'END:VEVENT',
    ]);
  }
  lines.add('END:VCALENDAR');
  return '${lines.map(_fold).join('\r\n')}\r\n';
}

/// The person's deadlines, kept in the browser on this device only.
class DeadlineStore {
  DeadlineStore({this.storageKey = 'dalil.deadlines.v1'});

  static final DeadlineStore instance = DeadlineStore();
  static const maxItems = 100;

  final String storageKey;
  final ValueNotifier<List<TrackedDeadline>> items = ValueNotifier<List<TrackedDeadline>>(const []);
  int _counter = 0;

  void load() {
    final raw = LocalStore.read(storageKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final data = jsonDecode(raw);
      final list = data is Map ? data['items'] : null;
      if (list is! List) return;
      final loaded = <TrackedDeadline>[];
      for (final e in list) {
        final t = TrackedDeadline.fromJson(e);
        if (t != null) loaded.add(t);
      }
      items.value = loaded;
    } catch (_) {
      // a damaged value is ignored, the list simply starts empty
    }
  }

  void _commit(List<TrackedDeadline> next) {
    items.value = next;
    LocalStore.write(storageKey, jsonEncode({'v': 1, 'items': next.map((e) => e.toJson()).toList()}));
  }

  String _newId(DateTime now) => '${now.microsecondsSinceEpoch}-${_counter++}';

  /// Adds deadlines that are not saved yet and returns how many were new.
  int addAll(String docType, List<ReportDeadline> found, {DateTime? now, String caseId = ''}) {
    final t = now ?? DateTime.now();
    final list = [...items.value];
    var added = 0;
    for (final f in found) {
      if (list.length >= maxItems) break;
      final key = '$docType|${f.label}|${f.date}|${f.withinDays}|${f.dateText}';
      if (list.any((x) => x.key == key)) continue;
      list.add(TrackedDeadline(
        id: _newId(t),
        key: key,
        label: f.label,
        docType: docType,
        addedOn: dateOnly(t),
        due: parseIsoDate(f.date),
        dateText: f.dateText,
        withinDays: f.withinDays,
        caseId: caseId,
      ));
      added++;
    }
    if (added > 0) _commit(list);
    return added;
  }

  void toggleDone(String id) => _commit([for (final x in items.value) x.id == id ? x.copyWith(done: !x.done) : x]);

  void setDue(String id, DateTime due) => _commit([for (final x in items.value) x.id == id ? x.copyWith(due: dateOnly(due)) : x]);

  /// For "within N days" items: the person says when they got the document.
  void setReceived(String id, DateTime received) {
    final x = items.value.where((e) => e.id == id).firstOrNull;
    final days = x?.withinDays;
    if (x == null || days == null) return;
    final r = dateOnly(received);
    setDue(id, DateTime(r.year, r.month, r.day + days));
  }

  void remove(String id) => _commit([for (final x in items.value) if (x.id != id) x]);

  void removeForCase(String caseId) => _commit([for (final x in items.value) if (x.caseId != caseId) x]);

  void clearDone() => _commit([for (final x in items.value) if (!x.done) x]);
}
