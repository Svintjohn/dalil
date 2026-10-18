/// Used outside the browser (for example in tests): keeps values in memory only.
class LocalStore {
  static final Map<String, String> _data = {};

  static String? read(String key) => _data[key];

  static void write(String key, String value) => _data[key] = value;

  static void remove(String key) => _data.remove(key);

  static void clearAll() => _data.clear();
}
