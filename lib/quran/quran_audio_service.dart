// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// quran_audio_service.dart
//
// بەڕێوەبردنی دەنگ + هایلایتی وشە بۆ قورئانی پیرۆز
//
// تایبەتمەندیەکان:
//   ✓ لیدانی ئۆنلاین (streaming) لە cdn.islamic.network
//   ✓ دابەزاندن و لیدانی ئۆفلاین
//   ✓ هایلایتی وشە بە تایمینگی api.quran.com
//   ✓ بەردەوامبوونی ئۆتۆماتیکی بۆ ئایەتی داهاتوو
//   ✓ کنترۆلی play/pause/stop/next/prev
//
// پاکێجەکان:
//   just_audio: ^0.9.37
//   http: ^1.2.1
//   path_provider: ^2.1.2
//   path: ^1.9.0
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'quran_models.dart';

// ──────────────────────────────────────────
// ثابتەکان
// ──────────────────────────────────────────

const String _kTimingBaseUrl = 'https://api.quran.com/api/v4';
const String _kAudioCacheFolder = 'quran_audio_cache';

// نەقشەی ئایدی ڕیسایتەشن لە api.quran.com بۆ هەر قاریئێک
const Map<String, int> _kReciterTimingIds = {
  'ar.alafasy': 7,
  'ar.abdurrahmaansudais': 2,
  'ar.husary': 5,
  'ar.mahermuaiqly': 9,
  'ar.minshawi': 3,
  'ar.shaatree': 1,
};

// ──────────────────────────────────────────
// سێرڤیسی دەنگ
// ──────────────────────────────────────────

class QuranAudioService {
  static final QuranAudioService _instance = QuranAudioService._internal();
  factory QuranAudioService() => _instance;
  QuranAudioService._internal();

  // ── پلەیەر
  final AudioPlayer _player = AudioPlayer();

  // ── دۆخ
  final _stateController = StreamController<AudioState>.broadcast();
  AudioState _state = const AudioState();

  // ── تایمینگی هایلایت
  List<AyahTiming> _timings = [];
  Timer? _highlightTimer;
  int _timingReciterId = 7; // بازمانی: العفاسی

  // ── داتای ئێستا
  Reciter _currentReciter = Reciter.defaults.first;
  int _currentSurahId = 1;
  int _currentAyahNumber = 1;
  int _totalAyahs = 7; // بۆ بەردەوامبوونی ئۆتۆماتیک

  // ── ستریمی گوێگرتن
  Stream<AudioState> get stateStream => _stateController.stream;
  AudioState get currentState => _state;

  // ════════════════════════════════════════
  // دەستپێکردن
  // ════════════════════════════════════════

  Future<void> init() async {
    // گوێگرتن لە تەواوبوونی ئایەت → بچۆ بۆ داهاتوو
    _player.playerStateStream.listen((playerState) {
      if (playerState.processingState == ProcessingState.completed) {
        _onAyahCompleted();
      }
    });

    // نوێکردنەوەی position بۆ هایلایت
    _player.positionStream.listen((pos) {
      _updateHighlight(pos.inMilliseconds);
      _emit(_state.copyWith(position: pos));
    });

    _player.durationStream.listen((dur) {
      if (dur != null) _emit(_state.copyWith(duration: dur));
    });
  }

  // ════════════════════════════════════════
  // دانانی قاریئ
  // ════════════════════════════════════════

  void setReciter(Reciter reciter) {
    _currentReciter = reciter;
    _timingReciterId = _kReciterTimingIds[reciter.id] ?? 7;
    _emit(_state.copyWith(reciter: reciter));
  }

  // ════════════════════════════════════════
  // لیدان — ئۆنلاین
  // ════════════════════════════════════════

  /// لیدانی ئایەتێک بە ئۆنلاین streaming
  Future<void> playOnline(int surahId, int ayahNumber,
      {int totalAyahs = 7}) async {
    _currentSurahId = surahId;
    _currentAyahNumber = ayahNumber;
    _totalAyahs = totalAyahs;

    _emit(_state.copyWith(
      status: AudioPlaybackState.loading,
      currentSurahId: surahId,
      currentAyahNumber: ayahNumber,
      highlightedWordIndex: null,
    ));

    try {
      final url = _currentReciter.onlineAudioUrl(surahId, ayahNumber);
      await _player.setAudioSource(AudioSource.uri(Uri.parse(url)));

      // فێچی تایمینگ بۆ هایلایت
      _fetchTimings(surahId, ayahNumber);

      await _player.play();
      _emit(_state.copyWith(status: AudioPlaybackState.playing));
    } catch (e) {
      _emit(_state.copyWith(
        status: AudioPlaybackState.error,
        errorMessage: 'کێشەی لیدان: $e',
      ));
    }
  }

  // ════════════════════════════════════════
  // لیدان — ئۆفلاین
  // ════════════════════════════════════════

  /// ئایا فایلی MP3 پێش دابەزراوە
  Future<bool> isDownloaded(int surahId, int ayahNumber) async {
    final path = await _ayahFilePath(surahId, ayahNumber);
    return File(path).exists();
  }

  /// دابەزاندنی یەک ئایەت
  Future<void> downloadAyah(int surahId, int ayahNumber) async {
    final url = _currentReciter.onlineAudioUrl(surahId, ayahNumber);
    final path = await _ayahFilePath(surahId, ayahNumber);
    final file = File(path);
    if (await file.exists()) return;

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        await file.parent.create(recursive: true);
        await file.writeAsBytes(response.bodyBytes);
      }
    } catch (_) {}
  }

  /// لیدانی ئۆفلاین — ئەگەر نەبوو ئۆنلاین دەکات
  Future<void> playOfflineOrOnline(int surahId, int ayahNumber,
      {int totalAyahs = 7}) async {
    _currentSurahId = surahId;
    _currentAyahNumber = ayahNumber;
    _totalAyahs = totalAyahs;

    _emit(_state.copyWith(
      status: AudioPlaybackState.loading,
      currentSurahId: surahId,
      currentAyahNumber: ayahNumber,
    ));

    try {
      final filePath = await _ayahFilePath(surahId, ayahNumber);
      final file = File(filePath);

      AudioSource source;
      if (await file.exists()) {
        source = AudioSource.file(filePath);
      } else {
        final url = _currentReciter.onlineAudioUrl(surahId, ayahNumber);
        source = AudioSource.uri(Uri.parse(url));
      }

      await _player.setAudioSource(source);
      _fetchTimings(surahId, ayahNumber);
      await _player.play();
      _emit(_state.copyWith(status: AudioPlaybackState.playing));
    } catch (e) {
      _emit(_state.copyWith(
        status: AudioPlaybackState.error,
        errorMessage: 'کێشەی لیدان: $e',
      ));
    }
  }

  // ════════════════════════════════════════
  // کنترۆلەکان
  // ════════════════════════════════════════

  Future<void> pause() async {
    await _player.pause();
    _emit(_state.copyWith(status: AudioPlaybackState.paused));
  }

  Future<void> resume() async {
    await _player.play();
    _emit(_state.copyWith(status: AudioPlaybackState.playing));
  }

  Future<void> stop() async {
    _highlightTimer?.cancel();
    await _player.stop();
    _timings = [];
    _emit(const AudioState());
  }

  Future<void> togglePlayPause() async {
    if (_state.isPlaying) {
      await pause();
    } else if (_state.status == AudioPlaybackState.paused) {
      await resume();
    }
  }

  /// بڕۆ بۆ ئایەتی داهاتوو
  Future<void> nextAyah() async {
    if (_currentAyahNumber < _totalAyahs) {
      await playOfflineOrOnline(
        _currentSurahId,
        _currentAyahNumber + 1,
        totalAyahs: _totalAyahs,
      );
    }
  }

  /// بڕۆ بۆ ئایەتی پێشوو
  Future<void> prevAyah() async {
    if (_currentAyahNumber > 1) {
      await playOfflineOrOnline(
        _currentSurahId,
        _currentAyahNumber - 1,
        totalAyahs: _totalAyahs,
      );
    }
  }

  // ════════════════════════════════════════
  // تایمینگی هایلایت
  // api.quran.com/api/v4/recitations/{id}/by_ayah/{surah}:{ayah}
  // ════════════════════════════════════════

  Future<void> _fetchTimings(int surahId, int ayahNumber) async {
    _timings = [];
    _highlightTimer?.cancel();

    try {
      final ayahKey = '$surahId:$ayahNumber';
      final url =
          '$_kTimingBaseUrl/recitations/$_timingReciterId/by_ayah/$ayahKey?words=true';

      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final ayahData = json['audio_files']?[0];
        if (ayahData != null) {
          _timings = [AyahTiming.fromJson(ayahData)];
        }
      }
    } catch (_) {
      // تایمینگ نەبوو — هایلایت نادرێت
    }
  }

  /// نوێکردنەوەی هایلایت بەپێی position ی ئێستا
  void _updateHighlight(int posMs) {
    if (_timings.isEmpty) return;

    final timing = _timings.first;
    for (int i = 0; i < timing.words.length; i++) {
      final word = timing.words[i];
      final isLast = i == timing.words.length - 1;
      final nextStart = isLast ? timing.endMs : timing.words[i + 1].startMs;

      if (posMs >= word.startMs && posMs < nextStart) {
        if (_state.highlightedWordIndex != i) {
          _emit(_state.copyWith(highlightedWordIndex: i));
        }
        return;
      }
    }
  }

  // ════════════════════════════════════════
  // بەردەوامبوونی ئۆتۆماتیک
  // ════════════════════════════════════════

  void _onAyahCompleted() {
    if (_currentAyahNumber < _totalAyahs) {
      Future.delayed(const Duration(milliseconds: 300), () {
        playOfflineOrOnline(
          _currentSurahId,
          _currentAyahNumber + 1,
          totalAyahs: _totalAyahs,
        );
      });
    } else {
      _emit(_state.copyWith(status: AudioPlaybackState.idle));
    }
  }

  // ════════════════════════════════════════
  // یارمەتیدەرەکان
  // ════════════════════════════════════════

  Future<String> _ayahFilePath(int surahId, int ayahNumber) async {
    final dir = await getApplicationDocumentsDirectory();
    final fileName = _currentReciter.offlineFileName(surahId, ayahNumber);
    return p.join(dir.path, _kAudioCacheFolder, _currentReciter.id, fileName);
  }

  void _emit(AudioState state) {
    _state = state;
    _stateController.add(state);
  }

  // ════════════════════════════════════════
  // داخستن
  // ════════════════════════════════════════

  Future<void> dispose() async {
    _highlightTimer?.cancel();
    await _stateController.close();
    await _player.dispose();
  }
}
