// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// quran_models.dart
// هەموو مۆدێلەکانی داتای ئەپی قورئانی پیرۆز
//
// سەرچاوەکان:
//   دەق عوسمانی  → tanzil.net  (SQLite .db)
//   وەرگێڕانی کوردی → tanzil.net/trans/ku.bamoki (TXT/SQLite)
//   دەنگ (ئۆنلاین) → cdn.islamic.network/quran/audio/
//   دەنگ (ئۆفلاین) → دابەزاندن و پاشەکەوتکردن لە storage
//   تایمینگ هایلایت → api.quran.com/api/v4
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

// ══════════════════════════════════════════
// ١. سورە
// ══════════════════════════════════════════

class Surah {
  final int id;
  final String nameArabic;
  final String nameSimple;
  final String nameKurdish;
  final int versesCount;
  final String revelationPlace; // makkah / madinah
  final int pageStart;
  final int juzStart;

  const Surah({
    required this.id,
    required this.nameArabic,
    required this.nameSimple,
    required this.nameKurdish,
    required this.versesCount,
    required this.revelationPlace,
    required this.pageStart,
    required this.juzStart,
  });

  factory Surah.fromMap(Map<String, dynamic> m) => Surah(
        id: m['id'] as int,
        nameArabic: m['name_arabic'] as String? ?? '',
        nameSimple: m['name_simple'] as String? ?? '',
        nameKurdish: m['name_kurdish'] as String? ?? '',
        versesCount: m['verses_count'] as int? ?? 0,
        revelationPlace: m['revelation_place'] as String? ?? '',
        pageStart: m['page_start'] as int? ?? 1,
        juzStart: m['juz_start'] as int? ?? 1,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name_arabic': nameArabic,
        'name_simple': nameSimple,
        'name_kurdish': nameKurdish,
        'verses_count': versesCount,
        'revelation_place': revelationPlace,
        'page_start': pageStart,
        'juz_start': juzStart,
      };

  bool get isMakki => revelationPlace == 'makkah';
  String get displayName => nameKurdish.isNotEmpty ? nameKurdish : nameArabic;
}

// ══════════════════════════════════════════
// ٢. ئایەت
// ══════════════════════════════════════════

class Ayah {
  final int id; // ناسنامەی گشتی ١-٦٢٣٦
  final int surahId;
  final int numberInSurah;
  final String textUthmani; // دەقی عوسمانی
  final String? textKurdish; // وەرگێڕانی کوردی بامۆکی
  final int page;
  final int juz;
  final bool sajda;

  const Ayah({
    required this.id,
    required this.surahId,
    required this.numberInSurah,
    required this.textUthmani,
    this.textKurdish,
    required this.page,
    required this.juz,
    this.sajda = false,
  });

  factory Ayah.fromMap(Map<String, dynamic> m) => Ayah(
        id: m['id'] as int,
        surahId: m['surah_id'] as int,
        numberInSurah: m['number_in_surah'] as int,
        textUthmani: m['text_uthmani'] as String? ?? '',
        textKurdish: m['text_kurdish'] as String?,
        page: m['page'] as int? ?? 1,
        juz: m['juz'] as int? ?? 1,
        sajda: (m['sajda'] as int? ?? 0) == 1,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'surah_id': surahId,
        'number_in_surah': numberInSurah,
        'text_uthmani': textUthmani,
        'text_kurdish': textKurdish,
        'page': page,
        'juz': juz,
        'sajda': sajda ? 1 : 0,
      };

  /// کلیدی MP3: مەسەلەن "002003" بۆ بقرە:٣
  String get audioKey =>
      '${surahId.toString().padLeft(3, '0')}${numberInSurah.toString().padLeft(3, '0')}';
}

// ══════════════════════════════════════════
// ٣. قاریئ
// ══════════════════════════════════════════

class Reciter {
  final String id;
  final String nameArabic;
  final String nameEnglish;
  final String style; // Murattal / Mujawwad
  final int bitrate; // 64 / 128

  const Reciter({
    required this.id,
    required this.nameArabic,
    required this.nameEnglish,
    required this.style,
    required this.bitrate,
  });

  /// URL ی یەک ئایەت — ئۆنلاین
  String onlineAudioUrl(int surahId, int ayahNumber) {
    final s = surahId.toString().padLeft(3, '0');
    final a = ayahNumber.toString().padLeft(3, '0');
    return 'https://cdn.islamic.network/quran/audio/$bitrate/$id/$s$a.mp3';
  }

  /// ناوی فایلی ئۆفلاین بۆ پاشەکەوتکردن
  String offlineFileName(int surahId, int ayahNumber) =>
      '${id}_${surahId.toString().padLeft(3, '0')}_${ayahNumber.toString().padLeft(3, '0')}.mp3';

  static const List<Reciter> defaults = [
    Reciter(
      id: 'ar.alafasy',
      nameArabic: 'مشاری راشد العفاسی',
      nameEnglish: 'Mishary Rashid Alafasy',
      style: 'Murattal',
      bitrate: 128,
    ),
    Reciter(
      id: 'ar.abdurrahmaansudais',
      nameArabic: 'عبدالرحمن السديس',
      nameEnglish: 'Abdurrahmaan As-Sudais',
      style: 'Murattal',
      bitrate: 128,
    ),
    Reciter(
      id: 'ar.husary',
      nameArabic: 'محمود خليل الحصری',
      nameEnglish: 'Mahmoud Khalil Al-Husary',
      style: 'Murattal',
      bitrate: 64,
    ),
    Reciter(
      id: 'ar.mahermuaiqly',
      nameArabic: 'ماهر المعيقلی',
      nameEnglish: 'Maher Al Muaiqly',
      style: 'Murattal',
      bitrate: 128,
    ),
    Reciter(
      id: 'ar.minshawi',
      nameArabic: 'محمد صديق المنشاوی',
      nameEnglish: 'Mohamed Siddiq al-Minshawi',
      style: 'Murattal',
      bitrate: 64,
    ),
    Reciter(
      id: 'ar.shaatree',
      nameArabic: 'أبو بكر الشاطری',
      nameEnglish: 'Abu Bakr Ash-Shaatree',
      style: 'Murattal',
      bitrate: 64,
    ),
  ];
}

// ══════════════════════════════════════════
// ٤. تایمینگی هایلایت (api.quran.com)
// ══════════════════════════════════════════

class WordTiming {
  final int position; // ژمارەی وشە لە ئایەتەکەدا
  final int startMs; // دەستپێکردن (ms)
  final int endMs; // کۆتایی (ms)
  final String text;

  const WordTiming({
    required this.position,
    required this.startMs,
    required this.endMs,
    required this.text,
  });

  factory WordTiming.fromJson(Map<String, dynamic> j) => WordTiming(
        position: j['position'] as int? ?? 0,
        startMs: ((j['timestamp_from'] as num?) ?? 0).toInt(),
        endMs: ((j['timestamp_to'] as num?) ?? 0).toInt(),
        text: j['text_uthmani'] as String? ?? '',
      );
}

class AyahTiming {
  final int ayahId;
  final int surahId;
  final int numberInSurah;
  final List<WordTiming> words;

  const AyahTiming({
    required this.ayahId,
    required this.surahId,
    required this.numberInSurah,
    required this.words,
  });

  int get startMs => words.isNotEmpty ? words.first.startMs : 0;
  int get endMs => words.isNotEmpty ? words.last.endMs : 0;

  factory AyahTiming.fromJson(Map<String, dynamic> j) {
    final wordList = (j['words'] as List<dynamic>? ?? [])
        .map((w) => WordTiming.fromJson(w as Map<String, dynamic>))
        .toList();
    return AyahTiming(
      ayahId: j['id'] as int? ?? 0,
      surahId: j['surah_id'] as int? ?? 0,
      numberInSurah: j['ayah_number'] as int? ?? 0,
      words: wordList,
    );
  }
}

// ══════════════════════════════════════════
// ٥. دۆخی خوێندنەوە و دەنگ
// ══════════════════════════════════════════

class QuranReadingState {
  final int surahId;
  final int ayahNumber;
  final int page;

  const QuranReadingState({
    required this.surahId,
    required this.ayahNumber,
    required this.page,
  });

  factory QuranReadingState.initial() =>
      const QuranReadingState(surahId: 1, ayahNumber: 1, page: 1);

  QuranReadingState copyWith({int? surahId, int? ayahNumber, int? page}) =>
      QuranReadingState(
        surahId: surahId ?? this.surahId,
        ayahNumber: ayahNumber ?? this.ayahNumber,
        page: page ?? this.page,
      );

  Map<String, dynamic> toMap() =>
      {'surah_id': surahId, 'ayah_number': ayahNumber, 'page': page};

  factory QuranReadingState.fromMap(Map<String, dynamic> m) =>
      QuranReadingState(
        surahId: m['surah_id'] as int? ?? 1,
        ayahNumber: m['ayah_number'] as int? ?? 1,
        page: m['page'] as int? ?? 1,
      );
}

enum AudioPlaybackState { idle, loading, playing, paused, error }

class AudioState {
  final AudioPlaybackState status;
  final int? currentSurahId;
  final int? currentAyahNumber;
  final int? highlightedWordIndex; // ئایندێکسی وشەی ئێستا
  final Duration position;
  final Duration duration;
  final Reciter? reciter;
  final String? errorMessage;

  const AudioState({
    this.status = AudioPlaybackState.idle,
    this.currentSurahId,
    this.currentAyahNumber,
    this.highlightedWordIndex,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.reciter,
    this.errorMessage,
  });

  bool get isPlaying => status == AudioPlaybackState.playing;
  bool get isLoading => status == AudioPlaybackState.loading;
  bool get hasError => status == AudioPlaybackState.error;

  AudioState copyWith({
    AudioPlaybackState? status,
    int? currentSurahId,
    int? currentAyahNumber,
    int? highlightedWordIndex,
    Duration? position,
    Duration? duration,
    Reciter? reciter,
    String? errorMessage,
  }) =>
      AudioState(
        status: status ?? this.status,
        currentSurahId: currentSurahId ?? this.currentSurahId,
        currentAyahNumber: currentAyahNumber ?? this.currentAyahNumber,
        highlightedWordIndex: highlightedWordIndex ?? this.highlightedWordIndex,
        position: position ?? this.position,
        duration: duration ?? this.duration,
        reciter: reciter ?? this.reciter,
        errorMessage: errorMessage ?? this.errorMessage,
      );

  AudioState get idle => const AudioState();
}
