// ══════════════════════════════════════════════════════════════════
//  quran_download_manager.dart  —  بەڕێوەبردنی دانلۆد
//
//  شێوازی کار:
//  • هیچ ZIP نییە — هەر لاپەرەیەک جیاوازە (001.svg … 604.svg)
//  • بەزینی ٨ دانلۆد لە یەک کاتدا (parallel)
//  • progress بار + ژمارەی تەواوبوو
//  • ئەگەر هەڵەیەک ڕووی بدا: جارێکی تر هەوڵ دەدرێتەوە
//  • دوای تەواوبوون: خۆکار دادەخات
// ══════════════════════════════════════════════════════════════════

import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const int kTotalPages = 604;

// ── URL بنەڕەتی ──────────────────────────────────────────────────
// ئەمە گۆڕین بۆ raw URL ی ریپۆزیتۆرییەکەت:
const String _kBase = 'https://daryan-m.github.io/quran_pages';

String _pageUrl(int page) => '$_kBase/${page.toString().padLeft(3, '0')}.svg';

const int _kParallel = 8; // چەند دانلۆد لەیەکجار
const int _kRetry = 2; // ژمارەی هەوڵدانەوە بۆ هەر لاپەرە

// ══════════════════════════════════════════════════════════════════
//  QuranDownloadManager  —  سێرڤیسی دانلۆد
// ══════════════════════════════════════════════════════════════════
class QuranDownloadManager {
  Future<Directory> getPagesDirectory() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/quran_svg');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  Future<bool> isDownloaded() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool('quran_svg_downloaded') ?? false;
  }

  Future<int> getLastPage() async {
    final p = await SharedPreferences.getInstance();
    return (p.getInt('quran_svg_last_page') ?? 1).clamp(1, kTotalPages);
  }

  Future<void> saveLastPage(int page) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt('quran_svg_last_page', page);
  }

  /// دانلۆدی هەموو لاپەرەکان
  /// [onProgress]: 0.0 → 1.0   [onDone]: ژمارەی تەواوبوو
  Future<void> downloadAll({
    required Directory dir,
    required void Function(double prog, int done, int total) onProgress,
    required VoidCallback onComplete,
    required void Function(String) onError,
  }) async {
    int done = 0;
    int total = kTotalPages;

    // پیدۆزینی لاپەرەکانی کەمبوو (بوومکەوتووی دانلۆد نەکراوون)
    final needed = <int>[];
    for (int p = 1; p <= total; p++) {
      final f = File('${dir.path}/${p.toString().padLeft(3, '0')}.svg');
      if (f.existsSync()) {
        done++;
        continue;
      }
      needed.add(p);
    }

    if (needed.isEmpty) {
      onComplete();
      return;
    }

    // پاشەکەوتکردنی progress کاروو
    onProgress(done / total, done, total);

    // دانلۆدی parallel
    final queue = needed.iterator;
    bool hasMore = queue.moveNext();
    final workers = <Future<void>>[];

    Future<void> worker() async {
      while (true) {
        int? page;
        if (hasMore) {
          page = queue.current;
          hasMore = queue.moveNext();
        } else {
          break;
        }

        final f = File('${dir.path}/${page.toString().padLeft(3, '0')}.svg');
        bool ok = false;

        for (int t = 0; t <= _kRetry && !ok; t++) {
          try {
            final resp = await http
                .get(Uri.parse(_pageUrl(page)))
                .timeout(const Duration(seconds: 20));
            if (resp.statusCode == 200) {
              f.writeAsBytesSync(resp.bodyBytes);
              ok = true;
            }
          } catch (_) {
            if (t == _kRetry) {
              onError('هەڵە لاپەرەی $page');
            }
            await Future.delayed(const Duration(seconds: 1));
          }
        }
        done++;
        onProgress(done / total, done, total);
      }
    }

    for (int i = 0; i < _kParallel; i++) {
      workers.add(worker());
    }
    await Future.wait(workers);

    // کاتی تەواوبوون
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('quran_svg_downloaded', true);
    onComplete();
  }
}

// ══════════════════════════════════════════════════════════════════
//  QuranDownloadDialog  —  dialog بچووک لەسەر لاپەرەکە
// ══════════════════════════════════════════════════════════════════
class QuranDownloadDialog extends StatefulWidget {
  final Directory pagesDir;
  final VoidCallback onComplete;

  const QuranDownloadDialog._({
    required this.pagesDir,
    required this.onComplete,
  });

  /// نیشاندانی dialog وەک BottomSheet
  static void show(
    BuildContext context, {
    required Directory pagesDir,
    required VoidCallback onComplete,
  }) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          QuranDownloadDialog._(pagesDir: pagesDir, onComplete: onComplete),
    );
  }

  @override
  State<QuranDownloadDialog> createState() => _QuranDownloadDialogState();
}

class _QuranDownloadDialogState extends State<QuranDownloadDialog>
    with SingleTickerProviderStateMixin {
  final _mgr = QuranDownloadManager();

  double _prog = 0;
  int _done = 0;
  bool _dlDone = false;
  bool _canX = false;
  String? _errMsg;

  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _prog = 0;
      _done = 0;
      _dlDone = false;
      _canX = false;
      _errMsg = null;
    });
    await _mgr.downloadAll(
      dir: widget.pagesDir,
      onProgress: (p, d, _) {
        if (mounted) {
          setState(() {
            _prog = p;
            _done = d;
          });
        }
      },
      onComplete: () async {
        if (!mounted) return;
        setState(() {
          _dlDone = true;
          _prog = 1.0;
          _canX = true;
        });
        widget.onComplete();
        await Future.delayed(const Duration(milliseconds: 1400));
        if (mounted) Navigator.pop(context);
      },
      onError: (msg) {
        if (mounted) {
          setState(() {
            _errMsg = msg;
            _canX = true;
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1C1A14) : Colors.white;
    const gold = Color(0xFFD4A853);

    return WillPopScope(
      onWillPop: () async => _canX,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: gold.withOpacity(0.3), width: 0.8),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 28,
                  offset: const Offset(0, -4))
            ],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // ─── دەستکێشک ─────────────────────────────────
            Center(
                child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2)),
            )),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─── سەرپۆش ──────────────────────────────
                  Row(children: [
                    AnimatedBuilder(
                      animation: _pulse,
                      builder: (_, __) => Opacity(
                        opacity: _dlDone ? 1.0 : 0.6 + 0.4 * _pulse.value,
                        child: Icon(
                            _dlDone
                                ? Icons.check_circle_rounded
                                : Icons.download_rounded,
                            color: _dlDone ? Colors.green : gold,
                            size: 20),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'دابەزاندنی لاپەرەکانی قورئانی پیرۆز',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87),
                      ),
                    ),
                    if (_canX)
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Icon(Icons.close_rounded,
                            color: Colors.grey.shade500, size: 19),
                      ),
                  ]),
                  const SizedBox(height: 16),

                  // ─── Progress ─────────────────────────────
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: _prog > 0 ? _prog : null,
                      backgroundColor: gold.withOpacity(0.12),
                      valueColor: const AlwaysStoppedAnimation<Color>(gold),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // ─── ژمارە + % ────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _dlDone
                            ? 'تەواو بوو ✓'
                            : 'دابەزاند: $_done / $kTotalPages',
                        style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white54 : Colors.black45),
                      ),
                      Text(
                        '${(_prog * 100).toInt()}%',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: gold),
                      ),
                    ],
                  ),

                  // ─── هەڵە ─────────────────────────────────
                  if (_errMsg != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: Colors.red.withOpacity(0.25), width: 0.7)),
                      child: Text(_errMsg!,
                          style: const TextStyle(
                              color: Colors.redAccent, fontSize: 11)),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: _start,
                        icon: const Icon(Icons.refresh_rounded, size: 15),
                        label: const Text('دووبارە هەوڵ بدەرەوە'),
                        style: TextButton.styleFrom(
                            foregroundColor: gold,
                            textStyle: const TextStyle(fontSize: 13)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
