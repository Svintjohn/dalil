import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'theme.dart';
import 'widgets.dart';

bool get needsLiveCamera =>
    kIsWeb && defaultTargetPlatform != TargetPlatform.android && defaultTargetPlatform != TargetPlatform.iOS;

Future<XFile?> takePhotoWithCamera(BuildContext context) async {
  final cams = await availableCameras();
  if (cams.isEmpty) throw StateError('no camera');
  final back = cams.where((c) => c.lensDirection == CameraLensDirection.back);
  final ctrl = CameraController(back.isNotEmpty ? back.first : cams.first, ResolutionPreset.high, enableAudio: false);
  await ctrl.initialize(); // asks the browser for permission
  if (!context.mounted) {
    await ctrl.dispose();
    return null;
  }
  try {
    return await showDialog<XFile>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CameraDialog(ctrl: ctrl),
    );
  } finally {
    await ctrl.dispose();
  }
}

class _CameraDialog extends StatefulWidget {
  const _CameraDialog({required this.ctrl});
  final CameraController ctrl;

  @override
  State<_CameraDialog> createState() => _CameraDialogState();
}

class _CameraDialogState extends State<_CameraDialog> {
  bool snapping = false;

  Future<void> _snap() async {
    if (snapping) return;
    setState(() => snapping = true);
    try {
      final f = await widget.ctrl.takePicture();
      if (mounted) Navigator.pop(context, f);
    } catch (_) {
      if (mounted) setState(() => snapping = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final ar = widget.ctrl.value.aspectRatio;
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(20),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 640),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: AspectRatio(
                aspectRatio: ar > 0 ? ar : 4 / 3,
                child: CameraPreview(widget.ctrl),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                  ),
                  Tappable(
                    label: 'Take photo',
                    radius: 40,
                    onTap: _snap,
                    child: Container(
                      width: 68,
                      height: 68,
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)),
                      child: DecoratedBox(decoration: BoxDecoration(shape: BoxShape.circle, color: snapping ? p.accent : Colors.white)),
                    ),
                  ),
                  const SizedBox(width: 64),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
