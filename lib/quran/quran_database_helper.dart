// lib/quran/quran_database_helper.dart
// ═══════════════════════════════════════════════════════════════
//  هەموو کارەکانی داتابەیس
//  + WordMap: word_id → (verse_key, ayah_start, meta_count)
//  + LineGlyph: گلیفی هەر ریزێک بەپێی word slice
// ═══════════════════════════════════════════════════════════════

import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'quran_models.dart';

// ─────────────────────────────────────────────────────────────
//  مۆدێلی زانیاری وشە
// ─────────────────────────────────────────────────────────────

class WordInfo {
  final String verseKey;
  final int ayahStart; // global word_id یەکەمی ئەم ئایەتە
  final int metaCount; // ژمارەی وشەکان لە metadata
  const WordInfo(this.verseKey, this.ayahStart, this.metaCount);
}

/// گلیفی یەک chunk لە ریزێک
class LineChunk {
  final String verseKey;
  final String glyphText; // بەشی گلیفی ئەم ریزە لەم ئایەتەوە
  const LineChunk(this.verseKey, this.glyphText);
}

// ═══════════════════════════════════════════════════════════════
//  QuranDatabaseHelper
// ═══════════════════════════════════════════════════════════════

class QuranDatabaseHelper {
  QuranDatabaseHelper._();
  static final QuranDatabaseHelper instance = QuranDatabaseHelper._();

  Database? _metaDb;
  Database? _glyphDb;
  Database? _pageDb;

  // ── WordMap cache ──────────────────────────────────────────
  /// word_id → WordInfo  (بار دەکرێت یەک جار)
  final Map<int, WordInfo> _wordMap = {};
  bool _wordMapLoaded = false;

  /// verse_key → گلیفەکانی ئایەت (split بەسپەیس)
  final Map<String, List<String>> _glyphCache = {};

  // ── Audio cache ────────────────────────────────────────────
  final Map<String, AyahAudio> _audioCache = {};
  bool _audioCacheLoaded = false;

  // ─────────────────────────────────────────────────────────────
  //  کردنەوەی داتابەیسەکان
  // ─────────────────────────────────────────────────────────────

  Future<Database> _openAssetDb(String assetName) async {
    final dbsPath = await getDatabasesPath();
    final path = join(dbsPath, assetName);
    if (!File(path).existsSync()) {
      final data = await rootBundle.load('assets/quran/$assetName');
      final bytes = data.buffer.asUint8List();
      await File(path).writeAsBytes(bytes, flush: true);
    }
    return openDatabase(path, readOnly: true);
  }

  Future<Database> get metaDb async =>
      _metaDb ??= await _openAssetDb('quran-metadata-ayah.sqlite');
  Future<Database> get glyphDb async =>
      _glyphDb ??= await _openAssetDb('qpc-v2-ayah-by-ayah-glyphs.db');
  Future<Database> get pageDb async =>
      _pageDb ??= await _openAssetDb('qpc-v2-15-lines.db');

  // ─────────────────────────────────────────────────────────────
  //  WordMap — بارکردن یەک جار لە دەستپێکردن
  // ─────────────────────────────────────────────────────────────

  /// پێویستە یەک جار لە دەستپێکی ئەپ بانگ بکرێت
  Future<void> buildWordMap() async {
    if (_wordMapLoaded) return;
    final db = await metaDb;
    final rows = await db.query(
      'verses',
      columns: ['verse_key', 'words_count'],
      orderBy: 'id ASC',
    );
    int wc = 0;
    for (final row in rows) {
      final vk = row['verse_key'] as String;
      final cnt = row['words_count'] as int;
      final start = wc + 1;
      final info = WordInfo(vk, start, cnt);
      for (int w = start; w <= wc + cnt; w++) {
        _wordMap[w] = info;
      }
      wc += cnt;
    }
    _wordMapLoaded = true;
  }

  // ─────────────────────────────────────────────────────────────
  //  گلیف Cache
  // ─────────────────────────────────────────────────────────────

  Future<List<String>> _getGlyphWords(String verseKey) async {
    if (_glyphCache.containsKey(verseKey)) return _glyphCache[verseKey]!;
    final db = await glyphDb;
    final rows = await db.query(
      'verses',
      columns: ['text'],
      where: 'verse_key = ?',
      whereArgs: [verseKey],
      limit: 1,
    );
    if (rows.isEmpty) {
      _glyphCache[verseKey] = [];
      return [];
    }
    final words = (rows.first['text'] as String).split(' ');
    _glyphCache[verseKey] = words;
    return words;
  }

  // ─────────────────────────────────────────────────────────────
  //  ریزبەندی لاپەرە — بناو WordMap و گلیف Slice
  // ─────────────────────────────────────────────────────────────

  /// گلیفەکانی هەر ریزێک لاپەرەیەک بەشێوەی [LineChunk]
  ///
  /// ئەلگۆریزم:
  ///  1. هەر ریز first_word_id و last_word_id هەیەتی
  ///  2. بەپێی _wordMap بزانە کام ئایەتەکانی ئەو ریزەن
  ///  3. بۆ هەر ئایەت: glyph[local_start..local_end] بگرە
  ///     (local_idx = word_id - ayah_start)
  Future<List<LineChunk>> getLineChunks(QuranPageLine line) async {
    if (line.lineType != 'ayah') return [];
    final fw = int.tryParse(line.firstWordId) ?? 0;
    final lw = int.tryParse(line.lastWordId) ?? 0;
    if (fw == 0 || lw == 0) return [];

    await buildWordMap();

    final result = <LineChunk>[];
    int i = fw;
    while (i <= lw) {
      final info = _wordMap[i];
      if (info == null) {
        i++;
        continue;
      }

      final vk = info.verseKey;
      final ayahStart = info.ayahStart;
      final metaCount = info.metaCount;
      final lastOfAyah = ayahStart + metaCount - 1;
      final sliceEnd = lw < lastOfAyah ? lw : lastOfAyah;

      final gStart = i - ayahStart; // 0-based
      final gEnd = sliceEnd - ayahStart; // inclusive

      final gWords = await _getGlyphWords(vk);
      // تەنها [0..metaCount-1] وشەکانی ئاسایین، بەدواییەکان مارکەرن
      final safeEnd = (gEnd + 1).clamp(0, metaCount).clamp(0, gWords.length);
      final safeStart = gStart.clamp(0, safeEnd);

      if (safeStart < safeEnd) {
        final chunk = gWords.sublist(safeStart, safeEnd).join(' ');
        result.add(LineChunk(vk, chunk));
      }

      i = sliceEnd + 1;
    }
    return result;
  }

  // ─────────────────────────────────────────────────────────────
  //  API-ی ئاسایی
  // ─────────────────────────────────────────────────────────────

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
  //  Audio Cache
  // ─────────────────────────────────────────────────────────────

  Future<void> loadAudioCache(String assetPath) async {
    if (_audioCacheLoaded) return;
    final raw = await rootBundle.loadString(assetPath);
    final decoded = json.decode(raw) as Map<String, dynamic>;
    for (final entry in decoded.entries) {
      _audioCache[entry.key] =
          AyahAudio.fromMap(entry.key, Map<String, dynamic>.from(entry.value));
    }
    _audioCacheLoaded = true;
  }

  AyahAudio? getAyahAudio(int surah, int ayah) => _audioCache['$surah:$ayah'];

  Future<void> closeAll() async {
    await _metaDb?.close();
    await _glyphDb?.close();
    await _pageDb?.close();
    _metaDb = _glyphDb = _pageDb = null;
  }
}
