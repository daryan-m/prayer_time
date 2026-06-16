import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'quran_models.dart';

class QuranDatabaseHelper {
  static final QuranDatabaseHelper _instance = QuranDatabaseHelper._internal();
  factory QuranDatabaseHelper() => _instance;
  QuranDatabaseHelper._internal();

  Database? _wordsDb;
  Database? _linesDb;
  Database? _glyphsDb;
  Database? _surahNameDb;
  Database? _juzDb;
  Database? _hizbDb;
  Database? _ayahDb;

  Map<String, AyahRecitation>? _recitationData;
  String? _loadedReciterId;

  Map<int, int>? _pageJuzMap;
  Map<int, int>? _pageSurahMap;

  // ─── Init ─────────────────────────────────────────────────────────────────

  Future<void> initAll() async {
    await Future.wait([
      _openWordsDb(),
      _openLinesDb(),
      _openGlyphsDb(),
      _openSurahNameDb(),
      _openJuzDb(),
      _openHizbDb(),
      _openAyahDb(),
    ]);
    await _buildPageMaps();
  }

  Future<Database> _openAssetDb(String assetName) async {
    final dbPath = join(await getDatabasesPath(), assetName);
    if (!await File(dbPath).exists()) {
      final data = await rootBundle.load('assets/quran/$assetName');
      final bytes = data.buffer.asUint8List();
      await File(dbPath).writeAsBytes(bytes);
    }
    return openDatabase(dbPath, readOnly: true);
  }

  Future<void> _openWordsDb() async =>
      _wordsDb = await _openAssetDb('qpc-v2.db');

  Future<void> _openLinesDb() async =>
      _linesDb = await _openAssetDb('qpc-v2-15-lines.db');

  Future<void> _openGlyphsDb() async =>
      _glyphsDb = await _openAssetDb('qpc-v2-ayah-by-ayah-glyphs.db');

  Future<void> _openSurahNameDb() async =>
      _surahNameDb = await _openAssetDb('quran-metadata-surah-name.sqlite');

  Future<void> _openJuzDb() async =>
      _juzDb = await _openAssetDb('quran-metadata-juz.sqlite');

  Future<void> _openHizbDb() async =>
      _hizbDb = await _openAssetDb('quran-metadata-hizb.sqlite');

  Future<void> _openAyahDb() async =>
      _ayahDb = await _openAssetDb('quran-metadata-ayah.sqlite');

  // ─── Page Lines ───────────────────────────────────────────────────────────

  Future<List<QuranPageLine>> getLinesForPage(int pageNumber) async {
    final rows = await _linesDb!.query(
      'pages',
      where: 'page_number = ?',
      whereArgs: [pageNumber],
      orderBy: 'line_number ASC',
    );
    return rows.map((r) => QuranPageLine.fromMap(r)).toList();
  }

  // ─── Words ────────────────────────────────────────────────────────────────

  Future<List<QuranWord>> getWordsRange(int firstId, int lastId) async {
    final rows = await _wordsDb!.query(
      'words',
      where: 'id >= ? AND id <= ?',
      whereArgs: [firstId, lastId],
      orderBy: 'id ASC',
    );
    return rows.map((r) => QuranWord.fromMap(r)).toList();
  }

  Future<List<QuranWord>> getWordsForAyah(int surah, int ayah) async {
    final rows = await _wordsDb!.query(
      'words',
      where: 'surah = ? AND ayah = ?',
      whereArgs: [surah, ayah],
      orderBy: 'word ASC',
    );
    return rows.map((r) => QuranWord.fromMap(r)).toList();
  }

  // ─── Ayah Glyphs ──────────────────────────────────────────────────────────

  Future<QuranAyahGlyph?> getAyahGlyph(int surah, int ayah) async {
    final rows = await _glyphsDb!.query(
      'verses',
      where: 'surah = ? AND ayah = ?',
      whereArgs: [surah, ayah],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return QuranAyahGlyph.fromMap(rows.first);
  }

  Future<int> getPageForAyah(int surah, int ayah) async {
    final rows = await _glyphsDb!.query(
      'verses',
      columns: ['page_number'],
      where: 'surah = ? AND ayah = ?',
      whereArgs: [surah, ayah],
      limit: 1,
    );
    if (rows.isEmpty) return 1;
    return rows.first['page_number'] as int;
  }

  // ─── Surah Info ───────────────────────────────────────────────────────────

  Future<List<SurahInfo>> getAllSurahs() async {
    final rows = await _surahNameDb!.query('chapters', orderBy: 'id ASC');
    return rows.map((r) => SurahInfo.fromMap(r)).toList();
  }

  Future<SurahInfo?> getSurahInfo(int surahNumber) async {
    final rows = await _surahNameDb!.query(
      'chapters',
      where: 'id = ?',
      whereArgs: [surahNumber],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return SurahInfo.fromMap(rows.first);
  }

  // ─── Juz Info ─────────────────────────────────────────────────────────────

  Future<List<JuzInfo>> getAllJuz() async {
    final rows = await _juzDb!.query('juz', orderBy: 'juz_number ASC');
    return rows.map((r) => JuzInfo.fromMap(r)).toList();
  }

  Future<int> getJuzForAyah(int surah, int ayah) async {
    final rows = await _juzDb!.query('juz', orderBy: 'juz_number ASC');
    for (final row in rows.reversed) {
      final parts = (row['first_verse_key'] as String).split(':');
      final fSurah = int.parse(parts[0]);
      final fAyah = int.parse(parts[1]);
      if (surah > fSurah || (surah == fSurah && ayah >= fAyah)) {
        return row['juz_number'] as int;
      }
    }
    return 1;
  }

  // ─── Hizb Info ────────────────────────────────────────────────────────────

  Future<List<HizbInfo>> getAllHizb() async {
    final rows = await _hizbDb!.query('hizbs', orderBy: 'hizb_number ASC');
    return rows.map((r) => HizbInfo.fromMap(r)).toList();
  }

  // ─── Ayah Metadata ────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getAyahMeta(int surah, int ayah) async {
    final rows = await _ayahDb!.query(
      'verses',
      where: 'surah_number = ? AND ayah_number = ?',
      whereArgs: [surah, ayah],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  // ─── Page Maps (cache) ────────────────────────────────────────────────────

  Future<void> _buildPageMaps() async {
    _pageJuzMap = {};
    _pageSurahMap = {};

    final rows = await _glyphsDb!.rawQuery('''
      SELECT page_number, MIN(surah) as first_surah, MIN(ayah) as first_ayah
      FROM verses
      GROUP BY page_number
      ORDER BY page_number
    ''');

    final juzRows = await _juzDb!.query('juz', orderBy: 'juz_number ASC');
    final juzList = juzRows.map((r) => JuzInfo.fromMap(r)).toList();

    for (final row in rows) {
      final page = row['page_number'] as int;
      final surah = row['first_surah'] as int;
      final ayah = row['first_ayah'] as int;

      _pageSurahMap![page] = surah;

      int juz = 1;
      for (final j in juzList.reversed) {
        final parts = j.firstVerseKey.split(':');
        final fSurah = int.parse(parts[0]);
        final fAyah = int.parse(parts[1]);
        if (surah > fSurah || (surah == fSurah && ayah >= fAyah)) {
          juz = j.juzNumber;
          break;
        }
      }
      _pageJuzMap![page] = juz;
    }
  }

  int getJuzForPage(int pageNumber) => _pageJuzMap?[pageNumber] ?? 1;

  int getSurahForPage(int pageNumber) => _pageSurahMap?[pageNumber] ?? 1;

  // ─── Recitation Data ──────────────────────────────────────────────────────

  Future<void> loadBuiltInRecitation(String fileName) async {
    if (_loadedReciterId == fileName) return;
    final jsonStr = await rootBundle.loadString('assets/quran/$fileName');
    _parseRecitationJson(jsonStr, fileName);
  }

  Future<void> loadDownloadedRecitation(String filePath, String id) async {
    if (_loadedReciterId == id) return;
    final file = File(filePath);
    if (!await file.exists()) return;
    final jsonStr = await file.readAsString();
    _parseRecitationJson(jsonStr, id);
  }

  void _parseRecitationJson(String jsonStr, String id) {
    final Map<String, dynamic> raw = json.decode(jsonStr);
    _recitationData = raw.map(
      (key, value) => MapEntry(
        key,
        AyahRecitation.fromMap(value as Map<String, dynamic>),
      ),
    );
    _loadedReciterId = id;
  }

  AyahRecitation? getAyahRecitation(int surah, int ayah) =>
      _recitationData?['$surah:$ayah'];

  bool get hasRecitationLoaded => _recitationData != null;

  void clearRecitation() {
    _recitationData = null;
    _loadedReciterId = null;
  }

  // ─── Search ───────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> searchAyahs(String query) async {
    final clean = query.replaceAll(
      RegExp(
          r'[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06DC\u06DF-\u06E4\u06E7\u06E8\u06EA-\u06ED]'),
      '',
    );
    final rows = await _ayahDb!.rawQuery('''
      SELECT surah_number, ayah_number, verse_key,
             REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
             REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
             text,
             char(0x064B),''), char(0x064C),''), char(0x064D),''),
             char(0x064E),''), char(0x064F),''), char(0x0650),''),
             char(0x0651),''), char(0x0652),''), char(0x0653),''),
             char(0x0654),'') as clean_text,
             text as original_text
      FROM verses
      WHERE clean_text LIKE ?
      ORDER BY surah_number ASC, ayah_number ASC
      LIMIT 100
    ''', ['%$clean%']);

    return rows
        .map((r) => {
              'surah_number': r['surah_number'],
              'ayah_number': r['ayah_number'],
              'verse_key': r['verse_key'],
              'text': r['original_text'],
            })
        .toList();
  }

  // ─── Close ────────────────────────────────────────────────────────────────

  Future<void> closeAll() async {
    await Future.wait([
      _wordsDb?.close() ?? Future.value(),
      _linesDb?.close() ?? Future.value(),
      _glyphsDb?.close() ?? Future.value(),
      _surahNameDb?.close() ?? Future.value(),
      _juzDb?.close() ?? Future.value(),
      _hizbDb?.close() ?? Future.value(),
      _ayahDb?.close() ?? Future.value(),
    ]);
  }
}
