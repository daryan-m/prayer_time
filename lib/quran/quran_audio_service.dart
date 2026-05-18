// ============================================================
//  quran_audio_service.dart
//
//  بەرپرسێتییەکان:
//    • لیدانی دەنگ ئایەت بە ئایەت
//    • هایلایتی وشە بەپێی segments
//    • بەردەوام بوون بۆ ئایەتی دواتر
//    • ئۆفلاین cache
//
//  سەرچاوەی دەنگ:
//    ئۆنلاین: cdn.islamic.network/quran/audio/128/{id}/{n}.mp3
//    ئۆفلاین: ApplicationDocuments/quran_audio/{n}.mp3
//    n = global ayah number (1:1=1, 2:1=8, ..., 114:6=6236)
//
//  تایمینگ:
//    assets/quran/ayah-recitation-...json
//    فۆرمات: { "1:1": { segments: [[pos,startMs,endMs], ...] } }
//
//  pubspec:
//    just_audio, http, path, path_provider
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'quran_models.dart';

// ── global ayah number ──────────────────────────────────────
// global(surah, ayah) = _kStart[surah] + ayah
// دڵنیابووە: 1:1=1, 1:7=7, 2:1=8, 114:6=6236

const List<int> _kStart = [
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

int _globalN(int surah, int ayah) {
  assert(surah >= 1 && surah <= 114, 'surah out of range');
  return _kStart[surah] + ayah;
}

String _cdnUrl(String reciterId, int surah, int ayah) =>
    'https://cdn.islamic.network/quran/audio/128/'
    '$reciterId/${_globalN(surah, ayah)}.mp3';

const String _kTimingAsset =
    'assets/quran/ayah-recitation-muhammad-siddiq-al-minshawi-murattal-hafs-959.json';
const String _kAudioDir = 'quran_audio';

// ────────────────────────────────────────────────────────────
//  _Seg  —  تایمینگی یەک وشە
// ────────────────────────────────────────────────────────────

class _Seg {
  final int pos; // 1-based word position
  final int startMs;
  final int endMs;
  const _Seg(this.pos, this.startMs, this.endMs);
}

// ────────────────────────────────────────────────────────────
//  _TimingCache  —  JSON asset بارکردن یەکجار
// ────────────────────────────────────────────────────────────

class _TimingCache {
  static final _TimingCache _instance = _TimingCache._();
  factory _TimingCache() => _instance;
  _TimingCache._();

  bool _loaded = false;
  final Map<String, List<_Seg>> _data = {};

  Future<void> ensure() async {
    if (_loaded) return;
    try {
      final raw = await rootBundle.loadString(_kTimingAsset);
      final root = jsonDecode(raw) as Map<String, dynamic>;
      for (final e in root.entries) {
        final rawSegs = e.value['segments'] as List<dynamic>?;
        if (rawSegs == null || rawSegs.isEmpty) continue;
        _data[e.key] = rawSegs.map<_Seg>((s) {
          final a = s as List<dynamic>;
          return _Seg(
            (a[0] as num).toInt(),
            (a[1] as num).toInt(),
            (a[2] as num).toInt(),
          );
        }).toList();
      }
      _loaded = true;
      debugPrint('[Timing] loaded ${_data.length} ayahs');
    } catch (e) {
      debugPrint('[Timing] error: $e');
    }
  }

  List<_Seg> segsFor(int surah, int ayah) => _data['$surah:$ayah'] ?? const [];
}

// ────────────────────────────────────────────────────────────
//  QuranAudioService  —  singleton
// ────────────────────────────────────────────────────────────

class QuranAudioService {
  QuranAudioService._();
  static final QuranAudioService instance = QuranAudioService._();
  factory QuranAudioService() => instance;

  final _player = AudioPlayer();
  final _timing = _TimingCache();
  final _ctrl = StreamController<AudioState>.broadcast();

  AudioState _state = const AudioState();
  Reciter _reciter = Reciter.defaults.first;
  int _surah = 1;
  int _ayah = 1;
  int _total = 7;
  List<_Seg> _segs = [];

  Stream<AudioState> get stream => _ctrl.stream;
  AudioState get current => _state;

  // ── راستکردنەوە ─────────────────────────────────────────

  Future<void> init() async {
    await _timing.ensure();

    _player.playerStateStream.listen((ps) {
      if (ps.processingState == ProcessingState.completed) {
        _onComplete();
      }
    });

    _player.positionStream.listen((pos) {
      _tick(pos.inMilliseconds);
      _emit(_state.copyWith(position: pos));
    });

    _player.durationStream.listen((dur) {
      if (dur != null) _emit(_state.copyWith(duration: dur));
    });
  }

  // ── قاریئ ───────────────────────────────────────────────

  void setReciter(Reciter r) {
    _reciter = r;
    _emit(_state.copyWith(reciter: r));
  }

  // ── لیدان ───────────────────────────────────────────────

  Future<void> play(int surah, int ayah, {required int totalAyahs}) async {
    _surah = surah;
    _ayah = ayah;
    _total = totalAyahs;
    _segs = _timing.segsFor(surah, ayah);

    _emit(_state.copyWith(
      status: AudioPlaybackState.loading,
      currentSurahId: surah,
      currentAyahNumber: ayah,
      clearHighlight: true,
      reciter: _reciter,
    ));

    try {
      await _player.setAudioSource(await _buildSource(surah, ayah));
      await _player.play();
      _emit(_state.copyWith(status: AudioPlaybackState.playing));
    } catch (e) {
      debugPrint('[Audio] play error: $e');
      _emit(_state.copyWith(
        status: AudioPlaybackState.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<AudioSource> _buildSource(int surah, int ayah) async {
    final path = await _localPath(surah, ayah);
    if (await File(path).exists()) {
      return AudioSource.file(path);
    }
    return AudioSource.uri(Uri.parse(_cdnUrl(_reciter.id, surah, ayah)));
  }

  // ── کنترۆڵ ──────────────────────────────────────────────

  Future<void> pause() async {
    await _player.pause();
    _emit(_state.copyWith(status: AudioPlaybackState.paused));
  }

  Future<void> resume() async {
    await _player.play();
    _emit(_state.copyWith(status: AudioPlaybackState.playing));
  }

  Future<void> togglePlayPause() async {
    if (_state.isPlaying) {
      await pause();
    } else if (_state.isPaused) {
      await resume();
    }
  }

  Future<void> stop() async {
    _segs = [];
    await _player.stop();
    _emit(const AudioState());
  }

  Future<void> nextAyah() async {
    if (_ayah < _total) await play(_surah, _ayah + 1, totalAyahs: _total);
  }

  Future<void> prevAyah() async {
    if (_ayah > 1) await play(_surah, _ayah - 1, totalAyahs: _total);
  }

  // ── هایلایتی وشە ────────────────────────────────────────

  void _tick(int posMs) {
    if (_segs.isEmpty) return;
    for (int i = 0; i < _segs.length; i++) {
      final s = _segs[i];
      final nextMs =
          i < _segs.length - 1 ? _segs[i + 1].startMs : s.endMs + 1000;
      if (posMs >= s.startMs && posMs < nextMs) {
        final idx = s.pos - 1; // convert to 0-based
        if (_state.highlightedWordIndex != idx) {
          _emit(_state.copyWith(highlightedWordIndex: idx));
        }
        return;
      }
    }
  }

  // ── بەردەوامبوون ────────────────────────────────────────

  void _onComplete() {
    if (_ayah < _total) {
      Future.delayed(
        const Duration(milliseconds: 300),
        () => play(_surah, _ayah + 1, totalAyahs: _total),
      );
    } else {
      _emit(const AudioState());
    }
  }

  // ── ئۆفلاین ─────────────────────────────────────────────

  Future<bool> isDownloaded(int surah, int ayah) async =>
      File(await _localPath(surah, ayah)).exists();

  Future<void> downloadAyah(int surah, int ayah) async {
    final path = await _localPath(surah, ayah);
    final file = File(path);
    if (await file.exists()) return;
    try {
      final resp = await http.get(Uri.parse(_cdnUrl(_reciter.id, surah, ayah)));
      if (resp.statusCode == 200) {
        await file.parent.create(recursive: true);
        await file.writeAsBytes(resp.bodyBytes);
      }
    } catch (e) {
      debugPrint('[Audio] download error: $e');
    }
  }

  // ── یارمەتیدەر ──────────────────────────────────────────

  Future<String> _localPath(int surah, int ayah) async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, _kAudioDir, '${_globalN(surah, ayah)}.mp3');
  }

  void _emit(AudioState s) {
    _state = s;
    if (!_ctrl.isClosed) _ctrl.add(s);
  }

  Future<void> dispose() async {
    await _ctrl.close();
    await _player.dispose();
  }
}
