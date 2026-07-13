import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
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
  int _pendingNextSurah = 0;
  int _pendingNextAyah = 0;
  int _highlightedWordIndex = 0;
  int _playingPage = 0; // ← زیاد بکە
  int get playingPage => _playingPage; // ← زیاد بکە
  void setPlayingPage(int page) => _playingPage = page; // ← زیاد بکە
  bool _completionHandled = false;

  String _currentReciterId = '959';
  String _currentReciterFileName =
      'ayah-recitation-muhammad-siddiq-al-minshawi-murattal-hafs-959.json';

  Timer? _segmentTimer;
  StreamSubscription? _playerStateSubscription;
  AyahRecitation? _currentRecitation;

  // ─── Download State ───────────────────────────────────────────────────────

  final Map<String, double> _downloadProgress = {};
  final Map<String, double> _pausedProgress = {};
  final Set<String> _downloadedReciters = {};
  final Set<String> _pausedReciters = {};
  bool _stopFlag = false;

  // ─── Getters ──────────────────────────────────────────────────────────────

  AudioState get state => _state;
  AudioMode get mode => _mode;
  int get currentSurah => _currentSurah;
  int get currentAyah => _currentAyah;
  int get highlightedWordIndex => _highlightedWordIndex;
  String get currentReciterId => _currentReciterId;
  bool get isPlaying => _state == AudioState.playing;
  bool get isPaused => _state == AudioState.paused;
  bool get hasHighlightedAyah => _currentSurah > 0 && _currentAyah > 0;
  Map<String, double> get downloadProgress => _downloadProgress;
  Set<String> get downloadedReciters => _downloadedReciters;
  Set<String> get pausedReciters => _pausedReciters;
  Map<String, double> get pausedProgress => _pausedProgress;

  // ─── Init ─────────────────────────────────────────────────────────────────

  Future<void> init() async {
    await _db.loadBuiltInRecitation(_currentReciterFileName);
    await _checkDownloadedReciters();
    await _resumePendingDownloads();
    await _setupAudioSession();
    _setupPlayerStateListener();
  }

  Future<void> _setupAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    session.interruptionEventStream.listen((event) {
      if (event.begin && _state == AudioState.playing) pause();
    });
  }

  void _setupPlayerStateListener() {
    _playerStateSubscription?.cancel();
    _playerStateSubscription = _player.playerStateStream.listen((playerState) {
      if (playerState.processingState == ProcessingState.completed) {
        if (!_completionHandled) {
          _completionHandled = true;
          _onAyahCompleted();
        }
      }
    });
  }

  void setCurrentAyah(int surah, int ayah) {
    _currentSurah = surah;
    _currentAyah = ayah;
  }

  // ─── Download Management ──────────────────────────────────────────────────

  Future<void> _checkDownloadedReciters() async {
    final dir = await _getReciterDir();
    for (final reciter in kAllReciters) {
      final id = reciter['id']!;
      if (await File('${dir.path}/$id/.done').exists()) {
        _downloadedReciters.add(id);
      }
    }
  }

  Future<void> _resumePendingDownloads() async {
    final prefs = await SharedPreferences.getInstance();
    for (final reciter in kAllReciters) {
      final id = reciter['id']!;
      if (_downloadedReciters.contains(id)) continue;
      final saved = prefs.getInt('dl_done_$id') ?? 0;
      if (saved > 0) {
        final jsonStr =
            await rootBundle.loadString('assets/quran/${reciter['file']}');
        final total = (jsonDecode(jsonStr) as Map).length;
        _pausedProgress[id] = saved / total;
        _pausedReciters.add(id);
      }
    }
    notifyListeners();
  }

  Future<Directory> _getReciterDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/quran_audio');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<void> downloadReciter(String reciterId) async {
    if (_downloadProgress.containsKey(reciterId)) return;
    if (_downloadedReciters.contains(reciterId)) return;

    final reciterData =
        kAllReciters.firstWhere((r) => r['id'] == reciterId, orElse: () => {});
    if (reciterData.isEmpty) return;

    final slug = reciterData['slug']!;
    final jsonStr =
        await rootBundle.loadString('assets/quran/${reciterData['file']}');
    final Map<String, dynamic> data = jsonDecode(jsonStr);
    final total = data.length;

    final prefs = await SharedPreferences.getInstance();
    int done = prefs.getInt('dl_done_$reciterId') ?? 0;

    _stopFlag = false;
    _downloadProgress[reciterId] = done / total;
    notifyListeners();

    try {
      final dir = await _getReciterDir();
      final mp3Dir = Directory('${dir.path}/$reciterId');
      if (!await mp3Dir.exists()) await mp3Dir.create(recursive: true);

      int idx = 0;
      for (final entry in data.entries) {
        idx++;
        if (idx <= done) continue;

        if (_stopFlag) {
          await prefs.setInt('dl_done_$reciterId', done);
          _downloadProgress.remove(reciterId);
          notifyListeners();
          return;
        }

        final ayahData = entry.value as Map<String, dynamic>;
        final surah = ayahData['surah_number'] as int;
        final ayah = ayahData['ayah_number'] as int;
        final fname =
            '${surah.toString().padLeft(3, '0')}${ayah.toString().padLeft(3, '0')}.mp3';
        final local = File('${mp3Dir.path}/$fname');

        if (!await local.exists()) {
          final url = 'https://everyayah.com/data/$slug/$fname';
          final res = await http.get(Uri.parse(url));
          if (res.statusCode == 200) await local.writeAsBytes(res.bodyBytes);
        }

        done++;
        _downloadProgress[reciterId] = done / total;
        await prefs.setInt('dl_done_$reciterId', done);
        if (done % 20 == 0) notifyListeners();
      }

      await File('${mp3Dir.path}/.done').writeAsString('ok');
      await prefs.remove('dl_done_$reciterId');
      _downloadedReciters.add(reciterId);
      _downloadProgress.remove(reciterId);
      notifyListeners();
    } catch (e) {
      await prefs.setInt('dl_done_$reciterId', done);
      _downloadProgress.remove(reciterId);
      notifyListeners();
      debugPrint('Download error: $e');
    }
  }

  void pauseDownload(String reciterId) {
    if (!_downloadProgress.containsKey(reciterId)) return;
    _stopFlag = true;
    _pausedProgress[reciterId] = _downloadProgress[reciterId]!;
    _pausedReciters.add(reciterId);
    _downloadProgress.remove(reciterId);
    notifyListeners();
  }

  Future<void> resumeDownload(String reciterId) async {
    if (!_pausedReciters.contains(reciterId)) return;
    _pausedReciters.remove(reciterId);
    _pausedProgress.remove(reciterId);
    await downloadReciter(reciterId);
  }

  Future<void> cancelDownload(String reciterId) async {
    _stopFlag = true;
    _downloadProgress.remove(reciterId);
    _pausedProgress.remove(reciterId);
    _pausedReciters.remove(reciterId);
    final dir = await _getReciterDir();
    final mp3Dir = Directory('${dir.path}/$reciterId');
    if (await mp3Dir.exists()) await mp3Dir.delete(recursive: true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('dl_done_$reciterId');
    notifyListeners();
  }

  Future<void> deleteDownloadedReciter(String reciterId) async {
    final dir = await _getReciterDir();
    final mp3Dir = Directory('${dir.path}/$reciterId');
    if (await mp3Dir.exists()) await mp3Dir.delete(recursive: true);
    _downloadedReciters.remove(reciterId);
    _pausedReciters.remove(reciterId);
    _pausedProgress.remove(reciterId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('dl_done_$reciterId');
    notifyListeners();
  }

  // ─── Reciter Switching ────────────────────────────────────────────────────

  Future<void> switchReciter(String reciterId, String fileName) async {
    if (_currentReciterId == reciterId) return;

    final wasPlaying = _state == AudioState.playing;
    final wasPaused = _state == AudioState.paused;
    final wasLoading = _state == AudioState.loading;
    final resumeSurah = _currentSurah;
    final resumeAyah = _currentAyah;

    _segmentTimer?.cancel();
    _completionHandled = true;
    await _player.stop();
    _highlightedWordIndex = 0;

    _currentReciterId = reciterId;
    _currentReciterFileName = fileName;

    final dir = await _getReciterDir();
    final localPath = '${dir.path}/$fileName';

    if (await File(localPath).exists()) {
      await _db.loadDownloadedRecitation(localPath, reciterId);
      _mode = AudioMode.offline;
    } else {
      await _db.loadBuiltInRecitation(fileName);
      _mode = AudioMode.online;
    }

    if ((wasPlaying || wasLoading) && resumeSurah > 0 && resumeAyah > 0) {
      await playAyah(resumeSurah, resumeAyah);
    } else if (wasPaused && resumeSurah > 0 && resumeAyah > 0) {
      _currentSurah = resumeSurah;
      _currentAyah = resumeAyah;
      _state = AudioState.paused;
      notifyListeners();
    } else {
      _state = AudioState.stopped;
      _currentSurah = 0;
      _currentAyah = 0;
      notifyListeners();
    }
  }

  // ─── Playback ─────────────────────────────────────────────────────────────

  Future<void> playAyah(int surah, int ayah) async {
    _segmentTimer?.cancel();
    _completionHandled = false;
    _pendingNextSurah = 0;
    _pendingNextAyah = 0;
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
      final fname =
          '${surah.toString().padLeft(3, '0')}${ayah.toString().padLeft(3, '0')}.mp3';
      final dir = await _getReciterDir();
      final localFile = File('${dir.path}/$_currentReciterId/$fname');

      if (await localFile.exists()) {
        await _player.setFilePath(localFile.path);
      } else {
        final slug = _getReciterSlug(_currentReciterId);
        await _player.setUrl('https://everyayah.com/data/$slug/$fname');
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

  /// بسمەڵە دەخوێنێت بەبێ گۆڕینی currentSurah/currentAyah
  Future<void> _playBasmallahOnly(int pendingSurah, int pendingAyah) async {
    _segmentTimer?.cancel();
    _completionHandled = false;
    _pendingNextSurah = pendingSurah;
    _pendingNextAyah = pendingAyah;
    _currentSurah = pendingSurah; // ← زیاد بکە
    _currentAyah = 0;
    _highlightedWordIndex = 0;
    _state = AudioState.loading;
    notifyListeners();

    try {
      final fname = '${pendingSurah.toString().padLeft(3, '0')}000.mp3';
      final dir = await _getReciterDir();
      final localFile = File('${dir.path}/$_currentReciterId/$fname');

      if (await localFile.exists()) {
        await _player.setFilePath(localFile.path);
      } else {
        final slug = _getReciterSlug(_currentReciterId);
        await _player.setUrl('https://everyayah.com/data/$slug/$fname');
      }

      await _player.play();
      _state = AudioState.playing;
      notifyListeners();
    } catch (e) {
      debugPrint('Basmallah play error: $e');
      _pendingNextSurah = 0;
      _pendingNextAyah = 0;
      await playAyah(pendingSurah, pendingAyah);
    }
  }

  Future<void> playFromSurahStart(int surahNumber) async {
    if (surahNumber != 1 && surahNumber != 9) {
      await _playBasmallahOnly(surahNumber, 1);
    } else {
      await playAyah(surahNumber, 1);
    }
  }

  Future<void> playNextAyah() async {
    if (_currentSurah == 0) return;
    await _playNextAyah();
  }

  Future<void> playPreviousAyah() async {
    if (_currentSurah == 0) return;
    int prevSurah = _currentSurah;
    int prevAyah = _currentAyah - 1;
    if (prevAyah < 1) {
      prevSurah--;
      if (prevSurah < 1) return;
      final surahInfo = await _db.getSurahInfo(prevSurah);
      if (surahInfo == null) return;
      prevAyah = surahInfo.versesCount;
    }
    await playAyah(prevSurah, prevAyah);
  }

  Future<void> pause() async {
    if (_state == AudioState.playing || _state == AudioState.loading) {
      _segmentTimer?.cancel();
      _completionHandled = true;
      await _player.pause();
      _state = AudioState.paused;
      notifyListeners();
    }
  }

  Future<void> resume() async {
    if (_state == AudioState.paused) {
      _completionHandled = false;
      await _player.play();
      _state = AudioState.playing;
      _startSegmentTracking();
      notifyListeners();
    }
  }

  Future<void> stop() async {
    _segmentTimer?.cancel();
    _completionHandled = true;
    await _player.stop();
    _state = AudioState.stopped;
    _highlightedWordIndex = 0;
    notifyListeners();
  }

  Future<void> togglePlayPause(int surah, int ayah) async {
    final isCurrentAndActive = _currentSurah == surah && _currentAyah == ayah;
    if (isCurrentAndActive &&
        (_state == AudioState.playing || _state == AudioState.loading)) {
      await pause();
    } else if (isCurrentAndActive && _state == AudioState.paused) {
      await resume();
    } else {
      if (_needsBasmallah(surah, ayah)) {
        await _playBasmallahOnly(surah, ayah);
      } else {
        await playAyah(surah, ayah);
      }
    }
  }

  /// ئایەتەکە گۆڕبێت بەبێ دەستپێکردنی دەنگ (بۆ کاتی paused)
  void moveToAyah(int surah, int ayah) {
    _currentSurah = surah;
    _currentAyah = ayah;
    _highlightedWordIndex = 0;
    notifyListeners();
  }

  // ─── State Checks ─────────────────────────────────────────────────────────

  bool isCurrentAyah(int surah, int ayah) =>
      _currentSurah == surah && _currentAyah == ayah;

  bool isWordHighlighted(int surah, int ayah, int wordIndex) =>
      isCurrentAyah(surah, ayah) &&
      _state == AudioState.playing &&
      _highlightedWordIndex == wordIndex;

  // ─── Private Helpers ──────────────────────────────────────────────────────

  String _getReciterSlug(String reciterId) {
    final data = kAllReciters.firstWhere(
      (r) => r['id'] == reciterId,
      orElse: () => {},
    );
    return data['slug'] ?? '';
  }

  bool _needsBasmallah(int surah, int ayah) =>
      ayah == 1 && surah != 9 && surah != 1;

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
    if (_pendingNextSurah > 0) {
      final s = _pendingNextSurah;
      final a = _pendingNextAyah;
      _pendingNextSurah = 0;
      _pendingNextAyah = 0;
      playAyah(s, a);
    } else {
      _playNextAyah();
    }
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

    if (_needsBasmallah(nextSurah, nextAyah)) {
      await _playBasmallahOnly(nextSurah, nextAyah);
    } else {
      await playAyah(nextSurah, nextAyah);
    }
  }

  // ─── Dispose ──────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _segmentTimer?.cancel();
    _playerStateSubscription?.cancel();
    _player.dispose();
    super.dispose();
  }
}
