import 'package:flutter/material.dart';

import 'api.dart';
import 'fonts.dart';
import 'models.dart';
import 'theme.dart';

/// "How accurate is Dalil?": the real numbers from the labeled test documents, and what they do not show.
class AccuracyDialog extends StatefulWidget {
  const AccuracyDialog({super.key, required this.api});
  final DalilApi api;

  @override
  State<AccuracyDialog> createState() => _AccuracyDialogState();
}

class _AccuracyDialogState extends State<AccuracyDialog> {
  Accuracy? data;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final a = await widget.api.accuracy();
      if (mounted) setState(() => data = a);
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) setState(() => error = 'The numbers could not be loaded. Try again in a minute.');
    }
  }

  Widget _row(BuildContext context, String key, String label, int part, int whole, {bool lowIsGood = false}) {
    final p = Palette.of(context);
    final f = whole == 0 ? 0.0 : part / whole;
    final good = lowIsGood ? part == 0 : part == whole;
    final color = good ? p.ok : p.mid;
    return Padding(
      key: ValueKey(key),
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, height: 1.35))),
          const SizedBox(width: 12),
          Text('$part of $whole', style: Fonts.display(TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color))),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(value: lowIsGood ? (whole == 0 ? 0 : (whole - part) / whole) : f, minHeight: 8, backgroundColor: p.inset, color: color),
        ),
      ]),
    );
  }

  Widget _block(BuildContext context, String title, String sub, AccuracyPart a, String idp) {
    final p = Palette.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: Fonts.display(const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, letterSpacing: -0.3))),
      const SizedBox(height: 2),
      Text(sub, style: TextStyle(color: p.inkSoft, fontSize: 13.5, height: 1.4)),
      const SizedBox(height: 14),
      _row(context, '$idp-scam', 'Scam-like messages that got a warning', a.scamWarned, a.scamN),
      _row(context, '$idp-alarm', 'Ordinary documents that got a false warning', a.falseAlarms, a.legitN, lowIsGood: true),
      _row(context, '$idp-numbers', 'Bills whose total was checked correctly', a.numCorrect, a.numN),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final a = data;
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 760),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 22),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: Text('How accurate is Dalil?', style: Fonts.display(const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -0.6)))),
              IconButton(tooltip: 'Close', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ]),
            Text('Dalil is tested on made-up documents with a known answer. These are the real results, including what they do not show.', style: TextStyle(color: p.inkSoft, height: 1.45)),
            const SizedBox(height: 20),
            if (a == null && error == null) const Padding(padding: EdgeInsets.symmetric(vertical: 36), child: Center(child: CircularProgressIndicator())),
            if (error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 20), child: Text(error!, key: const ValueKey('accuracy-error'), style: TextStyle(color: p.high, fontWeight: FontWeight.w600))),
            if (a != null) ...[
              _block(context, 'The rule checks', 'Warning signs and bill arithmetic, run exactly as the app runs them.', a.offline, 'offline'),
              const SizedBox(height: 8),
              if (a.live != null)
                _block(
                  context,
                  'With the AI model',
                  'The AI reads every test document${a.liveModel.isEmpty ? '' : ' (${a.liveModel})'}. About ${a.liveSeconds.toStringAsFixed(0)} seconds each${a.liveErrors > 0 ? '; ${a.liveErrors} did not run' : ''}.',
                  a.live!,
                  'live',
                )
              else
                Container(
                  key: const ValueKey('live-missing'),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: p.inset, borderRadius: BorderRadius.circular(14)),
                  child: const Text('A full run with the AI model has not been published yet.', style: TextStyle(height: 1.4)),
                ),
              const SizedBox(height: 18),
              Container(
                key: const ValueKey('accuracy-caveat'),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: p.midTint, borderRadius: BorderRadius.circular(14), border: Border.all(color: p.mid, width: 1.2)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('What these numbers do not show', style: TextStyle(fontWeight: FontWeight.w800, color: p.mid, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text(a.caveat.isEmpty ? 'The test documents were written by the developers. This is not proof of accuracy on real documents.' : a.caveat, style: const TextStyle(height: 1.45)),
                  const SizedBox(height: 8),
                  for (final t in const [
                    'The AI can misread a document. Always confirm with the official office.',
                    'Answers in languages other than the main ones have not been checked by native speakers yet.',
                    'Rules for each country come from official pages and are re-checked from time to time.',
                  ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Padding(padding: const EdgeInsets.only(top: 7), child: Icon(Icons.circle, size: 5, color: p.mid)),
                        const SizedBox(width: 10),
                        Expanded(child: Text(t, style: const TextStyle(height: 1.4, fontSize: 14.5))),
                      ]),
                    ),
                ]),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}
