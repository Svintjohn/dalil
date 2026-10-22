import 'dart:typed_data';

/// Outside the browser there is no share sheet and nothing to save to, so both report that they did nothing.
Future<String> shareImage(Uint8List bytes, String name, String text) async => 'unsupported';

bool saveImage(Uint8List bytes, String name) => false;
