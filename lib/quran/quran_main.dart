// ══════════════════════════════════════════════════════════════════
//  quran_main.dart  —  هەماهەنگکەری سەرەکی بەشی قورئان
//
//  شێوازی کار:
//  • یەکەمجار  → لاپەرەی ١ یەکسەر + dialog دانلۆد لە پاشەوە
//  • جارەکانی تر → ئاخرین لاپەرەی سەیرکراو
//  • بتونی قاریئ لە top bar
// ══════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import 'quran_download_manager.dart';
import 'quran_page_viewer.dart';
import 'quran_reciter_selector.dart';

// ─── ثابتەکان ────────────────────────────────────────────────────
const int kTotalPages = 604;
const String _kPrefLastPage = 'quran_svg_last_page';
const String _kPrefDownloaded = 'quran_svg_downloaded';
const String _kPrefReciter = 'quran_reciter_id';

/// مۆدێلی قاریئ
class Reciter {
  final String id; // alquran.cloud identifier
  final String name; // ناوی عەرەبی
  final String nameKu; // ناوی کوردی

  const Reciter({
    required this.id,
    required this.name,
    required this.nameKu,
  });
}

const List<Reciter> kReciters = [
  Reciter(id: 'ar.alafasy', name: 'مشاری العفاسی', nameKu: 'مەشاری ئەلعەفاسی'),
  Reciter(
      id: 'ar.abdurrahmaansudais',
      name: 'عبدالرحمن السديس',
      nameKu: 'عەبدولرەحمان سودەیس'),
  Reciter(id: 'ar.shaatree', name: 'أبو بكر الشاطري', nameKu: 'ئەبوبەکر شاتری'),
  Reciter(id: 'ar.husary', name: 'محمود خليل الحصري', nameKu: 'مەحمود حوسەری'),
  Reciter(id: 'ar.minshawi', name: 'محمد صديق المنشاوي', nameKu: 'مەنشاوی'),
  Reciter(id: 'ar.mahermuaiqly', name: 'ماهر المعيقلي', nameKu: 'ماهر مەعیقلی'),
];

// ══════════════════════════════════════════════════════════════════
//  QuranMain  —  entry point
// ══════════════════════════════════════════════════════════════════
class QuranMain extends StatefulWidget {
  const QuranMain({super.key});

  @override
  State<QuranMain> createState() => _QuranMainState();
}

class _QuranMainState extends State<QuranMain>
    with SingleTickerProviderStateMixin {
  // ─── سێرڤیسەکان ──────────────────────────────────────────────

  // ─── دۆخ ─────────────────────────────────────────────────────
  bool _ready = false;
  int _initialPage = 1;
  Directory? _pagesDir;
  bool _downloaded = false;
  Reciter _reciter = kReciters[0];

  // ─── ئانیمەیشنی داخڵبوون ─────────────────────────────────────
  late AnimationController _entryCtrl;
  late Animation<double> _entryFade;
  late Animation<Offset> _entrySlide;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _entryFade = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _entrySlide = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut));

    _init();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    super.dispose();
  }

  // ─── ئامادەکردن ──────────────────────────────────────────────
  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/quran_svg');
    if (!dir.existsSync()) dir.createSync(recursive: true);

    final downloaded = prefs.getBool(_kPrefDownloaded) ?? false;
    final lastPage = prefs.getInt(_kPrefLastPage) ?? 1;
    final reciterId = prefs.getString(_kPrefReciter) ?? kReciters[0].id;

    final verified = downloaded &&
        File('${dir.path}/001.svg').existsSync() &&
        File('${dir.path}/604.svg').existsSync();

    final reciter = kReciters.firstWhere((r) => r.id == reciterId,
        orElse: () => kReciters[0]);

    if (!mounted) return;
    setState(() {
      _pagesDir = dir;
      _downloaded = verified;
      _reciter = reciter;
      _initialPage = verified ? lastPage.clamp(1, kTotalPages) : 1;
      _ready = true;
    });

    _entryCtrl.forward();

    // یەکەمجار: dialog دانلۆد
    if (!verified) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showDownloadDialog();
      });
    }
  }

  // ─── پاشەکەوتکردن ────────────────────────────────────────────
  Future<void> _savePage(int page) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kPrefLastPage, page);
  }

  Future<void> _saveReciter(Reciter r) async {
    setState(() => _reciter = r);
    final p = await SharedPreferences.getInstance();
    await p.setString(_kPrefReciter, r.id);
  }

  // ─── Dialog دانلۆد ───────────────────────────────────────────
  void _showDownloadDialog() {
    if (_pagesDir == null) return;
    QuranDownloadDialog.show(
      context,
      pagesDir: _pagesDir!,
      onComplete: () async {
        final p = await SharedPreferences.getInstance();
        await p.setBool(_kPrefDownloaded, true);
        if (mounted) setState(() => _downloaded = true);
      },
    );
  }

  // ─── هەڵبژاردنی قاریئ ────────────────────────────────────────
  void _openReciter() {
    ReciterSelectorSheet.show(
      context,
      reciters: kReciters,
      current: _reciter,
      onSelected: _saveReciter,
    );
  }

  // ─── build ───────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (!_ready || _pagesDir == null) {
      return const _QuranSplash();
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xFF0D0B08),
      ),
      child: FadeTransition(
        opacity: _entryFade,
        child: SlideTransition(
          position: _entrySlide,
          child: QuranPageViewer(
            pagesDir: _pagesDir!,
            initialPage: _initialPage,
            totalPages: kTotalPages,
            reciter: _reciter,
            downloaded: _downloaded,
            onPageChanged: _savePage,
            onReciterTap: _openReciter,
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  _QuranSplash
// ══════════════════════════════════════════════════════════════════
class _QuranSplash extends StatelessWidget {
  const _QuranSplash();
  @override
  Widget build(BuildContext context) => const Scaffold(
        backgroundColor: Color(0xFF0D0B08),
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.menu_book_outlined, color: Color(0xFFD4A853), size: 52),
            SizedBox(height: 20),
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                  color: Color(0xFFD4A853), strokeWidth: 2),
            ),
          ]),
        ),
      );
}
