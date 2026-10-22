import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'deadlines.dart';
import 'fonts.dart';
import 'models.dart';
import 'motion.dart';
import 'scam_report.dart';
import 'theme.dart';
import 'widgets.dart';

class ReportView extends StatefulWidget {
  const ReportView({super.key, required this.report, required this.onOpen});
  final Report report;
  final void Function(String url) onOpen;

  @override
  State<ReportView> createState() => _ReportViewState();
}

class _ReportViewState extends State<ReportView> {
  final Set<int> done = {};
  final Set<int> brought = {};

  Report get r => widget.report;

  Widget _heading(BuildContext context, String text) {
    final p = Palette.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 40, bottom: 14),
      child: Row(children: [
        Container(width: 4, height: 18, decoration: BoxDecoration(color: p.accent, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 10),
        Flexible(child: Text(text, style: Fonts.display(TextStyle(fontSize: 19, fontWeight: FontWeight.w700, letterSpacing: -0.3, color: p.ink)))),
      ]),
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
        if (r.scamReport != null) ...[
          const SizedBox(height: 12),
          _reportScam(context, r.scamReport!),
        ],
      ]),
    );
  }

  /// Where to report it and a message to send. The offices come from the verified registry; the message is a fixed template.
  Widget _reportScam(BuildContext context, ScamReportPack pack) {
    final p = Palette.of(context);
    return Disclosure(
      key: const ValueKey('scam-report'),
      icon: Icons.campaign_outlined,
      title: r.label('report_scam', 'Report this scam'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(r.label('report_where', 'Where to report it'), style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        if (pack.authorities.isEmpty)
          Text(r.label('report_none', 'Report it to the police or the cyber-crime unit in the country where you received it.'), style: const TextStyle(height: 1.45))
        else
          for (final a in pack.authorities) Padding(padding: const EdgeInsets.only(bottom: 8), child: _authority(context, a)),
        const SizedBox(height: 10),
        Text(r.label('report_msg', 'A message you can send'), style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: p.inset, borderRadius: BorderRadius.circular(12)),
          child: SelectableText(scamReportMessage(r), key: const ValueKey('scam-report-text'), textDirection: TextDirection.ltr, style: const TextStyle(fontSize: 14, height: 1.5)),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: OutlinedButton.icon(
            key: const ValueKey('scam-report-copy'),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: scamReportMessage(r)));
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied. Fill in the brackets, then send it.')));
            },
            icon: const Icon(Icons.copy_outlined, size: 18),
            label: const Text('Copy'),
          ),
        ),
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
      // Never say "no red flags" next to a warning: the scam shield or the number check already found something.
      if (r.scam.shown) return const SizedBox.shrink();
      final nc = r.numberCheck;
      if (nc != null && !nc.ok) {
        return Row(children: [
          Icon(Icons.warning_amber_rounded, size: 20, color: p.sev('medium')),
          const SizedBox(width: 8),
          Flexible(child: Text(r.label('numbers_flag', 'The amounts do not add up'), style: TextStyle(color: p.sev('medium'), fontWeight: FontWeight.w700))),
        ]);
      }
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

  Widget _due(BuildContext context) {
    final p = Palette.of(context);
    final d = r.due!;
    final when = dueWhen(d);
    return Container(
      key: const ValueKey('due-amount'),
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: p.accentTint, borderRadius: BorderRadius.circular(14)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.payments_outlined, color: p.accent),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.label('due_amount', 'Amount due'), style: TextStyle(color: p.inkSoft, fontSize: 13, fontWeight: FontWeight.w600)),
            Text(d.money, style: Fonts.display(const TextStyle(fontSize: 30, fontWeight: FontWeight.w700, height: 1.25, letterSpacing: -0.5))),
            if (d.label.isNotEmpty) Text(d.label, style: TextStyle(color: p.inkSoft, height: 1.4)),
            if (when.isNotEmpty) Text('${r.label('due_by', 'Pay by')} $when', style: const TextStyle(fontWeight: FontWeight.w600, height: 1.4)),
            if (d.check)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(r.label('due_check', 'Check this figure: the amounts on the paper do not add up.'), style: TextStyle(color: p.mid, fontWeight: FontWeight.w600, height: 1.4)),
              ),
          ]),
        ),
      ]),
    );
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
    return PremiumCard(
      margin: const EdgeInsets.only(bottom: 16),
      stripe: p.sev(sev),
      tint: p.sevTint(sev).withAlpha(70),
      padding: const EdgeInsetsDirectional.fromSTEB(22, 16, 18, 16),
      lift: false,
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

  Widget _prep(BuildContext context) {
    final p = Palette.of(context);
    final prep = r.prep!;
    Widget sub(String text) => Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 8),
          child: Text(text, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: p.inkSoft)),
        );
    return Container(
      key: const ValueKey('prep'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: p.inset, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (prep.authority != null) _authority(context, prep.authority!) else if (prep.office.isNotEmpty) Text(prep.office, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        if (prep.bring.isNotEmpty) ...[
          sub(r.label('prep_bring', 'Bring')),
          for (var i = 0; i < prep.bring.length; i++)
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => setState(() => brought.contains(i) ? brought.remove(i) : brought.add(i)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(brought.contains(i) ? Icons.check_circle : Icons.radio_button_unchecked, size: 22, color: brought.contains(i) ? p.accent : p.inkSoft),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(
                        prep.bring[i].item,
                        style: TextStyle(fontSize: 16, height: 1.45, color: brought.contains(i) ? p.inkSoft : p.ink, decoration: brought.contains(i) ? TextDecoration.lineThrough : TextDecoration.none),
                      ),
                      Text(
                        prep.bring[i].required ? r.label('prep_required', 'The document asks for this') : r.label('prep_suggested', 'Suggested'),
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: prep.bring[i].required ? p.sev('medium') : p.inkSoft),
                      ),
                    ]),
                  ),
                ]),
              ),
            ),
        ],
        if (prep.questions.isNotEmpty) ...[
          sub(r.label('prep_ask', 'Ask')),
          for (var i = 0; i < prep.questions.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(width: 24, child: Text('${i + 1}.', style: TextStyle(fontWeight: FontWeight.w700, color: p.inkSoft))),
                Expanded(child: SelectableText(prep.questions[i], style: const TextStyle(fontSize: 16, height: 1.45))),
              ]),
            ),
        ],
      ]),
    );
  }

  String _issueText(NumberIssue i) {
    switch (i.code) {
      case 'tax_mismatch':
        return r.label('numbers_tax', 'The tax shown does not match the tax rate.');
      case 'subtotal_mismatch':
        return r.label('numbers_subtotal', 'The subtotal does not match the items.');
      default:
        return r.label('numbers_bad', 'The amounts shown do not add up to the total on the document.');
    }
  }

  Widget _numberCheck(BuildContext context) {
    final p = Palette.of(context);
    final n = r.numberCheck!;
    final color = n.ok ? p.ok : p.sev('medium');
    return Container(
      key: const ValueKey('number-check'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: n.ok ? p.okTint : p.sevTint('medium'), borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(n.ok ? Icons.check_circle_outline : Icons.warning_amber_rounded, size: 22, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              n.ok ? r.label('numbers_ok', 'The amounts shown add up to the total on the document.') : _issueText(n.issues.first),
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color, height: 1.4),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        for (final ln in n.lines)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Text(ln.label.isEmpty ? ln.role : ln.label, style: TextStyle(fontSize: 15, height: 1.4, fontWeight: (ln.role == 'total' || ln.role == 'subtotal') ? FontWeight.w700 : FontWeight.w400)),
              ),
              const SizedBox(width: 12),
              Text(
                '${ln.role == 'discount' ? '-' : ''}${n.money(ln.amount)}',
                textDirection: TextDirection.ltr,
                style: TextStyle(fontSize: 15, fontWeight: (ln.role == 'total' || ln.role == 'subtotal') ? FontWeight.w700 : FontWeight.w400),
              ),
            ]),
          ),
        if (!n.ok)
          for (var k = 0; k < n.issues.length; k++) ...[
            const SizedBox(height: 10),
            if (k > 0) Text(_issueText(n.issues[k]), style: TextStyle(fontWeight: FontWeight.w600, color: color, height: 1.4)),
            Text(
              '${r.label('numbers_stated', 'On the document')}: ${n.money(n.issues[k].stated)}  ·  ${r.label('numbers_computed', 'Added up')}: ${n.money(n.issues[k].computed)}${n.issues[k].code == 'total_mismatch' ? '  ·  ${r.label('numbers_diff', 'Difference')}: ${n.money(n.issues[k].difference.abs())}' : ''}',
              textDirection: TextDirection.ltr,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, height: 1.5),
            ),
          ],
        if (!n.ok) ...[
          const SizedBox(height: 10),
          Text(r.label('numbers_hint', 'This can also be a reading mistake. Compare each figure with the paper, and if it still differs, ask the sender to explain.'), style: TextStyle(color: p.inkSoft, height: 1.45)),
        ],
        const SizedBox(height: 8),
        Text(r.label('numbers_note', 'Dalil checked the arithmetic only, not whether the prices are fair.'), style: TextStyle(fontSize: 13, color: p.inkSoft, height: 1.4)),
      ]),
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

  /// Each part of the result comes in a little after the one before it, so the page builds itself instead of appearing all at once.
  Widget _in(int i, Widget child) => Reveal(delayMs: i == 0 ? 0 : math.min(i, 6) * 70, lift: 0.025, child: child);

  Widget _group(String heading, List<Widget> body) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [_heading(context, heading), ...body]);

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final groups = <Widget>[
      if (r.recognized) ...[
        if (r.nextSteps.isNotEmpty) _group(r.label('next_steps', 'What to do'), [_nextSteps(context)]),
        if (r.ifIgnored.isNotEmpty || (r.deadlines.isNotEmpty && !r.scam.stop)) _group(r.label('if_ignored', 'If you do nothing'), [_ifIgnored(context)]),
        if (r.prep != null) _group(r.label('prep', 'Before you go'), [_prep(context)]),
        if (r.points.isNotEmpty) _group(r.label('plain_words', 'In plain words'), [_plainWords(context)]),
        if (r.keyFacts.isNotEmpty) _group(r.label('key_facts', 'Key details'), [_keyFacts(context)]),
        if (r.numberCheck != null) _group(r.label('numbers', 'Number check'), [_numberCheck(context)]),
        if (r.findings.isNotEmpty) _group(r.label('watch_out', 'Watch out'), [for (final f in r.findings) _finding(context, f)]),
        if (r.terms.isNotEmpty) _group(r.label('terms', 'Hard words explained'), [_terms(context)]),
        if (r.checklist.isNotEmpty) _group(r.label('checklist', 'Your checklist'), [_checklist(context)]),
        if (r.notSure.isNotEmpty) _group(r.label('not_sure', 'Not sure about'), [Text(r.notSure, style: TextStyle(color: p.inkSoft, height: 1.5))]),
      ],
    ];
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
          _in(0, Text(r.summary, style: Fonts.display(const TextStyle(fontSize: 27, fontWeight: FontWeight.w700, height: 1.25, letterSpacing: -0.6)))),
          if (r.recognized) ...[
            const SizedBox(height: 18),
            _in(1, Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [_overview(context), if (r.due != null) _due(context)])),
            for (var i = 0; i < groups.length; i++) _in(i + 2, groups[i]),
          ],
          if (r.closing.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 32), child: Text(r.closing, style: TextStyle(color: p.inkSoft, fontSize: 14, height: 1.5))),
        ],
      ),
    );
  }
}
