import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';

import '../app_state.dart';
import '../services/location_service.dart';
import '../services/prayer_calc.dart';
import '../utils.dart';
import '../widgets/key_scroll.dart';

class QiblaScreen extends StatefulWidget {
  const QiblaScreen({super.key});

  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends State<QiblaScreen> {
  StreamSubscription? _sub;
  double? _heading;
  bool _noSensor = false;
  bool _wasAligned = false;
  bool _locating = false;
  final st = AppState.instance;

  @override
  void initState() {
    super.initState();
    Stream<CompassEvent>? events;
    try {
      events = kIsWeb ? null : FlutterCompass.events;
    } catch (_) {
      events = null;
    }
    if (events == null) {
      _noSensor = true;
    } else {
      _sub = events.listen((e) {
        if (!mounted) return;
        if (e.heading == null) {
          setState(() => _noSensor = true);
          return;
        }
        setState(() => _heading = e.heading);
      });
    }
    st.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _sub?.cancel();
    st.removeListener(_refresh);
    super.dispose();
  }

  Future<void> _locate() async {
    setState(() => _locating = true);
    final r = await LocationService.updateLocation();
    if (!mounted) return;
    setState(() => _locating = false);
    if (!r.ok && r.error != null) showSnack(context, r.error!);
  }

  @override
  Widget build(BuildContext context) {
    final qibla = qiblaDirection(st.lat, st.lng);
    final dist = distanceToMakkah(st.lat, st.lng);
    final heading = _heading ?? 0;
    double diff = (qibla - heading) % 360;
    if (diff > 180) diff -= 360;
    final aligned = _heading != null && diff.abs() <= 3;
    if (aligned && !_wasAligned) HapticFeedback.heavyImpact();
    _wasAligned = aligned;

    return Scaffold(
      appBar: AppBar(title: const Text('اتجاه القبلة')),
      body: KeyScroll(
          tab: 4,
          builder: (context, sc) => ListView(
          controller: sc,
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.location_on, color: kGreen),
              Flexible(
                child: Text(st.hasLocation ? st.cityName : 'لم يتم تحديد الموقع',
                    style: const TextStyle(fontSize: 16)),
              ),
              TextButton(
                onPressed: _locating ? null : _locate,
                child: Text(_locating ? 'جارِ التحديد...' : 'تحديث'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              aligned
                  ? 'أنت متجه للقبلة ✅'
                  : _noSensor
                      ? 'جهازك لا يحتوي على بوصلة'
                      : 'لف الموبايل ببطء حتى يصبح السهم لأعلى',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: aligned ? kGreen : Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 24),
          AspectRatio(
            aspectRatio: 1,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // قرص البوصلة يدور عكس اتجاه الجهاز
                Transform.rotate(
                  angle: -heading * math.pi / 180,
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: _DialPainter(qibla: qibla, aligned: aligned),
                  ),
                ),
                // مؤشر أعلى الشاشة
                const Align(
                  alignment: Alignment.topCenter,
                  child: Icon(Icons.arrow_drop_down, size: 48, color: kGreen),
                ),
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: aligned ? kGreen : Colors.white,
                    border: Border.all(color: kGold, width: 3),
                  ),
                  child: const Center(
                      child: Text('🕋', style: TextStyle(fontSize: 30))),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Card(
            color: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.shade200)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _row('اتجاه القبلة', '${ar(qibla.toStringAsFixed(1))}° من الشمال'),
                  const Divider(),
                  _row('المسافة إلى مكة', '${ar(dist.round())} كم'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'نصيحة: ابعد الموبايل عن الأجهزة المعدنية والمغناطيس، ولو البوصلة مش دقيقة حرّك الموبايل على شكل رقم 8 في الهوا.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
        ],
      )),
    );
  }

  Widget _row(String a, String b) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(a, style: const TextStyle(fontSize: 16)),
          Text(b,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: kGreen)),
        ],
      );
}

class _DialPainter extends CustomPainter {
  final double qibla;
  final bool aligned;
  _DialPainter({required this.qibla, required this.aligned});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = math.min(size.width, size.height) / 2 - 8;

    canvas.drawCircle(c, r, Paint()..color = Colors.white);
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..color = kGold
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4);

    // علامات الدرجات
    for (int d = 0; d < 360; d += 10) {
      final a = (d - 90) * math.pi / 180;
      final len = d % 90 == 0 ? 18.0 : (d % 30 == 0 ? 12.0 : 6.0);
      final p1 = c + Offset(math.cos(a), math.sin(a)) * r;
      final p2 = c + Offset(math.cos(a), math.sin(a)) * (r - len);
      canvas.drawLine(
          p1,
          p2,
          Paint()
            ..color = d % 90 == 0 ? kGreen : Colors.grey
            ..strokeWidth = d % 90 == 0 ? 3 : 1.5);
    }

    // الجهات
    const labels = {0: 'ش', 90: 'ق', 180: 'ج', 270: 'غ'};
    labels.forEach((deg, label) {
      final a = (deg - 90) * math.pi / 180;
      final pos = c + Offset(math.cos(a), math.sin(a)) * (r - 36);
      final tp = TextPainter(
        text: TextSpan(
            text: label,
            style: TextStyle(
                color: deg == 0 ? Colors.red : kGreen,
                fontSize: 20,
                fontWeight: FontWeight.bold)),
        textDirection: TextDirection.rtl,
      )..layout();
      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    });

    // سهم القبلة
    final qa = (qibla - 90) * math.pi / 180;
    final tip = c + Offset(math.cos(qa), math.sin(qa)) * (r - 20);
    final paint = Paint()
      ..color = aligned ? kGreen : kGold
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(c, tip, paint);
    final head = Path();
    final left = tip + Offset(math.cos(qa + 2.6), math.sin(qa + 2.6)) * 26;
    final right = tip + Offset(math.cos(qa - 2.6), math.sin(qa - 2.6)) * 26;
    head
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(left.dx, left.dy)
      ..lineTo(right.dx, right.dy)
      ..close();
    canvas.drawPath(head, Paint()..color = aligned ? kGreen : kGold);
  }

  @override
  bool shouldRepaint(covariant _DialPainter old) =>
      old.qibla != qibla || old.aligned != aligned;
}
