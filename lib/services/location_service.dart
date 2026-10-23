import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../app_state.dart';

class LocationResult {
  final bool ok;
  final String? error;
  LocationResult.ok()
      : ok = true,
        error = null;
  LocationResult.fail(this.error) : ok = false;
}

class LocationService {
  /// تحديد الموقع الحالي وحفظه
  static Future<LocationResult> updateLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return LocationResult.fail('خدمة الموقع (GPS) مقفولة. شغّلها من إعدادات الموبايل.');
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied) {
        return LocationResult.fail('لازم تسمح للتطبيق بالوصول للموقع عشان نحسب المواقيت.');
      }
      if (perm == LocationPermission.deniedForever) {
        await Geolocator.openAppSettings();
        return LocationResult.fail('إذن الموقع مرفوض. افتح الإعدادات واسمح بالموقع.');
      }

      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 20),
          ),
        );
      } catch (_) {
        pos = await Geolocator.getLastKnownPosition();
      }
      if (pos == null) {
        return LocationResult.fail('تعذّر تحديد الموقع. حاول مرة تانية في مكان مفتوح.');
      }

      String city = 'موقعي الحالي';
      String? iso;
      try {
        final marks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
        if (marks.isNotEmpty) {
          final m = marks.first;
          final parts = [m.locality, m.administrativeArea, m.country]
              .where((e) => e != null && e.trim().isNotEmpty)
              .cast<String>()
              .toList();
          if (parts.isNotEmpty) city = parts.take(2).join('، ');
          iso = m.isoCountryCode;
        }
      } catch (_) {}

      await AppState.instance.setLocation(pos.latitude, pos.longitude, city, iso);
      return LocationResult.ok();
    } catch (e) {
      return LocationResult.fail('حصل خطأ أثناء تحديد الموقع.');
    }
  }
}
