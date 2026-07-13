import 'package:flutter/material.dart';
import 'quran_models.dart';
import 'quran_audio_service.dart';
import 'quran_database_helper.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// QuranPageAudioBridge
//
// ئەم کلاسە هەموو لۆجیکی هاوکاری نێوان دەنگ و لاپەڕەکانی قورئان هەیەتی
//
// حاڵەتەکانی هاندەڵ دەکات:
//  ١. سوایپی لاپەڕە  → ئایەتی یەکەمی لاپەڕەی نوێ دەخوێنێت
//  ٢. هەڵبژاردنی سورە → لە سورەتی نوێ دەستپێدەکات (+ بسمەڵە)
//  ٣. هەڵبژاردنی جوز  → لەو ئایەتەی دەستپێدەکات  (+ بسمەڵە گەرەک بوو)
//  ٤. کۆتایی لاپەڕە   → تۆماتیک لاپەڕە گۆڕدرێت
//  ٥. کۆتایی سورەت   → بسمەڵە + سورەتی دواتر  (لە audio service دایە)
//
// بەکارهێنان لە quran_screen.dart:
//
//   late QuranPageAudioBridge _bridge;
//
//   void initState() {
//     super.initState();
//     _init();   // لەناوی init دوای ساختن:
//   }
//
//   // لەناوی _init(), دوای _audio.init():
//   _bridge = QuranPageAudioBridge(
//     audio: _audio,
//     db: _db,
//     pageController: _pageController,
//     setState: setState,
//   );
//
//   // لە dispose():
//   _bridge.dispose();
//
//   // _onPageChanged بگۆڕە بۆ:
//   Future<void> _onPageChanged(int index) async {
//     final newPage = index + 1;
//     await _loadPage(newPage);
//     if (!mounted) return;
//     await _bridge.handlePageChanged(newPage, _pageWords);
//   }
//
//   // _showSurahList() بگۆڕە بۆ:
//   void _showSurahList() => showSurahListSheet(
//     ...,
//     onSurahSelected: (surahId, page) => _bridge.handleSurahSelected(surahId, page),
//   );
//
//   // _showJuzList() بگۆڕە بۆ:
//   void _showJuzList() async {
//     ...
//     showJuzListSheet(
//       ...,
//       onJuzSelected: (surah, ayah, page) => _bridge.handleJuzSelected(surah, ayah, page),
//     );
//   }
//
//   // _onAudioChanged و _isSwiping بیسرە — bridge ئەمەی جێگیر دەکات
// ═══════════════════════════════════════════════════════════════════════════════

class QuranPageAudioBridge {
  final QuranAudioService _audio;
  final QuranDatabaseHelper _db;
  final PageController _pageController;
  final void Function(VoidCallback) _setState;

  bool _isAudioNavigation = false;
  bool _isSwipeHandling = false; // ← زیاد بکە
  int _currentPage = 1;

  QuranPageAudioBridge({
    required QuranAudioService audio,
    required QuranDatabaseHelper db,
    required PageController pageController,
    required void Function(VoidCallback) setState,
  })  : _audio = audio,
        _db = db,
        _pageController = pageController,
        _setState = setState {
    _audio.addListener(_onAudioChanged);
  }

  void dispose() {
    _audio.removeListener(_onAudioChanged);
  }

  // ── ١. لیستەنەری دەنگ — ئۆتۆماتیک گۆڕینی لاپەڕە ─────────────────────────
  void _onAudioChanged() {
    final s = _audio.currentSurah;
    final a = _audio.currentAyah;
    if (s <= 0 || a <= 0) {
      _setState(() {});
      return;
    }
    _db.getPageForAyah(s, a).then((page) {
      if (_isSwipeHandling) {
        _setState(() {});
        return;
      }
      if (page != _currentPage) {
        if (_audio.isPlaying || _audio.state == AudioState.loading) {
          _isAudioNavigation = true;
          _pageController.animateToPage(
            page - 1,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
          );
        } else {
          _setState(() {});
        }
      } else {
        _setState(() {});
      }
    });
  }

  void beginSwipe() {
    _isSwipeHandling = true;
  }

  // ── ٢. هاندەڵ کردنی گۆڕینی لاپەڕە ───────────────────────────────────────────
  // ئەمە لە _onPageChanged() دوای _loadPage() بانگهێشت بکە
  Future<void> handlePageChanged(int newPage, List<QuranWord> pageWords) async {
    _currentPage = newPage;

    // ئۆتۆماتیک بوو (دەنگ بوو لاپەڕەی گۆڕی) → تەنها ریبیلد
    if (_isAudioNavigation) {
      _isAudioNavigation = false;
      _setState(() {});
      return;
    }

    // بەکارهێنەر خۆی سوایپی کرد
    final wasPlaying = _audio.isPlaying || _audio.state == AudioState.loading;
    final wasPaused = _audio.isPaused;

    _isSwipeHandling = true; // ← پێش pause()
    if (wasPlaying) await _audio.pause();

    final firstWord = pageWords.isNotEmpty ? pageWords.first : null;
    if (firstWord == null) {
      _isSwipeHandling = false;
      _setState(() {});
      return;
    }

    if (wasPlaying) {
      _audio.setPlayingPage(newPage);
      _audio.setCurrentAyah(firstWord.surah, firstWord.ayah);
      await Future.delayed(const Duration(milliseconds: 300));
      await _playWithBasmallahCheck(firstWord.surah, firstWord.ayah);
    } else if (wasPaused) {
      _audio.moveToAyah(firstWord.surah, firstWord.ayah);
    } else {
      _setState(() {});
    }

    _isSwipeHandling = false; // ← دوای تەواو بوون
  }

  // ── ٣. هاندەڵ کردنی هەڵبژاردنی سورە ─────────────────────────────────────────
  Future<void> handleSurahSelected(int surahId, int page) async {
    final wasPlaying = _audio.isPlaying || _audio.state == AudioState.loading;
    _isAudioNavigation = true;
    _currentPage = page;
    _pageController.jumpToPage(page - 1);

    if (wasPlaying || _audio.isPaused) {
      await _audio.playFromSurahStart(surahId);
    }
  }

  // ── ٤. هاندەڵ کردنی هەڵبژاردنی جوز ──────────────────────────────────────────
  Future<void> handleJuzSelected(int surah, int ayah, int page) async {
    final wasPlaying = _audio.isPlaying || _audio.state == AudioState.loading;
    _isAudioNavigation = true;
    _currentPage = page;
    _pageController.jumpToPage(page - 1);

    if (wasPlaying || _audio.isPaused) {
      _audio.setCurrentAyah(surah, ayah);
      await _playWithBasmallahCheck(surah, ayah);
    }
  }

  Future<void> handlePageJump(int newPage, List<QuranWord> pageWords) async {
    _currentPage = newPage;
    final wasPlaying = _audio.isPlaying || _audio.state == AudioState.loading;
    final wasPaused = _audio.isPaused;

    _isSwipeHandling = true;
    if (wasPlaying) await _audio.pause();

    final firstWord = pageWords.isNotEmpty ? pageWords.first : null;
    if (firstWord == null) {
      _isSwipeHandling = false;
      _setState(() {});
      return;
    }

    if (wasPlaying) {
      _audio.setPlayingPage(newPage);
      _audio.setCurrentAyah(firstWord.surah, firstWord.ayah);
      await _playWithBasmallahCheck(firstWord.surah, firstWord.ayah);
    } else if (wasPaused) {
      _audio.moveToAyah(firstWord.surah, firstWord.ayah);
    } else {
      _setState(() {});
    }
    _isSwipeHandling = false;
  }

  // ── یارمەتیدەر: بسمەڵە چەک ───────────────────────────────────────────────────
  Future<void> _playWithBasmallahCheck(int surah, int ayah) async {
    if (ayah == 1 && surah != 1 && surah != 9) {
      await _audio.playFromSurahStart(surah);
    } else {
      await _audio.playAyah(surah, ayah);
    }
  }
}
