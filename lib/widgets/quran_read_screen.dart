import 'dart:async';
import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../utils/constants.dart';
import '../utils/quran_audio_bridge.dart';
import 'quran_service.dart';
import 'quran_surah_data.dart';
import 'quran_download_dialog.dart';

class QuranReadScreen extends StatefulWidget {
  final QuranSurah surah;
  final Color primaryColor;
  final ThemePalette palette;

  const QuranReadScreen({
    super.key,
    required this.surah,
    required this.primaryColor,
    required this.palette,
  });

  @override
  State<QuranReadScreen> createState() => _QuranReadScreenState();
}

class _QuranReadScreenState extends State<QuranReadScreen>
    with WidgetsBindingObserver {
  List<Map<String, dynamic>> _ayahs = [];
  List<List<Map<String, dynamic>>> _pages = [];
  bool _loading = true;
  String _error = '';

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  int _currentAyahIdx = -1;
  int _selectedReciterIdx = 0;

  late PageController _pageCtrl;
  int _currentPage = 0;

  bool _surahDrawerOpen = false;
  bool _reciterDrawerOpen = false;
  int _currentJuz = 1;
  StreamSubscription<dynamic>? _quranNativeSub;

  /// FIX ١: فۆنتی دینامیکی بۆ لاپەرە
  double _currentFontSize = 17.5;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageCtrl = PageController();
    _loadSurah();
    _loadReciter();
    if (!QuranAudioBridge.isNativeAndroid) {
      _initAudioSession();
    }
    if (QuranAudioBridge.isNativeAndroid) {
      _quranNativeSub = QuranAudioBridge.eventStream.listen((event) {
        if (!mounted) return;
        if (event == 'complete' && _isPlaying) {
          _playNext();
        } else if (event == 'stopped') {
          setState(() {
            _isPlaying = false;
            _currentAyahIdx = -1;
          });
        }
      });
    } else {
      _audioPlayer.onPlayerComplete.listen((_) {
        if (!mounted || !_isPlaying) return;
        _playNext();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    WakelockPlus.disable();
    _quranNativeSub?.cancel();
    if (QuranAudioBridge.isNativeAndroid) {
      unawaited(QuranAudioBridge.stop());
    } else {
      _audioPlayer.stop();
      _audioPlayer.dispose();
    }
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadReciter() async {
    final prefs = await SharedPreferences.getInstance();
    final idx = prefs.getInt('quran_reciter_idx') ?? 0;
    if (mounted) {
      setState(
          () => _selectedReciterIdx = idx.clamp(0, quranReciters.length - 1));
    }
  }

  Future<void> _loadSurah() async {
    try {
      final ayahs = await QuranService.loadSurah(widget.surah.number);
      final pages = QuranService.splitIntoPages(ayahs);
      final startPage = await _restoreLastPage(pages);
      if (mounted) {
        setState(() {
          _ayahs = ayahs;
          _pages = pages;
          _currentPage = startPage;
          _loading = false;
          if (pages.isNotEmpty && pages[startPage].isNotEmpty) {
            _currentJuz =
                pages[startPage][0]['juz'] as int? ?? widget.surah.juzStart;
          }
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_pageCtrl.hasClients && startPage < _pages.length) {
            _pageCtrl.jumpToPage(startPage);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'هەڵە لە بارکردن: $e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _initAudioSession() async {
    await _audioPlayer.setPlayerMode(PlayerMode.mediaPlayer);
    await _audioPlayer.setReleaseMode(ReleaseMode.stop);
    await _audioPlayer.setAudioContext(
      const AudioContext(
        android: AudioContextAndroid(
          isSpeakerphoneOn: false,
          stayAwake: true,
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.media,
          audioFocus: AndroidAudioFocus.gain,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: [AVAudioSessionOptions.mixWithOthers],
        ),
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isPlaying &&
        (state == AppLifecycleState.inactive ||
            state == AppLifecycleState.paused)) {
      WakelockPlus.enable();
    }
  }

  String _toKurdishDigits(Object value) {
    const en = '0123456789';
    const ku = '٠١٢٣٤٥٦٧٨٩';
    return value.toString().split('').map((ch) {
      final idx = en.indexOf(ch);
      return idx >= 0 ? ku[idx] : ch;
    }).join();
  }

  Future<void> _saveReadingPosition() async {
    if (_pages.isEmpty || _currentPage >= _pages.length) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('quran_last_surah', widget.surah.number);
    await prefs.setInt(
        'quran_last_page_idx_${widget.surah.number}', _currentPage);
  }

  Future<int> _restoreLastPage(List<List<Map<String, dynamic>>> pages) async {
    final prefs = await SharedPreferences.getInstance();
    final savedIdx =
        prefs.getInt('quran_last_page_idx_${widget.surah.number}') ?? 0;
    if (savedIdx >= pages.length) return 0;
    return savedIdx;
  }

  int _globalIdx(int pageIdx, int localIdx) {
    int c = 0;
    for (int p = 0; p < pageIdx; p++) {
      c += _pages[p].length;
    }
    return c + localIdx;
  }

  int _pageOfGlobal(int gi) {
    int c = 0;
    for (int p = 0; p < _pages.length; p++) {
      if (gi < c + _pages[p].length) return p;
      c += _pages[p].length;
    }
    return _pages.length - 1;
  }

  Future<void> _playAyah(int gi) async {
    if (gi < 0 || gi >= _ayahs.length) return;
    setState(() => _currentAyahIdx = gi);

    final pageIdx = _pageOfGlobal(gi);
    if (_currentPage != pageIdx) {
      _currentPage = pageIdx;
      // FIX ٢: سواپی تۆقەتداری بۆ دواتر (نه بۆ پیشەوە)
      _pageCtrl.animateToPage(pageIdx,
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }

    await WakelockPlus.enable();
    final ayahNum = _ayahs[gi]['a'] as int;
    final key = quranReciters[_selectedReciterIdx].key;
    final src =
        await QuranService.getAudioSource(widget.surah.number, ayahNum, key);

    if (QuranAudioBridge.isNativeAndroid) {
      final title = '${widget.surah.nameArabic} — ${_toKurdishDigits(ayahNum)}';
      await QuranAudioBridge.play(
        isFile: src.startsWith('/'),
        source: src,
        title: title,
      );
    } else {
      await _audioPlayer.stop();
      if (src.startsWith('/')) {
        await _audioPlayer.play(DeviceFileSource(src));
      } else {
        await _audioPlayer.play(UrlSource(src));
      }
    }
  }

  void _playNext() {
    if (_currentAyahIdx < _ayahs.length - 1) {
      _playAyah(_currentAyahIdx + 1);
    } else {
      WakelockPlus.disable();
      setState(() {
        _isPlaying = false;
        _currentAyahIdx = -1;
      });
    }
  }

  Future<void> _togglePlay() async {
    if (QuranAudioBridge.isNativeAndroid) {
      if (_isPlaying) {
        await QuranAudioBridge.pause();
        await WakelockPlus.disable();
        setState(() => _isPlaying = false);
      } else {
        setState(() => _isPlaying = true);
        await WakelockPlus.enable();
        if (_currentAyahIdx < 0) {
          await _playAyah(0);
        } else {
          await QuranAudioBridge.resume();
        }
      }
      return;
    }
    if (_isPlaying) {
      await _audioPlayer.pause();
      await WakelockPlus.disable();
      setState(() => _isPlaying = false);
    } else {
      setState(() => _isPlaying = true);
      await WakelockPlus.enable();
      await _playAyah(_currentAyahIdx < 0 ? 0 : _currentAyahIdx);
    }
  }

  Future<void> _stopPlay() async {
    if (QuranAudioBridge.isNativeAndroid) {
      await QuranAudioBridge.stop();
    } else {
      await _audioPlayer.stop();
    }
    await WakelockPlus.disable();
    setState(() {
      _isPlaying = false;
      _currentAyahIdx = -1;
    });
  }

  void _goToNextSurah() {
    final currentNum = widget.surah.number;
    if (currentNum >= 114) return;
    final nextIdx =
        QuranScreenData.surahs.indexWhere((s) => s.number == currentNum + 1);
    if (nextIdx < 0) return;
    final nextSurah = QuranScreenData.surahs[nextIdx];
    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => QuranReadScreen(
            surah: nextSurah,
            primaryColor: widget.primaryColor,
            palette: widget.palette,
          ),
        ),
      );
    });
  }

  Future<void> _changeReciter(int idx) async {
    final reciter = quranReciters[idx];
    final status = await QuranService.reciterDownloadStatus(reciter.key);

    if (status == ReciterDlStatus.none) {
      if (!mounted) return;
      _showDownloadDialog(reciter, allowOnline: true);
      return;
    }

    if (QuranAudioBridge.isNativeAndroid) {
      await QuranAudioBridge.stop();
    } else {
      await _audioPlayer.stop();
    }
    if (!mounted) return;
    setState(() {
      _selectedReciterIdx = idx;
      _isPlaying = false;
      _currentAyahIdx = -1;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('quran_reciter_idx', idx);
  }

  void _showDownloadDialog(QuranReciter reciter, {bool allowOnline = false}) {
    setState(() => _reciterDrawerOpen = false);

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => QuranDownloadDialog(
        reciter: reciter,
        primaryColor: widget.primaryColor,
        palette: widget.palette,
        surahs: QuranScreenData.surahs,
        allowOnline: allowOnline,
        onUseOnline: allowOnline
            ? () async {
                if (QuranAudioBridge.isNativeAndroid) {
                  QuranAudioBridge.stop();
                } else {
                  _audioPlayer.stop();
                }
                final idx = quranReciters.indexOf(reciter);
                if (!mounted) return;
                setState(() {
                  _selectedReciterIdx = idx;
                  _isPlaying = false;
                  _currentAyahIdx = -1;
                });
                SharedPreferences.getInstance()
                    .then((p) => p.setInt('quran_reciter_idx', idx));
              }
            : null,
        onDownloadComplete: () async {
          if (QuranAudioBridge.isNativeAndroid) {
            QuranAudioBridge.stop();
          } else {
            _audioPlayer.stop();
          }
          final idx = quranReciters.indexOf(reciter);
          if (!mounted) return;
          setState(() {
            _selectedReciterIdx = idx;
            _isPlaying = false;
            _currentAyahIdx = -1;
          });
          SharedPreferences.getInstance()
              .then((p) => p.setInt('quran_reciter_idx', idx));
        },
      ),
    );
  }

  Widget _buildPage(int pageIdx, BoxConstraints constraints) {
    final pageAyahs = _pages[pageIdx];
    if (pageAyahs.isEmpty) return const SizedBox();
    final mushafPage = pageAyahs[0]['page'] as int;

    return Column(children: [
      Expanded(
        child: _PageContent(
          pageAyahs: pageAyahs,
          pageIdx: pageIdx,
          currentAyahIdx: _currentAyahIdx,
          isPlaying: _isPlaying,
          primaryColor: widget.primaryColor,
          palette: widget.palette,
          onAyahTap: (gi) async {
            setState(() => _isPlaying = true);
            await _playAyah(gi);
          },
          onFontSizeChange: (size) {
            setState(() => _currentFontSize = size);
          },
          currentFontSize: _currentFontSize,
          globalIdx: _globalIdx,
          availableHeight: constraints.maxHeight,
          isFirstSurahPage: pageIdx == 0,
          surahNumber: widget.surah.number,
        ),
      ),
      Container(
        padding: const EdgeInsets.symmetric(vertical: 3),
        color: widget.palette.cardBg,
        child: Text(
          '— ${_toKurdishDigits(mushafPage)} —',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: widget.palette.listText.withOpacity(0.4), fontSize: 11),
        ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final pc = widget.primaryColor;
    final pal = widget.palette;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: pal.background,
        appBar: AppBar(
          backgroundColor: pal.background,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: pal.secondary),
            onPressed: () async {
              final nav = Navigator.of(context);
              await _saveReadingPosition();
              if (mounted) nav.pop();
            },
          ),
          title: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                widget.surah.nameArabic,
                style: TextStyle(
                  color: pal.secondary,
                  fontSize: 17,
                  fontFamily: 'Uthmanic',
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${_toKurdishDigits(widget.surah.ayahCount)} ئایەت · ${widget.surah.isMakki ? "مەکی" : "مەدەنی"} · جوزئی ${_toKurdishDigits(_currentJuz)}',
                style: TextStyle(
                    color: pal.listText.withOpacity(0.6), fontSize: 10),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          centerTitle: true,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: Colors.white24),
          ),
        ),
        body: _loading
            ? Center(child: CircularProgressIndicator(color: pc))
            : _error.isNotEmpty
                ? Center(
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                        Text(_error,
                            style: const TextStyle(color: Colors.white70),
                            textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _loading = true;
                              _error = '';
                            });
                            _loadSurah();
                          },
                          child: const Text("دووبارە هەوڵ بدەرەوە"),
                        ),
                      ]))
                : Stack(children: [
                    Column(children: [
                      Expanded(
                        child: LayoutBuilder(
                          builder: (ctx, constraints) => PageView.builder(
                            controller: _pageCtrl,
                            // FIX ٢: بۆ سواپی لاپەرە بۆ دواتر (ڕاست)
                            reverse: false,
                            itemCount: _pages.length,
                            onPageChanged: (p) {
                              setState(() {
                                _currentPage = p;
                                if (_pages[p].isNotEmpty) {
                                  _currentJuz = _pages[p][0]['juz'] as int? ??
                                      widget.surah.juzStart;
                                }
                              });
                              _saveReadingPosition();
                              if (p == _pages.length - 1) {
                                _goToNextSurah();
                              }
                            },
                            itemBuilder: (_, pi) => _buildPage(pi, constraints),
                          ),
                        ),
                      ),
                      _buildPlayer(),
                    ]),
                    if (_surahDrawerOpen || _reciterDrawerOpen)
                      GestureDetector(
                        onTap: () => setState(() {
                          _surahDrawerOpen = false;
                          _reciterDrawerOpen = false;
                        }),
                        child: Container(color: Colors.black54),
                      ),
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeInOut,
                      left: _surahDrawerOpen
                          ? 0
                          : -MediaQuery.of(context).size.width * 0.55,
                      top: 0,
                      bottom: 0,
                      width: MediaQuery.of(context).size.width * 0.55,
                      child: _SurahDrawer(
                        surahs: QuranScreenData.surahs,
                        currentSurah: widget.surah,
                        primaryColor: pc,
                        palette: pal,
                        onSelect: (s) {
                          setState(() => _surahDrawerOpen = false);
                          Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => QuranReadScreen(
                                  surah: s,
                                  primaryColor: pc,
                                  palette: pal,
                                ),
                              ));
                        },
                      ),
                    ),
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeInOut,
                      right: _reciterDrawerOpen
                          ? 0
                          : -MediaQuery.of(context).size.width * 0.55,
                      top: 0,
                      bottom: 0,
                      width: MediaQuery.of(context).size.width * 0.55,
                      child: _ReciterDrawer(
                        isOpen: _reciterDrawerOpen,
                        selectedIdx: _selectedReciterIdx,
                        primaryColor: pc,
                        palette: pal,
                        onSelect: (idx) {
                          setState(() => _reciterDrawerOpen = false);
                          _changeReciter(idx);
                        },
                      ),
                    ),
                  ]),
      ),
    );
  }

  Widget _buildPlayer() {
    final pc = widget.primaryColor;
    final pal = widget.palette;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: pal.cardBg,
          border: Border(top: BorderSide(color: pc.withOpacity(0.2))),
        ),
        child: Row(children: [
          GestureDetector(
            onTap: () => setState(() {
              _surahDrawerOpen = !_surahDrawerOpen;
              if (_surahDrawerOpen) _reciterDrawerOpen = false;
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: pc.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: pc.withOpacity(0.3)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(widget.surah.nameArabic,
                    style: TextStyle(
                        color: pc,
                        fontSize: 13,
                        fontFamily: 'Uthmanic',
                        fontWeight: FontWeight.bold)),
                const SizedBox(width: 4),
                Icon(Icons.keyboard_arrow_down_rounded, color: pc, size: 14),
              ]),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _btn(Icons.stop_rounded, _stopPlay, 20),
              const SizedBox(width: 6),
              _btn(Icons.skip_previous_rounded, () {
                if (_currentAyahIdx > 0) _playAyah(_currentAyahIdx - 1);
              }, 22),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: _togglePlay,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: pc.withOpacity(0.2),
                    border: Border.all(color: pc.withOpacity(0.6), width: 1.5),
                  ),
                  child: Icon(
                      _isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: pc,
                      size: 26),
                ),
              ),
              const SizedBox(width: 6),
              _btn(Icons.skip_next_rounded, () {
                if (_currentAyahIdx < _ayahs.length - 1) {
                  _playAyah(_currentAyahIdx + 1);
                }
              }, 22),
            ]),
          ),
          GestureDetector(
            onTap: () => setState(() {
              _reciterDrawerOpen = !_reciterDrawerOpen;
              if (_reciterDrawerOpen) _surahDrawerOpen = false;
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: pc.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: pc.withOpacity(0.3)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.person_outline_rounded, color: pc, size: 12),
                const SizedBox(width: 4),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 70),
                  child: Text(
                    quranReciters[_selectedReciterIdx].nameArabic,
                    style: TextStyle(
                        color: pc, fontSize: 10, fontFamily: 'Uthmanic'),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _btn(IconData icon, VoidCallback onTap, double size) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(icon, color: widget.palette.secondary, size: size),
    );
  }
}

// ==================== ناوەرۆکی لاپەرە ====================

class _PageContent extends StatefulWidget {
  final List<Map<String, dynamic>> pageAyahs;
  final int pageIdx;
  final int currentAyahIdx;
  final bool isPlaying;
  final Color primaryColor;
  final ThemePalette palette;
  final void Function(int gi) onAyahTap;
  final void Function(double) onFontSizeChange;
  final double currentFontSize;
  final int Function(int pi, int li) globalIdx;
  final double availableHeight;
  final bool isFirstSurahPage;
  final int surahNumber;

  const _PageContent({
    required this.pageAyahs,
    required this.pageIdx,
    required this.currentAyahIdx,
    required this.isPlaying,
    required this.primaryColor,
    required this.palette,
    required this.onAyahTap,
    required this.onFontSizeChange,
    required this.currentFontSize,
    required this.globalIdx,
    required this.availableHeight,
    required this.isFirstSurahPage,
    required this.surahNumber,
  });

  @override
  State<_PageContent> createState() => _PageContentState();
}

class _PageContentState extends State<_PageContent> {
  final Map<int, GlobalKey> _ayahKeys = {};

  @override
  void didUpdateWidget(_PageContent old) {
    super.didUpdateWidget(old);
    if (widget.currentAyahIdx != old.currentAyahIdx &&
        widget.currentAyahIdx >= 0) {
      _scrollToActive();
    }
  }

  void _scrollToActive() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final li = _localIdxOfGlobal(widget.currentAyahIdx);
      if (li < 0) return;
      final ctx = _ayahKeys[li]?.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(ctx,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOut,
          alignment: 0.3);
    });
  }

  int _localIdxOfGlobal(int gi) {
    for (int li = 0; li < widget.pageAyahs.length; li++) {
      if (widget.globalIdx(widget.pageIdx, li) == gi) return li;
    }
    return -1;
  }

  String _toKurdishDigits(Object value) {
    const en = '0123456789';
    const ku = '٠١٢٣٤٥٦٧٨٩';
    return value.toString().split('').map((ch) {
      final idx = en.indexOf(ch);
      return idx >= 0 ? ku[idx] : ch;
    }).join();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bool isSmall = media.size.shortestSide < 360;

    // FIX ١: بسم الله دوپات نیە تەنها ناوەرۆست
    // و فۆنتی دینامیکی بۆ گونجاندن
    double ayahFontSize = widget.currentFontSize;
    const double ayahLineHeight = 2.0;
    final double badgeFontSize = isSmall ? 13.5 : 14.5;

    final bool showBasmala = widget.isFirstSurahPage &&
        widget.surahNumber != 9 &&
        widget.pageAyahs.isNotEmpty &&
        (widget.pageAyahs[0]['a'] as int) == 1;

    final List<InlineSpan> allSpans = [];

    for (int li = 0; li < widget.pageAyahs.length; li++) {
      final gi = widget.globalIdx(widget.pageIdx, li);
      final ayah = widget.pageAyahs[li];
      final int ayahNum = ayah['a'] as int;
      String text = (ayah['t'] as String)
          .replaceAll(RegExp(r'﴿[٠-٩0-9]+﴾'), '')
          .replaceAll('\uFEFF', '')
          .trim();

      // FIX ١: بسم الله لە ئایەتی یەکەمدا سڕ بکە
      // تەنها لە سورە ١ (فاتیحە) و سورە دیکەتر
      if (ayahNum == 1 && widget.surahNumber != 9) {
        text = text
            .replaceFirst(
              'بِسْمِ اللَّهِ الرَّحْمٰنِ الرَّحِيمِ',
              '',
            )
            .trim();
      }

      final bool isActive = widget.currentAyahIdx == gi;
      final bool isSajda = ayah['sajda'] == true;
      final String ayahNumKu = _toKurdishDigits(ayahNum);

      _ayahKeys[li] ??= GlobalKey();

      allSpans.add(
        TextSpan(
          text: text,
          style: TextStyle(
            fontSize: ayahFontSize,
            fontFamily: 'Uthmanic',
            color:
                isActive ? widget.palette.secondary : widget.palette.listText,
            fontWeight: FontWeight.normal,
            height: ayahLineHeight,
            letterSpacing: 0.0,
            wordSpacing: 0.0,
            background: isActive
                ? (Paint()
                  ..color = widget.palette.secondary.withOpacity(0.6)
                  ..style = PaintingStyle.fill)
                : null,
          ),
          recognizer: _TapRecognizer(() => widget.onAyahTap(gi)),
        ),
      );

      // FIX ١: نیشانە دیاریکراو (تەنیا یەک)
      allSpans.add(
        TextSpan(
          text: ' ﴿$ayahNumKu﴾ ',
          style: TextStyle(
            fontSize: badgeFontSize,
            fontFamily: 'Uthmanic',
            color: widget.palette.secondary.withOpacity(isActive ? 1.0 : 0.55),
            fontWeight: FontWeight.normal,
            height: ayahLineHeight,
          ),
        ),
      );

      if (isSajda) {
        allSpans.add(TextSpan(
          text: '۩ ',
          style: TextStyle(
              fontSize: 12,
              color: Colors.amber.withOpacity(0.8),
              height: ayahLineHeight),
        ));
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            isSmall ? 8 : 12,
            isSmall ? 6 : 8,
            isSmall ? 8 : 12,
            isSmall ? 6 : 8,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight - (isSmall ? 12 : 16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // FIX ١: بسم الله لەناوەرۆستدا (تەنها سورە ١ بۆ ٨ و ١٠)
                if (showBasmala)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14, top: 3),
                    child: Text(
                      'بِسْمِ اللَّهِ الرَّحْمٰنِ الرَّحِيمِ',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: ayahFontSize + 1,
                        fontFamily: 'Uthmanic',
                        color: widget.palette.secondary.withOpacity(0.7),
                        fontWeight: FontWeight.normal,
                        height: ayahLineHeight,
                      ),
                    ),
                  ),

                Text.rich(
                  TextSpan(children: allSpans),
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.justify,
                  strutStyle: StrutStyle(
                    fontFamily: 'Uthmanic',
                    height: ayahLineHeight,
                    fontSize: ayahFontSize,
                    leadingDistribution: TextLeadingDistribution.even,
                    forceStrutHeight: true,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TapRecognizer extends TapGestureRecognizer {
  _TapRecognizer(VoidCallback onTap) {
    this.onTap = onTap;
  }
}

// ==================== دراوەری سووراتەکان ====================

class _SurahDrawer extends StatelessWidget {
  final List<QuranSurah> surahs;
  final QuranSurah currentSurah;
  final Color primaryColor;
  final ThemePalette palette;
  final void Function(QuranSurah) onSelect;

  const _SurahDrawer({
    required this.surahs,
    required this.currentSurah,
    required this.primaryColor,
    required this.palette,
    required this.onSelect,
  });

  String _toKurdishDigits(Object value) {
    const en = '0123456789';
    const ku = '٠١٢٣٤٥٦٧٨٩';
    return value.toString().split('').map((ch) {
      final idx = en.indexOf(ch);
      return idx >= 0 ? ku[idx] : ch;
    }).join();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        margin: const EdgeInsets.only(bottom: 110),
        decoration: BoxDecoration(
          color: palette.drawerBg,
          border: Border(
            right: BorderSide(
              color: primaryColor.withOpacity(0.3),
              width: 1.5,
            ),
          ),
        ),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Text(
                  "سورەتەکان",
                  style: TextStyle(
                    color: primaryColor,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Divider(color: primaryColor.withOpacity(0.4), height: 1),
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: surahs.length,
                  itemBuilder: (_, i) {
                    final s = surahs[i];
                    final selected = s.number == currentSurah.number;
                    return GestureDetector(
                      onTap: () => onSelect(s),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 9),
                        decoration: BoxDecoration(
                          color: selected
                              ? primaryColor.withOpacity(0.15)
                              : Colors.transparent,
                          border: Border(
                            bottom: BorderSide(
                              color: primaryColor.withOpacity(0.07),
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 24,
                              child: Text(
                                _toKurdishDigits(s.number),
                                style: TextStyle(
                                  color: primaryColor.withOpacity(0.7),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s.nameArabic,
                                    style: TextStyle(
                                      color: selected
                                          ? primaryColor
                                          : palette.listText,
                                      fontSize: 13,
                                      fontFamily: 'Uthmanic',
                                      fontWeight: selected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                  Text(
                                    '${_toKurdishDigits(s.ayahCount)} ئایەت · ${s.isMakki ? "مەکی" : "مەدەنی"}',
                                    style: TextStyle(
                                      color: palette.listText.withOpacity(0.7),
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReciterDrawer extends StatefulWidget {
  final bool isOpen;
  final int selectedIdx;
  final Color primaryColor;
  final ThemePalette palette;
  final void Function(int) onSelect;

  const _ReciterDrawer({
    required this.isOpen,
    required this.selectedIdx,
    required this.primaryColor,
    required this.palette,
    required this.onSelect,
  });

  @override
  State<_ReciterDrawer> createState() => _ReciterDrawerState();
}

class _ReciterDrawerState extends State<_ReciterDrawer> {
  final Map<String, ReciterDlStatus> _st = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (widget.isOpen) _load();
  }

  @override
  void didUpdateWidget(covariant _ReciterDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOpen && !oldWidget.isOpen) _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    for (final r in quranReciters) {
      _st[r.key] = await QuranService.reciterDownloadStatus(r.key);
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        margin: const EdgeInsets.only(bottom: 110),
        decoration: BoxDecoration(
          color: widget.palette.drawerBg,
          border: Border(
              left: BorderSide(
                  color: widget.primaryColor.withOpacity(0.4), width: 1.5)),
        ),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Text("دەنگەکان",
                  style: TextStyle(
                      color: widget.primaryColor,
                      fontSize: 15,
                      fontWeight: FontWeight.bold)),
            ),
            Divider(color: widget.primaryColor.withOpacity(0.2), height: 1),
            if (_loading)
              const Expanded(
                  child:
                      Center(child: CircularProgressIndicator(strokeWidth: 2)))
            else
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: quranReciters.length,
                  itemBuilder: (_, i) {
                    final r = quranReciters[i];
                    final selected = i == widget.selectedIdx;
                    final st = _st[r.key] ?? ReciterDlStatus.none;
                    return GestureDetector(
                      onTap: () => widget.onSelect(i),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: selected
                              ? widget.primaryColor.withOpacity(0.15)
                              : Colors.transparent,
                          border: Border(
                              bottom: BorderSide(
                                  color:
                                      widget.primaryColor.withOpacity(0.07))),
                        ),
                        child: Row(children: [
                          Icon(
                            selected
                                ? Icons.radio_button_checked_rounded
                                : Icons.radio_button_unchecked_rounded,
                            color: selected
                                ? widget.primaryColor
                                : widget.palette.listText.withOpacity(0.4),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(r.nameArabic,
                                      style: TextStyle(
                                          color: selected
                                              ? widget.primaryColor
                                              : widget.palette.listText,
                                          fontSize: 13,
                                          fontFamily: 'Uthmanic')),
                                  const SizedBox(height: 2),
                                  Row(children: [
                                    if (st != ReciterDlStatus.none)
                                      _DownloadChip(
                                          status: st,
                                          primaryColor: widget.primaryColor,
                                          palette: widget.palette),
                                    if (st != ReciterDlStatus.none)
                                      const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(r.nameKurdish,
                                          style: TextStyle(
                                              color: widget.palette.listText
                                                  .withOpacity(0.7),
                                              fontSize: 10)),
                                    ),
                                  ]),
                                ]),
                          ),
                        ]),
                      ),
                    );
                  },
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

class _DownloadChip extends StatelessWidget {
  final ReciterDlStatus status;
  final Color primaryColor;
  final ThemePalette palette;

  const _DownloadChip({
    required this.status,
    required this.primaryColor,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    String t;
    Color c;
    switch (status) {
      case ReciterDlStatus.complete:
        t = 'تەواو';
        c = Colors.green.shade500;
        break;
      case ReciterDlStatus.partial:
        t = 'بەشێک';
        c = Colors.orange.shade600;
        break;
      case ReciterDlStatus.none:
        t = '';
        c = Colors.transparent;
    }
    if (t.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: c.withOpacity(0.2),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: c.withOpacity(0.6)),
      ),
      child: Text(t,
          style: TextStyle(color: c, fontSize: 8, fontWeight: FontWeight.w600)),
    );
  }
}
