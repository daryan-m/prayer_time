import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart'; // ← زیادکرا بۆ debugPrint
import 'package:intl/intl.dart';
import 'package:hijri/hijri_calendar.dart';

// ==================== MODELS ====================

class PrayerTimes {
  final DateTime fajr;
  final DateTime sunrise;
  final DateTime dhuhr;
  final DateTime asr;
  final DateTime maghrib;
  final DateTime isha;
  final String gregorianDate;

  PrayerTimes({
    required this.fajr,
    required this.sunrise,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
    required this.gregorianDate,
  });
}

// ==================== SERVICES ====================

class PrayerDataService {
  Future<PrayerTimes> getPrayerTimes(String city, DateTime date) async {
    try {
      // چێککردنی ساڵی کەبیسە
      bool isLeapYear = _isLeapYear(date.year);

      // دیاریکردنی ناوی فایل بەپێی شار و ساڵی کەبیسە
      String fileName;
      if (city == "پێنجوێن") {
        fileName = isLeapYear ? "penjwen_time_leap.json" : "penjwen_time.json";
      } else {
        fileName = isLeapYear ? "prayer_time_leap.json" : "prayer_time.json";
      }

      debugPrint("Loading: $fileName for ${date.year} (Leap: $isLeapYear)");

      // خوێندنەوەی فایلی JSON
      String jsonString = await rootBundle.loadString('assets/data/$fileName');
      List<dynamic> prayerData = json.decode(jsonString);

      // گەڕان بەپێی بەرواری میلادی
      Map<String, dynamic>? todayPrayer;
      for (var prayer in prayerData) {
        // چاککردنەوەی فۆرماتی بەروار بۆ بەراوردکردن
        String prayerDate = prayer['میلادى'];
        if (_compareDates(prayerDate, date)) {
          todayPrayer = prayer;
          break;
        }
      }

      // ئەگەر نەدۆزرایەوە، یەکەمیان بەکاربهێنە
      todayPrayer ??= prayerData[0]; // ← چاککرایەوە

      return PrayerTimes(
        fajr: _parseTime(date, todayPrayer!['بەیانی']), // ← ! زیادکرا
        sunrise: _parseTime(date, todayPrayer['خۆرهەڵاتن']), // ← ! زیادکرا
        dhuhr: _parseTime(date, todayPrayer['نیوەڕۆ']), // ← ! زیادکرا
        asr: _parseTime(date, todayPrayer['عەسر']), // ← ! زیادکرا
        maghrib: _parseTime(date, todayPrayer['ئێوارە']), // ← ! زیادکرا
        isha: _parseTime(date, todayPrayer['خەوتنان']), // ← ! زیادکرا
        gregorianDate: todayPrayer['میلادى'], // ← ! زیادکرا
      );
    } catch (e) {
      debugPrint("Error loading prayer times: $e"); // ← ئێستا کاردەکات
      // ئەگەر هەڵەیەک ڕوویدا، کاتە سەرەتاییەکان
      return PrayerTimes(
        fajr: DateTime(date.year, date.month, date.day, 5, 0),
        sunrise: DateTime(date.year, date.month, date.day, 6, 30),
        dhuhr: DateTime(date.year, date.month, date.day, 12, 0),
        asr: DateTime(date.year, date.month, date.day, 15, 0),
        maghrib: DateTime(date.year, date.month, date.day, 18, 0),
        isha: DateTime(date.year, date.month, date.day, 19, 30),
        gregorianDate: "01/01/2026",
      );
    }
  }

  bool _compareDates(String jsonDate, DateTime targetDate) {
    try {
      // فۆرماتی JSON: "01 - کانونی دووەم "
      List<String> parts = jsonDate.split(' - ');
      if (parts.length < 2) return false;

      int day = int.parse(parts[0].trim());

      // گۆڕینی ناوی مانگ بۆ ژمارە
      Map<String, int> months = {
        'کانونی دووەم': 1,
        'شوبات': 2,
        'ئادار': 3,
        'نیسان': 4,
        'ئایار': 5,
        'حوزەیران': 6,
        'تەمووز': 7,
        'ئاب': 8,
        'ئەیلول': 9,
        'تشرینی یەکەم': 10,
        'تشرینی دووەم': 11,
        'کانونی یەکەم': 12
      };

      int? month = months[parts[1]
          .trim()
          .replaceAll('\u200f', '')
          .replaceAll('\u200e', '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim()];
      if (month == null) return false;

      return day == targetDate.day && month == targetDate.month;
    } catch (e) {
      return false;
    }
  }

  DateTime _parseTime(DateTime date, String time) {
    try {
      List<String> parts = time.split(':');
      int hour = int.parse(parts[0]);
      int minute = int.parse(parts[1]);

      return DateTime(date.year, date.month, date.day, hour, minute);
    } catch (e) {
      return date;
    }
  }
}

// ← TimeService یەکەم لابرا، تەنها ئەمەی خوارەوە مایەوە
class TimeService {
  TimeService() {
    HijriCalendar.setLocal('ar');
  }
  String toKu(String n) {
    return n
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

  String gregorianDateString(DateTime dt) {
    // فۆرماتی میلادی بە /
    return "\u200E${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}";
  }

  String hijriDateString() {
    var hijriDate = HijriCalendar.now();
    var day = toKu(hijriDate.hDay.toString());
    var month = hijriDate.toFormat("MMMM"); // ناوی مانگەکە وەردەگرێت
    var year = toKu(hijriDate.hYear.toString());

    // لێرەدا پیتى "ی" دەخەینە نێوان ڕۆژ و مانگ
    return "کۆچى: $dayـى $month $year";
  }

  String kurdishDateString(DateTime dt) {
    // فۆرمولای ڕاست بەپێی ساڵنامەی کوردی
    // نەورۆز = ٢١ مارت = ١/١ کوردی

    final months = [
      "نەورۆز", // ١ (٢١ مارت - ١٩ ئەپریل)
      "گوڵان", // ٢ (٢٠ ئەپریل - ٢٠ مای)
      "جۆزەردان", // ٣ (٢١ مای - ٢٠ جوون)
      "پووشپەڕ", // ٤ (٢١ جوون - ٢٢ جولای)
      "گەلاوێژ", // ٥ (٢٣ جولای - ٢٢ ئاگۆست)
      "خەرمانان", // ٦ (٢٣ ئاگۆست - ٢٢ سێپتەمبەر)
      "ڕەزبەر", // ٧ (٢٣ سێپتەمبەر - ٢٢ ئۆکتۆبەر)
      "گەڵاڕێزان", // ٨ (٢٣ ئۆکتۆبەر - ٢١ نۆڤەمبەر)
      "سەرماوەز", // ٩ (٢٢ نۆڤەمبەر - ٢١ دجەمبەر)
      "بەفرانبار", // ١٠ (٢٢ دجەمبەر - ٢٠ یانویەر)
      "ڕێبەندان", // ١١ (٢١ یانویەر - ١٩ فیبرایەر)
      "ڕەشەمە" // ١٢ (٢٠ فیبرایەر - ٢٠ مارت)
    ];

    // سەرەتاکانی هەر مانگێک (مانگ/ڕۆژ)
    final monthStarts = [
      [3, 21], // نەورۆز
      [4, 20], // گوڵان
      [5, 21], // جۆزەردان
      [6, 21], // پووشپەڕ
      [7, 23], // گەلاوێژ
      [8, 23], // خەرمانان
      [9, 23], // ڕەزبەر
      [10, 23], // گەڵاڕێزان
      [11, 22], // سەرماوەز
      [12, 22], // بەفرانبار
      [1, 21], // ڕێبەندان
      [2, 20], // ڕەشەمە
    ];

    int kurdishYear = dt.year + 700;
    int kurdishMonth = 1;
    int kurdishDay = 1;

    // دۆزینەوەی مانگ بەپێی بەروار
    if (dt.month >= 3 && (dt.month > 3 || dt.day >= 21)) {
      // دوای نەورۆز لە هەمان ساڵدا
      for (int i = 0; i < 11; i++) {
        int nextMonth = monthStarts[i + 1][0];
        int nextDay = monthStarts[i + 1][1];

        if (dt.month < nextMonth ||
            (dt.month == nextMonth && dt.day < nextDay)) {
          kurdishMonth = i + 1;
          int startMonth = monthStarts[i][0];
          int startDay = monthStarts[i][1];

          DateTime monthStart = DateTime(dt.year, startMonth, startDay);
          kurdishDay = dt.difference(monthStart).inDays + 1;
          break;
        }
      }
    } else {
      // پێش نەورۆز = ساڵی پێشوو
      kurdishYear = dt.year + 700 - 1;

      if (dt.month == 2 && dt.day >= 20) {
        // ڕەشەمە (٢٠ فیبرایەر - ٢٠ مارت)
        kurdishMonth = 12;
        kurdishDay = dt.day - 20 + 1;
      } else if (dt.month == 1 && dt.day >= 21) {
        // ڕێبەندان (٢١ یانویەر - ١٩ فیبرایەر)
        kurdishMonth = 11;
        kurdishDay = dt.day - 21 + 1;
      } else if (dt.month == 2 && dt.day < 20) {
        // کۆتایی ڕێبەندان
        kurdishMonth = 11;
        kurdishDay = 10 + dt.day + 1;
      } else {
        // مانگەکانی تر
        kurdishMonth = 10;
        kurdishDay = dt.day + 10;
      }
    }

    int monthIndex = kurdishMonth - 1;
    if (monthIndex < 0) monthIndex = 0;
    if (monthIndex > 11) monthIndex = 11;

    return "${toKu(kurdishDay.toString())}ـى ${months[monthIndex]} ${toKu(kurdishYear.toString())}";
  }
}

// ئەم فەنکشنە زیاد بکە
bool _isLeapYear(int year) {
  // ساڵی پڕ ئەو ساڵەیە کە:
  // ١. بەسەر ٤ دابەش دەبێت،
  // ٢. بەسەر ١٠٠ دابەش نابێت، مەگەر بەسەر ٤٠٠یش دابەش ببێت.
  return (year % 4 == 0) && ((year % 100 != 0) || (year % 400 == 0));
}
