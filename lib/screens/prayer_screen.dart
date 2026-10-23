import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hijri/hijri_calendar.dart';

import '../app_state.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import '../services/prayer_calc.dart';
import '../utils.dart';
import 'settings_screen.dart';

class PrayerScreen extends StatefulWidget {
  const PrayerScreen({super.key});

  @override
  State<PrayerScreen> createState() => _PrayerScreenState();
}

class _PrayerScreenState extends State<PrayerScreen>
    with WidgetsBindingObserver {
  Timer? _timer;
  DateTime _now = DateTime.now();
  bool _locating = false;
  final st = AppState.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    st.addListener(_onSettings);
    WidgetsBinding.instance.addPostFrameCallback((_) => _firstRun());
  }

  Future<void> _firstRun() async {
    if (!st.hasLocation) {
      await _locate(silent: true);
    }
    await NotificationService.requestPermissions();
    await NotificationService.scheduleAll();
  }

  void _onSettings() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      NotificationService.scheduleAll();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    st.removeListener(_onSettings);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _locate({bool silent = false}) async {
    setState(() => _locating = true);
    final r = await LocationService.updateLocation();
    if (!mounted) return;
    setState(() => _locating = false);
    if (r.ok) {
      await NotificationService.scheduleAll();
      if (mounted && !silent) showSnack(context, 'تم تحديث الموقع: ${st.cityName}');
    } else if (r.error != null && mounted) {
      showSnack(context, r.error!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime(_now.year, _now.month, _now.day);
    final times = st.timesFor(today);
    const order = [
      Prayer.fajr,
      Prayer.sunrise,
      Prayer.dhuhr,
      Prayer.asr,
      Prayer.maghrib,
      Prayer.isha,
    ];

    Prayer? next;
    DateTime? nextTime;
    for (final p in order) {
      if (p == Prayer.sunrise) continue;
      if (times[p].isAfter(_now)) {
        next = p;
        nextTime = times[p];
        break;
      }
    }
    if (next == null) {
      final tomorrow = st.timesFor(today.add(const Duration(days: 1)));
      next = Prayer.fajr;
      nextTime = tomorrow[Prayer.fajr];
    }
    final DateTime nt = nextTime ?? times[Prayer.fajr];

    final h = HijriCalendar.fromDate(_now);
    final hijriStr =
        '${ar(h.hDay)} ${hijriMonths[(h.hMonth - 1).clamp(0, 11)]} ${ar(h.hYear)} هـ';

    return Scaffold(
      appBar: AppBar(
        title: const Text('مواقيت الصلاة'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'الإعدادات',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [kGreen, kGreenLight],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                    color: kGreen.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6)),
              ],
            ),
            child: Column(
              children: [
                InkWell(
                  onTap: _locating ? null : () => _locate(),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.location_on, color: kGold, size: 20),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          st.hasLocation ? st.cityName : 'اضغط لتحديد موقعك',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 16),
                        ),
                      ),
                      const SizedBox(width: 6),
                      _locating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.my_location,
                              color: Colors.white70, size: 18),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(hijriStr,
                    style: const TextStyle(
                        color: kGold,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                Text(formatGregorian(_now),
                    style: const TextStyle(color: Colors.white70)),
                const Divider(color: Colors.white24, height: 28),
                Text('الصلاة القادمة: ${prayerNames[next]}',
                    style: const TextStyle(color: Colors.white, fontSize: 18)),
                const SizedBox(height: 6),
                Text(formatDuration(nt.difference(_now)),
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2)),
                Text('عند ${formatTime(nt)}',
                    style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          if (!st.hasLocation)
            Card(
              margin: const EdgeInsets.only(top: 16),
              color: Colors.amber.shade50,
              child: ListTile(
                leading: const Icon(Icons.info_outline, color: Colors.orange),
                title: const Text(
                    'المواقيت معروضة حاليًا لمكة المكرمة. اضغط هنا لتحديد موقعك.'),
                onTap: () => _locate(),
              ),
            ),
          const SizedBox(height: 16),
          ...order.map((p) {
            final isNext = p == next && nextTime == times[p];
            final passed = times[p].isBefore(_now);
            return Card(
              elevation: isNext ? 3 : 0,
              color: isNext ? kGold.withValues(alpha: 0.18) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                    color: isNext ? kGold : Colors.grey.shade200,
                    width: isNext ? 2 : 1),
              ),
              margin: const EdgeInsets.symmetric(vertical: 5),
              child: ListTile(
                leading: Icon(_iconFor(p),
                    color: passed && !isNext ? Colors.grey : kGreen),
                title: Text(prayerNames[p]!,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: isNext ? FontWeight.bold : FontWeight.w500,
                        color: passed && !isNext ? Colors.grey : Colors.black87)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(formatTime(times[p]),
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: passed && !isNext ? Colors.grey : kGreen)),
                    if (p != Prayer.sunrise) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          st.notify[p] == true
                              ? Icons.notifications_active
                              : Icons.notifications_off_outlined,
                          color: st.notify[p] == true ? kGold : Colors.grey,
                        ),
                        onPressed: () async {
                          await st.setNotify(p, !(st.notify[p] ?? false));
                          await NotificationService.scheduleAll();
                        },
                      ),
                    ] else
                      const SizedBox(width: 48),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          Text(
            'طريقة الحساب: ${st.method.name}',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(Prayer p) {
    switch (p) {
      case Prayer.fajr:
        return Icons.nights_stay_outlined;
      case Prayer.sunrise:
        return Icons.light_mode_outlined;
      case Prayer.dhuhr:
        return Icons.wb_sunny;
      case Prayer.asr:
        return Icons.wb_sunny_outlined;
      case Prayer.maghrib:
        return Icons.brightness_6;
      case Prayer.isha:
        return Icons.dark_mode_outlined;
    }
  }
}
