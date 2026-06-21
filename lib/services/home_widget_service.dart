import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:home_widget/home_widget.dart';
import 'prayer_service.dart';
import 'package:intl/intl.dart';

// ══════════════════════════════════════════════════════════════════════════════
// HomeWidgetService
//
// ئەم سرڤیسە بەرپرسیارە لە نووسینی داتای کاتی بانگ، بەروار، و ناوی شار
// بۆ SharedPreferences، پاشان داوای نوێکردنەوەی widget ـی شاشەی هۆمی مۆبایل
// دەکات (PrayerWidgetProvider.kt لای Android).
//
// بەکارهێنان لە home_screen.dart:
//
//   import '../services/home_widget_service.dart';
//
//   final HomeWidgetService _homeWidgetService = HomeWidgetService();
//
//   // دوای بارکردنی کاتەکانی بانگ:
//   await _homeWidgetService.update(
//     prayerTimes: prayerTimes,
//     todayTimes: todayTimes,
//     now: _now,
//     timeService: _timeService,
//   );
// ══════════════════════════════════════════════════════════════════════════════

class HomeWidgetService {
  static const String _androidWidgetName = 'PrayerWidgetProvider';

  /// ناوی بانگی داهاتوو دەستنیشان دەکات (بەیانی، نیوەڕۆ، عەسر، ئێوارە، خەوتنان)
  String _getNextPrayerName(PrayerTimes times, DateTime now) {
    if (now.isBefore(times.fajr)) return "بەیانی";
    if (now.isBefore(times.dhuhr)) return "نیوەڕۆ";
    if (now.isBefore(times.asr)) return "عەسر";
    if (now.isBefore(times.maghrib)) return "ئێوارە";
    if (now.isBefore(times.isha)) return "خەوتنان";
    return "بەیانی";
  }

  /// کاتی DateTime ـی بانگی داهاتوو دەستنیشان دەکات
  DateTime _getNextPrayerDateTime(PrayerTimes times, DateTime now) {
    if (now.isBefore(times.fajr)) return times.fajr;
    if (now.isBefore(times.dhuhr)) return times.dhuhr;
    if (now.isBefore(times.asr)) return times.asr;
    if (now.isBefore(times.maghrib)) return times.maghrib;
    if (now.isBefore(times.isha)) return times.isha;
    return times.fajr;
  }

  /// داتای کاتی بانگ، بەروار، و شار دەنووسێت بۆ SharedPreferences
  /// و widget ـی شاشەی هۆمی مۆبایل نوێ دەکاتەوە.
  ///
  /// [prayerTimes]  — کاتەکانی بانگی ئەمڕۆ (لە PrayerDataService)
  /// [todayTimes]   — لیستی ٦ کاتی بانگ بە فۆرماتی "HH:mm" (بەیانی،خۆرهەڵاتن،نیوەڕۆ،عەسر،ئێوارە،خەوتنان)
  /// [now]          — کاتی ئێستا
  /// [timeService]  — TimeService ـی هەمان ئەپ (بۆ فۆرماتکردنی کات و بەروار)
  Future<void> update({
    required PrayerTimes prayerTimes,
    required DateTime now,
    required TimeService timeService,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final nextName = _getNextPrayerName(prayerTimes, now);
      final nextDateTime = _getNextPrayerDateTime(prayerTimes, now);
      final nextTimeStr = timeService
          .formatTo12Hr('${nextDateTime.hour.toString().padLeft(2, '0')}:'
              '${nextDateTime.minute.toString().padLeft(2, '0')}');

      final formatter = DateFormat('HH:mm');
      final todayTimes = [
        formatter.format(prayerTimes.fajr),
        formatter.format(prayerTimes.sunrise),
        formatter.format(prayerTimes.dhuhr),
        formatter.format(prayerTimes.asr),
        formatter.format(prayerTimes.maghrib),
        formatter.format(prayerTimes.isha),
      ];

      await prefs.setString('widget_next_name', nextName);
      await prefs.setString('widget_next_time', nextTimeStr);

      const prayerLabels = [
        "بەیانی",
        "خۆرهەڵاتن",
        "نیوەڕۆ",
        "عەسر",
        "ئێوارە",
        "خەوتنان",
      ];

      for (int i = 0; i < 6 && i < todayTimes.length; i++) {
        await prefs.setString('widget_p$i',
            '${prayerLabels[i]} — ${timeService.formatTo12Hr(todayTimes[i])}');
      }

      await prefs.setString('widget_hijri', timeService.hijriDateString());
      await prefs.setString(
          'widget_gregorian', timeService.gregorianDateString(now));
      await prefs.setString(
          'widget_kurdish', timeService.kurdishDateString(now));

      await HomeWidget.updateWidget(androidName: _androidWidgetName);
    } catch (e) {
      debugPrint("❌ HomeWidgetService update error: $e");
    }
  }
}
