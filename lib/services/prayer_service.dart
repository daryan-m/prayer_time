import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:hijri/hijri_calendar.dart';
import '../utils/constants.dart';

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

// ==================== DATA SERVICE ====================

class PrayerDataService {
  Future<PrayerTimes> getPrayerTimes(
      String cityDisplayName, DateTime date) async {
    try {
      final CityConfig? config = getCityConfig(cityDisplayName);

      // ئەگەر شار نەدۆزرایەوە یان فایلەکەی تازە نییە
      if (config == null || !config.hasFile) {
        debugPrint("City '$cityDisplayName' has no data file yet.");
        return _fallback(date);
      }

      final String fileName = '${config.jsonFile}.json';
      debugPrint("Loading: $fileName");

      final String jsonString =
          await rootBundle.loadString('assets/data/$fileName');
      final Map<String, dynamic> cityData = json.decode(jsonString);

      // ── فۆرماتی JSON نوێ: {city, source, months:[{month, days:[{day,fajr,...}]}]} ──
      final List<dynamic> months = cityData['months'];

      // دۆزینەوەی مانگ و ڕۆژ
      Map<String, dynamic>? todayEntry;

      // ١. فانکشنێک بۆ گەڕان بەدوای داتای ڕۆژێکی دیاریکراو
      Map<String, dynamic>? findDay(int m, int d) {
        try {
          for (final monthData in months) {
            if (monthData['month'] == m) {
              final List<dynamic> days = monthData['days'];
              for (final dayData in days) {
                if (dayData['day'] == d) return dayData;
              }
            }
          }
        } catch (e) {
          return null;
        }
        return null;
      }

      // ٢. کاتژمێر ١٢ی شەو کە بەروار دەگۆڕێت، یەکەمجار هەوڵ دەدات داتای "ئەمڕۆ" بدۆزێتەوە
      todayEntry = findDay(date.month, date.day);

      // ٣. گرنگترین بەش: ئەگەر داتای ئەمڕۆی نەدۆزییەوە (بۆ نموونە ٢١/٤ کێشەی تێدابوو)
      // با یەکسەر بگەڕێتەوە بۆ داتای دوێنێ (واتە ٢٠/٤)
      if (todayEntry == null) {
        debugPrint(
            "داتای ئەمڕۆ نەدۆزرایەوە، ئەپەکە لەسەر داتای دوێنێ دەمێنێتەوە");
        DateTime yesterday = date.subtract(const Duration(days: 1));
        todayEntry = findDay(yesterday.month, yesterday.day);
      }

      // ٤. ئەگەر فایلەکە بە تەواوی کێشەی تێدا بوو (وەک دوا هەوڵ)
      todayEntry ??= (months[0]['days'] as List).first;

      return PrayerTimes(
        fajr: _parseTime(date, todayEntry!['fajr']),
        sunrise: _parseTime(date, todayEntry['sunrise']),
        dhuhr: _parseTime(date, todayEntry['dhuhr'], isAfternoon: true),
        asr: _parseTime(date, todayEntry['asr'], isAfternoon: true),
        maghrib: _parseTime(date, todayEntry['maghrib'], isAfternoon: true),
        isha: _parseTime(date, todayEntry['isha'], isAfternoon: true),
        gregorianDate:
            '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}',
      );
    } catch (e) {
      debugPrint("Error loading prayer times: $e");
      return _fallback(date);
    }
  }

  // ── پارسکردنی کات ──────────────────────────────────
  // JSON کاتەکان وەک "05:41" یان "02:39" (12h بەبێ AM/PM)
  // نیوەڕۆ، عەسر، ئێوارە، خەوتنان: ئەگەر < 12 بوو +12 دەکرێت
  DateTime _parseTime(DateTime date, String time, {bool isAfternoon = false}) {
    try {
      final List<String> parts = time.split(':');
      int hour = int.parse(parts[0]);
      final int minute = int.parse(parts[1]);

      if (isAfternoon && hour < 12) {
        hour += 12;
      }

      return DateTime(date.year, date.month, date.day, hour, minute);
    } catch (e) {
      return date;
    }
  }

  // ── کاتە سەرەتاییەکان کاتی هەڵە ──────────────────
  PrayerTimes _fallback(DateTime date) {
    return PrayerTimes(
      fajr: DateTime(date.year, date.month, date.day, 5, 0),
      sunrise: DateTime(date.year, date.month, date.day, 6, 30),
      dhuhr: DateTime(date.year, date.month, date.day, 12, 0),
      asr: DateTime(date.year, date.month, date.day, 15, 0),
      maghrib: DateTime(date.year, date.month, date.day, 18, 0),
      isha: DateTime(date.year, date.month, date.day, 19, 30),
      gregorianDate: '01/01/2026',
    );
  }
}

// ==================== TIME SERVICE ====================

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
    final int m = int.tryParse(parts[1]) ?? 0;
    final String period = h >= 12 ? "د.ن" : "پ.ن";
    h = h % 12 == 0 ? 12 : h % 12;
    return "${toKu(h.toString().padLeft(2, '0'))}:${toKu(m.toString().padLeft(2, '0'))} $period";
  }

  String gregorianDateString(DateTime dt) {
    return "\u200E${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}";
  }

  String hijriDateString() {
    final hijriDate = HijriCalendar.now();
    final day = toKu(hijriDate.hDay.toString());
    final month = hijriDate.toFormat("MMMM");
    final year = toKu(hijriDate.hYear.toString());
    return "کۆچى: $dayـى $month $year";
  }

  String kurdishDateString(DateTime dt) {
    const List<String> months = [
      "نەورۆز",
      "گوڵان",
      "جۆزەردان",
      "پووشپەڕ",
      "گەلاوێژ",
      "خەرمانان",
      "ڕەزبەر",
      "گەڵاڕێزان",
      "سەرماوەز",
      "بەفرانبار",
      "ڕێبەندان",
      "ڕەشەمە",
    ];

    int kYear, kMonth, kDay;
    final DateTime noroz = DateTime(dt.year, 3, 21);

    if (dt.isBefore(noroz)) {
      kYear = dt.year + 700 - 1;
      final DateTime previousNoroz = DateTime(dt.year - 1, 3, 21);
      final int diff = dt.difference(previousNoroz).inDays;
      if (diff < 186) {
        kMonth = (diff ~/ 31) + 1;
        kDay = (diff % 31) + 1;
      } else {
        final int r = diff - 186;
        kMonth = (r ~/ 30) + 7;
        kDay = (r % 30) + 1;
      }
    } else {
      kYear = dt.year + 700;
      final int diff = dt.difference(noroz).inDays;
      if (diff < 186) {
        kMonth = (diff ~/ 31) + 1;
        kDay = (diff % 31) + 1;
      } else {
        final int r = diff - 186;
        kMonth = (r ~/ 30) + 7;
        kDay = (r % 30) + 1;
      }
    }

    if (kMonth > 12) kMonth = 12;
    return "${toKu(kDay.toString())}ـى ${months[kMonth - 1]} ${toKu(kYear.toString())}";
  }
}
