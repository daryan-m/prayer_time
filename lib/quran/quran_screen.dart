// lib/quran/quran_screen.dart
// ═══════════════════════════════════════════════════════════════
//  بەبێ AppBar — لاپەرە پڕ شاشە
//  دوگمەی گەڕانەوە لەسەر لاپەرە (گۆشەی سەرەوەی چەپ)
//  ئۆتۆماتیک دانلۆدی فۆنتەکانی لاپەرەکان
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'quran_database_helper.dart';
import 'quran_models.dart';
import 'quran_audio_service.dart';
import 'quran_page_view.dart';

const _kBg = Color(0xFFEDE8D8);
const _kGold = Color(0xFFD4AF37);
const _kDefaultReciterAsset =
    'assets/quran/ayah-recitation-muhammad-siddiq-al-minshawi-murattal-hafs-959.json';

class QuranScreen extends StatefulWidget {
  final int? openSurah;
  final int? openAyah;
  const QuranScreen({super.key, this.openSurah, this.openAyah});

  @override
  State<QuranScreen> createState() => _QuranScreenState();
}

class _QuranScreenState extends State<QuranScreen> {
  late final PageController _pageCtrl;
  final _audio = QuranAudioService.instance;
  QuranDatabaseHelper get _db => QuranDatabaseHelper.instance;

  bool _initialized = false;
  final Map<int, SurahInfo?> _surahCache = {};

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
    _audio.addListener(_rebuild);
    _init();
  }

  Future<void> _init() async {
    _audio.init();
    // WordMap یەک جار بار دەکرێت
    await _db.buildWordMap();
    await _db.loadAudioCache(_kDefaultReciterAsset);

    int target = 1;
    if (widget.openSurah != null) {
      target = widget.openAyah != null
          ? await _db.getPageOfAyah(widget.openSurah!, widget.openAyah!) ??
              await _db.getSurahStartPage(widget.openSurah!)
          : await _db.getSurahStartPage(widget.openSurah!);
    }

    if (mounted) {
      setState(() => _initialized = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageCtrl.hasClients) _pageCtrl.jumpToPage(target - 1);
        _prefetch(target);
      });
    }
  }

  void _rebuild() => setState(() {});

  @override
  void dispose() {
    _audio.removeListener(_rebuild);
    _pageCtrl.dispose();
    super.dispose();
  }

  /// ئۆتۆماتیک دانلۆدی فۆنتەکانی لاپەرەی ئێستا و چەند لاپەرەی دواتر
  void _prefetch(int page) {
    for (int p = page; p <= (page + 3).clamp(1, 604); p++) {
      QuranFontCache.instance.ensureLoaded(p);
    }
  }

  Future<SurahInfo?> _fetchSurah(int page) async {
    if (_surahCache.containsKey(page)) return _surahCache[page];
    final glyphs = await _db.getGlyphsOfPage(page);
    if (glyphs.isEmpty) {
      _surahCache[page] = null;
      return null;
    }
    final info = kSurahList.firstWhere((s) => s.number == glyphs.first.surah,
        orElse: () => kSurahList.first);
    _surahCache[page] = info;
    return info;
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Color(0xFF111111),
      systemNavigationBarIconBrightness: Brightness.light,
    ));

    return Scaffold(
      backgroundColor: _kBg,
      extendBodyBehindAppBar: true,
      extendBody: true,
      body: !_initialized
          ? const _LoadingView()
          : SafeArea(
              bottom: false,
              child: Stack(children: [
                // ── PageView ────────────────────────────────
                PageView.builder(
                  controller: _pageCtrl,
                  itemCount: 604,
                  onPageChanged: (i) {
                    _fetchSurah(i + 1);
                    _fetchSurah(i + 2);
                    _prefetch(i + 1);
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
                ),

                // ── دوگمەی گەڕانەوە ─────────────────────────
                Positioned(
                  top: 6,
                  left: 6,
                  child: _BackBtn(onTap: () => Navigator.maybePop(context)),
                ),
              ]),
            ),
    );
  }

  int _juz(int page) => ((page - 1) ~/ 20) + 1;
}

// ── دوگمەی گەڕانەوە ─────────────────────────────────────────────

class _BackBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _BackBtn({required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xCC1C1C1C),
            shape: BoxShape.circle,
            border: Border.all(color: _kGold.withOpacity(0.5), width: 0.8),
          ),
          child: const Icon(Icons.arrow_back_ios_new_rounded,
              color: _kGold, size: 14),
        ),
      );
}

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
          Text('   ...',
              style: TextStyle(color: _kGold, fontSize: 14)),
        ],
      ));
}
