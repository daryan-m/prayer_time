import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../utils/constants.dart';
import '../utils/quran_download_progress.dart';
import 'quran_service.dart';

// ==================== دیالۆگی داگرتن ====================
// کاتێک قاریێک داگیرانەکرا و بەکارهێنەر کلیکی لەناوی دەکات

class QuranDownloadDialog extends StatefulWidget {
  final QuranReciter reciter;
  final Color primaryColor;
  final ThemePalette palette;
  final List<QuranSurah> surahs;
  final VoidCallback onDownloadComplete;
  final Future<void> Function()? onUseOnline;
  final bool allowOnline;

  const QuranDownloadDialog({
    super.key,
    required this.reciter,
    required this.primaryColor,
    required this.palette,
    required this.surahs,
    required this.onDownloadComplete,
    this.onUseOnline,
    required this.allowOnline,
  });

  @override
  State<QuranDownloadDialog> createState() => _QuranDownloadDialogState();
}

class _QuranDownloadDialogState extends State<QuranDownloadDialog> {
  bool _downloading = false;
  bool _paused = false;
  int _done = 0;
  int _failed = 0;
  static const int _total = 6236;
  DownloadController? _ctrl;

  Future<void> _start() async {
    await QuranService.clearReciterDownloadComplete(widget.reciter.key);
    final ctrl = DownloadController();
    setState(() {
      _downloading = true;
      _done = 0;
      _failed = 0;
      _ctrl = ctrl;
    });
    await WakelockPlus.enable();
    int iter = 0;
    int done = 0;
    try {
      for (final s in widget.surahs) {
        for (int a = 1; a <= s.ayahCount; a++) {
          if (ctrl.isCancelled) break;
          await ctrl.waitIfPaused();
          if (ctrl.isCancelled) break;
          iter++;
          if (iter % 3 == 0) {
            await Future<void>.delayed(Duration.zero);
          }
          final ok =
              await QuranService.downloadAyah(s.number, a, widget.reciter.key);
          if (ok) {
            done++;
          } else {
            _failed++;
          }
          if (mounted) setState(() => _done = done);
          if (done == 1 || done % 25 == 0) {
            await QuranDownloadProgress.show(
                done, _total, widget.reciter.nameKurdish);
          }
        }
        if (ctrl.isCancelled) break;
      }

      if (!ctrl.isCancelled && mounted) {
        if (done == _total) {
          await QuranService.markReciterDownloadComplete(widget.reciter.key);
        }
        if (done == _total) {
          await QuranDownloadProgress.cancel();
          widget.onDownloadComplete();
        } else {
          setState(() {
            _downloading = false;
            _paused = false;
            _ctrl = null;
          });
          await QuranDownloadProgress.cancel();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  "داگرتن ناتەواوە: ${_total - done} ئایەت دانەگیرا.",
                ),
                backgroundColor: Colors.orange.shade700,
              ),
            );
          }
        }
      }
    } finally {
      await WakelockPlus.disable();
      await QuranDownloadProgress.cancel();
    }
  }

  void _pauseResume() {
    if (_ctrl == null) return;
    if (_paused) {
      _ctrl!.resume();
      setState(() => _paused = false);
    } else {
      _ctrl!.pause();
      setState(() => _paused = true);
    }
  }

  void _cancel() {
    _ctrl?.cancel();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final pc = widget.primaryColor;
    final pal = widget.palette;
    final double progress = _total > 0 ? _done / _total : 0.0;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: pal.drawerBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: pc.withOpacity(0.3)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // هیدەر
          Row(children: [
            Icon(Icons.download_rounded, color: pc, size: 20),
            const SizedBox(width: 8),
            Text("داگرتنی دەنگ",
                style: TextStyle(
                    color: pal.listText,
                    fontSize: 14,
                    fontWeight: FontWeight.bold)),
            const Spacer(),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: Icon(Icons.close,
                  color: pal.listText.withOpacity(0.4), size: 18),
              onPressed: _cancel,
            ),
          ]),
          const SizedBox(height: 10),
          Text(widget.reciter.nameKurdish,
              style: TextStyle(
                  color: pc, fontSize: 14, fontWeight: FontWeight.bold)),
          Text(widget.reciter.nameArabic,
              style: TextStyle(
                  color: pal.listText.withOpacity(0.5), fontSize: 11)),
          const SizedBox(height: 16),

          if (!_downloading) ...[
            Text(
              "دەنگی ئەم قاریئە دانەگیراوە.\nداگرتن پێویستە بۆ خوێندنەوەی ئۆفلاین.",
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: pal.listText.withOpacity(0.7),
                  fontSize: 13,
                  height: 1.6),
            ),

            // ✅ زیادکرا — ئۆنلاین
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: pc,
                side: BorderSide(color: pc.withOpacity(0.4)),
              ),
              icon: Icon(Icons.wifi_rounded, size: 16, color: pc),
              label: const Text("ئۆنلاین"),
              onPressed: () async {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context, rootNavigator: true).pop();
                }
                if (widget.onUseOnline != null) {
                  await widget.onUseOnline!();
                }
              },
            ),

            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: pal.listText.withOpacity(0.5),
                  side: BorderSide(color: pal.listText.withOpacity(0.2)),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text("پاشگەزبوونەوە"),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: pc.withOpacity(0.2),
                  foregroundColor: pc,
                  side: BorderSide(color: pc.withOpacity(0.5)),
                ),
                icon: const Icon(Icons.download_rounded, size: 16),
                label: const Text("داگرتن"),
                onPressed: _start,
              ),
            ]),
          ] else ...[
            // پرۆگرەس بار
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: pal.listText.withOpacity(0.1),
                valueColor:
                    AlwaysStoppedAnimation<Color>(_paused ? Colors.amber : pc),
              ),
            ),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(
                _paused ? 'وەستێنراوە ...' : 'دادەگیرێت...',
                style: TextStyle(
                    color: pal.listText.withOpacity(0.5), fontSize: 10),
              ),
              Text(
                '$_done / $_total ئایەت${_failed > 0 ? " · هەڵە: $_failed" : ""}',
                style: TextStyle(
                    color: pal.listText.withOpacity(0.5), fontSize: 10),
              ),
            ]),
            const SizedBox(height: 12),
            // دوگمەکانی کۆنترۆل
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade300,
                  side: BorderSide(color: Colors.red.withOpacity(0.3)),
                ),
                icon: Icon(Icons.close_rounded,
                    size: 14, color: Colors.red.shade300),
                label: const Text("هەڵوەشاندنەوە"),
                onPressed: _cancel,
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: pc.withOpacity(0.15),
                  foregroundColor: pc,
                  side: BorderSide(color: pc.withOpacity(0.4)),
                ),
                icon: Icon(
                    _paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                    size: 16),
                label: Text(_paused ? "بەردەوامبە" : "وەستان"),
                onPressed: _pauseResume,
              ),
            ]),
          ],
        ]),
      ),
    );
  }
}
