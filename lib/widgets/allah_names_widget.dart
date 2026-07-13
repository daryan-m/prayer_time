import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import 'package:wakelock_plus/wakelock_plus.dart';

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
  final Color? dialogBg;
  const AllahNamesDialog(
      {super.key, required this.primaryColor, this.dialogBg});

  @override
  State<AllahNamesDialog> createState() => _AllahNamesDialogState();
}

class _AllahNamesDialogState extends State<AllahNamesDialog> {
  final ScrollController _scrollCtrl = ScrollController();
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isPlaying = false;
  int _currentIndex = -1;
  Timer? _autoTimer;

  static const double _cardWidth = 150.0;
  static const double _cardSpacing = 10.0;
  static const double _secondsPerName = 2.5;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _autoTimer?.cancel();
    _scrollCtrl.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playSound(int index) async {
    final fileName = '${index + 1}.mp3';
    await _audioPlayer.stop();
    await _audioPlayer.play(AssetSource('audio/allah_names/$fileName'));
  }

  void _startAutoPlay() {
    WakelockPlus.enable();
    _autoTimer?.cancel();
    _autoTimer = Timer.periodic(
      Duration(milliseconds: (_secondsPerName * 1000).toInt()),
      (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        if (_currentIndex < allahNames.length - 1) {
          setState(() => _currentIndex++);
          _scrollToCenter(_currentIndex);
          _playSound(_currentIndex);
        } else {
          timer.cancel();
          setState(() {
            _isPlaying = false;
            _currentIndex = allahNames.length - 1;
          });
        }
      },
    );
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      WakelockPlus.disable();
      _autoTimer?.cancel();
      await _audioPlayer.stop();
      setState(() => _isPlaying = false);
    } else {
      final startIdx =
          (_currentIndex < 0 || _currentIndex >= allahNames.length - 1)
              ? 0
              : _currentIndex;
      setState(() {
        _currentIndex = startIdx;
        _isPlaying = true;
      });
      _scrollToCenter(startIdx);
      await _playSound(startIdx);
      _startAutoPlay();
    }
  }

  Future<void> _stopAndReset() async {
    WakelockPlus.disable();
    _autoTimer?.cancel();
    await _audioPlayer.stop();
    setState(() {
      _isPlaying = false;
      _currentIndex = -1;
    });
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(
        0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _scrollToCenter(int index) {
    if (!_scrollCtrl.hasClients) return;
    final double viewportWidth = _scrollCtrl.position.viewportDimension;
    final double itemOffset = index * (_cardWidth + _cardSpacing);
    final double targetOffset =
        itemOffset - (viewportWidth / 2) + (_cardWidth / 2);
    _scrollCtrl.animateTo(
      targetOffset.clamp(0.0, _scrollCtrl.position.maxScrollExtent),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
    );
  }

  void _jumpBySeconds(int seconds) {
    if (_currentIndex < 0) return;
    final int step = (seconds / _secondsPerName).round();
    final int newIndex = (_currentIndex + step).clamp(0, allahNames.length - 1);
    _autoTimer?.cancel();
    setState(() => _currentIndex = newIndex);
    _scrollToCenter(newIndex);
    _playSound(newIndex);
    if (_isPlaying) _startAutoPlay();
  }

  String _toKurdish(Object value) {
    const en = '0123456789';
    const ku = '٠١٢٣٤٥٦٧٨٩';
    String input = value.toString();
    return input.split('').map((ch) {
      final idx = en.indexOf(ch);
      return idx >= 0 ? ku[idx] : ch;
    }).join();
  }

  @override
  Widget build(BuildContext context) {
    final Color pc = widget.primaryColor;
    final bool hasActive =
        _currentIndex >= 0 && _currentIndex < allahNames.length;
    final AllahName? active = hasActive ? allahNames[_currentIndex] : null;
    final Color bgColor =
        widget.dialogBg ?? Theme.of(context).colorScheme.surface;
    final textTheme = Theme.of(context).textTheme;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
      child: Container(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.86),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: pc.withOpacity(0.7)),
          boxShadow: [
            BoxShadow(
                color: pc.withOpacity(0.12), blurRadius: 30, spreadRadius: 2),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ئەمە بخەرە شوێنەکەی
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Row(children: [
                // دوگمەی داخستن کەوتە لای چەپ
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(Icons.close,
                      color: textTheme.bodyMedium?.color?.withOpacity(0.3),
                      size: 20),
                  onPressed: () {
                    _autoTimer?.cancel();
                    _audioPlayer.stop();
                    Navigator.pop(context);
                  },
                ),
                const Spacer(),
                // تێکست و ئایکۆنەکە کەوتنە لای ڕاست
                Text("٩٩ ناوی خوای گەورە",
                    style: TextStyle(
                        color: textTheme.bodyLarge?.color,
                        fontSize: 14,
                        fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Icon(Icons.auto_awesome, color: pc, size: 16),
              ]),
            ),
            SizedBox(
              height: 138,
              child: ListView.builder(
                controller: _scrollCtrl,
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                itemCount: allahNames.length,
                itemBuilder: (ctx, i) {
                  final item = allahNames[i];
                  final bool isActive = _currentIndex == i;

                  return GestureDetector(
                    onTap: () async {
                      _autoTimer?.cancel();
                      setState(() {
                        _currentIndex = i;
                        _isPlaying = true;
                      });
                      _scrollToCenter(i);
                      await _playSound(i);
                      _startAutoPlay();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 280),
                      width: _cardWidth,
                      margin: EdgeInsets.only(
                        right: _cardSpacing,
                        top: isActive ? 0 : 6,
                        bottom: isActive ? 0 : 6,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isActive
                              ? [
                                  item.color.withOpacity(0.55),
                                  item.color.withOpacity(0.18),
                                ]
                              : [
                                  item.color.withOpacity(0.12),
                                  item.color.withOpacity(0.04),
                                ],
                        ),
                        border: Border.all(
                          color: item.color.withOpacity(isActive ? 1.0 : 0.3),
                          width: isActive ? 1.8 : 1,
                        ),
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                  color: item.color.withOpacity(0.45),
                                  blurRadius: 18,
                                  spreadRadius: 0,
                                )
                              ]
                            : [],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: item.color
                                  .withOpacity(isActive ? 0.35 : 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _toKurdish(i + 1),
                              style: TextStyle(
                                color: isActive
                                    ? Colors.white
                                    : item.color.withOpacity(0.7),
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            item.name,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isActive
                                  ? Colors.white
                                  : item.color.withOpacity(0.88),
                              fontWeight: FontWeight.bold,
                              fontSize: isActive ? 16 : 14,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Text(
                              item.meaning,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isActive
                                    ? Colors.white.withOpacity(0.7)
                                    : textTheme.bodyMedium?.color
                                        ?.withOpacity(0.54),
                                fontSize: 9.5,
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
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.09),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              child: active != null
                  ? Container(
                      key: ValueKey(_currentIndex),
                      margin: const EdgeInsets.fromLTRB(14, 12, 14, 6),
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFCFBC1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: const Color(0xFF0026FF), width: 0.8),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0x1F0051FF),
                              border:
                                  Border.all(color: const Color(0x5F0026FF)),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              _toKurdish(_currentIndex + 1),
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  active.name,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xFF002FFF),
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  active.meaning,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: const Color(0xFF5C80F8)
                                        .withOpacity(0.70),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            _isPlaying
                                ? Icons.volume_up_rounded
                                : Icons.volume_off_rounded,
                            color: const Color(0x880400FF),
                            size: 18,
                          ),
                        ],
                      ),
                    )
                  : Padding(
                      key: const ValueKey(-1),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      child: Text(
                        "دوگمەی پلەی بکە یان ناوێک هەڵبژێرە",
                        style:
                            TextStyle(color: pc.withOpacity(0.4), fontSize: 12),
                      ),
                    ),
            ),
            const SizedBox(height: 4),
            Container(
              margin: const EdgeInsets.fromLTRB(14, 4, 14, 14),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color:
                    Theme.of(context).colorScheme.onSurface.withOpacity(0.04),
                borderRadius: BorderRadius.circular(40),
                border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.08)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ctrlBtn(
                    icon: Icons.replay_10_rounded,
                    color: pc,
                    onTap: () => _jumpBySeconds(-10),
                  ),
                  _ctrlBtn(
                    icon: Icons.stop_rounded,
                    color: pc,
                    onTap: _stopAndReset,
                  ),
                  GestureDetector(
                    onTap: _togglePlay,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(colors: [
                          pc.withOpacity(0.5),
                          pc.withOpacity(0.18),
                        ]),
                        border: Border.all(color: pc.withOpacity(0.7)),
                        boxShadow: [
                          BoxShadow(
                              color: pc.withOpacity(0.3),
                              blurRadius: 12,
                              spreadRadius: 1)
                        ],
                      ),
                      child: Icon(
                        _isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                  _ctrlBtn(
                    icon: Icons.forward_10_rounded,
                    color: pc,
                    onTap: () => _jumpBySeconds(10),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ctrlBtn({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withOpacity(0.1),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }
}
