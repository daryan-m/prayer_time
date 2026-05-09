// ═══════════════════════════════════════════════════════════════
//  lib/quran/quran_database_helper.dart
//  هەموو کارەکانی خوێندنەوەی داتابەیس و JSON
// ═══════════════════════════════════════════════════════════════
//
//  پێویستە ئەم پاکێجانە لە pubspec.yaml زیاد بکەیت:
//    sqflite: ^2.3.3+1
//    path: ^1.9.0
//    flutter/services.dart  (ناو فلوتەرەوە)
//
//  داتابەیسەکان و JSON دابنێ لە: assets/quran/
//  flutter:
//    assets:
//      - assets/quran/qpc-v2-15-lines.db
//      - assets/quran/qpc-v2-ayah-by-ayah-glyphs.db
//      - assets/quran/quran-metadata-ayah.sqlite
//      - assets/quran/ayah-recitation-<reciter>.json
// ═══════════════════════════════════════════════════════════════

import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'quran_models.dart';

class QuranDatabaseHelper {
  QuranDatabaseHelper._();
  static final QuranDatabaseHelper instance = QuranDatabaseHelper._();

  // ── داتابەیسەکان ──────────────────────────────────────────
  Database? _metaDb; // quran-metadata-ayah.sqlite
  Database? _glyphDb; // qpc-v2-ayah-by-ayah-glyphs.db
  Database? _pageDb; // qpc-v2-15-lines.db

  // ── کاش بۆ دەنگ ───────────────────────────────────────────
  final Map<String, AyahAudio> _audioCache = {};
  bool _audioCacheLoaded = false;

  // ─────────────────────────────────────────────────────────────
  //  کردنەوەی داتابەیس – کۆپی فایل لە assets بۆ ئەندام
  // ─────────────────────────────────────────────────────────────

  Future<Database> _openAssetDb(String assetName) async {
    final dbsPath = await getDatabasesPath();
    final path = join(dbsPath, assetName);

    if (!File(path).existsSync()) {
      // کۆپی لە assets
      final data = await rootBundle.load('assets/quran/$assetName');
      final bytes = data.buffer.asUint8List();
      await File(path).writeAsBytes(bytes, flush: true);
    }
    return openDatabase(path, readOnly: true);
  }

  Future<Database> get metaDb async {
    _metaDb ??= await _openAssetDb('quran-metadata-ayah.sqlite');
    return _metaDb!;
  }

  Future<Database> get glyphDb async {
    _glyphDb ??= await _openAssetDb('qpc-v2-ayah-by-ayah-glyphs.db');
    return _glyphDb!;
  }

  Future<Database> get pageDb async {
    _pageDb ??= await _openAssetDb('qpc-v2-15-lines.db');
    return _pageDb!;
  }

  // ─────────────────────────────────────────────────────────────
  //  خوێندنەوەی مێتاداتا
  // ─────────────────────────────────────────────────────────────

  /// هەموو ئایەتەکانی یەک سورە
  Future<List<QuranAyah>> getAyahsOfSurah(int surahNumber) async {
    final db = await metaDb;
    final rows = await db.query(
      'verses',
      where: 'surah_number = ?',
      whereArgs: [surahNumber],
      orderBy: 'ayah_number ASC',
    );
    return rows.map(QuranAyah.fromMap).toList();
  }

  /// ئایەتێکی دیاریکراو
  Future<QuranAyah?> getAyah(int surah, int ayah) async {
    final db = await metaDb;
    final rows = await db.query(
      'verses',
      where: 'surah_number = ? AND ayah_number = ?',
      whereArgs: [surah, ayah],
      limit: 1,
    );
    return rows.isEmpty ? null : QuranAyah.fromMap(rows.first);
  }

  /// گەڕان لە نووسینی قورئان (عەرەبی)
  Future<List<QuranAyah>> searchAyahs(String query) async {
    final db = await metaDb;
    final rows = await db.query(
      'verses',
      where: 'text LIKE ?',
      whereArgs: ['%$query%'],
    );
    return rows.map(QuranAyah.fromMap).toList();
  }

  // ─────────────────────────────────────────────────────────────
  //  خوێندنەوەی گلیفی QPC V2
  // ─────────────────────────────────────────────────────────────

  /// گلیفی ئایەتێک (بۆ نیشاندان بە فۆنتی قورئان)
  Future<QuranGlyph?> getGlyph(int surah, int ayah) async {
    final db = await glyphDb;
    final rows = await db.query(
      'verses',
      where: 'surah = ? AND ayah = ?',
      whereArgs: [surah, ayah],
      limit: 1,
    );
    return rows.isEmpty ? null : QuranGlyph.fromMap(rows.first);
  }

  /// هەموو گلیفەکانی یەک لاپەرە
  Future<List<QuranGlyph>> getGlyphsOfPage(int pageNumber) async {
    final db = await glyphDb;
    final rows = await db.query(
      'verses',
      where: 'page_number = ?',
      whereArgs: [pageNumber],
      orderBy: 'id ASC',
    );
    return rows.map(QuranGlyph.fromMap).toList();
  }

  /// هەموو گلیفەکانی یەک سورە
  Future<List<QuranGlyph>> getGlyphsOfSurah(int surahNumber) async {
    final db = await glyphDb;
    final rows = await db.query(
      'verses',
      where: 'surah = ?',
      whereArgs: [surahNumber],
      orderBy: 'ayah ASC',
    );
    return rows.map(QuranGlyph.fromMap).toList();
  }

  // ─────────────────────────────────────────────────────────────
  //  خوێندنەوەی زانیاری لاپەرە (15-line)
  // ─────────────────────────────────────────────────────────────

  /// هەموو ریزەکانی لاپەرەیەک
  Future<List<QuranPageLine>> getPageLines(int pageNumber) async {
    final db = await pageDb;
    final rows = await db.query(
      'pages',
      where: 'page_number = ?',
      whereArgs: [pageNumber],
      orderBy: 'line_number ASC',
    );
    return rows.map(QuranPageLine.fromMap).toList();
  }

  /// ژمارەی لاپەرەی یەک سورە
  Future<int> getSurahStartPage(int surahNumber) async {
    final db = await pageDb;
    final rows = await db.query(
      'pages',
      where: 'surah_number = ? AND line_type = ?',
      whereArgs: [surahNumber.toString(), 'surah_name'],
      orderBy: 'page_number ASC',
      limit: 1,
    );
    return rows.isEmpty ? 1 : rows.first['page_number'] as int;
  }

  /// کام لاپەرەیە ئەو ئایەتەیە
  Future<int?> getPageOfAyah(int surah, int ayah) async {
    final db = await glyphDb;
    final rows = await db.query(
      'verses',
      columns: ['page_number'],
      where: 'surah = ? AND ayah = ?',
      whereArgs: [surah, ayah],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['page_number'] as int;
  }

  // ─────────────────────────────────────────────────────────────
  //  خوێندنەوەی JSON دەنگ
  // ─────────────────────────────────────────────────────────────

  /// بارکردنی هەموو JSON یەک بۆ کاش (یەک جار تەنها)
  Future<void> loadAudioCache(String assetPath) async {
    if (_audioCacheLoaded) return;
    final raw = await rootBundle.loadString(assetPath);
    final Map<String, dynamic> decoded = json.decode(raw);
    for (final entry in decoded.entries) {
      _audioCache[entry.key] = AyahAudio.fromMap(
        entry.key,
        Map<String, dynamic>.from(entry.value),
      );
    }
    _audioCacheLoaded = true;
  }

  /// زانیاری دەنگی ئایەتێک
  AyahAudio? getAyahAudio(int surah, int ayah) {
    return _audioCache['$surah:$ayah'];
  }

  /// گەرانەوەی کاتی دەستپێکردن و کۆتایی ئایەتێک (ms) لە فایلی دەنگ
  /// ئەمەش بۆ پلەیەر لازمە بۆ سلێکتکردنی ئایەت بە ئایەت
  ({int start, int end})? getAyahTimestamp(int surah, int ayah) {
    final audio = getAyahAudio(surah, ayah);
    if (audio == null || audio.segments.isEmpty) return null;
    final firstSeg = audio.segments.first;
    final lastSeg = audio.segments.last;
    return (start: firstSeg[1], end: lastSeg[2]);
  }

  // ─────────────────────────────────────────────────────────────
  //  داخستنی داتابەیسەکان
  // ─────────────────────────────────────────────────────────────

  Future<void> closeAll() async {
    await _metaDb?.close();
    await _glyphDb?.close();
    await _pageDb?.close();
    _metaDb = null;
    _glyphDb = null;
    _pageDb = null;
  }
}
