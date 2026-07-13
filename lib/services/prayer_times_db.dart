import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

// ══════════════════════════════════════════════════════════════════════════════
// PrayerTimesDatabase
//
// کاتێک بەکارهێنەر شارێک هەڵدەبژێرێت، کاتەکانی بانگی هەموو ساڵ لە JSON
// دەخوێنرێتەوە و لە SQLite ذەخیرە دەکرێت.
// Kotlin ئەوا بخوێنێتەوە بەبێ پێویستی بە Flutter.
//
// بەکارهێنان:
//   final db = PrayerTimesDatabase();
//   await db.saveCityPrayerTimes('هەولێر');
// ══════════════════════════════════════════════════════════════════════════════

class PrayerTimesDatabase {
  static Database? _db;
  static const String _dbName = 'prayer_times.db';
  static const int _dbVersion = 1;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE prayer_times (
            city TEXT NOT NULL,
            month INTEGER NOT NULL,
            day INTEGER NOT NULL,
            fajr TEXT NOT NULL,
            sunrise TEXT NOT NULL,
            dhuhr TEXT NOT NULL,
            asr TEXT NOT NULL,
            maghrib TEXT NOT NULL,
            isha TEXT NOT NULL,
            PRIMARY KEY (city, month, day)
          )
        ''');
      },
    );
  }

  /// کاتی بانگی هەموو ساڵ لە JSON دەخوێنێتەوە و لە SQLite ذەخیرە دەکات
  Future<void> saveCityPrayerTimes(String cityDisplayName) async {
    try {
      // فایلی JSON لە assets دەخوێنێتەوە
      final cityKey = cityDisplayName.trim();
      final config = _getCityJsonFile(cityKey);
      if (config == null) {
        debugPrint("❌ فایلی JSON بۆ '$cityKey' نەدۆزرایەوە");
        return;
      }

      final String jsonString =
          await rootBundle.loadString('assets/data/$config.json');
      final Map<String, dynamic> cityData = json.decode(jsonString);
      final List<dynamic> months = cityData['months'];

      final db = await database;

      // داتای کۆنی ئەو شارە لادەبرێت
      await db.delete('prayer_times', where: 'city = ?', whereArgs: [cityKey]);

      // بەچی ذەخیرە دەکرێت بۆ خێرایی
      final batch = db.batch();
      for (final monthData in months) {
        final int month = monthData['month'];
        final List<dynamic> days = monthData['days'];
        for (final dayData in days) {
          batch.insert(
            'prayer_times',
            {
              'city': cityKey,
              'month': month,
              'day': dayData['day'],
              'fajr': dayData['fajr'],
              'sunrise': dayData['sunrise'],
              'dhuhr': dayData['dhuhr'],
              'asr': dayData['asr'],
              'maghrib': dayData['maghrib'],
              'isha': dayData['isha'],
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
      await batch.commit(noResult: true);

      debugPrint("✅ کاتەکانی '$cityKey' لە SQLite پاشەکەوت کران");
    } catch (e) {
      debugPrint("❌ saveCityPrayerTimes error: $e");
    }
  }

  /// چەک دەکات ئایا داتای ئەو شارە پێشتر ذەخیرە کراوە
  Future<bool> isCitySaved(String cityDisplayName) async {
    try {
      final db = await database;
      final result = await db.query(
        'prayer_times',
        where: 'city = ?',
        whereArgs: [cityDisplayName.trim()],
        limit: 1,
      );
      return result.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// ناوی فایلی JSON بۆ شارێک دەگەڕێنێتەوە
  String? _getCityJsonFile(String cityName) {
    const Map<String, String> cityFiles = {
      'هەولێر': 'hawler_prayer_times',
      'سلێمانى': 'slemany_prayer_times',
      'دهۆک': 'duhok_prayer_times',
      'کەرکووک': 'kirkuk_prayer_times',
      'هەلەبجە': 'halabja_prayer_times',
      'کەلار': 'kalar_prayer_times',
      'ڕانیە': 'ranya_prayer_times',
      'کۆیە': 'koya_prayer_times',
      'سۆران': 'soran_prayer_times',
      'زاخۆ': 'zaxo_prayer_times',
      'خانەقین': 'xanaqin_prayer_times',
      'چەمچەماڵ': 'chamchamal_prayer_times',
      'پێنجوێن': 'penjuin_prayer_times',
      'هەلەبجەى تازە': 'halabjan_prayer_times',
      'سیدصادق': 'saidsadiq_prayer_times',
      'دەربەندیخان': 'darbandixan_prayer_times',
      'کفرى': 'kfri_prayer_times',
      'قەڵادزێ': 'qaladze_prayer_times',
      'قەرەداغ': 'qaradax_prayer_times',
      'قەسرێ': 'qasre_prayer_times',
      'قادرکەرەم': 'qadirkaram_prayer_times',
      'چوارتا': 'chwarta_prayer_times',
      'بازیان': 'bazyan_prayer_times',
      'بەرزنجە': 'barznja_prayer_times',
      'عەربەت': 'arbat_prayer_times',
      'ئاکرێ': 'akre_prayer_times',
      'ئامێدى': 'amedi_prayer_times',
      'پیرەمەگرون': 'piramagrun_prayer_times',
      'تەکیە': 'takya_prayer_times',
      'تەق تەق': 'taqtaq_prayer_times',
      'تاسڵوجە': 'tasluja_prayer_times',
      'دوزخورماتو': 'tuzxurmatu_prayer_times',
      'دوکان': 'dukan_prayer_times',
      'حاجیاوا': 'hajiawa_prayer_times',
      'خەلەکان': 'xalakan_prayer_times',
    };
    return cityFiles[cityName];
  }
}
