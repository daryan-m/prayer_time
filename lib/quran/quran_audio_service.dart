import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'quran_models.dart';
import 'quran_database_helper.dart';

enum AudioState { idle, loading, playing, paused, stopped, error }

class QuranAudioService extends ChangeNotifier {
  static final QuranAudioService _instance = QuranAudioService._internal();
  factory QuranAudioService() => _instance;
  QuranAudioService._internal();

  final AudioPlayer _player = AudioPlayer();
  final QuranDatabaseHelper _db = QuranDatabaseHelper();

  AudioState _state = AudioState.idle;
  int _currentSurah = 0;
  int _currentAyah = 0;
  int _highlightedWordIndex = 0;
  String _currentReciterId = '953';

  Timer? _segmentTimer;
  AyahRecitation? _currentRecitation;

  // ─── Getters ───────────────────────────────────────────────────────────────

  AudioState get state => _state;
  int get currentSurah => _currentSurah;
  int get currentAyah => _currentAyah;
  int get highlightedWordIndex => _highlightedWordIndex;
  String get currentReciterId => _currentReciterId;
  bool get isPlaying => _state == AudioState.playing;
  bool get isPaused => _state == AudioState.paused;

  // ─── Prefs ─────────────────────────────────────────────────────────────────

  Future<File> _getPrefsFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/quran_prefs.json');
  }

  Future<void> _saveSelectedReciter(String id) async {
    try {
      final f = await _getPrefsFile();
      await f.writeAsString(jsonEncode({'reciter_id': id}));
    } catch (_) {}
  }

  Future<String?> _loadSavedReciterId() async {
    try {
      final f = await _getPrefsFile();
      if (!await f.exists()) return null;
      final map = jsonDecode(await f.readAsString()) as Map;
      return map['reciter_id'] as String?;
    } catch (_) {
      return null;
    }
  }

  // ─── Init ──────────────────────────────────────────────────────────────────

  Future<void> init() async {
    final savedId = await _loadSavedReciterId();
    final id = (savedId != null && kAllReciters.any((r) => r['id'] == savedId))
        ? savedId
        : kAllReciters.first['id']!;

    await _loadReciter(id);

    _player.playerStateStream.listen((playerState) {
      if (playerState.processingState == ProcessingState.completed) {
        _onAyahCompleted();
      }
    });
  }

  // ─── Reciter loading ───────────────────────────────────────────────────────

  Future<void> _loadReciter(String reciterId) async {
    final reciter = kAllReciters.firstWhere(
      (r) => r['id'] == reciterId,
      orElse: () => kAllReciters.first,
    );
    _currentReciterId = reciter['id']!;
    await _db.loadBuiltInRecitation(reciter['file']!);
  }

  Future<void> switchReciter(String reciterId) async {
    if (_currentReciterId == reciterId) return;
    await stop();
    await _loadReciter(reciterId);
    await _saveSelectedReciter(reciterId);
    notifyListeners();
  }

  // ─── Playback ──────────────────────────────────────────────────────────────

  Future<void> playAyah(int surah, int ayah, {bool continuous = false}) async {
    _segmentTimer?.cancel();
    _currentSurah = surah;
    _currentAyah = ayah;
    _highlightedWordIndex = 0;
    _state = AudioState.loading;
    notifyListeners();

    _currentRecitation = _db.getAyahRecitation(surah, ayah);
    if (_currentRecitation == null) {
      _state = AudioState.error;
      notifyListeners();
      return;
    }

    try {
      // audio_url لە JSON دێت — ناو assets/quran/audio پاشکەوتکراوە
      final audioUrl = _currentRecitation!.audioUrl;

      // ئەگەر URL ی ئۆنلاینە (https) ڕاستەوخۆ لێی بدە
      // چونکە فایلەکان لە assets/quran/audio دابەزێنراون
      if (audioUrl.startsWith('https')) {
        await _player.setUrl(audioUrl);
      } else {
        await _player.setAsset(audioUrl);
      }

      await _player.play();
      _state = AudioState.playing;
      _startSegmentTracking();
      notifyListeners();
    } catch (e) {
      _state = AudioState.error;
      notifyListeners();
      debugPrint('Audio play error: $e');
    }
  }

  void _startSegmentTracking() {
    _segmentTimer?.cancel();
    final segments = _currentRecitation?.segments ?? [];
    if (segments.isEmpty) return;

    _segmentTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (_state != AudioState.playing) {
        timer.cancel();
        return;
      }
      final pos = _player.position.inMilliseconds;
      for (int i = segments.length - 1; i >= 0; i--) {
        if (pos >= segments[i].startMs) {
          if (_highlightedWordIndex != segments[i].wordIndex) {
            _highlightedWordIndex = segments[i].wordIndex;
            notifyListeners();
          }
          break;
        }
      }
    });
  }

  void _onAyahCompleted() {
    _segmentTimer?.cancel();
    _highlightedWordIndex = 0;
    _playNextAyah();
  }

  Future<void> _playNextAyah() async {
    final surahInfo = await _db.getSurahInfo(_currentSurah);
    if (surahInfo == null) {
      _state = AudioState.stopped;
      notifyListeners();
      return;
    }

    int nextSurah = _currentSurah;
    int nextAyah = _currentAyah + 1;

    if (nextAyah > surahInfo.versesCount) {
      nextSurah++;
      nextAyah = 1;
      if (nextSurah > 114) {
        _state = AudioState.stopped;
        notifyListeners();
        return;
      }
    }

    await playAyah(nextSurah, nextAyah, continuous: true);
  }

  Future<void> pause() async {
    if (_state == AudioState.playing) {
      _segmentTimer?.cancel();
      await _player.pause();
      _state = AudioState.paused;
      notifyListeners();
    }
  }

  Future<void> resume() async {
    if (_state == AudioState.paused) {
      await _player.play();
      _state = AudioState.playing;
      _startSegmentTracking();
      notifyListeners();
    }
  }

  Future<void> stop() async {
    _segmentTimer?.cancel();
    await _player.stop();
    _state = AudioState.stopped;
    _highlightedWordIndex = 0;
    notifyListeners();
  }

  Future<void> togglePlayPause(int surah, int ayah) async {
    if (_state == AudioState.playing &&
        _currentSurah == surah &&
        _currentAyah == ayah) {
      await pause();
    } else if (_state == AudioState.paused &&
        _currentSurah == surah &&
        _currentAyah == ayah) {
      await resume();
    } else {
      await playAyah(surah, ayah);
    }
  }

  bool isCurrentAyah(int surah, int ayah) {
    return _currentSurah == surah && _currentAyah == ayah;
  }

  bool isWordHighlighted(int surah, int ayah, int wordIndex) {
    return isCurrentAyah(surah, ayah) &&
        _state == AudioState.playing &&
        _highlightedWordIndex == wordIndex;
  }

  @override
  void dispose() {
    _segmentTimer?.cancel();
    _player.dispose();
    super.dispose();
  }
}
