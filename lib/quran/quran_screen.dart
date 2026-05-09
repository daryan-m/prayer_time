// ═══════════════════════════════════════════════════════════════
//  lib/quran/quran_screen.dart
// ═══════════════════════════════════════════════════════════════
//
//  گۆڕانکاریەکان:
//  ✦ SafeArea + MediaQuery → ناوچەی سیستەم (notch، statusBar،
//      navigationBar) هەموو شاشەکان دەگرێتەوە
//  ✦ لاپەرە تا لێواری مۆبایل دەچێت (edge-to-edge)
//  ✦ AppBar ناتووتە — تەنها نازک و ساکار
//  ✦ بارەی دەنگ ئەنئێستا لە ناو overlay دەکرێت (لە quran_page_view)
//      بۆئەوە هیچ بارێکی جیاواز لە quran_screen نییە
//  ✦ _getSurahInfoForPage لە داتابەیس دەخوێنێت بە cache
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'quran_database_helper.dart';
import 'quran_models.dart';
import 'quran_audio_service.dart';
import 'quran_page_view.dart';

// ─────────────────────────────────────────────────────────────
//  ڕەنگەکان
// ─────────────────────────────────────────────────────────────
const _kBg = Color(0xFFEDE8D8); // پاشبەرزی بیرونی
const _kBarBg = Color(0xFF1C1C1C);
const _kGold = Color(0xFFD4AF37);
const _kTextDim = Color(0xFF888888);

const _kDefaultReciterAsset =
    'assets/quran/ayah-recitation-muhammad-siddiq-al-minshawi-murattal-hafs-959.json';

// ═══════════════════════════════════════════════════════════════

class QuranScreen extends StatefulWidget {
  final int? openSurah;
  final int? openAyah;
  const QuranScreen({super.key, this.openSurah, this.openAyah});

  @override
  State<QuranScreen> createState() => _QuranScreenState();
}

// ═══════════════════════════════════════════════════════════════

class _QuranScreenState extends State<QuranScreen> {
  late final PageController _pageController;
  final _audio = QuranAudioService.instance;
  final _db = QuranDatabaseHelper.instance;

  int _currentPage = 1;
  bool _initialized = false;
  ViewMode _viewMode = ViewMode.page;

  // cache: page → SurahInfo
  final Map<int, SurahInfo?> _surahCache = {};

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _audio.addListener(_onAudio);
    _init();
  }

  Future<void> _init() async {
    _audio.init();
    await _db.loadAudioCache(_kDefaultReciterAsset);

    int target = 1;
    if (widget.openSurah != null) {
      target = widget.openAyah != null
          ? await _db.getPageOfAyah(widget.openSurah!, widget.openAyah!) ??
              await _db.getSurahStartPage(widget.openSurah!)
          : await _db.getSurahStartPage(widget.openSurah!);
    }

    if (mounted) {
      setState(() {
        _currentPage = target;
        _initialized = true;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageController.hasClients) {
          _pageController.jumpToPage(target - 1);
        }
      });
    }
  }

  void _onAudio() => setState(() {});

  @override
  void dispose() {
    _audio.removeListener(_onAudio);
    _pageController.dispose();
    super.dispose();
  }

  // ── cache بارکردنی سورەی لاپەرەیەک ──────────────────────────

  Future<SurahInfo?> _fetchSurah(int page) async {
    if (_surahCache.containsKey(page)) return _surahCache[page];
    final glyphs = await _db.getGlyphsOfPage(page);
    if (glyphs.isEmpty) {
      _surahCache[page] = null;
      return null;
    }
    final info = kSurahList.firstWhere(
      (s) => s.number == glyphs.first.surah,
      orElse: () => kSurahList.first,
    );
    _surahCache[page] = info;
    return info;
  }

  // ─────────────────────────────────────────────────────────────
  //  Build
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // StatusBar سپی لەسەر پاشبەرزی روون
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Color(0xFF1C1C1C),
      systemNavigationBarIconBrightness: Brightness.light,
    ));

    final mq = MediaQuery.of(context);
    final topPad = mq.padding.top; // statusBar + notch
    final bottomPad = mq.padding.bottom; // navigationBar / homeIndicator

    return Scaffold(
      backgroundColor: _kBg,
      // Scaffold.body تا ئەدگیکان دەچێت — SafeArea ئێمە بەخۆمان بەڕێوە دەبەین
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: _buildAppBar(topPad),
      body: !_initialized
          ? const _LoadingView()
          : Column(
              children: [
                // فاصلەی سەرەوە (statusBar + AppBar)
                SizedBox(height: topPad + kToolbarHeight),
                // ناوەڕۆکی سەرەکی
                Expanded(
                  child: _viewMode == ViewMode.page
                      ? _buildPageView(bottomPad)
                      : _buildAyahView(bottomPad),
                ),
                // فاصلەی خوارەوە (navigationBar)
                SizedBox(height: bottomPad),
              ],
            ),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(double topPad) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: Container(
        color: _kBarBg,
        padding: EdgeInsets.only(top: topPad),
        child: SizedBox(
          height: kToolbarHeight,
          child: Row(
            children: [
              // دوگمەی گەڕانەوە
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: _kGold, size: 18),
                onPressed: () => Navigator.maybePop(context),
                splashRadius: 20,
              ),

              // ناوی سورە
              Expanded(
                child: FutureBuilder<SurahInfo?>(
                  future: _fetchSurah(_currentPage),
                  builder: (_, snap) => Text(
                    snap.data?.name ?? 'قورئانی کەریم',
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(
                      fontFamily: 'me_quran_volt_newmet',
                      color: _kGold,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              // مۆدی نیشاندان
              IconButton(
                icon: Icon(
                  _viewMode == ViewMode.page
                      ? Icons.view_list_rounded
                      : Icons.menu_book_rounded,
                  color: _kGold,
                  size: 20,
                ),
                onPressed: () => setState(() {
                  _viewMode = _viewMode == ViewMode.page
                      ? ViewMode.ayahByAyah
                      : ViewMode.page;
                }),
                splashRadius: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── PageView ──────────────────────────────────────────────────

  Widget _buildPageView(double bottomPad) {
    return PageView.builder(
      controller: _pageController,
      itemCount: 604,
      // لاپەرەکان بەشێوەی عمودی پڕ دەکاتەوە
      scrollDirection: Axis.horizontal,
      onPageChanged: (i) {
        setState(() => _currentPage = i + 1);
        _fetchSurah(i + 1); // pre-cache
        _fetchSurah(i + 2);
      },
      itemBuilder: (ctx, idx) {
        final page = idx + 1;
        return FutureBuilder<SurahInfo?>(
          future: _fetchSurah(page),
          builder: (_, snap) {
            final surah = snap.data ?? _surahCache[page];
            return QuranPageView(
              pageNumber: page,
              surahNumber: surah?.number ?? 1,
              surahName: surah?.name ?? '',
              isMakki: surah?.isMakki ?? true,
              juzNumber: _juz(page),
              activeVerseKey: _audio.currentVerseKey,
              activeWordIndex: _audio.activeWordIndex,
              onAyahTap: (g) => _audio.playAyah(g.surah, g.ayah),
            );
          },
        );
      },
    );
  }

  // ── AyahByAyah ────────────────────────────────────────────────

  Widget _buildAyahView(double bottomPad) {
    return FutureBuilder<SurahInfo?>(
      future: _fetchSurah(_currentPage),
      builder: (ctx, snap) {
        final surah = snap.data;
        if (surah == null) {
          return const Center(
            child: CircularProgressIndicator(color: _kGold, strokeWidth: 1.5),
          );
        }
        return FutureBuilder(
          future: Future.wait([
            _db.getGlyphsOfSurah(surah.number),
            _db.getAyahsOfSurah(surah.number),
          ]),
          builder: (_, snap2) {
            if (!snap2.hasData) {
              return const Center(
                child:
                    CircularProgressIndicator(color: _kGold, strokeWidth: 1.5),
              );
            }
            return AyahByAyahView(
              surahNumber: surah.number,
              glyphs: snap2.data![0] as List<QuranGlyph>,
              ayahs: snap2.data![1] as List<QuranAyah>,
              activeVerseKey: _audio.currentVerseKey,
              activeWordIndex: _audio.activeWordIndex,
              onAyahTap: (g) => _audio.playAyah(g.surah, g.ayah),
            );
          },
        );
      },
    );
  }

  // ── یارمەتیدەر ────────────────────────────────────────────────

  int _juz(int page) => ((page - 1) ~/ 20) + 1;
}

// ═══════════════════════════════════════════════════════════════

enum ViewMode { page, ayahByAyah }

// ═══════════════════════════════════════════════════════════════
//  _LoadingView
// ═══════════════════════════════════════════════════════════════

class _LoadingView extends StatelessWidget {
  const _LoadingView();
  @override
  Widget build(BuildContext context) => const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: _kGold, strokeWidth: 1.5),
            SizedBox(height: 14),
            Text('قورئان دەبارێت...',
                style: TextStyle(color: _kGold, fontSize: 14)),
          ],
        ),
      );
}
