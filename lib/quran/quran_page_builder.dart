import 'package:flutter/material.dart';
import 'quran_models.dart';
import 'quran_audio_service.dart';

// ─── Constants ────────────────────────────────────────────────────────────────

const String kFontBaseUrl = 'https://daryan-m.github.io/fonts';
const int kTotalPages = 604;

// ─── Helper: Kurdish/Arabic numerals ─────────────────────────────────────────

String toKNum(int n) {
  const digits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  return n.toString().split('').map((c) {
    final i = int.tryParse(c);
    return i != null ? digits[i] : c;
  }).join();
}

// ─── Page Header ─────────────────────────────────────────────────────────────

class QuranPageHeader extends StatelessWidget {
  final int juzNumber;
  final SurahInfo? surahInfo;
  final VoidCallback onBack;

  const QuranPageHeader({
    super.key,
    required this.juzNumber,
    required this.surahInfo,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final juzText = 'جزء ${toKNum(juzNumber)}';
    final placeText = surahInfo?.isMakki == true ? 'مکی' : 'مدنی';
    final surahName = surahInfo?.nameArabic ?? '';

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFC2E4C2), Color(0xFFFDF6E3)],
        ),
        border: Border.all(color: const Color(0xFFC2E4C2), width: 1.5),
      ),
      padding: const EdgeInsets.only(left: 4, right: 4, bottom: 4, top: 1),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: GestureDetector(
              onTap: onBack,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFDF6E3), Color(0xFFC2E4C2)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4A7C59).withOpacity(0.4),
                      blurRadius: 8,
                      spreadRadius: 1,
                      offset: const Offset(2, 3),
                    ),
                    const BoxShadow(
                      color: Colors.white,
                      blurRadius: 4,
                      spreadRadius: 0,
                      offset: Offset(-1, -1),
                    ),
                  ],
                ),
                child: const Center(
                  child: Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(
                      Icons.arrow_back_ios,
                      size: 16,
                      color: Color(0xFF215B33),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                children: [
                  TextSpan(
                    text: surahName,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF4A7C59),
                      fontFamily: 'Notonaskh',
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                  TextSpan(
                    text: ' ($placeText)',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6AA17A),
                      fontFamily: 'Notonaskh',
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            width: 60,
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: RichText(
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: juzText,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF4A7C59),
                        fontFamily: 'Notonaskh',
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
// ─── Font Loading Placeholder ─────────────────────────────────────────────────

class FontLoadingPage extends StatelessWidget {
  final double? downloadProgress;
  final VoidCallback onRetry;

  const FontLoadingPage({
    super.key,
    required this.downloadProgress,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final isDownloading = downloadProgress != null;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Color(0xFF4A7C59)),
          const SizedBox(height: 12),
          Text(
            isDownloading
                ? 'فۆنت دادەبەزێت... ${toKNum(((downloadProgress ?? 0) * 100).toInt())}٪'
                : 'فۆنت بەردەست نییە',
            style: const TextStyle(fontSize: 12),
          ),
          if (!isDownloading)
            TextButton(
              onPressed: onRetry,
              child: const Text('دابەزاندن'),
            ),
        ],
      ),
    );
  }
}

// ─── Mushaf Page Lines ────────────────────────────────────────────────────────

class MushafPageLines extends StatelessWidget {
  final List<QuranPageLine> lines;
  final Map<int, QuranWord> wordById;
  final String fontName;
  final QuranAudioService audio;

  const MushafPageLines({
    super.key,
    required this.lines,
    required this.wordById,
    required this.fontName,
    required this.audio,
  });

  @override
  Widget build(BuildContext context) {
    final children = lines.map((l) => _buildLine(l)).toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: const EdgeInsets.only(
          left: 16,
          right: 16,
          top: 0,
          bottom: 76,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }

  Widget _buildLine(QuranPageLine line) {
    switch (line.lineType) {
      case 'surah_name':
        return const SizedBox.shrink();
      case 'basmallah':
        return _buildBasmallahLine(line);
      case 'ayah':
        return _buildAyahLine(line);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildBasmallahLine(QuranPageLine line) {
    if (line.firstWordId != null && line.lastWordId != null) {
      final words = <QuranWord>[];
      for (int id = line.firstWordId!; id <= line.lastWordId!; id++) {
        final w = wordById[id];
        if (w != null) words.add(w);
      }
      if (words.isNotEmpty) {
        return ListenableBuilder(
          listenable: audio,
          builder: (_, __) => _buildWordLine(words, true),
        );
      }
    }
    // Fallback: image basmallah
    return LayoutBuilder(
      builder: (_, constraints) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Image.asset(
            'assets/images/besmelah1.png',
            width: constraints.maxWidth * 0.63,
            height: 45,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  Widget _buildAyahLine(QuranPageLine line) {
    if (line.firstWordId == null || line.lastWordId == null) {
      return const SizedBox(height: 24);
    }

    final words = <QuranWord>[];
    for (int id = line.firstWordId!; id <= line.lastWordId!; id++) {
      final w = wordById[id];
      if (w != null) words.add(w);
    }

    if (words.isEmpty) return const SizedBox(height: 24);

    return ListenableBuilder(
      listenable: audio,
      builder: (_, __) => _buildWordLine(words, line.isCentered),
    );
  }

  Widget _buildWordLine(List<QuranWord> words, bool centered) {
    return SizedBox(
      width: double.infinity,
      child: Wrap(
        textDirection: TextDirection.rtl,
        alignment: WrapAlignment.center,
        runAlignment: WrapAlignment.center,
        children: words.map((w) => _buildWord(w)).toList(),
      ),
    );
  }

  Widget _buildWord(QuranWord word) {
    final isHighlighted =
        audio.isCurrentAyah(word.surah, word.ayah) && audio.hasHighlightedAyah;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => audio.togglePlayPause(word.surah, word.ayah),
      child: Container(
        color: isHighlighted ? const Color(0xFFC2E4C2).withOpacity(0.35) : null,
        padding: const EdgeInsets.symmetric(horizontal: 1),
        child: Text(
          word.text,
          style: TextStyle(
            fontFamily: fontName,
            fontSize: 18,
            color: isHighlighted
                ? const Color(0xFF2D5016)
                : const Color(0xFF1A1A1A),
            height: 1.6,
          ),
        ),
      ),
    );
  }
}

// ─── Bottom Bar ───────────────────────────────────────────────────────────────

class QuranBottomBar extends StatelessWidget {
  final int currentPage;
  final int downloadedFonts;
  final int totalFonts;
  final bool allFontsDone;
  final QuranAudioService audio;
  final List<QuranWord> pageWords;
  final VoidCallback onShowSurahList;
  final VoidCallback onShowJuzList;
  final VoidCallback onShowPageJump;
  final VoidCallback onShowReciterSheet;

  const QuranBottomBar({
    super.key,
    required this.currentPage,
    required this.downloadedFonts,
    required this.totalFonts,
    required this.allFontsDone,
    required this.audio,
    required this.pageWords,
    required this.onShowSurahList,
    required this.onShowJuzList,
    required this.onShowPageJump,
    required this.onShowReciterSheet,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        if (!allFontsDone) _buildFontProgressBanner(),
        _buildMainBar(context),
        _buildPageNumberBadge(),
        _buildTopNotch(),
      ],
    );
  }

  Widget _buildFontProgressBanner() {
    return Positioned(
      top: 28,
      left: 0,
      right: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
            child: LinearProgressIndicator(
              value: (downloadedFonts / totalFonts).clamp(0.0, 1.0),
              minHeight: 3,
              backgroundColor: const Color(0xFF4A7C59).withOpacity(0.15),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFF4A7C59)),
            ),
          ),
          Container(
            color: const Color(0xFF4A7C59).withOpacity(0.08),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(
              'دابەزاندنی لاپەڕەکانی قورئانی پیرۆز ${toKNum(downloadedFonts * 100 ~/ totalFonts)}٪',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                color: const Color(0xFF4A7C59).withOpacity(0.9),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainBar(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 32),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFDF6E3), Color(0xFFC2E4C2)],
        ),
        border: Border.all(color: const Color(0xFFC2E4C2), width: 1.5),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      padding: const EdgeInsets.only(left: 4, right: 4, bottom: 4, top: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _BarButton(
            icon: Icons.person_outline,
            label: 'القاریء',
            onTap: onShowReciterSheet,
          ),
          _BarDivider(),
          _BarButton(
            icon: Icons.menu_book_outlined,
            label: 'السورة',
            onTap: onShowSurahList,
          ),
          _BarDivider(),
          _buildPlayerControls(),
          _BarDivider(),
          _BarButton(
            icon: Icons.layers_outlined,
            label: 'الجزء',
            onTap: onShowJuzList,
          ),
          _BarDivider(),
          _BarButton(
            icon: Icons.open_in_new,
            label: 'الصفحة',
            onTap: onShowPageJump,
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerControls() {
    return ListenableBuilder(
      listenable: audio,
      builder: (_, __) {
        final isPlaying = audio.isPlaying;
        final isPaused = audio.isPaused;
        final isLoading = audio.state == AudioState.loading;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SmallIconButton(
              icon: Icons.skip_previous,
              onTap: () => audio.playPreviousAyah(),
            ),
            const SizedBox(width: 8),
            _CenterBarButton(
              icon: (isPlaying || isLoading) ? Icons.pause : Icons.play_arrow,
              onTap: () {
                if (isPlaying || isLoading) {
                  audio.pause();
                } else if (isPaused) {
                  audio.resume();
                } else if (pageWords.isNotEmpty) {
                  audio.playAyah(pageWords.first.surah, pageWords.first.ayah);
                }
              },
            ),
            const SizedBox(width: 4),
            _CenterBarButton(
              icon: Icons.stop,
              onTap: audio.stop,
            ),
            const SizedBox(width: 8),
            _SmallIconButton(
              icon: Icons.skip_next,
              onTap: () => audio.playNextAyah(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPageNumberBadge() {
    return Positioned(
      bottom: 49,
      child: ClipRect(
        child: Align(
          alignment: Alignment.topCenter,
          heightFactor: 0.5,
          child: Container(
            width: 120,
            height: 50,
            alignment: Alignment.center,
            padding: const EdgeInsets.only(bottom: 18),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.all(Radius.elliptical(16, 16)),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFC2E4C2),
                  Color(0xFFFDF6E3),
                  Color(0xFFC2E4C2),
                ],
              ),
              border: Border.all(color: const Color(0xFFC2E4C2), width: 1.5),
            ),
            child: Text(
              toKNum(currentPage),
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF4A7C59),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopNotch() {
    return Positioned(
      top: 32,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          width: 67,
          height: 4,
          color: const Color(0xFFFDF6E3),
        ),
      ),
    );
  }
}

// ─── Internal Bottom Bar Widgets ──────────────────────────────────────────────

class _BarDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      width: 1,
      color: const Color(0xFF4A7C59).withOpacity(0.4),
    );
  }
}

class _BarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _BarButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF4A7C59), size: 16),
          if (label.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: Color(0xFF4A7C59)),
            ),
          ],
        ],
      ),
    );
  }
}

class _CenterBarButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CenterBarButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFF2B922B),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

class _SmallIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _SmallIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(icon, color: const Color(0xFF4A7C59), size: 20),
    );
  }
}
