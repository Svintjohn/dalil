import 'package:flutter/material.dart';

import 'motion.dart';
import 'sfx.dart';
import 'sound_studio.dart' deferred as studio;
import 'theme.dart';
import 'widgets.dart';

/// Opens the sound studio. Its code is a separate download that only starts when it is first needed,
/// so people who never open it never download it.
Future<void> openSoundStudio(BuildContext context, [Sfx? sfx]) async {
  try {
    await studio.loadLibrary();
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open the sound studio. Check your connection and try again.')));
    }
    return;
  }
  if (!context.mounted) return;
  await showSpringDialog<void>(context, (_) => studio.SoundStudio(sfx: sfx));
}

/// The small floating button that opens the sound studio.
class SoundPill extends StatelessWidget {
  const SoundPill({super.key, Sfx? sfx}) : _sfx = sfx;
  final Sfx? _sfx;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final sfx = _sfx ?? Sfx.instance;
    return AnimatedBuilder(
      animation: sfx,
      builder: (context, _) {
        final on = sfx.enabled;
        return Semantics(
          button: true,
          label: 'Sound studio',
          child: Pressable(
            child: Material(
              color: on ? p.accent : p.surface,
              shape: StadiumBorder(side: BorderSide(color: on ? p.accent : p.ink.withAlpha(60), width: 1.2)),
              elevation: 0,
              child: InkWell(
                key: const ValueKey('sound-pill'),
                customBorder: const StadiumBorder(),
                onTap: () => openSoundStudio(context, sfx),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(on ? Icons.graphic_eq : Icons.volume_off_outlined, size: 19, color: on ? p.onAccent : p.ink),
                    const SizedBox(width: 8),
                    Text('Sound', style: TextStyle(fontWeight: FontWeight.w700, color: on ? p.onAccent : p.ink)),
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

/// Plays the click sound for a tap or click anywhere in the app (when the person has turned it on).
/// A drag or a scroll is not a tap, so it stays silent.
class TapSounds extends StatefulWidget {
  const TapSounds({super.key, required this.child, this.sfx});
  final Widget child;
  final Sfx? sfx;

  @override
  State<TapSounds> createState() => _TapSoundsState();
}

class _TapSoundsState extends State<TapSounds> {
  Offset? _down;
  DateTime _at = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (e) {
        _down = e.position;
        _at = DateTime.now();
      },
      onPointerUp: (e) {
        final d = _down;
        _down = null;
        if (d == null) return;
        final quick = DateTime.now().difference(_at) < const Duration(milliseconds: 600);
        if (quick && (e.position - d).distance < 12) (widget.sfx ?? Sfx.instance).tap();
      },
      onPointerCancel: (_) => _down = null,
      child: widget.child,
    );
  }
}
