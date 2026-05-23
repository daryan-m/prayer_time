import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'quran_models.dart';
import 'quran_database_helper.dart';

enum AudioMode { online, offline }

enum AudioState { idle, loading, playing, paused, stopped, error }

class QuranAudioService extends ChangeNotifier {
  static final QuranAudioService _instance = QuranAudioService._internal();
  factory QuranAudioService() => _instance;
  QuranAudioService._internal();

  final AudioPlayer _player = AudioPlayer();
  final QuranDatabaseHelper _db = QuranDatabaseHelper();

  AudioState _state = AudioState.idle;
  AudioMode _mode = AudioMode.online;

  int _currentSurah = 0;
  int _currentAyah = 0;
  int _highlightedWordIndex = 0; // 1-based word index
  String _currentReciterId = '953';
  String _currentReciterFileName =
      'ayah-recitation-mishari-rashid-al-afasy-murattal-hafs-953.json';

  Timer? _segmentTimer;
  AyahRecitation? _currentRecitation;

  // Download progress
  final Map<String, double> _downloadProgress = {};
  final Set<String> _downloadedReciters = {};

  // ─── Getters ───────────────────────────────────────────────────────────────

  AudioState get state => _state;
  AudioMode get mode => _mode;
  int get currentSurah => _currentSurah;
  int get currentAyah => _currentAyah;
  int get highlightedWordIndex => _highlightedWordIndex;
  String get currentReciterId => _currentReciterId;
  bool get isPlaying => _state == AudioState.playing;
  bool get isPaused => _state == AudioState.paused;
  Map<String, double> get downloadProgress => _downloadProgress;
  Set<String> get downloadedReciters => _downloadedReciters;

  // ─── Init ──────────────────────────────────────────────────────────────────

  Future<void> init() async {
    // Load built-in reciter (Afasy)
    await _db.loadBuiltInRecitation(_currentReciterFileName);
    await _checkDownloadedReciters();

    _player.playerStateStream.listen((playerState) {
      if (playerState.processingState == ProcessingState.completed) {
        _onAyahCompleted();
      }
    });
  }

  Future<void> _checkDownloadedReciters() async {
    final dir = await _getReciterDir();
    for (final reciter in kAllReciters) {
      final file = File('${dir.path}/${reciter['file']}');
      if (await file.exists()) {
        _downloadedReciters.add(reciter['id']!);
      }
    }
  }

  Future<Directory> _getReciterDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/quran_audio');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  // ─── Reciter Management ────────────────────────────────────────────────────

  Future<void> switchReciter(String reciterId, String fileName) async {
    if (_currentReciterId == reciterId) return;

    // ئایەتی ئێستا پاشکەوت بکە پێش وەستاندن
    final wasPlaying =
        _state == AudioState.playing || _state == AudioState.paused;
    final resumeSurah = _currentSurah;
    final resumeAyah = _currentAyah;

    await stop();
    _currentReciterId = reciterId;
    _currentReciterFileName = fileName;

    if (reciterId == '953') {
      await _db.loadBuiltInRecitation(fileName);
    } else {
      final dir = await _getReciterDir();
      final path = '${dir.path}/$fileName';
      if (await File(path).exists()) {
        await _db.loadDownloadedRecitation(path, reciterId);
        _mode = AudioMode.offline;
      } else {
        _mode = AudioMode.online;
      }
    }
    notifyListeners();

    // ئەگەر دەنگ لە کارکردندا بوو، هەمان ئایەتە بخوێنەوە
    if (wasPlaying && resumeSurah > 0 && resumeAyah > 0) {
      await playAyah(resumeSurah, resumeAyah);
    }
  }

  Future<void> downloadReciter(String reciterId) async {
    if (_downloadProgress.containsKey(reciterId)) return;
    if (_downloadedReciters.contains(reciterId)) return;

    final reciterData = kAllReciters.firstWhere(
      (r) => r['id'] == reciterId,
      orElse: () => {},
    );
    if (reciterData.isEmpty) return;

    final slug = reciterData['slug']!;
    final jsonStr =
        await rootBundle.loadString('assets/quran/${reciterData['file']}');
    final Map<String, dynamic> data = jsonDecode(jsonStr);
    final total = data.length;
    int done = 0;

    _downloadProgress[reciterId] = 0.0;
    notifyListeners();

    try {
      final dir = await _getReciterDir();
      final mp3Dir = Directory('${dir.path}/$reciterId');
      if (!await mp3Dir.exists()) await mp3Dir.create(recursive: true);

      for (final entry in data.entries) {
        final ayahData = entry.value as Map<String, dynamic>;
        final surah = ayahData['surah_number'] as int;
        final ayah = ayahData['ayah_number'] as int;
        final fname =
            '${surah.toString().padLeft(3, '0')}${ayah.toString().padLeft(3, '0')}.mp3';
        final local = File('${mp3Dir.path}/$fname');

        if (!await local.exists()) {
          final url = 'https://audio-cdn.tarteel.ai/quran/$slug/$fname';
          final res = await http.get(Uri.parse(url));
          if (res.statusCode == 200) {
            await local.writeAsBytes(res.bodyBytes);
          }
        }
        done++;
        _downloadProgress[reciterId] = done / total;
        if (done % 20 == 0) notifyListeners();
      }

      // marker
      await File('${mp3Dir.path}/.done').writeAsString('ok');
      _downloadedReciters.add(reciterId);
      _downloadProgress.remove(reciterId);
      notifyListeners();
    } catch (e) {
      _downloadProgress.remove(reciterId);
      notifyListeners();
      debugPrint('Download failed: $e');
    }
  }

  Future<void> deleteDownloadedReciter(String reciterId) async {
    final dir = await _getReciterDir();
    final mp3Dir = Directory('${dir.path}/$reciterId');
    if (await mp3Dir.exists()) await mp3Dir.delete(recursive: true);
    _downloadedReciters.remove(reciterId);
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
      final audioUrl = _currentRecitation!.audioUrl;

      // ئۆفلاین چێک — لە فۆڵدەری نوێ
      final fname =
          '${surah.toString().padLeft(3, '0')}${ayah.toString().padLeft(3, '0')}.mp3';
      final dir = await _getReciterDir();
      final localFile = File('${dir.path}/$_currentReciterId/$fname');

      if (await localFile.exists()) {
        await _player.setFilePath(localFile.path);
      } else {
        await _player.setUrl(audioUrl);
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
      // Find current segment
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
    // هەمیشە بەردەوام بێت — نەوەستێت
    _playNextAyah();
  }

  Future<void> _playNextAyah() async {
    // Get total ayahs for current surah
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
