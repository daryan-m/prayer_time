// ══════════════════════════════════════════════════════════════════
//  quran_reciter_selector.dart
// ══════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'quran_main.dart';

String _previewUrl(String id) =>
    'https://cdn.islamic.network/quran/audio/128/$id/1.mp3';

class ReciterSelectorSheet extends StatefulWidget {
  final List<Reciter> reciters;
  final Reciter current;
  final void Function(Reciter) onSelected;

  const ReciterSelectorSheet._({
    required this.reciters,
    required this.current,
    required this.onSelected,
  });

  static void show(
    BuildContext context, {
    required List<Reciter> reciters,
    required Reciter current,
    required void Function(Reciter) onSelected,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ReciterSelectorSheet._(
        reciters: reciters,
        current: current,
        onSelected: onSelected,
      ),
    );
  }

  @override
  State<ReciterSelectorSheet> createState() => _ReciterSelectorSheetState();
}

class _ReciterSelectorSheetState extends State<ReciterSelectorSheet> {
  final AudioPlayer _audio = AudioPlayer();
  String? _previewingId;
  bool _audioLoading = false;

  @override
  void dispose() {
    _audio.stop();
    _audio.dispose();
    super.dispose();
  }

  Future<void> _togglePreview(Reciter r) async {
    if (_previewingId == r.id) {
      await _audio.stop();
      setState(() {
        _previewingId = null;
        _audioLoading = false;
      });
      return;
    }
    setState(() {
      _previewingId = r.id;
      _audioLoading = true;
    });
    try {
      await _audio.stop();
      await _audio.play(UrlSource(_previewUrl(r.id)));
      if (mounted) setState(() => _audioLoading = false);
      _audio.onPlayerComplete.listen((_) {
        if (mounted) setState(() => _previewingId = null);
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _previewingId = null;
          _audioLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // ── رەنگەکان گونجاو لەگەڵ چوارچێوەی مصحف ──
    const gold = Color(0xFFD4A853);
    const brown = Color(0xFF3B2410);
    const midBrown = Color(0xFF6B4C2A);
    const bgColor = Color(0xFFF5EDD8); // کرێمی گەرم
    const borderClr = Color(0xFFC09428);

    final maxH = MediaQuery.of(context).size.height * 0.70;

    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        border: Border.all(color: borderClr.withOpacity(0.5), width: 1.0),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 30,
              offset: const Offset(0, -4)),
        ],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // دەستکێشک
        Center(
            child: Container(
          margin: const EdgeInsets.only(top: 10),
          width: 36,
          height: 4,
          decoration: BoxDecoration(
              color: borderClr.withOpacity(0.35),
              borderRadius: BorderRadius.circular(2)),
        )),

        // سەرپۆش
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Row(children: [
            const Icon(Icons.headphones_rounded, color: midBrown, size: 18),
            const SizedBox(width: 8),
            const Text('دەنگی قورئانخوێن',
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600, color: brown)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: borderClr.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: borderClr.withOpacity(0.4), width: 0.7)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.wifi_rounded, color: midBrown, size: 12),
                SizedBox(width: 4),
                Text('ئۆنلاین',
                    style: TextStyle(fontSize: 10, color: midBrown)),
              ]),
            ),
          ]),
        ),

        Divider(height: 1, thickness: 0.5, color: borderClr.withOpacity(0.3)),

        // لیستی قاریئەکان
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.only(top: 6, bottom: 20),
            itemCount: widget.reciters.length,
            itemBuilder: (_, i) => _item(
                widget.reciters[i], gold, brown, midBrown, borderClr, bgColor),
          ),
        ),
      ]),
    );
  }

  Widget _item(Reciter r, Color gold, Color brown, Color midBrown,
      Color borderClr, Color bgColor) {
    final sel = r.id == widget.current.id;
    final prev = _previewingId == r.id;

    return GestureDetector(
      onTap: () {
        _audio.stop();
        widget.onSelected(r);
        Navigator.pop(context);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: sel ? gold.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: sel
                  ? borderClr.withOpacity(0.6)
                  : borderClr.withOpacity(0.15),
              width: sel ? 1.0 : 0.5),
        ),
        child: Row(children: [
          // چەک بۆکس
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: sel ? gold : Colors.transparent,
              border: Border.all(
                  color: sel ? gold : borderClr.withOpacity(0.4), width: 1.5),
            ),
            child: sel
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 13)
                : null,
          ),
          const SizedBox(width: 12),

          // ناوی قاریئ
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(r.name,
                  style: TextStyle(
                      fontFamily: 'Amiri',
                      fontSize: 14,
                      color: sel ? brown : brown,
                      fontWeight: sel ? FontWeight.w600 : FontWeight.normal)),
              const SizedBox(height: 2),
              Text(r.nameKu,
                  style: TextStyle(
                      fontSize: 11, color: midBrown.withOpacity(0.7))),
            ],
          )),

          // دوگمەی Preview
          GestureDetector(
            onTap: () => _togglePreview(r),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    prev ? gold.withOpacity(0.2) : borderClr.withOpacity(0.1),
                border: Border.all(
                    color: prev
                        ? gold.withOpacity(0.6)
                        : borderClr.withOpacity(0.25),
                    width: 0.8),
              ),
              child: _audioLoading && prev
                  ? Padding(
                      padding: const EdgeInsets.all(9),
                      child: CircularProgressIndicator(
                          strokeWidth: 1.5, color: gold))
                  : Icon(prev ? Icons.stop_rounded : Icons.play_arrow_rounded,
                      color: prev ? gold : midBrown, size: 18),
            ),
          ),
        ]),
      ),
    );
  }
}
