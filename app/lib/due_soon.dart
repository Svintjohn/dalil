import 'cases.dart';
import 'deadlines.dart';

/// How many things need the person within a week, for the number in the header.
class DueSoon {
  const DueSoon(this.count, this.overdue);
  final int count; // everything due in the next 7 days, plus anything already late
  final int overdue; // the part of [count] that is already late
  static const none = DueSoon(0, 0);

  String get label => count == 1 ? '1 due this week' : '$count due this week';

  String get tip => overdue == 0 ? 'Things due in the next 7 days' : (overdue == 1 ? 'Includes 1 that is already late' : 'Includes $overdue that are already late');
}

/// Counts open deadlines and unpaid amounts that are due within [days] days, or already late.
/// An amount from a case that already has a counted deadline is not counted twice.
DueSoon dueSoon(List<TrackedDeadline> deadlines, List<CaseFile> cases, {DateTime? now, int days = 7}) {
  final today = dateOnly(now ?? DateTime.now());
  var count = 0;
  var overdue = 0;
  final countedCases = <String>{};
  for (final d in deadlines) {
    if (d.done || d.due == null) continue;
    final left = daysBetween(today, d.due!);
    if (left > days) continue;
    count++;
    if (left < 0) overdue++;
    if (d.caseId.isNotEmpty) countedCases.add(d.caseId);
  }
  for (final m in moneyDue(cases).unpaid) {
    final due = parseIsoDate(m.due.date);
    if (due == null || countedCases.contains(m.caseId)) continue;
    final left = daysBetween(today, due);
    if (left > days) continue;
    count++;
    if (left < 0) overdue++;
  }
  return DueSoon(count, overdue);
}
