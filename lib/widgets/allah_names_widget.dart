import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';

// ==================== داتای ٩٩ ناوی خوای گەورە ====================

class AllahName {
  final String name;
  final String meaning;
  final Color color;
  const AllahName(this.name, this.meaning, this.color);
}

const List<AllahName> allahNames = [
  AllahName(
      "اللَّهُ", "خودا — ئەو ناوەیە کە تایبەتە بە خودا", Color(0xFF6366F1)),
  AllahName("الرَّحْمَٰنُ", "بە بەزەیى", Color(0xFF8B5CF6)),
  AllahName("الرَّحِيمُ", " بەخشندە", Color(0xFF0EA5E9)),
  AllahName("الْمَلِكُ", " خاوەنی تەواوی مولکە", Color(0xFFF59E0B)),
  AllahName("الْقُدُّوسُ", "پیرۆز و پاک و بیگەرد", Color(0xFF10B981)),
  AllahName("السَّلَامُ", "سەرچاوەی ئاشتى", Color(0xFF22D3EE)),
  AllahName("الْمُؤْمِنُ", "دڵنیاکەرەوە", Color(0xFF14B8A6)),
  AllahName("الْمُهَيْمِنُ", "چاودیرى کار", Color(0xFFEF4444)),
  AllahName("الْعَزِيزُ", "دەسەڵاتدار", Color(0xFF84CC16)),
  AllahName("الْجَبَّارُ", "ناچارکار", Color(0xFFF97316)),
  AllahName("الْمُتَكَبِّرُ", "  سەروو هەموو شتێک", Color(0xFF8B5CF6)),
  AllahName("الْخَالِقُ", " دروستکەر", Color(0xFF0EA5E9)),
  AllahName("الْبَارِئُ", "دروستکەر-بەدیهینەرى ئاڵۆز", Color(0xFF10B981)),
  AllahName("الْمُصَوِّرُ", " وێنەکێش-شیوە بەخش", Color(0xFFEC4899)),
  AllahName("الْغَفَّارُ", "زۆر لێبوردە ", Color(0xFFFFD700)),
  AllahName("الْقَهَّارُ", " زۆر بەتوانا", Color(0xFF22D3EE)),
  AllahName("الْوَهَّابُ", "زۆر بەخشەر", Color(0xFF6366F1)),
  AllahName("الرَّزَّاقُ", "زۆر رۆزیدەر", Color(0xFF14B8A6)),
  AllahName("الْفَتَّاحُ", "دەرووکەرەوە", Color(0xFFF59E0B)),
  AllahName("الْعَلِيمُ", "زانا", Color(0xFFEF4444)),
  AllahName("الْقَابِضُ", "گرتنەوەر — رزق لە دەست کێ دەوێت دەگرێتەوە",
      Color(0xFF84CC16)),
  AllahName("الْبَاسِطُ", "فراوانکەر — رزق بۆ کێ دەوێت فراوان دەکات",
      Color(0xFFF97316)),
  AllahName(
      "الْخَافِضُ", "دابەزێنەر — هەر بەرزێک دادەبەزێنیت", Color(0xFF8B5CF6)),
  AllahName("الرَّافِعُ", "بەرزکەرەوە — ئەو کەسەى بیەوێت بەرزى دەکات",
      Color(0xFF0EA5E9)),
  AllahName(
      "الْمُعِزُّ", "بەهێزکەر —  کێى بوویت بەهێزى دەکات", Color(0xFF10B981)),
  AllahName("الْمُذِلُّ", "ستەمکاران سەر شۆڕ دەکات", Color(0xFFEC4899)),
  AllahName("السَّمِيعُ", "بیسەر", Color(0xFFFFD700)),
  AllahName("الْبَصِيرُ", " بینەر", Color(0xFF22D3EE)),
  AllahName("الْحَكَمُ", "داوەر", Color(0xFF6366F1)),
  AllahName("الْعَدْلُ", "دادپەروەر", Color(0xFF14B8A6)),
  AllahName("اللَّطِيفُ", "وردبین ", Color(0xFFF59E0B)),
  AllahName("الْخَبِيرُ", "شارەزا", Color(0xFFEF4444)),
  AllahName("الْحَلِيمُ", "هێدى", Color(0xFF84CC16)),
  AllahName("الْعَظِيمُ", "مەزن", Color(0xFFF97316)),
  AllahName("الْغَفُورُ", "لێخۆشبوو", Color(0xFF8B5CF6)),
  AllahName("الشَّكُورُ", "سوپاسگوزار", Color(0xFF0EA5E9)),
  AllahName("الْعَلِيُّ", "بەرزى بەدەسەلات", Color(0xFF10B981)),
  AllahName("الْكَبِيرُ", "گەورە ", Color(0xFFEC4899)),
  AllahName("الْحَفِيظُ", "پارێزەر", Color(0xFFFFD700)),
  AllahName("الْمُقِيتُ", "بژێوى گەیەن و فریادرەس", Color(0xFF22D3EE)),
  AllahName("الْحَسِيبُ", "لێپرسەرەوەو چاودێر", Color(0xFF6366F1)),
  AllahName("الْجَلِيلُ", "سیفەت بەرز", Color(0xFF14B8A6)),
  AllahName("الْكَرِيمُ", "زۆر بەریز و بی پیویست — بەخشینی بێ سنوور",
      Color(0xFFF59E0B)),
  AllahName("الرَّقِيبُ", "چاودێر", Color(0xFFEF4444)),
  AllahName("الْمُجِيبُ", "وەڵامدەرەوە", Color(0xFF84CC16)),
  AllahName("الْوَاسِعُ", "فراوان", Color(0xFFF97316)),
  AllahName("الْحَكِيمُ", "کاربەجێ و دانا", Color(0xFF8B5CF6)),
  AllahName("الْوَدُودُ", " بەسۆز و خۆشەویست", Color(0xFF0EA5E9)),
  AllahName("الْمَجِيدُ", "پایە بەرز", Color(0xFF10B981)),
  AllahName("الْبَاعِثُ", "زیندوو کەرەوە", Color(0xFFEC4899)),
  AllahName("الشَّهِيدُ", "ئاگادار", Color(0xFFFFD700)),
  AllahName("الْحَقُّ", "ڕاست و رەوا", Color(0xFF22D3EE)),
  AllahName(
      "الْوَكِيلُ",
      "بەدیهێنان و بەڕێوەبردنی سەرجەم بەدیهێنراوەکانی خستۆتە سەر خۆی",
      Color(0xFF6366F1)),
  AllahName("الْقَوِيُّ", "بەتوانا", Color(0xFF14B8A6)),
  AllahName("الْمَتِينُ", "بەهێز", Color(0xFFF59E0B)),
  AllahName("الْوَلِيُّ", "دۆست و پشتیوان", Color(0xFFEF4444)),
  AllahName("الْحَمِيدُ", "سوپاس کراو", Color(0xFF84CC16)),
  AllahName("الْمُحْصِي", "ژمیرەرى هەموو شتیک", Color(0xFFF97316)),
  AllahName("الْمُبْدِئُ", "بەدیهێنەر", Color(0xFF8B5CF6)),
  AllahName("الْمُعِيدُ", "زیندووکەرەوە", Color(0xFF0EA5E9)),
  AllahName("الْمُحْيِي", "ژییەنەر", Color(0xFF10B981)),
  AllahName("الْمُمِيتُ", "مرینەر", Color(0xFFEC4899)),
  AllahName("الْحَيُّ", "زیندوو", Color(0xFFFFD700)),
  AllahName("الْقَيُّومُ", "ڕاگر و ڕێکخەر", Color(0xFF22D3EE)),
  AllahName("الْوَاجِدُ", "هەبوو", Color(0xFF6366F1)),
  AllahName("الْمَاجِدُ", "پایەبەرز", Color(0xFF14B8A6)),
  AllahName("الْوَاحِدُ", "تاک و تەنها", Color(0xFFF59E0B)),
  AllahName("الْأَحَدُ", "یەکەم — بێ هاوتا", Color(0xFFEF4444)),
  AllahName("الصَّمَدُ", "بێ پێویست ", Color(0xFF84CC16)),
  AllahName("الْقَادِرُ", "بەتوانا", Color(0xFFF97316)),
  AllahName("الْمُقْتَدِرُ", "سەرچاوەى توانا", Color(0xFF8B5CF6)),
  AllahName("الْمُقَدِّمُ", "پێشخەرى هەموو شتیک", Color(0xFF0EA5E9)),
  AllahName("الْمُؤَخِّرُ", "دواخەرى هەموو شتێک", Color(0xFF10B981)),
  AllahName("الْأَوَّلُ", "یەکەم — پێش هەموو شتێک بووە", Color(0xFFEC4899)),
  AllahName(
      "الْآخِرُ", "کۆتایی — دوای هەموو شتێک دەمێنێتەوە", Color(0xFFFFD700)),
  AllahName("الظَّاهِرُ", "ئاشکرا ", Color(0xFF22D3EE)),
  AllahName("الْبَاطِنُ", "پەنهان و نادیار", Color(0xFF6366F1)),
  AllahName("الْوَالِي", "سەرپەرشتیار", Color(0xFF14B8A6)),
  AllahName("الْمُتَعَالِي", "زۆر بەرز", Color(0xFFF59E0B)),
  AllahName("الْبَرُّ", "چاکەکار", Color(0xFFEF4444)),
  AllahName("التَّوَّابُ", "تۆبە وەرگر", Color(0xFF84CC16)),
  AllahName("الْمُنْتَقِمُ", "تۆڵەسێن لە ستەمکاران", Color(0xFFF97316)),
  AllahName("الْعَفُوُّ", "لێبوردە", Color(0xFF8B5CF6)),
  AllahName("الرَّؤُوفُ", "میهرەبان", Color(0xFF0EA5E9)),
  AllahName("مَالِكُ الْمُلْكِ", "خاوەنی هەموو مولک", Color(0xFF10B981)),
  AllahName("ذُو الْجَلَالِ", "خاوەن شکۆ و ڕێز ", Color(0xFFEC4899)),
  AllahName("الْمُقْسِطُ", "دادپەروەر ", Color(0xFFFFD700)),
  AllahName("الْجَامِعُ", "کۆکەرەوە", Color(0xFF22D3EE)),
  AllahName("الْغَنِيُّ", "دەوڵەمەند بە هەموو شتێک", Color(0xFF6366F1)),
  AllahName("الْمُغْنِي", "دەوڵەمەندکەر ", Color(0xFF14B8A6)),
  AllahName("الْمَانِعُ", "پاریزگار", Color(0xFFF59E0B)),
  AllahName(
      "الضَّارُّ", "زیانگەیەنەر — بە هەر کەسێک بیەوێت", Color(0xFFEF4444)),
  AllahName(
      "النَّافِعُ", "سودگەیەنەر — بە هەر کەسێک بیەوێت", Color(0xFF84CC16)),
  AllahName("النُّورُ", "ڕووناکی ", Color(0xFFF97316)),
  AllahName("الْهَادِي", "ڕێنوێنیکار — ڕێنوێنی باوەڕداران", Color(0xFF8B5CF6)),
  AllahName("الْبَدِيعُ", "داهێنەر", Color(0xFF0EA5E9)),
  AllahName("الْبَاقِي", "هەمیشە دەمێنێتەوە", Color(0xFF10B981)),
  AllahName("الْوَارِثُ", "میراتگرى هەموو بوونەوەر", Color(0xFFEC4899)),
  AllahName("الرَّشِيدُ", "شارەزاکەر و ڕێنیشاندەر", Color(0xFFFFD700)),
  AllahName("الصَّبُورُ", "ئارامگر", Color(0xFF22D3EE)),
];
// ==================== ویدجەت ====================

class AllahNamesDialog extends StatefulWidget {
  final Color primaryColor;
  const AllahNamesDialog({super.key, required this.primaryColor});

  @override
  State<AllahNamesDialog> createState() => _AllahNamesDialogState();
}

class _AllahNamesDialogState extends State<AllahNamesDialog> {
  final ScrollController _scrollCtrl = ScrollController();

  bool _isPlaying = false;
  int _currentIndex = -1;

  Timer? _autoTimer;

  static const double _cardWidth = 160.0;
  static const double _cardSpacing = 12.0;
  static const double _secondsPerName = 2.5;

  // ==================== AUTO PLAY ====================

  void _startAutoPlay() {
    _autoTimer?.cancel();

    _autoTimer = Timer.periodic(
      Duration(milliseconds: (_secondsPerName * 1000).toInt()),
      (timer) {
        if (_currentIndex < allahNames.length - 1) {
          setState(() => _currentIndex++);
          _scrollToIndex(_currentIndex);
        } else {
          timer.cancel();
          setState(() {
            _isPlaying = false;
            _currentIndex = -1;
          });
        }
      },
    );
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      _autoTimer?.cancel();
      setState(() => _isPlaying = false);
    } else {
      if (_currentIndex == -1) {
        setState(() => _currentIndex = 0);
        _scrollToIndex(0);
      }
      setState(() => _isPlaying = true);
      _startAutoPlay();
    }
  }

  void _scrollToIndex(int index) {
    if (!_scrollCtrl.hasClients) return;

    final double offset = (index * (_cardWidth + _cardSpacing)) -
        (_scrollCtrl.position.viewportDimension / 2) +
        (_cardWidth / 2);

    _scrollCtrl.animateTo(
      offset.clamp(0.0, _scrollCtrl.position.maxScrollExtent),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
    );
  }

  void _jumpBySeconds(int seconds) {
    int step = (seconds / _secondsPerName).floor();
    int newIndex = (_currentIndex + step).clamp(0, allahNames.length - 1);

    _autoTimer?.cancel();
    setState(() => _currentIndex = newIndex);
    _scrollToIndex(newIndex);
    _startAutoPlay();
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
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
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0F1E),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),

            // ==================== LIST ====================
            SizedBox(
              height: 130,
              child: ListView.builder(
                controller: _scrollCtrl,
                scrollDirection: Axis.horizontal,
                itemCount: allahNames.length,
                itemBuilder: (ctx, i) {
                  final item = allahNames[i];
                  final isActive = _currentIndex == i;

                  return GestureDetector(
                    onTap: () {
                      _autoTimer?.cancel();
                      setState(() {
                        _currentIndex = i;
                        _isPlaying = true;
                      });
                      _scrollToIndex(i);
                      _startAutoPlay();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: _cardWidth,
                      margin: const EdgeInsets.only(left: _cardSpacing),

                      // 🔥🔥 ئەمە highlight ـەکەیە
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
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                  color: item.color.withOpacity(0.5),
                                  blurRadius: 16,
                                  spreadRadius: 1,
                                )
                              ]
                            : [],
                      ),

                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "${i + 1}",
                            style:
                                TextStyle(color: item.color.withOpacity(0.6)),
                          ),
                          const SizedBox(height: 4),

                          // 🔥 ناوی Active سپی تۆخ
                          Text(
                            item.name,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isActive
                                  ? Colors.white
                                  : item.color.withOpacity(0.85),
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),

                          const SizedBox(height: 4),

                          Text(
                            item.meaning,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            const Divider(),

            // ==================== CURRENT ====================
            if (_currentIndex >= 0)
              Column(
                children: [
                  Text(
                    allahNames[_currentIndex].name,
                    style: TextStyle(
                        color: pc, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    allahNames[_currentIndex].meaning,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),

            const SizedBox(height: 10),

            // ==================== CONTROLS ====================
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.replay_10),
                  onPressed: () => _jumpBySeconds(-10),
                ),
                IconButton(
                  icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                  onPressed: _togglePlay,
                ),
                IconButton(
                  icon: const Icon(Icons.forward_10),
                  onPressed: () => _jumpBySeconds(10),
                ),
              ],
            ),

            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
