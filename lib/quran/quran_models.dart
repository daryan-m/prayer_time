// ============================================================
//  quran_models.dart
//  تەنها مۆدێلەکانی داتا — هیچ لۆجیک تێدا نییە
// ============================================================

// ─────────────────────────────────────────────────────────
//  Surah
// ─────────────────────────────────────────────────────────

class Surah {
  final int id;
  final String nameArabic;
  final String nameSimple;
  final String nameKurdish;
  final int versesCount;
  final String revelationPlace; // 'makkah' | 'madinah'
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

  bool get isMakki => revelationPlace == 'makkah';
  String get displayName => nameKurdish.isNotEmpty ? nameKurdish : nameArabic;
}

// ─────────────────────────────────────────────────────────
//  Reciter
// ─────────────────────────────────────────────────────────

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
    this.bitrate = 128,
  });

  static const List<Reciter> defaults = [
    Reciter(
      id: 'ar.alafasy',
      nameArabic: 'مشاری راشد العفاسی',
      nameEnglish: 'Mishary Alafasy',
      style: 'Murattal',
    ),
    Reciter(
      id: 'ar.abdulbasitmurattal',
      nameArabic: 'عبد الباسط عبد الصمد',
      nameEnglish: 'Abdul Basit Murattal',
      style: 'Murattal',
    ),
    Reciter(
      id: 'ar.husary',
      nameArabic: 'محمود خلیل الحصری',
      nameEnglish: 'Mahmoud Khalil Al-Husary',
      style: 'Murattal',
    ),
    Reciter(
      id: 'ar.shaatree',
      nameArabic: 'أبو بكر الشاطری',
      nameEnglish: 'Abu Bakr Ash-Shaatree',
      style: 'Murattal',
    ),
    Reciter(
      id: 'ar.minshawi',
      nameArabic: 'محمد صدیق المنشاوی',
      nameEnglish: 'Mohamed Siddiq Al-Minshawi',
      style: 'Murattal',
    ),
  ];
}

// ─────────────────────────────────────────────────────────
//  QuranReadingState
// ─────────────────────────────────────────────────────────

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
}

// ─────────────────────────────────────────────────────────
//  AudioPlaybackState
// ─────────────────────────────────────────────────────────

enum AudioPlaybackState { idle, loading, playing, paused, error }

// ─────────────────────────────────────────────────────────
//  AudioState  —  immutable snapshot ی دۆخی پلەیەر
// ─────────────────────────────────────────────────────────

class AudioState {
  final AudioPlaybackState status;
  final int? currentSurahId;
  final int? currentAyahNumber;
  final int? highlightedWordIndex; // 0-based
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
  bool get isPaused => status == AudioPlaybackState.paused;
  bool get isActive => status != AudioPlaybackState.idle;
  bool get hasError => status == AudioPlaybackState.error;

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
