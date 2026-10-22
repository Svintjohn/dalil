import 'dart:js_interop';
import 'dart:typed_data';

/// web/dalil_share.js: the phone's share sheet and a plain download. Both stay in the browser.
@JS('dalilShare.share')
external JSPromise<JSString> _share(JSUint8Array bytes, String name, String mime, String text);
@JS('dalilShare.save')
external bool _save(JSUint8Array bytes, String name, String mime);

/// 'shared' when the share sheet opened with the picture, 'cancelled' when the person closed it,
/// and 'unsupported' when the browser cannot share files (the caller then offers a download).
Future<String> shareImage(Uint8List bytes, String name, String text) async {
  try {
    final r = await _share(bytes.toJS, name, 'image/png', text).toDart;
    return r.toDart;
  } catch (_) {
    return 'unsupported';
  }
}

/// Downloads the picture. False when the browser did not allow it.
bool saveImage(Uint8List bytes, String name) {
  try {
    return _save(bytes.toJS, name, 'image/png');
  } catch (_) {
    return false;
  }
}
