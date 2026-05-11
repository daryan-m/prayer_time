// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// quran_screen.dart
//
// سکرینی سەرەکی ئەپی قورئانی پیرۆز
// هەماهەنگکاری: داتابەیس + دەنگ + UI
//
// پاکێجی زیادە (pubspec.yaml):
//   sqflite: ^2.3.0
//   path: ^1.9.0
//   path_provider: ^2.1.2
//   just_audio: ^0.9.37
//   http: ^1.2.1
//   shared_preferences: ^2.2.2
//
// assets (pubspec.yaml):
//   assets:
//     - assets/db/quran.db           ← tanzil SQLite
//     - assets/translation/ku_bamoki.txt ← وەرگێڕانی کوردی
//     - assets/fonts/Uthmanic-Regular.ttf
//     - assets/fonts/Uthmanic-Bold.ttf
//
// سەرچاوەی داتا:
//   دەق: https://tanzil.net/pub/download/index.php?type=uthmani&format=sqlite
//   وەرگێڕان: https://tanzil.net/trans/ku.bamoki
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'quran_audio_service.dart';
import 'quran_database_helper.dart';
import 'quran_models.dart';
import 'quran_page_view.dart';

// ──────────────────────────────────────────
// سکرینی سەرەکی
// ──────────────────────────────────────────

class QuranScreen extends StatefulWidget {
  const QuranScreen({super.key});

  @override
  State<QuranScreen> createState() => _QuranScreenState();
}

class _QuranScreenState extends State<QuranScreen>
    with SingleTickerProviderStateMixin {
  // ─── سێرڤیسەکان
  final _db = QuranDatabaseHelper();
  final _audio = QuranAudioService();

  // ─── داتا
  List<Surah> _surahs = [];
  Surah? _currentSurah;
  List<Ayah> _currentAyahs = [];
  AudioState _audioState = const AudioState();

  // ─── دۆخ
  bool _isLoading = true;
  int _currentPage = 1;

  // ─── تاب کنترۆلەر
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _init();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _audio.dispose();
    _db.close();
    super.dispose();
  }

  // ════════════════════════════════════════
  // دەستپێکردن
  // ════════════════════════════════════════

  Future<void> _init() async {
    await _audio.init();

    // گوێگرتن لە دۆخی دەنگ
    _audio.stateStream.listen((state) {
      if (mounted) setState(() => _audioState = state);
    });

    // بارکردنی سورەکان
    await _loadSurahs();

    // بارکردنی دۆخی دواوە
    final savedState = await _db.loadReadingState();
    final savedReciterId = await _db.loadSelectedReciterId();

    // دانانی قاریئ
    final reciter = Reciter.defaults.firstWhere(
      (r) => r.id == savedReciterId,
      orElse: () => Reciter.defaults.first,
    );
    _audio.setReciter(reciter);

    // ئیمپۆرتی وەرگێڕانی کوردی (تەنها یەکجار)
    await _db.importKurdishTranslation();

    // کردنەوەی سورەی دواوە
    if (_surahs.isNotEmpty) {
      final surah = _surahs.firstWhere(
        (s) => s.id == savedState.surahId,
        orElse: () => _surahs.first,
      );
      await _openSurah(surah,
          ayahNumber: savedState.ayahNumber, saveState: false);
    }

    if (mounted) setState(() => _isLoading = false);
  }

  // ════════════════════════════════════════
  // بارکردنی داتا
  // ════════════════════════════════════════

  Future<void> _loadSurahs() async {
    try {
      final list = await _db.getAllSurahs();
      if (mounted) {
        setState(() {
          _surahs = list.isNotEmpty
              ? list
              : QuranDatabaseHelper.fallbackSurahs.map(Surah.fromMap).toList();
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _surahs =
              QuranDatabaseHelper.fallbackSurahs.map(Surah.fromMap).toList();
        });
      }
    }
  }

  Future<void> _openSurah(Surah surah,
      {int ayahNumber = 1, bool saveState = true}) async {
    setState(() => _isLoading = true);

    try {
      final ayahs = await _db.getAyahsOfSurah(surah.id);

      if (mounted) {
        setState(() {
          _currentSurah = surah;
          _currentAyahs = ayahs;
          _currentPage = surah.pageStart;
          _isLoading = false;
        });

        if (saveState) {
          await _db.saveReadingState(QuranReadingState(
            surahId: surah.id,
            ayahNumber: ayahNumber,
            page: surah.pageStart,
          ));
        }

        // بڕۆ بۆ تابی خوێندن
        _tabController.animateTo(1);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ════════════════════════════════════════
  // کنترۆلی دەنگ
  // ════════════════════════════════════════

  Future<void> _onAyahTap(Ayah ayah) async {
    if (_currentSurah == null) return;

    if (_audioState.currentSurahId == _currentSurah!.id &&
        _audioState.currentAyahNumber == ayah.numberInSurah) {
      // ئەگەر هەمان ئایەت بوو: play/pause
      await _audio.togglePlayPause();
    } else {
      // ئایەتی نوێ
      await _audio.playOfflineOrOnline(
        _currentSurah!.id,
        ayah.numberInSurah,
        totalAyahs: _currentSurah!.versesCount,
      );
    }
  }

  // ════════════════════════════════════════
  // هەڵبژاردنی قاریئ
  // ════════════════════════════════════════

  void _showReciterBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ReciterSheet(
        currentReciterId: _audioState.reciter?.id ?? 'ar.alafasy',
        onSelected: (reciter) async {
          _audio.setReciter(reciter);
          await _db.saveSelectedReciterId(reciter.id);
          if (mounted) setState(() {});
        },
      ),
    );
  }

  // ════════════════════════════════════════
  // build
  // ════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Color(0xFF1B4332),
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFFDF6E3),
        appBar: _buildAppBar(),
        body: Column(
          children: [
            // تابەکان
            _buildTabBar(),

            // ناوەرۆک
            Expanded(
              child: _isLoading
                  ? const _LoadingIndicator()
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        // تابی لیستی سورەکان
                        _SurahListTab(
                          surahs: _surahs,
                          currentSurahId: _currentSurah?.id,
                          onSurahTap: _openSurah,
                        ),

                        // تابی خوێندن
                        _currentSurah == null
                            ? const _EmptyReadingView()
                            : QuranPageView(
                                ayahs: _currentAyahs,
                                surah: _currentSurah!,
                                audioState: _audioState,
                                onAyahTap: _onAyahTap,
                                onSwipeLeft: () {
                                  // لاپەرەی داهاتوو — سورەی داهاتوو
                                  final idx = _surahs.indexWhere(
                                      (s) => s.id == _currentSurah!.id);
                                  if (idx < _surahs.length - 1) {
                                    _openSurah(_surahs[idx + 1]);
                                  }
                                },
                                onSwipeRight: () {
                                  final idx = _surahs.indexWhere(
                                      (s) => s.id == _currentSurah!.id);
                                  if (idx > 0) {
                                    _openSurah(_surahs[idx - 1]);
                                  }
                                },
                              ),
                      ],
                    ),
            ),

            // بارەی دەنگ
            QuranAudioBar(
              audioState: _audioState,
              currentSurah: _currentSurah,
              onPlayPause: _audio.togglePlayPause,
              onNext: _audio.nextAyah,
              onPrev: _audio.prevAyah,
              onStop: _audio.stop,
              onReciterTap: _showReciterBottomSheet,
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF1B4332),
      elevation: 0,
      centerTitle: true,
      title: const Text(
        'قورئانی پیرۆز',
        style: TextStyle(
          color: Color(0xFFD4A853),
          fontFamily: 'Uthmanic',
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
      actions: [
        // گەڕان
        IconButton(
          icon: const Icon(Icons.search, color: Color(0xFFD4A853)),
          onPressed: () => _showSearchSheet(),
        ),
        // قاریئ
        IconButton(
          icon: const Icon(Icons.record_voice_over_outlined,
              color: Color(0xFFD4A853)),
          onPressed: _showReciterBottomSheet,
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: const Color(0xFF1B4332),
      child: TabBar(
        controller: _tabController,
        indicatorColor: const Color(0xFFD4A853),
        labelColor: const Color(0xFFD4A853),
        unselectedLabelColor: Colors.white38,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        tabs: const [
          Tab(text: 'لیستی سورەکان'),
          Tab(text: 'خوێندنەوە'),
        ],
      ),
    );
  }

  // ════════════════════════════════════════
  // bottom sheet ی گەڕان
  // ════════════════════════════════════════

  void _showSearchSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SearchSheet(
        onAyahSelected: (ayah) async {
          // کردنەوەی سورەی ئایەت
          final surah = _surahs.firstWhere(
            (s) => s.id == ayah.surahId,
            orElse: () => _surahs.first,
          );
          await _openSurah(surah, ayahNumber: ayah.numberInSurah);
        },
        db: _db,
      ),
    );
  }
}

// ──────────────────────────────────────────
// لیستی سورەکان
// ──────────────────────────────────────────

class _SurahListTab extends StatelessWidget {
  final List<Surah> surahs;
  final int? currentSurahId;
  final void Function(Surah) onSurahTap;

  const _SurahListTab({
    required this.surahs,
    required this.currentSurahId,
    required this.onSurahTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: surahs.length,
      separatorBuilder: (_, __) => const Divider(
          height: 1, indent: 72, endIndent: 16, color: Color(0xFFE8D9A0)),
      itemBuilder: (context, index) {
        final surah = surahs[index];
        final isCurrent = surah.id == currentSurahId;

        return ListTile(
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCurrent
                  ? const Color(0xFF1B4332)
                  : const Color(0xFF1B4332).withOpacity(0.08),
            ),
            child: Center(
              child: Text(
                '${surah.id}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isCurrent
                      ? const Color(0xFFD4A853)
                      : const Color(0xFF1B4332),
                ),
              ),
            ),
          ),
          title: Text(
            surah.nameArabic,
            style: const TextStyle(
              fontFamily: 'Uthmanic',
              fontSize: 18,
              color: Color(0xFF1A1A1A),
            ),
            textDirection: TextDirection.rtl,
          ),
          subtitle: Text(
            '${surah.displayName}  •  ${surah.versesCount} ئایەت  •  ${surah.isMakki ? 'مەکی' : 'مەدەنی'}',
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
          trailing: isCurrent
              ? const Icon(Icons.menu_book, color: Color(0xFF1B4332), size: 20)
              : null,
          onTap: () => onSurahTap(surah),
        );
      },
    );
  }
}

// ──────────────────────────────────────────
// bottom sheet ی قاریئ
// ──────────────────────────────────────────

class _ReciterSheet extends StatelessWidget {
  final String currentReciterId;
  final void Function(Reciter) onSelected;

  const _ReciterSheet({
    required this.currentReciterId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1B4332),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFD4A853).withOpacity(0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Text(
            'هەڵبژاردنی قاریئ',
            style: TextStyle(
              color: Color(0xFFD4A853),
              fontFamily: 'Uthmanic',
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...Reciter.defaults.map((reciter) {
            final isSelected = reciter.id == currentReciterId;
            return ListTile(
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? const Color(0xFFD4A853)
                      : Colors.white.withOpacity(0.08),
                ),
                child: Icon(
                  isSelected ? Icons.check : Icons.mic_none_outlined,
                  color: isSelected ? Colors.white : Colors.white38,
                  size: 18,
                ),
              ),
              title: Text(
                reciter.nameArabic,
                style: TextStyle(
                  color: isSelected ? const Color(0xFFD4A853) : Colors.white,
                  fontFamily: 'Uthmanic',
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                textDirection: TextDirection.rtl,
              ),
              subtitle: Text(
                '${reciter.style}  •  ${reciter.bitrate}kbps',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
              onTap: () {
                onSelected(reciter);
                Navigator.pop(context);
              },
            );
          }),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────
// bottom sheet ی گەڕان
// ──────────────────────────────────────────

class _SearchSheet extends StatefulWidget {
  final void Function(Ayah) onAyahSelected;
  final QuranDatabaseHelper db;

  const _SearchSheet({required this.onAyahSelected, required this.db});

  @override
  State<_SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends State<_SearchSheet> {
  List<Ayah> _results = [];
  bool _isSearching = false;
  bool _searchKurdish = true;

  Future<void> _search(String query) async {
    if (query.length < 2) {
      setState(() => _results = []);
      return;
    }
    setState(() => _isSearching = true);
    final results =
        await widget.db.searchAyahs(query, inKurdish: _searchKurdish);
    if (mounted) {
      setState(() {
        _results = results;
        _isSearching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFFDF6E3),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // بارەی گەڕان
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF1B4332),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4A853).withOpacity(0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  TextField(
                    autofocus: true,
                    onChanged: _search,
                    style: const TextStyle(color: Colors.white),
                    textDirection: TextDirection.rtl,
                    decoration: InputDecoration(
                      hintText: _searchKurdish
                          ? 'گەڕان بە کوردی...'
                          : 'گەڕان بە عەرەبی...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      prefixIcon:
                          const Icon(Icons.search, color: Color(0xFFD4A853)),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.08),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: TextButton(
                        onPressed: () =>
                            setState(() => _searchKurdish = !_searchKurdish),
                        child: Text(
                          _searchKurdish ? 'ع' : 'ک',
                          style: const TextStyle(
                              color: Color(0xFFD4A853),
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ئەنجامەکان
            Expanded(
              child: _isSearching
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: Color(0xFF1B4332)))
                  : _results.isEmpty
                      ? const Center(
                          child: Text('ئەنجامێک نەدۆزرایەوە',
                              style: TextStyle(color: Colors.grey)))
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: _results.length,
                          itemBuilder: (_, i) {
                            final ayah = _results[i];
                            return ListTile(
                              title: Text(
                                ayah.textUthmani,
                                style: const TextStyle(
                                  fontFamily: 'Uthmanic',
                                  fontSize: 16,
                                ),
                                textDirection: TextDirection.rtl,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                'سورە ${ayah.surahId}  •  ئایەتی ${ayah.numberInSurah}',
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.grey),
                              ),
                              trailing: const Icon(Icons.arrow_forward_ios,
                                  size: 14, color: Colors.grey),
                              onTap: () {
                                Navigator.pop(context);
                                widget.onAyahSelected(ayah);
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
}

// ──────────────────────────────────────────
// ویجێتە یارمەتیدەرەکان
// ──────────────────────────────────────────

class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(Color(0xFF1B4332)),
            strokeWidth: 2,
          ),
          SizedBox(height: 12),
          Text('بارکردن...',
              style: TextStyle(color: Color(0xFF1B4332), fontSize: 14)),
        ],
      ),
    );
  }
}

class _EmptyReadingView extends StatelessWidget {
  const _EmptyReadingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.menu_book_outlined,
              size: 64, color: const Color(0xFF1B4332).withOpacity(0.3)),
          const SizedBox(height: 16),
          const Text(
            'سورەیەک هەڵبژێرە',
            style: TextStyle(
              color: Color(0xFF1B4332),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
