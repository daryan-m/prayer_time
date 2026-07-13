import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:home_widget/home_widget.dart';
import 'prayer_service.dart';
import 'package:intl/intl.dart';

class HomeWidgetService {
  static const String _androidWidgetName = 'PrayerWidgetProvider';

  int _getNextPrayerIndex(PrayerTimes times, DateTime now) {
    if (now.isBefore(times.fajr)) return 0;
    if (now.isBefore(times.dhuhr)) return 1;
    if (now.isBefore(times.asr)) return 2;
    if (now.isBefore(times.maghrib)) return 3;
    if (now.isBefore(times.isha)) return 4;
    return 0;
  }

  Future<void> update({
    required PrayerTimes prayerTimes,
    required DateTime now,
    required TimeService timeService,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final formatter = DateFormat('HH:mm');
      final todayTimes = [
        formatter.format(prayerTimes.fajr),
        formatter.format(prayerTimes.dhuhr),
        formatter.format(prayerTimes.asr),
        formatter.format(prayerTimes.maghrib),
        formatter.format(prayerTimes.isha),
      ];

      final nextIndex = _getNextPrayerIndex(prayerTimes, now);
      await prefs.setString('widget_next_index', nextIndex.toString());

      const prayerLabels = [
        "بەیانی",
        "نیوەڕۆ",
        "عەسر",
        "ئێوارە",
        "خەوتنان",
      ];

      for (int i = 0; i < 5 && i < todayTimes.length; i++) {
        await prefs.setString('widget_p${i}_name', prayerLabels[i]);
        await prefs.setString(
            'widget_p${i}_time', timeService.formatTo12Hr(todayTimes[i]));
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
