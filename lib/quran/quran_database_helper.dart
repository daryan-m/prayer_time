// ============================================================
//  quran_database_helper.dart
//
//  بەرپرسێتییەکان:
//    ١. getAllSurahs()       — ١١٤ سورە لە metadata DB
//    ٢. getSurahVerseCount() — ژمارەی ئایەتەکانی سورەیەک
//    ٣. saveReadingState / loadReadingState
//    ٤. saveReciterId / loadReciterId
//
//  assets:
//    assets/quran/quran-metadata-ayah.sqlite
//
//  pubspec:
//    sqflite, path, path_provider, shared_preferences
// ============================================================

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import 'quran_models.dart';

// SharedPreferences keys
const _kPage = 'q_page';
const _kSurah = 'q_surah';
const _kAyah = 'q_ayah';
const _kReciter = 'q_reciter';

// ────────────────────────────────────────────────────────────
//  QuranDatabaseHelper  —  singleton
// ────────────────────────────────────────────────────────────

class QuranDatabaseHelper {
  QuranDatabaseHelper._();
  static final QuranDatabaseHelper instance = QuranDatabaseHelper._();
  factory QuranDatabaseHelper() => instance;

  Database? _db;
  List<Surah>? _surahCache;

  // ── خوێندنەوەی DB ──────────────────────────────────────

  Future<Database> get _database async {
    if (_db != null) return _db!;
    final dir = await getApplicationDocumentsDirectory();
    final dest = File(p.join(dir.path, 'quran_meta.db'));
    if (!dest.existsSync()) {
      final bytes =
          await rootBundle.load('assets/quran/quran-metadata-ayah.sqlite');
      await dest.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
    }
    return _db = await openDatabase(dest.path, readOnly: true);
  }

  // ── سورەکان ─────────────────────────────────────────────

  /// هەموو ١١٤ سورە — یەکجار cache دەکرێت
  Future<List<Surah>> getAllSurahs() async {
    if (_surahCache != null) return _surahCache!;

    final db = await _database;
    final rows = await db.rawQuery(
      'SELECT surah_number, COUNT(*) AS c '
      'FROM verses GROUP BY surah_number ORDER BY surah_number',
    );

    _surahCache = rows.map((r) {
      final id = r['surah_number'] as int;
      final m = _kSurahMeta[id - 1];
      return Surah(
        id: id,
        nameArabic: m[0] as String,
        nameSimple: m[1] as String,
        nameKurdish: m[2] as String,
        versesCount: r['c'] as int,
        revelationPlace: m[3] as String,
        pageStart: m[4] as int,
        juzStart: m[5] as int,
      );
    }).toList();

    return _surahCache!;
  }

  /// ژمارەی ئایەتەکانی سورەیەک
  Future<int> getSurahVerseCount(int surahId) async {
    // cache چیک
    if (_surahCache != null) {
      final hit =
          _surahCache!.where((s) => s.id == surahId).map((s) => s.versesCount);
      if (hit.isNotEmpty) return hit.first;
    }
    // DB query
    final db = await _database;
    final res = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM verses WHERE surah_number = ?',
      [surahId],
    );
    return (res.first['c'] as int?) ?? 0;
  }

  // ── پاشەکەوتکردنی شوێن ──────────────────────────────────

  Future<void> saveReadingState(QuranReadingState s) async {
    final pref = await SharedPreferences.getInstance();
    await pref.setInt(_kPage, s.page);
    await pref.setInt(_kSurah, s.surahId);
    await pref.setInt(_kAyah, s.ayahNumber);
  }

  Future<QuranReadingState> loadReadingState() async {
    final pref = await SharedPreferences.getInstance();
    return QuranReadingState(
      page: pref.getInt(_kPage) ?? 1,
      surahId: pref.getInt(_kSurah) ?? 1,
      ayahNumber: pref.getInt(_kAyah) ?? 1,
    );
  }

  // ── قاریئ ────────────────────────────────────────────────

  Future<void> saveReciterId(String id) async =>
      (await SharedPreferences.getInstance()).setString(_kReciter, id);

  Future<String> loadReciterId() async =>
      (await SharedPreferences.getInstance()).getString(_kReciter) ??
      Reciter.defaults.first.id;

  // ── داخستن ───────────────────────────────────────────────

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  // ── مێتاداتای ١١٤ سورە (ثابت) ──────────────────────────
  // [nameArabic, nameSimple, nameKurdish, place, pageStart, juzStart]

  static const List<List<dynamic>> _kSurahMeta = [
    ['الفاتحة', 'Al-Fatihah', 'فاتیحە', 'makkah', 1, 1],
    ['البقرة', 'Al-Baqarah', 'بەقەرە', 'madinah', 2, 1],
    ['آل عمران', 'Ali Imran', 'ئالی عیمران', 'madinah', 50, 3],
    ['النساء', "An-Nisa'", 'نیساء', 'madinah', 77, 4],
    ['المائدة', "Al-Ma'idah", 'مائیدە', 'madinah', 106, 6],
    ['الأنعام', "Al-An'am", 'ئەنعام', 'makkah', 128, 7],
    ['الأعراف', "Al-A'raf", 'ئەعراف', 'makkah', 151, 8],
    ['الأنفال', 'Al-Anfal', 'ئەنفال', 'madinah', 177, 9],
    ['التوبة', 'At-Tawbah', 'تەوبە', 'madinah', 187, 10],
    ['يونس', 'Yunus', 'یونس', 'makkah', 208, 11],
    ['هود', 'Hud', 'هود', 'makkah', 221, 11],
    ['يوسف', 'Yusuf', 'یوسف', 'makkah', 235, 12],
    ['الرعد', "Ar-Ra'd", 'ڕەعد', 'madinah', 249, 13],
    ['إبراهيم', 'Ibrahim', 'ئیبراهیم', 'makkah', 255, 13],
    ['الحجر', 'Al-Hijr', 'حیجر', 'makkah', 262, 14],
    ['النحل', 'An-Nahl', 'نەحل', 'makkah', 267, 14],
    ['الإسراء', "Al-Isra'", 'ئیسراء', 'makkah', 282, 15],
    ['الكهف', 'Al-Kahf', 'کەهف', 'makkah', 293, 15],
    ['مريم', 'Maryam', 'مەریەم', 'makkah', 305, 16],
    ['طه', 'Ta-Ha', 'تاها', 'makkah', 312, 16],
    ['الأنبياء', 'Al-Anbiya', 'ئەنبیاء', 'makkah', 322, 17],
    ['الحج', 'Al-Hajj', 'حەج', 'madinah', 332, 17],
    ['المؤمنون', 'Al-Muminun', 'مومینون', 'makkah', 342, 18],
    ['النور', 'An-Nur', 'نور', 'madinah', 350, 18],
    ['الفرقان', 'Al-Furqan', 'فورقان', 'makkah', 359, 18],
    ['الشعراء', "Ash-Shu'ara", 'شوعەرا', 'makkah', 367, 19],
    ['النمل', 'An-Naml', 'نەمل', 'makkah', 377, 19],
    ['القصص', 'Al-Qasas', 'قەسەس', 'makkah', 385, 20],
    ['العنكبوت', 'Al-Ankabut', 'عەنکەبوت', 'makkah', 396, 20],
    ['الروم', 'Ar-Rum', 'روم', 'makkah', 404, 21],
    ['لقمان', 'Luqman', 'لوقمان', 'makkah', 411, 21],
    ['السجدة', 'As-Sajdah', 'سەجدە', 'makkah', 415, 21],
    ['الأحزاب', 'Al-Ahzab', 'ئەحزاب', 'madinah', 418, 21],
    ['سبأ', "Saba'", 'سەبأ', 'makkah', 428, 22],
    ['فاطر', 'Fatir', 'فاتیر', 'makkah', 434, 22],
    ['يس', 'Ya-Sin', 'یاسین', 'makkah', 440, 22],
    ['الصافات', 'As-Saffat', 'صافات', 'makkah', 446, 23],
    ['ص', 'Sad', 'ص', 'makkah', 453, 23],
    ['الزمر', 'Az-Zumar', 'زومەر', 'makkah', 458, 23],
    ['غافر', 'Ghafir', 'غافیر', 'makkah', 467, 24],
    ['فصلت', 'Fussilat', 'فوسسیلەت', 'makkah', 477, 24],
    ['الشورى', 'Ash-Shuraa', 'شوورا', 'makkah', 483, 25],
    ['الزخرف', 'Az-Zukhruf', 'زوخروف', 'makkah', 489, 25],
    ['الدخان', 'Ad-Dukhan', 'دوخان', 'makkah', 496, 25],
    ['الجاثية', 'Al-Jathiyah', 'جاسیە', 'makkah', 499, 25],
    ['الأحقاف', 'Al-Ahqaf', 'ئەحقاف', 'makkah', 502, 26],
    ['محمد', 'Muhammad', 'موحەممەد', 'madinah', 507, 26],
    ['الفتح', 'Al-Fath', 'فەتح', 'madinah', 511, 26],
    ['الحجرات', 'Al-Hujurat', 'حوجورات', 'madinah', 515, 26],
    ['ق', 'Qaf', 'ق', 'makkah', 518, 26],
    ['الذاريات', 'Adh-Dhariyat', 'زاریات', 'makkah', 520, 26],
    ['الطور', 'At-Tur', 'تور', 'makkah', 523, 27],
    ['النجم', 'An-Najm', 'نەجم', 'makkah', 526, 27],
    ['القمر', 'Al-Qamar', 'قەمەر', 'makkah', 528, 27],
    ['الرحمن', 'Ar-Rahman', 'ڕەحمان', 'madinah', 531, 27],
    ['الواقعة', "Al-Waqi'ah", 'واقیعە', 'makkah', 534, 27],
    ['الحديد', 'Al-Hadid', 'حەدید', 'madinah', 537, 27],
    ['المجادلة', 'Al-Mujadila', 'موجادیلە', 'madinah', 542, 28],
    ['الحشر', 'Al-Hashr', 'حەشر', 'madinah', 545, 28],
    ['الممتحنة', 'Al-Mumtahanah', 'مومتەحینە', 'madinah', 549, 28],
    ['الصف', 'As-Saf', 'صەف', 'madinah', 551, 28],
    ['الجمعة', "Al-Jumu'ah", 'جومعە', 'madinah', 553, 28],
    ['المنافقون', 'Al-Munafiqun', 'موناڤیقون', 'madinah', 554, 28],
    ['التغابن', 'At-Taghabun', 'تەغابون', 'madinah', 556, 28],
    ['الطلاق', 'At-Talaq', 'تەلاق', 'madinah', 558, 28],
    ['التحريم', 'At-Tahrim', 'تەحریم', 'madinah', 560, 28],
    ['الملك', 'Al-Mulk', 'ملک', 'makkah', 562, 29],
    ['القلم', 'Al-Qalam', 'قەلەم', 'makkah', 564, 29],
    ['الحاقة', 'Al-Haqqah', 'حاققە', 'makkah', 566, 29],
    ['المعارج', "Al-Ma'arij", 'مەعاریج', 'makkah', 568, 29],
    ['نوح', 'Nuh', 'نوح', 'makkah', 570, 29],
    ['الجن', 'Al-Jinn', 'جن', 'makkah', 572, 29],
    ['المزمل', 'Al-Muzzammil', 'موزەممیل', 'makkah', 574, 29],
    ['المدثر', 'Al-Muddathir', 'مودەسسیر', 'makkah', 575, 29],
    ['القيامة', 'Al-Qiyamah', 'قیامەت', 'makkah', 577, 29],
    ['الإنسان', 'Al-Insan', 'ئینسان', 'madinah', 578, 29],
    ['المرسلات', 'Al-Mursalat', 'موڕسەلات', 'makkah', 580, 29],
    ['النبأ', "An-Naba'", 'نەبأ', 'makkah', 582, 30],
    ['النازعات', "An-Nazi'at", 'نازیعات', 'makkah', 583, 30],
    ['عبس', 'Abasa', 'عەبەسە', 'makkah', 585, 30],
    ['التكوير', 'At-Takwir', 'تەکویر', 'makkah', 586, 30],
    ['الإنفطار', 'Al-Infitar', 'ئینفیتار', 'makkah', 587, 30],
    ['المطففين', 'Al-Mutaffifin', 'موتەففیفین', 'makkah', 587, 30],
    ['الإنشقاق', 'Al-Inshiqaq', 'ئینشیقاق', 'makkah', 589, 30],
    ['البروج', 'Al-Buruj', 'بوروج', 'makkah', 590, 30],
    ['الطارق', 'At-Tariq', 'تاریق', 'makkah', 591, 30],
    ['الأعلى', "Al-A'la", 'ئەعلا', 'makkah', 591, 30],
    ['الغاشية', 'Al-Ghashiyah', 'غاشیە', 'makkah', 592, 30],
    ['الفجر', 'Al-Fajr', 'فەجر', 'makkah', 593, 30],
    ['البلد', 'Al-Balad', 'بەلەد', 'makkah', 594, 30],
    ['الشمس', 'Ash-Shams', 'شەمس', 'makkah', 595, 30],
    ['الليل', 'Al-Layl', 'شەو', 'makkah', 595, 30],
    ['الضحى', 'Ad-Duhaa', 'دوحا', 'makkah', 596, 30],
    ['الشرح', 'Ash-Sharh', 'شەرح', 'makkah', 596, 30],
    ['التين', 'At-Tin', 'تین', 'makkah', 597, 30],
    ['العلق', "Al-'Alaq", 'عەلەق', 'makkah', 597, 30],
    ['القدر', 'Al-Qadr', 'قەدر', 'makkah', 598, 30],
    ['البينة', 'Al-Bayyinah', 'بەییینە', 'madinah', 598, 30],
    ['الزلزلة', 'Az-Zalzalah', 'زەلزەلە', 'madinah', 599, 30],
    ['العاديات', "Al-'Adiyat", 'عادیات', 'makkah', 599, 30],
    ['القارعة', "Al-Qari'ah", 'قارعە', 'makkah', 600, 30],
    ['التكاثر', 'At-Takathur', 'تەکاسور', 'makkah', 600, 30],
    ['العصر', "Al-'Asr", 'عەسر', 'makkah', 601, 30],
    ['الهمزة', 'Al-Humazah', 'هومەزە', 'makkah', 601, 30],
    ['الفيل', 'Al-Fil', 'فیل', 'makkah', 601, 30],
    ['قريش', 'Quraysh', 'قورەیش', 'makkah', 602, 30],
    ['الماعون', "Al-Ma'un", 'ماعون', 'makkah', 602, 30],
    ['الكوثر', 'Al-Kawthar', 'کەوسەر', 'makkah', 602, 30],
    ['الكافرون', 'Al-Kafirun', 'کافیرون', 'makkah', 603, 30],
    ['النصر', 'An-Nasr', 'نەسر', 'madinah', 603, 30],
    ['المسد', 'Al-Masad', 'مەسەد', 'makkah', 603, 30],
    ['الإخلاص', 'Al-Ikhlas', 'ئیخلاس', 'makkah', 604, 30],
    ['الفلق', 'Al-Falaq', 'فەلەق', 'makkah', 604, 30],
    ['الناس', 'An-Nas', 'ناس', 'makkah', 604, 30],
  ];
}
