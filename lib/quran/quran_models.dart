// ═══════════════════════════════════════════════════════════════
//  lib/quran/quran_models.dart
//  مۆدێلەکانی داتای قورئان
// ═══════════════════════════════════════════════════════════════

/// زانیاری هەر ئایەتێک لە داتابەیسی مێتاداتا
class QuranAyah {
  final int id;
  final int surahNumber;
  final int ayahNumber;
  final String verseKey; // "1:1"
  final int wordsCount;
  final String text; // نووسینی عەرەبی

  const QuranAyah({
    required this.id,
    required this.surahNumber,
    required this.ayahNumber,
    required this.verseKey,
    required this.wordsCount,
    required this.text,
  });

  factory QuranAyah.fromMap(Map<String, dynamic> m) => QuranAyah(
        id: m['id'] as int,
        surahNumber: m['surah_number'] as int,
        ayahNumber: m['ayah_number'] as int,
        verseKey: m['verse_key'] as String,
        wordsCount: m['words_count'] as int,
        text: m['text'] as String,
      );
}

/// گلیفی QPC V2 بۆ نیشاندانی فۆنتی قورئان
class QuranGlyph {
  final int id;
  final String verseKey;
  final int surah;
  final int ayah;
  final String text; // کاراکتەرەکانی فۆنت
  final int pageNumber;

  const QuranGlyph({
    required this.id,
    required this.verseKey,
    required this.surah,
    required this.ayah,
    required this.text,
    required this.pageNumber,
  });

  factory QuranGlyph.fromMap(Map<String, dynamic> m) => QuranGlyph(
        id: m['id'] as int,
        verseKey: m['verse_key'] as String,
        surah: m['surah'] as int,
        ayah: m['ayah'] as int,
        text: m['text'] as String,
        pageNumber: m['page_number'] as int,
      );
}

/// زانیاری هەر لاپەرەیەک (15 ریز)
class QuranPageLine {
  final int pageNumber;
  final int lineNumber;
  final String lineType; // 'ayah' | 'surah_name' | 'basmallah'
  final bool isCentered;
  final String firstWordId;
  final String lastWordId;
  final String surahNumber;

  const QuranPageLine({
    required this.pageNumber,
    required this.lineNumber,
    required this.lineType,
    required this.isCentered,
    required this.firstWordId,
    required this.lastWordId,
    required this.surahNumber,
  });

  factory QuranPageLine.fromMap(Map<String, dynamic> m) => QuranPageLine(
        pageNumber: m['page_number'] as int,
        lineNumber: m['line_number'] as int,
        lineType: m['line_type'] as String,
        isCentered: (m['is_centered'] as int) == 1,
        firstWordId: m['first_word_id']?.toString() ?? '',
        lastWordId: m['last_word_id']?.toString() ?? '',
        surahNumber: m['surah_number']?.toString() ?? '',
      );
}

/// زانیاری دەنگی ئایەتێک لە JSON
class AyahAudio {
  final int surahNumber;
  final int ayahNumber;
  final String audioUrl;
  final int? duration; // milliseconds
  /// segments: [[word_index, start_ms, end_ms], ...]
  final List<List<int>> segments;

  const AyahAudio({
    required this.surahNumber,
    required this.ayahNumber,
    required this.audioUrl,
    this.duration,
    required this.segments,
  });

  factory AyahAudio.fromMap(String key, Map<String, dynamic> m) {
    final rawSegs = (m['segments'] as List<dynamic>? ?? []);
    final segs = rawSegs
        .map<List<int>>(
            (s) => (s as List<dynamic>).map<int>((e) => e as int).toList())
        .toList();
    return AyahAudio(
      surahNumber: m['surah_number'] as int,
      ayahNumber: m['ayah_number'] as int,
      audioUrl: m['audio_url'] as String,
      duration: m['duration'] as int?,
      segments: segs,
    );
  }

  String get verseKey => '$surahNumber:$ayahNumber';
}

/// ئایەتێک کە ئێستا هەڵبژێردراوە (بۆ هایلایت)
class SelectedAyah {
  final String verseKey;
  final int? activeWordIndex; // ئێستا کام وشە دەخوێنرێ

  const SelectedAyah({required this.verseKey, this.activeWordIndex});

  SelectedAyah copyWith({String? verseKey, int? activeWordIndex}) =>
      SelectedAyah(
        verseKey: verseKey ?? this.verseKey,
        activeWordIndex: activeWordIndex ?? this.activeWordIndex,
      );
}

/// ئایەتەکانی یەک سورە
class SurahInfo {
  final int number;
  final String name;
  final int totalAyahs;
  final bool isMakki; // مەکی یان مەدەنی

  const SurahInfo({
    required this.number,
    required this.name,
    required this.totalAyahs,
    required this.isMakki,
  });
}

// لیستی سورەکان - بریتی 114 سورە
const List<SurahInfo> kSurahList = [
  SurahInfo(number: 1, name: 'الفاتحة', totalAyahs: 7, isMakki: true),
  SurahInfo(number: 2, name: 'البقرة', totalAyahs: 286, isMakki: false),
  SurahInfo(number: 3, name: 'آل عمران', totalAyahs: 200, isMakki: false),
  SurahInfo(number: 4, name: 'النساء', totalAyahs: 176, isMakki: false),
  SurahInfo(number: 5, name: 'المائدة', totalAyahs: 120, isMakki: false),
  SurahInfo(number: 6, name: 'الأنعام', totalAyahs: 165, isMakki: true),
  SurahInfo(number: 7, name: 'الأعراف', totalAyahs: 206, isMakki: true),
  SurahInfo(number: 8, name: 'الأنفال', totalAyahs: 75, isMakki: false),
  SurahInfo(number: 9, name: 'التوبة', totalAyahs: 129, isMakki: false),
  SurahInfo(number: 10, name: 'يونس', totalAyahs: 109, isMakki: true),
  SurahInfo(number: 11, name: 'هود', totalAyahs: 123, isMakki: true),
  SurahInfo(number: 12, name: 'يوسف', totalAyahs: 111, isMakki: true),
  SurahInfo(number: 13, name: 'الرعد', totalAyahs: 43, isMakki: false),
  SurahInfo(number: 14, name: 'إبراهيم', totalAyahs: 52, isMakki: true),
  SurahInfo(number: 15, name: 'الحجر', totalAyahs: 99, isMakki: true),
  SurahInfo(number: 16, name: 'النحل', totalAyahs: 128, isMakki: true),
  SurahInfo(number: 17, name: 'الإسراء', totalAyahs: 111, isMakki: true),
  SurahInfo(number: 18, name: 'الكهف', totalAyahs: 110, isMakki: true),
  SurahInfo(number: 19, name: 'مريم', totalAyahs: 98, isMakki: true),
  SurahInfo(number: 20, name: 'طه', totalAyahs: 135, isMakki: true),
  SurahInfo(number: 21, name: 'الأنبياء', totalAyahs: 112, isMakki: true),
  SurahInfo(number: 22, name: 'الحج', totalAyahs: 78, isMakki: false),
  SurahInfo(number: 23, name: 'المؤمنون', totalAyahs: 118, isMakki: true),
  SurahInfo(number: 24, name: 'النور', totalAyahs: 64, isMakki: false),
  SurahInfo(number: 25, name: 'الفرقان', totalAyahs: 77, isMakki: true),
  SurahInfo(number: 26, name: 'الشعراء', totalAyahs: 227, isMakki: true),
  SurahInfo(number: 27, name: 'النمل', totalAyahs: 93, isMakki: true),
  SurahInfo(number: 28, name: 'القصص', totalAyahs: 88, isMakki: true),
  SurahInfo(number: 29, name: 'العنكبوت', totalAyahs: 69, isMakki: true),
  SurahInfo(number: 30, name: 'الروم', totalAyahs: 60, isMakki: true),
  SurahInfo(number: 31, name: 'لقمان', totalAyahs: 34, isMakki: true),
  SurahInfo(number: 32, name: 'السجدة', totalAyahs: 30, isMakki: true),
  SurahInfo(number: 33, name: 'الأحزاب', totalAyahs: 73, isMakki: false),
  SurahInfo(number: 34, name: 'سبأ', totalAyahs: 54, isMakki: true),
  SurahInfo(number: 35, name: 'فاطر', totalAyahs: 45, isMakki: true),
  SurahInfo(number: 36, name: 'يس', totalAyahs: 83, isMakki: true),
  SurahInfo(number: 37, name: 'الصافات', totalAyahs: 182, isMakki: true),
  SurahInfo(number: 38, name: 'ص', totalAyahs: 88, isMakki: true),
  SurahInfo(number: 39, name: 'الزمر', totalAyahs: 75, isMakki: true),
  SurahInfo(number: 40, name: 'غافر', totalAyahs: 85, isMakki: true),
  SurahInfo(number: 41, name: 'فصلت', totalAyahs: 54, isMakki: true),
  SurahInfo(number: 42, name: 'الشورى', totalAyahs: 53, isMakki: true),
  SurahInfo(number: 43, name: 'الزخرف', totalAyahs: 89, isMakki: true),
  SurahInfo(number: 44, name: 'الدخان', totalAyahs: 59, isMakki: true),
  SurahInfo(number: 45, name: 'الجاثية', totalAyahs: 37, isMakki: true),
  SurahInfo(number: 46, name: 'الأحقاف', totalAyahs: 35, isMakki: true),
  SurahInfo(number: 47, name: 'محمد', totalAyahs: 38, isMakki: false),
  SurahInfo(number: 48, name: 'الفتح', totalAyahs: 29, isMakki: false),
  SurahInfo(number: 49, name: 'الحجرات', totalAyahs: 18, isMakki: false),
  SurahInfo(number: 50, name: 'ق', totalAyahs: 45, isMakki: true),
  SurahInfo(number: 51, name: 'الذاريات', totalAyahs: 60, isMakki: true),
  SurahInfo(number: 52, name: 'الطور', totalAyahs: 49, isMakki: true),
  SurahInfo(number: 53, name: 'النجم', totalAyahs: 62, isMakki: true),
  SurahInfo(number: 54, name: 'القمر', totalAyahs: 55, isMakki: true),
  SurahInfo(number: 55, name: 'الرحمن', totalAyahs: 78, isMakki: false),
  SurahInfo(number: 56, name: 'الواقعة', totalAyahs: 96, isMakki: true),
  SurahInfo(number: 57, name: 'الحديد', totalAyahs: 29, isMakki: false),
  SurahInfo(number: 58, name: 'المجادلة', totalAyahs: 22, isMakki: false),
  SurahInfo(number: 59, name: 'الحشر', totalAyahs: 24, isMakki: false),
  SurahInfo(number: 60, name: 'الممتحنة', totalAyahs: 13, isMakki: false),
  SurahInfo(number: 61, name: 'الصف', totalAyahs: 14, isMakki: false),
  SurahInfo(number: 62, name: 'الجمعة', totalAyahs: 11, isMakki: false),
  SurahInfo(number: 63, name: 'المنافقون', totalAyahs: 11, isMakki: false),
  SurahInfo(number: 64, name: 'التغابن', totalAyahs: 18, isMakki: false),
  SurahInfo(number: 65, name: 'الطلاق', totalAyahs: 12, isMakki: false),
  SurahInfo(number: 66, name: 'التحريم', totalAyahs: 12, isMakki: false),
  SurahInfo(number: 67, name: 'الملك', totalAyahs: 30, isMakki: true),
  SurahInfo(number: 68, name: 'القلم', totalAyahs: 52, isMakki: true),
  SurahInfo(number: 69, name: 'الحاقة', totalAyahs: 52, isMakki: true),
  SurahInfo(number: 70, name: 'المعارج', totalAyahs: 44, isMakki: true),
  SurahInfo(number: 71, name: 'نوح', totalAyahs: 28, isMakki: true),
  SurahInfo(number: 72, name: 'الجن', totalAyahs: 28, isMakki: true),
  SurahInfo(number: 73, name: 'المزمل', totalAyahs: 20, isMakki: true),
  SurahInfo(number: 74, name: 'المدثر', totalAyahs: 56, isMakki: true),
  SurahInfo(number: 75, name: 'القيامة', totalAyahs: 40, isMakki: true),
  SurahInfo(number: 76, name: 'الإنسان', totalAyahs: 31, isMakki: false),
  SurahInfo(number: 77, name: 'المرسلات', totalAyahs: 50, isMakki: true),
  SurahInfo(number: 78, name: 'النبأ', totalAyahs: 40, isMakki: true),
  SurahInfo(number: 79, name: 'النازعات', totalAyahs: 46, isMakki: true),
  SurahInfo(number: 80, name: 'عبس', totalAyahs: 42, isMakki: true),
  SurahInfo(number: 81, name: 'التكوير', totalAyahs: 29, isMakki: true),
  SurahInfo(number: 82, name: 'الإنفطار', totalAyahs: 19, isMakki: true),
  SurahInfo(number: 83, name: 'المطففين', totalAyahs: 36, isMakki: true),
  SurahInfo(number: 84, name: 'الإنشقاق', totalAyahs: 25, isMakki: true),
  SurahInfo(number: 85, name: 'البروج', totalAyahs: 22, isMakki: true),
  SurahInfo(number: 86, name: 'الطارق', totalAyahs: 17, isMakki: true),
  SurahInfo(number: 87, name: 'الأعلى', totalAyahs: 19, isMakki: true),
  SurahInfo(number: 88, name: 'الغاشية', totalAyahs: 26, isMakki: true),
  SurahInfo(number: 89, name: 'الفجر', totalAyahs: 30, isMakki: true),
  SurahInfo(number: 90, name: 'البلد', totalAyahs: 20, isMakki: true),
  SurahInfo(number: 91, name: 'الشمس', totalAyahs: 15, isMakki: true),
  SurahInfo(number: 92, name: 'الليل', totalAyahs: 21, isMakki: true),
  SurahInfo(number: 93, name: 'الضحى', totalAyahs: 11, isMakki: true),
  SurahInfo(number: 94, name: 'الشرح', totalAyahs: 8, isMakki: true),
  SurahInfo(number: 95, name: 'التين', totalAyahs: 8, isMakki: true),
  SurahInfo(number: 96, name: 'العلق', totalAyahs: 19, isMakki: true),
  SurahInfo(number: 97, name: 'القدر', totalAyahs: 5, isMakki: true),
  SurahInfo(number: 98, name: 'البينة', totalAyahs: 8, isMakki: false),
  SurahInfo(number: 99, name: 'الزلزلة', totalAyahs: 8, isMakki: false),
  SurahInfo(number: 100, name: 'العاديات', totalAyahs: 11, isMakki: true),
  SurahInfo(number: 101, name: 'القارعة', totalAyahs: 11, isMakki: true),
  SurahInfo(number: 102, name: 'التكاثر', totalAyahs: 8, isMakki: true),
  SurahInfo(number: 103, name: 'العصر', totalAyahs: 3, isMakki: true),
  SurahInfo(number: 104, name: 'الهمزة', totalAyahs: 9, isMakki: true),
  SurahInfo(number: 105, name: 'الفيل', totalAyahs: 5, isMakki: true),
  SurahInfo(number: 106, name: 'قريش', totalAyahs: 4, isMakki: true),
  SurahInfo(number: 107, name: 'الماعون', totalAyahs: 7, isMakki: true),
  SurahInfo(number: 108, name: 'الكوثر', totalAyahs: 3, isMakki: true),
  SurahInfo(number: 109, name: 'الكافرون', totalAyahs: 6, isMakki: true),
  SurahInfo(number: 110, name: 'النصر', totalAyahs: 3, isMakki: false),
  SurahInfo(number: 111, name: 'المسد', totalAyahs: 5, isMakki: true),
  SurahInfo(number: 112, name: 'الإخلاص', totalAyahs: 4, isMakki: true),
  SurahInfo(number: 113, name: 'الفلق', totalAyahs: 5, isMakki: true),
  SurahInfo(number: 114, name: 'الناس', totalAyahs: 6, isMakki: true),
];
