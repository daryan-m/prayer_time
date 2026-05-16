// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// quran_audio_service.dart
//
// دەنگ: cdn.islamic.network (global ayah number)
// تایمینگ: JSON asset (segments بۆ هایلایتی وشە)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'quran_models.dart';

const String _kAudioCacheFolder = 'quran_audio';
const String _kTimingAsset =
    'assets/quran/ayah-recitation-muhammad-siddiq-al-minshawi-murattal-hafs-959.json';

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// global ayah number
// global(surah, ayah) = _kSurahStart[surah] + ayah
// 1:1=1 ... 1:7=7 | 2:1=8 ... 114:6=6236
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

const List<int> _kSurahStart = [
  0,
  0,
  7,
  293,
  493,
  669,
  789,
  954,
  1164,
  1234,
  1364,
  1494,
  1611,
  1754,
  1816,
  1869,
  1926,
  2029,
  2140,
  2249,
  2348,
  2483,
  2595,
  2673,
  2790,
  2855,
  2992,
  3159,
  3252,
  3340,
  3409,
  3469,
  3503,
  3531,
  3606,
  3660,
  3705,
  3788,
  3856,
  3924,
  4000,
  4081,
  4133,
  4218,
  4272,
  4325,
  4414,
  4473,
  4510,
  4542,
  4591,
  4621,
  4675,
  4705,
  4735,
  4783,
  4846,
  4901,
  4978,
  5074,
  5104,
  5127,
  5148,
  5163,
  5177,
  5188,
  5199,
  5213,
  5227,
  5240,
  5271,
  5283,
  5294,
  5303,
  5311,
  5322,
  5336,
  5357,
  5379,
  5397,
  5416,
  5431,
  5440,
  5448,
  5458,
  5467,
  5475,
  5482,
  5494,
  5502,
  5511,
  5520,
  5527,
  5533,
  5536,
  5542,
  5546,
  5550,
  5555,
  5559,
  5563,
  5565,
  5571,
  5577,
  5582,
  5587,
  5590,
  5595,
  5599,
  5603,
  5607,
  5611,
  5616,
  5621,
  5626,
  5630,
  5634,
  5639,
  5642,
  5645,
];

int _globalAyah(int surah, int ayah) {
  if (surah < 1 || surah >= _kSurahStart.length) return ayah;
  return _kSurahStart[surah] + ayah;
}

String _onlineUrl(String reciterId, int surah, int ayah) =>
    'https://cdn.islamic.network/quran/audio/128/$reciterId/${_globalAyah(surah, ayah)}.mp3';

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// _Segment
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _Segment {
  final int wordPos; // 1-based
  final int startMs;
  final int endMs;
  const _Segment(this.wordPos, this.startMs, this.endMs);
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// _TimingCache
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _TimingCache {
  static final _TimingCache _i = _TimingCache._();
  factory _TimingCache() => _i;
  _TimingCache._();

  bool _loaded = false;
  final Map<String, List<_Segment>> _segs = {};

  Future<void> load() async {
    if (_loaded) return;
    try {
      final raw = await rootBundle.loadString(_kTimingAsset);
      final root = jsonDecode(raw) as Map<String, dynamic>;
      for (final e in root.entries) {
        final val = e.value as Map<String, dynamic>;
        final rawSegs = val['segments'] as List<dynamic>?;
        if (rawSegs != null) {
          _segs[e.key] = rawSegs.map<_Segment>((s) {
            final seg = s as List<dynamic>;
            return _Segment(
              (seg[0] as num).toInt(),
              (seg[1] as num).toInt(),
              (seg[2] as num).toInt(),
            );
          }).toList();
        }
      }
      _loaded = true;
    } catch (e) {
      debugPrint('[Timing] $e');
    }
  }

  List<_Segment> segsFor(int surah, int ayah) =>
      _segs['$surah:$ayah'] ?? const [];
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// QuranAudioService
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class QuranAudioService {
  static final QuranAudioService _instance = QuranAudioService._internal();
  factory QuranAudioService() => _instance;
  QuranAudioService._internal();

  final AudioPlayer _player = AudioPlayer();
  final _stateCtrl = StreamController<AudioState>.broadcast();
  final _timing = _TimingCache();

  AudioState _state = const AudioState();
  Reciter _reciter = Reciter.defaults.first;
  int _surahId = 1;
  int _ayahNumber = 1;
  int _totalAyahs = 7;
  List<_Segment> _curSegs = [];

  Stream<AudioState> get stateStream => _stateCtrl.stream;
  AudioState get currentState => _state;

  Future<void> init() async {
    await _timing.load();

    _player.playerStateStream.listen((ps) {
      if (ps.processingState == ProcessingState.completed) _onCompleted();
    });

    _player.positionStream.listen((pos) {
      _updateHighlight(pos.inMilliseconds);
      _emit(_state.copyWith(position: pos));
    });

    _player.durationStream.listen((dur) {
      if (dur != null) _emit(_state.copyWith(duration: dur));
    });
  }

  void setReciter(Reciter reciter) {
    _reciter = reciter;
    _emit(_state.copyWith(reciter: reciter));
  }

  Future<void> play(int surahId, int ayahNumber, {int totalAyahs = 7}) async {
    _surahId = surahId;
    _ayahNumber = ayahNumber;
    _totalAyahs = totalAyahs;
    _curSegs = _timing.segsFor(surahId, ayahNumber);

    _emit(_state.copyWith(
      status: AudioPlaybackState.loading,
      currentSurahId: surahId,
      currentAyahNumber: ayahNumber,
      clearHighlight: true,
      reciter: _reciter,
    ));

    try {
      final source = await _resolveSource(surahId, ayahNumber);
      await _player.setAudioSource(source);
      await _player.play();
      _emit(_state.copyWith(status: AudioPlaybackState.playing));
    } catch (e) {
      debugPrint('[Audio] $e');
      _emit(_state.copyWith(
        status: AudioPlaybackState.error,
        errorMessage: '$e',
      ));
    }
  }

  Future<AudioSource> _resolveSource(int surahId, int ayahNumber) async {
    final filePath = await _localPath(surahId, ayahNumber);
    if (await File(filePath).exists()) return AudioSource.file(filePath);
    final url = _onlineUrl(_reciter.id, surahId, ayahNumber);
    return AudioSource.uri(Uri.parse(url));
  }

  Future<void> pause() async {
    await _player.pause();
    _emit(_state.copyWith(status: AudioPlaybackState.paused));
  }

  Future<void> resume() async {
    await _player.play();
    _emit(_state.copyWith(status: AudioPlaybackState.playing));
  }

  Future<void> stop() async {
    _curSegs = [];
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

  void _updateHighlight(int posMs) {
    if (_curSegs.isEmpty) return;
    for (int i = 0; i < _curSegs.length; i++) {
      final s = _curSegs[i];
      final nextStart =
          i < _curSegs.length - 1 ? _curSegs[i + 1].startMs : s.endMs + 1000;
      if (posMs >= s.startMs && posMs < nextStart) {
        final wordIdx = s.wordPos - 1;
        if (_state.highlightedWordIndex != wordIdx) {
          _emit(_state.copyWith(highlightedWordIndex: wordIdx));
        }
        return;
      }
    }
  }

  Future<bool> isDownloaded(int surahId, int ayahNumber) async =>
      File(await _localPath(surahId, ayahNumber)).exists();

  Future<void> downloadAyah(int surahId, int ayahNumber) async {
    final path = await _localPath(surahId, ayahNumber);
    final file = File(path);
    if (await file.exists()) return;
    try {
      final url = _onlineUrl(_reciter.id, surahId, ayahNumber);
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode == 200) {
        await file.parent.create(recursive: true);
        await file.writeAsBytes(resp.bodyBytes);
      }
    } catch (_) {}
  }

  void _onCompleted() {
    if (_ayahNumber < _totalAyahs) {
      Future.delayed(const Duration(milliseconds: 300), () {
        play(_surahId, _ayahNumber + 1, totalAyahs: _totalAyahs);
      });
    } else {
      _emit(const AudioState());
    }
  }

  Future<String> _localPath(int surahId, int ayahNumber) async {
    final dir = await getApplicationDocumentsDirectory();
    final n = _globalAyah(surahId, ayahNumber);
    return p.join(dir.path, _kAudioCacheFolder, '$n.mp3');
  }

  void _emit(AudioState state) {
    _state = state;
    if (!_stateCtrl.isClosed) _stateCtrl.add(state);
  }

  Future<void> dispose() async {
    await _stateCtrl.close();
    await _player.dispose();
  }
}
