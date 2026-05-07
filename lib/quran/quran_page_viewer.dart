// ══════════════════════════════════════════════════════════════════
//  quran_page_viewer.dart
// ══════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:io';
import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;

import 'quran_main.dart';

const int kTotalPages = 604;

const String _kBase =
    'https://github.com/daryan-m/daryan-m.github.io/raw/refs/heads/main/quran_pages/';
String _svgUrl(int page) => '$_kBase/${page.toString().padLeft(3, '0')}.svg';

String _audioUrl(String reciterId, int surah) =>
    'https://cdn.islamic.network/quran/audio-surah/128/$reciterId/$surah.mp3';

int _surahOfPage(int page) {
  const sp = {
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
  int r = 1;
  for (int s = 1; s <= 114; s++) {
    if (sp[s]! <= page) {
      r = s;
    } else {
      break;
    }
  }
  return r;
}

// جوزء
int _juzOfPage(int page) {
  const js = [
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
    582
  ];
  int j = 1;
  for (int i = 0; i < js.length; i++) {
    if (js[i] <= page) {
      j = i + 1;
    } else {
      break;
    }
  }
  return j;
}

// ناوی عەرەبی سورەتەکان
const List<String> _surahNames = [
  '',
  'الفاتحة',
  'البقرة',
  'آل عمران',
  'النساء',
  'المائدة',
  'الأنعام',
  'الأعراف',
  'الأنفال',
  'التوبة',
  'يونس',
  'هود',
  'يوسف',
  'الرعد',
  'إبراهيم',
  'الحجر',
  'النحل',
  'الإسراء',
  'الكهف',
  'مريم',
  'طه',
  'الأنبياء',
  'الحج',
  'المؤمنون',
  'النور',
  'الفرقان',
  'الشعراء',
  'النمل',
  'القصص',
  'العنكبوت',
  'الروم',
  'لقمان',
  'السجدة',
  'الأحزاب',
  'سبأ',
  'فاطر',
  'يس',
  'الصافات',
  'ص',
  'الزمر',
  'غافر',
  'فصلت',
  'الشورى',
  'الزخرف',
  'الدخان',
  'الجاثية',
  'الأحقاف',
  'محمد',
  'الفتح',
  'الحجرات',
  'ق',
  'الذاريات',
  'الطور',
  'النجم',
  'القمر',
  'الرحمن',
  'الواقعة',
  'الحديد',
  'المجادلة',
  'الحشر',
  'الممتحنة',
  'الصف',
  'الجمعة',
  'المنافقون',
  'التغابن',
  'الطلاق',
  'التحريم',
  'الملك',
  'القلم',
  'الحاقة',
  'المعارج',
  'نوح',
  'الجن',
  'المزمل',
  'المدثر',
  'القيامة',
  'الإنسان',
  'المرسلات',
  'النبأ',
  'النازعات',
  'عبس',
  'التكوير',
  'الانفطار',
  'المطففين',
  'الانشقاق',
  'البروج',
  'الطارق',
  'الأعلى',
  'الغاشية',
  'الفجر',
  'البلد',
  'الشمس',
  'الليل',
  'الضحى',
  'الشرح',
  'التين',
  'العلق',
  'القدر',
  'البينة',
  'الزلزلة',
  'العاديات',
  'القارعة',
  'التكاثر',
  'العصر',
  'الهمزة',
  'الفيل',
  'قريش',
  'الماعون',
  'الكوثر',
  'الكافرون',
  'النصر',
  'المسد',
  'الإخلاص',
  'الفلق',
  'الناس',
];

String _surahName(int s) => s >= 1 && s <= 114 ? 'سورة ${_surahNames[s]}' : '';

// ناوی جوزء بە عەرەبی
String _juzName(int j) {
  const ar = [
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
    '٣٠'
  ];
  return 'الجزء ${ar[j]}';
}

// ژمارەی لاپەرە بە عەرەبی
String _pageNumAr(int page) {
  const e = '0123456789', a = '٠١٢٣٤٥٦٧٨٩';
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

  // ── دیاریبوونی کنترۆڵ ────────────────────────────────────────
  bool _ctrlVisible = false;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  final Map<int, _DlState> _dlState = HashMap();
  final Set<int> _dlQueue = {};

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

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeInOut);

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
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── تاپ: نیشاندان/شاردنەوەی کنترۆڵ ─────────────────────────
  void _onTap() {
    setState(() => _ctrlVisible = !_ctrlVisible);
    if (_ctrlVisible) {
      _fadeCtrl.forward();
    } else {
      _fadeCtrl.reverse();
    }
  }

  // ── دەنگ ─────────────────────────────────────────────────────
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
          'title': 'سورة $surah',
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
        throw Exception('${resp.statusCode}');
      }
    } catch (_) {
      if (mounted) setState(() => _dlState[page] = _DlState.error);
    } finally {
      _dlQueue.remove(page);
    }
  }

  Widget _buildSvg(int page) {
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _downloadPage(page));
    return _spinner();
  }

  // ══════════════════════════════════════════════════════════════
  //  build
  // ══════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final botPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: GestureDetector(
        // تاپ کردن: نیشاندان/شاردنەوەی کنترۆڵ
        onTap: _onTap,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            // ══ PageView — پڕی تەواوی شاشە ════════════════════
            Positioned.fill(
              child: PageView.builder(
                controller: _ctrl,
                physics: const ClampingScrollPhysics(),
                itemCount: widget.totalPages,
                onPageChanged: (i) {
                  final p = i + 1;
                  setState(() => _cur = p);
                  widget.onPageChanged(p);
                  if (p < widget.totalPages && !widget.downloaded) {
                    _downloadPage(p + 1);
                  }
                },
                itemBuilder: (_, i) => _buildPageItem(i + 1),
              ),
            ),

            // ══ کنترۆڵەکان — بە fade لەسەر چوارچێوەکە ════════
            FadeTransition(
              opacity: _fadeAnim,
              child: IgnorePointer(
                // کاتێک نادیارە، تاپەکان تێپەڕدەبن بۆ PageView
                ignoring: !_ctrlVisible,
                child: Stack(
                  children: [
                    // ── سەرەوەی چوارچێوە: گەڕانەوە + قاریئ ────
                    Positioned(
                      top: topPad + 6,
                      left: 10,
                      right: 10,
                      child: _buildTopOverlay(),
                    ),

                    // ── خوارەوەی چوارچێوە: play + تیرەکان ──────
                    Positioned(
                      bottom: botPad + 6,
                      left: 10,
                      right: 10,
                      child: _buildBottomOverlay(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── هەر لاپەرەیەک ────────────────────────────────────────────
  Widget _buildPageItem(int page) {
    // SafeArea لێرەدا وادەکات وێنەکە و دەقەکان نەچنە ژێر شەبەکە و دوگمەکان
    return SafeArea(
      child: LayoutBuilder(builder: (ctx, bc) {
        final w = bc.maxWidth;
        final h = bc.maxHeight;

        // پێوانەی ناوچەی سپی (ئەمانە وەک خۆی زۆر باشن)
        final topH = h * 0.000;
        final botH = h * 0.000;
        final sideW = w * 0.000;

        final surah = _surahOfPage(page);
        final juz = _juzOfPage(page);

        return Stack(
          children: [
            // ١. چوارچێوەکە - ئێستا بەهۆی SafeArea تەنها لە ناوەڕاست دەبێت
            Positioned.fill(
              child: Image.asset(
                'assets/images/border1.jpg',
                fit: BoxFit.fill,
                errorBuilder: (_, __, ___) => Container(
                  color: const Color(0xFFFBF6EA),
                  foregroundDecoration: BoxDecoration(
                    border:
                        Border.all(color: const Color(0xFFC09428), width: 2),
                  ),
                ),
              ),
            ),

            // ٢. SVG ناوەڕۆک
            Positioned(
              top: topH,
              bottom: -10,
              left: 45, 
              right: -8,
              child: Transform.scale(
    scale: 1.3, // ئەم ژمارەیە زیاد بکە بۆ گەورەکردن (بۆ نموونە 1.3 یان 1.5)
              child: _buildSvg(page),
            ),
            ),
          ],
        );
      }),
    );
  }

  // ── سەرەوە: گەڕانەوە (چەپ) + قاریئ (ڕاست) ──────────────────
  Widget _buildTopOverlay() {

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // بتونی گەڕانەوە
        GestureDetector(
          onTap: () async {
            await _stop();
            if (mounted) Navigator.pop(context);
          },
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFAAA277).withOpacity(0.85),
              border: Border.all(color: Colors.white, width: 0.8),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 16),
          ),
        ),

        // بتونی قاریئ
        GestureDetector(
          onTap: widget.onReciterTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFAAA277).withOpacity(0.85),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white, width: 0.8),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.record_voice_over_outlined,
                  color: Colors.white, size: 13),
              const SizedBox(width: 5),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 80),
                child: Text(widget.reciter.nameKu,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 12, fontFamily: 'Amiri'),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1),
              ),
              const SizedBox(width: 3),
              const Icon(Icons.keyboard_arrow_down_rounded,
                color: Colors.white, size: 24),
            ]),
          ),
        ),
      ],
    );
  }

  // ── خوارەوە: تیرەکان + stop + play ──────────────────────────
  Widget _buildBottomOverlay() {

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // تیری پێشەوە
        _navBtn(Icons.chevron_right_rounded, () => _goTo(_cur - 1), _cur > 1),

        // Stop
        if (_playing)
          _smallBtn(Icons.stop_rounded, _stop)
        else
          const SizedBox(width: 36),

        // Play / Pause
        GestureDetector(
          onTap: _togglePlay,
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFAAA277).withOpacity(0.85),
               border: Border.all(color: Colors.white, width: 0.8),
            ),
            child: Icon(
              _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
        ),

        // بوشایی سیمێتری
        if (_playing) const SizedBox(width: 36) else const SizedBox(width: 36),

        // تیری دواتر
        _navBtn(Icons.chevron_left_rounded, () => _goTo(_cur + 1),
            _cur < widget.totalPages),
      ],
    );
  }

  Widget _navBtn(IconData icon, VoidCallback cb, bool enabled) =>
      GestureDetector(
        onTap: enabled ? cb : null,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFAAA277).withOpacity(enabled ? 0.85 : 0.25),
             border: Border.all(color: Colors.white, width: 0.8),
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
      );

  Widget _smallBtn(IconData icon, VoidCallback cb) => GestureDetector(
        onTap: cb,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFAAA277).withOpacity(0.85),
            border: Border.all(color: Colors.white, width: 0.8),
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      );

  Widget _spinner() => const Center(
        child: SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(
                color: Color(0xFFD4A853), strokeWidth: 2)),
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
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                  color: Color(0xFFD4A853), strokeWidth: 2))
        else if (icon != null)
          Icon(icon, color: Colors.white38, size: 28),
        const SizedBox(height: 8),
        Text(text, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        if (btn != null) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: onBtnTap,
            child: Text(btn,
                style: const TextStyle(color: Color(0xFFD4A853), fontSize: 11)),
          ),
        ],
      ]));
}

enum _DlState { loading, done, error }
