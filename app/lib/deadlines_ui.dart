import 'package:flutter/material.dart';

import 'deadlines.dart';
import 'download.dart';
import 'landing.dart';
import 'theme.dart';
import 'widgets.dart';

void _say(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

void _exportCalendar(BuildContext context, List<TrackedDeadline> items, String filename) {
  final ok = saveTextFile(filename, 'text/calendar', buildIcs(items));
  _say(context, ok ? 'Calendar file saved. Open it to add the dates and reminders to your calendar.' : 'Could not save the calendar file here.');
}

/// A section of the page with everything the person is keeping track of.
class MyDeadlinesSection extends StatelessWidget {
  const MyDeadlinesSection({super.key, required this.store});
  final DeadlineStore store;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return ValueListenableBuilder<List<TrackedDeadline>>(
      valueListenable: store.items,
      builder: (context, list, _) {
        if (list.isEmpty) return const SizedBox.shrink();
        final sorted = sortedForDisplay(list);
        final hasDated = list.any((x) => x.due != null && !x.done);
        final hasDone = list.any((x) => x.done);
        final now = DateTime.now();
        return Band(
          top: 0,
          bottom: 80,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('My deadlines', style: h2Style(context)),
            const SizedBox(height: 14),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Text('Saved in this browser only. Nothing is sent to a server, so clearing your browser data removes them.', style: TextStyle(fontSize: 16, height: 1.5, color: p.inkSoft)),
            ),
            const SizedBox(height: 24),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                for (final d in sorted) _DeadlineRow(key: ValueKey(d.id), item: d, store: store, now: now),
                const SizedBox(height: 8),
                Wrap(spacing: 12, runSpacing: 8, children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 46),
                      foregroundColor: p.ink,
                      side: BorderSide(color: p.line),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      textStyle: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    onPressed: hasDated ? () => _exportCalendar(context, list, 'dalil-deadlines.ics') : null,
                    icon: const Icon(Icons.calendar_month_outlined, size: 18),
                    label: const Text('Add all to my calendar'),
                  ),
                  if (hasDone)
                    TextButton(
                      style: TextButton.styleFrom(foregroundColor: p.inkSoft, textStyle: const TextStyle(fontWeight: FontWeight.w600)),
                      onPressed: store.clearDone,
                      child: const Text('Remove finished'),
                    ),
                ]),
              ]),
            ),
          ]),
        );
      },
    );
  }
}

class _DeadlineRow extends StatelessWidget {
  const _DeadlineRow({super.key, required this.item, required this.store, required this.now});
  final TrackedDeadline item;
  final DeadlineStore store;
  final DateTime now;

  Future<void> _pick(BuildContext context) async {
    final today = dateOnly(now);
    final received = item.withinDays != null;
    final picked = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: DateTime(today.year - 1, today.month, today.day),
      lastDate: DateTime(today.year + 10, today.month, today.day),
      helpText: received ? 'The day you got the document' : 'The deadline date',
    );
    if (picked == null) return;
    if (received) {
      store.setReceived(item.id, picked);
    } else {
      store.setDue(item.id, picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final st = deadlineStatus(item, now);
    final Color fg;
    final Color bg;
    switch (st.level) {
      case 'done':
        fg = p.ok;
        bg = p.okTint;
      case 'none':
        fg = p.inkSoft;
        bg = p.inset;
      default:
        fg = p.sev(st.level);
        bg = p.sevTint(st.level);
    }
    final due = item.due;
    final source = item.withinDays != null && due == null
        ? (item.withinDays == 1 ? 'Within 1 day of receiving it' : 'Within ${item.withinDays} days of receiving it')
        : (due != null ? fmtDate(due) : item.dateText);
    final dateButton = due == null
        ? TextButton.icon(
            onPressed: () => _pick(context),
            icon: const Icon(Icons.edit_calendar_outlined, size: 18),
            label: Text(item.withinDays != null ? 'Set the day you got it' : 'Set the date'),
          )
        : null;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(8, 12, 14, 8),
      decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: p.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Checkbox(value: item.done, onChanged: (_) => store.toggleDone(item.id)),
          const SizedBox(width: 4),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
                  child: Text(st.text, style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 13)),
                ),
                const SizedBox(height: 8),
                Text(
                  item.label,
                  style: TextStyle(fontWeight: FontWeight.w600, height: 1.4, color: item.done ? p.inkSoft : p.ink, decoration: item.done ? TextDecoration.lineThrough : null),
                ),
                if (source.isNotEmpty) Text(source, style: TextStyle(color: p.inkSoft, height: 1.4)),
                if (item.docType.isNotEmpty) Text('From: ${item.docType}', style: TextStyle(color: p.inkSoft, fontSize: 13, height: 1.4)),
              ]),
            ),
          ),
        ]),
        Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Wrap(spacing: 4, children: [
            if (dateButton != null) dateButton,
            if (due != null && !item.done)
              TextButton.icon(
                onPressed: () => _exportCalendar(context, [item], 'dalil-deadline.ics'),
                icon: const Icon(Icons.calendar_month_outlined, size: 18),
                label: const Text('Add to calendar'),
              ),
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: p.inkSoft),
              onPressed: () => store.remove(item.id),
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Remove'),
            ),
          ]),
        ),
      ]),
    );
  }
}
