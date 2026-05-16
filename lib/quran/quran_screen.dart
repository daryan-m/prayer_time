// quran_screen.dart
//
// ✓ لاپەرەکان وەک PNG (assets: 1-3، دانلۆد: 4-604)
// ✓ تاپ لە ئایەت → هایلایت + دەنگ دەستدەکات
// ✓ پلەیەر لەخوارەوە — تاپ دووبارە پلەیەر دادەخات (دەنگ بەردەوامدەبێت)
// ✓ هایلایت بە ڕەنگی زەرد لەسەر ئایەتی دەنگدراو
// ✓ جوزء + سورە + مکی/مدنی لەسەرەوە
// ✓ ئاخرین لاپەرە پاشەکەوت دەکرێت

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

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// ثابتەکان
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

const int _kLocalMax = 3;
const int _kTotalPages = 604;
const String _kDownloadBase =
    'https://archive.org/download/ALQURANPERPAGEFORMATPNG/';
const String _kQpcAsset = 'assets/quran/qpc-v2-15-lines.db';

// جوزء → لاپەڕەی دەستپێک
const List<int> _kJuzPages = [
  1,
  10,
  50,
  77,
  106,
  128,
  151,
  177,
  187,
  208,
  221,
  249,
  262,
  282,
  293,
  305,
  312,
  332,
  342,
  359,
  396,
  404,
  428,
  453,
  477,
  499,
  502,
  520,
  537,
  562,
];

int _juzOf(int page) {
  for (int i = _kJuzPages.length - 1; i >= 0; i--) {
    if (_kJuzPages[i] <= page) return i + 1;
  }
  return 1;
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// _AyahBound — بەرپرسی ناوچەی یەک ئایەت
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _AyahBound {
  final int surah, ayah;
  final double y1, y2; // normalized 0-1
  const _AyahBound(this.surah, this.ayah, this.y1, this.y2);
  bool containsY(double ny) => ny >= y1 && ny <= y2;
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// _QpcService — خوێندنەوەی DB
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _QpcService {
  static final _QpcService _i = _QpcService._();
  factory _QpcService() => _i;
  _QpcService._();

  Database? _db;
  bool _built = false;

  // page → list of (surah, ayah, lineNum)
  final Map<int, List<(int, int, int)>> _map = {};

  Future<void> init() async {
    if (_built) return;
    final dir = await getApplicationDocumentsDirectory();
    final dest = File(p.join(dir.path, 'qpc_v2_15.db'));
    if (!dest.existsSync()) {
      final data = await rootBundle.load(_kQpcAsset);
      await dest.writeAsBytes(data.buffer.asUint8List(), flush: true);
    }
    _db = await openDatabase(dest.path, readOnly: true);
    await _build();
    _built = true;
  }

  Future<void> _build() async {
    try {
      final rows = await _db!.rawQuery(
        'SELECT page_number, line_number, line_type, first_word_id, surah_number '
        'FROM pages ORDER BY page_number, line_number',
      );

      int curSurah = 1;
      final Map<int, int> ayahCount = {};

      for (final r in rows) {
        final page = r['page_number'] as int;
        final ln = r['line_number'] as int;
        final lt = r['line_type'] as String? ?? '';
        final sn = r['surah_number'];
        final fw = r['first_word_id'];

        if (lt == 'surah_name' && sn != null) {
          final v = (sn is int) ? sn : int.tryParse(sn.toString().trim());
          if (v != null && v > 0) {
            curSurah = v;
            ayahCount.putIfAbsent(curSurah, () => 0);
          }
        } else if (lt == 'ayah' && fw != null) {
          final fwStr = fw.toString().trim();
          if (fwStr.isNotEmpty && int.tryParse(fwStr) != null) {
            ayahCount[curSurah] = (ayahCount[curSurah] ?? 0) + 1;
            _map.putIfAbsent(page, () => []);
            _map[page]!.add((curSurah, ayahCount[curSurah]!, ln));
          }
        }
      }
    } catch (e) {
      debugPrint('[QPC] $e');
    }
  }

  List<_AyahBound> boundsFor(int page) {
    final list = _map[page];
    if (list == null) return [];
    return list.map<_AyahBound>((e) {
      final y1 = (e.$3 - 1) / 15.0;
      final y2 = e.$3 / 15.0;
      return _AyahBound(e.$1, e.$2, y1, y2);
    }).toList();
  }

  int surahOf(int page) {
    final e = _map[page];
    if (e != null && e.isNotEmpty) return e.first.$1;
    return 1;
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// _PageDownloader
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _PageDownloader {
  static final _PageDownloader _i = _PageDownloader._();
  factory _PageDownloader() => _i;
  _PageDownloader._();

  String? _dir;

  Future<void> init() async {
    final base = await getApplicationDocumentsDirectory();
    _dir = p.join(base.path, 'quran_pages');
    await Directory(_dir!).create(recursive: true);
  }

  String localPath(int page) =>
      p.join(_dir!, 'page${page.toString().padLeft(3, '0')}.png');

  Future<bool> isReady(int page) async {
    if (page <= _kLocalMax) return true;
    return File(localPath(page)).exists();
  }

  ImageProvider provider(int page) {
    if (page <= _kLocalMax) {
      return AssetImage(
          'assets/quran/page${page.toString().padLeft(3, '0')}.png');
    }
    final f = File(localPath(page));
    if (f.existsSync()) return FileImage(f);
    return const AssetImage('assets/quran/page001.png');
  }

  Future<bool> download(int page, {void Function(double)? onProgress}) async {
    if (page <= _kLocalMax) return true;
    final dest = File(localPath(page));
    if (await dest.exists()) return true;
    final fname = 'page${page.toString().padLeft(3, '0')}.png';
    final url = '$_kDownloadBase$fname';
    for (int try_ = 1; try_ <= 3; try_++) {
      try {
        final req = http.Request('GET', Uri.parse(url));
        final resp = await req.send().timeout(const Duration(seconds: 45));
        if (resp.statusCode != 200) break;
        final total = resp.contentLength ?? 0;
        int got = 0;
        final sink = dest.openWrite();
        await for (final chunk in resp.stream) {
          sink.add(chunk);
          got += chunk.length;
          if (total > 0) onProgress?.call(got / total);
        }
        await sink.flush();
        await sink.close();
        return true;
      } catch (e) {
        try {
          await dest.delete();
        } catch (_) {}
        if (try_ < 3) await Future.delayed(Duration(seconds: try_ * 2));
      }
    }
    return false;
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// QuranScreen
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class QuranScreen extends StatefulWidget {
  const QuranScreen({super.key});
  @override
  State<QuranScreen> createState() => _QuranScreenState();
}

class _QuranScreenState extends State<QuranScreen> {
  final _db = QuranDatabaseHelper();
  final _qpc = _QpcService();
  final _dl = _PageDownloader();
  final _audio = QuranAudioService();

  late final PageController _pageCtrl;

  bool _ready = false;
  int _curPage = 1;

  List<_AyahBound> _bounds = [];
  Surah? _curSurah;
  List<Surah> _allSurahs = [];

  // دەنگ و هایلایت
  StreamSubscription<AudioState>? _audioSub;
  AudioState _audioState = const AudioState();
  bool _playerVisible = false;

  // دانلۆد
  int? _dlPage;
  double _dlProg = 0;
  int _dlDone = 0;
  int _dlTotal = 0;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
    _boot();
  }

  Future<void> _boot() async {
    await Future.wait([_qpc.init(), _dl.init(), _audio.init()]);
    _allSurahs = await _db.getAllSurahs();
    final saved = await _db.loadReadingState();
    _curPage = saved.page.clamp(1, _kTotalPages);
    _dlTotal = _kTotalPages - _kLocalMax;

    _audioSub = _audio.stateStream.listen(_onAudio);
    await _loadPage(_curPage);
    _runDownloader();

    if (mounted) {
      setState(() => _ready = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageCtrl.hasClients) {
          _pageCtrl.jumpToPage(_curPage - 1);
        }
      });
    }
  }

  Future<void> _loadPage(int page) async {
    final bounds = _qpc.boundsFor(page);
    final surahId = _qpc.surahOf(page);
    final s = _allSurahs.firstWhere(
      (x) => x.id == surahId,
      orElse: () => _allSurahs.isNotEmpty ? _allSurahs.first : _dummySurah,
    );
    if (mounted) {
      setState(() {
        _curPage = page;
        _bounds = bounds;
        _curSurah = s;
      });
    }
    await _db.saveReadingState(
        QuranReadingState(surahId: s.id, ayahNumber: 1, page: page));
  }

  Future<void> _runDownloader() async {
    int done = 0;
    for (int pg = _kLocalMax + 1; pg <= _kTotalPages; pg++) {
      if (!mounted) return;
      if (await _dl.isReady(pg)) {
        done++;
        continue;
      }

      if (mounted) {
        setState(() {
          _dlPage = pg;
          _dlProg = 0;
          _dlDone = done;
        });
      }

      await _dl.download(pg, onProgress: (v) {
        if (mounted) setState(() => _dlProg = v);
      });

      done++;
      if (mounted) {
        setState(() {
          _dlPage = null;
          _dlProg = 0;
          _dlDone = done;
        });
      }
      await Future.delayed(const Duration(milliseconds: 100));
    }
    if (mounted) {
      setState(() {
        _dlPage = null;
        _dlDone = done;
      });
    }
  }

  // ━━ دەنگ ━━

  void _onAudio(AudioState s) {
    if (!mounted) return;
    setState(() {
      _audioState = s;
      if (!s.isActive && !s.isPlaying) {
        // دەنگ وەستا — هایلایت بمێنێت بەڵام پلەیەر دادەخات
        if (s.status == AudioPlaybackState.idle) {
          _playerVisible = false;
        }
      }
    });
  }

  // ━━ تاپ ━━

  void _onTap(TapDownDetails d, Size sz) {
    // ئەگەر پلەیەر دیاریە → دادەخات
    if (_playerVisible) {
      setState(() => _playerVisible = false);
      return;
    }

    final ny = d.localPosition.dy / sz.height;
    for (final b in _bounds) {
      if (b.containsY(ny)) {
        _playAyah(b.surah, b.ayah);
        return;
      }
    }
  }

  Future<void> _playAyah(int surahId, int ayah) async {
    final total = await _db.getSurahVerseCount(surahId);
    setState(() => _playerVisible = true);
    await _audio.play(surahId, ayah, totalAyahs: total);
  }

  void _jumpTo(int page) {
    if (page < 1 || page > _kTotalPages) return;
    _pageCtrl.jumpToPage(page - 1);
    _loadPage(page);
  }

  @override
  void dispose() {
    _audioSub?.cancel();
    _audio.stop();
    _pageCtrl.dispose();
    super.dispose();
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // build
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  @override
  Widget build(BuildContext context) {
    if (!_ready) return _buildLoading();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // ── TopBar
            _TopBar(
              page: _curPage,
              juz: _juzOf(_curPage),
              surah: _curSurah,
              dlPage: _dlPage,
              dlProgress: _dlProg,
              dlDone: _dlDone,
              dlTotal: _dlTotal,
              onGoToPage: _showGoToPage,
              onSurahList: _showSurahList,
            ),

            // ── PageView
            Expanded(
              child: PageView.builder(
                controller: _pageCtrl,
                reverse: true, // عەرەبی: ڕاست → چەپ
                itemCount: _kTotalPages,
                onPageChanged: (i) => _loadPage(i + 1),
                itemBuilder: (_, i) => _buildOnePage(i + 1),
              ),
            ),

            // ── AudioBar
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: (_playerVisible || _audioState.isActive)
                  ? QuranAudioBar(
                      key: const ValueKey('bar'),
                      audioState: _audioState,
                      currentSurah: _curSurah,
                      surahs: _allSurahs,
                      onPlayPause: _audio.togglePlayPause,
                      onNext: _audio.nextAyah,
                      onPrev: _audio.prevAyah,
                      onStop: () {
                        _audio.stop();
                        setState(() => _playerVisible = false);
                      },
                      onReciterTap: _showReciterSheet,
                      onJumpToPage: _jumpTo,
                    )
                  : const SizedBox.shrink(key: ValueKey('empty')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOnePage(int page) {
    final isCurrent = page == _curPage;
    return LayoutBuilder(builder: (ctx, cons) {
      final sz = Size(cons.maxWidth, cons.maxHeight);
      return GestureDetector(
        onTapDown: isCurrent ? (d) => _onTap(d, sz) : null,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // وێنەی لاپەرە
            _PageImage(page: page, dl: _dl),

            // هایلایت — تەنها لاپەرەی ئێستا
            if (isCurrent && _audioState.currentSurahId != null)
              CustomPaint(
                painter: _HighlightPainter(
                  bounds: _bounds,
                  surah: _audioState.currentSurahId!,
                  ayah: _audioState.currentAyahNumber ?? 1,
                  wordIndex: _audioState.highlightedWordIndex,
                ),
              ),
          ],
        ),
      );
    });
  }

  // ━━ دیالۆگ ━━

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

  void _showSurahList() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1B4332),
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        builder: (_, sc) => _SurahSheet(
          surahs: _allSurahs,
          scrollCtrl: sc,
          onTap: (s) {
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
      builder: (_) => _ReciterSheet(
        current: _audioState.reciter ?? Reciter.defaults.first,
        onSelect: (r) {
          _audio.setReciter(r);
          Navigator.pop(context);
        },
      ),
    );
  }

  Widget _buildLoading() => const Scaffold(
        backgroundColor: Color(0xFF1B4332),
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            CircularProgressIndicator(color: Color(0xFFD4A853)),
            SizedBox(height: 16),
            Text('قورئانی پیرۆز دامەزراودەکرێت...',
                style: TextStyle(
                    color: Colors.white70, fontFamily: 'Amiri', fontSize: 14)),
          ]),
        ),
      );

  static const _dummySurah = Surah(
    id: 1,
    nameArabic: 'الفاتحة',
    nameSimple: 'Al-Fatihah',
    nameKurdish: 'فاتیحە',
    versesCount: 7,
    revelationPlace: 'makkah',
    pageStart: 1,
    juzStart: 1,
  );
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// _TopBar
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _TopBar extends StatelessWidget {
  final int page;
  final int juz;
  final Surah? surah;
  final int? dlPage;
  final double dlProgress;
  final int dlDone;
  final int dlTotal;
  final VoidCallback onGoToPage;
  final VoidCallback onSurahList;

  const _TopBar({
    required this.page,
    required this.juz,
    required this.surah,
    required this.dlPage,
    required this.dlProgress,
    required this.dlDone,
    required this.dlTotal,
    required this.onGoToPage,
    required this.onSurahList,
  });

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFD4A853);
    const bg = Color(0xE61B4332);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          color: bg,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            children: [
              // چەپ: مکی/مدنی
              GestureDetector(
                onTap: onSurahList,
                child: _Chip(
                  label:
                      surah != null ? (surah!.isMakki ? 'مکی' : 'مدنی') : '—',
                  color: gold.withOpacity(0.15),
                  textColor: gold,
                ),
              ),
              const SizedBox(width: 6),

              // ناوەند: ناوی سورە
              Expanded(
                child: GestureDetector(
                  onTap: onGoToPage,
                  child: Column(
                    children: [
                      Text(
                        surah?.nameArabic ?? '',
                        style: const TextStyle(
                          fontFamily: 'Amiri',
                          fontSize: 15,
                          color: gold,
                          fontWeight: FontWeight.bold,
                        ),
                        textDirection: TextDirection.rtl,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        'لاپەڕە $page',
                        style: TextStyle(
                            color: gold.withOpacity(0.55), fontSize: 9),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 6),

              // ڕاست: جوزء
              _Chip(
                label: 'جوز $juz',
                color: Colors.white.withOpacity(0.08),
                textColor: gold,
                bordered: true,
              ),
            ],
          ),
        ),

        // نواری دانلۆد
        if (dlPage != null)
          Container(
            color: const Color(0xFF0D2818),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
            child: Row(
              children: [
                const Icon(Icons.downloading_rounded, color: gold, size: 11),
                const SizedBox(width: 5),
                Text(
                  'لاپەڕە $dlPage  ·  $dlDone/$dlTotal',
                  style: TextStyle(color: gold.withOpacity(0.7), fontSize: 9),
                ),
                const Spacer(),
                SizedBox(
                  width: 80,
                  child: LinearProgressIndicator(
                    value: dlProgress,
                    color: gold,
                    backgroundColor: gold.withOpacity(0.15),
                    minHeight: 2,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${(dlProgress * 100).toStringAsFixed(0)}%',
                  style: TextStyle(color: gold.withOpacity(0.6), fontSize: 9),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;
  final bool bordered;
  const _Chip({
    required this.label,
    required this.color,
    required this.textColor,
    this.bordered = false,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(7),
          border:
              bordered ? Border.all(color: textColor.withOpacity(0.35)) : null,
        ),
        child: Text(label,
            style: TextStyle(
                color: textColor, fontSize: 10, fontWeight: FontWeight.w600)),
      );
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// _PageImage
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _PageImage extends StatelessWidget {
  final int page;
  final _PageDownloader dl;
  const _PageImage({required this.page, required this.dl});

  @override
  Widget build(BuildContext context) {
    if (page <= _kLocalMax) {
      return Image(
        image: dl.provider(page),
        fit: BoxFit.fill,
        filterQuality: FilterQuality.medium,
      );
    }
    final path = dl.localPath(page);
    if (File(path).existsSync()) {
      return Image(
        image: FileImage(File(path)),
        fit: BoxFit.fill,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) => const Center(
            child: Icon(Icons.broken_image, color: Colors.white24)),
      );
    }
    // هێشتا دانلۆد نەبووە
    return Container(
      color: const Color(0xFFFDF6E3),
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.hourglass_top_rounded,
              color: Color(0xFF1B4332), size: 32),
          const SizedBox(height: 8),
          Text('لاپەڕەی $page',
              style: const TextStyle(
                  fontFamily: 'Amiri', color: Color(0xFF1B4332), fontSize: 14)),
        ]),
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// _HighlightPainter
//
// هایلایتی پرۆفیشناڵانە:
// • ئایەتی دەنگدراو: پاشبزمی زەرد نیمەشەفاف
// • دەوری ئایەت: خەتی زەرد نرم
// • ئەگەر bound نەبوو: هیچ مەکشێنە
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _HighlightPainter extends CustomPainter {
  final List<_AyahBound> bounds;
  final int surah;
  final int ayah;
  final int? wordIndex; // بۆ داهاتوو (word-level highlight)

  const _HighlightPainter({
    required this.bounds,
    required this.surah,
    required this.ayah,
    this.wordIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final matching = bounds.where((b) => b.surah == surah && b.ayah == ayah);
    if (matching.isEmpty) return;

    // پاشبزمی زەرد
    final fill = Paint()
      ..color = const Color(0x44FFD700)
      ..style = PaintingStyle.fill;

    // دەوری زەرد
    final stroke = Paint()
      ..color = const Color(0xBBFF8C00)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (final b in matching) {
      final rect = Rect.fromLTRB(
        4,
        b.y1 * size.height,
        size.width - 4,
        b.y2 * size.height,
      );
      final rr = RRect.fromRectAndRadius(rect, const Radius.circular(4));
      canvas.drawRRect(rr, fill);
      canvas.drawRRect(rr, stroke);
    }
  }

  @override
  bool shouldRepaint(_HighlightPainter o) =>
      o.surah != surah || o.ayah != ayah || o.wordIndex != wordIndex;
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// QuranAudioBar — پلەیەری خوارەوە
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class QuranAudioBar extends StatelessWidget {
  final AudioState audioState;
  final Surah? currentSurah;
  final List<Surah> surahs;
  final VoidCallback onPlayPause;
  final VoidCallback onNext;
  final VoidCallback onPrev;
  final VoidCallback onStop;
  final VoidCallback onReciterTap;
  final void Function(int) onJumpToPage;

  const QuranAudioBar({
    super.key,
    required this.audioState,
    required this.currentSurah,
    required this.surahs,
    required this.onPlayPause,
    required this.onNext,
    required this.onPrev,
    required this.onStop,
    required this.onReciterTap,
    required this.onJumpToPage,
  });

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFD4A853);
    const bg = Color(0xFF1B4332);

    // ناوی ئایەت
    String ayahLabel = '';
    if (audioState.currentSurahId != null) {
      final s = surahs.firstWhere(
        (x) => x.id == audioState.currentSurahId,
        orElse: () => currentSurah ?? _QuranScreenState._dummySurah,
      );
      ayahLabel = '${s.nameArabic}  ·  ئایەت ${audioState.currentAyahNumber}';
    }

    // progress
    final dur = audioState.duration.inMilliseconds;
    final pos = audioState.position.inMilliseconds;
    final progress = (dur > 0) ? (pos / dur).clamp(0.0, 1.0) : 0.0;

    return Container(
      color: bg,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // progress bar
          LinearProgressIndicator(
            value: progress,
            color: gold,
            backgroundColor: gold.withOpacity(0.15),
            minHeight: 2,
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                // وەستانی تەواو
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: Colors.white54, size: 18),
                  onPressed: onStop,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                ),

                // قاریئ
                GestureDetector(
                  onTap: onReciterTap,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: gold.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: gold.withOpacity(0.3), width: 0.6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.record_voice_over_outlined,
                            color: gold, size: 11),
                        const SizedBox(width: 4),
                        Text(
                          audioState.reciter?.nameArabic.split(' ').first ??
                              'قاریئ',
                          style: const TextStyle(
                              color: gold, fontSize: 9, fontFamily: 'Amiri'),
                        ),
                      ],
                    ),
                  ),
                ),

                const Spacer(),

                // ناوی ئایەت
                Flexible(
                  child: Text(
                    ayahLabel,
                    style: TextStyle(
                        color: gold.withOpacity(0.9),
                        fontSize: 11,
                        fontFamily: 'Amiri'),
                    textDirection: TextDirection.rtl,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),

                const Spacer(),

                // کنترۆڵەکان
                IconButton(
                  icon: const Icon(Icons.skip_next_rounded,
                      color: Colors.white70, size: 20),
                  onPressed: onNext,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                ),

                // Play/Pause
                GestureDetector(
                  onTap: onPlayPause,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: gold,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: gold.withOpacity(0.4),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Icon(
                      audioState.isPlaying
                          ? Icons.pause_rounded
                          : audioState.isLoading
                              ? Icons.hourglass_top_rounded
                              : Icons.play_arrow_rounded,
                      color: Colors.black87,
                      size: 24,
                    ),
                  ),
                ),

                IconButton(
                  icon: const Icon(Icons.skip_previous_rounded,
                      color: Colors.white70, size: 20),
                  onPressed: onPrev,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// _SurahSheet
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _SurahSheet extends StatelessWidget {
  final List<Surah> surahs;
  final ScrollController scrollCtrl;
  final void Function(Surah) onTap;
  const _SurahSheet(
      {required this.surahs, required this.scrollCtrl, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
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
      const Divider(color: Colors.white12),
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
                      color: Colors.white, fontFamily: 'Amiri', fontSize: 15)),
              subtitle: Text(s.displayName,
                  style: const TextStyle(color: Colors.white54, fontSize: 11)),
              trailing: Text('ل ${s.pageStart}',
                  style:
                      const TextStyle(color: Color(0xFFD4A853), fontSize: 10)),
              onTap: () => onTap(s),
            );
          },
        ),
      ),
    ]);
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// _ReciterSheet
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _ReciterSheet extends StatelessWidget {
  final Reciter current;
  final void Function(Reciter) onSelect;
  const _ReciterSheet({required this.current, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
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
    ]);
  }
}
