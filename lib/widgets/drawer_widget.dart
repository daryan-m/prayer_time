import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hijri/hijri_calendar.dart';
import '../utils/constants.dart';
import '../services/prayer_service.dart';
import 'allah_names_widget.dart';
import 'dart:convert';
import 'dart:typed_data';

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
  _ZikrItem("أَسْتَغْفِرُ اللَّهَ", "داوای لێخۆشبوون لە خوا دەکەم", 100),
  _ZikrItem("سُبْحَانَ اللَّهِ وَبِحَمْدِهِ",
      "   پاک و بیگەردى و سوپاس و ستایش بۆ خودا ", 100),
  _ZikrItem("لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ",
      "هیچ هێز و توانایەک نییە جگە لە هیز و تواناى خودا", 33),
  _ZikrItem(
      "اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ", "خودایا درود لە سەر محمد بنێرە", 10),
];

// ==================== DRAWER ====================

class PrayerDrawer extends StatefulWidget {
  final String currentCity;
  final Function(String) onCityChanged;
  final String selectedThemeName;
  final Color primaryColor;
  final Function(String, Color) onThemeChanged;
  final String selectedAthanFile;
  final Function(String) onAthanChanged;
  final PrayerTimes? prayerTimes;

  const PrayerDrawer({
    super.key,
    required this.currentCity,
    required this.onCityChanged,
    required this.selectedThemeName,
    required this.primaryColor,
    required this.onThemeChanged,
    required this.selectedAthanFile,
    required this.onAthanChanged,
    this.prayerTimes,
  });

  @override
  State<PrayerDrawer> createState() => _PrayerDrawerState();
}

class _PrayerDrawerState extends State<PrayerDrawer> {
  final AudioPlayer _previewPlayer = AudioPlayer();
  String? _currentlyPlaying;
  late String _localSelectedAthan;

  @override
  void initState() {
    super.initState();
    _localSelectedAthan = widget.selectedAthanFile;
    _previewPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _currentlyPlaying = null);
    });
  }

  @override
  void dispose() {
    _previewPlayer.stop();
    _previewPlayer.dispose();
    super.dispose();
  }

  Future<void> _togglePreview(String fileName) async {
    if (_currentlyPlaying == fileName) {
      await _previewPlayer.stop();
      if (mounted) setState(() => _currentlyPlaying = null);
      return;
    }
    await _previewPlayer.stop();
    if (mounted) setState(() => _currentlyPlaying = fileName);
    try {
      await _previewPlayer.release();
      final String cleanName = fileName.replaceAll('.mp3', '');
      await _previewPlayer.setReleaseMode(ReleaseMode.stop);
      await _previewPlayer.play(AssetSource('audio/$cleanName.mp3'));
    } catch (e) {
      debugPrint("Preview error: $e");
      if (mounted) setState(() => _currentlyPlaying = null);
    }
  }

  Future<void> _selectAthan(String fileName) async {
    if (mounted) setState(() => _localSelectedAthan = fileName);
    widget.onAthanChanged(fileName);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_sound', fileName);
  }

  ThemePalette get _pal => getThemePalette(widget.selectedThemeName);

  @override
  Widget build(BuildContext context) {
    final pal = _pal;
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.75,
      child: Drawer(
        backgroundColor: pal.drawerBg,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            bottomLeft: Radius.circular(20),
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            border:
                Border(left: BorderSide(color: pal.drawerBorder, width: 3.0)),
          ),
          child: Column(
            children: [
              _buildHeader(context, pal),
              Divider(color: pal.primary, thickness: 1),
              Expanded(
                child: ListView(
                  children: [
                    _buildExpansionTile(
                        Icons.record_voice_over, "دەنگی بانگبێژ", pal, [
                      _buildAthanOption("م. کمال رؤوف", "kamal_rauf.mp3", pal),
                      _buildAthanOption("بانگی مەدینە", "madina.mp3", pal),
                      _buildAthanOption("بانگی کوەیت", "kwait.mp3", pal),
                    ]),
                    _divider(pal),
                    _buildExpansionTile(
                        Icons.location_city,
                        "هەڵبژاردنی شار",
                        pal,
                        kurdistanCitiesData
                            .map((c) => _buildCityOption(c, pal))
                            .toList()),
                    _divider(pal),
                    _buildExpansionTile(
                      Icons.palette,
                      "ڕووکارەکان",
                      pal,
                      appThemes.keys
                          .map((themeName) => ListTile(
                                title: Text("ڕووکاری $themeName",
                                    style: TextStyle(
                                        color: pal.listText, fontSize: 13)),
                                leading: Radio<String>(
                                  value: themeName,
                                  groupValue: widget.selectedThemeName,
                                  activeColor: appThemes[themeName],
                                  onChanged: (v) {
                                    if (v != null) {
                                      widget.onThemeChanged(v, appThemes[v]!);
                                    }
                                  },
                                ),
                                onTap: () => widget.onThemeChanged(
                                    themeName, appThemes[themeName]!),
                              ))
                          .toList(),
                    ),
                    _divider(pal),
                    ListTile(
                      leading: Icon(Icons.grain, color: pal.primary, size: 22),
                      title: Text("تەسبیح",
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: pal.listText)),
                      trailing: Icon(Icons.arrow_forward_ios,
                          color: pal.listText.withOpacity(0.4), size: 14),
                      onTap: () => showDialog(
                          context: context,
                          builder: (_) =>
                              _TasbihDialog(primaryColor: pal.primary)),
                    ),
                    _divider(pal),
                    ListTile(
                      leading: Icon(Icons.auto_awesome,
                          color: pal.primary, size: 22),
                      title: Text("ناوەکانی خوای گەورە",
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: pal.listText)),
                      trailing: Icon(Icons.arrow_forward_ios,
                          color: pal.listText.withOpacity(0.4), size: 14),
                      onTap: () => showDialog(
                          context: context,
                          builder: (_) =>
                              AllahNamesDialog(primaryColor: pal.primary)),
                    ),
                    _divider(pal),
                    ListTile(
                      leading: Icon(Icons.calendar_month,
                          color: pal.primary, size: 22),
                      title: Text("گۆڕینی بەروار و دۆزینەوەی کاتی بانگ",
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: pal.listText)),
                      trailing: Icon(Icons.arrow_forward_ios,
                          color: pal.listText.withOpacity(0.4), size: 14),
                      onTap: () => showDialog(
                          context: context,
                          builder: (_) => _DateConverterDialog(
                                primaryColor: pal.primary,
                                palette: pal,
                                dataService: PrayerDataService(),
                                timeService: TimeService(),
                                currentCity: widget.currentCity,
                              )),
                    ),
                    Divider(color: pal.primary.withOpacity(0.15), thickness: 2),
                    ListTile(
                      leading: const Icon(Icons.play_circle_fill,
                          color: Colors.red, size: 28),
                      title: Text("ئێمە لە یوتیوب",
                          style: TextStyle(
                              color: pal.listText,
                              fontSize: 14,
                              fontWeight: FontWeight.bold)),
                      onTap: () async {
                        final Uri url =
                            Uri.parse('https://www.youtube.com/@daryan111');
                        if (!await launchUrl(url,
                            mode: LaunchMode.externalApplication)) {
                          debugPrint("کێشەیەک هەیە");
                        }
                      },
                    ),
                    _divider(pal),
                    _buildExpansionTile(Icons.info_outline, "دەربارە", pal,
                        [_buildAboutContent(pal)]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _divider(ThemePalette pal) => Divider(
      color: pal.primary.withOpacity(0.15),
      thickness: 2,
      indent: 20,
      endIndent: 20);

  Widget _buildHeader(BuildContext context, ThemePalette pal) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 25, 8, 10),
      child: Row(children: [
        Icon(Icons.mosque, size: 30, color: pal.secondary),
        const SizedBox(width: 12),
        Text("ڕێکخستنەکان",
            style: TextStyle(
                color: pal.headerText,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
        const Spacer(),
        IconButton(
            icon: const Icon(Icons.close, color: Colors.red),
            onPressed: () => Navigator.pop(context)),
      ]),
    );
  }

  Widget _buildAthanOption(String title, String fileName, ThemePalette pal) {
    final bool isSelected = _localSelectedAthan == fileName;
    final bool isPlaying = _currentlyPlaying == fileName;
    return ListTile(
      leading: IconButton(
        icon: Icon(isPlaying ? Icons.stop_circle : Icons.play_circle_fill,
            color: isPlaying ? Colors.redAccent : Colors.lightBlueAccent,
            size: 30),
        onPressed: () => _togglePreview(fileName),
      ),
      title: Text(title,
          style: TextStyle(
            color: isSelected ? pal.primary : pal.listText,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          )),
      trailing: Radio<String>(
        value: fileName,
        groupValue: _localSelectedAthan,
        activeColor: pal.primary,
        onChanged: (v) {
          if (v != null) _selectAthan(v);
        },
      ),
      onTap: () => _selectAthan(fileName),
    );
  }

  Widget _buildCityOption(String cityName, ThemePalette pal) {
    return ListTile(
      title:
          Text(cityName, style: TextStyle(color: pal.listText, fontSize: 13)),
      leading: Radio<String>(
        value: cityName,
        groupValue: widget.currentCity,
        activeColor: pal.primary,
        onChanged: (v) {
          if (v != null) widget.onCityChanged(v);
        },
      ),
      onTap: () => widget.onCityChanged(cityName),
    );
  }

  Widget _buildAboutContent(ThemePalette pal) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
            "ئەم ئەپلیکەیشنە تایبەتە بە کاتى بانگى شارو شارۆچکەکانى هەرێمى کوردستان.",
            style: TextStyle(color: pal.listText, fontSize: 13, height: 1.5)),
        const SizedBox(height: 15),
        Row(children: [
          Icon(Icons.label_outline, color: pal.primary, size: 16),
          const SizedBox(width: 8),
          Text("وەشانى: $currentAppVersion",
              style: TextStyle(
                  color: pal.listText.withOpacity(0.7), fontSize: 14)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Icon(Icons.brush_outlined, color: pal.primary, size: 16),
          const SizedBox(width: 8),
          Text("دیزاینەر: داریان مەزهەر",
              style: TextStyle(
                  color: pal.listText.withOpacity(0.7), fontSize: 14)),
        ]),
      ]),
    );
  }

  Widget _buildExpansionTile(
      IconData icon, String title, ThemePalette pal, List<Widget> children) {
    return ExpansionTile(
      leading: Icon(icon, color: pal.primary, size: 22),
      title: Text(title,
          style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.bold, color: pal.listText)),
      iconColor: pal.primary,
      collapsedIconColor: pal.listText.withOpacity(0.6),
      children: children,
    );
  }
}

// ==================== ویدجەتی تەسبیح ====================
enum _FeedbackType { haptic, tick, silent }

class _TasbihDialog extends StatefulWidget {
  final Color primaryColor;
  const _TasbihDialog({required this.primaryColor});
  @override
  State<_TasbihDialog> createState() => _TasbihDialogState();
}

class _TasbihDialogState extends State<_TasbihDialog>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  int _count = 0;
  int _totalCount = 0;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  _FeedbackType _feedbackType = _FeedbackType.haptic;
  final AudioPlayer _tickPlayer = AudioPlayer();
  static const String _prefsKey = 'tasbih_feedback';

  static final Uint8List _tickWav = base64Decode(
      'UklGRuwNAABXQVZFZm10IBAAAAABAAEARKwAAIhYAQACABAAZGF0YcgNAAAAAGgglT6PWKlsmXmLfjZ72G83XZJEiScGCBvo3MlCrweaiIuxhO2FIo+sn3G279FV8KQP0S3lSB1fC2+pd3B4WHHgYgJOHjTrFlX4W9ryvuKnqJZfjKyJto4hmxauU8Y+4gAAph1COQdRa2NBb8hzu3BVZkpVvT4sJFcHI+p3ziC2s6JwlS6PT5C7mN2ns7za1arxTw7sKbJCBleZZXxtMW60Z3haX0evL/gU/PiP3XrEYK+dnzSWvJNYmLWjDrU7y8bkAAAhG2M0I0r3Wstl72klZ6FdCU5nORghtwb/663SabyjqoCexpjPmYShXK9swnDZ4vIYDVsmBj2fT/VcLGTSZOJexlJNQaErMBOV+X3gisk8ttCnNJ/ynCmhj6tuu7jPF+cAANIY7y/UQzpTIl3sYF9eqlVmR4U0SB4lBrPtiNYpwuWxy6aOoYCijak4tqnHt9wA9PsLGCPVN9lIDVWnWz9c0Fa7S7876yeOESH6K+MszoK8UK9wp1+lOqm9skPB09M16QAAthbbKw8+Jkw2Va5YWFZhTlNBDTC0G58FQe8P2mrHirhhrpapdKrnsH+8dMy43wX19gocIBUzp0LRTdtTZlRuT0pFqjaGJA8Qofqf5WnSQMIttviuFK2csE+5mcaV1ybrAADHFCAoyDisRfdNI1EAT7ZHxTv3K1kZJQWu8EndO8yevlK18LC7saK3PcLW0Hbi9PUHCmAdvS78PDJHuUw4TaxIZj8EMmohsg4W+93nStaAx3W83LUhtFy3U797ywXb7OwAAAMTtiT0M78/VUc8SkhInUGvNjooMRe1BPzxPeCi0C7Erbupt2O4yb19x9nU+uTP9i0J4RrDKsw3JEEzRqdGfkIBOsMtkx5yDYH76+nW2U7MM8IrvJW6ir3TxPLPK96L7gAAZRGXIYkvUzpEQexDIkIIPAgyziQ4FU4ELfPx4qrURMl8wdC9er5rw0zMhdhG55f3ZQiYGCAnDTOaOzpApUDWPBI13in5G00M4/vM6xXdtNB1x/DBfcAxw9vJCdQL4QfwAADqD7sefitdNbc7JT6CPO02xy2sIWoT8ANE9GrlWdjszc3GcsMNxJLIstDg22HpTviuB4AWzCO2Log2xDolO6k3jzBPJpgZQQs8/ITtDeC61ETMN8fkxV3Ids7G163jY/EAAI8OHhzLJ9MwozbcOFw3QTLiKc8ewxGbA0T1ree52y7Sq8uYyCbJSc241PPeTev2+AcHlhTBILwq5THENR027TJtLA0jaxdMCo78Fu/F4mjYq9ALzNXKGc2t0jLbFuah8gAAUg26GWgkrCz9MQY0pzL7LVImMBxAEEwDLfa+6c/eFNYe0E/N0c2Z0WbYw+EQ7Y/5bgbWEvcdGiemLTExgzGZLqYoESBtFWwJ2fyG8ELlxtuz1HfQW89t0YjWU97K6MAAAzDIaEwyBj1yBFe6aEP2Z62A8i4C2FXHbO6BTSD0FHjCn/X5F3Ov5m3qPhNLYOixJqiU1y6AwZMVjFbvOPm7cVkNFAkBTBbhCifmHiAAA=');

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
        if (await Vibration.hasVibrator() ?? false) {
          Vibration.vibrate(duration: 40, amplitude: 128);
        }
        break;
      case _FeedbackType.tick:
        await _tickPlayer.stop();
        await _tickPlayer.play(BytesSource(_tickWav));
        if (await Vibration.hasVibrator() ?? false) {
          Vibration.vibrate(duration: 10, amplitude: 255);
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
          Icon(icon, size: 14, color: active ? pc : Colors.white38),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                color: active ? pc : Colors.white38,
                fontSize: 12,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
              )),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color pc = widget.primaryColor;
    final int target = _current.target;
    final double progress = _count / target;

    final Widget hapticBtn =
        _buildFeedbackBtn(_FeedbackType.haptic, Icons.vibration, "هەززە", pc);
    final Widget tickBtn =
        _buildFeedbackBtn(_FeedbackType.tick, Icons.music_note, "تیک", pc);
    final Widget silentBtn =
        _buildFeedbackBtn(_FeedbackType.silent, Icons.volume_off, "بێدەنگ", pc);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.92),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0F1E),
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
                      color: Colors.white,
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
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => Navigator.pop(context)),
            ]),
          ),
          const Divider(color: Colors.white12),
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
                      color: selected ? pc : Colors.white.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: selected ? pc : Colors.white24),
                    ),
                    child: Text(_zikrList[i].arabic,
                        style: TextStyle(
                          color: selected ? Colors.black87 : Colors.white70,
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
                      color: Colors.white54, fontSize: 13, height: 1.4)),
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
                    style:
                        const TextStyle(color: Colors.white38, fontSize: 13)),
              ]),
              const SizedBox(height: 6),
              ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: Colors.white12,
                      valueColor: AlwaysStoppedAnimation<Color>(pc))),
            ]),
          ),
          const SizedBox(height: 24),

          // ── هەززە چەپ، بێدەنگ سەرەوە، تیک ڕاست ──
          SizedBox(
            height: 220,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // بێدەنگ — سەرەوە
                Positioned(top: 0, child: silentBtn),
                // هەززە — چەپ
                Positioned(left: 20, top: 65, child: hapticBtn),
                // تیک — ڕاست
                Positioned(right: 20, top: 65, child: tickBtn),
                // دوگمەی ژمارەکردن — خوارەوە ناوەڕاست
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
                                      color: Colors.white,
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
            icon: const Icon(Icons.refresh, color: Colors.white38, size: 18),
            label: const Text("ڕیست",
                style: TextStyle(color: Colors.white54, fontSize: 13)),
          ),
          const SizedBox(height: 14),
        ]),
      ),
    );
  }
}

// ==================== ویدجەتی گۆڕینی بەروار ====================
class _DateConverterDialog extends StatefulWidget {
  final Color primaryColor;
  final ThemePalette palette;
  final PrayerDataService dataService;
  final TimeService timeService;
  final String currentCity;

  const _DateConverterDialog({
    required this.primaryColor,
    required this.palette,
    required this.dataService,
    required this.timeService,
    required this.currentCity,
  });

  @override
  State<_DateConverterDialog> createState() => _DateConverterDialogState();
}

class _DateConverterDialogState extends State<_DateConverterDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  final _gregDayCtrl = TextEditingController();
  final _gregMonthCtrl = TextEditingController();
  final _gregYearCtrl = TextEditingController();
  // کۆچی و کوردی: تەنها خوێندنەوە — خانەکان هەمیشە بەتاڵ
  final _hijriDayCtrl = TextEditingController();
  final _hijriMonthCtrl = TextEditingController();
  final _hijriYearCtrl = TextEditingController();
  final _kurdDayCtrl = TextEditingController();
  final _kurdMonthCtrl = TextEditingController();
  final _kurdYearCtrl = TextEditingController();
  // هەتاوی: ڕۆژ بە controller جیا بۆ چاككردنی کێشەی بەتاڵ بوون
  final _shamsiDayCtrl = TextEditingController();

  String _weekdayResult = "";
  String _hijriResult = "";
  String _kurdResult = "";
  String _shamsiResult = "";
  String _shamsiMonth = "";
  String _shamsiYear = "";

  final _prayDayCtrl = TextEditingController();
  final _prayMonthCtrl = TextEditingController();
  final _prayYearCtrl = TextEditingController();
  String? _selectedCity;
  PrayerTimes? _prayResult;
  bool _prayLoading = false;
  String _prayError = "";

  static const int _minYear = 1900;
  static const int _maxYear = 2126;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _selectedCity = widget.currentCity;
    // خانەی ڕۆژی بانگ هەرگیز بەتاڵ نابێت — بە ئەمڕۆ پڕ دەکرێت
    _prayDayCtrl.text = DateTime.now().day.toString();
    _prayMonthCtrl.text = DateTime.now().month.toString();
    _prayYearCtrl.text = DateTime.now().year.toString();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    for (final c in [
      _gregDayCtrl,
      _gregMonthCtrl,
      _gregYearCtrl,
      _hijriDayCtrl,
      _hijriMonthCtrl,
      _hijriYearCtrl,
      _kurdDayCtrl,
      _kurdMonthCtrl,
      _kurdYearCtrl,
      _shamsiDayCtrl,
      _prayDayCtrl,
      _prayMonthCtrl,
      _prayYearCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _convertFromGreg() {
    final d = int.tryParse(_gregDayCtrl.text.trim());
    final m = int.tryParse(_gregMonthCtrl.text.trim());
    final y = int.tryParse(_gregYearCtrl.text.trim());
    // نادروست یان بەتاڵ: هیچ نیشان نەدە، بەبێ پەیام
    if (d == null ||
        m == null ||
        y == null ||
        d < 1 ||
        d > 31 ||
        m < 1 ||
        m > 12) {
      setState(() {
        _hijriResult = "";
        _kurdResult = "";
        _shamsiResult = "";
        _shamsiDayCtrl.text = "";
        _shamsiMonth = "";
        _shamsiYear = "";
        _weekdayResult = "";
      });
      return;
    }
    // دەرەوەی ڕەنجی ساڵ: هیچ نیشان نەدە، بەبێ پەیام
    if (y < _minYear || y > _maxYear) {
      setState(() {
        _hijriResult = "";
        _kurdResult = "";
        _shamsiResult = "";
        _shamsiDayCtrl.text = "";
        _shamsiMonth = "";
        _shamsiYear = "";
        _weekdayResult = "";
      });
      return;
    }
    try {
      _computeAll(DateTime(y, m, d));
    } catch (_) {}
  }

  void _computeAll(DateTime dt) {
    final weekdays = [
      "یەک شەممە",
      "دوو شەممە",
      "سێ شەممە",
      "چوار شەممە",
      "پێنج شەممە",
      "هەینی",
      "شەممە"
    ];
    final weekday = weekdays[dt.weekday % 7];
    final hijri = HijriCalendar.fromDate(dt);
    final hijriStr =
        "${widget.timeService.toKu(hijri.hDay.toString())}ـى ${hijri.toFormat("MMMM")} ${widget.timeService.toKu(hijri.hYear.toString())}";
    final kurdStr = widget.timeService.kurdishDateString(dt);
    final shamsi = _toShamsi(dt);
    const List<String> shamsiMonths = [
      "فەروەردین",
      "ئوردیبەهەشت",
      "خوردات",
      "تیر",
      "مورداد",
      "شەهریوەر",
      "مەهر",
      "ئابان",
      "ئازەر",
      "دی",
      "بەهمەن",
      "ئیسفەند"
    ];
    final String mName = (shamsi[1] >= 1 && shamsi[1] <= 12)
        ? shamsiMonths[shamsi[1] - 1]
        : shamsi[1].toString();
    final String shamsiStr =
        "${widget.timeService.toKu(shamsi[2].toString())}ـى $mNameـى ${widget.timeService.toKu(shamsi[0].toString())}";

    setState(() {
      _hijriResult = hijriStr;
      _kurdResult = kurdStr;
      _shamsiResult = shamsiStr;
      _shamsiDayCtrl.text =
          shamsi[2].toString(); // ✅ ڕۆژی هەتاوی ئێستا هەمیشە پڕ دەبێت
      _shamsiMonth = shamsi[1].toString();
      _shamsiYear = shamsi[0].toString();
      _weekdayResult = weekday;
    });

    // کۆچی و کوردی خانەکانیان بەتاڵ دەمێننەوە
    _hijriDayCtrl.text = "";
    _hijriMonthCtrl.text = "";
    _hijriYearCtrl.text = "";
    _kurdDayCtrl.text = "";
    _kurdMonthCtrl.text = "";
    _kurdYearCtrl.text = "";
  }

  int _kDay(DateTime dt) {
    final base = _kBase(dt);
    final diff = dt.difference(base).inDays;
    return diff < 186 ? (diff % 31) + 1 : ((diff - 186) % 30) + 1;
  }

  int _kMonth(DateTime dt) {
    final base = _kBase(dt);
    final diff = dt.difference(base).inDays;
    int km = diff < 186 ? (diff ~/ 31) + 1 : ((diff - 186) ~/ 30) + 7;
    return km > 12 ? 12 : km;
  }

  int _kYear(DateTime dt) {
    final noroz = DateTime(dt.year, 3, 21);
    return dt.isBefore(noroz) ? dt.year + 700 - 1 : dt.year + 700;
  }

  DateTime _kBase(DateTime dt) {
    final noroz = DateTime(dt.year, 3, 21);
    return dt.isBefore(noroz) ? DateTime(dt.year - 1, 3, 21) : noroz;
  }

  List<int> _toShamsi(DateTime dt) {
    final int jd = _gregorianToJD(dt.year, dt.month, dt.day);
    return _jdToShamsi(jd);
  }

  int _gregorianToJD(int y, int m, int d) {
    return (1461 * (y + 4800 + (m - 14) ~/ 12)) ~/ 4 +
        (367 * (m - 2 - 12 * ((m - 14) ~/ 12))) ~/ 12 -
        (3 * ((y + 4900 + (m - 14) ~/ 12) ~/ 100)) ~/ 4 +
        d -
        32075;
  }

  int _shamsiYearStart(int y) => _gregorianToJD(y + 621, 3, 21);

  List<int> _jdToShamsi(int jd) {
    int y = (jd - _gregorianToJD(622, 3, 21)) ~/ 365 + 1;
    while (true) {
      final int start = _shamsiYearStart(y);
      if (jd < start) {
        y--;
        break;
      }
      if (jd < _shamsiYearStart(y + 1)) break;
      y++;
    }
    final int dayOfYear = jd - _shamsiYearStart(y) + 1;
    int m, d;
    if (dayOfYear <= 186) {
      m = (dayOfYear - 1) ~/ 31 + 1;
      d = dayOfYear - (m - 1) * 31;
    } else {
      final int rem = dayOfYear - 186;
      m = (rem - 1) ~/ 30 + 7;
      d = rem - (m - 7) * 30;
    }
    return [y, m, d];
  }

  void _clearConverter() {
    _gregDayCtrl.clear();
    _gregMonthCtrl.clear();
    _gregYearCtrl.clear();
    _hijriDayCtrl.clear();
    _hijriMonthCtrl.clear();
    _hijriYearCtrl.clear();
    _kurdDayCtrl.clear();
    _kurdMonthCtrl.clear();
    _kurdYearCtrl.clear();
    _shamsiDayCtrl.clear();
    setState(() {
      _hijriResult = "";
      _kurdResult = "";
      _shamsiResult = "";
      _shamsiMonth = "";
      _shamsiYear = "";
      _weekdayResult = "";
    });
  }

  Future<void> _lookupPrayer() async {
    final d = int.tryParse(_prayDayCtrl.text.trim());
    final m = int.tryParse(_prayMonthCtrl.text.trim());
    final y = int.tryParse(_prayYearCtrl.text.trim());

    if (d == null ||
        d < 1 ||
        d > 31 ||
        m == null ||
        m < 1 ||
        m > 12 ||
        _selectedCity == null) {
      setState(() {
        _prayError = "";
        _prayResult = null;
      });
      return;
    }
    final int year = y ?? DateTime.now().year;
    // دەرەوەی ڕەنج: هیچ نیشان نەدە، بەبێ پەیام
    if (year < _minYear || year > _maxYear) {
      setState(() {
        _prayError = "";
        _prayResult = null;
      });
      return;
    }
    setState(() {
      _prayLoading = true;
      _prayError = "";
      _prayResult = null;
    });
    try {
      final times = await widget.dataService
          .getPrayerTimes(_selectedCity!, DateTime(year, m, d));
      setState(() {
        _prayResult = times;
        _prayLoading = false;
      });
    } catch (e) {
      setState(() {
        _prayError = "هەڵە لە دۆزینەوە";
        _prayLoading = false;
      });
    }
  }

  void _clearPrayer() {
    _prayDayCtrl.text = DateTime.now().day.toString();
    _prayMonthCtrl.text = DateTime.now().month.toString();
    _prayYearCtrl.text = DateTime.now().year.toString();
    setState(() {
      _prayResult = null;
      _prayError = "";
      _selectedCity = widget.currentCity;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pc = widget.primaryColor;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(12),
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.88),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0F1E),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: pc.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
                color: pc.withOpacity(0.15), blurRadius: 25, spreadRadius: 2)
          ],
        ),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 6, 6),
            child: Row(children: [
              Icon(Icons.calendar_month, color: pc, size: 18),
              const SizedBox(width: 8),
              const Text("گۆڕینی بەروار و دۆزینەوەى کاتى بانگ",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                onPressed: () {
                  _clearConverter();
                  Navigator.pop(context);
                },
              ),
              const SizedBox(width: 6),
            ]),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabCtrl,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: pc.withOpacity(0.22),
                border: Border.all(color: pc.withOpacity(0.45)),
              ),
              labelColor: pc,
              unselectedLabelColor: Colors.white38,
              labelStyle:
                  const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(height: 30, text: "گۆڕینی بەروار"),
                Tab(height: 30, text: "دۆزینەوەی کاتی بانگ"),
              ],
            ),
          ),
          const SizedBox(height: 4),
          const Divider(color: Colors.white12),
          Expanded(
              child: TabBarView(controller: _tabCtrl, children: [
            _buildConverterTab(pc),
            _buildPrayerLookupTab(pc),
          ])),
        ]),
      ),
    );
  }

  Widget _buildConverterTab(Color pc) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // ── تێبینی ڕەنجی ساڵ ──
        Container(
          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 12),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: pc.withOpacity(0.07),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: pc.withOpacity(0.2)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.info_outline, color: pc.withOpacity(0.7), size: 12),
            const SizedBox(width: 6),
            Text("لە $_minYear تا $_maxYear ئەتوانیت داخل بکەیت",
                style: TextStyle(
                    color: pc.withOpacity(0.85),
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
          ]),
        ),

        if (_weekdayResult.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 12),
            decoration: BoxDecoration(
              color: pc.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: pc.withOpacity(0.3)),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.today, color: pc, size: 13),
              const SizedBox(width: 5),
              const Text("ڕۆژی هەفتە: ",
                  style: TextStyle(color: Colors.white38, fontSize: 11)),
              Text(_weekdayResult,
                  style: TextStyle(
                      color: pc, fontSize: 12, fontWeight: FontWeight.bold)),
            ]),
          ),
          const SizedBox(height: 7),
        ] else
          const SizedBox(height: 2),

        // ══ میلادی ══ label گەورەتر (13)
        Row(children: [
          Text("میلادی",
              style: TextStyle(
                  color: pc,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0)),
        ]),
        const SizedBox(height: 3),
        _row3(_gregDayCtrl, _gregMonthCtrl, _gregYearCtrl, pc, _convertFromGreg,
            topLabel: "میلادی"),
        Divider(
            color: Colors.white.withOpacity(0.15), height: 14, thickness: 0.5),

        // ══ کۆچی ══ label بچووکتر (11) — خوێندنەوەتەنها
        _rowLabel("کۆچی", const Color(0xFFF59E0B), readOnly: true),
        const SizedBox(height: 3),
        _row3(_hijriDayCtrl, _hijriMonthCtrl, _hijriYearCtrl, pc, null,
            readOnly: true),
        if (_hijriResult.isNotEmpty) ...[
          const SizedBox(height: 4),
          _resultLine(_hijriResult, const Color(0xFFF59E0B)),
        ],
        Divider(
            color: Colors.white.withOpacity(0.15), height: 12, thickness: 0.5),

        // ══ کوردی ══ label بچووکتر (11) — خوێندنەوەتەنها
        _rowLabel("کوردی", const Color(0xFF4ADE80), readOnly: true),
        const SizedBox(height: 3),
        _row3(_kurdDayCtrl, _kurdMonthCtrl, _kurdYearCtrl, pc, null,
            readOnly: true),
        if (_kurdResult.isNotEmpty) ...[
          const SizedBox(height: 4),
          _resultLine(_kurdResult, const Color(0xFF4ADE80)),
        ],
        Divider(
            color: Colors.white.withOpacity(0.15), height: 12, thickness: 0.5),

        // ══ هەتاوی ══ label بچووکتر (11) — خوێندنەوەتەنها
        _rowLabel("هەتاوی", const Color(0xFFF97316), readOnly: true),
        const SizedBox(height: 3),
        _rowShamsi(pc),
        if (_shamsiResult.isNotEmpty) ...[
          const SizedBox(height: 4),
          _resultLine(_shamsiResult, const Color(0xFFF97316)),
        ],

        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: pc.withOpacity(0.18),
              foregroundColor: pc,
              side: BorderSide(color: pc.withOpacity(0.45)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 18),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: const Icon(Icons.swap_horiz, size: 15),
            label: const Text("بیگۆڕە",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            onPressed: _convertFromGreg,
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white38,
              side: const BorderSide(color: Colors.white12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: const Icon(Icons.delete_outline, size: 14),
            label: const Text("سڕینەوە", style: TextStyle(fontSize: 12)),
            onPressed: _clearConverter,
          ),
        ]),
      ]),
    );
  }

  Widget _resultLine(String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(value,
          textAlign: TextAlign.center,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  // هەتاوی row — ڕۆژ لە _shamsiDayCtrl دێت
  Widget _rowShamsi(Color pc) {
    return Row(children: [
      Expanded(
          child: Column(children: [
        Text("ڕۆژ", style: TextStyle(color: pc.withOpacity(0.25), fontSize: 9)),
        const SizedBox(height: 2),
        _readonlyBox(_shamsiDayCtrl.text, pc),
      ])),
      const SizedBox(width: 5),
      Expanded(
          child: Column(children: [
        Text("مانگ",
            style: TextStyle(color: pc.withOpacity(0.25), fontSize: 9)),
        const SizedBox(height: 2),
        _readonlyBox(_shamsiMonth, pc),
      ])),
      const SizedBox(width: 5),
      Expanded(
          flex: 2,
          child: Column(children: [
            Text("ساڵ",
                style: TextStyle(color: pc.withOpacity(0.25), fontSize: 9)),
            const SizedBox(height: 2),
            _readonlyBox(_shamsiYear, pc),
          ])),
    ]);
  }

  Widget _readonlyBox(String val, Color pc) {
    return Container(
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Text(val.isEmpty ? "—" : val,
          style: const TextStyle(
              color: Colors.white38,
              fontSize: 13,
              fontWeight: FontWeight.bold)),
    );
  }

  // لەیبڵی کۆچی/کوردی/هەتاوی — fontSize: 11 (بچووکتر لە میلادی)
  Widget _rowLabel(String label, Color pc, {bool readOnly = false}) {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(label,
          style: TextStyle(
            color: readOnly ? pc.withOpacity(0.4) : pc,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          )),
    ]);
  }

  Widget _row3(
    TextEditingController d,
    TextEditingController m,
    TextEditingController y,
    Color pc,
    VoidCallback? onSubmit, {
    bool readOnly = false,
    int maxDay = 31,
    String? topLabel,
  }) {
    final style = TextStyle(
        color: readOnly ? Colors.white12 : Colors.white,
        fontSize: 13,
        fontWeight: FontWeight.bold);
    final BorderRadius br = BorderRadius.circular(8);
    final Color borderColor =
        readOnly ? Colors.white.withOpacity(0.06) : pc.withOpacity(0.35);

    InputDecoration dec(String hint) => InputDecoration(
          counterText: "",
          hintText: readOnly ? "—" : hint,
          hintStyle: TextStyle(
              color: Colors.white.withOpacity(readOnly ? 0.06 : 0.2),
              fontSize: 11),
          filled: true,
          fillColor: Colors.white.withOpacity(readOnly ? 0.02 : 0.06),
          border: OutlineInputBorder(
              borderRadius: br, borderSide: BorderSide(color: borderColor)),
          enabledBorder: OutlineInputBorder(
              borderRadius: br, borderSide: BorderSide(color: borderColor)),
          focusedBorder: OutlineInputBorder(
              borderRadius: br, borderSide: BorderSide(color: pc, width: 1.5)),
          contentPadding:
              const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
        );

    void clamp(TextEditingController ctrl, int max) {
      final v = int.tryParse(ctrl.text);
      if (v != null && v > max) {
        ctrl.text = max.toString();
        ctrl.selection = TextSelection.collapsed(offset: ctrl.text.length);
      }
    }

    return Row(children: [
      Expanded(
          child: Column(children: [
        // لەیبڵی "میلادی" تەنها لەسەری خانەی ڕۆژی میلادی
        Text(topLabel ?? "ڕۆژ",
            style: TextStyle(
              color: topLabel != null
                  ? pc.withOpacity(0.75)
                  : pc.withOpacity(readOnly ? 0.2 : 0.55),
              fontSize: 9,
              fontWeight:
                  topLabel != null ? FontWeight.bold : FontWeight.normal,
            )),
        const SizedBox(height: 2),
        TextField(
            controller: d,
            readOnly: readOnly,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 2,
            style: style,
            decoration: dec("ڕۆژ"),
            onChanged: readOnly ? null : (_) => clamp(d, maxDay),
            onSubmitted: readOnly
                ? null
                : (_) {
                    if (onSubmit != null) {
                      onSubmit();
                    }
                  }),
      ])),
      const SizedBox(width: 5),
      Expanded(
          child: Column(children: [
        Text("مانگ",
            style: TextStyle(
                color: pc.withOpacity(readOnly ? 0.2 : 0.55), fontSize: 9)),
        const SizedBox(height: 2),
        TextField(
            controller: m,
            readOnly: readOnly,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 2,
            style: style,
            decoration: dec("مانگ"),
            onChanged: readOnly ? null : (_) => clamp(m, 12),
            onSubmitted: readOnly
                ? null
                : (_) {
                    if (onSubmit != null) {
                      onSubmit();
                    }
                  }),
      ])),
      const SizedBox(width: 5),
      Expanded(
          flex: 2,
          child: Column(children: [
            Text("ساڵ",
                style: TextStyle(
                    color: pc.withOpacity(readOnly ? 0.2 : 0.55), fontSize: 9)),
            const SizedBox(height: 2),
            TextField(
                controller: y,
                readOnly: readOnly,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 4,
                style: style,
                decoration: dec("ساڵ"),
                onSubmitted: readOnly
                    ? null
                    : (_) {
                        if (onSubmit != null) {
                          onSubmit();
                        }
                      }),
          ])),
    ]);
  }

  Widget _buildPrayerLookupTab(Color pc) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // ── تێبینی ڕەنجی ساڵ ──
        Container(
          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 12),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: pc.withOpacity(0.07),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: pc.withOpacity(0.2)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.info_outline, color: pc.withOpacity(0.7), size: 12),
            const SizedBox(width: 6),
            Text("لە $_minYear تا $_maxYear ئەتوانیت داخل بکەیت",
                style: TextStyle(
                    color: pc.withOpacity(0.85),
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
          ]),
        ),

        Row(children: [
          Expanded(child: _numField(_prayDayCtrl, "ڕۆژ", pc)),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Text("/",
                  style: TextStyle(
                      color: pc, fontSize: 20, fontWeight: FontWeight.bold))),
          Expanded(child: _numField(_prayMonthCtrl, "مانگ", pc)),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Text("/",
                  style: TextStyle(
                      color: pc, fontSize: 20, fontWeight: FontWeight.bold))),
          Expanded(
              flex: 2, child: _numField(_prayYearCtrl, "ساڵ", pc, maxLen: 4)),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
              child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.07),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: pc.withOpacity(0.35)),
            ),
            child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
              value: _selectedCity,
              dropdownColor: const Color(0xFF0F172A),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              iconEnabledColor: Colors.white54,
              isExpanded: true,
              hint: const Text("شار", style: TextStyle(color: Colors.white38)),
              items: kurdistanCitiesData
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedCity = v),
            )),
          )),
          const SizedBox(width: 10),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: pc.withOpacity(0.2),
              foregroundColor: pc,
              side: BorderSide(color: pc.withOpacity(0.5)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
            ),
            onPressed: _lookupPrayer,
            child: const Text("بدۆزەرەوە",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          const SizedBox(width: 6),
          IconButton(
              onPressed: _clearPrayer,
              icon: const Icon(Icons.clear_all, color: Colors.white38)),
        ]),
        const SizedBox(height: 16),
        if (_prayLoading)
          Center(child: CircularProgressIndicator(color: pc))
        else if (_prayError.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 18),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(_prayError,
                      style: const TextStyle(color: Colors.red, fontSize: 13))),
            ]),
          )
        else if (_prayResult != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: pc.withOpacity(0.07),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: pc.withOpacity(0.25)),
            ),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(children: [
                          Icon(Icons.location_city, color: pc, size: 16),
                          const SizedBox(width: 6),
                          Text(_selectedCity ?? "",
                              style: TextStyle(
                                  color: pc,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14)),
                        ]),
                        Text(
                          "${_prayDayCtrl.text.padLeft(2, '0')}/${_prayMonthCtrl.text.padLeft(2, '0')}/${_prayYearCtrl.text.isNotEmpty ? _prayYearCtrl.text : DateTime.now().year}",
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12),
                        ),
                      ]),
                  const Divider(color: Colors.white10, height: 20),
                  ...List<Widget>.from([
                    [
                      "بەیانی",
                      _prayResult!.fajr,
                      Icons.wb_twilight,
                      const Color(0xFF818CF8)
                    ],
                    [
                      "خۆرهەڵاتن",
                      _prayResult!.sunrise,
                      Icons.wb_sunny,
                      Colors.orange
                    ],
                    [
                      "نیوەڕۆ",
                      _prayResult!.dhuhr,
                      Icons.light_mode,
                      const Color(0xFFFBBF24)
                    ],
                    [
                      "عەسر",
                      _prayResult!.asr,
                      Icons.wb_cloudy,
                      const Color(0xFF34D399)
                    ],
                    [
                      "ئێوارە",
                      _prayResult!.maghrib,
                      Icons.nights_stay,
                      const Color(0xFFF97316)
                    ],
                    [
                      "خەوتنان",
                      _prayResult!.isha,
                      Icons.dark_mode,
                      const Color(0xFF818CF8)
                    ],
                  ].map((row) {
                    final name = row[0] as String;
                    final dt = row[1] as DateTime;
                    final icon = row[2] as IconData;
                    final color = row[3] as Color;
                    final ts =
                        "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(children: [
                        Icon(icon, color: color, size: 18),
                        const SizedBox(width: 10),
                        Text(name,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 14)),
                        const Spacer(),
                        Text(widget.timeService.formatTo12Hr(ts),
                            style: TextStyle(
                                color: color,
                                fontSize: 15,
                                fontWeight: FontWeight.bold)),
                      ]),
                    );
                  })),
                ]),
          ),
        ],
      ]),
    );
  }

  Widget _numField(TextEditingController ctrl, String hint, Color pc,
      {int maxLen = 2}) {
    final border = OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: pc.withOpacity(0.35)));
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      maxLength: maxLen,
      style: const TextStyle(
          color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        counterText: "",
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
        filled: true,
        fillColor: Colors.white.withOpacity(0.07),
        border: border,
        enabledBorder: border,
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: pc, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }
}
