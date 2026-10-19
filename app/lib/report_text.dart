import 'deadlines.dart';
import 'models.dart';

String numberIssueText(Report r, NumberIssue i) {
  switch (i.code) {
    case 'tax_mismatch':
      return r.label('numbers_tax', 'The tax shown does not match the tax rate.');
    case 'subtotal_mismatch':
      return r.label('numbers_subtotal', 'The subtotal does not match the items.');
    default:
      return r.label('numbers_bad', 'The amounts shown do not add up to the total on the document.');
  }
}

String reportToText(Report r) {
  final b = StringBuffer();
  if (r.scam.shown) {
    b.writeln(r.scam.stop ? r.label('scam_stop', 'Stop. Do not pay or reply yet') : r.label('scam_caution', 'Be careful with this one'));
    for (final reason in r.scam.reasons) {
      b.writeln('- $reason');
    }
    b.writeln(r.label('scam_steps', 'Do not pay, send any code or open any link in it. Check with the office through its official app or website, typing the address yourself, or call a number you find yourself. Keep the message and ask someone you trust.'));
    b.writeln();
  }
  if (r.docType.isNotEmpty) b.writeln(r.docType);
  b.writeln(r.summary);
  if (r.nextSteps.isNotEmpty) {
    b.writeln();
    b.writeln(r.label('next_steps', 'What to do'));
    for (var i = 0; i < r.nextSteps.length; i++) {
      final s = r.nextSteps[i];
      b.writeln('${i + 1}. ${s.action}${s.deadline.isEmpty ? '' : ' (${s.deadline})'}');
      if (s.authority != null) b.writeln('   ${s.authority!.name}  ${s.authority!.url}');
    }
  }
  if (r.ifIgnored.isNotEmpty) {
    b.writeln();
    b.writeln(r.label('if_ignored', 'If you do nothing'));
    for (final it in r.ifIgnored) {
      b.writeln('- ${it.action}: ${it.consequence}');
    }
  }
  final nc = r.numberCheck;
  if (nc != null && !nc.ok) {
    b.writeln();
    b.writeln(r.label('numbers', 'Number check'));
    for (final i in nc.issues) {
      b.writeln('- ${numberIssueText(r, i)}: ${r.label('numbers_stated', 'On the document')} ${nc.money(i.stated)}, ${r.label('numbers_computed', 'Added up')} ${nc.money(i.computed)}');
    }
  }
  final prep = r.prep;
  if (prep != null) {
    b.writeln();
    b.writeln(prep.office.isEmpty ? r.label('prep', 'Before you go') : '${r.label('prep', 'Before you go')}: ${prep.office}');
    if (prep.bring.isNotEmpty) {
      b.writeln(r.label('prep_bring', 'Bring'));
      for (final i in prep.bring) {
        b.writeln('- ${i.item}');
      }
    }
    if (prep.questions.isNotEmpty) {
      b.writeln(r.label('prep_ask', 'Ask'));
      for (var n = 0; n < prep.questions.length; n++) {
        b.writeln('${n + 1}. ${prep.questions[n]}');
      }
    }
  }
  if (r.deadlines.isNotEmpty) {
    b.writeln();
    b.writeln(r.label('deadlines', 'Deadlines'));
    for (final d in r.deadlines) {
      final when = describeDeadline(d);
      b.writeln('- ${d.label}${when.isEmpty ? '' : ' ($when)'}');
    }
  }
  if (r.points.isNotEmpty) {
    b.writeln();
    b.writeln(r.label('plain_words', 'In plain words'));
    for (final p in r.points) {
      b.writeln('- ${p.plain}');
    }
  }
  if (r.findings.isNotEmpty) {
    b.writeln();
    b.writeln(r.label('watch_out', 'Watch out'));
    for (final f in r.findings) {
      b.writeln('- ${f.why}');
    }
  }
  if (r.checklist.isNotEmpty) {
    b.writeln();
    b.writeln(r.label('checklist', 'Your checklist'));
    for (final c in r.checklist) {
      b.writeln('- ${c.task}${c.due.isEmpty ? '' : ' (${c.due})'}');
    }
  }
  if (r.closing.isNotEmpty) {
    b.writeln();
    b.writeln(r.closing);
  }
  return b.toString().trim();
}

String reportToSpeech(Report r) {
  final b = StringBuffer();
  if (r.scam.shown) {
    b.writeln(r.scam.stop ? r.label('scam_stop', 'Stop. Do not pay or reply yet') : r.label('scam_caution', 'Be careful with this one'));
    for (final reason in r.scam.reasons) {
      b.writeln(reason);
    }
  }
  b.writeln(r.summary);
  if (r.nextSteps.isNotEmpty) {
    b.writeln(r.label('next_steps', 'What to do'));
    for (final s in r.nextSteps) {
      b.writeln('${s.action}${s.deadline.isEmpty ? '' : '. ${s.deadline}'}');
    }
  }
  final nc = r.numberCheck;
  if (nc != null && !nc.ok) {
    for (final i in nc.issues) {
      b.writeln('${numberIssueText(r, i)} ${r.label('numbers_stated', 'On the document')} ${nc.money(i.stated)}. ${r.label('numbers_computed', 'Added up')} ${nc.money(i.computed)}.');
    }
  }
  if (r.ifIgnored.isNotEmpty) {
    b.writeln(r.label('if_ignored', 'If you do nothing'));
    for (final it in r.ifIgnored) {
      b.writeln('${it.action}. ${it.consequence}');
    }
  }
  if (r.points.isNotEmpty) {
    b.writeln(r.label('plain_words', 'In plain words'));
    for (final p in r.points) {
      b.writeln(p.plain);
    }
  }
  if (r.findings.isNotEmpty) {
    b.writeln(r.label('watch_out', 'Watch out'));
    for (final f in r.findings) {
      b.writeln(f.why);
    }
  }
  return b.toString().trim();
}
