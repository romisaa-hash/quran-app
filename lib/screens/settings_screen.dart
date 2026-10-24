import 'package:flutter/material.dart';

import '../app_state.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import '../services/prayer_calc.dart';
import '../utils.dart';
import '../widgets/key_scroll.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final st = AppState.instance;
  bool _locating = false;

  Future<void> _apply() async {
    setState(() {});
    await NotificationService.scheduleAll();
  }

  Widget _header(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
        child: Text(t,
            style: const TextStyle(
                color: kGreen, fontWeight: FontWeight.bold, fontSize: 15)),
      );

  Widget _choice({
    required bool selected,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) =>
      ListTile(
        leading: Icon(
          selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
          color: selected ? kGreen : Colors.grey,
        ),
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle),
        onTap: onTap,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: KeyScroll(
          tab: null,
          builder: (context, sc) => ListView(
          controller: sc,
        children: [
          _header('الموقع'),
          ListTile(
            leading: const Icon(Icons.location_on, color: kGreen),
            title: Text(st.hasLocation ? st.cityName : 'غير محدد (مكة المكرمة)'),
            subtitle: Text(
                '${st.lat.toStringAsFixed(3)}, ${st.lng.toStringAsFixed(3)}',
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.right),
            trailing: _locating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.my_location),
            onTap: _locating
                ? null
                : () async {
                    setState(() => _locating = true);
                    final r = await LocationService.updateLocation();
                    if (!context.mounted) return;
                    setState(() => _locating = false);
                    showSnack(context,
                        r.ok ? 'تم تحديث الموقع' : (r.error ?? 'خطأ'));
                    await _apply();
                  },
          ),
          _header('طريقة حساب المواقيت'),
          _choice(
            selected: st.methodIsAuto,
            title: 'تلقائي حسب الدولة',
            subtitle: st.methodIsAuto ? st.method.name : null,
            onTap: () async {
              await st.setMethod(null);
              await _apply();
            },
          ),
          ...calcMethods.map((m) => _choice(
                selected: !st.methodIsAuto && st.methodId == m.id,
                title: m.name,
                onTap: () async {
                  await st.setMethod(m.id);
                  await _apply();
                },
              )),
          _header('حساب العصر'),
          _choice(
            selected: st.asrFactor == 1,
            title: 'الجمهور (الشافعي والمالكي والحنبلي)',
            onTap: () async {
              await st.setAsrFactor(1);
              await _apply();
            },
          ),
          _choice(
            selected: st.asrFactor == 2,
            title: 'الحنفي',
            onTap: () async {
              await st.setAsrFactor(2);
              await _apply();
            },
          ),
          _header('التنبيهات'),
          ...[Prayer.fajr, Prayer.dhuhr, Prayer.asr, Prayer.maghrib, Prayer.isha]
              .map((p) => SwitchListTile(
                    value: st.notify[p] ?? false,
                    title: Text('تنبيه صلاة ${prayerNames[p]}'),
                    activeTrackColor: kGreen,
                    onChanged: (v) async {
                      await st.setNotify(p, v);
                      await _apply();
                    },
                  )),
          SwitchListTile(
            value: st.preAlert,
            title: const Text('تنبيه قبل الأذان بـ ١٠ دقائق'),
            activeTrackColor: kGreen,
            onChanged: (v) async {
              await st.setPreAlert(v);
              await _apply();
            },
          ),
          ListTile(
            leading: const Icon(Icons.alarm_on, color: kGreen),
            title: const Text('السماح بالتنبيه في الوقت المضبوط'),
            subtitle: const Text(
                'لو التنبيه بيتأخر، فعّل الخيار ده من الشاشة اللي هتفتح'),
            onTap: () async {
              await NotificationService.requestExactAlarms();
              await _apply();
            },
          ),
          ListTile(
            leading: const Icon(Icons.notifications_active, color: kGold),
            title: const Text('تجربة التنبيه الآن'),
            onTap: () async {
              await NotificationService.requestPermissions();
              await NotificationService.testNow();
            },
          ),
          _header('عن التطبيق'),
          const ListTile(
            leading: Icon(Icons.info_outline, color: kGreen),
            title: Text('رفيق المسلم - الإصدار ١٫٠'),
            subtitle: Text(
                'صفحات المصحف: مصحف المدينة النبوية (مجمع الملك فهد)\n'
                'التلاوات: موقع mp3quran.net\n'
                'الأذكار: حصن المسلم'),
          ),
          const SizedBox(height: 24),
        ],
      )),
    );
  }
}
