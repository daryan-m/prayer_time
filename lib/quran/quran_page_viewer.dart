// ══════════════════════════════════════════════════════════════════
//  quran_page_viewer.dart
// ══════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:io';
import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;

import 'quran_main.dart';

const int kTotalPages = 604;

// ── URL وێنەکان ───────────────────────────────────────────────────
const String _kBase =
    'https://media.githubusercontent.com/media/daryan-m/daryan-m.github.io/refs/heads/main/quran_pages/004.svg';
String _svgUrl(int page) => '$_kBase/${page.toString().padLeft(3, '0')}.svg';

// ── URL دەنگ ──────────────────────────────────────────────────────
String _audioUrl(String reciterId, int surah) =>
    'https://cdn.islamic.network/quran/audio-surah/128/$reciterId/$surah.mp3';

// ══════════════════════════════════════════════════════════════════
//  داتای سورەت و جوزء بۆ هەر لاپەرە
// ══════════════════════════════════════════════════════════════════

// لاپەرە → سورەت (سورەتی کام لاپەرەیە)
int _surahOfPage(int page) {
  const surahStartPage = {
    1: 1,
    2: 2,
    3: 50,
    4: 77,
    5: 106,
    6: 128,
    7: 151,
    8: 177,
    9: 187,
    10: 208,
    11: 221,
    12: 235,
    13: 249,
    14: 255,
    15: 262,
    16: 267,
    17: 282,
    18: 293,
    19: 305,
    20: 312,
    21: 322,
    22: 332,
    23: 342,
    24: 350,
    25: 359,
    26: 367,
    27: 377,
    28: 385,
    29: 396,
    30: 404,
    31: 411,
    32: 415,
    33: 418,
    34: 428,
    35: 434,
    36: 440,
    37: 446,
    38: 453,
    39: 458,
    40: 467,
    41: 477,
    42: 483,
    43: 489,
    44: 496,
    45: 499,
    46: 502,
    47: 507,
    48: 511,
    49: 515,
    50: 518,
    51: 520,
    52: 523,
    53: 526,
    54: 528,
    55: 531,
    56: 534,
    57: 537,
    58: 542,
    59: 545,
    60: 549,
    61: 551,
    62: 553,
    63: 554,
    64: 556,
    65: 558,
    66: 560,
    67: 562,
    68: 564,
    69: 566,
    70: 568,
    71: 570,
    72: 572,
    73: 574,
    74: 575,
    75: 577,
    76: 578,
    77: 580,
    78: 582,
    79: 583,
    80: 585,
    81: 586,
    82: 587,
    83: 587,
    84: 589,
    85: 590,
    86: 591,
    87: 591,
    88: 592,
    89: 593,
    90: 594,
    91: 595,
    92: 595,
    93: 596,
    94: 596,
    95: 597,
    96: 597,
    97: 598,
    98: 598,
    99: 599,
    100: 599,
    101: 600,
    102: 600,
    103: 601,
    104: 601,
    105: 601,
    106: 602,
    107: 602,
    108: 602,
    109: 603,
    110: 603,
    111: 603,
    112: 604,
    113: 604,
    114: 604,
  };
  int result = 1;
  for (int s = 1; s <= 114; s++) {
    final start = surahStartPage[s]!;
    if (start <= page) {
      result = s;
    } else {
      break;
    }
  }
  return result;
}

// لاپەرە → جوزء (١ بۆ ٣٠)
int _juzOfPage(int page) {
  // هەر جوزء نزیکەی ٢٠ لاپەرەیە
  const juzStart = [
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
  int juz = 1;
  for (int i = 0; i < juzStart.length; i++) {
    if (juzStart[i] <= page) {
      juz = i + 1;
    } else {
      break;
    }
  }
  return juz;
}

// ناوی عەرەبی سورەتەکان
const List<String> _surahNames = [
  '', // index 0 بوش
  'الفاتحة', 'البقرة', 'آل عمران', 'النساء', 'المائدة',
  'الأنعام', 'الأعراف', 'الأنفال', 'التوبة', 'يونس',
  'هود', 'يوسف', 'الرعد', 'إبراهيم', 'الحجر',
  'النحل', 'الإسراء', 'الكهف', 'مريم', 'طه',
  'الأنبياء', 'الحج', 'المؤمنون', 'النور', 'الفرقان',
  'الشعراء', 'النمل', 'القصص', 'العنكبوت', 'الروم',
  'لقمان', 'السجدة', 'الأحزاب', 'سبأ', 'فاطر',
  'يس', 'الصافات', 'ص', 'الزمر', 'غافر',
  'فصلت', 'الشورى', 'الزخرف', 'الدخان', 'الجاثية',
  'الأحقاف', 'محمد', 'الفتح', 'الحجرات', 'ق',
  'الذاريات', 'الطور', 'النجم', 'القمر', 'الرحمن',
  'الواقعة', 'الحديد', 'المجادلة', 'الحشر', 'الممتحنة',
  'الصف', 'الجمعة', 'المنافقون', 'التغابن', 'الطلاق',
  'التحريم', 'الملك', 'القلم', 'الحاقة', 'المعارج',
  'نوح', 'الجن', 'المزمل', 'المدثر', 'القيامة',
  'الإنسان', 'المرسلات', 'النبأ', 'النازعات', 'عبس',
  'التكوير', 'الانفطار', 'المطففين', 'الانشقاق', 'البروج',
  'الطارق', 'الأعلى', 'الغاشية', 'الفجر', 'البلد',
  'الشمس', 'الليل', 'الضحى', 'الشرح', 'التين',
  'العلق', 'القدر', 'البينة', 'الزلزلة', 'العاديات',
  'القارعة', 'التكاثر', 'العصر', 'الهمزة', 'الفيل',
  'قريش', 'الماعون', 'الكوثر', 'الكافرون', 'النصر',
  'المسد', 'الإخلاص', 'الفلق', 'الناس',
];

String _surahName(int surah) =>
    surah >= 1 && surah <= 114 ? _surahNames[surah] : '';

// ناوی جوزء بە ژمارەی عەرەبی
String _juzName(int juz) {
  const arabic = [
    '',
    '١',
    '٢',
    '٣',
    '٤',
    '٥',
    '٦',
    '٧',
    '٨',
    '٩',
    '١٠',
    '١١',
    '١٢',
    '١٣',
    '١٤',
    '١٥',
    '١٦',
    '١٧',
    '١٨',
    '١٩',
    '٢٠',
    '٢١',
    '٢٢',
    '٢٣',
    '٢٤',
    '٢٥',
    '٢٦',
    '٢٧',
    '٢٨',
    '٢٩',
    '٣٠',
  ];
  return 'الجزء ${arabic[juz]}';
}

// ژمارەی لاپەرە بە عەرەبی
String _pageNumAr(int page) {
  const e = '0123456789';
  const a = '٠١٢٣٤٥٦٧٨٩';
  return page.toString().split('').map((c) {
    final i = e.indexOf(c);
    return i >= 0 ? a[i] : c;
  }).join();
}

// ══════════════════════════════════════════════════════════════════
class QuranPageViewer extends StatefulWidget {
  final Directory pagesDir;
  final int initialPage;
  final int totalPages;
  final Reciter reciter;
  final bool downloaded;
  final void Function(int) onPageChanged;
  final VoidCallback onReciterTap;

  const QuranPageViewer({
    super.key,
    required this.pagesDir,
    required this.initialPage,
    required this.totalPages,
    required this.reciter,
    required this.downloaded,
    required this.onPageChanged,
    required this.onReciterTap,
  });

  @override
  State<QuranPageViewer> createState() => _QuranPageViewerState();
}

class _QuranPageViewerState extends State<QuranPageViewer>
    with SingleTickerProviderStateMixin {
  late PageController _ctrl;
  int _cur = 1;
  bool _uiVisible = true;
  late AnimationController _uiCtrl;
  late Animation<double> _uiFade;

  final Map<int, _DlState> _dlState = HashMap();
  final Set<int> _dlQueue = {};

  // ── دەنگ ─────────────────────────────────────────────────────
  static const _mch = MethodChannel('com.daryan.prayer/quran_media');
  static const _ech = EventChannel('com.daryan.prayer/quran_media_events');
  StreamSubscription? _evSub;
  bool _playing = false;
  int _playingSurah = 0;

  @override
  void initState() {
    super.initState();
    _cur = widget.initialPage;
    _ctrl = PageController(initialPage: widget.initialPage - 1);
    _uiCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 220));
    _uiFade = CurvedAnimation(parent: _uiCtrl, curve: Curves.easeInOut);
    _uiCtrl.value = 1.0;

    _evSub = _ech.receiveBroadcastStream().listen((e) {
      if (!mounted) return;
      if (e == 'complete' || e == 'stopped') {
        setState(() {
          _playing = false;
          _playingSurah = 0;
        });
      }
    });
  }

  @override
  void dispose() {
    _evSub?.cancel();
    _mch.invokeMethod('stop').catchError((_) {});
    _ctrl.dispose();
    _uiCtrl.dispose();
    super.dispose();
  }

  // ── کنترۆڵی دەنگ ─────────────────────────────────────────────
  Future<void> _togglePlay() async {
    final surah = _surahOfPage(_cur);
    if (_playing) {
      await _mch.invokeMethod('pause');
      setState(() => _playing = false);
    } else {
      if (_playingSurah != surah) {
        await _mch.invokeMethod('play', {
          'isFile': false,
          'source': _audioUrl(widget.reciter.id, surah),
          'title': 'سورة ${_surahName(surah)}',
        });
        setState(() {
          _playing = true;
          _playingSurah = surah;
        });
      } else {
        await _mch.invokeMethod('resume');
        setState(() => _playing = true);
      }
    }
  }

  Future<void> _stop() async {
    await _mch.invokeMethod('stop').catchError((_) {});
    setState(() {
      _playing = false;
      _playingSurah = 0;
    });
  }

  void _toggleUI() {
    setState(() => _uiVisible = !_uiVisible);
    _uiVisible ? _uiCtrl.forward() : _uiCtrl.reverse();
  }

  void _goTo(int page) => _ctrl.animateToPage(
        page.clamp(1, widget.totalPages) - 1,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOut,
      );

  // ── فایل SVG ─────────────────────────────────────────────────
  File _file(int page) =>
      File('${widget.pagesDir.path}/${page.toString().padLeft(3, '0')}.svg');

  Future<void> _downloadPage(int page) async {
    if (_dlQueue.contains(page)) return;
    final f = _file(page);
    if (f.existsSync()) {
      if (mounted) setState(() => _dlState[page] = _DlState.done);
      return;
    }
    _dlQueue.add(page);
    if (mounted) setState(() => _dlState[page] = _DlState.loading);
    try {
      final resp = await http.get(Uri.parse(_svgUrl(page)));
      if (resp.statusCode == 200) {
        f.writeAsBytesSync(resp.bodyBytes);
        if (mounted) setState(() => _dlState[page] = _DlState.done);
      } else {
        throw Exception('HTTP ${resp.statusCode}');
      }
    } catch (_) {
      if (mounted) setState(() => _dlState[page] = _DlState.error);
    } finally {
      _dlQueue.remove(page);
    }
  }

  // ── بارکردنی SVG ─────────────────────────────────────────────
  Widget _buildSvg(int page) {
    // لاپەرەی یەکەم لە assets
    if (page == 1) {
      return SvgPicture.asset(
        'assets/quran/001.svg',
        fit: BoxFit.contain,
        placeholderBuilder: (_) => _spinner(),
      );
    }

    final f = _file(page);
    if ((widget.downloaded || _dlState[page] == _DlState.done) &&
        f.existsSync()) {
      return SvgPicture.file(
        f,
        fit: BoxFit.contain,
        placeholderBuilder: (_) => _spinner(),
      );
    }

    final st = _dlState[page];
    if (st == _DlState.loading) {
      return _centerMsg(text: 'دابەزاندن...', progress: true);
    }
    if (st == _DlState.error) {
      return _centerMsg(
        icon: Icons.wifi_off_rounded,
        text: 'کێشەی نێتووەرک',
        btn: 'دووبارە',
        onBtnTap: () => _downloadPage(page),
      );
    }

    // دەستپێکردنی دانلۆد
    WidgetsBinding.instance.addPostFrameCallback((_) => _downloadPage(page));
    return _spinner();
  }

  // ══════════════════════════════════════════════════════════════
  //  چوارچێوەی مصحف بە border.png
  // ══════════════════════════════════════════════════════════════
  Widget _buildFrame(Widget svgContent, double w, double h) {
    final surah = _surahOfPage(_cur);
    final juz = _juzOfPage(_cur);

    // ── بەرزی هەر بەشێک ──
    // سەرستیر: ~38px، خوارستیر: ~32px، ناوەرۆک: ماوەکە
    const topH = 38.0;
    const botH = 32.0;
    final bodyH = h - topH - botH;

    return SizedBox(
      width: w,
      height: h,
      child: Stack(
        children: [
          // ── چوارچێوەی PNG ─────────────────────────────────
          Positioned.fill(
            child: Image.asset(
              'assets/images/border1.jpg',
              fit: BoxFit.fill,
            ),
          ),

          // ── سەرستیر: ناوی سورەت (ڕاست) + ناوی جوزء (چەپ) ──
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: topH,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // جوزء — چەپ
                  Text(
                    _juzName(juz),
                    style: const TextStyle(
                      fontFamily: 'Uthmanic',
                      fontSize: 13,
                      color: Color(0xFF3B2A14),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  // سورەت — ڕاست
                  Text(
                    'سورة ${_surahName(surah)}',
                    style: const TextStyle(
                      fontFamily: 'Uthmanic',
                      fontSize: 13,
                      color: Color(0xFF3B2A14),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── ناوەرۆکی SVG ──────────────────────────────────
          Positioned(
            top: topH,
            left: 12,
            right: 12,
            height: bodyH,
            child: svgContent,
          ),

          // ── خوارستیر: ژمارەی لاپەرە لەناوەراستدا ──────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: botH,
            child: Center(
              child: Text(
                _pageNumAr(_cur),
                style: const TextStyle(
                  fontFamily: 'Uthmanic',
                  fontSize: 14,
                  color: Color(0xFF3B2A14),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  build
  // ══════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0D0B08) : const Color(0xFFEAE4D5);

    return Scaffold(
      backgroundColor: bg,
      body: GestureDetector(
        onTap: _toggleUI,
        child: Stack(
          children: [
            // ── PageView ──────────────────────────────────────
            LayoutBuilder(builder: (ctx, bc) {
              // نسبەی مصحف
              const ratio = 382.0 / 547.0;
              final safeH = bc.maxHeight -
                  MediaQuery.of(ctx).padding.top -
                  MediaQuery.of(ctx).padding.bottom -
                  72;
              final fH = safeH.clamp(200.0, 700.0);
              final fW =
                  (fH * ratio).clamp(100.0, (bc.maxWidth - 16).toDouble());

              return PageView.builder(
                controller: _ctrl,
                // physics ئاشکرا دیاری کراوە بۆ چارەسەرکردنی کێشەی ئیمولاتۆر
                physics: const ClampingScrollPhysics(),
                itemCount: widget.totalPages,
                onPageChanged: (i) {
                  final p = i + 1;
                  setState(() => _cur = p);
                  widget.onPageChanged(p);
                  // pre-fetch لاپەرەی دواتر
                  if (p < widget.totalPages && !widget.downloaded) {
                    _downloadPage(p + 1);
                  }
                },
                itemBuilder: (_, i) {
                  final page = i + 1;
                  return Center(
                    child: _buildFrame(_buildSvg(page), fW, fH),
                  );
                },
              );
            }),

            // ── UI سەرەوە + خوارەوە ───────────────────────────
            FadeTransition(
              opacity: _uiFade,
              child: Column(children: [
                _buildTopBar(isDark),
                const Spacer(),
                _buildBottomBar(isDark),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  // ── Top Bar ───────────────────────────────────────────────────
  Widget _buildTopBar(bool isDark) {
    final ov = Colors.black.withOpacity(isDark ? 0.72 : 0.48);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [ov, Colors.transparent],
        ),
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 4,
        left: 10,
        right: 10,
        bottom: 18,
      ),
      child: Row(children: [
        _circleBtn(Icons.arrow_back_ios_new_rounded, () async {
          await _stop();
          if (mounted) Navigator.pop(context);
        }),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'لاپەرەی  $_cur  /  ${widget.totalPages}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
            ),
          ),
        ),
        // بتونی قاریئ
        GestureDetector(
          onTap: widget.onReciterTap,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 150),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: const Color(0xFFD4A853).withOpacity(0.7), width: 0.9),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.record_voice_over_outlined,
                  color: Color(0xFFD4A853), size: 14),
              const SizedBox(width: 5),
              Flexible(
                child: Text(widget.reciter.nameKu,
                    style: const TextStyle(
                        color: Color(0xFFD4A853),
                        fontSize: 11,
                        fontFamily: 'Amiri'),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1),
              ),
              const SizedBox(width: 3),
              const Icon(Icons.keyboard_arrow_down_rounded,
                  color: Color(0xFFD4A853), size: 13),
            ]),
          ),
        ),
      ]),
    );
  }

  // ── Bottom Bar ────────────────────────────────────────────────
  Widget _buildBottomBar(bool isDark) {
    final ov = Colors.black.withOpacity(isDark ? 0.72 : 0.48);
    const gold = Color(0xFFD4A853);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [ov, Colors.transparent],
        ),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 8,
        left: 16,
        right: 16,
        top: 22,
      ),
      child: Row(children: [
        _navBtn(Icons.chevron_right_rounded, () => _goTo(_cur - 1), _cur > 1),

        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: _cur / widget.totalPages,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation<Color>(gold),
                minHeight: 3,
              ),
            ),
          ),
        ),

        // Stop
        if (_playing)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: _stop,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.12),
                  border: Border.all(color: Colors.white30, width: 0.8),
                ),
                child: const Icon(Icons.stop_rounded,
                    color: Colors.white70, size: 18),
              ),
            ),
          ),

        // Play / Pause
        GestureDetector(
          onTap: _togglePlay,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: gold.withOpacity(0.2),
              border: Border.all(color: gold.withOpacity(0.7), width: 1.2),
            ),
            child: Icon(
              _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: gold,
              size: 26,
            ),
          ),
        ),

        const SizedBox(width: 6),
        _navBtn(Icons.chevron_left_rounded, () => _goTo(_cur + 1),
            _cur < widget.totalPages),
      ]),
    );
  }

  // ── یارمەتیدەرەکان ────────────────────────────────────────────
  Widget _circleBtn(IconData icon, VoidCallback cb) => GestureDetector(
        onTap: cb,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.15),
          ),
          child: Icon(icon, color: Colors.white, size: 17),
        ),
      );

  Widget _navBtn(IconData icon, VoidCallback cb, bool enabled) =>
      GestureDetector(
        onTap: enabled ? cb : null,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(enabled ? 0.15 : 0.05),
            border: Border.all(
              color: Colors.white.withOpacity(enabled ? 0.3 : 0.1),
              width: 0.8,
            ),
          ),
          child: Icon(icon,
              color: Colors.white.withOpacity(enabled ? 1.0 : 0.25), size: 22),
        ),
      );

  Widget _spinner() => const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
              color: Color(0xFFD4A853), strokeWidth: 2),
        ),
      );

  Widget _centerMsg({
    IconData? icon,
    required String text,
    bool progress = false,
    String? btn,
    VoidCallback? onBtnTap,
  }) =>
      Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (progress)
            const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    color: Color(0xFFD4A853), strokeWidth: 2))
          else if (icon != null)
            Icon(icon, color: Colors.white38, size: 32),
          const SizedBox(height: 10),
          Text(text,
              style: const TextStyle(color: Colors.white54, fontSize: 13)),
          if (btn != null) ...[
            const SizedBox(height: 10),
            TextButton(
              onPressed: onBtnTap,
              child: Text(btn,
                  style:
                      const TextStyle(color: Color(0xFFD4A853), fontSize: 12)),
            ),
          ],
        ]),
      );
}

// ── Enum ──────────────────────────────────────────────────────────
enum _DlState { loading, done, error }
