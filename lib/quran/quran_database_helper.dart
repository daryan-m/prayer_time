
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import 'quran_models.dart';

// ──────────────────────────────────────────
// ثابتەکان
// ──────────────────────────────────────────

const String _kAssetDbPath = 'assets/db/quran.db';
const String _kAssetTranslationPath = 'assets/translation/ku_asan.txt';
const String _kDbName = 'quran_app.db'; // ناوێکی جیاواز بۆ کۆپیکراوەکە
const String _kDbCopiedKey = 'quran_db_copied_v1';
const String _kTranslationImportedKey = 'quran_translation_imported_v1';

// ──────────────────────────────────────────
// چین سەرەکی
// ──────────────────────────────────────────

class QuranDatabaseHelper {
  static final QuranDatabaseHelper _instance = QuranDatabaseHelper._internal();
  factory QuranDatabaseHelper() => _instance;
  QuranDatabaseHelper._internal();

  Database? _db;

  // ════════════════════════════════════════
  // کردنەوەی داتابەیس
  // ════════════════════════════════════════

  Future<Database> get database async {
    if (_db != null && _db!.isOpen) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, _kDbName);

    await _copyTanzilDbIfNeeded(dbPath);

    final db = await openDatabase(
      dbPath,
      readOnly: false,
      onOpen: (db) async {
        // زیادکردنی تەیبڵی وەرگێڕان ئەگەر نەبوو
        await _ensureTranslationTable(db);
        // ئیمپۆرتی وەرگێڕانی کوردی
        await _importKurdishIfNeeded(db);
        // زیادکردنی تەیبڵی سورەکان ئەگەر نەبوو
        await _ensureSurahTable(db);
      },
    );

    return db;
  }

  // ════════════════════════════════════════
  // کۆپیکردنی DB لە assets
  // ════════════════════════════════════════

  Future<void> _copyTanzilDbIfNeeded(String dbPath) async {
    final prefs = await SharedPreferences.getInstance();
    final copied = prefs.getBool(_kDbCopiedKey) ?? false;
    final file = File(dbPath);

    if (copied && await file.exists()) return;

    try {
      final data = await rootBundle.load(_kAssetDbPath);
      final bytes = data.buffer.asUint8List();
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes, flush: true);
      await prefs.setBool(_kDbCopiedKey, true);
    } catch (e) {
      // ئەگەر فایلی assets نەبوو، داتابەیسی بەتاڵ دروست دەکات
      await _createEmptyDb(dbPath);
    }
  }

  Future<void> _createEmptyDb(String dbPath) async {
    final db = await openDatabase(dbPath, version: 1, onCreate: (db, _) async {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS quran_text (
          "index" INTEGER PRIMARY KEY AUTOINCREMENT,
          sura INTEGER NOT NULL DEFAULT 0,
          aya INTEGER NOT NULL DEFAULT 0,
          text TEXT NOT NULL
        )
      ''');
    });
    await db.close();
  }

  // ════════════════════════════════════════
  // تەیبڵی وەرگێڕان
  // ════════════════════════════════════════

  Future<void> _ensureTranslationTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS kurdish_translation (
        sura  INTEGER NOT NULL,
        aya   INTEGER NOT NULL,
        text  TEXT    NOT NULL,
        PRIMARY KEY (sura, aya)
      )
    ''');
  }

  // ════════════════════════════════════════
  // تەیبڵی سورەکان (metadata)
  // ════════════════════════════════════════

  Future<void> _ensureSurahTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS surahs (
        id               INTEGER PRIMARY KEY,
        name_arabic      TEXT NOT NULL,
        name_simple      TEXT NOT NULL,
        name_kurdish     TEXT NOT NULL DEFAULT '',
        verses_count     INTEGER NOT NULL,
        revelation_place TEXT NOT NULL DEFAULT 'makkah',
        page_start       INTEGER NOT NULL DEFAULT 1,
        juz_start        INTEGER NOT NULL DEFAULT 1
      )
    ''');

    final count =
        Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM surahs'));
    if ((count ?? 0) == 0) {
      await _insertSurahMetadata(db);
    }
  }

  // ════════════════════════════════════════
  // ئیمپۆرتی وەرگێڕانی کوردی (ku_asan.txt)
  // فۆرمات: sura|aya|دەق
  // ════════════════════════════════════════

  Future<void> _importKurdishIfNeeded(Database db) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_kTranslationImportedKey) ?? false) return;

    try {
      final raw = await rootBundle.loadString(_kAssetTranslationPath);
      final lines = raw.split('\n');

      final batch = db.batch();
      // ignore: unused_local_variable
      int imported = 0;

      for (final line in lines) {
        final trimmed = line.trim();
        // تێپەڕاندنی کامێنت و هێڵی بەتاڵ
        if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

        // فۆرمات: 1|1|دەق
        final parts = trimmed.split('|');
        if (parts.length < 3) continue;

        final sura = int.tryParse(parts[0]);
        final aya = int.tryParse(parts[1]);
        // دەقەکە دەتوانێت | تێیدا هەبێت
        final text = parts.sublist(2).join('|').trim();

        if (sura == null || aya == null || text.isEmpty) continue;

        batch.insert(
          'kurdish_translation',
          {'sura': sura, 'aya': aya, 'text': text},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        imported++;
      }

      await batch.commit(noResult: true);
      await prefs.setBool(_kTranslationImportedKey, true);
    } catch (e) {
      // فایلی وەرگێڕان نەبوو — بەردەوام بە
    }
  }

  // ════════════════════════════════════════
  // خوێندنی ئایەتەکان
  // تەیبڵ: quran_text — ستوون: index, sura, aya, text
  // ════════════════════════════════════════

  /// هەموو ئایەتەکانی یەک سورە
  Future<List<Ayah>> getAyahsOfSurah(int surahId) async {
    final db = await database;

    // JOIN بۆ وەرگێڕانی کوردی
    final rows = await db.rawQuery('''
      SELECT
        qt."index"  AS id,
        qt.sura     AS surah_id,
        qt.aya      AS number_in_surah,
        qt.text     AS text_uthmani,
        kt.text     AS text_kurdish,
        0           AS page,
        0           AS juz,
        0           AS sajda
      FROM quran_text qt
      LEFT JOIN kurdish_translation kt
        ON kt.sura = qt.sura AND kt.aya = qt.aya
      WHERE qt.sura = ?
      ORDER BY qt.aya ASC
    ''', [surahId]);

    return rows.map(_ayahFromRow).toList();
  }

  /// یەک ئایەت بە سورە + ژمارە
  Future<Ayah?> getAyah(int surahId, int numberInSurah) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT
        qt."index"  AS id,
        qt.sura     AS surah_id,
        qt.aya      AS number_in_surah,
        qt.text     AS text_uthmani,
        kt.text     AS text_kurdish,
        0 AS page, 0 AS juz, 0 AS sajda
      FROM quran_text qt
      LEFT JOIN kurdish_translation kt
        ON kt.sura = qt.sura AND kt.aya = qt.aya
      WHERE qt.sura = ? AND qt.aya = ?
      LIMIT 1
    ''', [surahId, numberInSurah]);

    if (rows.isEmpty) return null;
    return _ayahFromRow(rows.first);
  }

  /// گەڕان لە دەق یان وەرگێڕان
  Future<List<Ayah>> searchAyahs(String query, {bool inKurdish = false}) async {
    final db = await database;

    final List<Map<String, dynamic>> rows;
    if (inKurdish) {
      rows = await db.rawQuery('''
        SELECT
          qt."index" AS id,
          qt.sura    AS surah_id,
          qt.aya     AS number_in_surah,
          qt.text    AS text_uthmani,
          kt.text    AS text_kurdish,
          0 AS page, 0 AS juz, 0 AS sajda
        FROM kurdish_translation kt
        JOIN quran_text qt
          ON qt.sura = kt.sura AND qt.aya = kt.aya
        WHERE kt.text LIKE ?
        LIMIT 50
      ''', ['%$query%']);
    } else {
      rows = await db.rawQuery('''
        SELECT
          qt."index" AS id,
          qt.sura    AS surah_id,
          qt.aya     AS number_in_surah,
          qt.text    AS text_uthmani,
          kt.text    AS text_kurdish,
          0 AS page, 0 AS juz, 0 AS sajda
        FROM quran_text qt
        LEFT JOIN kurdish_translation kt
          ON kt.sura = qt.sura AND kt.aya = qt.aya
        WHERE qt.text LIKE ?
        LIMIT 50
      ''', ['%$query%']);
    }

    return rows.map(_ayahFromRow).toList();
  }

  /// ژمارەی ئایەتەکانی سورەیەک
  Future<int> getSurahVerseCount(int surahId) async {
    final db = await database;
    final result = await db.rawQuery(
        'SELECT COUNT(*) as c FROM quran_text WHERE sura = ?', [surahId]);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ════════════════════════════════════════
  // خوێندنی سورەکان
  // ════════════════════════════════════════

  Future<List<Surah>> getAllSurahs() async {
    final db = await database;
    final rows = await db.query('surahs', orderBy: 'id ASC');
    if (rows.isNotEmpty) return rows.map(Surah.fromMap).toList();
    // بازمانی
    return _kSurahMetadata.map(Surah.fromMap).toList();
  }

  Future<Surah?> getSurah(int id) async {
    final db = await database;
    final rows = await db.query('surahs', where: 'id = ?', whereArgs: [id]);
    if (rows.isNotEmpty) return Surah.fromMap(rows.first);
    final meta = _kSurahMetadata.where((m) => m['id'] == id);
    if (meta.isNotEmpty) return Surah.fromMap(meta.first);
    return null;
  }

  // ════════════════════════════════════════
  // یارمەتیدەر: دروستکردنی Ayah لە row
  // ════════════════════════════════════════

  Ayah _ayahFromRow(Map<String, dynamic> row) => Ayah(
        id: row['id'] as int? ?? 0,
        surahId: row['surah_id'] as int? ?? 0,
        numberInSurah: row['number_in_surah'] as int? ?? 0,
        textUthmani: row['text_uthmani'] as String? ?? '',
        textKurdish: row['text_kurdish'] as String?,
        page: row['page'] as int? ?? 0,
        juz: row['juz'] as int? ?? 0,
        sajda: (row['sajda'] as int? ?? 0) == 1,
      );

  // ════════════════════════════════════════
  // پاشەکەوتکردنی دۆخ
  // ════════════════════════════════════════

  Future<void> saveReadingState(QuranReadingState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('q_surah', state.surahId);
    await prefs.setInt('q_ayah', state.ayahNumber);
    await prefs.setInt('q_page', state.page);
  }

  Future<QuranReadingState> loadReadingState() async {
    final prefs = await SharedPreferences.getInstance();
    return QuranReadingState(
      surahId: prefs.getInt('q_surah') ?? 1,
      ayahNumber: prefs.getInt('q_ayah') ?? 1,
      page: prefs.getInt('q_page') ?? 1,
    );
  }

  Future<void> saveSelectedReciterId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('q_reciter', id);
  }

  Future<String> loadSelectedReciterId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('q_reciter') ?? 'ar.alafasy';
  }

  // ════════════════════════════════════════
  // داخستن
  // ════════════════════════════════════════

  Future<void> close() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
      _db = null;
    }
  }

  // ════════════════════════════════════════
  // تەیبڵی سورەکان — داتای تەواو ١١٤ سورە
  // ════════════════════════════════════════

  Future<void> _insertSurahMetadata(Database db) async {
    final batch = db.batch();
    for (final m in _kSurahMetadata) {
      batch.insert('surahs', m, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
  }

  static const List<Map<String, dynamic>> _kSurahMetadata = [
    {
      'id': 1,
      'name_arabic': 'ٱلْفَاتِحَة',
      'name_simple': 'Al-Fatihah',
      'name_kurdish': 'فاتیحە',
      'verses_count': 7,
      'revelation_place': 'makkah',
      'page_start': 1,
      'juz_start': 1
    },
    {
      'id': 2,
      'name_arabic': 'ٱلْبَقَرَة',
      'name_simple': 'Al-Baqarah',
      'name_kurdish': 'بەقەرە',
      'verses_count': 286,
      'revelation_place': 'madinah',
      'page_start': 2,
      'juz_start': 1
    },
    {
      'id': 3,
      'name_arabic': 'آلِ عِمْرَان',
      'name_simple': 'Ali Imran',
      'name_kurdish': 'ئاڵی عیمران',
      'verses_count': 200,
      'revelation_place': 'madinah',
      'page_start': 50,
      'juz_start': 3
    },
    {
      'id': 4,
      'name_arabic': 'ٱلنِّسَاء',
      'name_simple': 'An-Nisa',
      'name_kurdish': 'نیسا',
      'verses_count': 176,
      'revelation_place': 'madinah',
      'page_start': 77,
      'juz_start': 4
    },
    {
      'id': 5,
      'name_arabic': 'ٱلْمَائِدَة',
      'name_simple': 'Al-Maidah',
      'name_kurdish': 'مائیدە',
      'verses_count': 120,
      'revelation_place': 'madinah',
      'page_start': 106,
      'juz_start': 6
    },
    {
      'id': 6,
      'name_arabic': 'ٱلْأَنْعَام',
      'name_simple': 'Al-Anam',
      'name_kurdish': 'ئەنعام',
      'verses_count': 165,
      'revelation_place': 'makkah',
      'page_start': 128,
      'juz_start': 7
    },
    {
      'id': 7,
      'name_arabic': 'ٱلْأَعْرَاف',
      'name_simple': 'Al-Araf',
      'name_kurdish': 'ئەعراف',
      'verses_count': 206,
      'revelation_place': 'makkah',
      'page_start': 151,
      'juz_start': 8
    },
    {
      'id': 8,
      'name_arabic': 'ٱلْأَنفَال',
      'name_simple': 'Al-Anfal',
      'name_kurdish': 'ئەنفال',
      'verses_count': 75,
      'revelation_place': 'madinah',
      'page_start': 177,
      'juz_start': 9
    },
    {
      'id': 9,
      'name_arabic': 'ٱلتَّوْبَة',
      'name_simple': 'At-Tawbah',
      'name_kurdish': 'توبە',
      'verses_count': 129,
      'revelation_place': 'madinah',
      'page_start': 187,
      'juz_start': 10
    },
    {
      'id': 10,
      'name_arabic': 'يُونُس',
      'name_simple': 'Yunus',
      'name_kurdish': 'یونس',
      'verses_count': 109,
      'revelation_place': 'makkah',
      'page_start': 208,
      'juz_start': 11
    },
    {
      'id': 11,
      'name_arabic': 'هُود',
      'name_simple': 'Hud',
      'name_kurdish': 'هود',
      'verses_count': 123,
      'revelation_place': 'makkah',
      'page_start': 221,
      'juz_start': 11
    },
    {
      'id': 12,
      'name_arabic': 'يُوسُف',
      'name_simple': 'Yusuf',
      'name_kurdish': 'یوسف',
      'verses_count': 111,
      'revelation_place': 'makkah',
      'page_start': 235,
      'juz_start': 12
    },
    {
      'id': 13,
      'name_arabic': 'ٱلرَّعْد',
      'name_simple': 'Ar-Rad',
      'name_kurdish': 'ڕەعد',
      'verses_count': 43,
      'revelation_place': 'madinah',
      'page_start': 249,
      'juz_start': 13
    },
    {
      'id': 14,
      'name_arabic': 'إِبْرَاهِيم',
      'name_simple': 'Ibrahim',
      'name_kurdish': 'ئیبراهیم',
      'verses_count': 52,
      'revelation_place': 'makkah',
      'page_start': 255,
      'juz_start': 13
    },
    {
      'id': 15,
      'name_arabic': 'ٱلْحِجْر',
      'name_simple': 'Al-Hijr',
      'name_kurdish': 'حیجر',
      'verses_count': 99,
      'revelation_place': 'makkah',
      'page_start': 262,
      'juz_start': 14
    },
    {
      'id': 16,
      'name_arabic': 'ٱلنَّحْل',
      'name_simple': 'An-Nahl',
      'name_kurdish': 'نەحل',
      'verses_count': 128,
      'revelation_place': 'makkah',
      'page_start': 267,
      'juz_start': 14
    },
    {
      'id': 17,
      'name_arabic': 'ٱلْإِسْرَاء',
      'name_simple': 'Al-Isra',
      'name_kurdish': 'ئیسرا',
      'verses_count': 111,
      'revelation_place': 'makkah',
      'page_start': 282,
      'juz_start': 15
    },
    {
      'id': 18,
      'name_arabic': 'ٱلْكَهْف',
      'name_simple': 'Al-Kahf',
      'name_kurdish': 'کەهف',
      'verses_count': 110,
      'revelation_place': 'makkah',
      'page_start': 293,
      'juz_start': 15
    },
    {
      'id': 19,
      'name_arabic': 'مَرْيَم',
      'name_simple': 'Maryam',
      'name_kurdish': 'مەریەم',
      'verses_count': 98,
      'revelation_place': 'makkah',
      'page_start': 305,
      'juz_start': 16
    },
    {
      'id': 20,
      'name_arabic': 'طه',
      'name_simple': 'Taha',
      'name_kurdish': 'تاها',
      'verses_count': 135,
      'revelation_place': 'makkah',
      'page_start': 312,
      'juz_start': 16
    },
    {
      'id': 21,
      'name_arabic': 'ٱلْأَنبِيَاء',
      'name_simple': 'Al-Anbiya',
      'name_kurdish': 'ئەنبیا',
      'verses_count': 112,
      'revelation_place': 'makkah',
      'page_start': 322,
      'juz_start': 17
    },
    {
      'id': 22,
      'name_arabic': 'ٱلْحَجّ',
      'name_simple': 'Al-Hajj',
      'name_kurdish': 'حەج',
      'verses_count': 78,
      'revelation_place': 'madinah',
      'page_start': 332,
      'juz_start': 17
    },
    {
      'id': 23,
      'name_arabic': 'ٱلْمُؤْمِنُون',
      'name_simple': 'Al-Muminun',
      'name_kurdish': 'مومینون',
      'verses_count': 118,
      'revelation_place': 'makkah',
      'page_start': 342,
      'juz_start': 18
    },
    {
      'id': 24,
      'name_arabic': 'ٱلنُّور',
      'name_simple': 'An-Nur',
      'name_kurdish': 'نور',
      'verses_count': 64,
      'revelation_place': 'madinah',
      'page_start': 350,
      'juz_start': 18
    },
    {
      'id': 25,
      'name_arabic': 'ٱلْفُرْقَان',
      'name_simple': 'Al-Furqan',
      'name_kurdish': 'فورقان',
      'verses_count': 77,
      'revelation_place': 'makkah',
      'page_start': 359,
      'juz_start': 18
    },
    {
      'id': 26,
      'name_arabic': 'ٱلشُّعَرَاء',
      'name_simple': 'Ash-Shuara',
      'name_kurdish': 'شوعەرا',
      'verses_count': 227,
      'revelation_place': 'makkah',
      'page_start': 367,
      'juz_start': 19
    },
    {
      'id': 27,
      'name_arabic': 'ٱلنَّمْل',
      'name_simple': 'An-Naml',
      'name_kurdish': 'نەمل',
      'verses_count': 93,
      'revelation_place': 'makkah',
      'page_start': 377,
      'juz_start': 19
    },
    {
      'id': 28,
      'name_arabic': 'ٱلْقَصَص',
      'name_simple': 'Al-Qasas',
      'name_kurdish': 'قەسەس',
      'verses_count': 88,
      'revelation_place': 'makkah',
      'page_start': 385,
      'juz_start': 20
    },
    {
      'id': 29,
      'name_arabic': 'ٱلْعَنكَبُوت',
      'name_simple': 'Al-Ankabut',
      'name_kurdish': 'عەنکەبوت',
      'verses_count': 69,
      'revelation_place': 'makkah',
      'page_start': 396,
      'juz_start': 20
    },
    {
      'id': 30,
      'name_arabic': 'ٱلرُّوم',
      'name_simple': 'Ar-Rum',
      'name_kurdish': 'ڕوم',
      'verses_count': 60,
      'revelation_place': 'makkah',
      'page_start': 404,
      'juz_start': 21
    },
    {
      'id': 31,
      'name_arabic': 'لُقْمَان',
      'name_simple': 'Luqman',
      'name_kurdish': 'لوقمان',
      'verses_count': 34,
      'revelation_place': 'makkah',
      'page_start': 411,
      'juz_start': 21
    },
    {
      'id': 32,
      'name_arabic': 'ٱلسَّجْدَة',
      'name_simple': 'As-Sajdah',
      'name_kurdish': 'سەجدە',
      'verses_count': 30,
      'revelation_place': 'makkah',
      'page_start': 415,
      'juz_start': 21
    },
    {
      'id': 33,
      'name_arabic': 'ٱلْأَحْزَاب',
      'name_simple': 'Al-Ahzab',
      'name_kurdish': 'ئەحزاب',
      'verses_count': 73,
      'revelation_place': 'madinah',
      'page_start': 418,
      'juz_start': 21
    },
    {
      'id': 34,
      'name_arabic': 'سَبَأ',
      'name_simple': 'Saba',
      'name_kurdish': 'سەبە',
      'verses_count': 54,
      'revelation_place': 'makkah',
      'page_start': 428,
      'juz_start': 22
    },
    {
      'id': 35,
      'name_arabic': 'فَاطِر',
      'name_simple': 'Fatir',
      'name_kurdish': 'فاتیر',
      'verses_count': 45,
      'revelation_place': 'makkah',
      'page_start': 434,
      'juz_start': 22
    },
    {
      'id': 36,
      'name_arabic': 'يس',
      'name_simple': 'Ya-Sin',
      'name_kurdish': 'یاسین',
      'verses_count': 83,
      'revelation_place': 'makkah',
      'page_start': 440,
      'juz_start': 22
    },
    {
      'id': 37,
      'name_arabic': 'ٱلصَّافَّات',
      'name_simple': 'As-Saffat',
      'name_kurdish': 'سافات',
      'verses_count': 182,
      'revelation_place': 'makkah',
      'page_start': 446,
      'juz_start': 23
    },
    {
      'id': 38,
      'name_arabic': 'ص',
      'name_simple': 'Sad',
      'name_kurdish': 'ساد',
      'verses_count': 88,
      'revelation_place': 'makkah',
      'page_start': 453,
      'juz_start': 23
    },
    {
      'id': 39,
      'name_arabic': 'ٱلزُّمَر',
      'name_simple': 'Az-Zumar',
      'name_kurdish': 'زومەر',
      'verses_count': 75,
      'revelation_place': 'makkah',
      'page_start': 458,
      'juz_start': 23
    },
    {
      'id': 40,
      'name_arabic': 'غَافِر',
      'name_simple': 'Ghafir',
      'name_kurdish': 'غافیر',
      'verses_count': 85,
      'revelation_place': 'makkah',
      'page_start': 467,
      'juz_start': 24
    },
    {
      'id': 41,
      'name_arabic': 'فُصِّلَت',
      'name_simple': 'Fussilat',
      'name_kurdish': 'فوسیلەت',
      'verses_count': 54,
      'revelation_place': 'makkah',
      'page_start': 477,
      'juz_start': 24
    },
    {
      'id': 42,
      'name_arabic': 'ٱلشُّورَىٰ',
      'name_simple': 'Ash-Shura',
      'name_kurdish': 'شورا',
      'verses_count': 53,
      'revelation_place': 'makkah',
      'page_start': 483,
      'juz_start': 25
    },
    {
      'id': 43,
      'name_arabic': 'ٱلزُّخْرُف',
      'name_simple': 'Az-Zukhruf',
      'name_kurdish': 'زوخروف',
      'verses_count': 89,
      'revelation_place': 'makkah',
      'page_start': 489,
      'juz_start': 25
    },
    {
      'id': 44,
      'name_arabic': 'ٱلدُّخَان',
      'name_simple': 'Ad-Dukhan',
      'name_kurdish': 'دوخان',
      'verses_count': 59,
      'revelation_place': 'makkah',
      'page_start': 496,
      'juz_start': 25
    },
    {
      'id': 45,
      'name_arabic': 'ٱلْجَاثِيَة',
      'name_simple': 'Al-Jathiyah',
      'name_kurdish': 'جاسیە',
      'verses_count': 37,
      'revelation_place': 'makkah',
      'page_start': 499,
      'juz_start': 25
    },
    {
      'id': 46,
      'name_arabic': 'ٱلْأَحْقَاف',
      'name_simple': 'Al-Ahqaf',
      'name_kurdish': 'ئەحقاف',
      'verses_count': 35,
      'revelation_place': 'makkah',
      'page_start': 502,
      'juz_start': 26
    },
    {
      'id': 47,
      'name_arabic': 'مُحَمَّد',
      'name_simple': 'Muhammad',
      'name_kurdish': 'محمد',
      'verses_count': 38,
      'revelation_place': 'madinah',
      'page_start': 507,
      'juz_start': 26
    },
    {
      'id': 48,
      'name_arabic': 'ٱلْفَتْح',
      'name_simple': 'Al-Fath',
      'name_kurdish': 'فەتح',
      'verses_count': 29,
      'revelation_place': 'madinah',
      'page_start': 511,
      'juz_start': 26
    },
    {
      'id': 49,
      'name_arabic': 'ٱلْحُجُرَات',
      'name_simple': 'Al-Hujurat',
      'name_kurdish': 'حوجورات',
      'verses_count': 18,
      'revelation_place': 'madinah',
      'page_start': 515,
      'juz_start': 26
    },
    {
      'id': 50,
      'name_arabic': 'ق',
      'name_simple': 'Qaf',
      'name_kurdish': 'قاف',
      'verses_count': 45,
      'revelation_place': 'makkah',
      'page_start': 518,
      'juz_start': 26
    },
    {
      'id': 51,
      'name_arabic': 'ٱلذَّارِيَات',
      'name_simple': 'Adh-Dhariyat',
      'name_kurdish': 'زاریات',
      'verses_count': 60,
      'revelation_place': 'makkah',
      'page_start': 520,
      'juz_start': 26
    },
    {
      'id': 52,
      'name_arabic': 'ٱلطُّور',
      'name_simple': 'At-Tur',
      'name_kurdish': 'تور',
      'verses_count': 49,
      'revelation_place': 'makkah',
      'page_start': 523,
      'juz_start': 27
    },
    {
      'id': 53,
      'name_arabic': 'ٱلنَّجْم',
      'name_simple': 'An-Najm',
      'name_kurdish': 'نەجم',
      'verses_count': 62,
      'revelation_place': 'makkah',
      'page_start': 526,
      'juz_start': 27
    },
    {
      'id': 54,
      'name_arabic': 'ٱلْقَمَر',
      'name_simple': 'Al-Qamar',
      'name_kurdish': 'قەمەر',
      'verses_count': 55,
      'revelation_place': 'makkah',
      'page_start': 528,
      'juz_start': 27
    },
    {
      'id': 55,
      'name_arabic': 'ٱلرَّحْمَٰن',
      'name_simple': 'Ar-Rahman',
      'name_kurdish': 'ڕەحمان',
      'verses_count': 78,
      'revelation_place': 'madinah',
      'page_start': 531,
      'juz_start': 27
    },
    {
      'id': 56,
      'name_arabic': 'ٱلْوَاقِعَة',
      'name_simple': 'Al-Waqiah',
      'name_kurdish': 'واقیعە',
      'verses_count': 96,
      'revelation_place': 'makkah',
      'page_start': 534,
      'juz_start': 27
    },
    {
      'id': 57,
      'name_arabic': 'ٱلْحَدِيد',
      'name_simple': 'Al-Hadid',
      'name_kurdish': 'حەدید',
      'verses_count': 29,
      'revelation_place': 'madinah',
      'page_start': 537,
      'juz_start': 27
    },
    {
      'id': 58,
      'name_arabic': 'ٱلْمُجَادِلَة',
      'name_simple': 'Al-Mujadila',
      'name_kurdish': 'موجادیلە',
      'verses_count': 22,
      'revelation_place': 'madinah',
      'page_start': 542,
      'juz_start': 28
    },
    {
      'id': 59,
      'name_arabic': 'ٱلْحَشْر',
      'name_simple': 'Al-Hashr',
      'name_kurdish': 'حەشر',
      'verses_count': 24,
      'revelation_place': 'madinah',
      'page_start': 545,
      'juz_start': 28
    },
    {
      'id': 60,
      'name_arabic': 'ٱلْمُمْتَحَنَة',
      'name_simple': 'Al-Mumtahanah',
      'name_kurdish': 'مومتەحینە',
      'verses_count': 13,
      'revelation_place': 'madinah',
      'page_start': 549,
      'juz_start': 28
    },
    {
      'id': 61,
      'name_arabic': 'ٱلصَّف',
      'name_simple': 'As-Saf',
      'name_kurdish': 'سەف',
      'verses_count': 14,
      'revelation_place': 'madinah',
      'page_start': 551,
      'juz_start': 28
    },
    {
      'id': 62,
      'name_arabic': 'ٱلْجُمُعَة',
      'name_simple': 'Al-Jumuah',
      'name_kurdish': 'جومعە',
      'verses_count': 11,
      'revelation_place': 'madinah',
      'page_start': 553,
      'juz_start': 28
    },
    {
      'id': 63,
      'name_arabic': 'ٱلْمُنَافِقُون',
      'name_simple': 'Al-Munafiqun',
      'name_kurdish': 'موناقیقون',
      'verses_count': 11,
      'revelation_place': 'madinah',
      'page_start': 554,
      'juz_start': 28
    },
    {
      'id': 64,
      'name_arabic': 'ٱلتَّغَابُن',
      'name_simple': 'At-Taghabun',
      'name_kurdish': 'تەغابون',
      'verses_count': 18,
      'revelation_place': 'madinah',
      'page_start': 556,
      'juz_start': 28
    },
    {
      'id': 65,
      'name_arabic': 'ٱلطَّلَاق',
      'name_simple': 'At-Talaq',
      'name_kurdish': 'تەلاق',
      'verses_count': 12,
      'revelation_place': 'madinah',
      'page_start': 558,
      'juz_start': 28
    },
    {
      'id': 66,
      'name_arabic': 'ٱلتَّحْرِيم',
      'name_simple': 'At-Tahrim',
      'name_kurdish': 'تەحریم',
      'verses_count': 12,
      'revelation_place': 'madinah',
      'page_start': 560,
      'juz_start': 28
    },
    {
      'id': 67,
      'name_arabic': 'ٱلْمُلْك',
      'name_simple': 'Al-Mulk',
      'name_kurdish': 'موڵک',
      'verses_count': 30,
      'revelation_place': 'makkah',
      'page_start': 562,
      'juz_start': 29
    },
    {
      'id': 68,
      'name_arabic': 'ٱلْقَلَم',
      'name_simple': 'Al-Qalam',
      'name_kurdish': 'قەلەم',
      'verses_count': 52,
      'revelation_place': 'makkah',
      'page_start': 564,
      'juz_start': 29
    },
    {
      'id': 69,
      'name_arabic': 'ٱلْحَاقَّة',
      'name_simple': 'Al-Haqqah',
      'name_kurdish': 'حاققە',
      'verses_count': 52,
      'revelation_place': 'makkah',
      'page_start': 566,
      'juz_start': 29
    },
    {
      'id': 70,
      'name_arabic': 'ٱلْمَعَارِج',
      'name_simple': 'Al-Maarij',
      'name_kurdish': 'مەعارج',
      'verses_count': 44,
      'revelation_place': 'makkah',
      'page_start': 568,
      'juz_start': 29
    },
    {
      'id': 71,
      'name_arabic': 'نُوح',
      'name_simple': 'Nuh',
      'name_kurdish': 'نوح',
      'verses_count': 28,
      'revelation_place': 'makkah',
      'page_start': 570,
      'juz_start': 29
    },
    {
      'id': 72,
      'name_arabic': 'ٱلْجِن',
      'name_simple': 'Al-Jinn',
      'name_kurdish': 'جن',
      'verses_count': 28,
      'revelation_place': 'makkah',
      'page_start': 572,
      'juz_start': 29
    },
    {
      'id': 73,
      'name_arabic': 'ٱلْمُزَّمِّل',
      'name_simple': 'Al-Muzzammil',
      'name_kurdish': 'مووزەممیل',
      'verses_count': 20,
      'revelation_place': 'makkah',
      'page_start': 574,
      'juz_start': 29
    },
    {
      'id': 74,
      'name_arabic': 'ٱلْمُدَّثِّر',
      'name_simple': 'Al-Muddaththir',
      'name_kurdish': 'موددەسیر',
      'verses_count': 56,
      'revelation_place': 'makkah',
      'page_start': 575,
      'juz_start': 29
    },
    {
      'id': 75,
      'name_arabic': 'ٱلْقِيَامَة',
      'name_simple': 'Al-Qiyamah',
      'name_kurdish': 'قیامەت',
      'verses_count': 40,
      'revelation_place': 'makkah',
      'page_start': 577,
      'juz_start': 29
    },
    {
      'id': 76,
      'name_arabic': 'ٱلْإِنسَان',
      'name_simple': 'Al-Insan',
      'name_kurdish': 'ئینسان',
      'verses_count': 31,
      'revelation_place': 'madinah',
      'page_start': 578,
      'juz_start': 29
    },
    {
      'id': 77,
      'name_arabic': 'ٱلْمُرْسَلَات',
      'name_simple': 'Al-Mursalat',
      'name_kurdish': 'مورسەلات',
      'verses_count': 50,
      'revelation_place': 'makkah',
      'page_start': 580,
      'juz_start': 29
    },
    {
      'id': 78,
      'name_arabic': 'ٱلنَّبَأ',
      'name_simple': 'An-Naba',
      'name_kurdish': 'نەبە',
      'verses_count': 40,
      'revelation_place': 'makkah',
      'page_start': 582,
      'juz_start': 30
    },
    {
      'id': 79,
      'name_arabic': 'ٱلنَّازِعَات',
      'name_simple': 'An-Naziat',
      'name_kurdish': 'نازیعات',
      'verses_count': 46,
      'revelation_place': 'makkah',
      'page_start': 583,
      'juz_start': 30
    },
    {
      'id': 80,
      'name_arabic': 'عَبَسَ',
      'name_simple': 'Abasa',
      'name_kurdish': 'عەبەسە',
      'verses_count': 42,
      'revelation_place': 'makkah',
      'page_start': 585,
      'juz_start': 30
    },
    {
      'id': 81,
      'name_arabic': 'ٱلتَّكْوِير',
      'name_simple': 'At-Takwir',
      'name_kurdish': 'تەکویر',
      'verses_count': 29,
      'revelation_place': 'makkah',
      'page_start': 586,
      'juz_start': 30
    },
    {
      'id': 82,
      'name_arabic': 'ٱلِانفِطَار',
      'name_simple': 'Al-Infitar',
      'name_kurdish': 'ئینفیتار',
      'verses_count': 19,
      'revelation_place': 'makkah',
      'page_start': 587,
      'juz_start': 30
    },
    {
      'id': 83,
      'name_arabic': 'ٱلْمُطَفِّفِين',
      'name_simple': 'Al-Mutaffifin',
      'name_kurdish': 'مووتەففیفین',
      'verses_count': 36,
      'revelation_place': 'makkah',
      'page_start': 587,
      'juz_start': 30
    },
    {
      'id': 84,
      'name_arabic': 'ٱلِانشِقَاق',
      'name_simple': 'Al-Inshiqaq',
      'name_kurdish': 'ئینشیقاق',
      'verses_count': 25,
      'revelation_place': 'makkah',
      'page_start': 589,
      'juz_start': 30
    },
    {
      'id': 85,
      'name_arabic': 'ٱلْبُرُوج',
      'name_simple': 'Al-Buruj',
      'name_kurdish': 'بوروج',
      'verses_count': 22,
      'revelation_place': 'makkah',
      'page_start': 590,
      'juz_start': 30
    },
    {
      'id': 86,
      'name_arabic': 'ٱلطَّارِق',
      'name_simple': 'At-Tariq',
      'name_kurdish': 'تاریق',
      'verses_count': 17,
      'revelation_place': 'makkah',
      'page_start': 591,
      'juz_start': 30
    },
    {
      'id': 87,
      'name_arabic': 'ٱلْأَعْلَىٰ',
      'name_simple': 'Al-Ala',
      'name_kurdish': 'ئەعلا',
      'verses_count': 19,
      'revelation_place': 'makkah',
      'page_start': 591,
      'juz_start': 30
    },
    {
      'id': 88,
      'name_arabic': 'ٱلْغَاشِيَة',
      'name_simple': 'Al-Ghashiyah',
      'name_kurdish': 'غاشیە',
      'verses_count': 26,
      'revelation_place': 'makkah',
      'page_start': 592,
      'juz_start': 30
    },
    {
      'id': 89,
      'name_arabic': 'ٱلْفَجْر',
      'name_simple': 'Al-Fajr',
      'name_kurdish': 'فەجر',
      'verses_count': 30,
      'revelation_place': 'makkah',
      'page_start': 593,
      'juz_start': 30
    },
    {
      'id': 90,
      'name_arabic': 'ٱلْبَلَد',
      'name_simple': 'Al-Balad',
      'name_kurdish': 'بەلەد',
      'verses_count': 20,
      'revelation_place': 'makkah',
      'page_start': 594,
      'juz_start': 30
    },
    {
      'id': 91,
      'name_arabic': 'ٱلشَّمْس',
      'name_simple': 'Ash-Shams',
      'name_kurdish': 'شەمس',
      'verses_count': 15,
      'revelation_place': 'makkah',
      'page_start': 595,
      'juz_start': 30
    },
    {
      'id': 92,
      'name_arabic': 'ٱللَّيْل',
      'name_simple': 'Al-Layl',
      'name_kurdish': 'لەیل',
      'verses_count': 21,
      'revelation_place': 'makkah',
      'page_start': 595,
      'juz_start': 30
    },
    {
      'id': 93,
      'name_arabic': 'ٱلضُّحَىٰ',
      'name_simple': 'Ad-Duhaa',
      'name_kurdish': 'دوحا',
      'verses_count': 11,
      'revelation_place': 'makkah',
      'page_start': 596,
      'juz_start': 30
    },
    {
      'id': 94,
      'name_arabic': 'ٱلشَّرْح',
      'name_simple': 'Ash-Sharh',
      'name_kurdish': 'شەرح',
      'verses_count': 8,
      'revelation_place': 'makkah',
      'page_start': 596,
      'juz_start': 30
    },
    {
      'id': 95,
      'name_arabic': 'ٱلتِّين',
      'name_simple': 'At-Tin',
      'name_kurdish': 'تین',
      'verses_count': 8,
      'revelation_place': 'makkah',
      'page_start': 597,
      'juz_start': 30
    },
    {
      'id': 96,
      'name_arabic': 'ٱلْعَلَق',
      'name_simple': 'Al-Alaq',
      'name_kurdish': 'عەلەق',
      'verses_count': 19,
      'revelation_place': 'makkah',
      'page_start': 597,
      'juz_start': 30
    },
    {
      'id': 97,
      'name_arabic': 'ٱلْقَدْر',
      'name_simple': 'Al-Qadr',
      'name_kurdish': 'قەدر',
      'verses_count': 5,
      'revelation_place': 'makkah',
      'page_start': 598,
      'juz_start': 30
    },
    {
      'id': 98,
      'name_arabic': 'ٱلْبَيِّنَة',
      'name_simple': 'Al-Bayyinah',
      'name_kurdish': 'بەییینە',
      'verses_count': 8,
      'revelation_place': 'madinah',
      'page_start': 598,
      'juz_start': 30
    },
    {
      'id': 99,
      'name_arabic': 'ٱلزَّلْزَلَة',
      'name_simple': 'Az-Zalzalah',
      'name_kurdish': 'زەلزەلە',
      'verses_count': 8,
      'revelation_place': 'madinah',
      'page_start': 599,
      'juz_start': 30
    },
    {
      'id': 100,
      'name_arabic': 'ٱلْعَادِيَات',
      'name_simple': 'Al-Adiyat',
      'name_kurdish': 'عادیات',
      'verses_count': 11,
      'revelation_place': 'makkah',
      'page_start': 599,
      'juz_start': 30
    },
    {
      'id': 101,
      'name_arabic': 'ٱلْقَارِعَة',
      'name_simple': 'Al-Qariah',
      'name_kurdish': 'قارعە',
      'verses_count': 11,
      'revelation_place': 'makkah',
      'page_start': 600,
      'juz_start': 30
    },
    {
      'id': 102,
      'name_arabic': 'ٱلتَّكَاثُر',
      'name_simple': 'At-Takathur',
      'name_kurdish': 'تەکاسور',
      'verses_count': 8,
      'revelation_place': 'makkah',
      'page_start': 600,
      'juz_start': 30
    },
    {
      'id': 103,
      'name_arabic': 'ٱلْعَصْر',
      'name_simple': 'Al-Asr',
      'name_kurdish': 'عەسر',
      'verses_count': 3,
      'revelation_place': 'makkah',
      'page_start': 601,
      'juz_start': 30
    },
    {
      'id': 104,
      'name_arabic': 'ٱلْهُمَزَة',
      'name_simple': 'Al-Humazah',
      'name_kurdish': 'هومەزە',
      'verses_count': 9,
      'revelation_place': 'makkah',
      'page_start': 601,
      'juz_start': 30
    },
    {
      'id': 105,
      'name_arabic': 'ٱلْفِيل',
      'name_simple': 'Al-Fil',
      'name_kurdish': 'فیل',
      'verses_count': 5,
      'revelation_place': 'makkah',
      'page_start': 601,
      'juz_start': 30
    },
    {
      'id': 106,
      'name_arabic': 'قُرَيْش',
      'name_simple': 'Quraysh',
      'name_kurdish': 'قورەیش',
      'verses_count': 4,
      'revelation_place': 'makkah',
      'page_start': 602,
      'juz_start': 30
    },
    {
      'id': 107,
      'name_arabic': 'ٱلْمَاعُون',
      'name_simple': 'Al-Maun',
      'name_kurdish': 'ماعون',
      'verses_count': 7,
      'revelation_place': 'makkah',
      'page_start': 602,
      'juz_start': 30
    },
    {
      'id': 108,
      'name_arabic': 'ٱلْكَوْثَر',
      'name_simple': 'Al-Kawthar',
      'name_kurdish': 'کەوسەر',
      'verses_count': 3,
      'revelation_place': 'makkah',
      'page_start': 602,
      'juz_start': 30
    },
    {
      'id': 109,
      'name_arabic': 'ٱلْكَافِرُون',
      'name_simple': 'Al-Kafirun',
      'name_kurdish': 'کافیرون',
      'verses_count': 6,
      'revelation_place': 'makkah',
      'page_start': 603,
      'juz_start': 30
    },
    {
      'id': 110,
      'name_arabic': 'ٱلنَّصْر',
      'name_simple': 'An-Nasr',
      'name_kurdish': 'نەسر',
      'verses_count': 3,
      'revelation_place': 'madinah',
      'page_start': 603,
      'juz_start': 30
    },
    {
      'id': 111,
      'name_arabic': 'ٱلْمَسَد',
      'name_simple': 'Al-Masad',
      'name_kurdish': 'مەسەد',
      'verses_count': 5,
      'revelation_place': 'makkah',
      'page_start': 603,
      'juz_start': 30
    },
    {
      'id': 112,
      'name_arabic': 'ٱلْإِخْلَاص',
      'name_simple': 'Al-Ikhlas',
      'name_kurdish': 'ئیخلاس',
      'verses_count': 4,
      'revelation_place': 'makkah',
      'page_start': 604,
      'juz_start': 30
    },
    {
      'id': 113,
      'name_arabic': 'ٱلْفَلَق',
      'name_simple': 'Al-Falaq',
      'name_kurdish': 'فەلەق',
      'verses_count': 5,
      'revelation_place': 'makkah',
      'page_start': 604,
      'juz_start': 30
    },
    {
      'id': 114,
      'name_arabic': 'ٱلنَّاس',
      'name_simple': 'An-Nas',
      'name_kurdish': 'ناس',
      'verses_count': 6,
      'revelation_place': 'makkah',
      'page_start': 604,
      'juz_start': 30
    },
  ];

  static get fallbackSurahs => null;

  Future<void> importKurdishTranslation() async {}
}
