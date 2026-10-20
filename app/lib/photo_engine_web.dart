import 'dart:js_interop';
import 'dart:typed_data';

/// web/dalil_img.js: resizes and re-encodes a photo with the browser's own image code.
@JS('dalilImg.shrink')
external JSPromise<JSUint8Array?> _shrink(JSUint8Array bytes, int side, double quality);

/// Returns the shrunk JPEG, or null when the browser could not do it.
Future<Uint8List?> shrinkPhotoFast(Uint8List bytes, {int longSide = 1400, int quality = 82}) async {
  try {
    final out = await _shrink(bytes.toJS, longSide, quality / 100).toDart;
    if (out == null) return null;
    final data = out.toDart;
    return data.isEmpty ? null : data;
  } catch (_) {
    return null;
  }
}
