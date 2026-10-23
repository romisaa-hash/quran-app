import 'package:flutter/material.dart';

const Color kGreen = Color(0xFF0F4C3A);
const Color kGreenLight = Color(0xFF1B6B53);
const Color kGold = Color(0xFFC9A227);
const Color kCream = Color(0xFFFBF7EE);

const _arDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

/// تحويل الأرقام إلى أرقام عربية
String ar(Object value) {
  final s = value.toString();
  final b = StringBuffer();
  for (final ch in s.split('')) {
    final d = int.tryParse(ch);
    b.write(d != null && ch.codeUnitAt(0) < 128 ? _arDigits[d] : ch);
  }
  return b.toString();
}

String two(int n) => n.toString().padLeft(2, '0');

/// تنسيق الوقت 12 ساعة: ٤:٣٥ م
String formatTime(DateTime t) {
  int h = t.hour % 12;
  if (h == 0) h = 12;
  final suffix = t.hour < 12 ? 'ص' : 'م';
  return '${ar(h)}:${ar(two(t.minute))} $suffix';
}

String formatDuration(Duration d) {
  if (d.isNegative) d = Duration.zero;
  final h = d.inHours;
  final m = d.inMinutes % 60;
  final s = d.inSeconds % 60;
  return ar('${two(h)}:${two(m)}:${two(s)}');
}

String formatMediaDuration(Duration d) {
  final m = d.inMinutes;
  final s = d.inSeconds % 60;
  return ar('$m:${two(s)}');
}

const List<String> arWeekdays = [
  'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد',
];

const List<String> arMonths = [
  'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس',
  'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
];

const List<String> hijriMonths = [
  'محرم', 'صفر', 'ربيع الأول', 'ربيع الآخر', 'جمادى الأولى', 'جمادى الآخرة',
  'رجب', 'شعبان', 'رمضان', 'شوال', 'ذو القعدة', 'ذو الحجة',
];

String formatGregorian(DateTime d) =>
    '${arWeekdays[d.weekday - 1]} ${ar(d.day)} ${arMonths[d.month - 1]} ${ar(d.year)}';

void showSnack(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));
}
