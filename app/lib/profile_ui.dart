import 'package:flutter/material.dart';

import 'cases.dart';
import 'deadlines.dart';
import 'due_soon.dart';
import 'fonts.dart';
import 'motion.dart';
import 'profile.dart';
import 'theme.dart';
import 'widgets.dart';

Future<void> openPersonalize(BuildContext context, [Profile? profile]) =>
    showSpringDialog<void>(context, (_) => PersonalizeDialog(profile: profile));

/// The hello at the top of the page. It asks for a name once, then greets the person in their language.
class HelloStrip extends StatefulWidget {
  const HelloStrip({super.key, required this.languageCode, this.rtl = false, this.profile, this.now});
  final String languageCode;
  final bool rtl;
  final Profile? profile;
  final DateTime? now; // for tests

  @override
  State<HelloStrip> createState() => _HelloStripState();
}

class _HelloStripState extends State<HelloStrip> {
  final name = TextEditingController();

  Profile get profile => widget.profile ?? Profile.instance;

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  void _save() {
    if (cleanName(name.text).isEmpty) return;
    profile.setName(name.text);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: profile,
      builder: (context, _) {
        final Widget child;
        if (profile.hasName) {
          child = _greeting(context);
        } else if (profile.shouldAsk) {
          child = _ask(context);
        } else {
          child = const SizedBox.shrink(key: ValueKey('hello-none'));
        }
        return AnimatedSize(
          duration: Motion.ms(context, 300),
          curve: Curves.easeOutCubic,
          alignment: AlignmentDirectional.topStart,
          child: AnimatedSwitcher(duration: Motion.ms(context, 300), child: child),
        );
      },
    );
  }

  Widget _greeting(BuildContext context) {
    final p = Palette.of(context);
    final sep = widget.rtl ? '، ' : ', ';
    final text = '${greetingFor(widget.languageCode, widget.now ?? DateTime.now())}$sep${profile.name}';
    return Padding(
      key: const ValueKey('hello-greeting'),
      padding: const EdgeInsets.only(bottom: 18),
      child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, children: [
        Icon(Icons.waving_hand_outlined, size: 22, color: p.accent),
        Text(text, textDirection: widget.rtl ? TextDirection.rtl : null, style: Fonts.display(TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.3, color: p.ink))),
        TextButton(
          key: const ValueKey('hello-edit'),
          onPressed: () => openPersonalize(context, profile),
          style: TextButton.styleFrom(foregroundColor: p.inkSoft, minimumSize: const Size(44, 36), textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
          child: const Text('Edit'),
        ),
      ]),
    );
  }

  Widget _ask(BuildContext context) {
    final p = Palette.of(context);
    return Align(
      key: const ValueKey('hello-ask'),
      alignment: AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Container(
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: p.ink.withAlpha(46), width: 1.2)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('What should we call you?', style: Fonts.display(const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.2))),
            const SizedBox(height: 4),
            Text('Only so Dalil can say hello. It stays on this device.', style: TextStyle(color: p.inkSoft, fontSize: 13.5, height: 1.4)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('hello-name'),
                  controller: name,
                  maxLength: 24,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _save(),
                  decoration: const InputDecoration(hintText: 'Your first name', counterText: '', isDense: true),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(key: const ValueKey('hello-save'), onPressed: _save, child: const Text('Say hi')),
            ]),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                key: const ValueKey('hello-skip'),
                onPressed: profile.skipAsking,
                style: TextButton.styleFrom(foregroundColor: p.inkSoft, textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                child: const Text('Not now'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Name, colour and font, in one place. Colour and font change at once; the name is saved with Save or Done.
class PersonalizeDialog extends StatefulWidget {
  const PersonalizeDialog({super.key, this.profile});
  final Profile? profile;

  @override
  State<PersonalizeDialog> createState() => _PersonalizeDialogState();
}

class _PersonalizeDialogState extends State<PersonalizeDialog> {
  late final TextEditingController name;

  Profile get profile => widget.profile ?? Profile.instance;

  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: profile.name);
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  void _saveName() => profile.setName(name.text);

  Widget _swatch(BuildContext context, Accent a) {
    final p = Palette.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final shade = Palette.forAccent(a, dark);
    final on = profile.accent == a;
    return Semantics(
      button: true,
      selected: on,
      label: '${accentLabel(a)} colour',
      excludeSemantics: true,
      child: GestureDetector(
        key: ValueKey('accent-${a.name}'),
        behavior: HitTestBehavior.opaque,
        onTap: () => profile.setAccent(a),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          AnimatedContainer(
            duration: Motion.ms(context, 220),
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: shade.accent, shape: BoxShape.circle, border: Border.all(color: on ? p.ink : p.line, width: on ? 3 : 1)),
            child: on ? Icon(Icons.check, color: shade.onAccent) : null,
          ),
          const SizedBox(height: 6),
          Text(accentLabel(a), style: TextStyle(fontSize: 12.5, fontWeight: on ? FontWeight.w800 : FontWeight.w600, color: on ? p.ink : p.inkSoft)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(14),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 700),
        child: AnimatedBuilder(
          animation: profile,
          builder: (context, _) {
            final p = Palette.of(context);
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Expanded(child: Text('Make it yours', style: Fonts.display(const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -0.6)))),
                  IconButton(tooltip: 'Close', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ]),
                Text('Kept on this device only. Nothing is sent anywhere, and "Clear saved data" removes it.', style: TextStyle(color: p.inkSoft, height: 1.4, fontSize: 14)),
                const SizedBox(height: 20),
                const Text('Your name', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: TextField(
                      key: const ValueKey('profile-name'),
                      controller: name,
                      maxLength: 24,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _saveName(),
                      decoration: const InputDecoration(hintText: 'Your first name', counterText: ''),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(key: const ValueKey('profile-save'), onPressed: _saveName, child: const Text('Save')),
                ]),
                const SizedBox(height: 22),
                const Text('Colour', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                Wrap(spacing: 14, runSpacing: 10, children: [for (final a in Accent.values) _swatch(context, a)]),
                const SizedBox(height: 20),
                Material(
                  color: p.inset,
                  borderRadius: BorderRadius.circular(16),
                  clipBehavior: Clip.antiAlias,
                  child: SwitchListTile(
                    key: const ValueKey('easy-read'),
                    title: const Text('Easy-read font', style: TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: const Text('A wide, open font that many people find easier to read. It is used everywhere in the app.'),
                    value: profile.easyRead,
                    onChanged: profile.setEasyRead,
                  ),
                ),
                const SizedBox(height: 18),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: FilledButton(
                    key: const ValueKey('profile-done'),
                    onPressed: () {
                      if (cleanName(name.text) != profile.name) _saveName();
                      Navigator.pop(context);
                    },
                    style: FilledButton.styleFrom(shape: const StadiumBorder(), padding: const EdgeInsets.symmetric(horizontal: 30)),
                    child: const Text('Done'),
                  ),
                ),
              ]),
            );
          },
        ),
      ),
    );
  }
}

/// "2 due this week", shown in the header only when something is due soon or late.
class DueBadge extends StatelessWidget {
  const DueBadge({super.key, required this.onTap, this.compact = false, this.deadlines, this.cases, this.now});
  final VoidCallback onTap;
  final bool compact; // just the number, for a narrow header
  final ValueNotifier<List<TrackedDeadline>>? deadlines;
  final ValueNotifier<List<CaseFile>>? cases;
  final DateTime? now; // for tests

  @override
  Widget build(BuildContext context) {
    final d = deadlines ?? DeadlineStore.instance.items;
    final c = cases ?? CaseStore.instance.cases;
    return AnimatedBuilder(
      animation: Listenable.merge([d, c]),
      builder: (context, _) {
        final due = dueSoon(d.value, c.value, now: now);
        if (due.count == 0) return const SizedBox.shrink();
        final p = Palette.of(context);
        final isLate = due.overdue > 0;
        final fg = isLate ? p.high : p.accent;
        final bg = isLate ? p.highTint : p.accentTint;
        return Tooltip(
          message: due.tip,
          child: Semantics(
            button: true,
            label: due.label,
            excludeSemantics: true,
            child: Material(
              color: bg,
              shape: const StadiumBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: const ValueKey('due-badge'),
                onTap: onTap,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 14, vertical: 9),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(isLate ? Icons.error_outline : Icons.event_outlined, size: 17, color: fg),
                    const SizedBox(width: 6),
                    Text(compact ? '${due.count}' : due.label, maxLines: 1, style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 14)),
                  ]),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
