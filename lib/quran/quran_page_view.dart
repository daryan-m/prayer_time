// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// quran_page_view.dart
//
// ویجێتی نیشاندانی ئایەتەکان بۆ ئەپی قورئانی پیرۆز
//
// تایبەتمەندیەکان:
//   ✓ نیشاندانی دەقی عوسمانی بە فۆنتی Uthmani
//   ✓ هایلایتی وشە بە رەنگی زەرد کاتی لیدان
//   ✓ وەرگێڕانی کوردی لەژێر هەر ئایەتێک
//   ✓ swipe بۆ گۆڕینی لاپەرە
//   ✓ دوبارەلێدانی ئایەت بە tap
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'package:flutter/material.dart';
import 'quran_models.dart';

// ──────────────────────────────────────────
// ویجێتی لاپەرەی سورە
// ──────────────────────────────────────────

class QuranPageView extends StatelessWidget {
  final List<Ayah> ayahs;
  final Surah surah;
  final AudioState audioState;
  final void Function(Ayah) onAyahTap;
  final VoidCallback? onSwipeLeft; // لاپەرەی داهاتوو
  final VoidCallback? onSwipeRight; // لاپەرەی پێشوو

  const QuranPageView({
    super.key,
    required this.ayahs,
    required this.surah,
    required this.audioState,
    required this.onAyahTap,
    this.onSwipeLeft,
    this.onSwipeRight,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity! < -300) onSwipeLeft?.call();
        if (details.primaryVelocity! > 300) onSwipeRight?.call();
      },
      child: Container(
        color: const Color(0xFFFDF6E3), // کاغەزی کۆن
        child: Column(
          children: [
            // ─── سەرووی سورە
            _SurahHeader(surah: surah),

            // ─── ئایەتەکان
            Expanded(
              child: ListView.builder(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: ayahs.length,
                itemBuilder: (context, index) {
                  final ayah = ayahs[index];
                  final isPlaying = audioState.currentSurahId == surah.id &&
                      audioState.currentAyahNumber == ayah.numberInSurah &&
                      audioState.isPlaying;

                  return _AyahCard(
                    ayah: ayah,
                    isCurrentlyPlaying: isPlaying,
                    highlightedWordIndex:
                        isPlaying ? audioState.highlightedWordIndex : null,
                    onTap: () => onAyahTap(ayah),
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
// سەرووی سورە
// ──────────────────────────────────────────

class _SurahHeader extends StatelessWidget {
  final Surah surah;
  const _SurahHeader({required this.surah});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1B4332), Color(0xFF2D6A4F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          // ناوی عەرەبی
          Text(
            surah.nameArabic,
            style: const TextStyle(
              fontFamily: 'Uthmanic',
              fontSize: 28,
              color: Color(0xFFD4A853),
              fontWeight: FontWeight.bold,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
          ),

          const SizedBox(height: 4),

          // ناوی کوردی
          Text(
            surah.displayName,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 6),

          // زانیاری
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _InfoChip(
                label: surah.isMakki ? 'مەکی' : 'مەدەنی',
                icon: Icons.location_on_outlined,
              ),
              const SizedBox(width: 12),
              _InfoChip(
                label: '${surah.versesCount} ئایەت',
                icon: Icons.format_list_numbered,
              ),
            ],
          ),

          const SizedBox(height: 14),

          // بەسمەڵە — بۆ هەموو سورە جگە لە توبە و فاتیحە
          if (surah.id != 1 && surah.id != 9)
            const Text(
              'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
              style: TextStyle(
                fontFamily: 'Uthmanic',
                fontSize: 20,
                color: Color(0xFFD4A853),
                height: 1.8,
              ),
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
            ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final IconData icon;
  const _InfoChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white60),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────
// کارتی ئایەت
// ──────────────────────────────────────────

class _AyahCard extends StatelessWidget {
  final Ayah ayah;
  final bool isCurrentlyPlaying;
  final int? highlightedWordIndex;
  final VoidCallback onTap;

  const _AyahCard({
    required this.ayah,
    required this.isCurrentlyPlaying,
    required this.highlightedWordIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isCurrentlyPlaying
              ? const Color(0xFFD4A853).withOpacity(0.08)
              : Colors.white.withOpacity(0.6),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isCurrentlyPlaying
                ? const Color(0xFFD4A853).withOpacity(0.6)
                : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ─── ژمارەی ئایەت
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // ژمارە لە چەپ
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCurrentlyPlaying
                        ? const Color(0xFFD4A853)
                        : const Color(0xFF2D6A4F).withOpacity(0.1),
                  ),
                  child: Center(
                    child: Text(
                      '${ayah.numberInSurah}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isCurrentlyPlaying
                            ? Colors.white
                            : const Color(0xFF2D6A4F),
                      ),
                    ),
                  ),
                ),

                // ئایکۆنی سەجدە
                if (ayah.sajda)
                  const Icon(Icons.arrow_downward,
                      color: Color(0xFFD4A853), size: 16),
              ],
            ),

            const SizedBox(height: 10),

            // ─── دەقی عوسمانی + هایلایت
            Directionality(
              textDirection: TextDirection.rtl,
              child: _buildArabicText(),
            ),

            // ─── وەرگێڕانی کوردی
            if (ayah.textKurdish != null && ayah.textKurdish!.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Divider(height: 1, color: Color(0xFFE0D5B0)),
              const SizedBox(height: 8),
              Text(
                ayah.textKurdish!,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF4A4A4A),
                  height: 1.7,
                  fontFamily: 'Noto Sans Arabic', // یان فۆنتی کوردی
                ),
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildArabicText() {
    // دەقی عوسمانی بۆ وشە جیابکەینەوە
    final words = ayah.textUthmani.split(' ');

    if (highlightedWordIndex == null || !isCurrentlyPlaying) {
      // بێ هایلایت
      return Text(
        ayah.textUthmani,
        style: const TextStyle(
          fontFamily: 'Uthmanic',
          fontSize: 22,
          color: Color(0xFF1A1A1A),
          height: 2.0,
        ),
        textAlign: TextAlign.justify,
      );
    }

    // هایلایتی وشە
    return RichText(
      textAlign: TextAlign.justify,
      text: TextSpan(
        children: words.asMap().entries.map((entry) {
          final i = entry.key;
          final word = entry.value;
          final isHighlighted = i == highlightedWordIndex;

          return TextSpan(
            children: [
              WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                  decoration: isHighlighted
                      ? BoxDecoration(
                          color: const Color(0xFFD4A853).withOpacity(0.3),
                          borderRadius: BorderRadius.circular(4),
                        )
                      : null,
                  child: Text(
                    i < words.length - 1 ? '$word ' : word,
                    style: TextStyle(
                      fontFamily: 'Uthmanic',
                      fontSize: 22,
                      height: 2.0,
                      color: isHighlighted
                          ? const Color(0xFF8B5E00)
                          : const Color(0xFF1A1A1A),
                      fontWeight:
                          isHighlighted ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ──────────────────────────────────────────
// بارەی کنترۆلی دەنگ (لەژێر سکرین)
// ──────────────────────────────────────────

class QuranAudioBar extends StatelessWidget {
  final AudioState audioState;
  final Surah? currentSurah;
  final VoidCallback onPlayPause;
  final VoidCallback onNext;
  final VoidCallback onPrev;
  final VoidCallback onStop;
  final VoidCallback onReciterTap;

  const QuranAudioBar({
    super.key,
    required this.audioState,
    required this.currentSurah,
    required this.onPlayPause,
    required this.onNext,
    required this.onPrev,
    required this.onStop,
    required this.onReciterTap,
  });

  @override
  Widget build(BuildContext context) {
    final isVisible = audioState.status != AudioPlaybackState.idle;
    if (!isVisible) return const SizedBox.shrink();

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1B4332),
        border: Border(
          top: BorderSide(color: Color(0xFFD4A853), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ─── progress bar
          if (audioState.duration.inMilliseconds > 0)
            SliderTheme(
              data: SliderThemeData(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                activeTrackColor: const Color(0xFFD4A853),
                inactiveTrackColor: const Color(0xFFD4A853).withOpacity(0.2),
                thumbColor: const Color(0xFFD4A853),
                overlayColor: const Color(0xFFD4A853).withOpacity(0.15),
              ),
              child: Slider(
                value: audioState.position.inSeconds.toDouble(),
                max: audioState.duration.inSeconds.toDouble(),
                onChanged: (_) {}, // بۆ ئێستا read-only
              ),
            ),

          // ─── زانیاری + کنترۆلەکان
          Row(
            children: [
              // ناوی سورە + ئایەت
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentSurah?.displayName ?? '',
                      style: const TextStyle(
                        color: Color(0xFFD4A853),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'ئایەتی ${audioState.currentAyahNumber ?? ''}',
                      style:
                          const TextStyle(color: Colors.white60, fontSize: 11),
                    ),
                  ],
                ),
              ),

              // کنترۆلەکان
              IconButton(
                icon: const Icon(Icons.skip_previous_rounded),
                color: Colors.white70,
                iconSize: 28,
                onPressed: onPrev,
              ),

              // play/pause
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFD4A853),
                ),
                child: audioState.isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : IconButton(
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          audioState.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                        onPressed: onPlayPause,
                      ),
              ),

              IconButton(
                icon: const Icon(Icons.skip_next_rounded),
                color: Colors.white70,
                iconSize: 28,
                onPressed: onNext,
              ),

              // بتونی قاریئ
              GestureDetector(
                onTap: onReciterTap,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color(0xFFD4A853).withOpacity(0.5),
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    audioState.reciter?.nameEnglish.split(' ').first ?? 'قاریئ',
                    style:
                        const TextStyle(color: Color(0xFFD4A853), fontSize: 10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
