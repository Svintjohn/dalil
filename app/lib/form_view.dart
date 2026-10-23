import 'package:flutter/material.dart';

import 'fonts.dart';
import 'models.dart';
import 'motion.dart';
import 'theme.dart';
import 'widgets.dart';

/// The text of the form help, for the Copy button. English headings are used when the report has none.
String formToText(FormHelp f) {
  final b = StringBuffer();
  if (f.formName.isNotEmpty) b.writeln(f.formName);
  if (f.purpose.isNotEmpty) b.writeln(f.purpose);
  if (f.fields.isNotEmpty) {
    b
      ..writeln()
      ..writeln(f.label('form_fields', 'What each box means'));
    for (var i = 0; i < f.fields.length; i++) {
      final x = f.fields[i];
      b.writeln('${i + 1}. ${x.label}: ${x.meaning}');
      if (x.howToFill.isNotEmpty && !x.isPrivate) b.writeln('   ${f.label('form_how', 'How to fill it in')}: ${x.howToFill}');
      if (x.isPrivate) b.writeln('   ${f.label('form_private', 'Private: write this yourself')}');
    }
  }
  final w = [if (f.secretField) f.label('form_secret', 'This form asks for a password, PIN or one-time code. A real office never needs these on a form.'), ...f.warnings];
  if (w.isNotEmpty) {
    b
      ..writeln()
      ..writeln(f.label('form_warnings', 'Be careful'));
    for (final x in w) {
      b.writeln('- $x');
    }
  }
  if (f.beforeSubmit.isNotEmpty) {
    b
      ..writeln()
      ..writeln(f.label('form_submit', 'Before you hand it in'));
    for (final x in f.beforeSubmit) {
      b.writeln('- $x');
    }
  }
  return b.toString().trimRight();
}

/// What each box on a form asks for. It never suggests a value for a personal detail.
class FormView extends StatefulWidget {
  const FormView({super.key, required this.help});
  final FormHelp help;

  @override
  State<FormView> createState() => _FormViewState();
}

class _FormViewState extends State<FormView> {
  final Set<int> ticked = {};

  FormHelp get f => widget.help;

  Widget _heading(BuildContext context, String text) {
    final p = Palette.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 28, bottom: 12),
      child: Row(children: [
        Container(width: 4, height: 18, decoration: BoxDecoration(color: p.accent, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 10),
        Flexible(child: Text(text, style: Fonts.display(TextStyle(fontSize: 19, fontWeight: FontWeight.w700, letterSpacing: -0.3, color: p.ink)))),
      ]),
    );
  }

  Widget _badge(BuildContext context, String text, Color fg, Color bg, {Key? key}) => Container(
        key: key,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
        child: Text(text, style: TextStyle(color: fg, fontSize: 12.5, fontWeight: FontWeight.w700)),
      );

  Widget _box(BuildContext context, int i, FormBox x) {
    final p = Palette.of(context);
    final stripe = x.isPrivate ? p.mid : (x.required == 'yes' ? p.accent : p.line);
    final badges = <Widget>[
      if (x.required == 'yes') _badge(context, f.label('form_required', 'Required'), p.accent, p.accentTint),
      if (x.kind == 'choice') _badge(context, f.label('form_choose', 'Choose one'), p.low, p.lowTint),
      if (x.isPrivate) _badge(context, '🔒', p.mid, p.midTint, key: ValueKey('private-$i')),
    ];
    return Reveal(
      lift: 0.03,
      delayMs: (i < 6 ? i : 6) * 40,
      child: PremiumCard(
        key: ValueKey('form-box-$i'),
        stripe: stripe,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsetsDirectional.fromSTEB(20, 14, 16, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(x.label, style: Fonts.display(const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.2, height: 1.25))),
          if (badges.isNotEmpty) ...[const SizedBox(height: 8), Wrap(spacing: 6, runSpacing: 6, children: badges)],
          const SizedBox(height: 8),
          Text(x.meaning, style: const TextStyle(fontSize: 15.5, height: 1.5)),
          if (x.isPrivate) ...[
            const SizedBox(height: 8),
            Text(f.label('form_private', 'Private: write this yourself, never share it with anyone who contacts you'), style: TextStyle(color: p.mid, fontWeight: FontWeight.w700, fontSize: 13.5, height: 1.4)),
          ] else if (x.howToFill.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(f.label('form_how', 'How to fill it in'), style: TextStyle(color: p.inkSoft, fontWeight: FontWeight.w700, fontSize: 12.5, letterSpacing: .3)),
            const SizedBox(height: 2),
            Text(x.howToFill, style: TextStyle(fontSize: 15, height: 1.45, color: p.ink)),
          ],
        ]),
      ),
    );
  }

  Widget _warnings(BuildContext context) {
    final p = Palette.of(context);
    final items = [if (f.secretField) f.label('form_secret', 'This form asks for a password, PIN or one-time code. A real office never needs these on a form. Do not write them and do not give them to anyone.'), ...f.warnings];
    if (items.isEmpty) return const SizedBox.shrink();
    return Container(
      key: const ValueKey('form-warnings'),
      margin: const EdgeInsets.only(top: 18),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: p.midTint, borderRadius: BorderRadius.circular(16), border: Border.all(color: p.mid, width: 1.3)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.warning_amber_rounded, color: p.mid),
          const SizedBox(width: 8),
          Expanded(child: Text(f.label('form_warnings', 'Be careful'), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: p.mid))),
        ]),
        const SizedBox(height: 8),
        for (final w in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(padding: const EdgeInsets.only(top: 7), child: Icon(Icons.circle, size: 6, color: p.mid)),
              const SizedBox(width: 10),
              Expanded(child: Text(w, style: const TextStyle(fontSize: 15.5, height: 1.45))),
            ]),
          ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final rtl = f.rtl;
    if (!f.isForm) {
      return Directionality(
        textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
        child: Padding(
          key: const ValueKey('form-not-form'),
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(f.label('form_not_form', 'This does not look like a form to fill in. Use Explain for letters, bills and notices.'), style: Fonts.display(const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, height: 1.3))),
            if (f.purpose.isNotEmpty) ...[const SizedBox(height: 10), Text(f.purpose, style: const TextStyle(fontSize: 16, height: 1.5))],
          ]),
        ),
      );
    }
    return Directionality(
      textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (f.formName.isNotEmpty) Text(f.formName, key: const ValueKey('form-name'), style: Fonts.display(const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -0.5, height: 1.2))),
        if (f.purpose.isNotEmpty) ...[const SizedBox(height: 8), Text(f.purpose, style: TextStyle(fontSize: 16.5, height: 1.5, color: p.inkSoft))],
        _warnings(context),
        _heading(context, f.label('form_fields', 'What each box means')),
        for (var i = 0; i < f.fields.length; i++) _box(context, i, f.fields[i]),
        if (f.beforeSubmit.isNotEmpty) ...[
          _heading(context, f.label('form_submit', 'Before you hand it in')),
          for (var i = 0; i < f.beforeSubmit.length; i++)
            Material(
              type: MaterialType.transparency,
              child: CheckboxListTile(
              key: ValueKey('submit-$i'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: ticked.contains(i),
              onChanged: (v) => setState(() => v == true ? ticked.add(i) : ticked.remove(i)),
              title: Text(f.beforeSubmit[i], style: const TextStyle(fontSize: 15.5, height: 1.4)),
            )),
        ],
        if (f.notSure.isNotEmpty) ...[const SizedBox(height: 14), Text(f.notSure, style: TextStyle(color: p.inkSoft, height: 1.45))],
        const SizedBox(height: 16),
        Text(
          f.label('form_note', 'This is a guide to what each box asks for. Dalil does not fill in your personal details and cannot tell you what to choose when it matters legally, medically or financially. Ask the office that gave you the form.'),
          style: TextStyle(fontSize: 13, color: p.inkSoft, height: 1.45),
        ),
      ]),
    );
  }
}
