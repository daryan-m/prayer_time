import 'dart:math';
import 'prayer_times_model.dart';

class PrayerCalcService {
  // Method: Muslim World League (MWL)
  // Fajr: 18°
  // Isha: 17°
  final double fajrAngle = 18.0;
  final double ishaAngle = 17.0;

  PrayerTimesModel calculateForDate({
    required DateTime date,
    required double latitude,
    required double longitude,
    required double timeZoneHours,
  }) {
    // Julian day
    final jd = _julian(date.year, date.month, date.day) - longitude / (15 * 24);

    // Solar declination + equation of time
    final decl = _sunDeclination(jd);
    final eqt = _equationOfTime(jd);

    // Dhuhr
    final dhuhr = 12 + timeZoneHours - longitude / 15 - eqt;

    // Sunrise/Sunset
    final sunrise = dhuhr - _sunAngleTime(0.833, latitude, decl);
    final sunset = dhuhr + _sunAngleTime(0.833, latitude, decl);

    // Fajr/Isha
    final fajr = dhuhr - _sunAngleTime(fajrAngle, latitude, decl);
    final isha = dhuhr + _sunAngleTime(ishaAngle, latitude, decl);

    // Asr (Shafi)
    final asr = dhuhr + _asrTime(1, latitude, decl);

    // Maghrib = sunset
    final maghrib = sunset;

    return PrayerTimesModel(
      fajr: _floatToTime(fajr),
      sunrise: _floatToTime(sunrise),
      dhuhr: _floatToTime(dhuhr),
      asr: _floatToTime(asr),
      maghrib: _floatToTime(maghrib),
      isha: _floatToTime(isha),
    );
  }

  // ---------------- Math ----------------

  double _dtr(double d) => (d * pi) / 180.0;
  double _rtd(double r) => (r * 180.0) / pi;

  double _fixAngle(double a) {
    a = a % 360.0;
    return a < 0 ? a + 360.0 : a;
  }

  double _fixHour(double a) {
    a = a % 24.0;
    return a < 0 ? a + 24.0 : a;
  }

  double _julian(int year, int month, int day) {
    if (month <= 2) {
      year -= 1;
      month += 12;
    }
    final a = (year / 100).floor();
    final b = 2 - a + (a / 4).floor();
    return (365.25 * (year + 4716)).floorToDouble() +
        (30.6001 * (month + 1)).floorToDouble() +
        day +
        b -
        1524.5;
  }

  double _sunDeclination(double jd) {
    final d = jd - 2451545.0;
    final g = _fixAngle(357.529 + 0.98560028 * d);
    final q = _fixAngle(280.459 + 0.98564736 * d);
    final l = _fixAngle(q + 1.915 * sin(_dtr(g)) + 0.020 * sin(_dtr(2 * g)));
    final e = 23.439 - 0.00000036 * d;
    return _rtd(asin(sin(_dtr(e)) * sin(_dtr(l))));
  }

  double _equationOfTime(double jd) {
    final d = jd - 2451545.0;
    final g = _fixAngle(357.529 + 0.98560028 * d);
    final q = _fixAngle(280.459 + 0.98564736 * d);
    final l = _fixAngle(q + 1.915 * sin(_dtr(g)) + 0.020 * sin(_dtr(2 * g)));
    final e = 23.439 - 0.00000036 * d;

    final ra = _rtd(atan2(cos(_dtr(e)) * sin(_dtr(l)), cos(_dtr(l)))) / 15.0;
    return q / 15.0 - _fixHour(ra);
  }

  double _sunAngleTime(double angle, double lat, double decl) {
    final term = (-sin(_dtr(angle)) - sin(_dtr(decl)) * sin(_dtr(lat))) /
        (cos(_dtr(decl)) * cos(_dtr(lat)));
    return (1 / 15.0) * _rtd(acos(term));
  }

  double _asrTime(int factor, double lat, double decl) {
    final angle = -_rtd(atan(1 / (factor + tan((_dtr((lat - decl).abs()))))));
    return _sunAngleTime(angle, lat, decl);
  }

  String _floatToTime(double time) {
    time = _fixHour(time);
    int h = time.floor();
    int m = ((time - h) * 60).round();
    if (m == 60) {
      h += 1;
      m = 0;
    }
    return "${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}";
  }
}
