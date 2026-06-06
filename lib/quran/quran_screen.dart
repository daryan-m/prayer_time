import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive_io.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'quran_models.dart';
import 'quran_database_helper.dart';
import 'quran_audio_service.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

// Font base URL — individual files on GitHub Pages
const String kFontBaseUrl = 'https://daryan-m.github.io/fonts';

class QuranScreen extends StatefulWidget {
  const QuranScreen({super.key});

  @override
  State<QuranScreen> createState() => _QuranScreenState();
}

class _QuranScreenState extends State<QuranScreen> {
  final QuranDatabaseHelper _db = QuranDatabaseHelper();
  final QuranAudioService _audio = QuranAudioService();

  bool _isInitialized = false;
  bool _isLoadingPage = false;

  // Font state
  final Map<int, bool> _fontReady = {};
  final Set<int> _loadedFonts = {};
  final Map<int, double> _pageDownloadProgress = {};
  String? _fontsDir;
  static const int _totalFonts = 603;
  int _downloadedFonts = 0;
  bool _allFontsDone = false;

  int _currentPage = 1;
  List<QuranPageLine> _pageLines = [];
  List<QuranWord> _pageWords = [];
  Map<int, QuranWord> _wordById = {};

  List<SurahInfo> _allSurahs = [];
  int _currentJuz = 1;
  SurahInfo? _currentSurah;

  final PageController _pageController = PageController(initialPage: 0);

  @override
  void initState() {
    super.initState();
    _init();
    // Fix 5: گوێگرتن لە گۆڕانکارییەکانی دەنگ بۆ گۆڕینی ئۆتۆماتیکی لاپەرە
    _audio.addListener(_onAudioChanged);
  }

  void _onAudioChanged() {
    if (!mounted) return;
    final s = _audio.currentSurah;
    final a = _audio.currentAyah;
    if (s <= 0 || a <= 0) return;
    // بزانە ئایەتەکە لە کام لاپەرەیەدایە
    _db.getPageForAyah(s, a).then((page) {
      if (!mounted) return;
      if (page != _currentPage) {
        _pageController.animateToPage(
          page - 1,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Future<void> _init() async {
    await _db.initAll();
    await _audio.init();
    _allSurahs = await _db.getAllSurahs();

    final appDir = await getApplicationDocumentsDirectory();
    _fontsDir = '${appDir.path}/quran_fonts';
    await Directory(_fontsDir!).create(recursive: true);

    _fontReady[1] = true;
    await _checkFontsReady();

    // حەساب بکە چەندێک پێشتر دابەزیوە
    _downloadedFonts = _fontReady.values.where((v) => v).length - 1;
    if (_downloadedFonts >= _totalFonts) _allFontsDone = true;

    final prefs = await SharedPreferences.getInstance();
    final savedPage = prefs.getInt('quran_last_page') ?? 1;
    await _loadPage(savedPage);
    if (mounted) {
      setState(() => _isInitialized = true);
      if (savedPage > 1) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _pageController.jumpToPage(savedPage - 1);
        });
      }
    }

    // هەموو فۆنتەکان لەپاشەکەوتدا دابەزێنە
    if (!_allFontsDone) _runFontQueue();
    WakelockPlus.enable();
  }

  Future<void> _runFontQueue() async {
    for (int p = 2; p <= 604; p++) {
      if (!mounted) return;
      if (_fontReady[p] == true) continue;
      await _downloadFontForPage(p);
      if (!mounted) return;
      setState(() {
        _downloadedFonts = _fontReady.values.where((v) => v).length - 1;
        if (_downloadedFonts >= _totalFonts) _allFontsDone = true;
      });
    }
  }

  // ─── Font Management ────────────────────────────────────────────────────────

  Future<void> _checkFontsReady() async {
    // Check all font files in parallel for speed
    final futures = <Future<MapEntry<int, bool>>>[];
    for (int page = 2; page <= 604; page++) {
      final p = page;
      futures.add(
        File('$_fontsDir/p$p.ttf').exists().then((e) => MapEntry(p, e)),
      );
    }
    final results = await Future.wait(futures);
    for (final entry in results) {
      _fontReady[entry.key] = entry.value;
    }
  }

  bool _isPageFontReady(int page) {
    if (page == 1) return true;
    return _fontReady[page] == true;
  }

  /// Download a single page font from GitHub Pages
  Future<void> _downloadFontForPage(int page) async {
    if (page == 1) return; // already in assets
    if (_fontReady[page] == true) return; // already downloaded
    if (_pageDownloadProgress.containsKey(page)) return; // already downloading

    final url = '$kFontBaseUrl/p$page.ttf';
    final outFile = File('$_fontsDir/p$page.ttf');

    try {
      final request = http.Request('GET', Uri.parse(url));
      final response = await http.Client().send(request);
      final totalBytes = response.contentLength ?? 0;
      int received = 0;

      if (mounted) setState(() => _pageDownloadProgress[page] = 0.0);

      final sink = outFile.openWrite();
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (totalBytes > 0 && mounted) {
          setState(() {
            _pageDownloadProgress[page] = received / totalBytes;
          });
        }
      }
      await sink.flush();
      await sink.close();

      if (mounted) {
        setState(() {
          _fontReady[page] = true;
          _pageDownloadProgress.remove(page);
        });
        // If this is the current page, reload it so font renders
        if (page == _currentPage) {
          _pendingPage = null;
          _isLoadingPage = false;
          await _loadPage(_currentPage);
        }
      }
    } catch (e) {
      try {
        await outFile.delete();
      } catch (_) {}
      if (mounted) setState(() => _pageDownloadProgress.remove(page));
      debugPrint('Font download error p$page: $e');
    }
  }

  /// Download fonts for current page + next 2 pages in background
  void _downloadAllFonts() {
    for (int p = 2; p <= 604; p++) {
      if (_fontReady[p] != true) {
        _downloadFontForPage(p);
      }
    }
  }

  /// Download current page font + prefetch nearby pages
  void _prefetchFonts(int currentPage) {
    for (int p = currentPage; p <= (currentPage + 3).clamp(1, 604); p++) {
      if (_fontReady[p] != true) {
        _downloadFontForPage(p);
      }
    }
  }

  Future<bool> _loadFontForPage(int page) async {
    if (page == 1) return true; // bundled in assets via pubspec
    if (_loadedFonts.contains(page)) return true; // already loaded
    if (_fontReady[page] != true) return false; // not downloaded yet

    final fontName = 'QCFp${page.toString().padLeft(3, '0')}';
    final file = File('$_fontsDir/p$page.ttf');
    if (!await file.exists()) return false;

    try {
      final loader = FontLoader(fontName);
      final bytes = await file.readAsBytes();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
      await loader.load();
      _loadedFonts.add(page);
      return true;
    } catch (e) {
      debugPrint('Font load error p$page: $e');
      return false;
    }
  }

  String _fontNameForPage(int page) {
    if (page == 1) return 'QCFp001'; // bundled p1.ttf
    return 'QCFp${page.toString().padLeft(3, '0')}';
  }

  // ─── Page Loading ───────────────────────────────────────────────────────────

  int? _pendingPage; // tracks the latest requested page

  Future<void> _loadPage(int pageNumber) async {
    _pendingPage = pageNumber;
    if (_isLoadingPage) {
      return; // debounce: will be triggered after current load
    }
    _isLoadingPage = true;

    while (_pendingPage != null) {
      final targetPage = _pendingPage!;
      _pendingPage = null;

      final lines = await _db.getLinesForPage(targetPage);

      final allWords = <QuranWord>[];
      final wordMap = <int, QuranWord>{};

      for (final line in lines) {
        if (line.lineType == 'ayah' || line.lineType == 'basmallah') {
          if (line.firstWordId != null && line.lastWordId != null) {
            final words =
                await _db.getWordsRange(line.firstWordId!, line.lastWordId!);
            for (final w in words) {
              wordMap[w.id] = w;
            }
            allWords.addAll(words);
          }
        }
      }

      // Load font — if not ready yet, page will show loading state
      final fontLoaded = await _loadFontForPage(targetPage);

      final juz = _db.getJuzForPage(targetPage);
      final surahNum = _db.getSurahForPage(targetPage);
      SurahInfo? surahInfo;
      if (_allSurahs.isNotEmpty && surahNum > 0) {
        surahInfo = _allSurahs.firstWhere(
          (s) => s.id == surahNum,
          orElse: () => _allSurahs.first,
        );
      }

      if (mounted) {
        setState(() {
          _currentPage = targetPage;
          SharedPreferences.getInstance()
              .then((p) => p.setInt('quran_last_page', targetPage));
          _pageLines = lines;
          _pageWords = allWords;
          _wordById = wordMap;
          _currentJuz = juz;
          _currentSurah = surahInfo;
          // If font was just loaded, mark it ready so UI renders
          if (fontLoaded) _fontReady[targetPage] = true;
        });
      }
    }

    _isLoadingPage = false;
    // Prefetch fonts for nearby pages
    _prefetchFonts(_currentPage);
  }

  void _goToPage(int page) {
    if (page < 1 || page > 604) return;
    _pageController.jumpToPage(page - 1);
  }

  // ─── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        backgroundColor: Color(0xFFFFFFFF),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFF4A7C59)),
              SizedBox(height: 16),
              Text('قورئانى پیرۆز...', style: TextStyle(fontSize: 16)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF006627),
      body: SafeArea(
        child: Stack(
          children: [
            // لاپەرەی قورئان — پڕ دەگرێت
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              child: _buildPageView(),
            ),
            // تولبارى سەرەوە

            // پلەیەری خوارەوە
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildBottomBar(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageView() {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        PageView.builder(
          controller: _pageController,
          reverse: true,
          onPageChanged: (index) {
            final newPage = index + 1;
            _loadPage(newPage).then((_) {
              if (!mounted) return;
              if (_pageWords.isNotEmpty) {
                final firstWord = _pageWords.first;
                if (_audio.isPlaying || _audio.isPaused) {
                  _audio.playAyah(firstWord.surah, firstWord.ayah);
                } else {
                  setState(() {});
                }
              }
            });
          },
          itemCount: 604,
          itemBuilder: (context, index) {
            final page = index + 1;
            return ColoredBox(
              color: const Color(0xFFFDF6E3),
              child: _buildMushafPage(page),
            );
          },
        ),
        // Per-page font download progress bar (top of page)
        if (_pageDownloadProgress.containsKey(_currentPage))
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(
              value: _pageDownloadProgress[_currentPage],
              backgroundColor: const Color(0xFFFDF6E3),
              color: const Color(0xFF4A7C59),
              minHeight: 3,
            ),
          ),
      ],
    );
  }

  Widget _buildMushafPage(int pageNumber) {
    // Show placeholder while this page's data is loading
    if (pageNumber != _currentPage) {
      return Container(
        key: ValueKey('placeholder_$pageNumber'),
        color: const Color(0xFFFDF6E3),
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFF4A7C59)),
        ),
      );
    }

    final fontReady = _isPageFontReady(pageNumber);
    final fontName = _fontNameForPage(pageNumber);

    return Container(
      key: ValueKey('page_$pageNumber'),
      color: const Color(0xFFFDF6E3),
      child: Column(
        children: [
          // Page border header
          _buildPageHeader(pageNumber),
          // Page content
          Expanded(
            child:
                fontReady ? _buildPageLines(fontName) : _buildFontLoadingPage(),
          ),
        ],
      ),
    );
  }

  Widget _buildPageHeader(int pageNumber) {
    final juzText = 'جزء ${_toKNum(_currentJuz)}';
    final placeText = _currentSurah?.isMakki == true ? 'مکی' : 'مدنی';
    final surahName = _currentSurah?.nameArabic ?? '';

    return Container(
      margin: const EdgeInsets.only(top: 0),
      padding: const EdgeInsets.only(
        top: 0,
        left: 0,
        right: 0,
        bottom: 1,
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFDF6E3),
              Color(0xFFC2E4C2),
            ],
          ),
          border: Border.all(color: const Color(0xFF4A7C59), width: 2),
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
        ),
        padding: const EdgeInsets.only(left: 4, right: 4, bottom: 4, top: 6),
        child: Row(
          children: [
            // لای چەپ فیزیکی: سەهمی گەرانەوە
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: GestureDetector(
                onTap: () => Navigator.of(context).maybePop(),
                child: const Icon(
                  Icons.arrow_back_ios,
                  size: 16,
                  color: Color(0xFF215B33),
                ),
              ),
            ),

            // ناوەراست: ناوی سورە + (مکی/مدنی)
            Expanded(
              child: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: surahName,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF215B33),
                        fontFamily: 'Notonaskh',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextSpan(
                      text: ' ($placeText)',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF215B33),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // لای راست فیزیکی: فراغ بۆ توازن
            SizedBox(
              width: 60,
              child: Text(
                juzText,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF215B33),
                  fontFamily: 'Notonaskh',
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _toKNum(int n) {
    const d = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return n.toString().split('').map((c) {
      final i = int.tryParse(c);
      return i != null ? d[i] : c;
    }).join();
  }

  Widget _buildFontLoadingPage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Color(0xFF4A7C59)),
          const SizedBox(height: 12),
          Text(
            _pageDownloadProgress.containsKey(_currentPage)
                ? 'فۆنت دادەبەزێت... ${_toKNum(((_pageDownloadProgress[_currentPage] ?? 0) * 100).toInt())}٪'
                : 'فۆنت بەردەست نییە',
            style: const TextStyle(fontSize: 12),
          ),
          if (!_pageDownloadProgress.containsKey(_currentPage))
            TextButton(
              onPressed: () => _downloadFontForPage(_currentPage),
              child: const Text('دابەزاندن'),
            ),
        ],
      ),
    );
  }

  Widget _buildPageLines(String fontName) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isLandscape = constraints.maxWidth > constraints.maxHeight;
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: const EdgeInsets.only(
              left: 16,
              right: 16,
              top: 3,
              bottom: 76,
            ),
            child: isLandscape
                ? SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: _pageLines
                          .map((line) => _buildLine(line, fontName))
                          .toList(),
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _pageLines
                        .map((line) => _buildLine(line, fontName))
                        .toList(),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildLine(QuranPageLine line, String fontName) {
    switch (line.lineType) {
      case 'surah_name':
        return _buildSurahNameLine(line);
      case 'basmallah':
        return _buildBasmallahLine(line, fontName);
      case 'ayah':
        return _buildAyahLine(line, fontName);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildSurahNameLine(QuranPageLine line) {
    return const SizedBox.shrink();
  }

  Widget _buildBasmallahLine(QuranPageLine line, String fontName) {
    if (line.firstWordId != null && line.lastWordId != null) {
      final words = <QuranWord>[];
      for (int id = line.firstWordId!; id <= line.lastWordId!; id++) {
        final w = _wordById[id];
        if (w != null) words.add(w);
      }
      if (words.isNotEmpty) {
        return ListenableBuilder(
          listenable: _audio,
          builder: (context, _) => _buildWordLine(words, fontName, true),
        );
      }
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Image.asset(
          'assets/images/besmelah1.png',
          height: 55,
          fit: BoxFit.fitWidth,
        ),
      ),
    );
  }

  Widget _buildAyahLine(QuranPageLine line, String fontName) {
    if (line.firstWordId == null || line.lastWordId == null) {
      return const SizedBox(height: 24);
    }

    // Get words for this line
    final words = <QuranWord>[];
    for (int id = line.firstWordId!; id <= line.lastWordId!; id++) {
      final w = _wordById[id];
      if (w != null) words.add(w);
    }

    if (words.isEmpty) return const SizedBox(height: 24);

    return ListenableBuilder(
      listenable: _audio,
      builder: (context, _) {
        return _buildWordLine(words, fontName, line.isCentered);
      },
    );
  }

  Widget _buildWordLine(List<QuranWord> words, String fontName, bool centered) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (words.isNotEmpty) {
          _audio.togglePlayPause(words.first.surah, words.first.ayah);
        }
      },
      child: SizedBox(
        width: double.infinity,
        child: Wrap(
          textDirection: TextDirection.rtl,
          alignment: WrapAlignment.center,
          runAlignment: WrapAlignment.center,
          children: words.map((word) => _buildWord(word, fontName)).toList(),
        ),
      ),
    );
  }

  Widget _buildWord(QuranWord word, String fontName) {
    final isCurrentAyah = _audio.isCurrentAyah(word.surah, word.ayah) &&
        (_audio.isPlaying ||
            _audio.isPaused ||
            _audio.state == AudioState.loading);

    // یەکەم ئایەتی لاپەرە بە زەرد دیاری بکە ئەگەر دەنگ لەکار نەبوو
    final Color textColor =
        isCurrentAyah ? const Color(0xFF2D5016) : const Color(0xFF1A1A1A);
    final Color? bgColor =
        isCurrentAyah ? const Color(0xFFFFD700).withOpacity(0.35) : null;

    return Container(
      color: bgColor,
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Text(
        word.text,
        style: TextStyle(
          fontFamily: fontName,
          fontSize: 18,
          color: textColor,
          height: 1.6,
        ),
      ),
    );
  }

  // ─── Bottom Bar ─────────────────────────────────────────────────────────────

  Widget _buildBottomBar() {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        if (!_allFontsDone)
          Positioned(
            top: 28,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  child: LinearProgressIndicator(
                    value: (_downloadedFonts / _totalFonts).clamp(0.0, 1.0),
                    minHeight: 3,
                    backgroundColor: const Color(0xFF4A7C59).withOpacity(0.15),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF4A7C59),
                    ),
                  ),
                ),
                Container(
                  color: const Color(0xFF4A7C59).withOpacity(0.08),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    'دابەزاندنی لاپەڕەکانی قورئانی پیرۆز ${_toKNum((_downloadedFonts * 100 ~/ _totalFonts))}٪',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      color: const Color(0xFF4A7C59).withOpacity(0.9),
                    ),
                  ),
                ),
              ],
            ),
          ),

        // ── بوتومبار ──
        Container(
          margin: const EdgeInsets.only(top: 32),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFFDF6E3),
                Color(0xFFC2E4C2),
              ],
            ),
            border: Border.all(color: const Color(0xFF4A7C59), width: 2),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
          ),
          padding: const EdgeInsets.only(left: 4, right: 4, bottom: 4, top: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // ── لای چەپ ──
              _buildBarButton(
                icon: Icons.person_outline,
                label: 'قاریء',
                onTap: _showReciterSheet,
                isCenter: false,
              ),
              _buildDivider(),
              _buildBarButton(
                icon: Icons.menu_book_outlined,
                label: 'السورة',
                onTap: _showSurahList,
                isCenter: false,
              ),
              _buildDivider(),

              // ── ناوەڕاست: پلەیەر ──
              ListenableBuilder(
                listenable: _audio,
                builder: (context, _) {
                  final isPlaying = _audio.isPlaying;
                  final isPaused = _audio.isPaused;
                  final isLoading = _audio.state == AudioState.loading;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ئایەتی پێشوو
                      _buildSmallButton(
                        icon: Icons.skip_previous,
                        onTap: () => _audio.playPreviousAyah(),
                      ),
                      const SizedBox(width: 4),
                      // play/pause
                      _buildBarButton(
                        icon: (isPlaying || isLoading)
                            ? Icons.pause
                            : Icons.play_arrow,
                        label: '',
                        onTap: () {
                          if (isPlaying) {
                            _audio.pause();
                          } else if (isPaused) {
                            _audio.resume();
                          } else if (isLoading) {
                            // loading دا کلیک کرا — چاوەڕێ بکە
                          } else {
                            if (_pageWords.isNotEmpty) {
                              _audio.playAyah(
                                _pageWords.first.surah,
                                _pageWords.first.ayah,
                              );
                            }
                          }
                        },
                        isCenter: true,
                      ),
                      const SizedBox(width: 4),
                      // stop
                      _buildBarButton(
                        icon: Icons.stop,
                        label: '',
                        onTap: _audio.stop,
                        isCenter: true,
                      ),
                      const SizedBox(width: 4),
                      // ئایەتی دواتر
                      _buildSmallButton(
                        icon: Icons.skip_next,
                        onTap: () => _audio.playNextAyah(),
                      ),
                    ],
                  );
                },
              ),
              _buildDivider(),

              // ── لای راست ──
              _buildBarButton(
                icon: Icons.layers_outlined,
                label: 'جزء',
                onTap: _showJuzList,
                isCenter: false,
              ),
              _buildDivider(),
              _buildBarButton(
                icon: Icons.open_in_new,
                label: 'الصفحة',
                onTap: _showPageJump,
                isCenter: false,
              ),
            ],
          ),
        ),

        // ── هێڵی سپی لەژێر بازنەکە ──
        Positioned(
          top: 28,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              width: 38,
              height: 6,
              color: const Color(0xFFFDF6E3),
            ),
          ),
        ),

        // ── بازنەی نیمچەگۆ لەسەر لێواری سەرەوە ──
        Positioned(
          bottom: 48,
          child: ClipRect(
            child: Align(
              alignment: Alignment.topCenter,
              heightFactor: 0.5, // ← تەنها نیوەی خوارەوە دەرکەوێت
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFFFDF6E3),
                      Color(0xFFC2E4C2),
                    ],
                  ),
                  border: Border.all(color: const Color(0xFF4A7C59), width: 2),
                ),
                alignment: Alignment.center,
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _toKNum(_currentPage),
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF2D5016),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSmallButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(
        icon,
        color: const Color(0xFF4A7C59),
        size: 20,
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 30,
      width: 1,
      color: const Color(0xFF4A7C59).withOpacity(0.4),
    );
  }

  Widget _buildBarButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isCenter,
  }) {
    if (isCenter) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36, // ← گەورەتر
          height: 36, // ← گەورەتر
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFF2B922B),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF4A7C59), size: 16),
          if (label.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF4A7C59),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showSurahList() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Color(0xFF1A2E14),
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              decoration: const BoxDecoration(
                color: Color(0xFF2D5016),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('سورەکان',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: const Icon(Icons.close,
                        color: Colors.white54, size: 20),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: _allSurahs.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  color: Colors.white.withOpacity(0.08),
                  indent: 56,
                ),
                itemBuilder: (ctx, i) {
                  final surah = _allSurahs[i];
                  final isCurrent = _currentSurah?.id == surah.id;
                  return ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: isCurrent
                          ? const Color(0xFF4A7C59)
                          : Colors.white.withOpacity(0.1),
                      child: Text(
                        _toKNum(surah.id),
                        style: TextStyle(
                          color: isCurrent ? Colors.white : Colors.white60,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      surah.nameArabic,
                      style: TextStyle(
                        fontFamily: 'Notonaskh',
                        fontSize: 16,
                        color:
                            isCurrent ? const Color(0xFFB8D4A8) : Colors.white,
                        fontWeight:
                            isCurrent ? FontWeight.bold : FontWeight.normal,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                    subtitle: Text(
                      '${surah.isMakki ? "مکی" : "مدنی"} / ${_toKNum(surah.versesCount)} ئایە',
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.45),
                        fontSize: 11,
                      ),
                    ),
                    trailing: isCurrent
                        ? const Icon(Icons.bookmark,
                            color: Color(0xFF8BC34A), size: 18)
                        : null,
                    onTap: () async {
                      Navigator.pop(ctx);
                      final page = await _db.getPageForAyah(surah.id, 1);
                      _goToPage(page);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showJuzList() async {
    final juzList = await _db.getAllJuz();
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Color(0xFF1A2E14),
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              decoration: const BoxDecoration(
                color: Color(0xFF2D5016),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('جزء',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: const Icon(Icons.close,
                        color: Colors.white54, size: 20),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: juzList.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  color: Colors.white.withOpacity(0.08),
                  indent: 56,
                ),
                itemBuilder: (ctx, i) {
                  final juz = juzList[i];
                  final isCurrent = _currentJuz == juz.juzNumber;
                  return ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: isCurrent
                          ? const Color(0xFF4A7C59)
                          : Colors.white.withOpacity(0.1),
                      child: Text(
                        _toKNum(juz.juzNumber),
                        style: TextStyle(
                          color: isCurrent ? Colors.white : Colors.white60,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      'جزء ${_toKNum(juz.juzNumber)}',
                      style: TextStyle(
                        fontSize: 15,
                        color:
                            isCurrent ? const Color(0xFFB8D4A8) : Colors.white,
                        fontWeight:
                            isCurrent ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(
                      'دەستپێک: ${juz.firstVerseKey}',
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.45),
                        fontSize: 11,
                      ),
                    ),
                    trailing: isCurrent
                        ? const Icon(Icons.bookmark,
                            color: Color(0xFF8BC34A), size: 18)
                        : null,
                    onTap: () async {
                      Navigator.pop(ctx);
                      final parts = juz.firstVerseKey.split(':');
                      final page = await _db.getPageForAyah(
                        int.parse(parts[0]),
                        int.parse(parts[1]),
                      );
                      _goToPage(page);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSearchSheet() {
    final controller = TextEditingController();
    List<Map<String, dynamic>> results = [];
    bool searched = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Color(0xFF1A2E14),
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              // هێدەر
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                decoration: const BoxDecoration(
                  color: Color(0xFF2D5016),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text('گەڕان لە ئایەتەکانى قورئانى پیرۆز',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: const Icon(Icons.close,
                          color: Colors.white54, size: 20),
                    ),
                  ],
                ),
              ),
              // سێرچ باکس
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: controller,
                  autofocus: true,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  decoration: InputDecoration(
                    hintText: 'وشەیەک بنووسە...',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.08),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(Icons.search, color: Colors.white54),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.arrow_forward,
                          color: Color(0xFF4A7C59)),
                      onPressed: () async {
                        if (controller.text.trim().isEmpty) return;
                        final r = await _db.searchAyahs(controller.text.trim());
                        setS(() {
                          results = r;
                          searched = true;
                        });
                      },
                    ),
                  ),
                  onSubmitted: (val) async {
                    if (val.trim().isEmpty) return;
                    final r = await _db.searchAyahs(val.trim());
                    setS(() {
                      results = r;
                      searched = true;
                    });
                  },
                ),
              ),
              // ئەنجامەکان
              Expanded(
                child: searched && results.isEmpty
                    ? Center(
                        child: Text('هیچ ئەنجامێک نەدۆزرایەوە',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.5))),
                      )
                    : ListView.separated(
                        itemCount: results.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color: Colors.white.withOpacity(0.08),
                          indent: 16,
                        ),
                        itemBuilder: (ctx, i) {
                          final r = results[i];
                          final surah = r['surah_number'] as int;
                          final ayah = r['ayah_number'] as int;
                          final text = r['text'] as String;
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            title: Text(
                              text,
                              textDirection: TextDirection.rtl,
                              style: const TextStyle(
                                fontFamily: 'Notonaskh',
                                color: Colors.white,
                                fontSize: 15,
                              ),
                            ),
                            subtitle: Text(
                              '${_allSurahs.firstWhere((s) => s.id == surah).nameArabic} — ئایە ${_toKNum(ayah)}',
                              textDirection: TextDirection.rtl,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.45),
                                fontSize: 11,
                              ),
                            ),
                            onTap: () async {
                              Navigator.pop(ctx);
                              final page =
                                  await _db.getPageForAyah(surah, ayah);
                              _goToPage(page);
                            },
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

  void _showPageJump() {
    final controller = TextEditingController(text: '$_currentPage');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF000000),
        title: const Text('بڕۆ بۆ لاپەرە'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'ژمارەی لاپەرە (1-604)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFFFFFFF),
            ),
            child: const Text('پاشگەزبوونەوە'),
          ),
          TextButton(
            onPressed: () {
              final page = int.tryParse(controller.text) ?? 1;
              Navigator.pop(ctx);
              _goToPage(page.clamp(1, 604));
            },
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFFFFFFF),
            ),
            child: const Text('بڕۆ'),
          ),
        ],
      ),
    );
  }

  void _showReciterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.65,
        decoration: const BoxDecoration(
          color: Color(0xFF1A2E14),
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              decoration: const BoxDecoration(
                color: Color(0xFF2D5016),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('دەنگەکان',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: const Icon(Icons.close,
                        color: Colors.white54, size: 20),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: _audio,
                builder: (context, _) => ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: kAllReciters.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: Colors.white.withOpacity(0.07),
                    indent: 60,
                  ),
                  itemBuilder: (context, i) {
                    final r = kAllReciters[i];
                    final id = r['id']!;
                    final isSelected = _audio.currentReciterId == id;
                    final isDl = _audio.downloadedReciters.contains(id);
                    final progress = _audio.downloadProgress[id];

                    return GestureDetector(
                        onTap: () {
                          Navigator.pop(ctx);
                          _audio.switchReciter(id, r['file']!);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          child: Row(
                            children: [
                              // بازنەی هەڵبژاردن
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF8BC34A)
                                        : Colors.white24,
                                    width: isSelected ? 2.5 : 1.5,
                                  ),
                                  color: isSelected
                                      ? const Color(0xFF4A7C59)
                                      : Colors.transparent,
                                ),
                                child: isSelected
                                    ? const Icon(Icons.check,
                                        color: Colors.white, size: 17)
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              // ناو + بار
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      r['nameArabic']!,
                                      style: TextStyle(
                                        color: isSelected
                                            ? const Color(0xFFB8D4A8)
                                            : Colors.white,
                                        fontSize: 14,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                      textDirection: TextDirection.rtl,
                                    ),
                                    const SizedBox(height: 5),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(3),
                                      child: LinearProgressIndicator(
                                        value: progress ?? (isDl ? 1.0 : 0.0),
                                        minHeight: 3,
                                        backgroundColor: Colors.white10,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          isDl && progress == null
                                              ? const Color(0xFF4A7C59)
                                              : const Color(0xFF8BC34A),
                                        ),
                                      ),
                                    ),
                                    if (progress != null) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        '${_toKNum((progress * 100).toInt())}٪ دادەبەزێت',
                                        style: const TextStyle(
                                            color: Color(0xFF8BC34A),
                                            fontSize: 10),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              // دوگمەی دابەزاندن / سڕینەوە
                              if (id != '') ...[
                                if (progress != null)
                                  GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () =>
                                        _audio.deleteDownloadedReciter(id),
                                    child: const Icon(Icons.close,
                                        color: Colors.white38, size: 18),
                                  )
                                else if (isDl)
                                  GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () =>
                                        _audio.deleteDownloadedReciter(id),
                                    child: Icon(Icons.delete_outline,
                                        color: Colors.white.withOpacity(0.3),
                                        size: 18),
                                  )
                                else
                                  GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () {
                                      _audio.downloadReciter(id);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 9, vertical: 4),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                            color: const Color(0xFF4A7C59)),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.download,
                                              color: Color(0xFF8BC34A),
                                              size: 13),
                                          SizedBox(width: 3),
                                          Text('دابەزێنە',
                                              style: TextStyle(
                                                  color: Color(0xFF8BC34A),
                                                  fontSize: 10)),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ],
                          ),
                        ));
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _audio.removeListener(_onAudioChanged);
    _pageController.dispose();
    super.dispose();
    WakelockPlus.disable();
  }
}

class _WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    const waveHeight = 16.0;
    const waveWidth = 60.0;
    final centerX = size.width / 2;

    path.moveTo(0, waveHeight);
    path.lineTo(centerX - waveWidth / 2, waveHeight);
    path.quadraticBezierTo(
      centerX,
      -waveHeight * 0.6,
      centerX + waveWidth / 2,
      waveHeight,
    );
    path.lineTo(size.width, waveHeight);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(_WaveClipper old) => false;
}

class _WaveBorderPainter extends CustomPainter {
  final Color color;
  _WaveBorderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    const waveHeight = 16.0;
    const waveWidth = 60.0;
    final centerX = size.width / 2;

    final path = Path();
    path.moveTo(0, waveHeight);
    path.lineTo(centerX - waveWidth / 2, waveHeight);
    path.quadraticBezierTo(
      centerX,
      -waveHeight * 0.6,
      centerX + waveWidth / 2,
      waveHeight,
    );
    path.lineTo(size.width, waveHeight);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_WaveBorderPainter old) => false;
}
