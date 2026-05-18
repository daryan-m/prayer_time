// ============================================================
//  quran_screen.dart
//
//  بەرپرسێتییەکان (UI تەنها):
//    • PageView بۆ ١-٣ asset + ٤-٦٠٤ دانلۆد PNG
//    • TopBar: مکی/مدنی — ناوی سورە — جوزء
//    • هایلایتی ئایەت: bounds لە QPC DB
//    • AudioBar: پلەیەر لەخوارەوە
//    • بۆکسی دانلۆد: progress گلۆبال، جوڵە نابێت
//    • پاشبزمی سپی
//
//  assets:
//    assets/quran/page001.png  ...  page003.png
//    assets/quran/qpc-v2-15-lines.db
//    assets/quran/qpc-v2-ayah-by-ayah-glyphs.db
//
//  pubspec:
//    sqflite, path, path_provider, http
// ============================================================

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'quran_audio_service.dart';
import 'quran_database_helper.dart';
import 'quran_models.dart';

// ── ثابتەکان ─────────────────────────────────────────────

const int _kLocalMax = 3;
const int _kTotalPages = 604;
const int _kLines = 15; // دێر بە لاپەرە
const String _kDlBase = 'https://archive.org/download/ALQURANPERPAGEFORMATPNG/';
const String _kLinesAsset = 'assets/quran/qpc-v2-15-lines.db';
const String _kGlyphsAsset = 'assets/quran/qpc-v2-ayah-by-ayah-glyphs.db';

// جوزء — لاپەرەی دەستپێکی هەر جوزئێک (دڵنیابووە لە DB)
const List<int> _kJuzStart = [
  1,
  22,
  42,
  62,
  82,
  102,
  122,
  142,
  162,
  182,
  202,
  222,
  242,
  262,
  282,
  302,
  322,
  342,
  362,
  382,
  402,
  422,
  442,
  462,
  482,
  502,
  522,
  542,
  562,
  582,
];

int _juzOf(int page) {
  for (int i = _kJuzStart.length - 1; i >= 0; i--) {
    if (_kJuzStart[i] <= page) return i + 1;
  }
  return 1;
}

// ── Fallback سورە ────────────────────────────────────────

const _kFallbackSurah = Surah(
  id: 1,
  nameArabic: 'الفاتحة',
  nameSimple: 'Al-Fatihah',
  nameKurdish: 'فاتیحە',
  versesCount: 7,
  revelationPlace: 'makkah',
  pageStart: 1,
  juzStart: 1,
);

// ============================================================
//  _AyahBound  —  ناوچەی ئایەتێک لە لاپەرە
//  y1/y2 normalized 0.0–1.0
// ============================================================

class _AyahBound {
  final int surah;
  final int ayah;
  final double y1;
  final double y2;

  const _AyahBound({
    required this.surah,
    required this.ayah,
    required this.y1,
    required this.y2,
  });

  bool contains(double ny) => ny >= y1 && ny < y2;
}

// ============================================================
//  _QuranLayoutService  —  singleton
//
//  لە دوو DB:
//    qpc-v2-ayah-by-ayah-glyphs.db  →  global word range
//    qpc-v2-15-lines.db             →  bounds بۆ هەر لاپەرە
// ============================================================

class _QuranLayoutService {
  _QuranLayoutService._();
  static final _QuranLayoutService instance = _QuranLayoutService._();
  factory _QuranLayoutService() => instance;

  bool _ready = false;
  bool get isReady => _ready;

  // verse_key → (wordStart, wordEnd, surah, ayah)
  final Map<String, (int, int, int, int)> _words = {};

  // page → List<_AyahBound> sorted by y1
  final Map<int, List<_AyahBound>> _bounds = {};

  // page → surahId
  final Map<int, int> _pageSurah = {};

  Future<void> init() async {
    if (_ready) return;
    final dir = await getApplicationDocumentsDirectory();

    final lPath = await _copyAsset(_kLinesAsset, dir, 'qpc_lines.db');
    final gPath = await _copyAsset(_kGlyphsAsset, dir, 'qpc_glyphs.db');

    // ── ١. global word range لە glyphs db ──
    final gDb = await openDatabase(gPath, readOnly: true);
    final gRows = await gDb.rawQuery(
        'SELECT verse_key, surah, ayah, text FROM verses ORDER BY id');
    await gDb.close();

    int total = 0;
    for (final r in gRows) {
      final vk = r['verse_key'] as String;
      final s = r['surah'] as int;
      final a = r['ayah'] as int;
      final wc = (r['text'] as String).split(' ').length;
      _words[vk] = (total + 1, total + wc, s, a);
      total += wc;
    }

    // ── ٢. page lines لە lines db ──
    final pDb = await openDatabase(lPath, readOnly: true);
    final pRows =
        await pDb.rawQuery('SELECT page_number, line_number, line_type, '
            'first_word_id, last_word_id, surah_number '
            'FROM pages ORDER BY page_number, line_number');
    await pDb.close();

    int curSurah = 1;
    // page → [(lineNum, firstWord, lastWord)]
    final Map<int, List<(int, int, int)>> pageLines = {};

    for (final r in pRows) {
      final pg = r['page_number'] as int;
      final ln = r['line_number'] as int;
      final lt = r['line_type'] as String? ?? '';
      final sn = r['surah_number'];
      final fw = r['first_word_id'];
      final lw = r['last_word_id'];

      if (lt == 'surah_name' && sn != null) {
        final v = sn is int ? sn : int.tryParse(sn.toString().trim());
        if (v != null && v > 0) curSurah = v;
      }
      _pageSurah.putIfAbsent(pg, () => curSurah);

      if (lt == 'ayah' && fw != null && lw != null) {
        final fwI = fw is int ? fw : int.tryParse(fw.toString().trim());
        final lwI = lw is int ? lw : int.tryParse(lw.toString().trim());
        if (fwI != null && lwI != null) {
          pageLines.putIfAbsent(pg, () => []);
          pageLines[pg]!.add((ln, fwI, lwI));
        }
      }
    }

    // ── ٣. bounds بنیات بکە ──
    for (final e in pageLines.entries) {
      final pg = e.key;
      final lines = e.value;
      final lc = lines.length; // ١٥

      // هەر ئایەتێک → (firstLine, lastLine)
      final Map<String, (int, int)> ayahLines = {};

      for (final line in lines) {
        final ln = line.$1;
        final fw = line.$2;
        final lw = line.$3;
        for (final we in _words.entries) {
          final ws = we.value.$1;
          final ww = we.value.$2;
          if (ws <= lw && ww >= fw) {
            final cur = ayahLines[we.key];
            ayahLines[we.key] = cur == null
                ? (ln, ln)
                : (cur.$1 < ln ? cur.$1 : ln, cur.$2 > ln ? cur.$2 : ln);
          }
        }
      }

      final list = <_AyahBound>[];
      for (final ae in ayahLines.entries) {
        final info = _words[ae.key]!;
        list.add(_AyahBound(
          surah: info.$3,
          ayah: info.$4,
          y1: (ae.value.$1 - 1) / lc,
          y2: ae.value.$2 / lc,
        ));
      }
      list.sort((a, b) => a.y1.compareTo(b.y1));
      _bounds[pg] = list;
    }

    _ready = true;
    debugPrint(
        '[Layout] ready — ${_words.length} ayahs, ${_bounds.length} pages');
  }

  Future<String> _copyAsset(String asset, Directory dir, String name) async {
    final dest = File(p.join(dir.path, name));
    if (!dest.existsSync()) {
      final d = await rootBundle.load(asset);
      await dest.writeAsBytes(d.buffer.asUint8List(), flush: true);
    }
    return dest.path;
  }

  List<_AyahBound> boundsFor(int page) => _bounds[page] ?? const [];
  int surahOf(int page) => _pageSurah[page] ?? 1;

  /// تاپ لە ny → ئایەت دۆزینەوە (یەکەم containsY)
  _AyahBound? findAyah(int page, double ny) {
    for (final b in boundsFor(page)) {
      if (b.contains(ny)) return b;
    }
    return null;
  }
}

// ============================================================
//  _PageDownloader  —  singleton
// ============================================================

class _PageDownloader {
  _PageDownloader._();
  static final _PageDownloader instance = _PageDownloader._();
  factory _PageDownloader() => instance;

  String? _dir;

  Future<void> init() async {
    final d = await getApplicationDocumentsDirectory();
    _dir = p.join(d.path, 'qpages');
    await Directory(_dir!).create(recursive: true);
  }

  String path(int page) =>
      p.join(_dir!, 'p${page.toString().padLeft(3, '0')}.png');

  bool exists(int page) => page <= _kLocalMax || File(path(page)).existsSync();

  ImageProvider imageOf(int page) {
    if (page <= _kLocalMax) {
      return AssetImage(
          'assets/quran/page${page.toString().padLeft(3, '0')}.png');
    }
    final f = File(path(page));
    if (f.existsSync()) return FileImage(f);
    // فالبەک: لاپەرەی یەکەم
    return const AssetImage('assets/quran/page001.png');
  }

  Future<bool> download(int page,
      {void Function(double progress)? onProgress}) async {
    if (page <= _kLocalMax) return true;
    final f = File(path(page));
    if (f.existsSync()) return true;

    final fname = 'page${page.toString().padLeft(3, '0')}.png';
    final url = '$_kDlBase$fname';

    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        final req = http.Request('GET', Uri.parse(url));
        final resp = await req.send().timeout(const Duration(seconds: 60));
        if (resp.statusCode != 200) break;

        final total = resp.contentLength ?? 0;
        int received = 0;
        final sink = f.openWrite();

        await for (final chunk in resp.stream) {
          sink.add(chunk);
          received += chunk.length;
          if (total > 0) onProgress?.call(received / total);
        }
        await sink.flush();
        await sink.close();
        return true;
      } catch (_) {
        try {
          await f.delete();
        } catch (_) {}
        if (attempt < 3) {
          await Future.delayed(Duration(seconds: attempt * 2));
        }
      }
    }
    return false;
  }
}

// ============================================================
//  QuranScreen
// ============================================================

class QuranScreen extends StatefulWidget {
  const QuranScreen({super.key});

  @override
  State<QuranScreen> createState() => _QuranScreenState();
}

class _QuranScreenState extends State<QuranScreen> {
  final _layout = _QuranLayoutService.instance;
  final _dl = _PageDownloader.instance;
  final _db = QuranDatabaseHelper.instance;
  final _audio = QuranAudioService.instance;

  late final PageController _ctrl;

  bool _ready = false;
  int _page = 1;
  Surah _surah = _kFallbackSurah;
  List<Surah> _surahs = [];

  StreamSubscription<AudioState>? _audioSub;
  AudioState _audioState = const AudioState();
  bool _playerVisible = false;

  // دانلۆد
  int _dlDone = 0;
  double _dlProg = 0.0;
  static const int _dlTotal = _kTotalPages - _kLocalMax;

  // ── init ────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _ctrl = PageController();
    _boot();
  }

  Future<void> _boot() async {
    // هەموو یەکجار بار بکە
    await Future.wait([
      _layout.init(),
      _dl.init(),
      _audio.init(),
    ]);

    _surahs = await _db.getAllSurahs();

    // ئاخرین شوێن
    final saved = await _db.loadReadingState();
    _page = saved.page.clamp(1, _kTotalPages);

    // قاریئی پاشەکەوتکراو
    final rid = await _db.loadReciterId();
    final rec = Reciter.defaults.firstWhere(
      (r) => r.id == rid,
      orElse: () => Reciter.defaults.first,
    );
    _audio.setReciter(rec);

    // ئاگادار چەند لاپەرە ئامادەن
    int done = 0;
    for (int pg = _kLocalMax + 1; pg <= _kTotalPages; pg++) {
      if (_dl.exists(pg)) done++;
    }

    _audioSub = _audio.stream.listen(_onAudio);

    if (mounted) {
      setState(() {
        _ready = true;
        _dlDone = done;
        _dlProg = done / _dlTotal;
        _surah = _surahFor(_layout.surahOf(_page));
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_ctrl.hasClients) _ctrl.jumpToPage(_page - 1);
      });
    }

    // ignore: unawaited_futures
    _runDownloader(done);
  }

  // ── دانلۆدی پاشبزم ──────────────────────────────────────

  Future<void> _runDownloader(int alreadyDone) async {
    int done = alreadyDone;
    for (int pg = _kLocalMax + 1; pg <= _kTotalPages; pg++) {
      if (!mounted) return;
      if (_dl.exists(pg)) continue;

      await _dl.download(pg, onProgress: (v) {
        if (!mounted) return;
        final g = (done + v) / _dlTotal;
        if ((g - _dlProg).abs() > 0.005) {
          setState(() => _dlProg = g.clamp(0.0, 1.0));
        }
      });

      done++;
      if (mounted) {
        setState(() {
          _dlDone = done;
          _dlProg = (done / _dlTotal).clamp(0.0, 1.0);
        });
      }
      await Future.delayed(const Duration(milliseconds: 30));
    }
  }

  // ── یارمەتیدەر ──────────────────────────────────────────

  Surah _surahFor(int id) => _surahs.firstWhere(
        (s) => s.id == id,
        orElse: () => _kFallbackSurah,
      );

  void _onPageChanged(int idx) {
    final pg = idx + 1;
    final s = _surahFor(_layout.surahOf(pg));
    setState(() {
      _page = pg;
      _surah = s;
    });
    _db.saveReadingState(
        QuranReadingState(surahId: s.id, ayahNumber: 1, page: pg));
  }

  // ── تاپ روو لاپەرە ──────────────────────────────────────

  void _onTap(TapDownDetails d, Size sz) {
    // تاپ کاتی پلەیەر دیاریە → دادەخات
    if (_playerVisible) {
      setState(() => _playerVisible = false);
      return;
    }
    final ny = d.localPosition.dy / sz.height;
    final bound = _layout.findAyah(_page, ny);
    if (bound != null) _playAyah(bound.surah, bound.ayah);
  }

  Future<void> _playAyah(int surah, int ayah) async {
    final total = await _db.getSurahVerseCount(surah);
    if (!mounted) return;
    setState(() => _playerVisible = true);
    await _audio.play(surah, ayah, totalAyahs: total);
  }

  void _onAudio(AudioState s) {
    if (!mounted) return;
    setState(() {
      _audioState = s;
      if (s.status == AudioPlaybackState.idle) _playerVisible = false;
    });
  }

  void _jumpTo(int page) => _ctrl.jumpToPage(page.clamp(1, _kTotalPages) - 1);

  // ── dispose ─────────────────────────────────────────────

  @override
  void dispose() {
    _audioSub?.cancel();
    _audio.stop();
    _ctrl.dispose();
    super.dispose();
  }

  // ── build ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const _SplashScreen();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(children: [
          // ── TopBar
          _TopBar(
            page: _page,
            juz: _juzOf(_page),
            surah: _surah,
            dlDone: _dlDone,
            dlTotal: _dlTotal,
            dlProg: _dlProg,
            onPage: _showGoToPage,
            onList: _showSurahList,
          ),

          // ── PageView
          Expanded(
            child: PageView.builder(
              controller: _ctrl,
              reverse: true, // ڕاست بۆ چەپ
              itemCount: _kTotalPages,
              onPageChanged: _onPageChanged,
              itemBuilder: (_, i) => _buildPage(i + 1),
            ),
          ),

          // ── AudioBar
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: (_playerVisible || _audioState.isActive)
                ? _AudioBar(
                    key: const ValueKey('bar'),
                    state: _audioState,
                    surah: _surah,
                    surahs: _surahs,
                    onPlay: _audio.togglePlayPause,
                    onNext: _audio.nextAyah,
                    onPrev: _audio.prevAyah,
                    onStop: () {
                      _audio.stop();
                      setState(() => _playerVisible = false);
                    },
                    onReciter: _showReciterSheet,
                  )
                : const SizedBox.shrink(key: ValueKey('empty')),
          ),
        ]),
      ),
    );
  }

  Widget _buildPage(int page) {
    final isCurrent = page == _page;
    return LayoutBuilder(builder: (_, bc) {
      final sz = Size(bc.maxWidth, bc.maxHeight);
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: isCurrent ? (d) => _onTap(d, sz) : null,
        child: Stack(fit: StackFit.expand, children: [
          // پاشبزمی سپی
          const ColoredBox(color: Colors.white),

          // وێنەی لاپەرە
          _PageImage(page: page, dl: _dl),

          // هایلایتی ئایەت — تەنها لاپەرەی ئێستا
          if (isCurrent && _audioState.currentSurahId != null)
            RepaintBoundary(
              child: CustomPaint(
                size: sz,
                painter: _HighlightPainter(
                  bounds: _layout.boundsFor(page),
                  surah: _audioState.currentSurahId!,
                  ayah: _audioState.currentAyahNumber ?? 1,
                ),
              ),
            ),
        ]),
      );
    });
  }

  // ── دیالۆگەکان ──────────────────────────────────────────

  void _showGoToPage() {
    final c = TextEditingController(text: '$_page');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1B4332),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('بڕۆ بۆ لاپەڕە',
            style: TextStyle(
                color: Color(0xFFD4A853), fontFamily: 'Amiri', fontSize: 18)),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white, fontSize: 22),
          textAlign: TextAlign.center,
          decoration: const InputDecoration(
            hintText: '١ — ٦٠٤',
            hintStyle: TextStyle(color: Colors.white38),
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFFD4A853))),
            focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFFD4A853), width: 2)),
          ),
          onSubmitted: (v) {
            Navigator.pop(context);
            final n = int.tryParse(v);
            if (n != null) _jumpTo(n);
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              final n = int.tryParse(c.text);
              if (n != null) _jumpTo(n);
            },
            child: const Text('بڕۆ',
                style: TextStyle(
                    color: Color(0xFFD4A853),
                    fontWeight: FontWeight.bold,
                    fontSize: 15)),
          ),
        ],
      ),
    );
  }

  void _showSurahList() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1B4332),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        builder: (_, sc) => _SurahSheet(
          surahs: _surahs,
          sc: sc,
          onSelect: (s) {
            Navigator.pop(context);
            _jumpTo(s.pageStart);
          },
        ),
      ),
    );
  }

  void _showReciterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1B4332),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _ReciterSheet(
        current: _audioState.reciter ?? Reciter.defaults.first,
        onSelect: (r) async {
          _audio.setReciter(r);
          await _db.saveReciterId(r.id);
          if (!mounted) return;
          Navigator.pop(context);
        },
      ),
    );
  }
}

// ============================================================
//  _SplashScreen
// ============================================================

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF1B4332),
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircularProgressIndicator(color: Color(0xFFD4A853), strokeWidth: 2),
          SizedBox(height: 20),
          Text('قورئانی پیرۆز',
              style: TextStyle(
                  color: Color(0xFFD4A853),
                  fontFamily: 'Amiri',
                  fontSize: 24,
                  fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text('دامەزراودەکرێت...',
              style: TextStyle(color: Colors.white54, fontSize: 13)),
        ]),
      ),
    );
  }
}

// ============================================================
//  _TopBar
// ============================================================

class _TopBar extends StatelessWidget {
  final int page;
  final int juz;
  final Surah surah;
  final int dlDone;
  final int dlTotal;
  final double dlProg;
  final VoidCallback onPage;
  final VoidCallback onList;

  const _TopBar({
    required this.page,
    required this.juz,
    required this.surah,
    required this.dlDone,
    required this.dlTotal,
    required this.dlProg,
    required this.onPage,
    required this.onList,
  });

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFD4A853);
    const bg = Color(0xFF1B4332);
    final done = dlDone >= dlTotal;

    return Column(mainAxisSize: MainAxisSize.min, children: [
      // بارەی سەرەکی
      Container(
        color: bg,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(children: [
          // مکی/مدنی
          GestureDetector(
            onTap: onList,
            child: _Chip(
              surah.isMakki ? 'مکی' : 'مدنی',
              gold.withOpacity(0.15),
              gold,
            ),
          ),
          const SizedBox(width: 8),

          // ناوی سورە
          Expanded(
              child: GestureDetector(
            onTap: onPage,
            child: Column(children: [
              Text(
                surah.nameArabic,
                style: const TextStyle(
                    color: gold,
                    fontFamily: 'Amiri',
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
                textDirection: TextDirection.rtl,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              Text(
                'لاپەڕە $page',
                style: TextStyle(color: gold.withOpacity(0.5), fontSize: 9),
              ),
            ]),
          )),

          const SizedBox(width: 8),

          // جوزء
          _Chip('جزء $juz', Colors.white.withOpacity(0.08), gold, border: true),
        ]),
      ),

      // بۆکسی دانلۆد — AnimatedSize بۆ جوڵەی نەرم
      AnimatedSize(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
        child: done
            ? const SizedBox.shrink()
            : Container(
                color: const Color(0xFF0D2818),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                child: Row(children: [
                  const Icon(Icons.cloud_download_outlined,
                      color: gold, size: 12),
                  const SizedBox(width: 6),
                  Text(
                    'دابەزاندن  $dlDone / $dlTotal',
                    style:
                        TextStyle(color: gold.withOpacity(0.8), fontSize: 10),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 90,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: dlProg,
                        color: gold,
                        backgroundColor: gold.withOpacity(0.15),
                        minHeight: 4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${(dlProg * 100).toStringAsFixed(0)}٪',
                    style:
                        TextStyle(color: gold.withOpacity(0.65), fontSize: 10),
                  ),
                ]),
              ),
      ),
    ]);
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  final bool border;
  const _Chip(this.label, this.bg, this.fg, {this.border = false});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: border ? Border.all(color: fg.withOpacity(0.4)) : null,
        ),
        child: Text(label,
            style: TextStyle(
                color: fg, fontSize: 10, fontWeight: FontWeight.w700)),
      );
}

// ============================================================
//  _PageImage
// ============================================================

class _PageImage extends StatelessWidget {
  final int page;
  final _PageDownloader dl;
  const _PageImage({required this.page, required this.dl});

  @override
  Widget build(BuildContext context) {
    if (page <= _kLocalMax) {
      return Image(
        image: AssetImage(
            'assets/quran/page${page.toString().padLeft(3, '0')}.png'),
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
      );
    }

    final path = dl.path(page);
    if (File(path).existsSync()) {
      return Image(
        image: FileImage(File(path)),
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) => const Center(
            child: Icon(Icons.broken_image_outlined,
                color: Colors.black26, size: 48)),
      );
    }

    // هێشتا دانلۆد نەبووە
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.hourglass_top_rounded,
            color: Color(0xFF1B4332), size: 40),
        const SizedBox(height: 10),
        Text('لاپەڕەی $page',
            style: const TextStyle(
                fontFamily: 'Amiri', color: Color(0xFF1B4332), fontSize: 16)),
        const SizedBox(height: 4),
        const Text('دامەزردەکرێت...',
            style: TextStyle(color: Colors.black38, fontSize: 12)),
      ]),
    );
  }
}

// ============================================================
//  _HighlightPainter
//
//  هایلایتی ئایەت بەتەواوی:
//  • لە y1 یەکەمین دێر تا y2 دواترین دێر یەک ناوچە
//  • پاشبزمی زەرد نیمەشەفاف + دەوری نرم
// ============================================================

class _HighlightPainter extends CustomPainter {
  final List<_AyahBound> bounds;
  final int surah;
  final int ayah;

  const _HighlightPainter({
    required this.bounds,
    required this.surah,
    required this.ayah,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final matching =
        bounds.where((b) => b.surah == surah && b.ayah == ayah).toList();

    if (matching.isEmpty) return;

    // یەک ناوچەی یەکگرتوو — لە یەکەم تا دواترین دێر
    final y1 = matching.first.y1 * size.height;
    final y2 = matching.last.y2 * size.height;

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTRB(6, y1, size.width - 6, y2),
      const Radius.circular(6),
    );

    // پاشبزمی زەرد
    canvas.drawRRect(
      rect,
      Paint()
        ..color = const Color(0x55FFD700)
        ..style = PaintingStyle.fill,
    );

    // دەوری
    canvas.drawRRect(
      rect,
      Paint()
        ..color = const Color(0xCCFF8C00)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );
  }

  @override
  bool shouldRepaint(_HighlightPainter o) => o.surah != surah || o.ayah != ayah;
}

// ============================================================
//  _AudioBar
// ============================================================

class _AudioBar extends StatelessWidget {
  final AudioState state;
  final Surah surah;
  final List<Surah> surahs;
  final VoidCallback onPlay;
  final VoidCallback onNext;
  final VoidCallback onPrev;
  final VoidCallback onStop;
  final VoidCallback onReciter;

  const _AudioBar({
    super.key,
    required this.state,
    required this.surah,
    required this.surahs,
    required this.onPlay,
    required this.onNext,
    required this.onPrev,
    required this.onStop,
    required this.onReciter,
  });

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFD4A853);
    const bg = Color(0xFF1B4332);

    // ناوی ئایەت
    String label = '';
    if (state.currentSurahId != null) {
      final s = surahs.firstWhere(
        (x) => x.id == state.currentSurahId,
        orElse: () => surah,
      );
      label = '${s.nameArabic}  ·  ئایەت ${state.currentAyahNumber ?? ''}';
    }

    // progress
    final dur = state.duration.inMilliseconds;
    final prog =
        dur > 0 ? (state.position.inMilliseconds / dur).clamp(0.0, 1.0) : 0.0;

    return Container(
      color: bg,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // progress bar
        ClipRect(
          child: LinearProgressIndicator(
            value: prog,
            color: gold,
            backgroundColor: gold.withOpacity(0.15),
            minHeight: 2,
          ),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(children: [
            // داخستن
            _IBtn(Icons.close_rounded, Colors.white54, 20, onStop),
            const SizedBox(width: 4),

            // قاریئ
            GestureDetector(
              onTap: onReciter,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: gold.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: gold.withOpacity(0.35), width: 0.7),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.record_voice_over_outlined,
                      color: gold, size: 12),
                  const SizedBox(width: 4),
                  Text(
                    state.reciter?.nameArabic.split(' ').first ?? 'قاریئ',
                    style: const TextStyle(
                        color: gold, fontSize: 10, fontFamily: 'Amiri'),
                  ),
                ]),
              ),
            ),

            const Spacer(),

            // ناوی ئایەت
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                    color: gold.withOpacity(0.9),
                    fontSize: 12,
                    fontFamily: 'Amiri'),
                textDirection: TextDirection.rtl,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),

            const Spacer(),

            // کنترۆڵ
            _IBtn(Icons.skip_next_rounded, Colors.white70, 22, onNext),
            const SizedBox(width: 4),

            // Play / Pause
            GestureDetector(
              onTap: onPlay,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: gold,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: gold.withOpacity(0.4),
                        blurRadius: 8,
                        spreadRadius: 1),
                  ],
                ),
                child: Icon(
                  state.isPlaying
                      ? Icons.pause_rounded
                      : state.isLoading
                          ? Icons.hourglass_top_rounded
                          : Icons.play_arrow_rounded,
                  color: Colors.black87,
                  size: 26,
                ),
              ),
            ),
            const SizedBox(width: 4),

            _IBtn(Icons.skip_previous_rounded, Colors.white70, 22, onPrev),
          ]),
        ),
      ]),
    );
  }
}

class _IBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final VoidCallback onTap;
  const _IBtn(this.icon, this.color, this.size, this.onTap);

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, color: color, size: size),
        ),
      );
}

// ============================================================
//  _SurahSheet
// ============================================================

class _SurahSheet extends StatelessWidget {
  final List<Surah> surahs;
  final ScrollController sc;
  final void Function(Surah) onSelect;

  const _SurahSheet({
    required this.surahs,
    required this.sc,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFD4A853);
    return Column(children: [
      // هاندل
      Container(
        width: 36,
        height: 4,
        margin: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
            color: Colors.white24, borderRadius: BorderRadius.circular(2)),
      ),
      const Text('پێرستی سورەکان',
          style: TextStyle(
              color: gold,
              fontSize: 16,
              fontFamily: 'Amiri',
              fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      const Divider(color: Colors.white12),
      Expanded(
        child: ListView.builder(
          controller: sc,
          itemCount: surahs.length,
          itemBuilder: (_, i) {
            final s = surahs[i];
            return ListTile(
              dense: true,
              leading: CircleAvatar(
                radius: 15,
                backgroundColor: const Color(0xFF2D6A4F),
                child: Text('${s.id}',
                    style: const TextStyle(color: gold, fontSize: 10)),
              ),
              title: Text(s.nameArabic,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(
                      color: Colors.white, fontFamily: 'Amiri', fontSize: 15)),
              subtitle: Text(
                  '${s.versesCount} ئایەت  ·  '
                  '${s.isMakki ? "مکی" : "مدنی"}',
                  style: const TextStyle(color: Colors.white54, fontSize: 10)),
              trailing: Text('ل ${s.pageStart}',
                  style: const TextStyle(color: gold, fontSize: 10)),
              onTap: () => onSelect(s),
            );
          },
        ),
      ),
    ]);
  }
}

// ============================================================
//  _ReciterSheet
// ============================================================

class _ReciterSheet extends StatelessWidget {
  final Reciter current;
  final void Function(Reciter) onSelect;

  const _ReciterSheet({
    required this.current,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFD4A853);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 36,
        height: 4,
        margin: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
            color: Colors.white24, borderRadius: BorderRadius.circular(2)),
      ),
      const Text('هەڵبژاردنی قاریئ',
          style: TextStyle(
              color: gold,
              fontSize: 15,
              fontFamily: 'Amiri',
              fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      ...Reciter.defaults.map((r) {
        final sel = r.id == current.id;
        return ListTile(
          dense: true,
          leading: Icon(
            sel ? Icons.radio_button_checked : Icons.radio_button_off,
            color: gold,
            size: 18,
          ),
          title: Text(r.nameArabic,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                  color: sel ? gold : Colors.white70,
                  fontFamily: 'Amiri',
                  fontSize: 14,
                  fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
          subtitle: Text(r.style,
              style: const TextStyle(color: Colors.white38, fontSize: 10)),
          onTap: () => onSelect(r),
        );
      }),
      const SizedBox(height: 16),
    ]);
  }
}
