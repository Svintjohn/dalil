import 'package:flutter/material.dart';

import 'fonts.dart';
import 'models.dart';
import 'motion.dart';
import 'theme.dart';

class ReportView extends StatefulWidget {
  const ReportView({super.key, required this.report, required this.onOpen});
  final Report report;
  final void Function(String url) onOpen;

  @override
  State<ReportView> createState() => _ReportViewState();
}

class _ReportViewState extends State<ReportView> {
  final Set<int> done = {};

  Report get r => widget.report;

  Widget _heading(BuildContext context, String text) {
    final p = Palette.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 36, bottom: 14),
      child: Text(text, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: p.inkSoft)),
    );
  }

  Widget _quote(BuildContext context, String text) {
    final p = Palette.of(context);
    return Container(
      padding: const EdgeInsetsDirectional.only(start: 14),
      decoration: BoxDecoration(border: BorderDirectional(start: BorderSide(color: p.line, width: 3))),
      child: Text(
        text,
        textDirection: TextDirection.ltr,
        style: Fonts.doc(TextStyle(fontSize: 15, height: 1.55, color: p.inkSoft, fontStyle: FontStyle.italic)),
      ),
    );
  }

  Widget _link(BuildContext context, String text, String url, {IconData icon = Icons.open_in_new}) {
    final p = Palette.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: url.isEmpty ? null : () => widget.onOpen(url),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Flexible(child: Text(text, style: TextStyle(color: p.accent, fontWeight: FontWeight.w600, decoration: TextDecoration.underline, decorationColor: p.accent.withAlpha(90)))),
          const SizedBox(width: 6),
          Icon(icon, size: 14, color: p.accent),
        ]),
      ),
    );
  }

  Widget _notice(BuildContext context, String text, String sev, {IconData icon = Icons.info_outline}) {
    final p = Palette.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: p.sevTint(sev), borderRadius: BorderRadius.circular(14)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 18, color: p.sev(sev)),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: TextStyle(color: p.sev(sev), fontWeight: FontWeight.w600, height: 1.4))),
      ]),
    );
  }

  Widget _scamShield(BuildContext context) {
    final p = Palette.of(context);
    final stop = r.scam.stop;
    final sev = stop ? 'high' : 'medium';
    final title = stop ? r.label('scam_stop', 'Stop. Do not pay or reply yet') : r.label('scam_caution', 'Be careful with this one');
    return Container(
      key: const ValueKey('scam-shield'),
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.sevTint(sev),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.sev(sev), width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(stop ? Icons.gpp_bad_outlined : Icons.shield_outlined, size: 26, color: p.sev(sev)),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: p.sev(sev), height: 1.3))),
        ]),
        if (r.scam.reasons.isNotEmpty) ...[
          const SizedBox(height: 12),
          for (final reason in r.scam.reasons)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(padding: const EdgeInsets.only(top: 7), child: Icon(Icons.circle, size: 6, color: p.sev(sev))),
                const SizedBox(width: 10),
                Expanded(child: Text(reason, style: const TextStyle(fontSize: 15.5, height: 1.45))),
              ]),
            ),
        ],
        const SizedBox(height: 8),
        Text(
          r.label('scam_steps', 'Do not pay, send any code or open any link in it. Check with the office through its official app or website, typing the address yourself, or call a number you find yourself. Keep the message and ask someone you trust.'),
          style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, height: 1.45),
        ),
        const SizedBox(height: 10),
        Text(r.label('scam_note', 'Dalil cannot tell if this is genuine. These are warning signs only.'), style: TextStyle(fontSize: 13, color: p.inkSoft, height: 1.4)),
      ]),
    );
  }

  Widget _overview(BuildContext context) {
    final p = Palette.of(context);
    final counts = <String, int>{'high': 0, 'medium': 0, 'low': 0};
    for (final f in r.findings) {
      final k = counts.containsKey(f.severity) ? f.severity : 'medium';
      counts[k] = counts[k]! + 1;
    }
    if (r.findings.isEmpty) {
      return Row(children: [
        Icon(Icons.check_circle, size: 20, color: p.ok),
        const SizedBox(width: 8),
        Flexible(child: Text(r.label('no_flags', 'No red flags found'), style: TextStyle(color: p.ok, fontWeight: FontWeight.w700))),
      ]);
    }
    return Wrap(spacing: 18, runSpacing: 8, children: [
      for (final sev in const ['high', 'medium', 'low'])
        if (counts[sev]! > 0)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 9, height: 9, decoration: BoxDecoration(color: p.sev(sev), shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text('${r.label(sev, sev)} · ${counts[sev]}', style: TextStyle(color: p.sev(sev), fontWeight: FontWeight.w700)),
          ]),
    ]);
  }

  Widget _plainWords(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final side = box.maxWidth >= 620;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final pt in r.points)
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: pt.original.isEmpty
                  ? Text(pt.plain, style: const TextStyle(fontSize: 16.5, height: 1.5))
                  : side
                      ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Expanded(flex: 4, child: _quote(context, pt.original)),
                          const SizedBox(width: 28),
                          Expanded(flex: 6, child: Text(pt.plain, style: const TextStyle(fontSize: 16.5, height: 1.5))),
                        ])
                      : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          _quote(context, pt.original),
                          const SizedBox(height: 8),
                          Text(pt.plain, style: const TextStyle(fontSize: 16.5, height: 1.5)),
                        ]),
            ),
        ],
      );
    });
  }

  Widget _terms(BuildContext context) {
    final p = Palette.of(context);
    return Wrap(spacing: 10, runSpacing: 10, children: [
      for (final t in r.terms)
        Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: p.inset, borderRadius: BorderRadius.circular(12)),
          child: Text.rich(TextSpan(children: [
            TextSpan(text: t.term, style: const TextStyle(fontWeight: FontWeight.w700)),
            TextSpan(text: '  ${t.meaning}', style: TextStyle(color: p.inkSoft)),
          ]), style: const TextStyle(height: 1.4)),
        ),
    ]);
  }

  Widget _keyFacts(BuildContext context) {
    final p = Palette.of(context);
    final digit = RegExp(r'\d');
    var marks = 0;
    return Column(children: [
      for (var i = 0; i < r.keyFacts.length; i++)
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(border: Border(top: BorderSide(color: i == 0 ? Colors.transparent : p.line))),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(flex: 4, child: Text(r.keyFacts[i].label, style: TextStyle(color: p.inkSoft, height: 1.4))),
            const SizedBox(width: 16),
            Expanded(
              flex: 6,
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: digit.hasMatch(r.keyFacts[i].value)
                    ? Marker(color: p.marker, delayMs: 500 + 220 * (marks++), child: Text(r.keyFacts[i].value, style: const TextStyle(fontWeight: FontWeight.w700, height: 1.4)))
                    : Text(r.keyFacts[i].value, style: const TextStyle(fontWeight: FontWeight.w700, height: 1.4)),
              ),
            ),
          ]),
        ),
    ]);
  }

  Widget _finding(BuildContext context, Finding f) {
    final p = Palette.of(context);
    final sev = const ['high', 'medium', 'low'].contains(f.severity) ? f.severity : 'medium';
    final scam = f.kind == 'scam_signal';
    return Container(
      margin: const EdgeInsets.only(bottom: 22),
      padding: const EdgeInsetsDirectional.only(start: 16),
      decoration: BoxDecoration(border: BorderDirectional(start: BorderSide(color: p.sev(sev), width: 3))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(scam ? r.label('suspicious', 'Looks suspicious') : r.label(sev, sev), style: TextStyle(color: p.sev(sev), fontWeight: FontWeight.w800)),
          if (f.quote.isNotEmpty) ...[const SizedBox(height: 10), _quote(context, f.quote)],
          const SizedBox(height: 10),
          Text(f.why, style: const TextStyle(fontSize: 16.5, height: 1.5)),
          if (scam) ...[
            const SizedBox(height: 10),
            _notice(context, r.label('suspicious_note', 'Do not pay through this link or account. Check on the official app or website of the office named below.'), 'medium', icon: Icons.warning_amber_rounded),
          ],
          if (f.ask.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text.rich(TextSpan(children: [
              TextSpan(text: '${r.label('ask', 'Ask for')}: ', style: const TextStyle(fontWeight: FontWeight.w700)),
              TextSpan(text: f.ask),
            ]), style: const TextStyle(height: 1.5)),
          ],
          const SizedBox(height: 8),
          if (f.sources.isEmpty)
            Row(children: [
              Icon(Icons.help_outline, size: 16, color: p.inkSoft),
              const SizedBox(width: 6),
              Flexible(child: Text(r.label('unverified', 'Not matched to an official source'), style: TextStyle(color: p.inkSoft, fontSize: 13.5))),
            ])
          else
            for (final s in f.sources)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(padding: const EdgeInsets.only(top: 3), child: Icon(Icons.verified_outlined, size: 16, color: p.ok)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(s.statement, style: TextStyle(color: p.inkSoft, fontSize: 13.5, height: 1.4)),
                      _link(context, 'Official source${s.verifiedOn.isEmpty ? '' : ', checked ${s.verifiedOn}'}', s.url),
                    ]),
                  ),
                ]),
              ),
        ],
      ),
    );
  }

  Widget _ifIgnored(BuildContext context) {
    final p = Palette.of(context);
    if (r.ifIgnored.isEmpty) {
      return Text(
        r.label('if_ignored_unstated', 'The document does not say what happens if you miss it. Ask the office that sent it.'),
        key: const ValueKey('if-ignored-unstated'),
        style: TextStyle(color: p.inkSoft, height: 1.5),
      );
    }
    return Column(
      key: const ValueKey('if-ignored'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final it in r.ifIgnored)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: p.sevTint('medium'), borderRadius: BorderRadius.circular(14)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(it.action, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, height: 1.4)),
              const SizedBox(height: 6),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(padding: const EdgeInsets.only(top: 3), child: Icon(Icons.arrow_forward, size: 16, color: p.sev('medium'))),
                const SizedBox(width: 8),
                Expanded(child: Text(it.consequence, style: const TextStyle(fontSize: 16, height: 1.5))),
              ]),
              const SizedBox(height: 8),
              Text(
                it.source == 'rule' ? r.label('from_rule', 'Official rule') : r.label('from_document', 'The document says'),
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: p.inkSoft),
              ),
              for (final s in it.sources) _link(context, 'Official source${s.verifiedOn.isEmpty ? '' : ', checked ${s.verifiedOn}'}', s.url),
            ]),
          ),
      ],
    );
  }

  Widget _authority(BuildContext context, Authority a) {
    final p = Palette.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _link(context, a.name, a.url),
      if (a.phone.isNotEmpty) SelectableText('Phone ${a.phone}', style: TextStyle(color: p.inkSoft, fontSize: 13.5)),
    ]);
  }

  Widget _nextSteps(BuildContext context) {
    final p = Palette.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: p.accentTint, borderRadius: BorderRadius.circular(18)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (var i = 0; i < r.nextSteps.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == r.nextSteps.length - 1 ? 0 : 18),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: p.accent, shape: BoxShape.circle),
                child: Text('${i + 1}', style: TextStyle(color: p.onAccent, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r.nextSteps[i].action, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, height: 1.4)),
                  if (r.nextSteps[i].deadline.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Marker(color: p.marker, delayMs: 700, child: Text(r.nextSteps[i].deadline, style: const TextStyle(fontWeight: FontWeight.w600))),
                    ),
                  if (r.nextSteps[i].authority != null) Padding(padding: const EdgeInsets.only(top: 6), child: _authority(context, r.nextSteps[i].authority!)),
                ]),
              ),
            ]),
          ),
      ]),
    );
  }

  Widget _checklist(BuildContext context) {
    final p = Palette.of(context);
    return Column(children: [
      for (var i = 0; i < r.checklist.length; i++)
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() => done.contains(i) ? done.remove(i) : done.add(i)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              AnimatedContainer(
                duration: Motion.ms(context, 420),
                curve: Motion.lively,
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: done.contains(i) ? p.accent : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(color: done.contains(i) ? p.accent : p.inkSoft, width: 1.6),
                ),
                child: AnimatedScale(
                  scale: done.contains(i) ? 1 : 0,
                  duration: Motion.ms(context, 420),
                  curve: Motion.lively,
                  child: Icon(Icons.check, size: 16, color: p.onAccent),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AnimatedDefaultTextStyle(
                  duration: Motion.ms(context, 300),
                  style: TextStyle(fontSize: 16, height: 1.45, color: done.contains(i) ? p.inkSoft : p.ink, decoration: done.contains(i) ? TextDecoration.lineThrough : TextDecoration.none),
                  child: Text(r.checklist[i].due.isEmpty ? r.checklist[i].task : '${r.checklist[i].task}  (${r.checklist[i].due})'),
                ),
              ),
            ]),
          ),
        ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Directionality(
      textDirection: r.rtl ? TextDirection.rtl : TextDirection.ltr,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (r.saved) _notice(context, r.savedNote.isEmpty ? 'This is a saved sample result.' : r.savedNote, 'low'),
          if (r.coverage == 'none' && r.recognized && r.country.isNotEmpty && r.findings.any((f) => !f.verified))
            _notice(context, 'Dalil has no verified official rules for ${r.countryName.isEmpty ? r.country : r.countryName} yet. The points below are general cautions, not rule checks.', 'medium'),
          if (r.hiddenTotal > 0)
            _notice(context, '${r.hiddenTotal} personal number${r.hiddenTotal == 1 ? ' was' : 's were'} hidden before your document was read.', 'ok', icon: Icons.visibility_off_outlined),
          if (r.recognized && r.scam.shown) _scamShield(context),
          if (r.docType.isNotEmpty) Text(r.docType, style: TextStyle(fontWeight: FontWeight.w600, color: p.inkSoft)),
          if (r.coverage == 'verified' && r.countryName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('Checked against official sources of ${r.countryName}, last verified ${r.registryChecked}.', style: TextStyle(fontSize: 13, color: p.inkSoft)),
            ),
          const SizedBox(height: 12),
          Text(r.summary, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w700, height: 1.3, letterSpacing: -0.4)),
          if (r.recognized) ...[
            const SizedBox(height: 18),
            _overview(context),
            if (r.nextSteps.isNotEmpty) ...[_heading(context, r.label('next_steps', 'What to do')), _nextSteps(context)],
            if (r.ifIgnored.isNotEmpty || (r.deadlines.isNotEmpty && !r.scam.stop)) ...[_heading(context, r.label('if_ignored', 'If you do nothing')), _ifIgnored(context)],
            if (r.points.isNotEmpty) ...[_heading(context, r.label('plain_words', 'In plain words')), _plainWords(context)],
            if (r.keyFacts.isNotEmpty) ...[_heading(context, r.label('key_facts', 'Key details')), _keyFacts(context)],
            if (r.findings.isNotEmpty) ...[_heading(context, r.label('watch_out', 'Watch out')), for (final f in r.findings) _finding(context, f)],
            if (r.terms.isNotEmpty) ...[_heading(context, r.label('terms', 'Hard words explained')), _terms(context)],
            if (r.checklist.isNotEmpty) ...[_heading(context, r.label('checklist', 'Your checklist')), _checklist(context)],
            if (r.notSure.isNotEmpty) ...[_heading(context, r.label('not_sure', 'Not sure about')), Text(r.notSure, style: TextStyle(color: p.inkSoft, height: 1.5))],
          ],
          if (r.closing.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 32), child: Text(r.closing, style: TextStyle(color: p.inkSoft, fontSize: 14, height: 1.5))),
        ],
      ),
    );
  }
}
