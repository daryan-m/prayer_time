import 'package:intl/intl.dart';
import 'package:hijri/hijri_calendar.dart';

import 'prayer_times_model.dart';

class TimeService {
  String toKu(String n) => n
      .replaceAll('0', '٠')
      .replaceAll('1', '١')
      .replaceAll('2', '٢')
      .replaceAll('3', '٣')
      .replaceAll('4', '٤')
      .replaceAll('5', '٥')
      .replaceAll('6', '٦')
      .replaceAll('7', '٧')
      .replaceAll('8', '٨')
      .replaceAll('9', '٩');

  double timeZoneHours() {
    return 3.0;
  }

  String formatTo12Hr(String time24) {
    final parts = time24.split(':');
    if (parts.length < 2) return time24;

    int h = int.tryParse(parts[0]) ?? 0;
    int m = int.tryParse(parts[1]) ?? 0;

    String period = h >= 12 ? "د.ن" : "پ.ن";
    h = h % 12 == 0 ? 12 : h % 12;

    return "${toKu(h.toString().padLeft(2, '0'))}:${toKu(m.toString().padLeft(2, '0'))} $period";
  }

  String nextPrayerRemaining(DateTime now, PrayerTimesModel times) {
    final nowSec = now.hour * 3600 + now.minute * 60 + now.second;

    final list = [
      times.fajr,
      times.dhuhr,
      times.asr,
      times.maghrib,
      times.isha,
    ];

    final seconds = list.map(_timeToSeconds).toList();

    int diff = 0;
    bool found = false;

    for (final s in seconds) {
      if (s > nowSec) {
        diff = s - nowSec;
        found = true;
        break;
      }
    }

    if (!found) diff = (24 * 3600 - nowSec) + seconds[0];

    final h = diff ~/ 3600;
    final m = (diff % 3600) ~/ 60;
    final s = diff % 60;

    return "${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
  }

  String nextPrayerName(DateTime now, PrayerTimesModel times) {
    final nowSec = now.hour * 3600 + now.minute * 60 + now.second;

    final names = ["بەیانی", "نیوەڕۆ", "عەسر", "ئێوارە", "خەوتنان"];

    final list = [
      times.fajr,
      times.dhuhr,
      times.asr,
      times.maghrib,
      times.isha,
    ];

    final seconds = list.map(_timeToSeconds).toList();

    for (int i = 0; i < seconds.length; i++) {
      if (seconds[i] > nowSec) return names[i];
    }
    return names[0];
  }

  int _timeToSeconds(String hhmm) {
    final p = hhmm.split(':');
    final h = int.tryParse(p[0]) ?? 0;
    final m = int.tryParse(p[1]) ?? 0;
    return h * 3600 + m * 60;
  }

  String gregorianDateString(DateTime dt) {
    final f = DateFormat("dd-MM-yyyy");
    return f.format(dt);
  }

  String hijriDateString(DateTime dt) {
    final h = HijriCalendar.fromDate(dt);
    final hijriMonthsKu = [
      "موحەرەم", "سەفەر", "ڕەبیعى یەکەم", "ڕەبیعى دووەم",
      "جەمادی یەکەم", "جەمادی دووەم", "رەجەب", "شەعبان",
      "ڕەمەزان", "شەوال", "ذیقعدە", "ذیحیجە"
    ];
    final monthName = hijriMonthsKu[h.hMonth - 1];
    return "${toKu(h.hDay.toString())} ـی $monthName ${toKu(h.hYear.toString())} کۆچی";
  }

  String kurdishDateString(DateTime dt) {
    final k = _gregorianToKurdish(dt);
    return "${toKu(k.day.toString())}ـی ${k.monthName} ${toKu(k.year.toString())}";
  }

  _Kurdish _gregorianToKurdish(DateTime date) {
    final gY = date.year;
    final gM = date.month;
    final gD = date.day;
    
    int jy;

    final gDaysInMonth = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    bool leap = (gY % 4 == 0 && gY % 100 != 0) || (gY % 400 == 0);
    if (leap) gDaysInMonth[1] = 29;

    int gy = gY - 1600;
    int gm = gM - 1;
    int gd = gD - 1;

    int gDayNo = 365 * gy +
        ((gy + 3) / 4).floor() -
        ((gy + 99) / 100).floor() +
        ((gy + 399) / 400).floor();

    for (int i = 0; i < gm; ++i) {
      gDayNo += gDaysInMonth[i];
    }
    gDayNo += gd;
    int jDayNo = gDayNo - 79;

    int jNp = (jDayNo / 12053).floor();
    jDayNo %= 12053;

    jy = 979 + 33 * jNp + 4 * (jDayNo / 1461).floor();
    jDayNo %= 1461;

    if (jDayNo >= 366) {
      jy += ((jDayNo - 1) / 365).floor();
      jDayNo = (jDayNo - 1) % 365;
    }

    final jDaysInMonth = [31, 31, 31, 31, 31, 31, 30, 30, 30, 30, 30, 29];

    int jm;
    for (jm = 0; jm < 11 && jDayNo >= jDaysInMonth[jm]; ++jm) {
      jDayNo -= jDaysInMonth[jm];
    }
    int jd = jDayNo + 1;

    final kurdishYear = jy + 700;

    return _Kurdish(
      day: jd,
      month: jm + 1,
      year: kurdishYear,
    );
  }

  String formatDuration(Duration d) {
      final h = d.inHours.toString().padLeft(2, '0');
      final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
      final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
      return "$h:$m:$s";
  }
}

class _Kurdish {
  final int day;
  final int month;
  final int year;

  _Kurdish({required this.day, required this.month, required this.year});

  String get monthName {
    const months = [
      "خاکەلێوە", "گوڵان", "جۆزەردان", "پووشپەڕ", "گەلاوێژ", "خەرمانان",
      "ڕەزبەر", "گەڵاڕێزان", "سەرماوەز", "بەفرانبار", "ڕێبەندان", "ڕەشەمە",
    ];
    return months[(month - 1).clamp(0, 11)];
  }
}
