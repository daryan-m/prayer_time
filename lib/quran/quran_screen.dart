import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive_io.dart';
import 'package:http/http.dart' as http;
import 'quran_models.dart';
import 'quran_database_helper.dart';
import 'quran_audio_service.dart';

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

  // ─── هێلپەرەکان ─────────────────────────────────────────────────────────────

  static String toKurdishNum(int n) {
    const d = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return n.toString().split('').map((c) {
      final i = int.tryParse(c);
      return i != null ? d[i] : c;
    }).join();
  }

  static const List<String> _juzNames = [
    '',
    'الأول',
    'الثاني',
    'الثالث',
    'الرابع',
    'الخامس',
    'السادس',
    'السابع',
    'الثامن',
    'التاسع',
    'العاشر',
    'الحادي عشر',
    'الثاني عشر',
    'الثالث عشر',
    'الرابع عشر',
    'الخامس عشر',
    'السادس عشر',
    'السابع عشر',
    'الثامن عشر',
    'التاسع عشر',
    'العشرون',
    'الحادي والعشرون',
    'الثاني والعشرون',
    'الثالث والعشرون',
    'الرابع والعشرون',
    'الخامس والعشرون',
    'السادس والعشرون',
    'السابع والعشرون',
    'الثامن والعشرون',
    'التاسع والعشرون',
    'الثلاثون',
  ];

  static String juzArabicName(int juz) {
    if (juz < 1 || juz > 30) return 'جزء ${toKurdishNum(juz)}';
    return 'جزء ${_juzNames[juz]}';
  }

  bool _isInitialized = false;
  bool _isLoadingPage = false;
  bool _barsVisible = false; // bars hidden by default, show on tap

  // Font state
  final Map<int, bool> _fontReady = {}; // page -> font loaded
  final Set<int> _loadedFonts = {}; // pages whose font is loaded into engine
  final Map<int, double> _pageDownloadProgress =
      {}; // per-page download progress
  String? _fontsDir;

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

    // Setup fonts directory
    final appDir = await getApplicationDocumentsDirectory();
    _fontsDir = '${appDir.path}/quran_fonts';
    await Directory(_fontsDir!).create(recursive: true);

    // p1.ttf is always in assets — mark page 1 as ready
    _fontReady[1] = true;

    // Check if other fonts already downloaded
    await _checkFontsReady();

    await _loadPage(1);

    if (mounted) setState(() => _isInitialized = true);

    // Start downloading fonts — current page first, then background
    _prefetchFonts(1);
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
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 200),
                offset: _barsVisible ? Offset.zero : const Offset(0, -1),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _barsVisible ? 1 : 0,
                  child: IgnorePointer(
                    ignoring: !_barsVisible,
                    child: _buildTopBar(),
                  ),
                ),
              ),
            ),
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

  Widget _buildTopBar() {
    final surahName = _currentSurah?.nameArabic ?? '';
    final juzText = juzArabicName(_currentJuz);
    final placeText = _currentSurah?.isMakki == true ? 'مکی' : 'مدنی';

    return Container(
      color: const Color(0xFF2D5016),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      child: Row(
        children: [
          // چەپ: سەهمی گەرانەوە + ژمارەی لاپەرە
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).maybePop(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
              Text(
                placeText,
                style: const TextStyle(color: Colors.white60, fontSize: 14),
              ),
            ],
          ),
          // ناوەراست: ناوی سورە + (مکی/مدنی)
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  surahName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontFamily: 'quran-common',
                  ),
                ),
              ],
            ),
          ),
          // راست: جزء
          SizedBox(
            width: 72,
            child: Text(
              juzText,
              textAlign: TextAlign.justify,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageView() {
    return Stack(
      children: [
        PageView.builder(
          controller: _pageController,
          reverse: true, // RTL — right page = lower number
          onPageChanged: (index) => _loadPage(index + 1),
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
    final juzText = juzArabicName(_currentJuz);
    final placeText = _currentSurah?.isMakki == true ? 'مکی' : 'مدنی';
    final surahName = _currentSurah?.nameArabic ?? '';

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0xFF4A7C59), width: 2),
          left: BorderSide(color: Color(0xFF4A7C59), width: 2),
          right: BorderSide(color: Color(0xFF4A7C59), width: 2),
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(6),
          topRight: Radius.circular(6),
        ),
      ),
      child: Row(
        children: [
          // لای راست: سەهمی گەرانەوە
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: const Icon(
              Icons.arrow_back_ios,
              size: 14,
              color: Color(0xFF4A7C59),
            ),
          ),
          const SizedBox(width: 4),
          // جزء
          Text(
            juzText,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF4A7C59),
              fontWeight: FontWeight.bold,
            ),
            textDirection: TextDirection.rtl,
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
                      fontSize: 11,
                      color: Color(0xFF2D5016),
                      fontFamily: 'quran-common',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextSpan(
                    text: '  ($placeText)',
                    style: const TextStyle(
                      fontSize: 9,
                      color: Color(0xFF4A7C59),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // لای چەپ: فراغ بۆ توازن
          const SizedBox(width: 60),
        ],
      ),
    );
  }

  Widget _buildPageFooter(int pageNumber) {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFF4A7C59), width: 2),
          left: BorderSide(color: Color(0xFF4A7C59), width: 2),
          right: BorderSide(color: Color(0xFF4A7C59), width: 2),
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(6),
          bottomRight: Radius.circular(6),
        ),
      ),
      child: Center(
        child: Text(
          '— ${toKurdishNum(pageNumber)} —',
          style: const TextStyle(fontSize: 10, color: Color(0xFF4A7C59)),
        ),
      ),
    );
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
                ? 'فۆنت دادەبەزێت... ${((_pageDownloadProgress[_currentPage] ?? 0) * 100).toStringAsFixed(0)}%'
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
              'quran-common', // لێرە فۆنتی Amiri یان Uthmanic بەکاربهێنە بۆ ڕوونی
          fontSize: 20, // کەمێک گەورەتری بکە چونکە ئاسۆییە
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
    // هایلایت بە ئایەت — نەک وشە بە وشە
    final isCurrentAyah = _audio.isCurrentAyah(word.surah, word.ayah) &&
        (_audio.isPlaying || _audio.isPaused);

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
          height: 1.8,
        ),
      ),
    );
  }

  // ─── Bottom Bar ─────────────────────────────────────────────────────────────

  Widget _buildBottomBar() {
    return Container(
      color: const Color(0xFF2D5016),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      child: Row(
        children: [
          // Reciter button
          IconButton(
            icon: const Icon(Icons.person, color: Colors.white70),
            onPressed: _showReciterSheet,
            tooltip: 'قورئانخوێن',
          ),
          // Play/Pause current ayah
          ListenableBuilder(
            listenable: _audio,
            builder: (context, _) {
              final isActive = _audio.isPlaying || _audio.isPaused;
              return Row(
                children: [
                  IconButton(
                    icon: Icon(
                      _audio.isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      if (isActive) {
                        if (_audio.isPlaying) {
                          _audio.pause();
                        } else {
                          _audio.resume();
                        }
                      } else {
                        // Play from first ayah on page — continuous always true
                        if (_pageWords.isNotEmpty) {
                          _audio.playAyah(
                            _pageWords.first.surah,
                            _pageWords.first.ayah,
                            continuous: true,
                          );
                        }
                      }
                    },
                  ),
                  if (isActive)
                    IconButton(
                      icon: const Icon(Icons.stop, color: Colors.white70),
                      onPressed: _audio.stop,
                    ),
                ],
              );
            },
          ),
          const Spacer(),
          // Surah list button
          IconButton(
            icon: const Icon(Icons.list, color: Colors.white70),
            onPressed: _showSurahList,
          ),
          // Page jump
          IconButton(
            icon: const Icon(Icons.open_in_new, color: Colors.white70),
            onPressed: _showPageJump,
          ),
        ],
      ),
    );
  }

  void _showSurahList() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFF5F0E8),
      builder: (ctx) => ListView.builder(
        itemCount: _allSurahs.length,
        itemBuilder: (ctx, i) {
          final surah = _allSurahs[i];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFF2D5016),
              child: Text(
                '${surah.id}',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
            title: Text(
              surah.nameArabic,
              style: const TextStyle(fontFamily: 'quran-common', fontSize: 18),
              textDirection: TextDirection.rtl,
            ),
            subtitle: Text(
              '${surah.isMakki ? "مکی" : "مدنی"} · ${surah.versesCount} ئایە',
              textDirection: TextDirection.rtl,
            ),
            onTap: () async {
              Navigator.pop(ctx);
              final page = await _db.getPageForAyah(surah.id, 1);
              _goToPage(page);
            },
          );
        },
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
      builder: (ctx) => DefaultTabController(
        length: 2,
        child: Container(
          height: MediaQuery.of(context).size.height * 0.65,
          decoration: const BoxDecoration(
            color: Color(0xFF1A2E14),
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                decoration: const BoxDecoration(
                  color: Color(0xFF2D5016),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'قورئانخوێنان',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(ctx),
                          child: const Icon(Icons.close,
                              color: Colors.white54, size: 20),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const TabBar(
                      indicatorColor: Colors.white,
                      indicatorWeight: 2,
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.white38,
                      labelStyle:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      tabs: [
                        Tab(icon: Icon(Icons.wifi, size: 16), text: 'ئۆنلاین'),
                        Tab(
                            icon: Icon(Icons.download_done, size: 16),
                            text: 'دانلۆدکراو'),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildOnlineTab(ctx),
                    _buildOfflineTab(ctx),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOnlineTab(BuildContext ctx) {
    return ListenableBuilder(
      listenable: _audio,
      builder: (context, _) {
        final currentId = _audio.currentReciterId;
        final isOnlineMode = _audio.mode == AudioMode.online;
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: kAllReciters.length,
          separatorBuilder: (_, __) => Divider(
              height: 1, color: Colors.white.withOpacity(0.07), indent: 56),
          itemBuilder: (context, i) {
            final reciter = kAllReciters[i];
            final id = reciter['id']!;
            final isBuiltIn = id == '953';
            final isSelected =
                currentId == id && (isBuiltIn ? true : isOnlineMode);
            return ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: CircleAvatar(
                radius: 18,
                backgroundColor: isSelected
                    ? const Color(0xFF4A7C59)
                    : Colors.white.withOpacity(0.08),
                child: Icon(
                  isBuiltIn ? Icons.star : Icons.wifi,
                  size: 16,
                  color: isSelected ? Colors.white : Colors.white38,
                ),
              ),
              title: Text(
                reciter['nameArabic']!,
                style: TextStyle(
                  color: isSelected ? const Color(0xFFB8D4A8) : Colors.white,
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                textDirection: TextDirection.rtl,
              ),
              trailing: isSelected
                  ? const Icon(Icons.radio_button_checked,
                      color: Color(0xFF8BC34A), size: 22)
                  : Icon(Icons.radio_button_unchecked,
                      color: Colors.white.withOpacity(0.25), size: 22),
              onTap: () {
                _audio.switchReciter(id, reciter['file']!,
                    forceOnline: !isBuiltIn);
                Navigator.pop(ctx);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildOfflineTab(BuildContext ctx) {
    return ListenableBuilder(
      listenable: _audio,
      builder: (context, _) {
        final currentId = _audio.currentReciterId;
        final isOfflineMode = _audio.mode == AudioMode.offline;
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: kAllReciters.length,
          separatorBuilder: (_, __) => Divider(
              height: 1, color: Colors.white.withOpacity(0.07), indent: 56),
          itemBuilder: (context, i) {
            final reciter = kAllReciters[i];
            final id = reciter['id']!;
            final isBuiltIn = id == '953';
            final isDownloaded =
                isBuiltIn || _audio.downloadedReciters.contains(id);
            final isSelected = currentId == id && isOfflineMode;
            final progress = _audio.downloadProgress[id];

            return ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: CircleAvatar(
                radius: 18,
                backgroundColor: isSelected
                    ? const Color(0xFF4A7C59)
                    : isDownloaded
                        ? Colors.white.withOpacity(0.12)
                        : Colors.white.withOpacity(0.05),
                child: Icon(
                  isBuiltIn
                      ? Icons.star
                      : isDownloaded
                          ? Icons.download_done
                          : Icons.download_outlined,
                  size: 16,
                  color: isSelected
                      ? Colors.white
                      : isDownloaded
                          ? const Color(0xFF8BC34A)
                          : Colors.white24,
                ),
              ),
              title: Text(
                reciter['nameArabic']!,
                style: TextStyle(
                  color: isSelected
                      ? const Color(0xFFB8D4A8)
                      : isDownloaded
                          ? Colors.white
                          : Colors.white38,
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                textDirection: TextDirection.rtl,
              ),
              // نیشانەی پڕبوونەوە — تەنها کاتی دابەزاندن
              subtitle: progress != null
                  ? Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 4,
                              backgroundColor: Colors.white12,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                  Color(0xFF8BC34A)),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${toKurdishNum((progress * 100).toInt())}٪',
                            style: const TextStyle(
                                color: Color(0xFF8BC34A), fontSize: 10),
                          ),
                        ],
                      ),
                    )
                  : null,
              trailing: progress != null
                  ? const SizedBox(width: 24)
                  : isSelected
                      ? const Icon(Icons.check_circle,
                          color: Color(0xFF8BC34A), size: 22)
                      : isDownloaded
                          ? isBuiltIn
                              ? null
                              : GestureDetector(
                                  onTap: () =>
                                      _audio.deleteDownloadedReciter(id),
                                  child: Icon(Icons.delete_outline,
                                      color: Colors.white.withOpacity(0.35),
                                      size: 18),
                                )
                          : GestureDetector(
                              onTap: () => _audio.downloadReciter(id),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                      color: const Color(0xFF4A7C59), width: 1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.download,
                                        color: Color(0xFF8BC34A), size: 13),
                                    SizedBox(width: 3),
                                    Text('داگرتن',
                                        style: TextStyle(
                                            color: Color(0xFF8BC34A),
                                            fontSize: 10)),
                                  ],
                                ),
                              ),
                            ),
              onTap: isDownloaded && progress == null
                  ? () {
                      _audio.switchReciter(id, reciter['file']!);
                      Navigator.pop(ctx);
                    }
                  : null,
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _audio.removeListener(_onAudioChanged);
    _pageController.dispose();
    super.dispose();
  }
}
