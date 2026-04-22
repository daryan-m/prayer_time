import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/constants.dart';
import '../services/prayer_service.dart';

// ==================== ویدجەتی تەسبیح ====================
enum _FeedbackType { haptic, tick, silent }

// ==================== داتای تەسبیح ====================

class _ZikrItem {
  final String arabic;
  final String kurdish;
  final int target;
  _ZikrItem(this.arabic, this.kurdish, this.target);
}

final List<_ZikrItem> _zikrList = [
  _ZikrItem("سُبْحَانَ اللَّهِ", "پاک وبیگەردى بۆ خوا", 33),
  _ZikrItem("الْحَمْدُ لِلَّهِ", "سوپاس و ستایش بۆ خودا", 33),
  _ZikrItem("اللَّهُ أَكْبَرُ", "خوا گەورەترە", 34),
  _ZikrItem("لَا إِلَٰهَ إِلَّا اللَّهُ", "هیچ خوایەک نییە جگە لەالله", 100),
  _ZikrItem("أَسْتَغْفِرُ اللهَ وَأَتُوبُ إِلَيْهِ ",
      "داوای لێخۆشبوون لە خوا دەکەم", 100),
  _ZikrItem("سُبْحَانَ اللَّهِ وَبِحَمْدِهِ",
      "   پاک و بیگەردى و سوپاس و ستایش بۆ خودا ", 100),
  _ZikrItem("لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ",
      "هیچ هێز و توانایەک نییە جگە لە هیز و تواناى خودا", 33),
  _ZikrItem(" اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ وَعَلَى آلِ مُحَمَّدٍ",
      "خودایا درود لە سەر محمد بنێرە", 10),
];

class TasbihDialog extends StatefulWidget {
  final Color primaryColor;
  final Color? dialogBg;
  const TasbihDialog({super.key, required this.primaryColor, this.dialogBg});
  @override
  State<TasbihDialog> createState() => _TasbihDialogState();
}

class _TasbihDialogState extends State<TasbihDialog>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  int _count = 0;
  int _totalCount = 0;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  _FeedbackType _feedbackType = _FeedbackType.haptic;
  final AudioPlayer _tickPlayer = AudioPlayer();
  static const String _prefsKey = 'tasbih_feedback';

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 120));
    _pulseAnim = Tween<double>(begin: 1.0, end: 0.93)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _loadFeedbackPref();
  }

  Future<void> _loadFeedbackPref() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey) ?? 'haptic';
    if (mounted) {
      setState(() {
        _feedbackType = _FeedbackType.values.firstWhere(
          (e) => e.name == saved,
          orElse: () => _FeedbackType.haptic,
        );
      });
    }
  }

  Future<void> _saveFeedbackPref(_FeedbackType type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, type.name);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _tickPlayer.stop();
    _tickPlayer.dispose();
    super.dispose();
  }

  _ZikrItem get _current => _zikrList[_selectedIndex];

  Future<void> _doFeedback() async {
    switch (_feedbackType) {
      case _FeedbackType.haptic:
        if (await Vibration.hasVibrator() == true) {
          Vibration.vibrate(duration: 70, amplitude: 255);
        }
        break;
      case _FeedbackType.tick:
        try {
          await _tickPlayer.stop();
          await _tickPlayer.play(AssetSource('audio/tick.mp3'));
        } catch (e) {
          debugPrint("Error playing tick: $e");
        }
        if (await Vibration.hasVibrator() == true) {
          Vibration.vibrate(duration: 20, amplitude: 255);
        }
        break;
      case _FeedbackType.silent:
        break;
    }
  }

  void _tap() async {
    _doFeedback();
    await _pulseCtrl.forward();
    await _pulseCtrl.reverse();
    setState(() {
      _count++;
      _totalCount++;
    });
    if (_count >= _current.target) {
      await Future.delayed(const Duration(milliseconds: 150));
      if (mounted) {
        setState(() => _count = 0);
        _showRoundComplete();
      }
    }
  }

  void _reset() => setState(() {
        _count = 0;
        _totalCount = 0;
      });

  void _showRoundComplete() {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text("${_current.target} جار تەواو بوو ✓",
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold)),
      backgroundColor: Colors.green.shade700,
      duration: const Duration(seconds: 1),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  Widget _buildFeedbackBtn(
      _FeedbackType type, IconData icon, String label, Color pc) {
    final active = _feedbackType == type;
    return GestureDetector(
      onTap: () {
        setState(() => _feedbackType = type);
        _saveFeedbackPref(type);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? pc.withOpacity(0.22) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? pc : Colors.white.withOpacity(0.15),
            width: active ? 1.5 : 1.0,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon,
              size: 14,
              color: active
                  ? pc
                  : Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.color
                      ?.withOpacity(0.38)),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                color: active
                    ? pc
                    : Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.color
                        ?.withOpacity(0.38),
                fontSize: 12,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
              )),
        ]),
      ),
    );
  }

  @override
  @override
  Widget build(BuildContext context) {
    final Color pc = widget.primaryColor;
    final int target = _current.target;
    final double progress = _count / target;
    final Color bgColor =
        widget.dialogBg ?? Theme.of(context).colorScheme.surface;

    // ✅ رەنگەکان لە bgColor دادەمەزرێن نەک لە تیمەکە
    const Color textColor = Colors.white;
    const Color textSubColor = Colors.white60;

    final Widget hapticBtn =
        _buildFeedbackBtn(_FeedbackType.haptic, Icons.vibration, "هەززە", pc);
    final Widget tickBtn =
        _buildFeedbackBtn(_FeedbackType.tick, Icons.music_note, "تیک", pc);
    final Widget silentBtn =
        _buildFeedbackBtn(_FeedbackType.silent, Icons.volume_off, "بێدەنگ", pc);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.76),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: pc.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
                color: pc.withOpacity(0.2), blurRadius: 30, spreadRadius: 2)
          ],
        ),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 12, 10),
            child: Row(children: [
              Icon(Icons.grain, color: pc, size: 22),
              const SizedBox(width: 10),
              const Text("تەسبیح",
                  style: TextStyle(
                      color: textColor, // ✅
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                    color: pc.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: pc.withOpacity(0.3))),
                child: Text("کۆی: $_totalCount",
                    style: TextStyle(color: pc, fontSize: 12)),
              ),
              const SizedBox(width: 8),
              IconButton(
                  icon: const Icon(Icons.close, color: textSubColor), // ✅
                  onPressed: () => Navigator.pop(context)),
            ]),
          ),
          Divider(color: Colors.white.withOpacity(0.1)),
          SizedBox(
            height: 42,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _zikrList.length,
              itemBuilder: (ctx, i) {
                final selected = i == _selectedIndex;
                return GestureDetector(
                  onTap: () => setState(() {
                    _selectedIndex = i;
                    _count = 0;
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color:
                          selected ? pc : Colors.white.withOpacity(0.07), // ✅
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: selected
                              ? pc
                              : Colors.white.withOpacity(0.24)), // ✅
                    ),
                    child: Text(_zikrList[i].arabic,
                        style: TextStyle(
                          color: selected ? Colors.black87 : textSubColor, // ✅
                          fontSize: 13,
                          fontWeight:
                              selected ? FontWeight.bold : FontWeight.normal,
                        )),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(children: [
              Text(_current.arabic,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: pc,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      height: 1.6)),
              const SizedBox(height: 4),
              Text(_current.kurdish,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: textSubColor, // ✅
                      fontSize: 13,
                      height: 1.4)),
            ]),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text("$_count",
                    style: TextStyle(
                        color: pc, fontSize: 13, fontWeight: FontWeight.bold)),
                Text("$target",
                    style: const TextStyle(
                        color: textSubColor, // ✅
                        fontSize: 13)),
              ]),
              const SizedBox(height: 6),
              ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: Colors.white.withOpacity(0.12), // ✅
                      valueColor: AlwaysStoppedAnimation<Color>(pc))),
            ]),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 220,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(top: 0, child: silentBtn),
                Positioned(left: 20, top: 65, child: hapticBtn),
                Positioned(right: 20, top: 65, child: tickBtn),
                Positioned(
                  bottom: 0,
                  child: GestureDetector(
                    onTap: _tap,
                    child: ScaleTransition(
                      scale: _pulseAnim,
                      child: Container(
                        width: 155,
                        height: 155,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(colors: [
                            pc.withOpacity(0.35),
                            pc.withOpacity(0.08)
                          ]),
                          border: Border.all(
                              color: pc.withOpacity(0.6), width: 2.5),
                          boxShadow: [
                            BoxShadow(
                                color: pc.withOpacity(0.3),
                                blurRadius: 25,
                                spreadRadius: 4)
                          ],
                        ),
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text("$_count",
                                  style: const TextStyle(
                                      color: textColor, // ✅
                                      fontSize: 46,
                                      fontWeight: FontWeight.bold)),
                              Text("/ $target",
                                  style: TextStyle(
                                      color: pc.withOpacity(0.7),
                                      fontSize: 15)),
                            ]),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _reset,
            icon: const Icon(Icons.refresh, color: textSubColor, size: 18), // ✅
            label: const Text("ڕیست",
                style: TextStyle(
                    color: textSubColor, // ✅
                    fontSize: 13)),
          ),
          const SizedBox(height: 14),
        ]),
      ),
    );
  }
}
