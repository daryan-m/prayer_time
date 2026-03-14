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

  static const String _audioAsset = 'audio/asmaulhusna.mp3';
  static const double _cardWidth = 160.0;
  static const double _cardSpacing = 12.0;

  // ── timestamp: ناوی یەکەم ٠-٥ چرکە، بەقی ٩٨ ناو بەیەکسانی ──
  // ناوی یەکەم "اللَّهُ" لە چرکەی ٠ دەستدەکات
  // ناوی دووەم "الرَّحْمَٰنُ" لە چرکەی ٥ دەستدەکات
  // هەر ناوێک کاتێک دەنگی (أ) ی دەستپێکی هاتەوە scroll دەکات
  List<double> _getTimestamps() {
    const double firstNameDuration = 5.0;
    final double totalSec =
        _total == Duration.zero ? 172.0 : _total.inSeconds.toDouble();
    final double remaining = totalSec - firstNameDuration;
    final double perName = remaining / 98;
    return List.generate(99, (i) {
      if (i == 0) return 0.0;
      return firstNameDuration + (i - 1) * perName;
    });
  }

  @override
  void initState() {
    super.initState();

    _player.onPositionChanged.listen((pos) {
      if (!mounted) return;
      setState(() {
        _position = pos;
        _updateCurrentIndex(pos.inMilliseconds / 1000.0);
      });
    });

    _player.onDurationChanged.listen((dur) {
      if (mounted) setState(() => _total = dur);
    });

    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _currentIndex = -1;
        });
      }
    });

    _player.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
    });
  }

  void _updateCurrentIndex(double seconds) {
    final timestamps = _getTimestamps();
    int newIndex = -1;
    for (int i = timestamps.length - 1; i >= 0; i--) {
      if (seconds >= timestamps[i]) {
        newIndex = i;
        break;
      }
    }
    if (newIndex != _currentIndex) {
      _currentIndex = newIndex;
      if (newIndex >= 0) _scrollToIndex(newIndex);
    }
  }

  void _scrollToIndex(int index) {
    if (!_scrollCtrl.hasClients) return;
    final double offset = (index * (_cardWidth + _cardSpacing)) -
        (_scrollCtrl.position.viewportDimension / 2) +
        (_cardWidth / 2);
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
      setState(() => _isLoading = true);
      try {
        await _player.play(AssetSource(_audioAsset));
        await _player.seek(Duration(milliseconds: (seconds * 1000).toInt()));
      } catch (e) {
        debugPrint("SeekTo error: $e");
      }
      if (mounted) setState(() => _isLoading = false);
    } else {
      await _player.seek(Duration(milliseconds: (seconds * 1000).toInt()));
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
            maxHeight: MediaQuery.of(context).size.height * 0.85),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0F1E),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: pc.withOpacity(0.35)),
          boxShadow: [
            BoxShadow(
                color: pc.withOpacity(0.15), blurRadius: 24, spreadRadius: 2)
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 10, 10),
              child: Row(children: [
                Icon(Icons.auto_awesome, color: pc, size: 22),
                const SizedBox(width: 10),
                const Text("ناوەکانی خوای گەورە",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold)),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: pc.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: pc.withOpacity(0.3)),
                  ),
                  child:
                      Text("٩٩ ناو", style: TextStyle(color: pc, fontSize: 12)),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => Navigator.pop(context),
                ),
              ]),
            ),
            const Divider(color: Colors.white12, height: 1),
            SizedBox(
              height: 130,
              child: ListView.builder(
                controller: _scrollCtrl,
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                    color: item.color.withOpacity(0.4),
                                    blurRadius: 12)
                              ]
                            : [],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("${i + 1}",
                              style: TextStyle(
                                  color: item.color.withOpacity(0.6),
                                  fontSize: 10)),
                          const SizedBox(height: 4),
                          Text(item.name,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: isActive
                                    ? item.color
                                    : item.color.withOpacity(0.85),
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                height: 1.4,
                              )),
                          const SizedBox(height: 4),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Text(item.meaning,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 9.5,
                                    height: 1.3)),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Column(children: [
                if (_currentIndex >= 0) ...[
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.music_note, color: pc, size: 14),
                    const SizedBox(width: 6),
                    Text(allahNames[_currentIndex].name,
                        style: TextStyle(
                            color: pc,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Text(allahNames[_currentIndex].meaning,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12)),
                  ]),
                  const SizedBox(height: 6),
                ],
                Row(children: [
                  Text(_formatDuration(_position),
                      style: TextStyle(color: pc, fontSize: 11)),
                  Expanded(
                    child: Slider(
                      value: _total.inSeconds > 0
                          ? _position.inSeconds
                              .toDouble()
                              .clamp(0, _total.inSeconds.toDouble())
                          : 0,
                      min: 0,
                      max: _total.inSeconds > 0
                          ? _total.inSeconds.toDouble()
                          : 1,
                      activeColor: pc,
                      inactiveColor: Colors.white12,
                      onChanged: (v) => _seekTo(v),
                    ),
                  ),
                  Text(_formatDuration(_total),
                      style:
                          const TextStyle(color: Colors.white38, fontSize: 11)),
                ]),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  IconButton(
                    icon: const Icon(Icons.replay_30,
                        color: Colors.white54, size: 28),
                    onPressed: () => _seekTo((_position.inSeconds - 30)
                        .clamp(0, _total.inSeconds)
                        .toDouble()),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _togglePlay,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(colors: [
                          pc.withOpacity(0.35),
                          pc.withOpacity(0.1)
                        ]),
                        border:
                            Border.all(color: pc.withOpacity(0.6), width: 2),
                        boxShadow: [
                          BoxShadow(color: pc.withOpacity(0.3), blurRadius: 14)
                        ],
                      ),
                      child: _isLoading
                          ? Padding(
                              padding: const EdgeInsets.all(14),
                              child: CircularProgressIndicator(
                                  color: pc, strokeWidth: 2))
                          : Icon(_isPlaying ? Icons.pause : Icons.play_arrow,
                              color: pc, size: 32),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.forward_30,
                        color: Colors.white54, size: 28),
                    onPressed: () => _seekTo((_position.inSeconds + 30)
                        .clamp(0, _total.inSeconds)
                        .toDouble()),
                  ),
                ]),
                const SizedBox(height: 4),
                const Text(
                  "تاپ لەسەر ناوێک بکە بۆ ئەوەی بچیت بۆ ئەو ناوە",
                  style: TextStyle(color: Colors.white24, fontSize: 10),
                  textAlign: TextAlign.center,
                ),
              ]),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
