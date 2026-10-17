import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

Uint8List? prepareForUpload(Uint8List bytes, {int longSide = 1400, int quality = 82}) {
  img.Image? im;
  try {
    im = img.decodeImage(bytes);
  } catch (_) {
    return null;
  }
  if (im == null) return null;
  im = img.bakeOrientation(im);
  final biggest = math.max(im.width, im.height);
  if (biggest > longSide) {
    im = im.width >= im.height ? img.copyResize(im, width: longSide) : img.copyResize(im, height: longSide);
  }
  return Uint8List.fromList(img.encodeJpg(im, quality: quality));
}
