import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services/prayer_calc.dart';

/// حالة التطبيق والإعدادات المحفوظة
class AppState extends ChangeNotifier {
  AppState._();
  static final AppState instance = AppState._();

  late SharedPreferences _p;

  // الموقع (الافتراضي: مكة المكرمة)
  double lat = 21.4225;
  double lng = 39.8262;
  String cityName = 'مكة المكرمة';
  String? countryIso;
  bool hasLocation = false;

  String? _methodId; // null = تلقائي حسب الدولة
  int asrFactor = 1;
  Map<Prayer, bool> notify = {
    Prayer.fajr: true,
    Prayer.dhuhr: true,
    Prayer.asr: true,
    Prayer.maghrib: true,
    Prayer.isha: true,
  };
  bool preAlert = false; // تنبيه قبل الأذان بـ 10 دقائق

  int lastPage = 1;
  List<int> bookmarks = [];

  String? reciterName;
  String? reciterServer;

  double azkarFontSize = 22;

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    lat = _p.getDouble('lat') ?? lat;
    lng = _p.getDouble('lng') ?? lng;
    cityName = _p.getString('city') ?? cityName;
    countryIso = _p.getString('country');
    hasLocation = _p.getBool('hasLocation') ?? false;
    _methodId = _p.getString('method');
    asrFactor = _p.getInt('asr') ?? 1;
    for (final pr in notify.keys.toList()) {
      notify[pr] = _p.getBool('notify_${pr.name}') ?? true;
    }
    preAlert = _p.getBool('preAlert') ?? false;
    lastPage = _p.getInt('lastPage') ?? 1;
    bookmarks = (_p.getStringList('bookmarks') ?? [])
        .map(int.tryParse)
        .whereType<int>()
        .toList();
    reciterName = _p.getString('reciterName');
    reciterServer = _p.getString('reciterServer');
    azkarFontSize = _p.getDouble('azkarFont') ?? 22;
  }

  bool get methodIsAuto => _methodId == null;
  String get methodId => _methodId ?? methodForCountry(countryIso);
  CalcMethod get method => methodById(methodId);

  Future<void> setLocation(double la, double lo, String city, String? iso) async {
    lat = la;
    lng = lo;
    cityName = city;
    countryIso = iso;
    hasLocation = true;
    await _p.setDouble('lat', la);
    await _p.setDouble('lng', lo);
    await _p.setString('city', city);
    if (iso != null) await _p.setString('country', iso);
    await _p.setBool('hasLocation', true);
    notifyListeners();
  }

  Future<void> setMethod(String? id) async {
    _methodId = id;
    if (id == null) {
      await _p.remove('method');
    } else {
      await _p.setString('method', id);
    }
    notifyListeners();
  }

  Future<void> setAsrFactor(int f) async {
    asrFactor = f;
    await _p.setInt('asr', f);
    notifyListeners();
  }

  Future<void> setNotify(Prayer pr, bool v) async {
    notify[pr] = v;
    await _p.setBool('notify_${pr.name}', v);
    notifyListeners();
  }

  Future<void> setPreAlert(bool v) async {
    preAlert = v;
    await _p.setBool('preAlert', v);
    notifyListeners();
  }

  Future<void> setLastPage(int page) async {
    lastPage = page;
    await _p.setInt('lastPage', page);
  }

  Future<void> toggleBookmark(int page) async {
    if (bookmarks.contains(page)) {
      bookmarks.remove(page);
    } else {
      bookmarks.add(page);
      bookmarks.sort();
    }
    await _p.setStringList('bookmarks', bookmarks.map((e) => '$e').toList());
    notifyListeners();
  }

  Future<void> setReciter(String name, String server) async {
    reciterName = name;
    reciterServer = server;
    await _p.setString('reciterName', name);
    await _p.setString('reciterServer', server);
    notifyListeners();
  }

  Future<void> setAzkarFont(double v) async {
    azkarFontSize = v;
    await _p.setDouble('azkarFont', v);
    notifyListeners();
  }

  PrayerTimes timesFor(DateTime day) => calculatePrayerTimes(
        date: day,
        lat: lat,
        lng: lng,
        method: method,
        asrFactor: asrFactor,
      );
}
