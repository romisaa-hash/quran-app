import 'dart:math' as math;

/// طريقة الحساب
class CalcMethod {
  final String id;
  final String name;
  final double fajrAngle;
  final double? ishaAngle;
  final int? ishaMinutes; // دقائق بعد المغرب (مثل أم القرى)
  const CalcMethod(this.id, this.name, this.fajrAngle,
      {this.ishaAngle, this.ishaMinutes});
}

const List<CalcMethod> calcMethods = [
  CalcMethod('egypt', 'الهيئة المصرية العامة للمساحة', 19.5, ishaAngle: 17.5),
  CalcMethod('makkah', 'أم القرى - مكة المكرمة', 18.5, ishaMinutes: 90),
  CalcMethod('mwl', 'رابطة العالم الإسلامي', 18, ishaAngle: 17),
  CalcMethod('karachi', 'جامعة العلوم الإسلامية - كراتشي', 18, ishaAngle: 18),
  CalcMethod('dubai', 'الهيئة العامة للشؤون الإسلامية - دبي', 18.2, ishaAngle: 18.2),
  CalcMethod('kuwait', 'الكويت', 18, ishaAngle: 17.5),
  CalcMethod('qatar', 'قطر', 18, ishaMinutes: 90),
  CalcMethod('isna', 'أمريكا الشمالية (ISNA)', 15, ishaAngle: 15),
];

CalcMethod methodById(String id) =>
    calcMethods.firstWhere((m) => m.id == id, orElse: () => calcMethods.first);

/// اختيار طريقة مناسبة حسب الدولة
String methodForCountry(String? iso) {
  switch ((iso ?? '').toUpperCase()) {
    case 'EG':
    case 'SD':
    case 'LY':
    case 'SY':
    case 'LB':
    case 'IQ':
    case 'JO':
    case 'PS':
      return 'egypt';
    case 'SA':
    case 'YE':
    case 'BH':
    case 'OM':
      return 'makkah';
    case 'AE':
      return 'dubai';
    case 'KW':
      return 'kuwait';
    case 'QA':
      return 'qatar';
    case 'PK':
    case 'IN':
    case 'BD':
    case 'AF':
      return 'karachi';
    case 'US':
    case 'CA':
      return 'isna';
    default:
      return 'mwl';
  }
}

enum Prayer { fajr, sunrise, dhuhr, asr, maghrib, isha }

const Map<Prayer, String> prayerNames = {
  Prayer.fajr: 'الفجر',
  Prayer.sunrise: 'الشروق',
  Prayer.dhuhr: 'الظهر',
  Prayer.asr: 'العصر',
  Prayer.maghrib: 'المغرب',
  Prayer.isha: 'العشاء',
};

class PrayerTimes {
  final DateTime date;
  final Map<Prayer, DateTime> times;
  PrayerTimes(this.date, this.times);

  DateTime operator [](Prayer p) => times[p]!;
}

double _rad(double d) => d * math.pi / 180.0;
double _deg(double r) => r * 180.0 / math.pi;
double _fix(double a, double b) {
  a = a - b * (a / b).floor();
  return a < 0 ? a + b : a;
}

double _fixAngle(double a) => _fix(a, 360);
double _fixHour(double a) => _fix(a, 24);

double _julian(int year, int month, int day) {
  if (month <= 2) {
    year -= 1;
    month += 12;
  }
  final a = (year / 100).floor();
  final b = 2 - a + (a / 4).floor();
  return (365.25 * (year + 4716)).floor() +
      (30.6001 * (month + 1)).floor() +
      day +
      b -
      1524.5;
}

class _SunPos {
  final double decl;
  final double eqt;
  _SunPos(this.decl, this.eqt);
}

_SunPos _sunPosition(double jd) {
  final d = jd - 2451545.0;
  final g = _fixAngle(357.529 + 0.98560028 * d);
  final q = _fixAngle(280.459 + 0.98564736 * d);
  final l = _fixAngle(q + 1.915 * math.sin(_rad(g)) + 0.020 * math.sin(_rad(2 * g)));
  final e = 23.439 - 0.00000036 * d;
  final ra = _fixHour(_deg(math.atan2(math.cos(_rad(e)) * math.sin(_rad(l)), math.cos(_rad(l)))) / 15);
  final eqt = q / 15 - ra;
  final decl = _deg(math.asin(math.sin(_rad(e)) * math.sin(_rad(l))));
  return _SunPos(decl, eqt);
}

/// حساب مواقيت الصلاة ليوم معين
/// asrFactor: 1 = الجمهور (شافعي/مالكي/حنبلي)، 2 = حنفي
PrayerTimes calculatePrayerTimes({
  required DateTime date,
  required double lat,
  required double lng,
  required CalcMethod method,
  int asrFactor = 1,
}) {
  final jDate = _julian(date.year, date.month, date.day) - lng / (15 * 24);

  double midDay(double t) {
    final eqt = _sunPosition(jDate + t).eqt;
    return _fixHour(12 - eqt);
  }

  double sunAngleTime(double angle, double t, {bool ccw = false}) {
    final decl = _sunPosition(jDate + t).decl;
    final noon = midDay(t);
    final x = (-math.sin(_rad(angle)) - math.sin(_rad(decl)) * math.sin(_rad(lat))) /
        (math.cos(_rad(decl)) * math.cos(_rad(lat)));
    final tt = _deg(math.acos(x)) / 15;
    return noon + (ccw ? -tt : tt);
  }

  double asrTime(int factor, double t) {
    final decl = _sunPosition(jDate + t).decl;
    final angle = -_deg(math.atan(1 / (factor + math.tan(_rad((lat - decl).abs())))));
    return sunAngleTime(angle, t);
  }

  // تقديرات أولية بالساعات
  double fajr = 5, sunrise = 6, dhuhr = 12, asr = 13, sunset = 18, isha = 18;

  for (int i = 0; i < 2; i++) {
    final f = fajr / 24, sr = sunrise / 24, dh = dhuhr / 24, asT = asr / 24;
    final ss = sunset / 24, ish = isha / 24;
    fajr = sunAngleTime(method.fajrAngle, f, ccw: true);
    sunrise = sunAngleTime(0.833, sr, ccw: true);
    dhuhr = midDay(dh);
    asr = asrTime(asrFactor, asT);
    sunset = sunAngleTime(0.833, ss);
    isha = method.ishaAngle != null ? sunAngleTime(method.ishaAngle!, ish) : sunset;
  }

  // تعديل خطوط العرض العالية (طريقة نسبة الزاوية)
  final night = _fixHour(sunrise - sunset);
  if (fajr.isNaN || _fixHour(sunrise - fajr) > method.fajrAngle / 60 * night) {
    fajr = sunrise - method.fajrAngle / 60 * night;
  }
  if (method.ishaMinutes != null) {
    isha = sunset + method.ishaMinutes! / 60.0;
  } else {
    final ia = method.ishaAngle!;
    if (isha.isNaN || _fixHour(isha - sunset) > ia / 60 * night) {
      isha = sunset + ia / 60 * night;
    }
  }

  final maghrib = sunset;
  // الظهر بعد الزوال بدقيقة احتياطًا
  dhuhr += 1 / 60;

  DateTime toLocal(double hoursUtcSolar) {
    // الساعات محسوبة بالتوقيت العالمي بعد طرح خط الطول
    final utcHours = hoursUtcSolar - lng / 15;
    final ms = (utcHours * 3600 * 1000).round();
    final base = DateTime.utc(date.year, date.month, date.day);
    final dt = base.add(Duration(milliseconds: ms)).toLocal();
    // تقريب لأقرب دقيقة (للأعلى عند 30 ثانية)
    final rounded = DateTime(dt.year, dt.month, dt.day, dt.hour, dt.minute)
        .add(Duration(minutes: dt.second >= 30 ? 1 : 0));
    return rounded;
  }

  return PrayerTimes(DateTime(date.year, date.month, date.day), {
    Prayer.fajr: toLocal(fajr),
    Prayer.sunrise: toLocal(sunrise),
    Prayer.dhuhr: toLocal(dhuhr),
    Prayer.asr: toLocal(asr),
    Prayer.maghrib: toLocal(maghrib),
    Prayer.isha: toLocal(isha),
  });
}

/// اتجاه القبلة بالدرجات من الشمال الجغرافي
double qiblaDirection(double lat, double lng) {
  const kLat = 21.4225, kLng = 39.8262;
  final dLng = _rad(kLng - lng);
  final y = math.sin(dLng);
  final x = math.cos(_rad(lat)) * math.tan(_rad(kLat)) -
      math.sin(_rad(lat)) * math.cos(dLng);
  return _fixAngle(_deg(math.atan2(y, x)));
}

/// المسافة إلى مكة بالكيلومتر
double distanceToMakkah(double lat, double lng) {
  const kLat = 21.4225, kLng = 39.8262;
  const r = 6371.0;
  final dLat = _rad(kLat - lat);
  final dLng = _rad(kLng - lng);
  final a = math.pow(math.sin(dLat / 2), 2) +
      math.cos(_rad(lat)) * math.cos(_rad(kLat)) * math.pow(math.sin(dLng / 2), 2);
  return 2 * r * math.asin(math.sqrt(a));
}
