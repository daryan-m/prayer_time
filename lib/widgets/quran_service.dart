import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ==================== مۆدێلەکان ====================

class QuranSurah {
  final int number;
  final String nameArabic;
  final String nameKurdish;
  final int ayahCount;
  final bool isMakki;
  final int juzStart;
  const QuranSurah({
    required this.number,
    required this.nameArabic,
    required this.nameKurdish,
    required this.ayahCount,
    required this.isMakki,
    required this.juzStart,
  });
}

class QuranReciter {
  final String nameArabic;
  final String nameKurdish;
  final String key;
  const QuranReciter({
    required this.nameArabic,
    required this.nameKurdish,
    required this.key,
  });
}

// ==================== قاریئەکان ====================

/// دۆخی داگیراوەی دێنگ (بەبێژماریانەی تەواو)
enum ReciterDlStatus { none, partial, complete }

const List<QuranReciter> quranReciters = [
  QuranReciter(
      nameArabic: 'مشاري العفاسي',
      nameKurdish: 'مشاری عەفاسی',
      key: 'Alafasy_128kbps'),
  QuranReciter(
      nameArabic: 'محمود خليل الحصري',
      nameKurdish: 'محموود حوسەری',
      key: 'Husary_128kbps'),
  QuranReciter(
      nameArabic: 'عبد الباسط (مرتل)',
      nameKurdish: 'عەبدولباسیت (مورەتتەل)',
      key: 'Abdul_Basit_Murattal_192kbps'),
  QuranReciter(
      nameArabic: 'عبد الباسط (مجود)',
      nameKurdish: 'عەبدولباسیت (موجەووەد)',
      key: 'Abdul_Basit_Mujawwad_128kbps'),
  QuranReciter(
      nameArabic: 'عبد الرحمن السديس',
      nameKurdish: 'عەبدورەحمان سودەیس',
      key: 'Abdurrahmaan_As-Sudais_192kbps'),
  QuranReciter(
      nameArabic: 'محمد صديق المنشاوي',
      nameKurdish: 'محەممەد مینشاوی',
      key: 'Minshawy_Murattal_128kbps'),
  QuranReciter(
      nameArabic: 'أبو بكر الشاطري',
      nameKurdish: 'ئەبوبەکر شاتیری',
      key: 'Abu_Bakr_Ash-Shaatree_128kbps'),
  QuranReciter(
      nameArabic: 'سعد الغامدي',
      nameKurdish: 'سەعد غامیدی',
      key: 'Ghamadi_40kbps'),
  QuranReciter(
      nameArabic: 'هاني الرفاعي',
      nameKurdish: 'هانی ڕیفاعی',
      key: 'Hani_Rifai_192kbps'),
  QuranReciter(
      nameArabic: 'علي الحذيفي',
      nameKurdish: 'علی حوزەیفی',
      key: 'Hudhaify_128kbps'),
  QuranReciter(
      nameArabic: 'أحمد العجمي',
      nameKurdish: 'ئەحمەد عەجەمی',
      key: 'ahmed_ibn_ali_al_ajamy_128kbps'),
  QuranReciter(
      nameArabic: 'عبدالله بصفر',
      nameKurdish: 'عەبدوللە بەسفەر',
      key: 'Abdullah_Basfar_192kbps'),
];

// ==================== سێرڤیسی قورئان ====================

class QuranService {
  static Map<String, dynamic>? _quranData;

  static Future<void> _ensureLoaded() async {
    if (_quranData != null) return;
    final String raw = await rootBundle.loadString('assets/quran/quran.json');
    _quranData = json.decode(raw) as Map<String, dynamic>;
  }

  /// ✅ FIX 1: سورەتەکان ڕاست بخات — تیکەڵبونەوە چاردەکات
  static Future<List<Map<String, dynamic>>> loadSurah(int surahNumber) async {
    await _ensureLoaded();

    // JSON تێخستنی جیا (data > surahs)
    final surahs = _quranData!['data']['surahs'] as List<dynamic>;

    // سورەتەی ڕاست بدۆزەوە
    final surah = surahs.firstWhere(
      (s) => s['number'] == surahNumber,
      orElse: () => throw Exception('سورە $surahNumber نەدۆزرایەوە'),
    );

    final ayahs = surah['ayahs'] as List<dynamic>;

    return ayahs.map<Map<String, dynamic>>((a) {
      // ✅ FIX 5: بسم الله لەگەل ئایەتی یەکەم
      String text = (a['text'] as String)
          .replaceAll('\uFEFF', '') // Zero-width no-break space
          .trim();

      return {
        'a': a['numberInSurah'] as int,
        't': text,
        'page': a['page'] as int,
        'juz': a['juz'] as int,
        'sajda': a['sajda'] ?? false,
      };
    }).toList();
  }

  /// ✅ FIX 2 & 6: لاپەرە ڕاست بخات — جوزئی ڕاست، ئایەتەکان بە لاپەرە
  static List<List<Map<String, dynamic>>> splitIntoPages(
      List<Map<String, dynamic>> ayahs) {
    final Map<int, List<Map<String, dynamic>>> pageMap = {};

    for (final ayah in ayahs) {
      final int page = ayah['page'] as int;
      pageMap.putIfAbsent(page, () => []).add(ayah);
    }

    // لاپەرەکان بە ڕێزدا
    final sortedKeys = pageMap.keys.toList()..sort();
    return sortedKeys.map((k) => pageMap[k]!).toList();
  }

  /// ✅ FIX 3: جوزئی یەکمەتی لاپەرەکە بگرە
  static int getFirstJuzOfPage(List<Map<String, dynamic>> pageAyahs) {
    if (pageAyahs.isEmpty) return 1;
    return (pageAyahs[0]['juz'] as int?) ?? 1;
  }

  // ── URLی دەنگ ──
  static String audioUrl(int surahNumber, int ayahNumber, String reciterKey) {
    final s = surahNumber.toString().padLeft(3, '0');
    final a = ayahNumber.toString().padLeft(3, '0');
    return 'https://everyayah.com/data/$reciterKey/$s$a.mp3';
  }

  // ── شوێنی فایلی لۆکەل — بە getApplicationSupportDirectory ──
  static Future<String> _audioDir(String key) async {
    Directory base;
    if (Platform.isAndroid) {
      base = await getApplicationDocumentsDirectory();
    } else {
      base = await getApplicationSupportDirectory();
    }
    final dir = Directory('${base.path}/quran_audio/$key');
    await dir.create(recursive: true);
    return dir.path;
  }

  static Future<String> _localFilePath(int s, int a, String key) async {
    final dir = await _audioDir(key);
    return '$dir/${s.toString().padLeft(3, '0')}${a.toString().padLeft(3, '0')}.mp3';
  }

  // پشکنینی داگیراوی ئایەت
  static Future<bool> isAyahDownloaded(int s, int a, String key) async {
    try {
      final path = await _localFilePath(s, a, key);
      final f = File(path);
      if (!await f.exists()) return false;
      final size = await f.length();
      return size > 500;
    } catch (_) {
      return false;
    }
  }

  static Future<String> _completionMarker(String key) async {
    final dir = await _audioDir(key);
    return '$dir/.complete';
  }

  static Future<void> markReciterDownloadComplete(String key) async {
    final marker = File(await _completionMarker(key));
    await marker.writeAsString('ok');
  }

  static Future<void> clearReciterDownloadComplete(String key) async {
    final marker = File(await _completionMarker(key));
    if (await marker.exists()) {
      await marker.delete();
    }
  }

  static Future<bool> isReciterDownloaded(String key) async {
    final marker = File(await _completionMarker(key));
    return marker.exists();
  }

  static Future<ReciterDlStatus> reciterDownloadStatus(String key) async {
    if (await isReciterDownloaded(key)) return ReciterDlStatus.complete;
    final dir = Directory(await _audioDir(key));
    if (!await dir.exists()) return ReciterDlStatus.none;
    final has = await _dirHasAnyMp3(dir);
    if (!has) return ReciterDlStatus.none;
    return ReciterDlStatus.partial;
  }

  static Future<bool> _dirHasAnyMp3(Directory d) async {
    await for (final e in d.list(followLinks: false)) {
      if (e is File && e.path.toLowerCase().endsWith('.mp3')) return true;
    }
    return false;
  }

  static Future<String> getAudioSource(int s, int a, String key) async {
    final path = await _localFilePath(s, a, key);
    if (await File(path).exists() && await File(path).length() > 500) {
      return path;
    }
    return audioUrl(s, a, key);
  }

  static Future<bool> downloadAyah(int s, int a, String key) async {
    final path = await _localFilePath(s, a, key);
    final f = File(path);
    if (await f.exists() && await f.length() > 500) return true;
    for (int tryCount = 0; tryCount < 3; tryCount++) {
      try {
        final resp = await http
            .get(Uri.parse(audioUrl(s, a, key)))
            .timeout(const Duration(seconds: 30));
        if (resp.statusCode == 200 && resp.bodyBytes.length > 500) {
          await f.writeAsBytes(resp.bodyBytes, flush: true);
          return true;
        }
      } catch (_) {
        if (tryCount == 2) {
          return false;
        }
      }
    }
    return false;
  }

  static Future<void> deleteReciter(String key) async {
    try {
      await clearReciterDownloadComplete(key);
      final dir = Directory(await _audioDir(key));
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {}
  }

  static Future<String> getAudioFolderPath(String key) async {
    return _audioDir(key);
  }
}

// ==================== داگرتنی کۆنترۆڵکراو ====================

class DownloadController {
  bool _cancelled = false;
  bool _paused = false;

  void cancel() => _cancelled = true;
  void pause() => _paused = true;
  void resume() => _paused = false;
  bool get isCancelled => _cancelled;
  bool get isPaused => _paused;

  Future<void> waitIfPaused() async {
    while (_paused && !_cancelled) {
      await Future.delayed(const Duration(milliseconds: 200));
    }
  }
}
