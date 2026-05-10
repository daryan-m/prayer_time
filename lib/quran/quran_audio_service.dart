// ═══════════════════════════════════════════════════════════════
//  lib/quran/quran_audio_service.dart
//
//  پەیوەندی Flutter ↔ Kotlin لە ڕێگەی MethodChannel و EventChannel
//
//  Kotlin ChannelNames:
//    METHOD  →  com.daryan.prayer/quran_media
//    EVENT   →  com.daryan.prayer/quran_media_events
//
//  Kotlin emit()  دەنێرێت:  "complete" | "stopped" | "error"
//
//  pubspec.yaml پێویستی:
//    just_audio   ❌  پێویست نییە
//    audio_session ❌  پێویست نییە
//    — هەموو کار لە Kotlin QuranMediaService دەکرێت
// ═══════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'quran_database_helper.dart';
import 'quran_models.dart';

// ─────────────────────────────────────────────────────────────
//  دۆخی پلەیەر
// ─────────────────────────────────────────────────────────────

enum QuranPlayState { idle, loading, playing, paused, stopped, error }

// ═══════════════════════════════════════════════════════════════
//  QuranAudioService  —  سینگلتۆن
// ═══════════════════════════════════════════════════════════════

class QuranAudioService extends ChangeNotifier {
  QuranAudioService._();
  static final QuranAudioService instance = QuranAudioService._();

  // ── Kotlin Channels ──────────────────────────────────────────
  static const _methodChannel = MethodChannel('com.daryan.prayer/quran_media');
  static const _eventChannel =
      EventChannel('com.daryan.prayer/quran_media_events');

  StreamSubscription? _eventSub;

  // ── دۆخی ئێستا ───────────────────────────────────────────────
  QuranPlayState _state = QuranPlayState.idle;
  String? _currentVerseKey; // "2:255"
  int? _activeWordIndex; // وشەی هایلایتکراو (لە segments)
  bool _repeatAyah = false;
  bool _autoNextAyah = true;

  // ── گیتەرەکان ─────────────────────────────────────────────────
  QuranPlayState get state => _state;
  String? get currentVerseKey => _currentVerseKey;
  int? get activeWordIndex => _activeWordIndex;
  bool get repeatAyah => _repeatAyah;
  bool get autoNextAyah => _autoNextAyah;
  bool get isPlaying => _state == QuranPlayState.playing;

  // ─────────────────────────────────────────────────────────────
  //  دەستپێکردن — گوێگرتن لە ئیڤێنتی Kotlin
  // ─────────────────────────────────────────────────────────────

  void init() {
    if (_eventSub != null) return; // دووجار نەکرێتەوە
    _eventSub = _eventChannel
        .receiveBroadcastStream()
        .listen(_onKotlinEvent, onError: _onKotlinError);
  }

  // ─────────────────────────────────────────────────────────────
  //  گوێگرتن لە ئیڤێنتی Kotlin
  //    "complete" → ئایەتی دواتر یان تکرار
  //    "stopped"  → ڕاگرتنی تەواو
  //    "error"    → هەڵە
  // ─────────────────────────────────────────────────────────────

  void _onKotlinEvent(dynamic event) {
    switch (event as String) {
      case 'complete':
        if (_repeatAyah && _currentVerseKey != null) {
          _replayCurrentAyah();
        } else if (_autoNextAyah) {
          nextAyah();
        } else {
          _setState(QuranPlayState.stopped);
        }
        break;
      case 'stopped':
        _stopWordHighlight();
        _setState(QuranPlayState.stopped);
        _activeWordIndex = null;
        notifyListeners();
        break;
      case 'error':
        _stopWordHighlight();
        _setState(QuranPlayState.error);
        break;
    }
  }

  void _onKotlinError(Object err) {
    debugPrint('QuranAudioService EventChannel error: $err');
    _setState(QuranPlayState.error);
  }

  // ─────────────────────────────────────────────────────────────
  //  پلەی ئایەت
  // ─────────────────────────────────────────────────────────────

  /// پلەی ئایەتێک — URL لە JSON cache دەهێنرێت
  Future<void> playAyah(int surah, int ayah) async {
    final audio = QuranDatabaseHelper.instance.getAyahAudio(surah, ayah);
    if (audio == null) {
      debugPrint('QuranAudioService: no audio for $surah:$ayah');
      return;
    }

    _currentVerseKey = '$surah:$ayah';
    _activeWordIndex = null;
    _stopWordHighlight();
    _setState(QuranPlayState.loading);

    try {
      // QuranMediaService.kt → playNew(isFile=false, source=url, title=...)
      await _methodChannel.invokeMethod<void>('play', {
        'isFile': false,
        'source': audio.audioUrl, // https://audio-cdn.tarteel.ai/...
        'title': _buildTitle(surah, ayah),
      });
      _setState(QuranPlayState.playing);
      _startWordHighlight(audio);
    } on PlatformException catch (e) {
      debugPrint('QuranAudioService play error: ${e.message}');
      _setState(QuranPlayState.error);
    }
  }

  // ─────────────────────────────────────────────────────────────
  //  کۆنترۆڵەکان
  // ─────────────────────────────────────────────────────────────

  Future<void> pause() async {
    if (_state != QuranPlayState.playing) return;
    _stopWordHighlight();
    try {
      await _methodChannel.invokeMethod<void>('pause');
    } on PlatformException catch (e) {
      debugPrint('pause error: ${e.message}');
    }
    _setState(QuranPlayState.paused);
  }

  Future<void> resume() async {
    if (_state != QuranPlayState.paused) return;
    try {
      await _methodChannel.invokeMethod<void>('resume');
    } on PlatformException catch (e) {
      debugPrint('resume error: ${e.message}');
      return;
    }
    _setState(QuranPlayState.playing);
    // هایلایت دووبارە دەستی پێ بکا لە شوێنی ماوەتەوە
    final vk = _currentVerseKey;
    if (vk != null) {
      final p = vk.split(':');
      final audio = QuranDatabaseHelper.instance
          .getAyahAudio(int.parse(p[0]), int.parse(p[1]));
      if (audio != null) _startWordHighlight(audio);
    }
  }

  Future<void> togglePlayPause() async {
    if (isPlaying) {
      await pause();
    } else if (_state == QuranPlayState.paused) {
      await resume();
    }
  }

  Future<void> stop() async {
    _stopWordHighlight();
    try {
      await _methodChannel.invokeMethod<void>('stop');
    } on PlatformException catch (e) {
      debugPrint('stop error: ${e.message}');
    }
    _currentVerseKey = null;
    _activeWordIndex = null;
    _setState(QuranPlayState.stopped);
  }

  Future<void> nextAyah() async {
    if (_currentVerseKey == null) return;
    final p = _currentVerseKey!.split(':');
    final surah = int.parse(p[0]);
    final ayah = int.parse(p[1]);
    final info = kSurahList.firstWhere(
      (s) => s.number == surah,
      orElse: () => kSurahList.first,
    );
    if (ayah < info.totalAyahs) {
      await playAyah(surah, ayah + 1);
    } else if (surah < 114) {
      await playAyah(surah + 1, 1);
    } else {
      await stop();
    }
  }

  Future<void> prevAyah() async {
    if (_currentVerseKey == null) return;
    final p = _currentVerseKey!.split(':');
    final surah = int.parse(p[0]);
    final ayah = int.parse(p[1]);
    if (ayah > 1) {
      await playAyah(surah, ayah - 1);
    } else if (surah > 1) {
      final prev = kSurahList.firstWhere((s) => s.number == surah - 1);
      await playAyah(surah - 1, prev.totalAyahs);
    }
  }

  // ── ئۆپشنەکان ───────────────────────────────────────────────

  void setRepeatAyah(bool v) {
    _repeatAyah = v;
    notifyListeners();
  }

  void setAutoNextAyah(bool v) {
    _autoNextAyah = v;
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────
  //  هایلایتی وشە  —  بەپێی segments-ی JSON
  //
  //  segments فۆرمات:  [[wordIndex, startMs, endMs], ...]
  //  نموونە:  [1, 0, 840]  →  وشەی 1  لە 0ms بۆ 840ms
  //
  //  چونکە Kotlin MediaPlayer هیچ position callback نەدەنێرێت بۆ
  //  Flutter، تایمەرێکی ناوخۆ بەکار دەهێنین کە لە دەستپێکی
  //  playAyah() دەست دەکات و elapsed time چیک دەکات.
  // ─────────────────────────────────────────────────────────────

  Timer? _highlightTimer;
  DateTime? _playStartTime;
  List<List<int>>? _activeSegments;

  void _startWordHighlight(AyahAudio audio) {
    _stopWordHighlight();
    if (audio.segments.isEmpty) return;
    _activeSegments = audio.segments;
    _playStartTime = DateTime.now();

    // هەر 80ms یەکجار چیک دەکات (خێرای بەسەر بدوز)
    _highlightTimer = Timer.periodic(
      const Duration(milliseconds: 80),
      (_) => _checkWordHighlight(),
    );
  }

  void _checkWordHighlight() {
    final segs = _activeSegments;
    final start = _playStartTime;
    if (segs == null || start == null) return;

    final elapsed = DateTime.now().difference(start).inMilliseconds;
    int? newWord;
    for (final seg in segs) {
      if (elapsed >= seg[1] && elapsed <= seg[2]) {
        newWord = seg[0] - 1; // 1-based → 0-based index
        break;
      }
    }
    if (newWord != _activeWordIndex) {
      _activeWordIndex = newWord;
      notifyListeners();
    }
  }

  void _stopWordHighlight() {
    _highlightTimer?.cancel();
    _highlightTimer = null;
    _playStartTime = null;
    _activeSegments = null;
  }

  // ─────────────────────────────────────────────────────────────
  //  یارمەتیدەرەکانی ناوخۆ
  // ─────────────────────────────────────────────────────────────

  Future<void> _replayCurrentAyah() async {
    final vk = _currentVerseKey;
    if (vk == null) return;
    final p = vk.split(':');
    await playAyah(int.parse(p[0]), int.parse(p[1]));
  }

  void _setState(QuranPlayState s) {
    _state = s;
    notifyListeners();
  }

  /// ناوی ئایەت بۆ نۆتیفیکەیشنی Kotlin
  String _buildTitle(int surah, int ayah) {
    final info = kSurahList.firstWhere(
      (s) => s.number == surah,
      orElse: () => kSurahList.first,
    );
    return '${info.name}  —  ئایەت $ayah';
  }

  // ─────────────────────────────────────────────────────────────
  //  داخستن
  // ─────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _stopWordHighlight();
    _eventSub?.cancel();
    super.dispose();
  }
}
