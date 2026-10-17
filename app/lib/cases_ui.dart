import 'package:flutter/material.dart';

import 'cases.dart';
import 'deadlines.dart';
import 'landing.dart';
import 'models.dart';
import 'theme.dart';
import 'widgets.dart';

void _say(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

Future<bool> _confirm(BuildContext context, String title, String body) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
      ],
    ),
  );
  return ok == true;
}

/// Shown under a result: save it to a case and keep its deadlines.
class TrackCard extends StatefulWidget {
  const TrackCard({super.key, required this.report, required this.cases, required this.deadlines});
  final Report report;
  final CaseStore cases;
  final DeadlineStore deadlines;

  @override
  State<TrackCard> createState() => _TrackCardState();
}

class _TrackCardState extends State<TrackCard> {
  String choice = 'new';
  bool saved = false;

  void _save() {
    final r = widget.report;
    final stillOpen = widget.cases.cases.value.any((c) => c.id == choice && !c.closed);
    final id = widget.cases.addDocument(r, caseId: stillOpen ? choice : null);
    if (id == null) {
      _say(context, 'Your case list is full. Delete an old case first.');
      return;
    }
    if (r.deadlines.isNotEmpty) widget.deadlines.addAll(r.docType, r.deadlines, caseId: id);
    setState(() => saved = true);
    _say(context, 'Saved to My cases. It stays on this device only.');
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final r = widget.report;
    return Sheet(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(Icons.folder_open_outlined, color: p.accent),
          const SizedBox(width: 10),
          const Expanded(child: Text('Keep track of this', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
        ]),
        if (r.deadlines.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(r.label('deadlines', 'Deadlines'), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: p.inkSoft)),
          const SizedBox(height: 8),
          for (final d in r.deadlines)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(d.label, style: const TextStyle(fontWeight: FontWeight.w600, height: 1.4)),
                if (describeDeadline(d).isNotEmpty) Text(describeDeadline(d), style: TextStyle(color: p.inkSoft, height: 1.4)),
              ]),
            ),
          Text('Check each date against your paper before you rely on it.', style: TextStyle(color: p.inkSoft, fontSize: 13, height: 1.4)),
        ],
        const SizedBox(height: 16),
        ValueListenableBuilder<List<CaseFile>>(
          valueListenable: widget.cases.cases,
          builder: (context, all, _) {
            final open = [for (final c in all) if (!c.closed) c];
            final value = open.any((c) => c.id == choice) ? choice : 'new';
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(color: p.inset, borderRadius: BorderRadius.circular(14)),
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                underline: const SizedBox.shrink(),
                items: [
                  const DropdownMenuItem(value: 'new', child: Text('Start a new case')),
                  for (final c in open) DropdownMenuItem(value: c.id, child: Text('Add to: ${c.title}', overflow: TextOverflow.ellipsis)),
                ],
                onChanged: saved ? null : (v) => setState(() => choice = v ?? 'new'),
              ),
            );
          },
        ),
        const SizedBox(height: 14),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 48),
              backgroundColor: p.accent,
              foregroundColor: p.onAccent,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              textStyle: const TextStyle(fontWeight: FontWeight.w600),
            ),
            onPressed: saved ? null : _save,
            icon: Icon(saved ? Icons.check : Icons.bookmark_add_outlined, size: 18),
            label: Text(saved ? 'Saved to My cases' : (r.deadlines.isEmpty ? 'Save to my cases' : 'Save and track deadlines')),
          ),
        ),
        const SizedBox(height: 10),
        Text('Only a short summary is kept, on this device. Your photos and the full text are not saved.', style: TextStyle(color: p.inkSoft, fontSize: 13, height: 1.4)),
      ]),
    );
  }
}

/// A section of the page with every case and its timeline.
class MyCasesSection extends StatelessWidget {
  const MyCasesSection({super.key, required this.cases, required this.deadlines});
  final CaseStore cases;
  final DeadlineStore deadlines;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return ValueListenableBuilder<List<CaseFile>>(
      valueListenable: cases.cases,
      builder: (context, list, _) {
        if (list.isEmpty) return const SizedBox.shrink();
        final sorted = sortedCases(list);
        return Band(
          top: 0,
          bottom: 80,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('My cases', style: h2Style(context)),
            const SizedBox(height: 14),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Text('Each case keeps the papers and notes about one matter, in order. Saved in this browser only.', style: TextStyle(fontSize: 16, height: 1.5, color: p.inkSoft)),
            ),
            const SizedBox(height: 24),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                for (final c in sorted) _CaseCard(key: ValueKey(c.id), item: c, cases: cases, deadlines: deadlines),
              ]),
            ),
          ]),
        );
      },
    );
  }
}

class _CaseCard extends StatefulWidget {
  const _CaseCard({super.key, required this.item, required this.cases, required this.deadlines});
  final CaseFile item;
  final CaseStore cases;
  final DeadlineStore deadlines;

  @override
  State<_CaseCard> createState() => _CaseCardState();
}

class _CaseCardState extends State<_CaseCard> {
  bool open = false;

  Future<void> _addNote() async {
    final text = await showDialog<String>(context: context, builder: (c) => const _NoteDialog());
    if (text == null || text.trim().isEmpty) return;
    final ok = widget.cases.addNote(widget.item.id, text);
    if (!ok && mounted) _say(context, 'This case is full, so the note was not saved.');
  }

  Future<void> _delete() async {
    final yes = await _confirm(context, 'Delete this case?', 'The case, its notes and its deadlines will be removed from this device. This cannot be undone.');
    if (!yes) return;
    widget.cases.removeCase(widget.item.id);
    widget.deadlines.removeForCase(widget.item.id);
  }

  Widget _timelineEntry(BuildContext context, CaseEntry e) {
    final p = Palette.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Container(
        decoration: BoxDecoration(border: BorderDirectional(start: BorderSide(color: p.line, width: 2))),
        padding: const EdgeInsetsDirectional.only(start: 20, bottom: 18),
        child: Stack(clipBehavior: Clip.none, children: [
          PositionedDirectional(
            start: -27,
            top: 3,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(color: e.isNote ? p.mid : p.accent, shape: BoxShape.circle, border: Border.all(color: p.surface, width: 2)),
            ),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Text(fmtDate(e.date), style: TextStyle(color: p.inkSoft, fontSize: 13, fontWeight: FontWeight.w600))),
              InkResponse(
                onTap: () => widget.cases.removeEntry(widget.item.id, e.id),
                radius: 16,
                child: Tooltip(message: 'Remove this update', child: Icon(Icons.close, size: 16, color: p.inkSoft)),
              ),
            ]),
            const SizedBox(height: 2),
            Text(e.title, style: const TextStyle(fontWeight: FontWeight.w700, height: 1.4)),
            if (e.summary.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(e.summary, style: TextStyle(color: p.ink, height: 1.5))),
            if (e.facts.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(e.facts.join('  ·  '), style: TextStyle(color: p.inkSoft, fontSize: 13, height: 1.5)),
              ),
            if (e.steps.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  for (final s in e.steps) Text('• $s', style: TextStyle(color: p.inkSoft, fontSize: 13, height: 1.5)),
                ]),
              ),
            if (e.watchCount > 0)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(e.watchCount == 1 ? '1 thing to watch out for' : '${e.watchCount} things to watch out for', style: TextStyle(color: p.mid, fontSize: 13, fontWeight: FontWeight.w600)),
              ),
          ]),
        ]),
      ),
    );
  }

  Widget _nextDeadlines(BuildContext context, List<TrackedDeadline> all) {
    final p = Palette.of(context);
    final mine = sortedForDisplay([for (final d in all) if (d.caseId == widget.item.id && !d.done) d]);
    if (mine.isEmpty) return const SizedBox.shrink();
    final now = DateTime.now();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final d in mine.take(3))
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text('${deadlineStatus(d, now).text}: ${d.label}', style: TextStyle(color: p.inkSoft, fontSize: 13, height: 1.4)),
          ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final c = widget.item;
    final n = c.entries.length;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: p.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => setState(() => open = !open),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(c.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, height: 1.3)),
                  const SizedBox(height: 2),
                  Text('${n == 1 ? '1 update' : '$n updates'}  ·  last ${fmtDate(c.lastUpdate)}', style: TextStyle(color: p.inkSoft, fontSize: 13)),
                  ValueListenableBuilder<List<TrackedDeadline>>(
                    valueListenable: widget.deadlines.items,
                    builder: (context, all, _) => _nextDeadlines(context, all),
                  ),
                ]),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(color: c.closed ? p.okTint : p.accentTint, borderRadius: BorderRadius.circular(20)),
                child: Text(c.closed ? 'Closed' : 'Open', style: TextStyle(color: c.closed ? p.ok : p.accent, fontWeight: FontWeight.w700, fontSize: 13)),
              ),
              const SizedBox(width: 4),
              Icon(open ? Icons.expand_less : Icons.expand_more, color: p.inkSoft),
            ]),
          ),
        ),
        if (open) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 16, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (final e in c.entries) _timelineEntry(context, e),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Wrap(spacing: 4, children: [
              TextButton.icon(onPressed: _addNote, icon: const Icon(Icons.edit_note, size: 20), label: const Text('Add a note')),
              TextButton.icon(
                onPressed: () => widget.cases.setClosed(c.id, !c.closed),
                icon: Icon(c.closed ? Icons.undo : Icons.check_circle_outline, size: 18),
                label: Text(c.closed ? 'Reopen' : 'Mark as done'),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: p.inkSoft),
                onPressed: _delete,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Delete case'),
              ),
            ]),
          ),
        ],
      ]),
    );
  }
}

class _NoteDialog extends StatefulWidget {
  const _NoteDialog();

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  final ctl = TextEditingController();

  @override
  void dispose() {
    ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add a note'),
      content: TextField(
        controller: ctl,
        autofocus: true,
        minLines: 2,
        maxLines: 4,
        maxLength: 500,
        decoration: const InputDecoration(hintText: 'What happened? For example: I paid on 5 November.'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, ctl.text.trim()), child: const Text('Save')),
      ],
    );
  }
}
