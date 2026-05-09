// ═══════════════════════════════════════════════════════════════
//  lib/quran/quran_page_view.dart
// ═══════════════════════════════════════════════════════════════
//
//  هەڵەکانی ڕاستکراوە:
//  ✅ BUG1: ByteData.sublistView(bytes) → ByteData.view(bytes.buffer)
//  ✅ BUG2: .woff2 ناتوانرێت لە FontLoader بار بکرێت (Flutter mobile)
//           FIX: فایلەکان گۆڕدران بۆ .ttf — تەواو چارەسەر کراوە
//  ✅ BUG3: vk/label لەناو ListenableBuilder builder جێگیر کران
//  ✅ BUG4: TextStyle: color و foreground هەر دووی باهەم — color لادرا
//  ✅ ثابتەکانی نەبەکارهاتوو لادران
//
//  فۆنت:
//  • GitHub URL: https://github.com/daryan-m/daryan-m.github.io/raw/refs/heads/main/fonts
//  • فایلەکان: p1.ttf … p604.ttf  (بەبێ zero-padding)
//  • فۆنت ناو: QpcPage1 … QpcPage604
//  • Flutter FontLoader bytes-ی فایل بار دەکات (extension گرنگ نییە بۆ bytes)
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

/// لینکی GitHub — فایلەکان: p1.ttf … p604.ttf
const kFontBaseUrl =
    'https://github.com/daryan-m/daryan-m.github.io/raw/refs/heads/main/fonts';

/// بەیسی URL بۆ MP3ەکانی قاری
const kReciterBaseUrl = 'https://audio-cdn.tarteel.ai/quran/minshawyMurattal/';

// ─────────────────────────────────────────────────────────────
//  ڕەنگەکان
// ─────────────────────────────────────────────────────────────

const _kPageBg = Color(0xFFFAF3E0);
const _kPageBorder1 = Color(0xFFD4AF37);
const _kPageBorder2 = Color(0xFF8B6914);
const _kPageHeaderBg = Color(0xFFF5EAC8);
const _kHeaderText = Color(0xFF5D4037);
const _kHeaderTextSub = Color(0xFF8D6E63);
const _kDivider = Color(0xFFD4AF37);
const _kTextColor = Color(0xFF1C1C1C);
const _kHighlight = Color(0xFFFFE082);
const _kOverlayBg = Color(0xF2161616);
const _kOverlayGold = Color(0xFFD4AF37);
const _kOverlayText = Color(0xFFEEEEEE);

/// فۆنتی فالبەک — ئەگەر دانلۆد سەرکەوتوو نەبوو
/// فۆنتی فالبەک — null یانی Flutter فۆنتی سیستەم بەکاردێنێت
/// فۆنتی فالبەک بۆ ناوەڕۆکی قورئان
const String _kFontFallback = 'Uthmanic';

/// فۆنتی UI — ناوی سورە، header
const String _kUiFont = 'NotoNaskh';

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
  List<QuranGlyph> _glyphs = [];
  bool _loading = true;
  String? _fontFamily = _kFontFallback;
  bool _fontReady = false;

  bool _overlayVisible = false;
  late final AnimationController _oc;
  late final Animation<double> _of;

  @override
  void initState() {
    super.initState();
    _oc = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
    _of = CurvedAnimation(parent: _oc, curve: Curves.easeOut);
    _loadGlyphs();
    _loadFont(widget.pageNumber);
  }

  @override
  void didUpdateWidget(QuranPageView old) {
    super.didUpdateWidget(old);
    if (old.pageNumber != widget.pageNumber) {
      _loadGlyphs();
      _loadFont(widget.pageNumber);
      _closeOverlay();
    }
  }

  @override
  void dispose() {
    _oc.dispose();
    super.dispose();
  }

  // ── داتا ────────────────────────────────────────────────────

  Future<void> _loadGlyphs() async {
    setState(() => _loading = true);
    final g =
        await QuranDatabaseHelper.instance.getGlyphsOfPage(widget.pageNumber);
    if (mounted) {
      setState(() {
        _glyphs = g;
        _loading = false;
      });
    }
  }

  // ── فۆنت ─────────────────────────────────────────────────────
  //
  //  پرۆسە:
  //  1. فایل لە ذەخیرە هەیە؟  →  bytes بار دەکات
  //  2. نەخێر →  لە GitHub دادەبەزێت (.ttf)
  //  3. bytes-ەکە لە FontLoader بار دەکرێت
  //  4. ئەگەر هەڵە هاتەوە → فۆنتی فالبەک بەکاردێت
  // ─────────────────────────────────────────────────────────────

  Future<void> _loadFont(int page) async {
    if (mounted) {
      setState(() {
        _fontFamily = _kFontFallback;
        _fontReady = false;
      });
    }

    // فۆنت ناو — QpcPage1 … QpcPage604 (بەبێ zero-padding)
    final fontName = 'QpcPage$page';

    try {
      final dir = await getApplicationSupportDirectory();
      // ذەخیرەکردن بە .ttf
      final file = File('${dir.path}/qpc_p$page.ttf');

      Uint8List bytes;

      if (file.existsSync()) {
        // لە ذەخیرە بار بکە
        bytes = await file.readAsBytes();
      } else {
        // دانلۆد لە GitHub — فایل ناو: p1.ttf … p604.ttf
        final url = '$kFontBaseUrl/p$page.ttf';
        final resp = await http.get(Uri.parse(url));

        if (resp.statusCode != 200) {
          debugPrint('Font download failed: $url (${resp.statusCode})');
          if (mounted) {
            setState(() {
              _fontFamily = _kFontFallback;
              _fontReady = true;
            });
          }
          return;
        }

        bytes = resp.bodyBytes;
        // ذەخیرەکردن بۆ دواتر
        await file.writeAsBytes(bytes, flush: true);
      }

      // ✅ FIX BUG1: ByteData.view(bytes.buffer)  نەک  sublistView
      final byteData = ByteData.view(bytes.buffer);

      final loader = FontLoader(fontName)..addFont(Future.value(byteData));
      await loader.load();

      if (mounted) {
        setState(() {
          _fontFamily = fontName;
          _fontReady = true;
        });
      }
    } catch (e) {
      debugPrint('QuranPageView _loadFont error (page $page): $e');
      if (mounted) {
        setState(() {
          _fontFamily = _kFontFallback;
          _fontReady = true;
        });
      }
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

  // ── build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggleOverlay,
      behavior: HitTestBehavior.opaque,
      child: _PageFrame(
        header: _PageHeader(
          surahName: widget.surahName,
          isMakki: widget.isMakki,
          juzNumber: widget.juzNumber,
        ),
        footer: _PageFooter(pageNumber: widget.pageNumber),
        child: Stack(
          children: [
            // نیشانەی بارکردن — هەر دووی _loading و !_fontReady
            if (_loading || !_fontReady)
              const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: _kPageBorder1,
                ),
              )
            else
              _PageBody(
                glyphs: _glyphs,
                fontFamily: _fontFamily,
                activeVerseKey: widget.activeVerseKey,
                activeWordIndex: widget.activeWordIndex,
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
//  _PageFrame
// ═══════════════════════════════════════════════════════════════

class _PageFrame extends StatelessWidget {
  final Widget header;
  final Widget footer;
  final Widget child;
  const _PageFrame(
      {required this.header, required this.footer, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF0EAD6),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _kPageBg,
          border: Border.all(color: _kPageBorder1, width: 2.5),
          borderRadius: BorderRadius.circular(3),
          boxShadow: const [
            BoxShadow(
                color: Color(0x30000000), blurRadius: 8, offset: Offset(0, 2)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(1),
          child: Container(
            margin: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              border: Border.all(color: _kPageBorder2, width: 1),
              borderRadius: BorderRadius.circular(1),
            ),
            child: Column(
              children: [
                header,
                const Divider(height: 1, thickness: 1, color: _kDivider),
                Expanded(child: child),
                const Divider(height: 1, thickness: 1, color: _kDivider),
                footer,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  _PageHeader  —  سابت سەرەوە
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
      height: 32,
      color: _kPageHeaderBg,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          _HeaderTag(text: 'جز $juzNumber'),
          const Spacer(),
          Text(
            surahName,
            style: const TextStyle(
              fontFamily: _kUiFont,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _kHeaderText,
            ),
            textDirection: TextDirection.rtl,
          ),
          const Spacer(),
          _HeaderTag(
            text: isMakki ? 'مكية' : 'مدنية',
            color: isMakki ? const Color(0xFF795548) : const Color(0xFF546E7A),
          ),
        ],
      ),
    );
  }
}

class _HeaderTag extends StatelessWidget {
  final String text;
  final Color? color;
  const _HeaderTag({required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? _kHeaderTextSub;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: c.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.withOpacity(0.35), width: 0.7),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: c),
        textDirection: TextDirection.rtl,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  _PageFooter  —  سابت خوارەوە
// ═══════════════════════════════════════════════════════════════

class _PageFooter extends StatelessWidget {
  final int pageNumber;
  const _PageFooter({required this.pageNumber});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 26,
      color: _kPageHeaderBg,
      alignment: Alignment.center,
      child: Text(
        '— $pageNumber —',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: _kHeaderTextSub,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  _PageBody
// ═══════════════════════════════════════════════════════════════

class _PageBody extends StatelessWidget {
  final List<QuranGlyph> glyphs;
  final String? fontFamily;
  final String? activeVerseKey;
  final int? activeWordIndex;
  final void Function(QuranGlyph)? onAyahTap;

  const _PageBody({
    required this.glyphs,
    required this.fontFamily,
    this.activeVerseKey,
    this.activeWordIndex,
    this.onAyahTap,
  });

  @override
  Widget build(BuildContext context) {
    if (glyphs.isEmpty) {
      return const Center(
        child: Text('بێ داتا', style: TextStyle(color: _kHeaderTextSub)),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
        child: SingleChildScrollView(
          // بەڕاستی نابێت scroll بکات — فۆنت خۆی ریز ڕێکدەخات
          physics: const NeverScrollableScrollPhysics(),
          child: Wrap(
            textDirection: TextDirection.rtl,
            alignment: WrapAlignment.start,
            runAlignment: WrapAlignment.start,
            spacing: 0,
            runSpacing: 0,
            children: glyphs.map((g) {
              final isActive = g.verseKey == activeVerseKey;
              return GestureDetector(
                onTap: () => onAyahTap?.call(g),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 1, vertical: 1),
                  decoration: BoxDecoration(
                    color: isActive
                        ? _kHighlight.withOpacity(0.35)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    g.text,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontFamily: fontFamily,
                      fontSize: 18,
                      height: 1.95,
                      // ✅ FIX BUG4: تەنها foreground بەکار بهێنە ئەگەر ئەکتیڤ
                      // هەرگیز color و foreground باهەم نابەکارهێنرێن
                      color: isActive ? null : _kTextColor,
                      foreground: isActive
                          ? (Paint()..color = const Color(0xFF4A2800))
                          : null,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  _PageOverlay
// ═══════════════════════════════════════════════════════════════

class _PageOverlay extends StatelessWidget {
  final String surahName;
  final bool isMakki;
  final int juzNumber;
  final int pageNumber;
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
        color: _kOverlayBg.withOpacity(0.75),
        child: Column(
          children: [
            // ── سەرەوە ──
            GestureDetector(
              onTap: () {},
              child: Container(
                color: _kOverlayBg,
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: _OverlayTopMenu(
                  surahName: surahName,
                  isMakki: isMakki,
                  juzNumber: juzNumber,
                  pageNumber: pageNumber,
                  onClose: onClose,
                ),
              ),
            ),
            const Spacer(),
            // ── خوارەوە: کۆنترۆڵی دەنگ ──
            GestureDetector(
              onTap: () {},
              child: Container(
                color: _kOverlayBg,
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: _OverlayAudioControls(audio: audio),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── مینیۆی سەرەوە ───────────────────────────────────────────────

class _OverlayTopMenu extends StatelessWidget {
  final String surahName;
  final bool isMakki;
  final int juzNumber;
  final int pageNumber;
  final VoidCallback onClose;

  const _OverlayTopMenu({
    required this.surahName,
    required this.isMakki,
    required this.juzNumber,
    required this.pageNumber,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: onClose,
          child: const Icon(Icons.close, color: Colors.white38, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            surahName,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: _kUiFont,
              color: _kOverlayGold,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 10),
        _OverlayMenuBtn(
          icon: Icons.list,
          label: 'سورەکان',
          onTap: () => _openSurahMenu(context),
        ),
        const SizedBox(width: 8),
        _OverlayMenuBtn(
          icon: Icons.headphones,
          label: 'قاری',
          onTap: () => _openReciterPanel(context),
        ),
      ],
    );
  }

  void _openSurahMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _SurahPickerSheet(),
    );
  }

  void _openReciterPanel(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const ReciterPanel(),
    );
  }
}

class _OverlayMenuBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _OverlayMenuBtn(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _kOverlayGold.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
            border:
                Border.all(color: _kOverlayGold.withOpacity(0.5), width: 0.7),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: _kOverlayGold, size: 14),
              const SizedBox(width: 4),
              Text(label,
                  style: const TextStyle(
                      color: _kOverlayGold,
                      fontSize: 10,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );
}

// ── کۆنترۆڵی دەنگ ───────────────────────────────────────────────

class _OverlayAudioControls extends StatelessWidget {
  final QuranAudioService audio;
  const _OverlayAudioControls({required this.audio});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: audio,
      // ✅ FIX BUG3: vk و label لەناو builder — هەر جار ڕیبیلد دەبێت
      builder: (_, __) {
        final vk = audio.currentVerseKey;
        String label = 'کلیک لەئایەتێک بکە بۆ دەست پێکردن';
        if (vk != null) {
          final p = vk.split(':');
          final surah = kSurahList.firstWhere(
            (s) => s.number == int.tryParse(p[0]),
            orElse: () => kSurahList.first,
          );
          label = '${surah.name}  ·  ئایەت ${p[1]}';
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: vk != null ? _kOverlayGold : Colors.white38,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _OvBtn(
                    icon: Icons.skip_previous_rounded, onTap: audio.prevAyah),
                const SizedBox(width: 8),
                // دوگمەی پلەی
                GestureDetector(
                  onTap: audio.isPlaying
                      ? audio.togglePlayPause
                      : (audio.state == QuranPlayState.paused
                          ? audio.togglePlayPause
                          : null),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _kOverlayGold,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: _kOverlayGold.withOpacity(0.3),
                            blurRadius: 8,
                            spreadRadius: 1),
                      ],
                    ),
                    child: Icon(
                      audio.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.black,
                      size: 26,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _OvBtn(icon: Icons.skip_next_rounded, onTap: audio.nextAyah),
                const SizedBox(width: 20),
                _OvToggle(
                  icon: Icons.repeat_one,
                  active: audio.repeatAyah,
                  onTap: () => audio.setRepeatAyah(!audio.repeatAyah),
                ),
                const SizedBox(width: 10),
                _OvToggle(
                  icon: Icons.fast_forward_rounded,
                  active: audio.autoNextAyah,
                  onTap: () => audio.setAutoNextAyah(!audio.autoNextAyah),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _OvBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _OvBtn({required this.icon, this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Icon(icon, color: Colors.white70, size: 24),
      );
}

class _OvToggle extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback? onTap;
  const _OvToggle({required this.icon, required this.active, this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Icon(icon,
            color: active ? _kOverlayGold : Colors.white24, size: 20),
      );
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
  Widget build(BuildContext context) {
    return Container(
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
              color:
                  isActive ? _kHighlight.withOpacity(0.22) : Colors.transparent,
              child: Text(
                g.text,
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontFamily: _kFontFallback,
                  fontSize: 22,
                  color: _kTextColor,
                  height: 2.1,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  _SurahPickerSheet
// ═══════════════════════════════════════════════════════════════

class _SurahPickerSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.88,
        maxChildSize: 0.96,
        minChildSize: 0.4,
        expand: false,
        builder: (_, sc) => Column(
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const Text('سورەکان',
                style: TextStyle(
                    color: _kOverlayGold,
                    fontSize: 15,
                    fontWeight: FontWeight.bold)),
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
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 10),
                        textDirection: TextDirection.rtl),
                    leading: Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                          border: Border.all(
                              color: _kOverlayGold.withOpacity(0.4),
                              width: 0.7),
                          shape: BoxShape.circle),
                      child: Text('${s.number}',
                          style: const TextStyle(
                              color: _kOverlayGold,
                              fontSize: 10,
                              fontWeight: FontWeight.bold)),
                    ),
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

// ═══════════════════════════════════════════════════════════════
//  ReciterPanel  —  هەڵبژاردنی قاری + دانلۆد
// ═══════════════════════════════════════════════════════════════

class ReciterInfo {
  final String id;
  final String name;
  final String style;
  final String baseUrl;
  final String jsonAsset;
  const ReciterInfo({
    required this.id,
    required this.name,
    required this.style,
    required this.baseUrl,
    required this.jsonAsset,
  });
}

/// ✦ قاریانی تر لێرە زیاد بکە
const List<ReciterInfo> kReciters = [
  ReciterInfo(
    id: 'minshawyMurattal',
    name: 'محمد صدیق المنشاوی',
    style: 'مرتل',
    baseUrl: kReciterBaseUrl,
    jsonAsset:
        'assets/quran/ayah-recitation-muhammad-siddiq-al-minshawi-murattal-hafs-959.json',
  ),
  // زیادکردنی قاری تر:
  // ReciterInfo(
  //   id: 'husary',
  //   name: 'محمود خلیل الحصری',
  //   style: 'مرتل',
  //   baseUrl: 'https://YOUR_CDN/husary/',
  //   jsonAsset: 'assets/quran/ayah-recitation-husary.json',
  // ),
];

class ReciterPanel extends StatefulWidget {
  const ReciterPanel({super.key});
  @override
  State<ReciterPanel> createState() => _ReciterPanelState();
}

class _ReciterPanelState extends State<ReciterPanel> {
  final Map<String, _DlState> _dl = {};

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
                color: Colors.white24, borderRadius: BorderRadius.circular(2)),
          ),
          const Text('هەڵبژاردنی قاری',
              style: TextStyle(
                  color: _kOverlayGold,
                  fontSize: 15,
                  fontWeight: FontWeight.bold),
              textDirection: TextDirection.rtl),
          const SizedBox(height: 4),
          const Text('دانلۆد بکە بۆ گوێگرتنی ئۆفلاین',
              style: TextStyle(color: Colors.white38, fontSize: 10),
              textDirection: TextDirection.rtl),
          const SizedBox(height: 14),
          ...kReciters.map((r) => _ReciterTile(
                reciter: r,
                state: _dl[r.id] ?? _DlState.none,
                onDownload: () => _download(r),
              )),
        ],
      ),
    );
  }

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
      debugPrint('Download error: $e');
      if (mounted) setState(() => _dl[r.id] = _DlState.error);
    }
  }
}

enum _DlState { none, downloading, done, error }

class _ReciterTile extends StatelessWidget {
  final ReciterInfo reciter;
  final _DlState state;
  final VoidCallback onDownload;
  const _ReciterTile({
    required this.reciter,
    required this.state,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF242424),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10, width: 0.6),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _kOverlayGold.withOpacity(0.10),
              shape: BoxShape.circle,
              border: Border.all(
                  color: _kOverlayGold.withOpacity(0.35), width: 0.7),
            ),
            child: const Icon(Icons.person, color: _kOverlayGold, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
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
              ],
            ),
          ),
          const SizedBox(width: 12),
          _DlBtn(state: state, onTap: onDownload),
        ],
      ),
    );
  }
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
              color: _kOverlayGold.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _kOverlayGold, width: 0.7),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.download, color: _kOverlayGold, size: 14),
                SizedBox(width: 3),
                Text('دانلۆد',
                    style: TextStyle(color: _kOverlayGold, fontSize: 10)),
              ],
            ),
          ),
        );
      case _DlState.downloading:
        return const SizedBox(
          width: 22,
          height: 22,
          child:
              CircularProgressIndicator(strokeWidth: 1.5, color: _kOverlayGold),
        );
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
