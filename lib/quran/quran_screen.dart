// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// quran_screen.dart
//
// یەکخستنی هەموو فایلەکانی ئامادە:
//
//  ✓ QuranDatabaseHelper   ← دەقی قورئان + وەرگێڕانی کوردی
//  ✓ qpc-v2-15-lines.db    ← کۆردینات بۆ هایلایت
//  ✓ timing JSON            ← تایمینگی وشە بە وشە
//  ✓ QuranAudioService      ← لیدانی دەنگ
//  ✓ QuranAudioBar          ← بارەی دەنگ
//  ✓ PNG لاپەڕەکان          ← ١-٣ لۆکەل، ٤-٦٠٤ داگیردەکرێن
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'dart:async';
import 'dart:convert';
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
import 'quran_page_view.dart'; // QuranAudioBar لێرەیە

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// ثابتەکان
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

// لاپەڕەی ١-٣ لە assets دان، ٤-٦٠٤ داگیردەکرێن
const int _kLocalMax = 3;
const int _kTotalPages = 604;

// URL ی داگرتن
const String _kDownloadBase =
    'https://archive.org/download/ALQURANPERPAGEFORMATPNG/';

// فایلەکانی assets
const String _kQpcAsset = 'assets/quran/qpc-v2-15-lines.db';
const String _kTimingAsset =
    'assets/quran/ayah-recitation-muhammad-siddiq-al-minshawi-murattal-hafs-959.json';

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// مۆدێلی کۆردینات — لە qpc-v2-15-lines.db
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _AyahBound {
  final int surah;
  final int ayah;
  // normalized 0..1 — لەسەر ئەندازەی وێنەکە
  final double x1, y1, x2, y2;

  const _AyahBound(this.surah, this.ayah, this.x1, this.y1, this.x2, this.y2);

  bool containsNorm(double nx, double ny) =>
      nx >= x1 && nx <= x2 && ny >= y1 && ny <= y2;
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// _QpcService — بەڕێوەبردنی qpc-v2-15-lines.db
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _QpcService {
  static final _QpcService _i = _QpcService._();
  factory _QpcService() => _i;
  _QpcService._();

  Database? _db;

  Future<void> init() async {
    if (_db != null) return;
    final dir = await getApplicationDocumentsDirectory();
    final dest = File(p.join(dir.path, 'qpc_v2_15.db'));
    if (!dest.existsSync()) {
      final data = await rootBundle.load(_kQpcAsset);
      await dest.writeAsBytes(data.buffer.asUint8List(), flush: true);
    }
    _db = await openDatabase(dest.path, readOnly: true);
  }

  /// کۆردینات بۆ هەموو ئایەتەکانی لاپەڕەیەک
  /// QPC v2 schema: page_number, surah_number, ayah_number,
  ///                min_x, min_y, max_x, max_y  (0-1 float)
  Future<List<_AyahBound>> boundsFor(int page) async {
    if (_db == null) return [];
    try {
      final rows = await _db!.rawQuery(
        '''SELECT surah_number, first_word_id, last_word_id FROM pages WHERE page_number = ?

           ORDER  BY ayah_number''',
        [page],
      );
      return rows
          .map((r) => _AyahBound(
                r['surah_number'] as int,
                r['ayah_number'] as int,
                (r['min_x'] as num).toDouble(),
                (r['min_y'] as num).toDouble(),
                (r['max_x'] as num).toDouble(),
                (r['max_y'] as num).toDouble(),
              ))
          .toList();
    } catch (e) {
      debugPrint('[QPC] boundsFor($page): $e');
      return [];
    }
  }

  /// لاپەڕەی ئایەتێک لە QPC
  Future<int?> pageOf(int surah, int ayah) async {
    if (_db == null) return null;
    try {
      final rows = await _db!.rawQuery(
        '''SELECT page_number FROM pages
           WHERE surah_number=? AND ayah_number=?
           LIMIT 1''',
        [surah, ayah],
      );
      if (rows.isEmpty) return null;
      return rows.first['page_number'] as int?;
    } catch (_) {
      return null;
    }
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// _TimingService — بارکردنی JSON ی تایمینگ
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _TimingService {
  static final _TimingService _i = _TimingService._();
  factory _TimingService() => _i;
  _TimingService._();

  // "surah:ayah" → لیستی وشەکان
  final Map<String, List<WordTiming>> _cache = {};

  Future<void> init() async {
    if (_cache.isNotEmpty) return;
    try {
      final raw = await rootBundle.loadString(_kTimingAsset);
      final root = jsonDecode(raw) as Map<String, dynamic>;
      // فۆرمات: { "audio_files": [ { "verse_key":"1:1", "words":[...] } ] }
      final list = root['audio_files'] as List<dynamic>? ?? [];
      for (final item in list) {
        final m = item as Map<String, dynamic>;
        final key = m['verse_key'] as String? ?? '';
        final words = (m['words'] as List<dynamic>? ?? [])
            .map((w) => WordTiming.fromJson(w as Map<String, dynamic>))
            .toList();
        _cache[key] = words;
      }
    } catch (e) {
      debugPrint('[Timing] init: $e');
    }
  }

  List<WordTiming> forAyah(int surah, int ayah) => _cache['$surah:$ayah'] ?? [];
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// _PageDownloader — داگرتن + خەزنکردنی لاپەڕەکان
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _PageDownloader {
  static final _PageDownloader _i = _PageDownloader._();
  factory _PageDownloader() => _i;
  _PageDownloader._();

  String? _dir;

  Future<void> init() async {
    final base = await getApplicationDocumentsDirectory();
    _dir = p.join(base.path, 'pages');
    await Directory(_dir!).create(recursive: true);
  }

  // مەسیری لۆکەل — پابلیک بۆ _PageImage
  String _localPath(int page) =>
      p.join(_dir!, 'page${page.toString().padLeft(3, '0')}.png');

  // ئایا داگیراوە؟
  Future<bool> isReady(int page) async {
    if (page <= _kLocalMax) return true;
    return File(_localPath(page)).exists();
  }

  // داگرتنی یەک لاپەڕە
  Future<bool> download(int page, {void Function(double)? onProgress}) async {
    if (page <= _kLocalMax) return true;
    final dest = File(_localPath(page));
    if (await dest.exists()) return true;

    final name = 'page${page.toString().padLeft(3, '0')}.png';
    final url = '$_kDownloadBase$name';

    try {
      final req = http.Request('GET', Uri.parse(url));
      final resp = await req.send().timeout(const Duration(seconds: 30));
      if (resp.statusCode != 200) return false;

      final total = resp.contentLength ?? 0;
      int received = 0;
      final sink = dest.openWrite();
      await for (final chunk in resp.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) onProgress?.call(received / total);
      }
      await sink.flush();
      await sink.close();
      return true;
    } catch (e) {
      debugPrint('[Downloader] page $page: $e');
      try {
        await dest.delete();
      } catch (_) {}
      return false;
    }
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// QuranScreen
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class QuranScreen extends StatefulWidget {
  const QuranScreen({super.key});

  @override
  State<QuranScreen> createState() => _QuranScreenState();
}

class _QuranScreenState extends State<QuranScreen> {
  // سێرڤیسەکان — فایلەکانی تۆی ئامادە
  final _db = QuranDatabaseHelper();
  final _qpc = _QpcService();
  final _timing = _TimingService();
  final _dl = _PageDownloader();
  final _audio = QuranAudioService();

  late final PageController _pageCtrl;

  // دۆخ
  bool _ready = false;
  int _curPage = 1;
  List<_AyahBound> _bounds = [];
  Surah? _curSurah;
  String? _activeKey; // "surah:ayah"

  // داگرتن
  final Map<int, double> _dlProgress = {};
  final Set<int> _dlDone = {};

  // دەنگ
  StreamSubscription<AudioState>? _audioSub;
  AudioState _audioState = const AudioState();

  // ── init ───────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
    _boot();
  }

  Future<void> _boot() async {
    // هەموو سێرڤیسەکان ئامادەبکە
    await Future.wait([
      _qpc.init(),
      _timing.init(),
      _dl.init(),
      _audio.init(),
    ]);

    // دۆخی کۆتایی خوێندن
    final saved = await _db.loadReadingState();
    _curPage = saved.page.clamp(1, _kTotalPages);

    // گوێگرتن بە دەنگ
    _audioSub = _audio.stateStream.listen(_onAudio);

    // بارکردنی لاپەڕەی ئێستا
    await _loadPageData(_curPage);

    // داگرتنی پاشبزم
    _runDownloader();

    if (mounted) setState(() => _ready = true);
  }

  // ── بارکردنی داتای لاپەڕە ──────────────────────────────

  Future<void> _loadPageData(int page) async {
    // کۆردینات لە QPC
    final bounds = await _qpc.boundsFor(page);

    // سورەی ئەم لاپەڕەیە لە QuranDatabaseHelper
    final surahs = await _db.getAllSurahs();
    Surah? pageSurah;
    for (int i = surahs.length - 1; i >= 0; i--) {
      if (surahs[i].pageStart <= page) {
        pageSurah = surahs[i];
        break;
      }
    }

    if (mounted) {
      setState(() {
        _curPage = page;
        _bounds = bounds;
        _curSurah = pageSurah;
      });
    }

    // پاشەکەوتکردنی دۆخ
    await _db.saveReadingState(
      QuranReadingState(
        surahId: pageSurah?.id ?? 1,
        ayahNumber: 1,
        page: page,
      ),
    );
  }

  // ── داگرتنی پاشبزم ─────────────────────────────────────

  Future<void> _runDownloader() async {
    for (int pg = _kLocalMax + 1; pg <= _kTotalPages; pg++) {
      if (!mounted) return;
      if (await _dl.isReady(pg)) {
        setState(() => _dlDone.add(pg));
        continue;
      }
      await _dl.download(
        pg,
        onProgress: (v) {
          if (mounted) setState(() => _dlProgress[pg] = v);
        },
      );
      if (mounted) {
        setState(() {
          _dlDone.add(pg);
          _dlProgress.remove(pg);
        });
      }
      // کەمێک هەستکردن — نەبڕینی نێتۆرک
      await Future.delayed(const Duration(milliseconds: 150));
    }
  }

  // ── گوێگرتن بە دەنگ → هایلایت ─────────────────────────

  void _onAudio(AudioState state) {
    if (!mounted) return;
    setState(() {
      _audioState = state;
      if (state.isPlaying &&
          state.currentSurahId != null &&
          state.currentAyahNumber != null) {
        _activeKey = '${state.currentSurahId}:${state.currentAyahNumber}';
      } else {
        _activeKey = null;
      }
    });
  }

  // ── تاپ لەسەر لاپەڕە → دۆزینەوەی ئایەت → لیدان ────────

  void _onTap(TapDownDetails d, Size sz) {
    final nx = d.localPosition.dx / sz.width;
    final ny = d.localPosition.dy / sz.height;

    for (final b in _bounds) {
      if (b.containsNorm(nx, ny)) {
        // دەنگی ئایەتەکە بکە
        final count = _db.getSurahVerseCount(b.surah);
        count.then((total) {
          _audio.play(b.surah, b.ayah, totalAyahs: total);
        });
        setState(() => _activeKey = '${b.surah}:${b.ayah}');
        return;
      }
    }
  }

  // ── گۆڕینی لاپەڕە ──────────────────────────────────────

  void _jumpTo(int page) {
    if (page < 1 || page > _kTotalPages) return;
    _pageCtrl.jumpToPage(page - 1);
    _loadPageData(page);
  }

  @override
  void dispose() {
    _audioSub?.cancel();
    _audio.stop();
    _pageCtrl.dispose();
    super.dispose();
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // build
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  @override
  Widget build(BuildContext context) {
    if (!_ready) return _buildLoading();

    return Scaffold(
      backgroundColor: const Color(0xFF1B1B1B),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // بانەری داگرتن
          if (_dlProgress.isNotEmpty) _DownloadBanner(_dlProgress),

          // لاپەڕەکان
          Expanded(child: _buildPages()),

          // بارەی دەنگ — QuranAudioBar ی فایلی تۆی ئامادە
          QuranAudioBar(
            audioState: _audioState,
            currentSurah: _curSurah,
            onPlayPause: _audio.togglePlayPause,
            onNext: _audio.nextAyah,
            onPrev: _audio.prevAyah,
            onStop: _audio.stop,
            onReciterTap: () => _showReciterSheet(),
          ),
        ],
      ),
    );
  }

  // ── AppBar ──────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    const total = _kTotalPages - _kLocalMax;
    final done = _dlDone.where((p) => p > _kLocalMax).length;

    return AppBar(
      backgroundColor: const Color(0xFF1B4332),
      title: const Text(
        'قورئانی پیرۆز',
        style: TextStyle(
          fontFamily: 'Amiri',
          fontSize: 20,
          color: Color(0xFFD4A853),
          fontWeight: FontWeight.bold,
        ),
      ),
      centerTitle: true,
      actions: [
        // پرۆگرێسی داگرتن
        if (done < total)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                '$done/$total',
                style: const TextStyle(color: Color(0xFFD4A853), fontSize: 10),
              ),
            ),
          ),

        // بڕۆ بۆ لاپەڕە
        IconButton(
          icon: const Icon(Icons.tag, color: Color(0xFFD4A853), size: 20),
          onPressed: _showGoToPage,
        ),

        // لیستی سورەکان
        IconButton(
          icon: const Icon(Icons.menu_book_rounded,
              color: Color(0xFFD4A853), size: 20),
          onPressed: _showSurahList,
        ),
      ],
    );
  }

  // ── PageView ────────────────────────────────────────────

  Widget _buildPages() {
    return PageView.builder(
      controller: _pageCtrl,
      reverse: true, // RTL
      itemCount: _kTotalPages,
      onPageChanged: (i) => _loadPageData(i + 1),
      itemBuilder: (context, i) {
        final page = i + 1;
        return _buildOnePage(page);
      },
    );
  }

  Widget _buildOnePage(int page) {
    final isCurrent = page == _curPage;

    return LayoutBuilder(
      builder: (ctx, cons) {
        final sz = Size(cons.maxWidth, cons.maxHeight);

        return GestureDetector(
          onTapDown: isCurrent ? (d) => _onTap(d, sz) : null,
          child: Container(
            color: const Color(0xFFFDF6E3),
            padding: const EdgeInsets.all(4),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // ── وێنەی لاپەڕە ────────────────────────
                _PageImage(page: page, dl: _dl, progress: _dlProgress[page]),

                // ── هایلایت — تەنها بۆ لاپەڕەی ئێستا ───
                if (isCurrent && _activeKey != null)
                  CustomPaint(
                    painter: _HighlightPainter(
                      bounds: _bounds,
                      activeKey: _activeKey!,
                    ),
                  ),

                // ── ژمارەی لاپەڕە ────────────────────────
                Positioned(
                  bottom: 4,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('$page',
                          style: const TextStyle(
                              color: Color(0xFFD4A853), fontSize: 11)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── بارکردنی وێنە بە شێوەی زیرەک ──────────────────────

  // ── دیالۆگی لاپەڕە ─────────────────────────────────────

  void _showGoToPage() {
    final ctrl = TextEditingController(text: '$_curPage');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1B4332),
        title: const Text('بڕۆ بۆ لاپەڕە',
            style: TextStyle(color: Color(0xFFD4A853), fontFamily: 'Amiri')),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white, fontSize: 18),
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
            final pg = int.tryParse(v);
            if (pg != null) _jumpTo(pg);
          },
        ),
        actions: [
          TextButton(
            child:
                const Text('بڕۆ', style: TextStyle(color: Color(0xFFD4A853))),
            onPressed: () {
              Navigator.pop(context);
              final pg = int.tryParse(ctrl.text);
              if (pg != null) _jumpTo(pg);
            },
          ),
        ],
      ),
    );
  }

  // ── لیستی سورەکان — لە QuranDatabaseHelper ─────────────

  void _showSurahList() async {
    final surahs = await _db.getAllSurahs();
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1B4332),
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        builder: (_, sc) => _SurahSheet(
          surahs: surahs,
          scrollCtrl: sc,
          onTap: (s) {
            Navigator.pop(context);
            _jumpTo(s.pageStart);
          },
        ),
      ),
    );
  }

  // ── هەڵبژاردنی قاریئ ────────────────────────────────────

  void _showReciterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1B4332),
      builder: (_) => _ReciterSheet(
        current: _audioState.reciter ?? Reciter.defaults.first,
        onSelect: (r) {
          _audio.setReciter(r);
          Navigator.pop(context);
        },
      ),
    );
  }

  // ── Loading ─────────────────────────────────────────────

  Widget _buildLoading() => const Scaffold(
        backgroundColor: Color(0xFF1B4332),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Color(0xFFD4A853)),
              SizedBox(height: 16),
              Text(
                'قورئانی پیرۆز دامەزراودەکرێت...',
                style: TextStyle(color: Colors.white70, fontFamily: 'Amiri'),
              ),
            ],
          ),
        ),
      );
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// _PageImage — وێنەی لاپەڕە لە State جیاوازترەوە
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _PageImage extends StatelessWidget {
  final int page;
  final _PageDownloader dl;
  final double? progress;

  const _PageImage({
    required this.page,
    required this.dl,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    // لاپەڕەی ١-٣ هەمیشە لۆکەلن
    if (page <= _kLocalMax) {
      return Image(
        image: AssetImage(
            'assets/quran/page${page.toString().padLeft(3, '0')}.png'),
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
      );
    }

    // داگیراوە؟
    final localFile = File(dl._localPath(page));
    if (localFile.existsSync()) {
      return Image(
        image: FileImage(localFile),
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) => const Center(
            child: Icon(Icons.broken_image, color: Colors.white24, size: 48)),
      );
    }

    // دادەگیردرێت
    if (progress != null) {
      return Container(
        color: const Color(0xFFFDF6E3),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('لاپەڕەی $page',
                  style: const TextStyle(
                      fontFamily: 'Amiri',
                      color: Color(0xFF1B4332),
                      fontSize: 16)),
              const SizedBox(height: 16),
              SizedBox(
                width: 140,
                child: LinearProgressIndicator(
                  value: progress,
                  color: const Color(0xFFD4A853),
                  backgroundColor: const Color(0xFFD4A853).withOpacity(0.15),
                  minHeight: 3,
                ),
              ),
              const SizedBox(height: 8),
              Text('${(progress! * 100).toStringAsFixed(0)}%',
                  style:
                      const TextStyle(color: Color(0xFF1B4332), fontSize: 12)),
            ],
          ),
        ),
      );
    }

    // چاوەڕوان
    return Container(
      color: const Color(0xFFFDF6E3),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.hourglass_top_rounded,
                color: Color(0xFF1B4332), size: 36),
            const SizedBox(height: 10),
            Text(
              'لاپەڕەی $page\nچاوەڕواندەکرێت...',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontFamily: 'Amiri', color: Color(0xFF1B4332), fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// _HighlightPainter — هایلایتی زەرد لەسەر وێنەکە
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _HighlightPainter extends CustomPainter {
  final List<_AyahBound> bounds;
  final String activeKey; // "surah:ayah"

  const _HighlightPainter({
    required this.bounds,
    required this.activeKey,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final parts = activeKey.split(':');
    if (parts.length != 2) return;
    final surah = int.tryParse(parts[0]);
    final ayah = int.tryParse(parts[1]);
    if (surah == null || ayah == null) return;

    final fill = Paint()
      ..color = const Color(0x44FFD700)
      ..style = PaintingStyle.fill;

    final border = Paint()
      ..color = const Color(0xBBFF8C00)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (final b in bounds) {
      if (b.surah != surah || b.ayah != ayah) continue;
      final rect = Rect.fromLTRB(
        b.x1 * size.width,
        b.y1 * size.height,
        b.x2 * size.width,
        b.y2 * size.height,
      );
      final rr = RRect.fromRectAndRadius(rect, const Radius.circular(3));
      canvas.drawRRect(rr, fill);
      canvas.drawRRect(rr, border);
    }
  }

  @override
  bool shouldRepaint(_HighlightPainter o) => o.activeKey != activeKey;
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// _DownloadBanner
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _DownloadBanner extends StatelessWidget {
  final Map<int, double> progress;
  const _DownloadBanner(this.progress);

  @override
  Widget build(BuildContext context) {
    final cur = progress.entries.first;
    return Container(
      color: const Color(0xFF0D2818),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      child: Row(
        children: [
          const Icon(Icons.downloading_rounded,
              color: Color(0xFFD4A853), size: 13),
          const SizedBox(width: 6),
          Text('داگرتنی لاپەڕەی ${cur.key}',
              style: const TextStyle(color: Colors.white60, fontSize: 10)),
          const Spacer(),
          SizedBox(
            width: 80,
            child: LinearProgressIndicator(
              value: cur.value,
              color: const Color(0xFFD4A853),
              backgroundColor: Colors.white12,
              minHeight: 2,
            ),
          ),
          const SizedBox(width: 8),
          Text('${progress.length} مایەوە',
              style: const TextStyle(color: Colors.white30, fontSize: 9)),
        ],
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// _SurahSheet — لیستی سورەکان لە DB
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _SurahSheet extends StatelessWidget {
  final List<Surah> surahs;
  final ScrollController scrollCtrl;
  final void Function(Surah) onTap;

  const _SurahSheet({
    required this.surahs,
    required this.scrollCtrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 36,
          height: 4,
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
              color: Colors.white24, borderRadius: BorderRadius.circular(2)),
        ),
        const Text('پێرستی سورەکان',
            style: TextStyle(
                color: Color(0xFFD4A853),
                fontSize: 16,
                fontFamily: 'Amiri',
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Divider(color: Colors.white12, height: 1),
        Expanded(
          child: ListView.builder(
            controller: scrollCtrl,
            itemCount: surahs.length,
            itemBuilder: (_, i) {
              final s = surahs[i];
              return ListTile(
                dense: true,
                leading: CircleAvatar(
                  radius: 14,
                  backgroundColor: const Color(0xFF2D6A4F),
                  child: Text('${s.id}',
                      style: const TextStyle(
                          color: Color(0xFFD4A853), fontSize: 10)),
                ),
                title: Text(s.nameArabic,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Amiri',
                        fontSize: 15)),
                subtitle: Text(s.displayName,
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 11)),
                trailing: Text('ل ${s.pageStart}',
                    style: const TextStyle(
                        color: Color(0xFFD4A853), fontSize: 10)),
                onTap: () => onTap(s),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// _ReciterSheet — هەڵبژاردنی قاریئ
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _ReciterSheet extends StatelessWidget {
  final Reciter current;
  final void Function(Reciter) onSelect;

  const _ReciterSheet({required this.current, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 4,
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
              color: Colors.white24, borderRadius: BorderRadius.circular(2)),
        ),
        const Text('هەڵبژاردنی قاریئ',
            style: TextStyle(
                color: Color(0xFFD4A853),
                fontSize: 15,
                fontFamily: 'Amiri',
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        ...Reciter.defaults.map((r) => ListTile(
              dense: true,
              leading: Icon(
                r.id == current.id
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: const Color(0xFFD4A853),
                size: 18,
              ),
              title: Text(r.nameArabic,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                      color: r.id == current.id
                          ? const Color(0xFFD4A853)
                          : Colors.white70,
                      fontFamily: 'Amiri',
                      fontSize: 14)),
              subtitle: Text(r.style,
                  style: const TextStyle(color: Colors.white38, fontSize: 10)),
              onTap: () => onSelect(r),
            )),
        const SizedBox(height: 16),
      ],
    );
  }
}
