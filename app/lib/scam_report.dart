import 'models.dart';

/// A message the person can send to the office that takes scam reports. It is written here, not by the AI, so it is the same
/// every time and works when the AI is busy. It holds no amounts, names or numbers from the document: only what kind of
/// message it was and the warning signs. The person fills in the brackets.
String scamReportMessage(Report r) {
  final kind = r.docType.trim().isEmpty ? 'message' : r.docType.trim().toLowerCase();
  final signs = r.scamReport?.signsEn ?? const <String>[];
  final b = StringBuffer()
    ..writeln('Hello,')
    ..writeln()
    ..writeln('I want to report a suspected scam.')
    ..writeln()
    ..writeln('What I received: a $kind that looks like a scam, by [SMS / email / phone call / WhatsApp / letter] on [date].')
    ..writeln('Sent from: [phone number, email address, website or link]')
    ..writeln()
    ..writeln('Why it looks like a scam:');
  if (signs.isEmpty) {
    b.writeln('- [what made you worried]');
  } else {
    for (final s in signs) {
      b.writeln('- $s');
    }
  }
  b
    ..writeln()
    ..writeln('What I did so far: [for example: nothing / I paid AED ... / I shared a code]')
    ..writeln()
    ..writeln('Please tell me what I should do next.')
    ..writeln()
    ..writeln('[Your name] [Your phone number]');
  return b.toString().trimRight();
}
