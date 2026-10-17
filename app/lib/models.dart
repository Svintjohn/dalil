
String _s(dynamic v) => v is String ? v : (v == null ? '' : '$v');
List<dynamic> _l(dynamic v) => v is List ? v : const [];
Map<String, dynamic> _m(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
bool _b(dynamic v) => v == true;

class ApiException implements Exception {
  ApiException(this.code, this.message, [this.extra = const {}]);
  final String code;
  final String message;
  final Map<String, dynamic> extra;
  @override
  String toString() => '$code: $message';
}

class Language {
  Language({
    required this.code,
    required this.name,
    required this.native,
    required this.rtl,
    required this.tier,
    required this.featured,
    required this.note,
  });
  final String code, name, native, tier, note;
  final bool rtl, featured;

  factory Language.fromJson(Map<String, dynamic> j) => Language(
        code: _s(j['code']),
        name: _s(j['name']),
        native: _s(j['native']),
        rtl: _b(j['rtl']),
        tier: _s(j['tier']),
        featured: _b(j['featured']),
        note: _s(j['note']),
      );
}

class CountryCoverage {
  CountryCoverage({required this.code, required this.name, required this.lastVerified, required this.facts});
  final String code, name, lastVerified;
  final int facts;
  factory CountryCoverage.fromJson(Map<String, dynamic> j) => CountryCoverage(
        code: _s(j['code']),
        name: _s(j['name']),
        lastVerified: _s(j['last_verified']),
        facts: (j['facts'] is int) ? j['facts'] as int : 0,
      );
}

class SampleDoc {
  SampleDoc({required this.id, required this.title, required this.note, required this.text});
  final String id, title, note, text;
  factory SampleDoc.fromJson(Map<String, dynamic> j) =>
      SampleDoc(id: _s(j['id']), title: _s(j['title']), note: _s(j['note']), text: _s(j['text']));
}

class Meta {
  Meta({
    required this.version,
    required this.modelReady,
    required this.languages,
    required this.countries,
    required this.samples,
    required this.maxImages,
    required this.maxTextChars,
    required this.maxRequestKb,
    required this.photoTips,
    required this.privacyHeadline,
    required this.privacyPoints,
  });
  final String version, privacyHeadline;
  final bool modelReady;
  final List<Language> languages;
  final List<CountryCoverage> countries;
  final List<SampleDoc> samples;
  final int maxImages, maxTextChars, maxRequestKb;
  final List<String> photoTips, privacyPoints;

  factory Meta.fromJson(Map<String, dynamic> j) {
    final limits = _m(j['limits']);
    final privacy = _m(j['privacy']);
    int n(dynamic v, int d) => v is int ? v : d;
    return Meta(
      version: _s(j['version']),
      modelReady: _b(j['model_ready']),
      languages: _l(j['languages']).map((e) => Language.fromJson(_m(e))).toList(),
      countries: _l(j['countries']).map((e) => CountryCoverage.fromJson(_m(e))).toList(),
      samples: _l(j['samples']).map((e) => SampleDoc.fromJson(_m(e))).toList(),
      maxImages: n(limits['max_images'], 6),
      maxTextChars: n(limits['max_text_chars'], 30000),
      maxRequestKb: n(limits['max_request_kb'], 4000),
      photoTips: _l(j['photo_tips']).map(_s).toList(),
      privacyHeadline: _s(privacy['headline']),
      privacyPoints: _l(privacy['points']).map(_s).toList(),
    );
  }
}

class QualityIssue {
  QualityIssue(this.code, this.message);
  final String code, message;
  factory QualityIssue.fromJson(Map<String, dynamic> j) => QualityIssue(_s(j['code']), _s(j['message']));
}

class QualityResult {
  QualityResult(this.ok, this.issues);
  final bool ok;
  final List<QualityIssue> issues;
  factory QualityResult.fromJson(Map<String, dynamic> j) =>
      QualityResult(_b(j['ok']), _l(j['issues']).map((e) => QualityIssue.fromJson(_m(e))).toList());
}

class SourceRef {
  SourceRef({required this.ref, required this.statement, required this.url, required this.quote, required this.confidence, required this.verifiedOn});
  final String ref, statement, url, quote, confidence, verifiedOn;
  factory SourceRef.fromJson(Map<String, dynamic> j) => SourceRef(
        ref: _s(j['ref']),
        statement: _s(j['statement']),
        url: _s(j['url']),
        quote: _s(j['quote']),
        confidence: _s(j['confidence']),
        verifiedOn: _s(j['verified_on']),
      );
}

class Authority {
  Authority({required this.ref, required this.name, required this.url, required this.phone, required this.phoneSource});
  final String ref, name, url, phone, phoneSource;
  factory Authority.fromJson(Map<String, dynamic> j) => Authority(
        ref: _s(j['ref']),
        name: _s(j['name']),
        url: _s(j['url']),
        phone: _s(j['phone']),
        phoneSource: _s(j['phone_source']),
      );
}

class Finding {
  Finding({required this.severity, required this.kind, required this.quote, required this.why, required this.ask, required this.verified, required this.sources});
  final String severity, kind, quote, why, ask;
  final bool verified;
  final List<SourceRef> sources;
  factory Finding.fromJson(Map<String, dynamic> j) => Finding(
        severity: _s(j['severity']),
        kind: _s(j['kind']),
        quote: _s(j['quote']),
        why: _s(j['why']),
        ask: _s(j['ask']),
        verified: _b(j['verified']),
        sources: _l(j['sources']).map((e) => SourceRef.fromJson(_m(e))).toList(),
      );
}

class NextStep {
  NextStep({required this.action, required this.deadline, this.authority});
  final String action, deadline;
  final Authority? authority;
  factory NextStep.fromJson(Map<String, dynamic> j) => NextStep(
        action: _s(j['action']),
        deadline: _s(j['deadline']),
        authority: j['authority'] is Map ? Authority.fromJson(_m(j['authority'])) : null,
      );
}

class ChecklistItem {
  ChecklistItem(this.task, this.due);
  final String task, due;
  factory ChecklistItem.fromJson(Map<String, dynamic> j) => ChecklistItem(_s(j['task']), _s(j['due']));
}

class ReportDeadline {
  ReportDeadline({required this.label, required this.date, required this.dateText, this.withinDays});
  final String label, date, dateText; // date is YYYY-MM-DD, or empty when the document gives none
  final int? withinDays;
  factory ReportDeadline.fromJson(Map<String, dynamic> j) => ReportDeadline(
        label: _s(j['label']),
        date: _s(j['date']),
        dateText: _s(j['date_text']),
        withinDays: j['within_days'] is int ? j['within_days'] as int : null,
      );
}

class PlainPoint {
  PlainPoint(this.original, this.plain);
  final String original, plain;
  factory PlainPoint.fromJson(Map<String, dynamic> j) => PlainPoint(_s(j['original']), _s(j['plain']));
}

class Term {
  Term(this.term, this.meaning);
  final String term, meaning;
  factory Term.fromJson(Map<String, dynamic> j) => Term(_s(j['term']), _s(j['meaning']));
}

class KeyFact {
  KeyFact(this.label, this.value);
  final String label, value;
  factory KeyFact.fromJson(Map<String, dynamic> j) => KeyFact(_s(j['label']), _s(j['value']));
}

class Report {
  Report({
    required this.json,
    required this.recognized,
    required this.docType,
    required this.country,
    required this.countryName,
    required this.coverage,
    required this.registryChecked,
    required this.language,
    required this.rtl,
    required this.summary,
    required this.points,
    required this.terms,
    required this.keyFacts,
    required this.findings,
    required this.nextSteps,
    required this.checklist,
    required this.deadlines,
    required this.notSure,
    required this.closing,
    required this.labels,
    required this.saved,
    required this.savedNote,
    required this.hiddenTotal,
  });
  final Map<String, dynamic> json; // the raw report, sent back for follow-up questions and letters
  final bool recognized, rtl, saved;
  final String docType, country, countryName, coverage, registryChecked, language, summary, notSure, closing, savedNote;
  final List<PlainPoint> points;
  final List<Term> terms;
  final List<KeyFact> keyFacts;
  final List<Finding> findings;
  final List<NextStep> nextSteps;
  final List<ChecklistItem> checklist;
  final List<ReportDeadline> deadlines;
  final Map<String, String> labels;
  final int hiddenTotal;

  String label(String key, String fallback) {
    final v = labels[key];
    return (v == null || v.trim().isEmpty) ? fallback : v;
  }

  factory Report.fromJson(Map<String, dynamic> j) {
    final lab = <String, String>{};
    _m(j['labels']).forEach((k, v) => lab[k] = _s(v));
    final priv = _m(j['privacy']);
    return Report(
      json: j,
      recognized: j['recognized'] != false,
      docType: _s(j['doc_type']),
      country: _s(j['country']),
      countryName: _s(j['country_name']),
      coverage: _s(j['coverage']),
      registryChecked: _s(j['registry_checked']),
      language: _s(j['language']),
      rtl: _b(j['rtl']),
      summary: _s(j['summary']),
      points: _l(j['points']).map((e) => PlainPoint.fromJson(_m(e))).toList(),
      terms: _l(j['terms']).map((e) => Term.fromJson(_m(e))).toList(),
      keyFacts: _l(j['key_facts']).map((e) => KeyFact.fromJson(_m(e))).toList(),
      findings: _l(j['findings']).map((e) => Finding.fromJson(_m(e))).toList(),
      nextSteps: _l(j['next_steps']).map((e) => NextStep.fromJson(_m(e))).toList(),
      checklist: _l(j['checklist']).map((e) => ChecklistItem.fromJson(_m(e))).toList(),
      deadlines: _l(j['deadlines']).map((e) => ReportDeadline.fromJson(_m(e))).where((d) => d.label.trim().isNotEmpty).toList(),
      notSure: _s(j['not_sure']),
      closing: _s(j['closing']),
      labels: lab,
      saved: _b(j['saved']),
      savedNote: _s(j['saved_note']),
      hiddenTotal: priv['hidden_total'] is int ? priv['hidden_total'] as int : 0,
    );
  }
}

class AskAnswer {
  AskAnswer(this.answer, this.sources, this.authorities);
  final String answer;
  final List<SourceRef> sources;
  final List<Authority> authorities;
  factory AskAnswer.fromJson(Map<String, dynamic> j) => AskAnswer(
        _s(j['answer']),
        _l(j['sources']).map((e) => SourceRef.fromJson(_m(e))).toList(),
        _l(j['authorities']).map((e) => Authority.fromJson(_m(e))).toList(),
      );
}

class Letter {
  Letter({required this.to, required this.subject, required this.letterEn, required this.letterLocal, required this.language, required this.rtl, required this.sources, required this.note});
  final String to, subject, letterEn, letterLocal, language, note;
  final bool rtl;
  final List<SourceRef> sources;
  factory Letter.fromJson(Map<String, dynamic> j) => Letter(
        to: _s(j['to']),
        subject: _s(j['subject']),
        letterEn: _s(j['letter_en']),
        letterLocal: _s(j['letter_local']),
        language: _s(j['language']),
        rtl: _b(j['rtl']),
        sources: _l(j['sources']).map((e) => SourceRef.fromJson(_m(e))).toList(),
        note: _s(j['note']),
      );
}
