import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api.dart';
import 'camera_dialog.dart';
import 'cases.dart';
import 'cases_ui.dart';
import 'deadlines.dart';
import 'deadlines_ui.dart';
import 'fonts.dart';
import 'landing.dart';
import 'models.dart';
import 'motion.dart';
import 'photo.dart';
import 'print_html.dart';
import 'print_page.dart';
import 'report_text.dart';
import 'report_view.dart';
import 'settings.dart';
import 'speech.dart';
import 'theme.dart';
import 'widgets.dart';

class PageShot {
  PageShot(this.bytes) : b64 = base64Encode(bytes);
  final Uint8List bytes;
  final String b64;
  QualityResult? check;
  bool checking = true;
  String? checkError;
}

class ChatTurn {
  ChatTurn(this.q, {this.a, this.error, this.byVoice = false});
  final String q;
  final bool byVoice; // the question was spoken, so the answer is read aloud
  AskAnswer? a;
  String? error;
  bool errorCalm = false; // temporary trouble (busy, slow): shown calmly
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.api, this.openUrl, this.speaker, this.dictation});
  final DalilApi api;
  final Future<void> Function(String url)? openUrl;
  final Speaker? speaker;
  final Dictation? dictation;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Meta? meta;
  String? metaError;
  Language? language;
  String country = ''; // empty = let Dalil work it out from the document

  bool photoMode = true;
  final pages = <PageShot>[];
  final textCtl = TextEditingController();
  String? sampleId;

  bool busy = false;
  bool cooling = false;
  bool askCooling = false;
  Timer? _coolTimer;
  Timer? _askCoolTimer;
  bool slow = false;
  Timer? slowTimer;
  String? error;
  String? calmError; // the message of a temporary problem (busy, slow), shown in a calm style
  List<QualityIssue> blocking = [];
  Report? report;
  final chat = <ChatTurn>[];
  final askCtl = TextEditingController();
  bool asking = false;
  final scroll = ScrollController();
  final toolKey = GlobalKey();
  final howKey = GlobalKey();
  final langKey = GlobalKey();
  final casesKey = GlobalKey();
  bool speaking = false;
  ChatTurn? speakingTurn; // which answer is being read, or null for the whole report
  bool _askedByVoice = false;
  late final Speaker _speaker = widget.speaker ?? TtsSpeaker();
  late final Dictation _dictation = widget.dictation ?? SpeechDictation();
  bool listening = false;

  @override
  void initState() {
    super.initState();
    DeadlineStore.instance.load();
    CaseStore.instance.load();
    _loadMeta();
  }

  @override
  void dispose() {
    if (speaking) _speaker.stop();
    if (listening) _dictation.stop();
    slowTimer?.cancel();
    _coolTimer?.cancel();
    _askCoolTimer?.cancel();
    textCtl.dispose();
    askCtl.dispose();
    scroll.dispose();
    super.dispose();
  }

  Future<void> _loadMeta() async {
    setState(() => metaError = null);
    try {
      final m = await widget.api.meta();
      if (!mounted) return;
      setState(() {
        meta = m;
        language ??= m.languages.firstWhere((l) => l.code == 'en', orElse: () => m.languages.isNotEmpty ? m.languages.first : Language(code: 'en', name: 'English', native: 'English', rtl: false, tier: 'high', featured: true, note: ''));
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => metaError = e.message);
    }
  }

  Future<void> _open(String url) async {
    if (widget.openUrl != null) return widget.openUrl!(url);
    final u = Uri.tryParse(url);
    if (u != null && (u.scheme == 'https' || u.scheme == 'http')) await launchUrl(u, mode: LaunchMode.externalApplication);
  }

  Future<void> _addPhoto(ImageSource src) async {
    final max = meta?.maxImages ?? 6;
    if (pages.length >= max) {
      setState(() => error = 'You can add up to $max pages.');
      return;
    }
    final picker = ImagePicker();
    List<XFile> files;
    try {
      if (src == ImageSource.gallery) {
        files = await picker.pickMultiImage();
      } else {
        XFile? shot;
        if (needsLiveCamera) {
          try {
            shot = await takePhotoWithCamera(context); // desktop browser: live camera
          } catch (_) {
            if (mounted) setState(() => error = 'Dalil could not use your camera. Allow camera access in the browser, or choose a photo instead.');
            return;
          }
        } else {
          shot = await picker.pickImage(source: src); // phone: the camera app
        }
        files = [if (shot != null) shot];
      }
    } catch (_) {
      setState(() => error = 'The app could not open the camera or photo library.');
      return;
    }
    for (final f in files) {
      if (pages.length >= max) break;
      final raw = await f.readAsBytes();
      final small = prepareForUpload(raw);
      if (small == null) {
        setState(() => error = 'One file was not a photo the app can open.');
        continue;
      }
      final p = PageShot(small);
      setState(() {
        pages.add(p);
        error = null;
        blocking = [];
        sampleId = null;
      });
      _check(p);
    }
  }

  Future<void> _check(PageShot p) async {
    try {
      p.check = await widget.api.photoCheck(p.b64);
    } on ApiException catch (e) {
      p.checkError = e.message;
    }
    if (mounted) setState(() => p.checking = false);
  }

  bool get _hasBadPhoto => pages.any((p) => p.check != null && !p.check!.ok);
  bool get _checking => pages.any((p) => p.checking);

  void _cool(int seconds) {
    cooling = true;
    _coolTimer?.cancel();
    _coolTimer = Timer(Duration(seconds: seconds), () {
      if (mounted) setState(() => cooling = false);
    });
  }

  void _coolAsk(int seconds) {
    askCooling = true;
    _askCoolTimer?.cancel();
    _askCoolTimer = Timer(Duration(seconds: seconds), () {
      if (mounted) setState(() => askCooling = false);
    });
  }

  bool get _canReview {
    if (busy || cooling || language == null) return false;
    if (photoMode) return pages.isNotEmpty && !_checking && !_hasBadPhoto;
    return textCtl.text.trim().length >= 20 || sampleId != null;
  }

  Future<void> _review() async {
    slowTimer?.cancel();
    slowTimer = Timer(const Duration(seconds: 12), () {
      if (mounted) setState(() => slow = true);
    });
    setState(() {
      busy = true;
      slow = false;
      error = null;
      blocking = [];
      report = null;
      chat.clear();
    });
    try {
      final r = await widget.api.review(
        images: photoMode ? pages.map((p) => p.b64).toList() : const [],
        text: photoMode ? null : textCtl.text,
        language: language!.code,
        country: country,
        sampleId: photoMode ? null : sampleId,
      );
      if (!mounted) return;
      setState(() => report = r);
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToResult());
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.message;
        calmError = isBusyCode(e.code) ? e.message : null;
        if (e.code == 'photo_unreadable' || e.code == 'photo_quality') blocking = _issuesFrom(e);
      });
    } finally {
      slowTimer?.cancel();
      if (mounted) {
        setState(() {
          busy = false;
          _cool(4);
        });
      }
    }
  }

  void _goTo(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(ctx, duration: Motion.ms(context, 800), curve: Motion.smooth, alignment: 0.0);
  }

  void _scrollToResult() => _goTo(toolKey);

  void _toTop() {
    if (!scroll.hasClients) return;
    scroll.animateTo(0, duration: Motion.ms(context, 900), curve: Motion.smooth);
  }

  Future<void> _speak(String text, {ChatTurn? turn}) async {
    final l = language;
    if (l == null || text.trim().isEmpty) return;
    if (speaking) {
      final same = identical(speakingTurn, turn);
      await _speaker.stop();
      if (mounted) {
        setState(() {
          speaking = false;
          speakingTurn = null;
        });
      }
      if (same) return; // a second tap on the same button only stops
    }
    setState(() {
      speaking = true;
      speakingTurn = turn;
    });
    final ok = await _speaker.speak(text, l.code, onDone: () {
      if (mounted) {
        setState(() {
          speaking = false;
          speakingTurn = null;
        });
      }
    });
    if (!ok && mounted) {
      setState(() {
        speaking = false;
        speakingTurn = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Your browser has no ${l.name} voice installed. Add one in your computer speech settings, or try Chrome or Edge.')));
    }
  }

  Future<void> _listen() async {
    final r = report;
    if (r == null) return;
    await _speak(reportToSpeech(r));
  }

  Future<void> _dictate() async {
    final l = language;
    if (l == null) return;
    if (listening) {
      await _dictation.stop();
      if (mounted) setState(() => listening = false);
      if (mounted && askCtl.text.trim().isNotEmpty) await _ask(); // tapping stop means "I am done speaking"
      return;
    }
    await _speaker.stop();
    setState(() {
      listening = true;
      speaking = false;
      speakingTurn = null;
    });
    final ok = await _dictation.start(
      l.code,
      onText: (t) {
        if (!mounted) return;
        _askedByVoice = true;
        askCtl.text = t;
        askCtl.selection = TextSelection.collapsed(offset: t.length);
      },
      onEnd: () {
        if (!mounted || !listening) return;
        setState(() => listening = false);
        if (askCtl.text.trim().isNotEmpty) _ask(); // the microphone stopped by itself: send what was heard
      },
    );
    if (!ok && mounted) {
      setState(() => listening = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not use the microphone. Allow it in your browser, or try Chrome or Edge.')));
    }
  }

  void _savePdf() {
    final r = report;
    if (r == null) return;
    final ok = printHtml(buildReportPrintHtml(r));
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open the print window. Allow pop-ups for this site, or use Copy instead.')));
    }
  }

  Future<void> _share() async {
    final r = report;
    if (r == null) return;
    var ok = false;
    try {
      ok = await launchUrl(Uri.https('wa.me', '/', {'text': shareText(r)}), mode: LaunchMode.externalApplication);
    } catch (_) {
      ok = false;
    }
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open WhatsApp. Use Copy and paste it into a message instead.')));
    }
  }

  Future<void> _copy() async {
    final r = report;
    if (r == null) return;
    await Clipboard.setData(ClipboardData(text: reportToText(r)));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied. You can paste it into a message.')));
  }

  List<QualityIssue> _issuesFrom(ApiException e) {
    final out = <QualityIssue>[];
    final issues = e.extra['issues'];
    if (issues is List) {
      for (final i in issues) {
        if (i is Map) out.add(QualityIssue.fromJson(Map<String, dynamic>.from(i)));
      }
    }
    final pg = e.extra['pages'];
    if (pg is List) {
      for (final p in pg) {
        if (p is Map && p['issues'] is List) {
          for (final i in p['issues'] as List) {
            if (i is Map) out.add(QualityIssue.fromJson(Map<String, dynamic>.from(i)));
          }
        }
      }
    }
    return out;
  }

  Future<void> _ask() async {
    final q = askCtl.text.trim();
    if (q.isEmpty || report == null || asking || askCooling) return;
    final byVoice = _askedByVoice;
    _askedByVoice = false;
    final turn = ChatTurn(q, byVoice: byVoice);
    setState(() {
      chat.add(turn);
      asking = true;
      askCtl.clear();
    });
    try {
      final history = <Map<String, String>>[];
      for (final t in chat) {
        if (t.a != null) {
          history.add({'role': 'user', 'content': t.q});
          history.add({'role': 'assistant', 'content': t.a!.answer});
        }
      }
      turn.a = await widget.api.ask(question: q, report: report!.json, language: language!.code, history: history);
    } on ApiException catch (e) {
      turn.error = e.message;
      turn.errorCalm = isBusyCode(e.code);
    } finally {
      if (mounted) {
        setState(() {
          asking = false;
          _coolAsk(2);
        });
      }
    }
    final a = turn.a;
    if (mounted && byVoice && a != null) await _speak(a.answer, turn: turn); // a spoken question gets a spoken answer
  }

  Future<void> _letter() async {
    if (report == null) return;
    await showSpringDialog<void>(context, (_) => LetterDialog(api: widget.api, report: report!, language: language!, onOpen: _open));
  }

  Future<void> _pickLanguage() async {
    final m = meta;
    if (m == null || language == null) return;
    final r = await showSpringDialog<Language>(context, (_) => LanguageDialog(languages: m.languages, selected: language!));
    if (r != null && mounted) setState(() => language = r);
  }

  void _privacy() {
    final m = meta;
    if (m == null) return;
    showSpringDialog<void>(context, (_) => PrivacyDialog(headline: m.privacyHeadline, points: m.privacyPoints));
  }

  void _toggleTheme() => AppSettings.themeMode.value = Theme.of(context).brightness == Brightness.dark ? ThemeMode.light : ThemeMode.dark;

  Widget _header(BuildContext context) {
    final p = Palette.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 1040; // below this the links fold into the menu
    final dark = Theme.of(context).brightness == Brightness.dark;
    final links = <(String, String, GlobalKey)>[
      ('try', 'Try it', toolKey),
      ('how', 'How it works', howKey),
      ('lang', 'Languages', langKey),
    ];
    final side = pagePad(context) > 20 ? 24.0 : 12.0;
    final logo = Semantics(
      button: true,
      label: 'Dalil, back to the top',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toTop,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text('دليل', style: Fonts.mark(TextStyle(fontSize: 28, height: 1.2, color: p.accent, fontWeight: FontWeight.w700))),
            const SizedBox(width: 10),
            Text('Dalil', style: Fonts.display(const TextStyle(fontSize: 21, fontWeight: FontWeight.w700, letterSpacing: -0.4))),
          ]),
        ),
      ),
    );
    final themeButton = IconButton(
      tooltip: 'Light or dark',
      onPressed: _toggleTheme,
      icon: Icon(dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined, color: p.inkSoft),
    );
    return SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Padding(
            padding: EdgeInsets.fromLTRB(side, 10, side, 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  height: 58,
                  padding: const EdgeInsetsDirectional.only(start: 20, end: 8),
                  decoration: BoxDecoration(
                    color: p.surface.withAlpha(232),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: p.ink.withAlpha(46), width: 1.2),
                  ),
                  child: Row(children: [
                    logo,
                    if (wide)
                      Expanded(
                        child: Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: AlignmentDirectional.centerEnd,
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                      for (final n in links)
                        TextButton(
                          onPressed: meta == null ? null : () => _goTo(n.$3),
                          style: TextButton.styleFrom(foregroundColor: p.inkSoft, textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                          child: Text(n.$2),
                        ),
                      ValueListenableBuilder<List<CaseFile>>(
                        valueListenable: CaseStore.instance.cases,
                        builder: (context, cs, _) => cs.isEmpty
                            ? const SizedBox.shrink()
                            : TextButton(
                                onPressed: () => _goTo(casesKey),
                                style: TextButton.styleFrom(foregroundColor: p.inkSoft, textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                                child: const Text('My cases'),
                              ),
                      ),
                      TextButton.icon(
                        onPressed: meta == null ? null : _privacy,
                        icon: Icon(Icons.lock_outline, size: 18, color: p.inkSoft),
                        label: Text('Privacy', style: TextStyle(color: p.ink, fontWeight: FontWeight.w600)),
                      ),
                      IconButton(tooltip: 'Text size', onPressed: AppSettings.nextTextSize, icon: Icon(Icons.text_fields, color: p.inkSoft)),
                      themeButton,
                      const SizedBox(width: 6),
                      Pressable(
                        child: FilledButton(
                          onPressed: meta == null ? null : () => _goTo(toolKey),
                          style: FilledButton.styleFrom(minimumSize: const Size(0, 42), padding: const EdgeInsets.symmetric(horizontal: 20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999))),
                          child: const Text('Explain a document'),
                        ),
                      ),
                            ]),
                          ),
                        ),
                      )
                    else ...[
                      const Spacer(),
                      themeButton,
                      PopupMenuButton<String>(
                        tooltip: 'Menu',
                        icon: Icon(Icons.menu_rounded, color: p.ink),
                        color: p.surface,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: p.line)),
                        onSelected: (v) {
                          for (final n in links) {
                            if (n.$1 == v) _goTo(n.$3);
                          }
                          if (v == 'cases') _goTo(casesKey);
                          if (v == 'privacy') _privacy();
                          if (v == 'size') AppSettings.nextTextSize();
                        },
                        itemBuilder: (context) => [
                          for (final n in links) PopupMenuItem<String>(value: n.$1, enabled: meta != null, child: Text(n.$2)),
                          if (CaseStore.instance.cases.value.isNotEmpty) const PopupMenuItem<String>(value: 'cases', child: Text('My cases')),
                          const PopupMenuItem<String>(value: 'privacy', child: Text('Privacy')),
                          const PopupMenuItem<String>(value: 'size', child: Text('Text size')),
                        ],
                      ),
                    ],
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _thumb(BuildContext context, int i) {
    final p = Palette.of(context);
    final s = pages[i];
    final bad = s.check != null && !s.check!.ok;
    Widget badge;
    if (s.checking) {
      badge = SizedBox(key: const ValueKey('c'), width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: p.inkSoft));
    } else if (bad) {
      badge = Icon(Icons.priority_high, key: const ValueKey('b'), size: 16, color: p.onAccent);
    } else {
      badge = Icon(Icons.check, key: const ValueKey('o'), size: 16, color: p.onAccent);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Motion.ms(context, 650),
      curve: Motion.lively,
      builder: (context, v, child) => Opacity(opacity: v.clamp(0.0, 1.0), child: Transform.scale(scale: 0.88 + 0.12 * v, child: child)),
      child: SizedBox(
        width: 96,
        height: 124,
        child: Stack(children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: bad ? p.high : p.line, width: bad ? 2 : 1)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: ScanLine(active: busy, color: p.accent, child: Image.memory(s.bytes, fit: BoxFit.cover, width: 96, height: 124)),
              ),
            ),
          ),
          PositionedDirectional(
            end: 6,
            bottom: 6,
            child: AnimatedContainer(
              duration: Motion.ms(context, 400),
              curve: Motion.lively,
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: s.checking ? p.surface : (bad ? p.high : p.ok), shape: BoxShape.circle, boxShadow: [BoxShadow(color: p.shadow, blurRadius: 6)]),
              child: AnimatedSwitcher(duration: Motion.ms(context, 250), child: badge),
            ),
          ),
          PositionedDirectional(
            top: 4,
            end: 4,
            child: Semantics(
              button: true,
              label: 'Remove page ${i + 1}',
              child: GestureDetector(
                onTap: busy ? null : () => setState(() => pages.removeAt(i)),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(color: Colors.black.withAlpha(120), shape: BoxShape.circle),
                  child: const Icon(Icons.close, size: 15, color: Colors.white),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _photoArea(BuildContext context) {
    final p = Palette.of(context);
    final tips = meta?.photoTips ?? const <String>[];
    final secondary = OutlinedButton.styleFrom(
      minimumSize: const Size(0, 48),
      foregroundColor: p.ink,
      side: BorderSide(color: p.line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: const TextStyle(fontWeight: FontWeight.w600),
    );
    final primary = FilledButton.styleFrom(
      minimumSize: const Size(0, 48),
      backgroundColor: p.accent,
      foregroundColor: p.onAccent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: const TextStyle(fontWeight: FontWeight.w600),
    );
    final bads = <Widget>[];
    for (var i = 0; i < pages.length; i++) {
      final c = pages[i].check;
      if (c != null && !c.ok) {
        bads.add(Padding(
          padding: const EdgeInsets.only(top: 12),
          child: _inlineNotice(context, 'Retake page ${i + 1}', c.issues.map((q) => q.message).toList()),
        ));
      }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AnimatedSize(
        duration: Motion.ms(context, 560),
        curve: Motion.smooth,
        alignment: Alignment.topCenter,
        child: pages.isEmpty
            ? Semantics(
                button: true,
                label: 'Choose photos of your document',
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    key: const ValueKey('drop-zone'),
                    behavior: HitTestBehavior.opaque,
                    onTap: busy ? null : () => _addPhoto(ImageSource.gallery),
                    child: HoverLift(
                      radius: 20,
                      color: p.inset,
                      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
                      child: Column(children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(color: p.accentTint, shape: BoxShape.circle),
                          child: Icon(Icons.add_a_photo_outlined, size: 26, color: p.accent),
                        ),
                        const SizedBox(height: 14),
                        Text('Add a photo of your document', style: Fonts.display(const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.3))),
                        const SizedBox(height: 4),
                        Text('Tap here, or use the buttons below. One photo per page, up to ${meta?.maxImages ?? 6} pages.', textAlign: TextAlign.center, style: TextStyle(color: p.inkSoft, height: 1.4)),
                      ]),
                    ),
                  ),
                ),
              )
            : Wrap(spacing: 12, runSpacing: 12, children: [for (var i = 0; i < pages.length; i++) _thumb(context, i)]),
      ),
      ...bads,
      const SizedBox(height: 14),
      Wrap(spacing: 10, runSpacing: 10, children: [
        Pressable(enabled: !busy, child: FilledButton.icon(style: primary, onPressed: busy ? null : () => _addPhoto(ImageSource.camera), icon: const Icon(Icons.photo_camera_outlined), label: const Text('Take photo'))),
        Pressable(enabled: !busy, child: OutlinedButton.icon(style: secondary, onPressed: busy ? null : () => _addPhoto(ImageSource.gallery), icon: const Icon(Icons.photo_library_outlined), label: const Text('Choose photos'))),
      ]),
      if (tips.isNotEmpty) ...[
        const SizedBox(height: 8),
        Disclosure(
          icon: Icons.lightbulb_outline,
          title: 'Tips for a clear photo',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final t in tips)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(padding: const EdgeInsets.only(top: 3), child: Icon(Icons.check, size: 16, color: p.ok)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(t, style: TextStyle(color: p.inkSoft, height: 1.4))),
                ]),
              ),
          ]),
        ),
      ],
    ]);
  }

  Widget _inlineNotice(BuildContext context, String title, List<String> lines, {bool calm = false}) {
    final p = Palette.of(context);
    final ink = calm ? p.mid : p.high;
    return Container(
      key: calm ? const ValueKey('calm-notice') : null,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: calm ? p.midTint : p.highTint, borderRadius: BorderRadius.circular(14)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(calm ? Icons.hourglass_empty : Icons.error_outline, size: 20, color: ink),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(color: ink, fontWeight: FontWeight.w800, height: 1.4)),
            if (calm) Padding(padding: const EdgeInsets.only(top: 4), child: Text('Your document is still here. Press the button again in a minute.', style: TextStyle(color: ink, height: 1.4))),
            for (final l in lines) Padding(padding: const EdgeInsets.only(top: 2), child: Text(l, style: TextStyle(color: ink, height: 1.4))),
          ]),
        ),
      ]),
    );
  }

  Widget _textArea(BuildContext context) {
    final p = Palette.of(context);
    final samples = meta?.samples ?? const <SampleDoc>[];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TextField(
        controller: textCtl,
        minLines: 8,
        maxLines: 14,
        maxLength: meta?.maxTextChars ?? 30000,
        onChanged: (_) => setState(() => sampleId = null),
        decoration: const InputDecoration(hintText: 'Paste the text of a letter, notice, bill, message or contract.'),
      ),
      if (samples.isNotEmpty) ...[
        const SizedBox(height: 10),
        Text('Or try a made-up example', style: TextStyle(color: p.inkSoft)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final s in samples)
            ActionChip(
              label: Text(s.title),
              side: BorderSide(color: p.line),
              backgroundColor: p.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              onPressed: () => setState(() {
                textCtl.text = s.text;
                sampleId = s.id;
              }),
            ),
        ]),
      ],
    ]);
  }

  Widget _inputSheet(BuildContext context) {
    final p = Palette.of(context);
    final m = meta;
    return Sheet(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Segmented(
          labels: const ['Photos', 'Paste text'],
          icons: const [Icons.photo_camera_outlined, Icons.notes],
          index: photoMode ? 0 : 1,
          onChanged: (i) => setState(() {
            photoMode = i == 0;
            error = null;
            blocking = [];
          }),
        ),
        const SizedBox(height: 20),
        AnimatedSwitcher(
          duration: Motion.ms(context, 380),
          switchInCurve: Curves.easeOut,
          layoutBuilder: (current, previous) => Stack(alignment: Alignment.topCenter, children: [...previous, if (current != null) current]),
          child: KeyedSubtree(key: ValueKey(photoMode), child: photoMode ? _photoArea(context) : _textArea(context)),
        ),
        const SizedBox(height: 24),
        if (m != null && language != null)
          SettingRow(
            label: 'Reply in',
            onTap: _pickLanguage,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Flexible(child: Text('${language!.name}  ·  ${language!.native}', overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600))),
              Icon(Icons.chevron_right, color: p.inkSoft),
            ]),
          ),
        if (language != null && language!.note.isNotEmpty)
          Padding(padding: const EdgeInsets.only(top: 6, left: 4), child: Text(language!.note, style: TextStyle(fontSize: 13, color: p.inkSoft))),
        const SizedBox(height: 10),
        SettingRow(
          label: 'Country',
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerEnd,
            child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: country,
              isDense: true,
              borderRadius: BorderRadius.circular(14),
              dropdownColor: p.surface,
              icon: Icon(Icons.expand_more, color: p.inkSoft),
              style: TextStyle(color: p.ink, fontWeight: FontWeight.w600, fontSize: 15),
              items: [
                const DropdownMenuItem(value: '', child: Text('Detect automatically')),
                for (final c in m?.countries ?? const <CountryCoverage>[]) DropdownMenuItem(value: c.code, child: Text(c.name)),
              ],
              onChanged: (v) => setState(() => country = v ?? ''),
            ),
          ),
          ),
        ),
        const SizedBox(height: 24),
        AnimatedSize(
          duration: Motion.ms(context, 520),
          curve: Motion.smooth,
          alignment: Alignment.topCenter,
          child: error == null ? const SizedBox(width: double.infinity) : Padding(padding: const EdgeInsets.only(bottom: 14), child: _inlineNotice(context, error!, blocking.map((q) => q.message).toList(), calm: error == calmError)),
        ),
        Pressable(
          enabled: _canReview,
          child: FilledButton(
            onPressed: _canReview ? _review : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              backgroundColor: p.accent,
              foregroundColor: p.onAccent,
              disabledBackgroundColor: p.accent.withAlpha(60),
              disabledForegroundColor: p.onAccent.withAlpha(200),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            child: AnimatedSwitcher(
              duration: Motion.ms(context, 300),
              child: busy
                  ? Row(key: const ValueKey('busy'), mainAxisAlignment: MainAxisAlignment.center, children: [
                      SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: p.onAccent)),
                      const SizedBox(width: 12),
                      const Text('Reading your document'),
                    ])
                  : const Text('Explain this', key: ValueKey('idle')),
            ),
          ),
        ),
        AnimatedSize(
          duration: Motion.ms(context, 400),
          curve: Motion.smooth,
          child: (photoMode && _hasBadPhoto)
              ? Padding(padding: const EdgeInsets.only(top: 10), child: Text('Retake the marked photo to continue.', style: TextStyle(color: p.high, fontWeight: FontWeight.w600)))
              : slow && busy
                  ? Padding(padding: const EdgeInsets.only(top: 10), child: Text('Still reading. Longer documents take up to a minute.', style: TextStyle(color: p.inkSoft)))
                  : const SizedBox(width: double.infinity),
        ),
      ]),
    );
  }

  Widget _resultColumn(BuildContext context) {
    final p = Palette.of(context);
    final r = report;
    if (r == null) return busy ? const PaperDemo(key: ValueKey('reading'), scanning: true) : const BringAnything(key: ValueKey('bring'));
    return Column(
      key: ValueKey(r),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Sheet(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 32),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (r.recognized)
              Wrap(alignment: WrapAlignment.end, spacing: 4, runSpacing: 0, children: [
                _tool(context, speaking ? Icons.stop_circle_outlined : Icons.volume_up_outlined, speaking ? 'Stop' : 'Listen', _listen),
                _tool(context, Icons.copy_outlined, 'Copy', _copy),
                _tool(context, Icons.share_outlined, 'Share', _share),
                _tool(context, Icons.picture_as_pdf_outlined, 'Save as PDF', _savePdf),
                _tool(context, Icons.mail_outline, 'Draft a letter', _letter),
              ]),
            ReportView(report: r, onOpen: _open),
          ]),
        ),
        if (r.recognized && !r.scam.stop) ...[
          const SizedBox(height: 20),
          TrackCard(key: ValueKey(r), report: r, cases: CaseStore.instance, deadlines: DeadlineStore.instance),
        ],
        if (r.recognized) ...[
          const SizedBox(height: 20),
          Sheet(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Ask about this document', style: Fonts.display(const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.4))),
              const SizedBox(height: 14),
              for (final t in chat) _chatTurn(context, t),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: askCtl,
                    onChanged: (_) => _askedByVoice = false, // typing means the answer stays silent
                    onSubmitted: (_) => _ask(),
                    textInputAction: TextInputAction.send,
                    decoration: InputDecoration(hintText: listening ? 'Listening…' : 'Type or tap the mic: can they keep my passport?'),
                  ),
                ),
                const SizedBox(width: 10),
                Pressable(
                  child: IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: listening ? p.accent : p.inset,
                      foregroundColor: listening ? p.onAccent : p.accent,
                      minimumSize: const Size(50, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    tooltip: listening ? 'Stop listening' : 'Speak your question',
                    onPressed: _dictate,
                    icon: Icon(listening ? Icons.stop_rounded : Icons.mic_none_rounded),
                  ),
                ),
                const SizedBox(width: 8),
                Pressable(
                  enabled: !asking && !askCooling,
                  child: IconButton.filled(
                    style: IconButton.styleFrom(backgroundColor: p.accent, foregroundColor: p.onAccent, minimumSize: const Size(50, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    tooltip: 'Ask',
                    onPressed: asking || askCooling ? null : _ask,
                    icon: const Icon(Icons.arrow_upward),
                  ),
                ),
              ]),
            ]),
          ),
        ],
      ],
    );
  }

  Widget _tool(BuildContext context, IconData icon, String label, VoidCallback onTap) {
    final p = Palette.of(context);
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18, color: p.accent),
      label: Text(label, style: TextStyle(color: p.accent, fontWeight: FontWeight.w700)),
    );
  }

  Widget _chatTurn(BuildContext context, ChatTurn t) {
    final p = Palette.of(context);
    return Reveal(
      lift: 0.03,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Directionality(
          textDirection: (language?.rtl ?? false) ? TextDirection.rtl : TextDirection.ltr,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t.q, style: const TextStyle(fontWeight: FontWeight.w700, height: 1.4)),
            const SizedBox(height: 6),
            if (t.error != null)
              Text(t.error!, style: TextStyle(color: t.errorCalm ? p.mid : p.high, fontWeight: t.errorCalm ? FontWeight.w600 : null))
            else if (t.a == null)
              Text('Checking official sources', style: TextStyle(color: p.inkSoft))
            else ...[
              Text(t.a!.answer, style: const TextStyle(fontSize: 16, height: 1.5)),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  key: ValueKey('listen-answer-${chat.indexOf(t)}'),
                  onPressed: () => _speak(t.a!.answer, turn: t),
                  icon: Icon(speaking && identical(speakingTurn, t) ? Icons.stop_circle_outlined : Icons.volume_up_outlined, size: 18),
                  label: Text(speaking && identical(speakingTurn, t) ? 'Stop' : 'Listen', style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              for (final s in t.a!.sources)
                InkWell(
                  onTap: s.url.isEmpty ? null : () => _open(s.url),
                  child: Padding(padding: const EdgeInsets.only(top: 6), child: Text('Source: ${s.statement}', style: TextStyle(fontSize: 13.5, color: p.accent, decoration: TextDecoration.underline))),
                ),
              for (final a in t.a!.authorities)
                InkWell(
                  onTap: a.url.isEmpty ? null : () => _open(a.url),
                  child: Padding(padding: const EdgeInsets.only(top: 6), child: Text('Contact: ${a.name}', style: TextStyle(fontSize: 13.5, color: p.accent, decoration: TextDecoration.underline))),
                ),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final p = Palette.of(context);
    final wide = isWide(context);
    final m = meta!;
    final input = _inputSheet(context);
    final result = AnimatedSwitcher(
      duration: Motion.ms(context, 600),
      switchInCurve: Motion.smooth,
      transitionBuilder: (child, anim) {
        final v = anim.value.clamp(0.0, 1.0);
        return Opacity(opacity: v, child: Transform.translate(offset: Offset(0, (1 - v) * 24), child: child));
      },
      layoutBuilder: (current, previous) => Stack(alignment: Alignment.topCenter, children: [...previous, if (current != null) current]),
      child: _resultColumn(context),
    );
    return SingleChildScrollView(
      controller: scroll,
      child: SmoothWheel(controller: scroll, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        HeroSection(onTry: () => _goTo(toolKey), onHow: () => _goTo(howKey), languageCount: m.languages.length),
        LanguageTicker(languages: m.languages),
        Band(
          key: toolKey,
          top: 72,
          bottom: 72,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (wide)
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(flex: 5, child: Text('Show Dalil your document.', style: h2Style(context))),
                const SizedBox(width: 40),
                Expanded(
                  flex: 6,
                  child: Text('One photo per page. Dalil checks that it is clear before it reads, and you can paste text instead.', style: TextStyle(fontSize: 17, height: 1.5, color: p.inkSoft)),
                ),
              ])
            else ...[
              Text('Show Dalil your document.', style: h2Style(context)),
              const SizedBox(height: 12),
              Text('One photo per page. Dalil checks that it is clear before it reads, and you can paste text instead.', style: TextStyle(fontSize: 16.5, height: 1.5, color: p.inkSoft)),
            ],
            const SizedBox(height: 28),
            if (wide)
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(flex: 5, child: input),
                const SizedBox(width: 40),
                Expanded(flex: 6, child: result),
              ])
            else ...[
              input,
              const SizedBox(height: 28),
              result,
            ],
          ]),
        ),
        KeyedSubtree(key: casesKey, child: MyCasesSection(cases: CaseStore.instance, deadlines: DeadlineStore.instance)),
        MyDeadlinesSection(store: DeadlineStore.instance),
        KeyedSubtree(key: howKey, child: const ScrollReveal(child: RouteSection())),
        KeyedSubtree(
          key: langKey,
          child: ScrollReveal(
            child: LanguageWall(
              languages: m.languages,
              selected: language?.code,
              onPick: (l) {
                setState(() => language = l);
                _goTo(toolKey);
              },
            ),
          ),
        ),
        ScrollReveal(child: TrustSection(countries: m.countries)),
        const SiteFooter(),
      ])),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Scaffold(
      body: Stack(children: [
        Positioned.fill(
          child: meta == null
              ? Center(
                  child: metaError == null
                      ? CircularProgressIndicator(color: p.accent)
                      : Column(mainAxisSize: MainAxisSize.min, children: [
                          Text(metaError!, textAlign: TextAlign.center),
                          const SizedBox(height: 14),
                          FilledButton(onPressed: _loadMeta, style: FilledButton.styleFrom(backgroundColor: p.accent, foregroundColor: p.onAccent), child: const Text('Try again')),
                        ]),
                )
              : _body(context),
        ),
        Positioned(top: 0, left: 0, right: 0, child: _header(context)),
      ]),
    );
  }
}

class LetterDialog extends StatefulWidget {
  const LetterDialog({super.key, required this.api, required this.report, required this.language, required this.onOpen});
  final DalilApi api;
  final Report report;
  final Language language;
  final void Function(String url) onOpen;

  @override
  State<LetterDialog> createState() => _LetterDialogState();
}

class _LetterDialogState extends State<LetterDialog> {
  String recipient = 'landlord';
  final note = TextEditingController();
  bool busy = false;
  String? error;
  bool errorCalm = false;
  Letter? letter;

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  Future<void> _make() async {
    setState(() {
      busy = true;
      error = null;
      errorCalm = false;
    });
    try {
      final l = await widget.api.letter(report: widget.report.json, language: widget.language.code, recipient: recipient, note: note.text);
      if (mounted) setState(() => letter = l);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          error = e.message;
          errorCalm = isBusyCode(e.code);
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 700),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Draft a letter', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('Dalil writes a polite letter based on your document. Read it and change it before you send it.', style: TextStyle(color: p.inkSoft, height: 1.45)),
            const SizedBox(height: 18),
            SettingRow(
              label: 'Write to',
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerEnd,
                child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: recipient,
                  isDense: true,
                  borderRadius: BorderRadius.circular(14),
                  dropdownColor: p.surface,
                  icon: Icon(Icons.expand_more, color: p.inkSoft),
                  style: TextStyle(color: p.ink, fontWeight: FontWeight.w600, fontSize: 15),
                  items: const [
                    DropdownMenuItem(value: 'landlord', child: Text('Landlord or property manager')),
                    DropdownMenuItem(value: 'employer', child: Text('Employer')),
                    DropdownMenuItem(value: 'authority', child: Text('Government office')),
                    DropdownMenuItem(value: 'seller', child: Text('Seller or company')),
                    DropdownMenuItem(value: 'school', child: Text('School or teacher')),
                    DropdownMenuItem(value: 'other', child: Text('Someone else')),
                  ],
                  onChanged: (v) => setState(() => recipient = v ?? 'landlord'),
                ),
              ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(controller: note, maxLines: 2, decoration: const InputDecoration(hintText: 'Anything to add? (optional)')),
            const SizedBox(height: 14),
            if (error != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(error!, style: TextStyle(color: errorCalm ? p.mid : p.high, fontWeight: FontWeight.w600, height: 1.4))),
            FilledButton(
              onPressed: busy ? null : _make,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50), backgroundColor: p.accent, foregroundColor: p.onAccent, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              child: Text(busy ? 'Writing the letter' : 'Write the letter'),
            ),
            AnimatedSize(
              duration: Motion.ms(context, 600),
              curve: Motion.smooth,
              alignment: Alignment.topCenter,
              child: letter == null
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(top: 22),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        if (letter!.subject.isNotEmpty) Text('Subject: ${letter!.subject}', style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 10),
                        SelectableText(letter!.letterEn, style: Fonts.doc(const TextStyle(fontSize: 16, height: 1.6))),
                        if (letter!.letterLocal.isNotEmpty) ...[
                          const Divider(height: 36),
                          Directionality(textDirection: letter!.rtl ? TextDirection.rtl : TextDirection.ltr, child: SelectableText(letter!.letterLocal, style: Fonts.doc(const TextStyle(fontSize: 16, height: 1.6)))),
                        ],
                        if (letter!.note.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Text(letter!.note, style: TextStyle(color: p.inkSoft))),
                      ]),
                    ),
            ),
            const SizedBox(height: 10),
            Align(alignment: AlignmentDirectional.centerEnd, child: TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))),
          ]),
        ),
      ),
    );
  }
}
