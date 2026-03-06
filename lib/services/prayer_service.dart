import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:hijri/hijri_calendar.dart';

// ==================== HELPERS ====================

bool isLeapYear(int year) {
  return (year % 4 == 0) && ((year % 100 != 0) || (year % 400 == 0));
}

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
  Future<PrayerTimes> getPrayerTimes(String city, DateTime date) async {
    try {
      final bool leap = isLeapYear(date.year);

      String fileName;
      if (city == "پێنجوێن") {
        fileName = leap ? "penjwen_time_leap.json" : "penjwen_time.json";
      } else {
        fileName = leap ? "prayer_time_leap.json" : "prayer_time.json";
      }

      debugPrint("Loading: $fileName for ${date.year} (Leap: $leap)");

      final String jsonString =
          await rootBundle.loadString('assets/data/$fileName');
      final List<dynamic> prayerData = json.decode(jsonString);

      Map<String, dynamic>? todayPrayer;
      for (var prayer in prayerData) {
        if (_compareDates(prayer['میلادى'], date)) {
          todayPrayer = prayer;
          break;
        }
      }

      todayPrayer ??= prayerData[0];

      return PrayerTimes(
        fajr: _parseTime(date, todayPrayer!['بەیانی']),
        sunrise: _parseTime(date, todayPrayer['خۆرهەڵاتن']),
        dhuhr: _parseTime(date, todayPrayer['نیوەڕۆ'], isAfternoon: true),
        asr: _parseTime(date, todayPrayer['عەسر'], isAfternoon: true),
        maghrib: _parseTime(date, todayPrayer['ئێوارە'], isAfternoon: true),
        isha: _parseTime(date, todayPrayer['خەوتنان'], isAfternoon: true),
        gregorianDate: todayPrayer['میلادى'],
      );
    } catch (e) {
      debugPrint("Error loading prayer times: $e");
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
      final List<String> parts = jsonDate.split(' - ');
      if (parts.length < 2) return false;

      final int day = int.parse(parts[0].trim());

      const Map<String, int> months = {
        'کانونی دووەم': 1,
        'شوبات': 2,
        'ئادار': 3,
        'نیسان': 4,
        'ئایار': 5,
        'حوزەیران': 6,
        'تەمووز': 7,
        'ئاب': 8,
        'ئەیلوول': 9,
        'تشرینی یەکەم': 10,
        'تشرینی دووەم': 11,
        'کانونی یەکەم': 12,
      };

      final String monthName = parts[1]
          .trim()
          .replaceAll('\u200f', '')
          .replaceAll('\u200e', '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      final int? month = months[monthName];
      if (month == null) return false;

      return day == targetDate.day && month == targetDate.month;
    } catch (e) {
      return false;
    }
  }

  DateTime _parseTime(DateTime date, String time, {bool isAfternoon = false}) {
    try {
      final List<String> parts = time.split(':');
      int hour = int.parse(parts[0]);
      final int minute = int.parse(parts[1]);

      if (isAfternoon && hour < 12 && hour >= 1) {
        hour += 12;
      }

      return DateTime(date.year, date.month, date.day, hour, minute);
    } catch (e) {
      return date;
    }
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
      "نەورۆز", "گوڵان", "جۆزەردان", "پووشپەڕ",
      "گەلاوێژ", "خەرمانان", "ڕەزبەر", "گەڵاڕێزان",
      "سەرماوەز", "بەفرانبار", "ڕێبەندان", "ڕەشەمە"
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
        final int remainingDays = diff - 186;
        kMonth = (remainingDays ~/ 30) + 7;
        kDay = (remainingDays % 30) + 1;
      }
    } else {
      kYear = dt.year + 700;
      final int diff = dt.difference(noroz).inDays;

      if (diff < 186) {
        kMonth = (diff ~/ 31) + 1;
        kDay = (diff % 31) + 1;
      } else {
        final int remainingDays = diff - 186;
        kMonth = (remainingDays ~/ 30) + 7;
        kDay = (remainingDays % 30) + 1;
      }
    }

    if (kMonth > 12) kMonth = 12;

    return "${toKu(kDay.toString())}ـى ${months[kMonth - 1]} ${toKu(kYear.toString())}";
  }
}
