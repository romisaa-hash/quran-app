import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../app_state.dart';
import '../services/prayer_calc.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  static bool get _isIOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  static Future<void> init() async {
    if (_ready || kIsWeb) return;
    tzdata.initializeTimeZones();
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(settings: settings);
    _ready = true;
  }

  static Future<void> requestPermissions() async {
    if (kIsWeb) return;
    await init();
    if (_isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();
    } else if (_isIOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      await ios?.requestPermissions(alert: true, badge: true, sound: true);
    }
  }

  /// طلب إذن التنبيه في الوقت المضبوط (أندرويد 12+)
  static Future<void> requestExactAlarms() async {
    if (!_isAndroid) return;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestExactAlarmsPermission();
  }

  static Future<bool> _canExact() async {
    if (!_isAndroid) return true;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await android?.canScheduleExactNotifications() ?? false;
    } catch (_) {
      return false;
    }
  }

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'adhan_channel',
      'مواقيت الصلاة',
      channelDescription: 'تنبيهات دخول وقت الصلاة',
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.alarm,
    ),
    iOS: DarwinNotificationDetails(presentSound: true, presentAlert: true),
  );

  static const _preDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'pre_adhan_channel',
      'تنبيه قبل الأذان',
      channelDescription: 'تنبيه قبل دخول وقت الصلاة بعشر دقائق',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    ),
    iOS: DarwinNotificationDetails(),
  );

  /// جدولة تنبيهات الأيام القادمة
  static Future<void> scheduleAll() async {
    if (kIsWeb) return;
    try {
      await init();
      await _plugin.cancelAll();
      final st = AppState.instance;
      final exact = await _canExact();
      final mode = exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;
      final days = st.preAlert ? 5 : 7; // حد iOS = 64 تنبيه
      final now = DateTime.now();
      int id = 0;
      const prayers = [
        Prayer.fajr,
        Prayer.dhuhr,
        Prayer.asr,
        Prayer.maghrib,
        Prayer.isha,
      ];
      for (int d = 0; d < days; d++) {
        final day = DateTime(now.year, now.month, now.day).add(Duration(days: d));
        final times = st.timesFor(day);
        for (final pr in prayers) {
          if (st.notify[pr] != true) continue;
          final t = times[pr];
          final name = prayerNames[pr]!;
          final isFriday = t.weekday == DateTime.friday && pr == Prayer.dhuhr;
          if (t.isAfter(now)) {
            await _schedule(
              id++,
              isFriday ? 'حان الآن موعد صلاة الجمعة' : 'حان الآن موعد صلاة $name',
              'حسب توقيت ${st.cityName}',
              t,
              _details,
              mode,
            );
          }
          if (st.preAlert) {
            final pre = t.subtract(const Duration(minutes: 10));
            if (pre.isAfter(now)) {
              await _schedule(id++, 'باقي ١٠ دقائق على صلاة $name',
                  'استعد للصلاة', pre, _preDetails, mode);
            }
          }
        }
      }
    } catch (_) {
      // تجاهل أي خطأ في الجدولة حتى لا يتوقف التطبيق
    }
  }

  static Future<void> _schedule(int id, String title, String body, DateTime at,
      NotificationDetails details, AndroidScheduleMode mode) async {
    final when = tz.TZDateTime.from(at, tz.UTC);
    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: when,
        notificationDetails: details,
        androidScheduleMode: mode,
      );
    } catch (_) {
      if (mode != AndroidScheduleMode.inexactAllowWhileIdle) {
        await _plugin.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: when,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    }
  }

  static Future<void> testNow() async {
    if (kIsWeb) return;
    await init();
    await _plugin.show(
      id: 9999,
      title: 'تجربة التنبيه',
      body: 'التنبيهات شغالة تمام ✅',
      notificationDetails: _details,
    );
  }
}
