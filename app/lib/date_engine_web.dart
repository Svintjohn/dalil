import 'dart:js_interop';

/// web/dalil_date.js: "month-day" in the Islamic calendar, such as "9-14".
@JS('dalilHijri')
external String _hijri(double ms);

String hijriNow(DateTime now) {
  try {
    return _hijri(now.millisecondsSinceEpoch.toDouble());
  } catch (_) {
    return '';
  }
}
