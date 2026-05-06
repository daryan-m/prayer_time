// ══════════════════════════════════════════════════════════════════
//  quran_page_viewer.dart  —  بینەری لاپەرەکانی قورئان
//  • SVG viewer + چوارچێوەی مصحف
//  • دەنگی قاریئ لە alquran.cloud بە QuranMediaService
//  • نۆتیفیکەیشن + کنترۆڵی لۆک سکرین
// ══════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:io';
import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;

import 'quran_main.dart';

// ── URL وێنەکان ───────────────────────────────────────────────────
const String _kBase = 'https://daryan-m.github.io/quran_pages';
String _svgUrl(int page) => '$_kBase/${page.toString().padLeft(3, '0')}.svg';

// ── URL دەنگ — alquran.cloud ──────────────────────────────────────
String _audioUrl(String reciterId, int surah) =>
    'https://cdn.islamic.network/quran/audio-surah/128/$reciterId/$surah.mp3';

// ── نەخشەی لاپەرە → سورەت ───────────────────────────────────────
int _surahOfPage(int page) {
  const map = {
    1: 1,
    2: 2,
    3: 2,
    4: 2,
    5: 2,
    6: 2,
    7: 2,
    8: 2,
    9: 2,
    10: 2,
    11: 2,
    12: 2,
    13: 2,
    14: 2,
    15: 2,
    16: 2,
    17: 2,
    18: 2,
    19: 2,
    20: 2,
    21: 2,
    22: 3,
    23: 3,
    24: 3,
    25: 3,
    26: 3,
    27: 3,
    28: 3,
    29: 3,
    30: 3,
    31: 3,
    32: 3,
    33: 3,
    34: 4,
    35: 4,
    36: 4,
    37: 4,
    38: 4,
    39: 4,
    40: 4,
    41: 4,
    42: 4,
    43: 4,
    44: 4,
    45: 4,
    46: 4,
    47: 4,
    48: 4,
    49: 4,
    50: 5,
    51: 5,
    52: 5,
    53: 5,
    54: 5,
    55: 5,
    56: 5,
    57: 5,
    58: 5,
    59: 5,
    60: 5,
    61: 5,
    62: 5,
    63: 5,
    64: 6,
    65: 6,
    66: 6,
    67: 6,
    68: 6,
    69: 6,
    70: 6,
    71: 6,
    72: 6,
    73: 6,
    74: 6,
    75: 6,
    76: 6,
    77: 6,
    78: 6,
    79: 6,
    80: 6,
    81: 6,
    82: 7,
    83: 7,
    84: 7,
    85: 7,
    86: 7,
    87: 7,
    88: 7,
    89: 7,
    90: 7,
    91: 7,
    92: 7,
    93: 7,
    94: 7,
    95: 7,
    96: 7,
    97: 7,
    98: 7,
    99: 7,
    100: 7,
    101: 7,
    102: 7,
    103: 8,
    104: 8,
    105: 8,
    106: 8,
    107: 8,
    108: 8,
    109: 8,
    110: 9,
    111: 9,
    112: 9,
    113: 9,
    114: 9,
    115: 9,
    116: 9,
    117: 9,
    118: 9,
    119: 9,
    120: 9,
    121: 9,
    122: 9,
    123: 10,
    124: 10,
    125: 10,
    126: 10,
    127: 10,
    128: 10,
    129: 10,
    130: 10,
    131: 10,
    132: 11,
    133: 11,
    134: 11,
    135: 11,
    136: 11,
    137: 11,
    138: 11,
    139: 11,
    140: 11,
    141: 11,
    142: 11,
    143: 11,
    144: 12,
    145: 12,
    146: 12,
    147: 12,
    148: 12,
    149: 12,
    150: 12,
    151: 12,
    152: 13,
    153: 13,
    154: 13,
    155: 13,
    156: 13,
    157: 14,
    158: 14,
    159: 14,
    160: 14,
    161: 15,
    162: 15,
    163: 15,
    164: 15,
    165: 16,
    166: 16,
    167: 16,
    168: 16,
    169: 16,
    170: 16,
    171: 16,
    172: 16,
    173: 16,
    174: 16,
    175: 16,
    176: 16,
    177: 17,
    178: 17,
    179: 17,
    180: 17,
    181: 17,
    182: 17,
    183: 17,
    184: 17,
    185: 17,
    186: 18,
    187: 18,
    188: 18,
    189: 18,
    190: 18,
    191: 18,
    192: 18,
    193: 18,
    194: 18,
    195: 18,
    196: 18,
    197: 19,
    198: 19,
    199: 19,
    200: 19,
    201: 19,
    202: 19,
    203: 20,
    204: 20,
    205: 20,
    206: 20,
    207: 20,
    208: 20,
    209: 20,
    210: 20,
    211: 21,
    212: 21,
    213: 21,
    214: 21,
    215: 21,
    216: 21,
    217: 21,
    218: 21,
    219: 22,
    220: 22,
    221: 22,
    222: 22,
    223: 22,
    224: 22,
    225: 22,
    226: 23,
    227: 23,
    228: 23,
    229: 23,
    230: 23,
    231: 24,
    232: 24,
    233: 24,
    234: 24,
    235: 24,
    236: 24,
    237: 24,
    238: 25,
    239: 25,
    240: 25,
    241: 25,
    242: 25,
    243: 26,
    244: 26,
    245: 26,
    246: 26,
    247: 26,
    248: 26,
    249: 26,
    250: 26,
    251: 27,
    252: 27,
    253: 27,
    254: 27,
    255: 27,
    256: 27,
    257: 27,
    258: 28,
    259: 28,
    260: 28,
    261: 28,
    262: 28,
    263: 28,
    264: 28,
    265: 28,
    266: 29,
    267: 29,
    268: 29,
    269: 29,
    270: 29,
    271: 29,
    272: 30,
    273: 30,
    274: 30,
    275: 30,
    276: 30,
    277: 31,
    278: 31,
    279: 31,
    280: 31,
    281: 32,
    282: 32,
    283: 33,
    284: 33,
    285: 33,
    286: 33,
    287: 33,
    288: 33,
    289: 33,
    290: 33,
    291: 34,
    292: 34,
    293: 34,
    294: 34,
    295: 34,
    296: 35,
    297: 35,
    298: 35,
    299: 35,
    300: 35,
    301: 36,
    302: 36,
    303: 36,
    304: 36,
    305: 36,
    306: 37,
    307: 37,
    308: 37,
    309: 37,
    310: 37,
    311: 38,
    312: 38,
    313: 38,
    314: 38,
    315: 38,
    316: 39,
    317: 39,
    318: 39,
    319: 39,
    320: 39,
    321: 39,
    322: 40,
    323: 40,
    324: 40,
    325: 40,
    326: 40,
    327: 40,
    328: 40,
    329: 41,
    330: 41,
    331: 41,
    332: 41,
    333: 41,
    334: 42,
    335: 42,
    336: 42,
    337: 42,
    338: 42,
    339: 43,
    340: 43,
    341: 43,
    342: 43,
    343: 43,
    344: 44,
    345: 44,
    346: 44,
    347: 45,
    348: 45,
    349: 45,
    350: 46,
    351: 46,
    352: 46,
    353: 46,
    354: 47,
    355: 47,
    356: 47,
    357: 47,
    358: 48,
    359: 48,
    360: 48,
    361: 48,
    362: 49,
    363: 49,
    364: 49,
    365: 50,
    366: 50,
    367: 51,
    368: 51,
    369: 51,
    370: 51,
    371: 52,
    372: 52,
    373: 53,
    374: 53,
    375: 53,
    376: 54,
    377: 54,
    378: 55,
    379: 55,
    380: 55,
    381: 56,
    382: 56,
    383: 56,
    384: 57,
    385: 57,
    386: 57,
    387: 57,
    388: 58,
    389: 58,
    390: 58,
    391: 59,
    392: 59,
    393: 59,
    394: 60,
    395: 60,
    396: 60,
    397: 61,
    398: 61,
    399: 62,
    400: 62,
    401: 63,
    402: 63,
    403: 64,
    404: 64,
    405: 65,
    406: 65,
    407: 66,
    408: 66,
    409: 67,
    410: 67,
    411: 67,
    412: 68,
    413: 68,
    414: 69,
    415: 69,
    416: 70,
    417: 70,
    418: 71,
    419: 71,
    420: 72,
    421: 72,
    422: 73,
    423: 73,
    424: 74,
    425: 74,
    426: 74,
    427: 75,
    428: 75,
    429: 76,
    430: 76,
    431: 77,
    432: 77,
    433: 78,
    434: 78,
    435: 79,
    436: 79,
    437: 80,
    438: 80,
    439: 81,
    440: 82,
    441: 83,
    442: 83,
    443: 84,
    444: 85,
    445: 85,
    446: 86,
    447: 87,
    448: 88,
    449: 89,
    450: 89,
    451: 90,
    452: 91,
    453: 92,
    454: 93,
    455: 94,
    456: 95,
    457: 96,
    458: 97,
    459: 98,
    460: 98,
    461: 99,
    462: 100,
    463: 101,
    464: 102,
    465: 103,
    466: 104,
    467: 105,
    468: 106,
    469: 107,
    470: 108,
    471: 109,
    472: 110,
    473: 111,
    474: 112,
    475: 113,
    476: 114,
    477: 114,
    478: 114,
    479: 114,
    480: 114,
    481: 114,
    482: 114,
    483: 114,
    484: 114,
    485: 114,
    486: 114,
    487: 114,
    488: 114,
    489: 114,
    490: 114,
    491: 114,
    492: 114,
    493: 114,
    494: 114,
    495: 114,
    496: 114,
    497: 114,
    498: 114,
    499: 114,
    500: 114,
    501: 114,
    502: 114,
    503: 114,
    504: 114,
    505: 114,
    506: 114,
    507: 114,
    508: 114,
    509: 114,
    510: 114,
    511: 114,
    512: 114,
    513: 114,
    514: 114,
    515: 114,
    516: 114,
    517: 114,
    518: 114,
    519: 114,
    520: 114,
    521: 114,
    522: 114,
    523: 114,
    524: 114,
    525: 114,
    526: 114,
    527: 114,
    528: 114,
    529: 114,
    530: 114,
    531: 114,
    532: 114,
    533: 114,
    534: 114,
    535: 114,
    536: 114,
    537: 114,
    538: 114,
    539: 114,
    540: 114,
    541: 114,
    542: 114,
    543: 114,
    544: 114,
    545: 114,
    546: 114,
    547: 114,
    548: 114,
    549: 114,
    550: 114,
    551: 114,
    552: 114,
    553: 114,
    554: 114,
    555: 114,
    556: 114,
    557: 114,
    558: 114,
    559: 114,
    560: 114,
    561: 114,
    562: 114,
    563: 114,
    564: 114,
    565: 114,
    566: 114,
    567: 114,
    568: 114,
    569: 114,
    570: 114,
    571: 114,
    572: 114,
    573: 114,
    574: 114,
    575: 114,
    576: 114,
    577: 114,
    578: 114,
    579: 114,
    580: 114,
    581: 114,
    582: 114,
    583: 114,
    584: 114,
    585: 114,
    586: 114,
    587: 114,
    588: 114,
    589: 114,
    590: 114,
    591: 114,
    592: 114,
    593: 114,
    594: 114,
    595: 114,
    596: 114,
    597: 114,
    598: 114,
    599: 114,
    600: 114,
    601: 114,
    602: 114,
    603: 114,
    604: 114,
  };
  return map[page] ?? 1;
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
  // ── لاپەرە ───────────────────────────────────────────────────
  late PageController _ctrl;
  int _cur = 1;
  bool _uiVisible = true;
  late AnimationController _uiCtrl;
  late Animation<double> _uiFade;

  final Map<int, _DlState> _dlState = HashMap();
  final Set<int> _dlQueue = {};

  // ── دەنگ بە QuranMediaService ─────────────────────────────────
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

    // گوێگرتن بە ڕووداوی تەواوبوون
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
          'title': 'سورەی $surah — ${widget.reciter.nameKu}',
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

  // ── UI ───────────────────────────────────────────────────────
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
        throw Exception();
      }
    } catch (_) {
      if (mounted) setState(() => _dlState[page] = _DlState.error);
    } finally {
      _dlQueue.remove(page);
    }
  }

  // ── بارکردنی SVG ─────────────────────────────────────────────
  Widget _buildSvg(int page) {
    if (page == 1) {
      return SvgPicture.asset('assets/quran/001.svg',
          fit: BoxFit.contain, placeholderBuilder: (_) => _spinner());
    }
    final f = _file(page);
    if ((widget.downloaded || _dlState[page] == _DlState.done) &&
        f.existsSync()) {
      return SvgPicture.file(f,
          fit: BoxFit.contain, placeholderBuilder: (_) => _spinner());
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
          onBtnTap: () => _downloadPage(page));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _downloadPage(page));
    return _spinner();
  }

  // ══════════════════════════════════════════════════════════════
  //  چوارچێوەی مصحف
  // ══════════════════════════════════════════════════════════════
  Widget _buildFrame(Widget svg, double w, double h) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageBg = isDark ? const Color(0xFF1A1408) : const Color(0xFFFBF6EA);
    final outer = isDark ? const Color(0xFFBB9230) : const Color(0xFFC09428);
    final inner = isDark ? const Color(0xFF8A6A1E) : const Color(0xFF9E7B22);
    final corner = isDark ? const Color(0xFFD4A853) : const Color(0xFFBF8E18);

    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(color: pageBg, boxShadow: [
        BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.55 : 0.22),
            blurRadius: 28,
            offset: const Offset(0, 8),
            spreadRadius: 2),
        BoxShadow(
            color: outer.withOpacity(0.15), blurRadius: 48, spreadRadius: -6),
      ]),
      child: Stack(children: [
        Positioned.fill(
            child: Padding(
                padding: const EdgeInsets.all(5),
                child: DecoratedBox(
                    decoration: BoxDecoration(
                        border: Border.all(color: outer, width: 1.2))))),
        Positioned.fill(
            child: Padding(
                padding: const EdgeInsets.all(9),
                child: DecoratedBox(
                    decoration: BoxDecoration(
                        border: Border.all(
                            color: inner.withOpacity(0.5), width: 0.6))))),
        ..._corners(corner),
        Positioned(top: 13, left: 13, right: 13, bottom: 13, child: svg),
      ]),
    );
  }

  List<Widget> _corners(Color c) {
    const s = 18.0, t = 1.8, m = 2.5;
    return [
      _corner(top: m, left: m, c: c, s: s, t: t, tp: true, lt: true),
      _corner(top: m, right: m, c: c, s: s, t: t, tp: true, lt: false),
      _corner(bottom: m, left: m, c: c, s: s, t: t, tp: false, lt: true),
      _corner(bottom: m, right: m, c: c, s: s, t: t, tp: false, lt: false),
    ];
  }

  Widget _corner({
    double? top,
    double? bottom,
    double? left,
    double? right,
    required Color c,
    required double s,
    required double t,
    required bool tp,
    required bool lt,
  }) =>
      Positioned(
        top: top,
        bottom: bottom,
        left: left,
        right: right,
        child: SizedBox(
            width: s,
            height: s,
            child: CustomPaint(painter: _CornerPainter(c, t, tp, lt))),
      );

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
        child: Stack(children: [
          // PageView
          LayoutBuilder(builder: (ctx, bc) {
            const ratio = 382.0 / 547.0;
            final safeH = bc.maxHeight -
                MediaQuery.of(ctx).padding.top -
                MediaQuery.of(ctx).padding.bottom -
                72;
            final fH = safeH.clamp(200.0, 680.0);
            final fW = (fH * ratio).clamp(100.0, (bc.maxWidth - 24).toDouble());

            return PageView.builder(
              controller: _ctrl,
              physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics()),
              itemCount: widget.totalPages,
              onPageChanged: (i) {
                final p = i + 1;
                setState(() => _cur = p);
                widget.onPageChanged(p);
                if (p < widget.totalPages && !widget.downloaded) {
                  _downloadPage(p + 1);
                }
              },
              itemBuilder: (_, i) => Center(
                child: _buildFrame(_buildSvg(i + 1), fW, fH),
              ),
            );
          }),

          // UI
          FadeTransition(
            opacity: _uiFade,
            child: Column(children: [
              _buildTopBar(isDark),
              const Spacer(),
              _buildBottomBar(isDark),
            ]),
          ),
        ]),
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
              colors: [ov, Colors.transparent])),
      padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 4,
          left: 10,
          right: 10,
          bottom: 18),
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
              shadows: [Shadow(color: Colors.black54, blurRadius: 6)]),
        )),
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
                      maxLines: 1)),
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
              colors: [ov, Colors.transparent])),
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 8,
          left: 16,
          right: 16,
          top: 22),
      child: Row(children: [
        // تیری پێشەوە
        _navBtn(Icons.chevron_right_rounded, () => _goTo(_cur - 1), _cur > 1),

        // پرۆگرەس
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
        )),

        // Stop (تەنها کاتێک دەنگ دەدات)
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
                    border: Border.all(color: Colors.white30, width: 0.8)),
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
                size: 26),
          ),
        ),

        const SizedBox(width: 6),
        // تیری دواتر
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
                shape: BoxShape.circle, color: Colors.white.withOpacity(0.15)),
            child: Icon(icon, color: Colors.white, size: 17)),
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
                    width: 0.8)),
            child: Icon(icon,
                color: Colors.white.withOpacity(enabled ? 1.0 : 0.25),
                size: 22)),
      );

  Widget _spinner() => const Center(
      child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
              color: Color(0xFFD4A853), strokeWidth: 2)));

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
        Text(text, style: const TextStyle(color: Colors.white54, fontSize: 13)),
        if (btn != null) ...[
          const SizedBox(height: 10),
          TextButton(
              onPressed: onBtnTap,
              child: Text(btn,
                  style:
                      const TextStyle(color: Color(0xFFD4A853), fontSize: 12))),
        ],
      ]));
}

// ── Enum ──────────────────────────────────────────────────────────
enum _DlState { loading, done, error }

// ── گۆشەی مصحف ───────────────────────────────────────────────────
class _CornerPainter extends CustomPainter {
  final Color color;
  final double thickness;
  final bool isTop, isLeft;
  _CornerPainter(this.color, this.thickness, this.isTop, this.isLeft);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final s = size.width;
    if (isTop && isLeft) {
      canvas.drawLine(Offset(0, s), const Offset(0, 0), p);
      canvas.drawLine(const Offset(0, 0), Offset(s, 0), p);
    } else if (isTop) {
      canvas.drawLine(Offset(s, s), Offset(s, 0), p);
      canvas.drawLine(Offset(s, 0), const Offset(0, 0), p);
    } else if (isLeft) {
      canvas.drawLine(const Offset(0, 0), Offset(0, s), p);
      canvas.drawLine(Offset(0, s), Offset(s, s), p);
    } else {
      canvas.drawLine(Offset(s, 0), Offset(s, s), p);
      canvas.drawLine(Offset(s, s), Offset(0, s), p);
    }
  }

  @override
  bool shouldRepaint(_CornerPainter o) =>
      o.color != color || o.thickness != thickness;
}
