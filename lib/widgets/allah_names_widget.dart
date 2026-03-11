import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

// ==================== داتای ٩٩ ناوی خوای گەورە ====================

class AllahName {
  final String name;
  final String meaning;
  final Color color;
  const AllahName(this.name, this.meaning, this.color);
}

const List<AllahName> allahNames = [
  AllahName("اللَّهُ",              "خوا — تەنها هاوبەشی لەگەڵ نییە",                Color(0xFF6366F1)),
  AllahName("الرَّحْمَٰنُ",         "زۆر بەخشەندە — بۆ هەموو دابین دەکات",          Color(0xFF8B5CF6)),
  AllahName("الرَّحِيمُ",           "بەخشەندەی هەمیشەیی — بۆ باوەڕداران",          Color(0xFF0EA5E9)),
  AllahName("الْمَلِكُ",            "پاشا — خاوەنی تەواوی مولکە",                   Color(0xFFF59E0B)),
  AllahName("الْقُدُّوسُ",          "پیرۆز — دووری لە هەموو کێشەیەک",              Color(0xFF10B981)),
  AllahName("السَّلَامُ",           "سەرچاوەی سەلامەتی — داری نازاوی",             Color(0xFF22D3EE)),
  AllahName("الْمُؤْمِنُ",          "ئیمانی بەخشەر — پشتیوانی باوەڕداران",         Color(0xFF14B8A6)),
  AllahName("الْمُهَيْمِنُ",        "پاراستوان — سەیری هەموو شتێک دەکات",          Color(0xFFEF4444)),
  AllahName("الْعَزِيزُ",           "بەهێز — شکاندنی نابێت",                       Color(0xFF84CC16)),
  AllahName("الْجَبَّارُ",          "توانای گەورە — ئیرادەی هیچ ئەگەڕێتەوە",       Color(0xFFF97316)),
  AllahName("الْمُتَكَبِّرُ",       "بەرزترین — سەروو هەموو شتێک",                 Color(0xFF8B5CF6)),
  AllahName("الْخَالِقُ",           "دروستکەر — لە نێودا دروستکراو",               Color(0xFF0EA5E9)),
  AllahName("الْبَارِئُ",           "دروستکەری ئاڵۆز — بەرهەمی بێ نموونە",         Color(0xFF10B981)),
  AllahName("الْمُصَوِّرُ",         "شێوەدەر — شێوەی هەر شتێک بۆ دادەمەزرێت",     Color(0xFFEC4899)),
  AllahName("الْغَفَّارُ",          "زۆر بەخشەندەی گوناهەکان — دووبارە دووبارە",   Color(0xFFFFD700)),
  AllahName("الْقَهَّارُ",          "سەروەری داگیرکار — هیچ ئەگەڕێتەوە",          Color(0xFF22D3EE)),
  AllahName("الْوَهَّابُ",          "بەخشەری زۆر — بەبێ پشتیوانی",                Color(0xFF6366F1)),
  AllahName("الرَّزَّاقُ",          "رزقدەر — رزقی هەموو موجوداتێک دادەمەزرێت",   Color(0xFF14B8A6)),
  AllahName("الْفَتَّاحُ",          "کردنەوەر — هەموو دەروازەیەک کردەوە",          Color(0xFFF59E0B)),
  AllahName("الْعَلِيمُ",           "زانای هەموو شت — هیچ نهێنیەک نییە",          Color(0xFFEF4444)),
  AllahName("الْقَابِضُ",           "گرتنەوەر — رزق لە دەست کێ دەوێت دەگرێتەوە", Color(0xFF84CC16)),
  AllahName("الْبَاسِطُ",           "فراوانکەر — رزق بۆ کێ دەوێت فراوان دەکات",   Color(0xFFF97316)),
  AllahName("الْخَافِضُ",           "دابەزێنەر — هەر بەرزێک دابەزێنێت",           Color(0xFF8B5CF6)),
  AllahName("الرَّافِعُ",           "بەرزکەر — ئەو دەوێت بەرز دەکات",             Color(0xFF0EA5E9)),
  AllahName("الْمُعِزُّ",           "ئیزەتدەر — بە کێ دەوێت کەرامەت دەدات",       Color(0xFF10B981)),
  AllahName("الْمُذِلُّ",           "بەزاوکەر — بەهێزی دواناو دەکات",             Color(0xFFEC4899)),
  AllahName("السَّمِيعُ",           "گوێگر — گوێی هەموو دەنگێک",                  Color(0xFFFFD700)),
  AllahName("الْبَصِيرُ",           "بینا — بینینی هەموو شتێک",                   Color(0xFF22D3EE)),
  AllahName("الْحَكَمُ",            "داوەر — حوکمی تەنها دەست بەسەر",             Color(0xFF6366F1)),
  AllahName("الْعَدْلُ",            "دادگەر — بێ لایەنگیری",                      Color(0xFF14B8A6)),
  AllahName("اللَّطِيفُ",           "نەرم و باریک — وردییە نهێنییەکانی دەزانێت",  Color(0xFFF59E0B)),
  AllahName("الْخَبِيرُ",           "ئاگادار — لە ناوەوەی هەموو شت",              Color(0xFFEF4444)),
  AllahName("الْحَلِيمُ",           "سەبرکار — لە سزا نائەچێت",                   Color(0xFF84CC16)),
  AllahName("الْعَظِيمُ",           "گەورەترین — بەرزی نەگەیشتنی",               Color(0xFFF97316)),
  AllahName("الْغَفُورُ",           "بەخشەندە — گوناه دەپۆشێت",                  Color(0xFF8B5CF6)),
  AllahName("الشَّكُورُ",           "قەدردان — سوپاسی کارە باشەکان دەکات",        Color(0xFF0EA5E9)),
  AllahName("الْعَلِيُّ",           "بەرز — سەرووی هەموو",                        Color(0xFF10B981)),
  AllahName("الْكَبِيرُ",           "گەورە — بەرزیی گەورەیی",                    Color(0xFFEC4899)),
  AllahName("الْحَفِيظُ",           "پارێزەر — هەموو شت پارێزرێت",               Color(0xFFFFD700)),
  AllahName("الْمُقِيتُ",           "خواردن و هێزدەر — هیچ موجودێک بێ ئەو نازیو", Color(0xFF22D3EE)),
  AllahName("الْحَسِيبُ",           "ژمارەکەر — حسابی هەموو کارێک دەکات",         Color(0xFF6366F1)),
  AllahName("الْجَلِيلُ",           "بەرزی شکۆ — ئەوروو بەرزترین",               Color(0xFF14B8A6)),
  AllahName("الْكَرِيمُ",           "سەخی — بەخشینی بێ سنوور",                   Color(0xFFF59E0B)),
  AllahName("الرَّقِيبُ",           "چاودێر — هیچ شت لێی نهێنی نییە",            Color(0xFFEF4444)),
  AllahName("الْمُجِيبُ",           "وەڵامدەوەر — داواکارانی وەڵام دەداتەوە",    Color(0xFF84CC16)),
  AllahName("الْوَاسِعُ",           "فراوان — زانینی فراوانترە",                  Color(0xFFF97316)),
  AllahName("الْحَكِيمُ",           "زیرەک — هەموو کار بەمانای درستە",            Color(0xFF8B5CF6)),
  AllahName("الْوَدُودُ",           "خۆشەویست — باوەڕدارانی خۆشدەوێت",           Color(0xFF0EA5E9)),
  AllahName("الْمَجِيدُ",           "شکۆمەند — شکۆ و بزوتنەوەیەکی نایاب",        Color(0xFF10B981)),
  AllahName("الْبَاعِثُ",           "هەستەوەردەر — لە مردن دەهەستێنێت",          Color(0xFFEC4899)),
  AllahName("الشَّهِيدُ",           "شایەت — شایەتی هەموو شتێکە",                Color(0xFFFFD700)),
  AllahName("الْحَقُّ",             "ڕاستی — بونی تەواو و ڕاستی",               Color(0xFF22D3EE)),
  AllahName("الْوَكِيلُ",           "پشتێوان — واکیلی هەموو شت",                  Color(0xFF6366F1)),
  AllahName("الْقَوِيُّ",           "بەهێزترین — هێزی تەواو",                    Color(0xFF14B8A6)),
  AllahName("الْمَتِينُ",           "بەرپایەوە — هێزی نەبڕاو",                   Color(0xFFF59E0B)),
  AllahName("الْوَلِيُّ",           "خۆشەویستانەترین دۆست — باوەڕداران دەپارێزێت", Color(0xFFEF4444)),
  AllahName("الْحَمِيدُ",           "ستایشلێکراو — تەنها ستایش بۆ",              Color(0xFF84CC16)),
  AllahName("الْمُحْصِي",           "ژمارەکەر — هیچ شت لە ژمارەی نییە",          Color(0xFFF97316)),
  AllahName("الْمُبْدِئُ",          "دەستپێکەر — دروستکردنی هەموو شت",            Color(0xFF8B5CF6)),
  AllahName("الْمُعِيدُ",           "گەڕاندنەوەر — لە مردن دووبارە دەگەڕێنێتەوە", Color(0xFF0EA5E9)),
  AllahName("الْمُحْيِي",           "ژیاندەر — ژیان دەبەخشێت",                   Color(0xFF10B981)),
  AllahName("الْمُمِيتُ",           "مرژاوەر — مردن دەبەخشێت",                   Color(0xFFEC4899)),
  AllahName("الْحَيُّ",             "ژیوا — هەمیشەی ژیانی هەیە",                 Color(0xFFFFD700)),
  AllahName("الْقَيُّومُ",          "پارێزگاری هەمیشەیی — هەموو شت بەسەر",       Color(0xFF22D3EE)),
  AllahName("الْوَاجِدُ",           "دۆزینەوەر — هەموو شت دادەنرێت",             Color(0xFF6366F1)),
  AllahName("الْمَاجِدُ",           "شکۆمەندی گەورە — شکۆی بێ نموونە",           Color(0xFF14B8A6)),
  AllahName("الْوَاحِدُ",           "تەنها — تەنها خوا",                         Color(0xFFF59E0B)),
  AllahName("الْأَحَدُ",            "یەکەم — بی هاوتا",                          Color(0xFFEF4444)),
  AllahName("الصَّمَدُ",            "بێ پێویست — هەموو بەسەر دەگات",             Color(0xFF84CC16)),
  AllahName("الْقَادِرُ",           "توانا — بەسەر هەموو شت",                    Color(0xFFF97316)),
  AllahName("الْمُقْتَدِرُ",        "بەهێزی کامل — هیچ ئەگەڕێتەوە",             Color(0xFF8B5CF6)),
  AllahName("الْمُقَدِّمُ",         "پێشخستنەر — بە کێ دەوێت پێش دەخات",        Color(0xFF0EA5E9)),
  AllahName("الْمُؤَخِّرُ",         "دواخستنەر — بە کێ دەوێت دواتر دەخات",      Color(0xFF10B981)),
  AllahName("الْأَوَّلُ",           "یەکەم — پێش هەموو شتێک بووە",              Color(0xFFEC4899)),
  AllahName("الْآخِرُ",             "کۆتایی — دوای هەموو شتێک دەمێنێتەوە",      Color(0xFFFFD700)),
  AllahName("الظَّاهِرُ",           "ئاشکرا — بە نیشانەکانی ئاشکرایە",          Color(0xFF22D3EE)),
  AllahName("الْبَاطِنُ",           "نهێنی — نهێنیی هیچ شتێک لێی نییە",        Color(0xFF6366F1)),
  AllahName("الْوَالِي",            "پاراستوان — کارگێڕی هەموو شتێک",            Color(0xFF14B8A6)),
  AllahName("الْمُتَعَالِي",        "بەرزترین — بەرزی نەگەیشتنی",               Color(0xFFF59E0B)),
  AllahName("الْبَرُّ",             "باشترین — باشیی و خێریی",                   Color(0xFFEF4444)),
  AllahName("التَّوَّابُ",          "گەڕانەوەی هەمیشەیی — تەوبەی قبووڵ دەکات",  Color(0xFF84CC16)),
  AllahName("الْمُنْتَقِمُ",        "تۆڕمەگر — سزا دەدات",                      Color(0xFFF97316)),
  AllahName("الْعَفُوُّ",           "لێخۆشبووەر — گوناه دەبەخشێت",             Color(0xFF8B5CF6)),
  AllahName("الرَّؤُوفُ",           "زۆر برا — نەرمی و بزوتنەوەی زۆر",          Color(0xFF0EA5E9)),
  AllahName("مَالِكُ الْمُلْكِ",    "خاوەنی هەموو مولک — هیچ بەشداریبوون نییە", Color(0xFF10B981)),
  AllahName("ذُو الْجَلَالِ",       "خاوەن شکۆ و کەرەم — شایستەی ستایشە",       Color(0xFFEC4899)),
  AllahName("الْمُقْسِطُ",          "دادپەروەر — دادگەری پارەزرێت",             Color(0xFFFFD700)),
  AllahName("الْجَامِعُ",           "کۆکەرەوە — لە رۆژی دادگا کۆ دەکاتەوە",    Color(0xFF22D3EE)),
  AllahName("الْغَنِيُّ",           "بێ پێویست — پێویستی بە هیچ نییە",          Color(0xFF6366F1)),
  AllahName("الْمُغْنِي",           "دەوڵەمەندکەر — بێ پێویستی دادەمەزرێت",    Color(0xFF14B8A6)),
  AllahName("الْمَانِعُ",           "بەرگریکەر — زیان دەبەستێت",               Color(0xFFF59E0B)),
  AllahName("الضَّارُّ",            "زیانگەیاندەر — بە کێ دەوێت",              Color(0xFFEF4444)),
  AllahName("النَّافِعُ",           "سوودگەیاندەر — بە کێ دەوێت",              Color(0xFF84CC16)),
  AllahName("النُّورُ",             "ڕووناکی — ئاسمان و زەوی ڕووناک دەکات",    Color(0xFFF97316)),
  AllahName("الْهَادِي",            "ڕێنوێن — ڕێنوێنی باوەڕداران",             Color(0xFF8B5CF6)),
  AllahName("الْبَدِيعُ",           "دروستکەری بێ نموونە — هیچ نموونەیەک نەبوو", Color(0xFF0EA5E9)),
  AllahName("الْبَاقِي",            "مانەوەر — هەمیشە دەمێنێتەوە",             Color(0xFF10B981)),
  AllahName("الْوَارِثُ",           "میراتخۆر — دوای هەموو شت دەمێنێتەوە",     Color(0xFFEC4899)),
  AllahName("الرَّشِيدُ",           "ڕێنمابوون — هەموو کار بەڕێکی درستە",      Color(0xFFFFD700)),
  AllahName("الصَّبُورُ",           "سەبرکار — لە سزا نائەچێت",               Color(0xFF22D3EE)),
];

// ==================== ویدجەتی ناوەکانی خوا ====================

class AllahNamesDialog extends StatefulWidget {
  final Color primaryColor;
  const AllahNamesDialog({super.key, required this.primaryColor});

  @override
  State<AllahNamesDialog> createState() => _AllahNamesDialogState();
}

class _AllahNamesDialogState extends State<AllahNamesDialog> {
  final AudioPlayer _player = AudioPlayer();
  final ScrollController _scrollCtrl = ScrollController();

  bool _isPlaying = false;
  bool _isLoading = false;
  int _currentIndex = -1;
  Duration _position = Duration.zero;
  Duration _total = Duration.zero;

  // ── timestamp ئۆتۆماتیک بەپێی درێژی فایلەکە ──
  List<double> _getTimestamps() {
    if (_total == Duration.zero) {
      return List.generate(99, (i) => i * 16.0);
    }
    final double totalSec = _total.inSeconds.toDouble();
    return List.generate(99, (i) => (totalSec / 99) * i);
  }

  // ── URL ی دەنگی ناوەکانی خوا ──
  // ئەمە URL ی مستقیمی فایلی MP3 ی ئەسمائول حسنی ستاندارد
  static const String _audioAsset = 'audio/asmaulhusna.mp3';

  // پانی هەر کارتێک بە پیکسل بۆ سکرۆلی ئاسۆیی
  static const double _cardWidth = 160.0;
  static const double _cardSpacing = 12.0;

  @override
  void initState() {
    super.initState();

    _player.onPositionChanged.listen((pos) {
      if (!mounted) return;
      setState(() {
        _position = pos;
        // دۆزینەوەی ناوی کۆنونی بەپێی کات
        _updateCurrentIndex(pos.inSeconds.toDouble());
      });
    });

    _player.onDurationChanged.listen((dur) {
      if (mounted) setState(() => _total = dur);
    });

    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() { _isPlaying = false; _currentIndex = -1; });
    });

    _player.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() => _isPlaying = state == PlayerState.playing);
      }
    });
  }

  void _updateCurrentIndex(double seconds) {
    final timestamps = _getTimestamps();
    for (int i = timestamps.length - 1; i >= 0; i--) {
      if (seconds >= timestamps[i]) {
        if (_currentIndex != i) {
          _currentIndex = i;
          _scrollToIndex(i);
        }
        break;
      }
    }
  }

  void _scrollToIndex(int index) {
    if (!_scrollCtrl.hasClients) return;
    // سنتەری کارتەکە بخاتە بەر چاو
    final double offset = (index * (_cardWidth + _cardSpacing))
        - (_scrollCtrl.position.viewportDimension / 2)
        + (_cardWidth / 2);
    _scrollCtrl.animateTo(
      offset.clamp(0.0, _scrollCtrl.position.maxScrollExtent),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _togglePlay() async {
    if (_isLoading) return;
    if (_isPlaying) {
      await _player.pause();
    } else {
      if (_position == Duration.zero) {
        setState(() => _isLoading = true);
        try {
          await _player.play(AssetSource(_audioAsset));
        } catch (e) {
          debugPrint("Audio error: $e");
        }
        setState(() => _isLoading = false);
      } else {
        await _player.resume();
      }
    }
  }

  Future<void> _seekTo(double seconds) async {
    if (_position == Duration.zero && !_isPlaying) {
      // پلەیەر هێشتا دەستی نەکردووە — یەکەم play، پاشان seek
      setState(() => _isLoading = true);
      try {
        await _player.play(AssetSource(_audioAsset));
        await _player.seek(Duration(seconds: seconds.toInt()));
      } catch (e) {
        debugPrint("SeekTo error: $e");
      }
      if (mounted) setState(() => _isLoading = false);
    } else {
      // پلەیەر چالاکە — تەنها seek
      await _player.seek(Duration(seconds: seconds.toInt()));
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$m:$s";
  }

  @override
  void dispose() {
    _player.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color pc = widget.primaryColor;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(12),
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0F1E),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: pc.withOpacity(0.35)),
          boxShadow: [
            BoxShadow(color: pc.withOpacity(0.15), blurRadius: 24, spreadRadius: 2),
          ],
        ),
        child: Column(
          children: [
            // ── هیدەر ──────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 10, 10),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, color: pc, size: 22),
                  const SizedBox(width: 10),
                  const Text(
                    "ناوەکانی خوای گەورە",
                    style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: pc.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: pc.withOpacity(0.3)),
                    ),
                    child: Text("٩٩ ناو", style: TextStyle(color: pc, fontSize: 12)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 1),

            // ── لیستی ئاسۆیی ──────────────────────
            SizedBox(
              height: 130,
              child: ListView.builder(
                controller: _scrollCtrl,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                itemCount: allahNames.length,
                itemBuilder: (ctx, i) {
                  final AllahName item = allahNames[i];
                  final bool isActive = _currentIndex == i;
                  return GestureDetector(
                    onTap: () => _seekTo(_getTimestamps()[i]),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: _cardWidth,
                      margin: const EdgeInsets.only(left: _cardSpacing),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            item.color.withOpacity(isActive ? 0.45 : 0.2),
                            item.color.withOpacity(isActive ? 0.15 : 0.06),
                          ],
                        ),
                        border: Border.all(
                          color: item.color.withOpacity(isActive ? 0.9 : 0.35),
                          width: isActive ? 2 : 1,
                        ),
                        boxShadow: isActive ? [
                          BoxShadow(color: item.color.withOpacity(0.4), blurRadius: 12),
                        ] : [],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "${i + 1}",
                            style: TextStyle(
                              color: item.color.withOpacity(0.6),
                              fontSize: 10,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.name,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isActive ? item.color : item.color.withOpacity(0.85),
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Text(
                              item.meaning,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 9.5,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 4),
            const Divider(color: Colors.white12, height: 1),

            // ── پلەیەر ─────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Column(
                children: [
                  // ── کاتی کۆنونی ──
                  if (_currentIndex >= 0) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.music_note, color: pc, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          allahNames[_currentIndex].name,
                          style: TextStyle(
                            color: pc,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          allahNames[_currentIndex].meaning,
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],

                  // ── بارێکی پرۆگرێس ──
                  Row(
                    children: [
                      Text(
                        _formatDuration(_position),
                        style: TextStyle(color: pc, fontSize: 11),
                      ),
                      Expanded(
                        child: Slider(
                          value: _total.inSeconds > 0
                              ? _position.inSeconds.toDouble().clamp(0, _total.inSeconds.toDouble())
                              : 0,
                          min: 0,
                          max: _total.inSeconds > 0 ? _total.inSeconds.toDouble() : 1,
                          activeColor: pc,
                          inactiveColor: Colors.white12,
                          onChanged: (v) => _seekTo(v),
                        ),
                      ),
                      Text(
                        _formatDuration(_total),
                        style: const TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                    ],
                  ),

                  // ── کۆنترۆڵەکان ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // دواتر ٣٠ ثانیە
                      IconButton(
                        icon: const Icon(Icons.replay_30, color: Colors.white54, size: 28),
                        onPressed: () => _seekTo(
                          (_position.inSeconds - 30).clamp(0, _total.inSeconds).toDouble(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // play/pause
                      GestureDetector(
                        onTap: _togglePlay,
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(colors: [
                              pc.withOpacity(0.35),
                              pc.withOpacity(0.1),
                            ]),
                            border: Border.all(color: pc.withOpacity(0.6), width: 2),
                            boxShadow: [
                              BoxShadow(color: pc.withOpacity(0.3), blurRadius: 14),
                            ],
                          ),
                          child: _isLoading
                              ? Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: CircularProgressIndicator(color: pc, strokeWidth: 2),
                                )
                              : Icon(
                                  _isPlaying ? Icons.pause : Icons.play_arrow,
                                  color: pc,
                                  size: 32,
                                ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // پێشەوە ٣٠ ثانیە
                      IconButton(
                        icon: const Icon(Icons.forward_30, color: Colors.white54, size: 28),
                        onPressed: () => _seekTo(
                          (_position.inSeconds + 30).clamp(0, _total.inSeconds).toDouble(),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),
                  const Text(
                    "تاپ لەسەر ناوێک بکە بۆ ئەوەی بچیت بۆ ئەو ناوە",
                    style: TextStyle(color: Colors.white24, fontSize: 10),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
