import 'deadlines.dart';
import 'models.dart';

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
