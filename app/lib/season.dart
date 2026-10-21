import 'package:flutter/foundation.dart';

import 'date_engine.dart';
import 'local_store.dart';

/// A holiday that gets a few quiet decorations.
enum Season { none, halloween, christmas, newYear, uaeDay, ramadan, eid }

/// Which season a date falls in. [hijri] is "month-day" in the Islamic calendar ("" when unknown),
/// and [gulf] is true for people whose clock is on Gulf time, where the UAE National Day is celebrated.
Season seasonFor(DateTime d, {String hijri = '', bool gulf = false}) {
  final m = d.month, day = d.day;
  if ((m == 12 && day >= 30) || (m == 1 && day <= 2)) return Season.newYear;
  if (gulf && m == 12 && (day == 2 || day == 3)) return Season.uaeDay;
  final parts = hijri.split('-');
  if (parts.length == 2) {
    final hm = int.tryParse(parts[0]), hd = int.tryParse(parts[1]);
    if (hm != null && hd != null) {
      if ((hm == 10 && hd <= 3) || (hm == 12 && hd >= 10 && hd <= 13)) return Season.eid;
      if (hm == 9) return Season.ramadan;
    }
  }
  if ((m == 10 && day >= 24) || (m == 11 && day == 1)) return Season.halloween;
  if (m == 12 && day <= 26) return Season.christmas;
  return Season.none;
}

Season? seasonByName(String? name) {
  switch ((name ?? '').toLowerCase()) {
    case 'halloween':
      return Season.halloween;
    case 'christmas':
      return Season.christmas;
    case 'newyear':
      return Season.newYear;
    case 'uae':
      return Season.uaeDay;
    case 'ramadan':
      return Season.ramadan;
    case 'eid':
      return Season.eid;
    case 'off':
    case 'none':
      return Season.none;
  }
  return null;
}

/// Today's season from the device clock (no location is asked for). Adding `?season=christmas` to the address previews one.
Season currentSeason({DateTime? now, String? preview}) {
  final n = now ?? DateTime.now();
  final forced = seasonByName(preview ?? Uri.base.queryParameters['season']);
  if (forced != null) return forced;
  return seasonFor(n, hijri: hijriNow(n), gulf: n.timeZoneOffset == const Duration(hours: 4));
}

String seasonName(Season s) {
  switch (s) {
    case Season.halloween:
      return 'Halloween';
    case Season.christmas:
      return 'Christmas';
    case Season.newYear:
      return 'New Year';
    case Season.uaeDay:
      return 'UAE National Day';
    case Season.ramadan:
      return 'Ramadan';
    case Season.eid:
      return 'Eid';
    case Season.none:
      return '';
  }
}

/// Whether the person wants the decorations. On by default; one tap turns them off.
class SeasonSettings extends ChangeNotifier {
  SeasonSettings({String storageKey = 'dalil.season.v1'}) : _key = storageKey;
  static final SeasonSettings instance = SeasonSettings();

  final String _key;
  bool enabled = true;

  void load() {
    enabled = LocalStore.read(_key) != 'off';
    notifyListeners();
  }

  void setEnabled(bool on) {
    enabled = on;
    if (on) {
      LocalStore.remove(_key);
    } else {
      LocalStore.write(_key, 'off');
    }
    notifyListeners();
  }

  void wipe() {
    enabled = true;
    LocalStore.remove(_key);
    notifyListeners();
  }
}
