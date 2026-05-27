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
  bool _barsVisible = false; // bars hidden by default, show on tap

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

    await _loadPage(1);
    if (mounted) setState(() => _isInitialized = true);

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
        backgroundColor: Color(0xFFF5F0E8),
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
      backgroundColor: const Color(0xFFF5F0E8),
      body: SafeArea(
        child: Stack(
          children: [
            // لاپەرەی قورئان — پڕ دەگرێت
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => setState(() => _barsVisible = !_barsVisible),
              child: _buildPageView(),
            ),
            // تولبارى سەرەوە

            // پلەیەری خوارەوە
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 200),
                offset: _barsVisible ? Offset.zero : const Offset(0, 1),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _barsVisible ? 1 : 0,
                  child: IgnorePointer(
                    ignoring: !_barsVisible,
                    // Fix 3: تاپ لەسەر پلەیەر ناشاردرێتەوە
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {},
                      child: _buildBottomBar(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageView() {
    return Stack(
      children: [
        PageView.builder(
          controller: _pageController,
          reverse: true, // RTL — right page = lower number
          onPageChanged: (index) {
            final newPage = index + 1;
            _loadPage(newPage).then((_) {
              if (!mounted) return;
              // یەکەم ئایەتی لاپەرەکە ئەکتێف بکە
              if (_pageWords.isNotEmpty) {
                final firstWord = _pageWords.first;
                // ئەگەر دەنگ لەکارە، یەکەم ئایەتی لاپەرەی نوێ بخوێنەرەوە
                if (_audio.isPlaying || _audio.isPaused) {
                  _audio.playAyah(firstWord.surah, firstWord.ayah);
                } else {
                  // تەنها سلێکت بکە بەبێ خوێندنەوە
                  setState(() {});
                }
              }
            });
          },
          itemCount: 604,
          itemBuilder: (context, index) {
            final page = index + 1;
            return _buildMushafPage(page);
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
              backgroundColor: Colors.transparent,
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
        color: const Color(0xFFF5F0E8),
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFF4A7C59)),
        ),
      );
    }

    final fontReady = _isPageFontReady(pageNumber);
    final fontName = _fontNameForPage(pageNumber);

    return Container(
      key: ValueKey('page_$pageNumber'),
      color: const Color(0xFFF5F0E8),
      child: Column(
        children: [
          // Page border header
          _buildPageHeader(pageNumber),
          // Page content
          Expanded(
            child:
                fontReady ? _buildPageLines(fontName) : _buildFontLoadingPage(),
          ),
          // Page border footer
          _buildPageFooter(pageNumber),
        ],
      ),
    );
  }

  Widget _buildPageHeader(int pageNumber) {
    final juzText = 'جزء ${_toKNum(_currentJuz)}';
    final placeText = _currentSurah?.isMakki == true ? 'مکی' : 'مدنی';
    final surahName = _currentSurah?.nameArabic ?? '';

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(6),
          topRight: Radius.circular(6),
        ),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF4A7C59),
            Color(0xFFB8D4A8),
          ],
        ),
      ),
      padding: const EdgeInsets.only(
        top: 0,
        left: 0,
        right: 0,
        bottom: 1,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFD4E8D4),
              Color(0xFFF5F0E8),
            ],
          ),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(5),
            topRight: Radius.circular(5),
          ),
        ),
        child: Row(
          children: [
            // لای چەپ فیزیکی: سەهمی گەرانەوە
            GestureDetector(
              onTap: () => Navigator.of(context).maybePop(),
              child: const Icon(
                Icons.arrow_back_ios,
                size: 14,
                color: Color(0xFF4A7C59),
              ),
            ),
            const SizedBox(width: 4),

            // ناوەراست: ناوی سورە + (مکی/مدنی)
            Expanded(
              child: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: surahName,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF4A7C59),
                        fontFamily: 'Notonaskh',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextSpan(
                      text: ' ($placeText)',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF4A7C59),
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
                  fontSize: 11,
                  color: Color(0xFF4A7C59),
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

  Widget _buildPageFooter(int pageNumber) {
    final pct = (_downloadedFonts / _totalFonts).clamp(0.0, 1.0);
    final pctKu = _toKNum((_downloadedFonts * 100 ~/ _totalFonts));

    return GestureDetector(
      onTap: () => setState(() => _barsVisible = !_barsVisible),
      child: Container(
        margin: const EdgeInsets.fromLTRB(8, 0, 8, 4),
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(6),
            bottomRight: Radius.circular(6),
          ),
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Color(0xFF4A7C59), Color(0xFFB8D4A8)],
          ),
        ),
        padding: const EdgeInsets.only(bottom: 0, left: 0, right: 0, top: 1),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Color(0xFFD4E8D4), Color(0xFFF5F0E8)],
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(5),
              bottomRight: Radius.circular(5),
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // ژمارەی لاپەرە لەناوەراست
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '— ${_toKNum(pageNumber)} —',
                    style:
                        const TextStyle(fontSize: 10, color: Color(0xFF4A7C59)),
                  ),
                  if (!_allFontsDone) ...[
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 3,
                        backgroundColor:
                            const Color(0xFF4A7C59).withOpacity(0.15),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF4A7C59)),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'دابەزاندنی لاپەڕەکانی قورئانی پیرۆز $pctKu٪',
                      style: TextStyle(
                        fontSize: 10,
                        color: const Color(0xFF4A7C59).withOpacity(0.8),
                      ),
                    ),
                    // ئایکۆنی tune لەگۆشەی چەپ
                    Align(
                      alignment: Alignment.centerRight,
                      child: Icon(
                        Icons.tune,
                        size: 14,
                        color: const Color(0xFF4A7C59).withOpacity(0.6),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
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
            style: const TextStyle(fontSize: 14),
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
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children:
              _pageLines.map((line) => _buildLine(line, fontName)).toList(),
        ),
      ),
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
    // هەوڵدان بۆ هێنان و پیشاندانی وشەکان بە جیا (بۆ ئەوەی هایلایت ببن یان ئاسۆیی بن)
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

    // --- لێرە کێشەکە چارەسەر دەکەین ---
    // ئەگەر وشەکان نەدۆزرانەوە، دەقە ئاساییەکە بنووسە نەک کۆدە یوونیکۆدەکە
    return const Center(
      child: Text(
        'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ', // نووسینی دەقەکە بە ئاسۆیی
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily:
              'Notonaskh', // لێرە فۆنتی Amiri یان Uthmanic بەکاربهێنە بۆ ڕوونی
          fontSize: 18, // کەمێک گەورەتری بکە چونکە ئاسۆییە
          color: Color(0xFF1A1A1A),
          height: 1.5, // بۆ ئەوەی تەشکیلەکان نەلکێن بە دێڕی سەرەوە
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
        (_audio.isPlaying || _audio.isPaused);

    // یەکەم ئایەتی لاپەرە بە زەرد دیاری بکە ئەگەر دەنگ لەکار نەبوو
    final isFirstAyah = _pageWords.isNotEmpty &&
        word.surah == _pageWords.first.surah &&
        word.ayah == _pageWords.first.ayah &&
        !_audio.isPlaying &&
        !_audio.isPaused;

    final Color textColor =
        isCurrentAyah ? const Color(0xFF2D5016) : const Color(0xFF1A1A1A);
    final Color? bgColor = isCurrentAyah
        ? const Color(0xFFFFD700).withOpacity(0.35)
        : isFirstAyah
            ? const Color(0xFFFFD700).withOpacity(0.15)
            : null;

    return Container(
      color: bgColor,
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Text(
        word.text,
        style: TextStyle(
          fontFamily: fontName,
          fontSize: 18,
          color: textColor,
          height: 1.7,
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
        // بارەی سەرەکی
        ClipPath(
          clipper: _WaveClipper(),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFF5F0E8), Color(0xFFD4E8D4)],
              ),
            ),
            padding:
                const EdgeInsets.only(left: 8, right: 8, bottom: 0, top: 16),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.person, color: Color(0xFF4A7C59)),
                  onPressed: _showReciterSheet,
                  tooltip: 'قورئانخوێن',
                  visualDensity: VisualDensity.compact,
                ),
                ListenableBuilder(
                  listenable: _audio,
                  builder: (context, _) {
                    final isActive = _audio.isPlaying || _audio.isPaused;
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                              _audio.isPlaying ? Icons.pause : Icons.play_arrow,
                              color: const Color(0xFF4A7C59)),
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            if (isActive) {
                              if (_audio.isPlaying) {
                                _audio.pause();
                              } else {
                                _audio.resume();
                              }
                            } else {
                              if (_pageWords.isNotEmpty) {
                                _audio.playAyah(
                                  _pageWords.first.surah,
                                  _pageWords.first.ayah,
                                );
                              }
                            }
                          },
                        ),
                        if (isActive)
                          IconButton(
                            icon: const Icon(Icons.stop,
                                color: Color(0xFF4A7C59)),
                            onPressed: _audio.stop,
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    );
                  },
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.list, color: Color(0xFF4A7C59)),
                  onPressed: _showSurahList,
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  icon: const Icon(Icons.open_in_new, color: Color(0xFF4A7C59)),
                  onPressed: _showPageJump,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        ),
        // ژمارەی لاپەرە ناو تاسەی شەپۆلەکە
        Positioned(
          top: 0,
          child: Container(
            width: 36,
            height: 20,
            alignment: Alignment.center,
            child: Text(
              _toKNum(_currentPage),
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF2D5016),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
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

  void _showPageJump() {
    final controller = TextEditingController(text: '$_currentPage');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('بڕۆ بۆ لاپەرە'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'ژمارەی لاپەرە (1-604)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('پاشگەزبوونەوە'),
          ),
          TextButton(
            onPressed: () {
              final page = int.tryParse(controller.text) ?? 1;
              Navigator.pop(ctx);
              _goToPage(page.clamp(1, 604));
            },
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
                    child: Text('قورئانخوێنان',
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
                              if (id != '953') ...[
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
