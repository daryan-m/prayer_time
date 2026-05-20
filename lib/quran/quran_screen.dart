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
    final juzText = 'جزء $_currentJuz';
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
                'لپ $_currentPage',
                style: const TextStyle(color: Colors.white60, fontSize: 11),
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
                    fontSize: 15,
                    fontFamily: 'quran-common',
                  ),
                ),
                Text(
                  placeText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white60, fontSize: 10),
                ),
              ],
            ),
          ),
          // راست: جزء
          SizedBox(
            width: 72,
            child: Text(
              juzText,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
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
    final juzText = 'جزء $_currentJuz';
    final placeText = _currentSurah?.isMakki == true ? 'مکی' : 'مدنی';
    final surahName = _currentSurah?.nameArabic ?? '';

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0xFF4A7C59), width: 1),
          left: BorderSide(color: Color(0xFF4A7C59), width: 1),
          right: BorderSide(color: Color(0xFF4A7C59), width: 1),
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(6),
          topRight: Radius.circular(6),
        ),
      ),
      child: Row(
        children: [
          // لای راست: جزء
          SizedBox(
            width: 70,
            child: Text(
              juzText,
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xFF4A7C59),
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
            ),
          ),
          // ناوەراست: ناوی سورە
          Expanded(
            child: Text(
              surahName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF2D5016),
                fontFamily: 'quran-common',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // لای چەپ: مکی/مدنی
          SizedBox(
            width: 70,
            child: Text(
              placeText,
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xFF4A7C59),
              ),
              textAlign: TextAlign.left,
            ),
          ),
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
          bottom: BorderSide(color: Color(0xFF4A7C59), width: 1),
          left: BorderSide(color: Color(0xFF4A7C59), width: 1),
          right: BorderSide(color: Color(0xFF4A7C59), width: 1),
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(6),
          bottomRight: Radius.circular(6),
        ),
      ),
      child: Center(
        child: Text(
          '— $pageNumber —',
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
                ? 'فۆنت دابەزدێت... ${((_pageDownloadProgress[_currentPage] ?? 0) * 100).toStringAsFixed(0)}%'
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
    // وشەکانی بسمەلە لە _wordById — هەمان ڕێگای ئایەت
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
    // fallback unicode
    return Center(
      child: Text(
        '\uFDFD',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: fontName,
          fontSize: 22,
          color: const Color(0xFF1A1A1A),
          height: 1.8,
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
      backgroundColor: const Color(0xFFF5F0E8),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          return Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'قورئانخوێنان',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: ListView(
                  children: kAllReciters.map((reciter) {
                    final id = reciter['id']!;
                    final isBuiltIn = id == '953';
                    final isDownloaded =
                        isBuiltIn || _audio.downloadedReciters.contains(id);
                    final isCurrent = _audio.currentReciterId == id;
                    final progress = _audio.downloadProgress[id];

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isCurrent
                            ? const Color(0xFF2D5016)
                            : const Color(0xFF4A7C59).withOpacity(0.3),
                        child: Text(
                          id.substring(0, 2),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 11),
                        ),
                      ),
                      title: Text(reciter['nameArabic']!,
                          textDirection: TextDirection.rtl),
                      subtitle: Text(reciter['name']!),
                      trailing: _buildReciterTrailing(
                        id: id,
                        isBuiltIn: isBuiltIn,
                        isDownloaded: isDownloaded,
                        isCurrent: isCurrent,
                        progress: progress,
                        setLocal: setLocal,
                        reciter: reciter,
                      ),
                      onTap: isDownloaded
                          ? () {
                              _audio.switchReciter(id, reciter['file']!);
                              Navigator.pop(ctx);
                            }
                          : null,
                    );
                  }).toList(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildReciterTrailing({
    required String id,
    required bool isBuiltIn,
    required bool isDownloaded,
    required bool isCurrent,
    required double? progress,
    required StateSetter setLocal,
    required Map<String, String> reciter,
  }) {
    if (isCurrent) {
      return const Icon(Icons.check_circle, color: Color(0xFF2D5016));
    }
    if (progress != null) {
      return SizedBox(
        width: 40,
        height: 40,
        child: CircularProgressIndicator(
          value: progress,
          color: const Color(0xFF2D5016),
        ),
      );
    }
    if (isDownloaded) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.download_done, color: Color(0xFF4A7C59), size: 18),
          if (!isBuiltIn)
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              onPressed: () {
                _audio.deleteDownloadedReciter(id);
                setLocal(() {});
              },
            ),
        ],
      );
    }
    // Not downloaded
    return IconButton(
      icon: const Icon(Icons.download, color: Color(0xFF4A7C59)),
      onPressed: () {
        _audio.downloadReciter(id);
        setLocal(() {});
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
