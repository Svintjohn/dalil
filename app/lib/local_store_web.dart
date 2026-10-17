import 'package:web/web.dart' as web;

/// Saves small values in the browser on this device. Nothing is sent anywhere.
class LocalStore {
  static String? read(String key) {
    try {
      return web.window.localStorage.getItem(key);
    } catch (_) {
      return null;
    }
  }

  static void write(String key, String value) {
    try {
      web.window.localStorage.setItem(key, value);
    } catch (_) {}
  }

  static void clearAll() {}
}
