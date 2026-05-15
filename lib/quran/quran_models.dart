// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// quran_models.dart
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

// ══════════════════════════════════════════
// سورە
// ══════════════════════════════════════════

class Surah {
  final int id;
  final String nameArabic;
  final String nameSimple;
  final String nameKurdish;
  final int versesCount;
  final String revelationPlace;
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
        revelationPlace: m['revelation_place'] as String? ?? 'makkah',
        pageStart: m['page_start'] as int? ?? 1,
        juzStart: m['juz_start'] as int? ?? 1,
      );

  bool get isMakki => revelationPlace == 'makkah';
  String get displayName => nameKurdish.isNotEmpty ? nameKurdish : nameArabic;
}

// ══════════════════════════════════════════
// ئایەت — بە schema ی tanzil
// quran_text: index, sura, aya, text
// kurdish_translation: sura, aya, text
// ══════════════════════════════════════════

class Ayah {
  final int id; // index لە quran_text
  final int surahId; // sura
  final int numberInSurah; // aya
  final String textUthmani; // text لە quran_text
  final String? textKurdish; // text لە kurdish_translation
  final int page;
  final int juz;
  final bool sajda;

  const Ayah({
    required this.id,
    required this.surahId,
    required this.numberInSurah,
    required this.textUthmani,
    this.textKurdish,
    this.page = 0,
    this.juz = 0,
    this.sajda = false,
  });

  factory Ayah.fromMap(Map<String, dynamic> m) => Ayah(
        id: m['id'] as int? ?? 0,
        surahId: m['surah_id'] as int? ?? 0,
        numberInSurah: m['number_in_surah'] as int? ?? 0,
        textUthmani: m['text_uthmani'] as String? ?? '',
        textKurdish: m['text_kurdish'] as String?,
        page: m['page'] as int? ?? 0,
        juz: m['juz'] as int? ?? 0,
        sajda: (m['sajda'] as int? ?? 0) == 1,
      );

  /// کلیدی MP3: مەسەلەن "002003"
  String get audioKey =>
      '${surahId.toString().padLeft(3, '0')}${numberInSurah.toString().padLeft(3, '0')}';
}

// ══════════════════════════════════════════
// قاریئ
// ══════════════════════════════════════════

class Reciter {
  final String id;
  final String nameArabic;
  final String nameEnglish;
  final String style;
  final int bitrate;

  const Reciter({
    required this.id,
    required this.nameArabic,
    required this.nameEnglish,
    required this.style,
    required this.bitrate,
  });

  /// URL ی یەک ئایەت — cdn.islamic.network
  String onlineAudioUrl(int surahId, int ayahNumber) {
    final s = surahId.toString().padLeft(3, '0');
    final a = ayahNumber.toString().padLeft(3, '0');
    return 'https://cdn.islamic.network/quran/audio/$bitrate/$id/$s$a.mp3';
  }

  String offlineFileName(int surahId, int ayahNumber) {
    final s = surahId.toString().padLeft(3, '0');
    final a = ayahNumber.toString().padLeft(3, '0');
    return '${id}_$s$a.mp3';
  }

  static List<Reciter> defaults = [
    const Reciter(
      id: 'ar.alafasy',
      nameArabic: 'مشاری راشد العفاسی',
      nameEnglish: 'Mishary Alafasy',
      style: 'Murattal',
      bitrate: 128,
    ),
    const Reciter(
      id: 'ar.abdulbasitmurattal',
      nameArabic: 'عبد الباسط عبد الصمد',
      nameEnglish: 'Abdul Basit Murattal',
      style: 'Murattal',
      bitrate: 192,
    ),
    const Reciter(
      id: 'ar.sudalsshais',
      nameArabic: 'عبدالرحمن السدیس',
      nameEnglish: 'Abdurrahmaan As-Sudais',
      style: 'Murattal',
      bitrate: 192,
    ),
    const Reciter(
      id: 'ar.shaatree',
      nameArabic: 'أبو بكر الشاطری',
      nameEnglish: 'Abu Bakr Ash-Shaatree',
      style: 'Murattal',
      bitrate: 128,
    ),
  ];
}

// ══════════════════════════════════════════
// تایمینگی هایلایت — api.quran.com
// ══════════════════════════════════════════

class WordTiming {
  final int position;
  final int startMs;
  final int endMs;
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
  final int surahId;
  final int numberInSurah;
  final List<WordTiming> words;

  const AyahTiming({
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
      surahId: j['surah_id'] as int? ?? 0,
      numberInSurah: j['ayah_number'] as int? ?? 0,
      words: wordList,
    );
  }
}

// ══════════════════════════════════════════
// دۆخی خوێندنەوە و دەنگ
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
  final int? highlightedWordIndex;
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
  bool get isActive => status != AudioPlaybackState.idle;

  AudioState copyWith({
    AudioPlaybackState? status,
    int? currentSurahId,
    int? currentAyahNumber,
    int? highlightedWordIndex,
    bool clearHighlight = false,
    Duration? position,
    Duration? duration,
    Reciter? reciter,
    String? errorMessage,
  }) =>
      AudioState(
        status: status ?? this.status,
        currentSurahId: currentSurahId ?? this.currentSurahId,
        currentAyahNumber: currentAyahNumber ?? this.currentAyahNumber,
        highlightedWordIndex: clearHighlight
            ? null
            : (highlightedWordIndex ?? this.highlightedWordIndex),
        position: position ?? this.position,
        duration: duration ?? this.duration,
        reciter: reciter ?? this.reciter,
        errorMessage: errorMessage ?? this.errorMessage,
      );
}
