import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'fonts.dart';
import 'models.dart';
import 'profile.dart';
import 'share_engine.dart';
import 'theme.dart';

const _mask = '•••';

final _email = RegExp(r'[\w.+-]+@[\w-]+(?:\.[\w-]+)+');
final _phone = RegExp(r'(?:\+|00)?\d[\d ()\-]{6,}\d');
const _currency = r'(?:AED|USD|EUR|GBP|SAR|QAR|KWD|BHD|OMR|INR|PKR|PHP|BDT|LKR|NPR|Dhs?|Dh|dirhams?|riyals?|rupees?|pesos?|euros?|dollars?|\$|€|£)';
final _moneyAfter = RegExp('($_currency)\\s?\\d[\\d,]*(?:\\.\\d+)?', caseSensitive: false);
final _moneyBefore = RegExp('\\d[\\d,]*(?:\\.\\d+)?\\s?($_currency)(?![A-Za-z])', caseSensitive: false);
final _date = RegExp(r'^\d{1,4}[-/.]\d{1,2}[-/.]\d{2,4}$');
final _dateIn = RegExp(r'(?<!\d)\d{1,4}[-/.]\d{1,2}[-/.]\d{2,4}(?!\d)');
final _time = RegExp(r'^\d{1,2}:\d{2}$');
final _grouped = RegExp(r'^\d{1,3}(?:,\d{3})+(?:\.\d+)?$');
final _decimal = RegExp(r'^\d+\.\d{1,2}$');
final _letters = RegExp(r'\p{L}', unicode: true);
final _edges = RegExp(r'^([^\p{L}\p{N}]*)(.*?)([^\p{L}\p{N}]*)$', unicode: true);

/// Takes out what must not be on a picture that gets shared: emails, phone numbers and long reference or account numbers,
/// always. With [hideAmounts], money amounts too. Dates, times, percentages and small counts such as "30 days" stay.
String redactForCard(String text, {bool hideAmounts = true}) {
  // dates are set aside first, so a date is never mistaken for a phone number
  final dates = <String>[];
  var t = text.replaceAllMapped(_dateIn, (m) {
    dates.add(m[0]!);
    return '\uE000${String.fromCharCode(0xE100 + dates.length - 1)}';
  });
  t = t.replaceAll(_email, _mask);
  t = t.replaceAllMapped(_phone, (m) => RegExp(r'\d').allMatches(m[0]!).length >= 8 ? _mask : m[0]!);
  if (hideAmounts) {
    t = t.replaceAllMapped(_moneyAfter, (m) => '${m[1]} $_mask');
    t = t.replaceAllMapped(_moneyBefore, (m) => '$_mask ${m[1]}');
  }
  t = t.replaceAllMapped(RegExp(r'\S+'), (m) {
    final raw = m[0]!;
    final e = _edges.firstMatch(raw);
    if (e == null) return raw;
    final lead = e[1]!, mid = e[2]!, tail = e[3]!;
    if (mid.isEmpty || mid.contains('•')) return raw;
    final digits = RegExp(r'\d').allMatches(mid).length;
    if (digits == 0) return raw;
    if (_date.hasMatch(mid) || _time.hasMatch(mid)) return raw;
    final plain = RegExp(r'^\d+$').hasMatch(mid);
    final amount = _grouped.hasMatch(mid) || _decimal.hasMatch(mid) || (plain && digits <= 5);
    if (amount) {
      final year = plain && digits == 4 && int.parse(mid) >= 1900 && int.parse(mid) <= 2100;
      final small = plain && digits <= 3; // "30 days", "3 steps"
      final percent = tail.startsWith('%');
      if (!hideAmounts || year || small || percent) return raw;
      return '$lead$_mask$tail';
    }
    if (digits >= 6) return '$lead$_mask$tail'; // an account, reference or phone number
    if (_letters.hasMatch(mid) && digits >= 3 && mid.length >= 5) return '$lead$_mask$tail'; // a mixed code such as AB12345
    return raw;
  });
  for (var i = 0; i < dates.length; i++) {
    t = t.replaceAll('\uE000${String.fromCharCode(0xE100 + i)}', dates[i]);
  }
  return t;
}

/// At most [max] characters, cut at the end of a sentence when there is one, else at a word.
String shortenText(String s, int max) {
  final t = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  final runes = t.runes.toList();
  if (runes.length <= max) return t;
  final cut = String.fromCharCodes(runes.take(max));
  final end = cut.lastIndexOf(RegExp(r'[.!?。]'));
  if (end > max ~/ 2) return cut.substring(0, end + 1);
  final sp = cut.lastIndexOf(' ');
  return '${(sp > max ~/ 2 ? cut.substring(0, sp) : cut).trimRight()}…';
}

/// Everything printed on the summary card. It has the plain-language summary and the next steps, and never the
/// person's name, the quoted text of the document or its numbers.
class ShareCardData {
  const ShareCardData({
    required this.kicker,
    required this.headline,
    required this.listLabel,
    required this.items,
    required this.watchLabel,
    required this.watchCount,
    required this.rtl,
    required this.stop,
  });

  final String kicker, headline, listLabel, watchLabel;
  final List<String> items;
  final int watchCount;
  final bool rtl, stop;

  factory ShareCardData.fromReport(Report r, {bool hideAmounts = true}) {
    String clean(String s, int max) => shortenText(redactForCard(s, hideAmounts: hideAmounts), max);
    final scam = r.scam.shown;
    final kicker = scam
        ? (r.scam.stop ? r.label('scam_stop', 'Stop. Do not pay or reply yet') : r.label('scam_caution', 'Be careful with this one'))
        : (r.docType.trim().isEmpty ? 'Document' : r.docType.trim());
    final items = scam
        ? [for (final s in r.scam.reasons.take(3)) clean(s, 110)]
        : [
            for (final s in r.nextSteps.take(3))
              clean(s.deadline.trim().isEmpty ? s.action : '${s.action} (${s.deadline})', 110),
          ];
    return ShareCardData(
      kicker: shortenText(kicker, 40),
      headline: clean(r.summary, 230),
      listLabel: scam ? r.label('watch_out', 'Watch out') : r.label('next_steps', 'What to do'),
      items: [for (final i in items) if (i.isNotEmpty) i],
      watchLabel: r.label('watch_out', 'Watch out'),
      watchCount: scam ? 0 : r.findings.length,
      rtl: r.rtl,
      stop: scam && r.scam.stop,
    );
  }
}

/// The picture itself, always on light paper so it looks the same whatever the app's theme is.
class ShareCard extends StatelessWidget {
  const ShareCard({super.key, required this.data});
  final ShareCardData data;

  static const width = 540.0;
  static const height = 675.0;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: buildTheme(Brightness.light, accent: Profile.instance.accent),
      child: Builder(builder: (context) {
        final p = Palette.of(context);
        final warn = data.stop;
        return Directionality(
          textDirection: data.rtl ? TextDirection.rtl : TextDirection.ltr,
          child: SizedBox(
            width: width,
            height: height,
            child: ColoredBox(
              color: p.bg,
              child: Padding(
                padding: const EdgeInsets.all(26),
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: p.ink, width: 1.6),
                    boxShadow: [BoxShadow(color: p.ink, offset: const Offset(7, 7))],
                  ),
                  child: Stack(children: [
                    PositionedDirectional(
                      top: -64,
                      end: -64,
                      child: Container(width: 200, height: 200, decoration: BoxDecoration(color: warn ? p.highTint : p.accentTint, shape: BoxShape.circle)),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(28, 26, 28, 22),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        _header(p, warn),
                        const SizedBox(height: 22),
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: AlignmentDirectional.topStart,
                            child: SizedBox(width: width - 52 - 56, child: _body(p)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _footer(p),
                      ]),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _header(Palette p, bool warn) {
    return Row(children: [
      Text('دليل', style: Fonts.mark(TextStyle(fontSize: 30, height: 1.2, color: p.accent, fontWeight: FontWeight.w700))),
      const SizedBox(width: 8),
      Text('Dalil', style: Fonts.display(TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: p.ink))),
      const SizedBox(width: 14),
      Expanded(
        child: Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: warn ? p.highTint : p.surface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: warn ? p.high : p.ink.withAlpha(90), width: 1.2),
            ),
            child: Text(data.kicker, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: warn ? p.high : p.ink)),
          ),
        ),
      ),
    ]);
  }

  Widget _body(Palette p) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(data.headline, style: Fonts.display(TextStyle(fontSize: 31, height: 1.16, fontWeight: FontWeight.w700, letterSpacing: -0.6, color: p.ink))),
      if (data.items.isNotEmpty) ...[
        const SizedBox(height: 26),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: p.marker, borderRadius: BorderRadius.circular(4)),
          child: Text(data.listLabel, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: p.ink)),
        ),
        const SizedBox(height: 14),
        for (var i = 0; i < data.items.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: data.stop ? p.high : p.accent, shape: BoxShape.circle),
                child: Text('${i + 1}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: p.onAccent)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(data.items[i], style: TextStyle(fontSize: 18, height: 1.35, color: p.ink))),
            ]),
          ),
      ],
    ]);
  }

  Widget _footer(Palette p) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(height: 1.2, color: p.line),
      const SizedBox(height: 12),
      Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        if (data.watchCount > 0)
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: p.midTint, borderRadius: BorderRadius.circular(999)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.flag_outlined, size: 16, color: p.mid),
                  const SizedBox(width: 5),
                  Text('${data.watchLabel}  ${data.watchCount}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: p.mid)),
                ]),
              ),
            ),
          ),
        const SizedBox(width: 12),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerEnd, // never overflows, whatever the language or font
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
              Text('Explained by Dalil', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: p.ink)),
              const SizedBox(height: 2),
              Directionality(textDirection: TextDirection.ltr, child: Text('dalil-rouge.vercel.app', style: TextStyle(fontSize: 12, color: p.inkSoft))),
              Text('A guide, not legal advice', style: TextStyle(fontSize: 11.5, color: p.inkSoft)),
            ]),
          ),
        ),
      ]),
    ]);
  }
}

/// Draws the card at twice its size, which gives a 1080 by 1350 picture.
Future<Uint8List?> renderShareCard(GlobalKey boundaryKey) async {
  final ro = boundaryKey.currentContext?.findRenderObject();
  if (ro is! RenderRepaintBoundary) return null;
  final image = await ro.toImage(pixelRatio: 2.0);
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}

/// A preview of the card, a switch for hiding amounts, and buttons to share or save it.
class ShareCardDialog extends StatefulWidget {
  const ShareCardDialog({super.key, required this.report});
  final Report report;

  @override
  State<ShareCardDialog> createState() => _ShareCardDialogState();
}

class _ShareCardDialogState extends State<ShareCardDialog> {
  final boundary = GlobalKey();
  bool hide = true;
  bool busy = false;
  String status = '';

  Future<void> _share() async {
    if (busy) return;
    setState(() {
      busy = true;
      status = '';
    });
    String note;
    try {
      final bytes = await renderShareCard(boundary);
      if (bytes == null) {
        note = 'Could not make the picture. Try again.';
      } else {
        final how = await shareImage(bytes, 'dalil-summary.png', 'Explained with Dalil: https://dalil-rouge.vercel.app');
        if (how == 'shared') {
          note = '';
        } else if (how == 'cancelled') {
          note = '';
        } else {
          note = saveImage(bytes, 'dalil-summary.png')
              ? 'This browser cannot open the share sheet, so the picture was saved. Send it from your downloads.'
              : 'Could not share or save the picture. Try Chrome or Edge.';
        }
      }
    } catch (_) {
      note = 'Could not make the picture. Try again.';
    }
    if (mounted) {
      setState(() {
        busy = false;
        status = note;
      });
    }
  }

  Future<void> _save() async {
    if (busy) return;
    setState(() {
      busy = true;
      status = '';
    });
    String note;
    try {
      final bytes = await renderShareCard(boundary);
      note = bytes == null
          ? 'Could not make the picture. Try again.'
          : (saveImage(bytes, 'dalil-summary.png') ? 'Saved. Look in your downloads.' : 'Could not save the picture. Try Chrome or Edge.');
    } catch (_) {
      note = 'Could not make the picture. Try again.';
    }
    if (mounted) {
      setState(() {
        busy = false;
        status = note;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final data = ShareCardData.fromReport(widget.report, hideAmounts: hide);
    return Dialog(
      insetPadding: const EdgeInsets.all(14),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 820),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 16, 10, 0),
            child: Row(children: [
              Expanded(child: Text('Share as a picture', style: Fonts.display(const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.5)))),
              IconButton(tooltip: 'Close', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 10),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text('The summary and the next steps only. No name, no quoted text and no reference numbers. Look at it before you send it.', style: TextStyle(color: p.inkSoft, height: 1.4, fontSize: 14)),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 4, 22, 8),
              child: Column(children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 380),
                    child: AspectRatio(
                      aspectRatio: ShareCard.width / ShareCard.height,
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: SizedBox(
                          width: ShareCard.width,
                          height: ShareCard.height,
                          child: RepaintBoundary(key: boundary, child: ShareCard(data: data)),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Material(
                  color: p.inset,
                  borderRadius: BorderRadius.circular(16),
                  clipBehavior: Clip.antiAlias,
                  child: SwitchListTile(
                    key: const ValueKey('card-hide'),
                    title: const Text('Hide amounts', style: TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: const Text('Money amounts are covered with dots. Dates stay.'),
                    value: hide,
                    onChanged: (v) => setState(() => hide = v),
                  ),
                ),
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (status.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Semantics(liveRegion: true, child: Text(status, key: const ValueKey('card-status'), style: TextStyle(color: p.mid, fontWeight: FontWeight.w600, height: 1.35))),
                ),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(key: const ValueKey('card-save'), onPressed: busy ? null : _save, icon: const Icon(Icons.download_outlined, size: 18), label: const Text('Save picture')),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(key: const ValueKey('card-share'), onPressed: busy ? null : _share, icon: const Icon(Icons.share_outlined, size: 18), label: const Text('Share')),
                ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}
