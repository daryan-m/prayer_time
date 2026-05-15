import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'quran_models.dart';

const String _kTimingBaseUrl = 'https://api.quran.com/api/v4';
const String _kAudioCacheFolder = 'quran_audio';

// نەقشەی ئایدی تایمینگ بۆ هەر قاریئێک
const Map<String, int> _kTimingIds = {
  'ar.alafasy': 7,
  'ar.abdurrahmaansudais': 2,
  'ar.husary': 5,
  'ar.mahermuaiqly': 9,
  'ar.minshawi': 3,
  'ar.shaatree': 1,
};

class QuranAudioService {
  static final QuranAudioService _instance = QuranAudioService._internal();
  factory QuranAudioService() => _instance;
  QuranAudioService._internal();

  final AudioPlayer _player = AudioPlayer();
  final _stateCtrl = StreamController<AudioState>.broadcast();

  AudioState _state = const AudioState();
  Reciter _reciter = Reciter.defaults.first;
  int _surahId = 1;
  int _ayahNumber = 1;
  int _totalAyahs = 7;
  List<WordTiming> _wordTimings = [];

  Stream<AudioState> get stateStream => _stateCtrl.stream;
  AudioState get currentState => _state;

  // ════════════════════════════════════════
  // دەستپێکردن
  // ════════════════════════════════════════

  Future<void> init() async {
    _player.playerStateStream.listen((ps) {
      if (ps.processingState == ProcessingState.completed) {
        _onCompleted();
      }
    });

    _player.positionStream.listen((pos) {
      _updateWordHighlight(pos.inMilliseconds);
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
    _reciter = reciter;
    _emit(_state.copyWith(reciter: reciter));
  }

  // ════════════════════════════════════════
  // لیدان — ئۆنلاین یان ئۆفلاین
  // ════════════════════════════════════════

  Future<void> play(int surahId, int ayahNumber, {int totalAyahs = 7}) async {
    _surahId = surahId;
    _ayahNumber = ayahNumber;
    _totalAyahs = totalAyahs;
    _wordTimings = [];

    _emit(_state.copyWith(
      status: AudioPlaybackState.loading,
      currentSurahId: surahId,
      currentAyahNumber: ayahNumber,
      clearHighlight: true,
      reciter: _reciter,
    ));

    try {
      // ئۆفلاین ئەگەر هەبوو، ئینجا ئۆنلاین
      final filePath = await _localPath(surahId, ayahNumber);
      final file = File(filePath);

      final AudioSource source;
      if (await file.exists()) {
        source = AudioSource.file(filePath);
      } else {
        final url = _reciter.onlineAudioUrl(surahId, ayahNumber);
        source = AudioSource.uri(Uri.parse(url));
      }

      await _player.setAudioSource(source);
      await _player.play();

      _emit(_state.copyWith(status: AudioPlaybackState.playing));

      // فێچی تایمینگ بۆ هایلایت (لە پاشبزم)
      _fetchWordTimings(surahId, ayahNumber);
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
    _wordTimings = [];
    await _player.stop();
    _emit(const AudioState());
  }

  Future<void> togglePlayPause() async {
    if (_state.isPlaying) {
      await pause();
    } else if (_state.status == AudioPlaybackState.paused) {
      await resume();
    }
  }

  Future<void> nextAyah() async {
    if (_ayahNumber < _totalAyahs) {
      await play(_surahId, _ayahNumber + 1, totalAyahs: _totalAyahs);
    }
  }

  Future<void> prevAyah() async {
    if (_ayahNumber > 1) {
      await play(_surahId, _ayahNumber - 1, totalAyahs: _totalAyahs);
    }
  }

  // ════════════════════════════════════════
  // دابەزاندنی ئۆفلاین
  // ════════════════════════════════════════

  Future<bool> isDownloaded(int surahId, int ayahNumber) async {
    final path = await _localPath(surahId, ayahNumber);
    return File(path).exists();
  }

  Future<void> downloadAyah(int surahId, int ayahNumber) async {
    final path = await _localPath(surahId, ayahNumber);
    final file = File(path);
    if (await file.exists()) return;

    try {
      final url = _reciter.onlineAudioUrl(surahId, ayahNumber);
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        await file.parent.create(recursive: true);
        await file.writeAsBytes(response.bodyBytes);
      }
    } catch (_) {}
  }

  // ════════════════════════════════════════
  // تایمینگی هایلایت
  // api.quran.com/api/v4/recitations/{id}/by_ayah/{surah}:{ayah}
  // ════════════════════════════════════════

  Future<void> _fetchWordTimings(int surahId, int ayahNumber) async {
    try {
      final recitationId = _kTimingIds[_reciter.id] ?? 7;
      final url =
          '$_kTimingBaseUrl/recitations/$recitationId/by_ayah/$surahId:$ayahNumber?words=true';

      final resp =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));

      if (resp.statusCode == 200) {
        final json = jsonDecode(resp.body);
        final files = json['audio_files'] as List<dynamic>?;
        if (files != null && files.isNotEmpty) {
          final timing = AyahTiming.fromJson(files[0] as Map<String, dynamic>);
          _wordTimings = timing.words;
        }
      }
    } catch (_) {
      // تایمینگ نەبوو — هایلایت نادرێت
    }
  }

  void _updateWordHighlight(int posMs) {
    if (_wordTimings.isEmpty) return;
    for (int i = 0; i < _wordTimings.length; i++) {
      final w = _wordTimings[i];
      final nextStart = i < _wordTimings.length - 1
          ? _wordTimings[i + 1].startMs
          : w.endMs + 1000;
      if (posMs >= w.startMs && posMs < nextStart) {
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

  void _onCompleted() {
    if (_ayahNumber < _totalAyahs) {
      Future.delayed(const Duration(milliseconds: 400), () {
        play(_surahId, _ayahNumber + 1, totalAyahs: _totalAyahs);
      });
    } else {
      _emit(const AudioState());
    }
  }

  // ════════════════════════════════════════
  // یارمەتیدەر
  // ════════════════════════════════════════

  Future<String> _localPath(int surahId, int ayahNumber) async {
    final dir = await getApplicationDocumentsDirectory();
    final name = _reciter.offlineFileName(surahId, ayahNumber);
    return p.join(dir.path, _kAudioCacheFolder, _reciter.id, name);
  }

  void _emit(AudioState state) {
    _state = state;
    if (!_stateCtrl.isClosed) _stateCtrl.add(state);
  }

  Future<void> dispose() async {
    await _stateCtrl.close();
    await _player.dispose();
  }

  Future<void> playOfflineOrOnline(int id, int numberInSurah,
      {required int totalAyahs}) async {}
}
