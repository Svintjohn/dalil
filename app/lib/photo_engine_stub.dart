import 'dart:typed_data';

/// Outside the browser there is no fast path, so the caller uses the Dart code in photo.dart.
Future<Uint8List?> shrinkPhotoFast(Uint8List bytes, {int longSide = 1400, int quality = 82}) async => null;
