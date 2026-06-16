import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'quran_models.dart';
import 'quran_database_helper.dart';
import 'quran_audio_service.dart';
import 'quran_page_builder.dart';
import 'quran_navigation_sheets.dart';

class QuranScreen extends StatefulWidget {
  const QuranScreen({super.key});

  @override
  State<QuranScreen> createState() => _QuranScreenState();
}

class _QuranScreenState extends State<QuranScreen> {
  final QuranDatabaseHelper _db = QuranDatabaseHelper();
  final QuranAudioService _audio = QuranAudioService();

  // ─── State ────────────────────────────────────────────────────────────────

  bool _isInitialized = false;
  bool _isLoadingPage = false;
  bool _isSwiping = false;

  // Font management
  final Map<int, bool> _fontReady = {};
  final Set<int> _loadedFonts = {};
  final Map<int, double> _pageDownloadProgress = {};
  String? _fontsDir;
  static const int _totalFonts = 603;
  int _downloadedFonts = 0;
  bool _allFontsDone = false;

  // Page state
  int _currentPage = 1;
  int? _pendingPage;
  List<QuranPageLine> _pageLines = [];
  List<QuranWord> _pageWords = [];
  Map<int, QuranWord> _wordById = {};

  // Metadata
  List<SurahInfo> _allSurahs = [];
  int _currentJuz = 1;
  SurahInfo? _currentSurah;

  final PageController _pageController = PageController(initialPage: 0);

  // ─── Lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _init();
    _audio.addListener(_onAudioChanged);
  }

  @override
  void dispose() {
    _audio.removeListener(_onAudioChanged);
    _audio.stop();
    _pageController.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  // ─── Init ─────────────────────────────────────────────────────────────────

  Future<void> _init() async {
    await _db.initAll();
    await _audio.init();
    _allSurahs = await _db.getAllSurahs();

    final appDir = await getApplicationDocumentsDirectory();
    _fontsDir = '${appDir.path}/quran_fonts';
    await Directory(_fontsDir!).create(recursive: true);

    _fontReady[1] = true;
    await _checkFontsReady();
    _downloadedFonts = _fontReady.values.where((v) => v).length - 1;
    if (_downloadedFonts >= _totalFonts) _allFontsDone = true;

    final prefs = await SharedPreferences.getInstance();
    final savedPage = prefs.getInt('quran_last_page') ?? 1;

    // بارکردنی قاریئی پاشەکەوتکراو
    final savedReciterId = prefs.getString('quran_last_reciter');
    if (savedReciterId != null && savedReciterId != _audio.currentReciterId) {
      final reciterData = kAllReciters.firstWhere(
        (r) => r['id'] == savedReciterId,
        orElse: () => <String, String>{},
      );
      if (reciterData.isNotEmpty) {
        await _audio.switchReciter(savedReciterId, reciterData['file']!);
      }
    }

    await _loadPage(savedPage);

    if (mounted) {
      setState(() => _isInitialized = true);
      if (savedPage > 1) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _pageController.jumpToPage(savedPage - 1);
        });
      }
    }

    if (!_allFontsDone) _runFontQueue();
    WakelockPlus.enable();
  }

  // ─── Audio Listener ───────────────────────────────────────────────────────

  void _onAudioChanged() {
    if (!mounted || _isSwiping) return;
    final s = _audio.currentSurah;
    final a = _audio.currentAyah;
    if (s <= 0 || a <= 0) return;
    _db.getPageForAyah(s, a).then((page) {
      if (!mounted) return;
      if (page != _currentPage) {
        _pageController.animateToPage(
          page - 1,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      } else {
        setState(() {});
      }
    });
  }

  // ─── Font Management ──────────────────────────────────────────────────────

  Future<void> _checkFontsReady() async {
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

  bool _isPageFontReady(int page) =>
      page == 1 ? true : _fontReady[page] == true;

  String _fontNameForPage(int page) =>
      'QCFp${page.toString().padLeft(3, '0')}';

  Future<void> _downloadFontForPage(int page) async {
    if (page == 1 || _fontReady[page] == true) return;
    if (_pageDownloadProgress.containsKey(page)) return;

    final url = '$kFontBaseUrl/p$page.ttf';
    final outFile = File('$_fontsDir/p$page.ttf');

    try {
      final request = await HttpClient().getUrl(Uri.parse(url));
      final response = await request.close();
      final totalBytes = response.contentLength;
      int received = 0;

      if (mounted) setState(() => _pageDownloadProgress[page] = 0.0);

      final sink = outFile.openWrite();
      await for (final chunk in response) {
        sink.add(chunk);
        received += chunk.length;
        if (totalBytes > 0 && mounted) {
          setState(
              () => _pageDownloadProgress[page] = received / totalBytes);
        }
      }
      await sink.flush();
      await sink.close();

      if (mounted) {
        setState(() {
          _fontReady[page] = true;
          _pageDownloadProgress.remove(page);
        });
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

  void _prefetchFonts(int currentPage) {
    for (int p = currentPage; p <= (currentPage + 3).clamp(1, 604); p++) {
      if (_fontReady[p] != true) _downloadFontForPage(p);
    }
  }

  Future<bool> _loadFontForPage(int page) async {
    if (page == 1) return true;
    if (_loadedFonts.contains(page)) return true;
    if (_fontReady[page] != true) return false;

    final file = File('$_fontsDir/p$page.ttf');
    if (!await file.exists()) return false;

    try {
      final fontName = _fontNameForPage(page);
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

  // ─── Page Loading ─────────────────────────────────────────────────────────

  Future<void> _loadPage(int pageNumber) async {
    _pendingPage = pageNumber;
    if (_isLoadingPage) return;
    _isLoadingPage = true;

    while (_pendingPage != null) {
      final targetPage = _pendingPage!;
      _pendingPage = null;

      final lines = await _db.getLinesForPage(targetPage);
      final wordMap = <int, QuranWord>{};
      final allWords = <QuranWord>[];

      for (final line in lines) {
        if ((line.lineType == 'ayah' || line.lineType == 'basmallah') &&
            line.firstWordId != null &&
            line.lastWordId != null) {
          final words =
              await _db.getWordsRange(line.firstWordId!, line.lastWordId!);
          for (final w in words) {
            wordMap[w.id] = w;
          }
          allWords.addAll(words);
        }
      }

      final fontLoaded = await _loadFontForPage(targetPage);
      final juz = _db.getJuzForPage(targetPage);
      final surahNum = _db.getSurahForPage(targetPage);
      final surahInfo = _allSurahs.isNotEmpty && surahNum > 0
          ? _allSurahs.firstWhere(
              (s) => s.id == surahNum,
              orElse: () => _allSurahs.first,
            )
          : null;

      if (mounted) {
        setState(() {
          _currentPage = targetPage;
          _pageLines = lines;
          _pageWords = allWords;
          _wordById = wordMap;
          _currentJuz = juz;
          _currentSurah = surahInfo;
          if (fontLoaded) _fontReady[targetPage] = true;
          SharedPreferences.getInstance()
              .then((p) => p.setInt('quran_last_page', targetPage));
        });
      }
    }

    _isLoadingPage = false;
    _prefetchFonts(_currentPage);
  }

  void _goToPage(int page) {
    if (page < 1 || page > 604) return;
    _pageController.jumpToPage(page - 1);
  }

  // ─── Build ────────────────────────────────────────────────────────────────

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

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          _audio.stop();
          WakelockPlus.disable();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF006627),
        body: SafeArea(
          child: Stack(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.translucent,
                child: _buildPageView(),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: QuranBottomBar(
                  currentPage: _currentPage,
                  downloadedFonts: _downloadedFonts,
                  totalFonts: _totalFonts,
                  allFontsDone: _allFontsDone,
                  audio: _audio,
                  pageWords: _pageWords,
                  onShowSurahList: _showSurahList,
                  onShowJuzList: _showJuzList,
                  onShowPageJump: _showPageJump,
                  onShowReciterSheet: _showReciterSheet,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Page View ────────────────────────────────────────────────────────────

  Widget _buildPageView() {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        PageView.builder(
          controller: _pageController,
          reverse: true,
          onPageChanged: _onPageChanged,
          itemCount: kTotalPages,
          itemBuilder: (context, index) {
            final page = index + 1;
            return ColoredBox(
              color: const Color(0xFFFDF6E3),
              child: _buildMushafPage(page),
            );
          },
        ),
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

  Future<void> _onPageChanged(int index) async {
    final newPage = index + 1;
    final wasPlaying = _audio.isPlaying;
    final wasPaused = _audio.isPaused;

    _isSwiping = true;
    if (wasPlaying) await _audio.pause();

    await _loadPage(newPage);
    if (!mounted) return;

    final firstWord = _pageWords.isNotEmpty ? _pageWords.first : null;
    if (firstWord != null) {
      if (wasPlaying) {
        await _audio.playAyah(firstWord.surah, firstWord.ayah);
      } else {
        _audio.moveToAyah(firstWord.surah, firstWord.ayah);
        if (!wasPlaying && !wasPaused) setState(() {});
      }
    } else {
      setState(() {});
    }

    _isSwiping = false;
  }

  Widget _buildMushafPage(int pageNumber) {
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
          QuranPageHeader(
            pageNumber: pageNumber,
            juzNumber: _currentJuz,
            surahInfo: _currentSurah,
            onBack: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: fontReady
                ? MushafPageLines(
                    lines: _pageLines,
                    wordById: _wordById,
                    fontName: fontName,
                    audio: _audio,
                  )
                : FontLoadingPage(
                    downloadProgress: _pageDownloadProgress[_currentPage],
                    onRetry: () => _downloadFontForPage(_currentPage),
                  ),
          ),
        ],
      ),
    );
  }

  // ─── Navigation Delegates ─────────────────────────────────────────────────

  void _showSurahList() => showSurahListSheet(
        context: context,
        surahs: _allSurahs,
        currentSurah: _currentSurah,
        db: _db,
        audio: _audio,
        goToPage: _goToPage,
      );

  void _showJuzList() async {
    final juzList = await _db.getAllJuz();
    if (!mounted) return;
    showJuzListSheet(
      context: context,
      juzList: juzList,
      currentJuz: _currentJuz,
      db: _db,
      audio: _audio,
      goToPage: _goToPage,
    );
  }

  void _showPageJump() => showPageJumpDialog(
        context: context,
        currentPage: _currentPage,
        goToPage: _goToPage,
      );

  void _showReciterSheet() => showReciterSheet(
        context: context,
        audio: _audio,
      );
}
