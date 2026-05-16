// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// quran_page_view.dart  — نسخەی چاکسەرکراو
//
// گۆڕانکارییەکان:
//   ✓ QuranPageView (لیست-بەیس) لابراوە — بەکار نایێت
//   ✓ QuranAudioBar: بە تاپ دەکشێتەوە و پلەیەری تەواو دەردەکات
//   ✓ لیستی سورە و قاریئ لەناو پلەیەر
//   ✓ هایلایتی وشە بەردەوام کار دەکات
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'package:flutter/material.dart';
import 'quran_models.dart';

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// QuranAudioBar
//
// دوو حاڵ:
//   collapsed  → تەنها بارێکی تەنگ لەخوارەوە (لەکاتی تاپ کردن دەکشێتەوە)
//   expanded   → پلەیەری تەواو بە لیستی سورە و قاریئ
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class QuranAudioBar extends StatefulWidget {
  final AudioState          audioState;
  final Surah?              currentSurah;
  final VoidCallback        onPlayPause;
  final VoidCallback        onNext;
  final VoidCallback        onPrev;
  final VoidCallback        onStop;
  final VoidCallback        onReciterTap;
  final List<Surah>?        surahs;
  final void Function(int page)? onJumpToPage;

  const QuranAudioBar({
    super.key,
    required this.audioState,
    required this.currentSurah,
    required this.onPlayPause,
    required this.onNext,
    required this.onPrev,
    required this.onStop,
    required this.onReciterTap,
    this.surahs,
    this.onJumpToPage,
  });

  @override
  State<QuranAudioBar> createState() => _QuranAudioBarState();
}

class _QuranAudioBarState extends State<QuranAudioBar>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _ctrl;
  late final Animation<double>   _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 320),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _ctrl.forward();
    } else {
      _ctrl.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isActive = widget.audioState.status != AudioPlaybackState.idle;

    return AnimatedBuilder(
      animation: _anim,
      builder: (ctx, _) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0D2818),
            border: Border(
              top: BorderSide(
                  color: const Color(0xFFD4A853).withOpacity(0.6), width: 1),
            ),
            boxShadow: const [
              BoxShadow(color: Colors.black38, blurRadius: 12, offset: Offset(0, -3)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── بارێکی سەرەوە ── (هەمیشە دیارە)
              _CollapsedBar(
                audioState:   widget.audioState,
                currentSurah: widget.currentSurah,
                onPlayPause:  widget.onPlayPause,
                onNext:       widget.onNext,
                onPrev:       widget.onPrev,
                onToggle:     _toggle,
                isExpanded:   _expanded,
                isActive:     isActive,
              ),

              // ── پلەیەری تەواو ── (کاتی expanded)
              ClipRect(
                child: Align(
                  alignment: Alignment.topCenter,
                  heightFactor: _anim.value,
                  child: _ExpandedPlayer(
                    audioState:   widget.audioState,
                    currentSurah: widget.currentSurah,
                    surahs:       widget.surahs,
                    onPlayPause:  widget.onPlayPause,
                    onNext:       widget.onNext,
                    onPrev:       widget.onPrev,
                    onStop: () {
                      widget.onStop();
                      _toggle(); // داخستن بعد stop
                    },
                    onReciterTap: widget.onReciterTap,
                    onJumpToPage: widget.onJumpToPage,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// _CollapsedBar — بارێکی تەنگ
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _CollapsedBar extends StatelessWidget {
  final AudioState  audioState;
  final Surah?      currentSurah;
  final VoidCallback onPlayPause;
  final VoidCallback onNext;
  final VoidCallback onPrev;
  final VoidCallback onToggle;
  final bool        isExpanded;
  final bool        isActive;

  const _CollapsedBar({
    required this.audioState,
    required this.currentSurah,
    required this.onPlayPause,
    required this.onNext,
    required this.onPrev,
    required this.onToggle,
    required this.isExpanded,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            // ئایکۆنی بکشانەوە
            Icon(
              isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
              color: const Color(0xFFD4A853),
              size: 20,
            ),
            const SizedBox(width: 8),

            // زانیاری سورە
            Expanded(
              child: isActive
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          currentSurah?.nameArabic ?? '',
                          style: const TextStyle(
                            color:      Color(0xFFD4A853),
                            fontSize:   12,
                            fontFamily: 'Amiri',
                            fontWeight: FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'ئایەتی ${audioState.currentAyahNumber ?? ''}',
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 10),
                        ),
                      ],
                    )
                  : const Text(
                      'تاپ بکە بۆ دەستپێکردن',
                      style: TextStyle(color: Colors.white38, fontSize: 11),
                    ),
            ),

            // progress
            if (isActive && audioState.duration.inSeconds > 0) ...[
              SizedBox(
                width: 60,
                child: LinearProgressIndicator(
                  value: audioState.duration.inSeconds > 0
                      ? audioState.position.inSeconds /
                          audioState.duration.inSeconds
                      : 0,
                  color:           const Color(0xFFD4A853),
                  backgroundColor: Colors.white12,
                  minHeight:       2,
                ),
              ),
              const SizedBox(width: 8),
            ],

            // play/pause
            if (isActive) ...[
              _SmallButton(
                icon:      Icons.skip_previous_rounded,
                onPressed: onPrev,
              ),
              _PlayButton(audioState: audioState, onPressed: onPlayPause),
              _SmallButton(
                icon:      Icons.skip_next_rounded,
                onPressed: onNext,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// _ExpandedPlayer — پلەیەری تەواو
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _ExpandedPlayer extends StatelessWidget {
  final AudioState  audioState;
  final Surah?      currentSurah;
  final List<Surah>? surahs;
  final VoidCallback onPlayPause;
  final VoidCallback onNext;
  final VoidCallback onPrev;
  final VoidCallback onStop;
  final VoidCallback onReciterTap;
  final void Function(int page)? onJumpToPage;

  const _ExpandedPlayer({
    required this.audioState,
    required this.currentSurah,
    required this.surahs,
    required this.onPlayPause,
    required this.onNext,
    required this.onPrev,
    required this.onStop,
    required this.onReciterTap,
    this.onJumpToPage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color:   const Color(0xFF0A1F10),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 12),

          // ── ناوی سورە و ئایەت
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentSurah?.nameArabic ?? '—',
                      style: const TextStyle(
                        color:      Color(0xFFD4A853),
                        fontSize:   18,
                        fontFamily: 'Amiri',
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                    Text(
                      currentSurah?.displayName ?? '',
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
              // ژمارەی ئایەت
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color:        Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'ئایەت ${audioState.currentAyahNumber ?? '—'}',
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 12),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ── progress bar
          if (audioState.duration.inSeconds > 0) ...[
            SliderTheme(
              data: SliderThemeData(
                trackHeight:  3,
                thumbShape:   const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                activeTrackColor:   const Color(0xFFD4A853),
                inactiveTrackColor: const Color(0xFFD4A853).withOpacity(0.15),
                thumbColor:         const Color(0xFFD4A853),
                overlayColor:       const Color(0xFFD4A853).withOpacity(0.15),
              ),
              child: Slider(
                value: audioState.position.inSeconds
                    .clamp(0, audioState.duration.inSeconds)
                    .toDouble(),
                max: audioState.duration.inSeconds.toDouble(),
                onChanged: (_) {},
              ),
            ),
            // کات
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_fmt(audioState.position),
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 10)),
                  Text(_fmt(audioState.duration),
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 10)),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],

          // ── کنترۆلەکان
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // stop
              IconButton(
                icon:  const Icon(Icons.stop_rounded, size: 22),
                color: Colors.white38,
                onPressed: onStop,
              ),
              const SizedBox(width: 4),
              _SmallButton(icon: Icons.skip_previous_rounded, onPressed: onPrev),
              const SizedBox(width: 8),
              _PlayButton(audioState: audioState, onPressed: onPlayPause, big: true),
              const SizedBox(width: 8),
              _SmallButton(icon: Icons.skip_next_rounded,     onPressed: onNext),
              const SizedBox(width: 4),
              // قاریئ
              GestureDetector(
                onTap: onReciterTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: const Color(0xFFD4A853).withOpacity(0.4)),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.mic_none_rounded,
                          size: 13, color: Color(0xFFD4A853)),
                      const SizedBox(width: 4),
                      Text(
                        audioState.reciter?.nameEnglish.split(' ').first
                            ?? 'قاریئ',
                        style: const TextStyle(
                            color: Color(0xFFD4A853), fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // ── لیستی سورەکان (ئەگەر هەیە)
          if (surahs != null && surahs!.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(color: Colors.white10, height: 1),
            const SizedBox(height: 8),
            const Align(
              alignment: Alignment.centerRight,
              child: Text(
                'سورەکان',
                style: TextStyle(
                    color: Colors.white38, fontSize: 11),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 110,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: surahs!.length,
                itemBuilder: (_, i) {
                  final s = surahs![i];
                  final isCur = s.id == currentSurah?.id;
                  return GestureDetector(
                    onTap: () => onJumpToPage?.call(s.pageStart),
                    child: Container(
                      width:  72,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: isCur
                            ? const Color(0xFFD4A853).withOpacity(0.12)
                            : Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(10),
                        border: isCur
                            ? Border.all(
                                color: const Color(0xFFD4A853).withOpacity(0.5))
                            : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius:          16,
                            backgroundColor: isCur
                                ? const Color(0xFFD4A853)
                                : Colors.white.withOpacity(0.08),
                            child: Text(
                              '${s.id}',
                              style: TextStyle(
                                color:    isCur ? Colors.white : Colors.white54,
                                fontSize: 10,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            s.nameArabic,
                            style: TextStyle(
                              color:      isCur
                                  ? const Color(0xFFD4A853)
                                  : Colors.white70,
                              fontSize:   11,
                              fontFamily: 'Amiri',
                            ),
                            textAlign: TextAlign.center,
                            maxLines:   1,
                            overflow:   TextOverflow.ellipsis,
                          ),
                          Text(
                            '${s.versesCount} ئایەت',
                            style: const TextStyle(
                                color: Colors.white30, fontSize: 9),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// یارمەتیدەرەکان
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _PlayButton extends StatelessWidget {
  final AudioState  audioState;
  final VoidCallback onPressed;
  final bool         big;
  const _PlayButton({
    required this.audioState,
    required this.onPressed,
    this.big = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = big ? 52.0 : 40.0;
    return Container(
      width:  size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFD4A853),
        boxShadow: [
          BoxShadow(
            color:      const Color(0xFFD4A853).withOpacity(0.3),
            blurRadius: 8,
          ),
        ],
      ),
      child: audioState.isLoading
          ? Padding(
              padding: EdgeInsets.all(big ? 12 : 10),
              child: const CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2),
            )
          : IconButton(
              padding: EdgeInsets.zero,
              icon: Icon(
                audioState.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                color: Colors.white,
                size:  big ? 30 : 22,
              ),
              onPressed: onPressed,
            ),
    );
  }
}

class _SmallButton extends StatelessWidget {
  final IconData     icon;
  final VoidCallback onPressed;
  const _SmallButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) => IconButton(
        icon:      Icon(icon),
        color:     Colors.white70,
        iconSize:  26,
        onPressed: onPressed,
      );
}