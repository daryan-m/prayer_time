// lib/quran/quran_page_view.dart
// ═══════════════════════════════════════════════════════════════
//  لاپەرەی مسحەف — ریز بەریز لە داتابەیس
//
//  ساختمان:
//  ┌──────────────────────────────────────────┐
//  │ [مكية][جز N]    ناوی سورە           [✕] │  ← header سابت
//  ├──────────────────────────────────────────┤
//  │  ریزی ١  ............................     │
//  │  ریزی ٢  ............................     │  ← 15 ریز، بەبێ scroll
//  │  ...                                      │
//  │  ریزی ١٥ ............................     │
//  ├──────────────────────────────────────────┤
//  │              ── N ──                      │  ← footer سابت
//  └──────────────────────────────────────────┘
//
//  تاپ → overlay (سەرەوە: مینیۆ | خوارەوە: پلەیەر)
// ═══════════════════════════════════════════════════════════════

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

import 'quran_database_helper.dart';
import 'quran_models.dart';
import 'quran_audio_service.dart';

// ─────────────────────────────────────────────────────────────
//  ✦ LINKS
// ─────────────────────────────────────────────────────────────

const kFontBaseUrl =
    'https://github.com/daryan-m/daryan-m.github.io/raw/refs/heads/main/fonts';
const kReciterBaseUrl = 'https://audio-cdn.tarteel.ai/quran/minshawyMurattal/';

// ─────────────────────────────────────────────────────────────
//  ڕەنگەکان
// ─────────────────────────────────────────────────────────────

const _kPageBg = Color(0xFFFAF3E0);
const _kBorder1 = Color(0xFFD4AF37);
const _kBorder2 = Color(0xFF8B6914);
const _kHeaderBg = Color(0xFFF5EAC8);
const _kHeaderText = Color(0xFF5D4037);
const _kHeaderSub = Color(0xFF8D6E63);
const _kDivider = Color(0xFFD4AF37);
const _kText = Color(0xFF1C1C1C);
const _kHL = Color(0xFFFFE082);
const _kOverlayBg = Color(0xF0141414);
const _kGold = Color(0xFFD4AF37);
const _kOverlayText = Color(0xFFEEEEEE);

const String _kFontFallback = 'Uthmanic';
const String _kUiFont = 'NotoNaskhArabic';

// ═══════════════════════════════════════════════════════════════
//  QuranFontCache  —  دانلۆد و بارکردنی فۆنتی هەر لاپەرە
// ═══════════════════════════════════════════════════════════════

class QuranFontCache {
  QuranFontCache._();
  static final QuranFontCache instance = QuranFontCache._();

  final Map<int, String> _loaded = {};
  final Set<int> _loading = {};

  String fontFor(int page) => _loaded[page] ?? _kFontFallback;
  bool isReady(int page) => _loaded.containsKey(page);

  Future<void> ensureLoaded(int page) async {
    if (_loaded.containsKey(page) || _loading.contains(page)) return;
    _loading.add(page);
    final name = 'QpcPage$page';
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}/qpc_p$page.ttf');
      if (!file.existsSync()) {
        final resp = await http.get(Uri.parse('$kFontBaseUrl/p$page.ttf'));
        if (resp.statusCode != 200) {
          _loaded[page] = _kFontFallback;
          _loading.remove(page);
          return;
        }
        await file.writeAsBytes(resp.bodyBytes, flush: true);
      }
      final bytes = await file.readAsBytes();
      await (FontLoader(name)
            ..addFont(Future.value(ByteData.view(bytes.buffer))))
          .load();
      _loaded[page] = name;
    } catch (e) {
      debugPrint('FontCache p$page: $e');
      _loaded[page] = _kFontFallback;
    }
    _loading.remove(page);
  }
}

// ═══════════════════════════════════════════════════════════════
//  QuranPageView
// ═══════════════════════════════════════════════════════════════

class QuranPageView extends StatefulWidget {
  final int pageNumber;
  final int surahNumber;
  final String surahName;
  final bool isMakki;
  final int juzNumber;
  final String? activeVerseKey;
  final int? activeWordIndex;
  final void Function(QuranGlyph)? onAyahTap;

  const QuranPageView({
    super.key,
    required this.pageNumber,
    required this.surahNumber,
    required this.surahName,
    required this.isMakki,
    required this.juzNumber,
    this.activeVerseKey,
    this.activeWordIndex,
    this.onAyahTap,
  });

  @override
  State<QuranPageView> createState() => _QuranPageViewState();
}

class _QuranPageViewState extends State<QuranPageView>
    with SingleTickerProviderStateMixin {
  // داتا
  List<QuranPageLine> _lines = [];
  Map<String, List<LineChunk>> _lineChunks = {}; // lineNum→chunks
  bool _loading = true;

  // فۆنت
  bool _fontReady = false;

  // overlay
  bool _overlayVisible = false;
  late final AnimationController _oc;
  late final Animation<double> _of;

  @override
  void initState() {
    super.initState();
    _oc = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
    _of = CurvedAnimation(parent: _oc, curve: Curves.easeOut);
    _loadPage(widget.pageNumber);
  }

  @override
  void didUpdateWidget(QuranPageView old) {
    super.didUpdateWidget(old);
    if (old.pageNumber != widget.pageNumber) {
      _loadPage(widget.pageNumber);
      _closeOverlay();
    }
  }

  @override
  void dispose() {
    _oc.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  //  بارکردنی لاپەرە
  // ─────────────────────────────────────────────────────────────

  Future<void> _loadPage(int page) async {
    setState(() {
      _loading = true;
      _fontReady = false;
    });

    // ١. WordMap (یەک جار بار دەکرێت)
    // ٢. ریزەکان لە pageDb
    // ٣. فۆنت دانلۆد
    final db = QuranDatabaseHelper.instance;
    await db.buildWordMap();

    final lines = await db.getPageLines(page);

    // بارکردنی chunks بۆ هەر ریز
    final chunks = <String, List<LineChunk>>{};
    for (final line in lines) {
      if (line.lineType == 'ayah') {
        final key = '${line.lineNumber}';
        chunks[key] = await db.getLineChunks(line);
      }
    }

    // فۆنت
    await QuranFontCache.instance.ensureLoaded(page);

    if (mounted) {
      setState(() {
        _lines = lines;
        _lineChunks = chunks;
        _fontReady = true;
        _loading = false;
      });
    }
  }

  // ── overlay ─────────────────────────────────────────────────

  void _toggleOverlay() {
    if (_overlayVisible) {
      _closeOverlay();
    } else {
      setState(() => _overlayVisible = true);
      _oc.forward();
    }
  }

  void _closeOverlay() {
    _oc.reverse().then((_) {
      if (mounted) setState(() => _overlayVisible = false);
    });
  }

  // ─────────────────────────────────────────────────────────────
  //  Build
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final font = QuranFontCache.instance.fontFor(widget.pageNumber);

    return GestureDetector(
      onTap: _toggleOverlay,
      behavior: HitTestBehavior.opaque,
      child: _PageShell(
        header: _PageHeader(
          surahName: widget.surahName,
          isMakki: widget.isMakki,
          juzNumber: widget.juzNumber,
        ),
        footer: _PageFooter(pageNumber: widget.pageNumber),
        child: Stack(
          children: [
            if (_loading || !_fontReady)
              const Center(
                  child: CircularProgressIndicator(
                      strokeWidth: 1.5, color: _kBorder1))
            else
              _MushafBody(
                lines: _lines,
                lineChunks: _lineChunks,
                fontFamily: font,
                surahName: widget.surahName,
                activeVerseKey: widget.activeVerseKey,
                onAyahTap: widget.onAyahTap,
              ),
            if (_overlayVisible)
              Positioned.fill(
                child: FadeTransition(
                  opacity: _of,
                  child: _PageOverlay(
                    surahName: widget.surahName,
                    isMakki: widget.isMakki,
                    juzNumber: widget.juzNumber,
                    pageNumber: widget.pageNumber,
                    onClose: _closeOverlay,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  _PageShell
// ═══════════════════════════════════════════════════════════════

class _PageShell extends StatelessWidget {
  final Widget header, footer, child;
  const _PageShell(
      {required this.header, required this.footer, required this.child});

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final botPad = mq.padding.bottom;

    return Container(
      color: const Color(0xFFF0EAD6),
      padding: EdgeInsets.fromLTRB(5, 2, 5, botPad + 2),
      child: Container(
        decoration: BoxDecoration(
          color: _kPageBg,
          border: Border.all(color: _kBorder1, width: 2.5),
          borderRadius: BorderRadius.circular(3),
          boxShadow: const [
            BoxShadow(
                color: Color(0x25000000), blurRadius: 8, offset: Offset(0, 2))
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(1),
          child: Container(
            margin: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
              border: Border.all(color: _kBorder2, width: 0.8),
              borderRadius: BorderRadius.circular(1),
            ),
            child: Column(children: [
              header,
              const Divider(height: 1, thickness: 1, color: _kDivider),
              Expanded(child: child),
              const Divider(height: 1, thickness: 1, color: _kDivider),
              footer,
            ]),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  _PageHeader  —  [مكية][جز N]  ناوی سورە
// ═══════════════════════════════════════════════════════════════

class _PageHeader extends StatelessWidget {
  final String surahName;
  final bool isMakki;
  final int juzNumber;
  const _PageHeader(
      {required this.surahName,
      required this.isMakki,
      required this.juzNumber});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      color: _kHeaderBg,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          _HTag(
              text: isMakki ? 'مكية' : 'مدنية',
              color:
                  isMakki ? const Color(0xFF795548) : const Color(0xFF546E7A)),
          const SizedBox(width: 4),
          _HTag(text: 'جز $juzNumber'),
          const Spacer(),
          Text(surahName,
              style: const TextStyle(
                  fontFamily: _kUiFont,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _kHeaderText),
              textDirection: TextDirection.rtl),
          const Spacer(),
          const SizedBox(width: 52), // بەلانسی چەپ
        ],
      ),
    );
  }
}

class _HTag extends StatelessWidget {
  final String text;
  final Color? color;
  const _HTag({required this.text, this.color});
  @override
  Widget build(BuildContext context) {
    final c = color ?? _kHeaderSub;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: c.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.withOpacity(0.3), width: 0.6),
      ),
      child: Text(text,
          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: c),
          textDirection: TextDirection.rtl),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  _PageFooter
// ═══════════════════════════════════════════════════════════════

class _PageFooter extends StatelessWidget {
  final int pageNumber;
  const _PageFooter({required this.pageNumber});
  @override
  Widget build(BuildContext context) => Container(
        height: 20,
        color: _kHeaderBg,
        alignment: Alignment.center,
        child: Text('— $pageNumber —',
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: _kHeaderSub,
                letterSpacing: 1.5)),
      );
}

// ═══════════════════════════════════════════════════════════════
//  _MushafBody  —  ناوەڕۆکی لاپەرە، 15 ریز، بەبێ scroll
// ═══════════════════════════════════════════════════════════════

class _MushafBody extends StatelessWidget {
  final List<QuranPageLine> lines;
  final Map<String, List<LineChunk>> lineChunks;
  final String fontFamily;
  final String surahName;
  final String? activeVerseKey;
  final void Function(QuranGlyph)? onAyahTap;

  const _MushafBody({
    required this.lines,
    required this.lineChunks,
    required this.fontFamily,
    required this.surahName,
    this.activeVerseKey,
    this.onAyahTap,
  });

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) {
      return const Center(
          child: Text('بێ داتا', style: TextStyle(color: _kHeaderSub)));
    }

    return LayoutBuilder(builder: (ctx, constraints) {
      // بەرزی هەر ریز = بەرزی گشتی / ژمارەی ریزەکان
      final lineH = constraints.maxHeight / lines.length;

      return Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: lines
              .map((line) => SizedBox(
                    height: lineH,
                    child: _buildLine(line, lineH),
                  ))
              .toList(),
        ),
      );
    });
  }

  Widget _buildLine(QuranPageLine line, double lineH) {
    // ── ناوی سورە ─────────────────────────────────────────────
    if (line.lineType == 'surah_name') {
      final name = kSurahList
          .firstWhere((s) => s.number.toString() == line.surahNumber,
              orElse: () => kSurahList.first)
          .name;
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          decoration: BoxDecoration(
            border: Border.all(color: _kBorder1, width: 0.7),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Text(name,
              style: TextStyle(
                  fontFamily: _kUiFont,
                  fontSize: lineH * 0.25,
                  fontWeight: FontWeight.w700,
                  color: _kHeaderText),
              textDirection: TextDirection.rtl),
        ),
      );
    }

    // ── بسمله ─────────────────────────────────────────────────
    if (line.lineType == 'basmallah') {
      return Center(
        child: Text(
          'بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ',
          textDirection: TextDirection.rtl,
          style: TextStyle(
            fontFamily: fontFamily,
            fontSize: lineH * 0.30,
            color: _kText,
            height: 1.0,
          ),
        ),
      );
    }

    // ── ریزی ئایەت ────────────────────────────────────────────
    final chunks = lineChunks['${line.lineNumber}'] ?? [];
    if (chunks.isEmpty) return const SizedBox.shrink();

    // fontSize: تا هەموو ریزەکان بگونجێن بەبێ overflow
    final fontSize = lineH * 0.30;

    return _MushafLine(
      chunks: chunks,
      isCentered: line.isCentered,
      fontFamily: fontFamily,
      fontSize: fontSize,
      activeVerseKey: activeVerseKey,
      onAyahTap: onAyahTap,
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  _MushafLine  —  یەک ریزی مسحەف
// ═══════════════════════════════════════════════════════════════

class _MushafLine extends StatelessWidget {
  final List<LineChunk> chunks;
  final bool isCentered;
  final String fontFamily;
  final double fontSize;
  final String? activeVerseKey;
  final void Function(QuranGlyph)? onAyahTap;

  const _MushafLine({
    required this.chunks,
    required this.isCentered,
    required this.fontFamily,
    required this.fontSize,
    this.activeVerseKey,
    this.onAyahTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: isCentered
          ? MainAxisAlignment.center
          : MainAxisAlignment.spaceBetween,
      textDirection: TextDirection.rtl,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: chunks.map((chunk) {
        final isActive = chunk.verseKey == activeVerseKey;
        return Flexible(
          child: GestureDetector(
            // بۆ تاپ پێویستمان بە QuranGlyph، ئەمەش دروست دەکەین
            onTap: () {
              if (onAyahTap == null) return;
              final parts = chunk.verseKey.split(':');
              onAyahTap!(QuranGlyph(
                id: 0,
                verseKey: chunk.verseKey,
                surah: int.tryParse(parts[0]) ?? 1,
                ayah: int.tryParse(parts[1]) ?? 1,
                text: chunk.glyphText,
                pageNumber: 0,
              ));
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              decoration: BoxDecoration(
                color: isActive ? _kHL.withOpacity(0.35) : Colors.transparent,
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                chunk.glyphText,
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.visible,
                style: TextStyle(
                  fontFamily: fontFamily,
                  fontSize: fontSize,
                  height: 1.0,
                  color: isActive ? null : _kText,
                  foreground: isActive
                      ? (Paint()..color = const Color(0xFF4A2800))
                      : null,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  _PageOverlay  —  تاپ → مینیۆ سەرەوە + پلەیەر خوارەوە
// ═══════════════════════════════════════════════════════════════

class _PageOverlay extends StatelessWidget {
  final String surahName;
  final bool isMakki;
  final int juzNumber, pageNumber;
  final VoidCallback onClose;

  const _PageOverlay({
    required this.surahName,
    required this.isMakki,
    required this.juzNumber,
    required this.pageNumber,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final audio = QuranAudioService.instance;
    return GestureDetector(
      onTap: onClose,
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: Colors.black.withOpacity(0.50),
        child: Column(children: [
          // ── سەرەوە ──────────────────────────────────────────
          GestureDetector(
            onTap: () {},
            child: Container(
              color: _kOverlayBg,
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: _OverlayTopBar(
                surahName: surahName,
                isMakki: isMakki,
                juzNumber: juzNumber,
                pageNumber: pageNumber,
                onClose: onClose,
              ),
            ),
          ),
          const Spacer(),
          // ── پلەیەر خوارەوە ───────────────────────────────
          GestureDetector(
            onTap: () {},
            child: Container(
              color: _kOverlayBg,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
              child: _OverlayPlayer(audio: audio),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── مینیۆی سەرەوە ───────────────────────────────────────────────

class _OverlayTopBar extends StatelessWidget {
  final String surahName;
  final bool isMakki;
  final int juzNumber, pageNumber;
  final VoidCallback onClose;

  const _OverlayTopBar({
    required this.surahName,
    required this.isMakki,
    required this.juzNumber,
    required this.pageNumber,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      // ✕
      GestureDetector(
        onTap: onClose,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
              color: Colors.white10,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24, width: 0.6)),
          child:
              const Icon(Icons.close_rounded, color: Colors.white60, size: 14),
        ),
      ),
      const SizedBox(width: 8),
      // ناوی سورە
      Expanded(
          child: Text(surahName,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontFamily: _kUiFont,
                  color: _kGold,
                  fontSize: 14,
                  fontWeight: FontWeight.bold))),
      const SizedBox(width: 8),
      _OvBtn(
          icon: Icons.format_list_bulleted_rounded,
          label: 'سورەکان',
          onTap: () => _openSheet(context, _SurahPickerSheet())),
      const SizedBox(width: 5),
      _OvBtn(
          icon: Icons.headphones_rounded,
          label: 'قاری',
          onTap: () => _openSheet(context, const ReciterPanel())),
    ]);
  }

  void _openSheet(BuildContext context, Widget sheet) => showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => sheet);
}

class _OvBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _OvBtn({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
              color: _kGold.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _kGold.withOpacity(0.45), width: 0.7)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: _kGold, size: 13),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(
                    color: _kGold, fontSize: 10, fontWeight: FontWeight.w600)),
          ]),
        ),
      );
}

// ── پلەیەر ──────────────────────────────────────────────────────

class _OverlayPlayer extends StatelessWidget {
  final QuranAudioService audio;
  const _OverlayPlayer({required this.audio});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: audio,
        builder: (_, __) {
          final vk = audio.currentVerseKey;
          String label = 'ئایەتێک تاپ بکە بۆ دەستپێکردن';
          if (vk != null) {
            final p = vk.split(':');
            final s = kSurahList.firstWhere(
                (x) => x.number == int.tryParse(p[0]),
                orElse: () => kSurahList.first);
            label = '${s.name}  ·  ئایەت ${p[1]}';
          }
          return Column(mainAxisSize: MainAxisSize.min, children: [
            Text(label,
                style: TextStyle(
                    color: vk != null ? _kGold : Colors.white38,
                    fontSize: 11,
                    fontWeight: FontWeight.w500),
                textDirection: TextDirection.rtl),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _PBtn(icon: Icons.skip_previous_rounded, onTap: audio.prevAyah),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: audio.isPlaying
                    ? audio.togglePlayPause
                    : audio.state == QuranPlayState.paused
                        ? audio.togglePlayPause
                        : null,
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                      color: _kGold,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: _kGold.withOpacity(0.35), blurRadius: 10)
                      ]),
                  child: Icon(
                      audio.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.black87,
                      size: 27),
                ),
              ),
              const SizedBox(width: 10),
              _PBtn(icon: Icons.skip_next_rounded, onTap: audio.nextAyah),
              const SizedBox(width: 20),
              _PTgl(
                  icon: Icons.repeat_one_rounded,
                  active: audio.repeatAyah,
                  onTap: () => audio.setRepeatAyah(!audio.repeatAyah)),
              const SizedBox(width: 10),
              _PTgl(
                  icon: Icons.fast_forward_rounded,
                  active: audio.autoNextAyah,
                  onTap: () => audio.setAutoNextAyah(!audio.autoNextAyah)),
            ]),
          ]);
        },
      );
}

class _PBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _PBtn({required this.icon, this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: onTap, child: Icon(icon, color: Colors.white70, size: 25));
}

class _PTgl extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback? onTap;
  const _PTgl({required this.icon, required this.active, this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: onTap,
      child: Icon(icon, color: active ? _kGold : Colors.white24, size: 21));
}

// ═══════════════════════════════════════════════════════════════
//  AyahByAyahView
// ═══════════════════════════════════════════════════════════════

class AyahByAyahView extends StatelessWidget {
  final int surahNumber;
  final List<QuranGlyph> glyphs;
  final List<QuranAyah> ayahs;
  final String? activeVerseKey;
  final int? activeWordIndex;
  final void Function(QuranGlyph)? onAyahTap;
  final bool useQpcFont;

  const AyahByAyahView({
    super.key,
    required this.surahNumber,
    required this.glyphs,
    required this.ayahs,
    this.activeVerseKey,
    this.activeWordIndex,
    this.onAyahTap,
    this.useQpcFont = true,
  });

  @override
  Widget build(BuildContext context) => Container(
        color: _kPageBg,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          itemCount: glyphs.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, color: Color(0xFFE2D5B5)),
          itemBuilder: (ctx, i) {
            final g = glyphs[i];
            final isActive = g.verseKey == activeVerseKey;
            return GestureDetector(
              onTap: () => onAyahTap?.call(g),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 6),
                color: isActive ? _kHL.withOpacity(0.22) : Colors.transparent,
                child: Text(g.text,
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        fontFamily: _kFontFallback,
                        fontSize: 22,
                        color: _kText,
                        height: 2.1)),
              ),
            );
          },
        ),
      );
}

// ═══════════════════════════════════════════════════════════════
//  _SurahPickerSheet
// ═══════════════════════════════════════════════════════════════

class _SurahPickerSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
            color: Color(0xFF1A1A1A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(14))),
        child: DraggableScrollableSheet(
          initialChildSize: 0.88,
          maxChildSize: 0.96,
          minChildSize: 0.4,
          expand: false,
          builder: (_, sc) => Column(children: [
            Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2))),
            const Text('سورەکان',
                style: TextStyle(
                    color: _kGold, fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
                child: ListView.separated(
              controller: sc,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: kSurahList.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: Color(0xFF2A2A2A)),
              itemBuilder: (ctx, i) {
                final s = kSurahList[i];
                return ListTile(
                  dense: true,
                  onTap: () => Navigator.pop(ctx, s),
                  title: Text(s.name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontFamily: _kUiFont),
                      textDirection: TextDirection.rtl),
                  subtitle: Text(
                      '${s.totalAyahs} ئایەت · ${s.isMakki ? "مكية" : "مدنية"}',
                      style:
                          const TextStyle(color: Colors.white38, fontSize: 10),
                      textDirection: TextDirection.rtl),
                  leading: Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        border: Border.all(
                            color: _kGold.withOpacity(0.4), width: 0.7),
                        shape: BoxShape.circle),
                    child: Text('${s.number}',
                        style: const TextStyle(
                            color: _kGold,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                  ),
                );
              },
            )),
          ]),
        ),
      );
}

// ═══════════════════════════════════════════════════════════════
//  ReciterPanel
// ═══════════════════════════════════════════════════════════════

class ReciterInfo {
  final String id, name, style, baseUrl, jsonAsset;
  const ReciterInfo(
      {required this.id,
      required this.name,
      required this.style,
      required this.baseUrl,
      required this.jsonAsset});
}

const List<ReciterInfo> kReciters = [
  ReciterInfo(
    id: 'minshawyMurattal',
    name: 'محمد صدیق المنشاوی',
    style: 'مرتل',
    baseUrl: kReciterBaseUrl,
    jsonAsset:
        'assets/quran/ayah-recitation-muhammad-siddiq-al-minshawi-murattal-hafs-959.json',
  ),
];

class ReciterPanel extends StatefulWidget {
  const ReciterPanel({super.key});
  @override
  State<ReciterPanel> createState() => _ReciterPanelState();
}

class _ReciterPanelState extends State<ReciterPanel> {
  final Map<String, _DlState> _dl = {};

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
            color: Color(0xFF1A1A1A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(14))),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2))),
          const Text('هەڵبژاردنی قاری',
              style: TextStyle(
                  color: _kGold, fontSize: 15, fontWeight: FontWeight.bold),
              textDirection: TextDirection.rtl),
          const SizedBox(height: 4),
          const Text('دانلۆد بکە بۆ گوێگرتنی ئۆفلاین',
              style: TextStyle(color: Colors.white38, fontSize: 10),
              textDirection: TextDirection.rtl),
          const SizedBox(height: 14),
          ...kReciters.map((r) => _ReciterTile(
              reciter: r,
              state: _dl[r.id] ?? _DlState.none,
              onDownload: () => _download(r))),
        ]),
      );

  Future<void> _download(ReciterInfo r) async {
    setState(() => _dl[r.id] = _DlState.downloading);
    try {
      final dir = await getApplicationSupportDirectory();
      final rDir = Directory('${dir.path}/audio/${r.id}');
      await rDir.create(recursive: true);
      for (int s = 1; s <= 114; s++) {
        final total = kSurahList.firstWhere((x) => x.number == s).totalAyahs;
        for (int a = 1; a <= total; a++) {
          final fn =
              '${s.toString().padLeft(3, '0')}${a.toString().padLeft(3, '0')}.mp3';
          final f = File('${rDir.path}/$fn');
          if (f.existsSync()) continue;
          final resp = await http.get(Uri.parse('${r.baseUrl}$fn'));
          if (resp.statusCode == 200) {
            await f.writeAsBytes(resp.bodyBytes, flush: true);
          }
        }
      }
      if (mounted) setState(() => _dl[r.id] = _DlState.done);
    } catch (e) {
      debugPrint('DL error: $e');
      if (mounted) setState(() => _dl[r.id] = _DlState.error);
    }
  }
}

enum _DlState { none, downloading, done, error }

class _ReciterTile extends StatelessWidget {
  final ReciterInfo reciter;
  final _DlState state;
  final VoidCallback onDownload;
  const _ReciterTile(
      {required this.reciter, required this.state, required this.onDownload});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
            color: const Color(0xFF242424),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white10, width: 0.6)),
        child: Row(children: [
          Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                  color: _kGold.withOpacity(0.10),
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: _kGold.withOpacity(0.35), width: 0.7)),
              child: const Icon(Icons.person, color: _kGold, size: 18)),
          const SizedBox(width: 12),
          Expanded(
              child:
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(reciter.name,
                style: const TextStyle(
                    color: _kOverlayText,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
                textDirection: TextDirection.rtl),
            const SizedBox(height: 2),
            Text(reciter.style,
                style: const TextStyle(color: Colors.white38, fontSize: 10),
                textDirection: TextDirection.rtl),
          ])),
          const SizedBox(width: 12),
          _DlBtn(state: state, onTap: onDownload),
        ]),
      );
}

class _DlBtn extends StatelessWidget {
  final _DlState state;
  final VoidCallback onTap;
  const _DlBtn({required this.state, required this.onTap});

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case _DlState.none:
        return GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                  color: _kGold.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _kGold, width: 0.7)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.download, color: _kGold, size: 14),
                SizedBox(width: 3),
                Text('دانلۆد', style: TextStyle(color: _kGold, fontSize: 10)),
              ]),
            ));
      case _DlState.downloading:
        return const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 1.5, color: _kGold));
      case _DlState.done:
        return const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.check_circle_outline, color: Color(0xFF81C784), size: 16),
          SizedBox(width: 3),
          Text('ئامادەیە',
              style: TextStyle(color: Color(0xFF81C784), fontSize: 10)),
        ]);
      case _DlState.error:
        return const Icon(Icons.error_outline,
            color: Color(0xFFEF9A9A), size: 18);
    }
  }
}
