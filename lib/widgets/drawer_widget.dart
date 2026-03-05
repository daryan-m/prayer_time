import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrayerDrawer extends StatefulWidget {
  final String currentCity;
  final Function(String) onCityChanged;
  final String selectedThemeName;
  final Color primaryColor;
  final Function(String, Color) onThemeChanged;
  final String selectedAthanFile;
  final Function(String) onAthanChanged;
  final String? previewingSound;
  final Function(String?) onPreviewChanged;
  final AudioPlayer audioPlayer;
  // لێرەدا کاتەکانی بانگ زیاد دەکەین بۆ ئەوەی بیناسێت
  final dynamic prayerTimes;

  const PrayerDrawer({
    super.key,
    required this.currentCity,
    required this.onCityChanged,
    required this.selectedThemeName,
    required this.primaryColor,
    required this.onThemeChanged,
    required this.selectedAthanFile,
    required this.onAthanChanged,
    required this.previewingSound,
    required this.onPreviewChanged,
    required this.audioPlayer,
    this.prayerTimes, // کاتەکان لێرە وەردەگرین
  });

  @override
  State<PrayerDrawer> createState() => _PrayerDrawerState();
}

class _PrayerDrawerState extends State<PrayerDrawer> {
  final AudioPlayer _testPlayer = AudioPlayer();
  String? _currentlyPlaying; // بۆ ئەوەی بزانین کام دەنگە ئێستا لێدەدات

  // دروستکردنی گۆڕاوێکی ناوخۆیی بۆ ئەوەی بتوانین بە setState بیگۆڕین
  late String _localSelectedAthan;

  @override
  void initState() {
    super.initState();
    _localSelectedAthan = widget.selectedAthanFile;
  }

  @override
  void dispose() {
    _testPlayer.dispose(); // دەنگەکە دەکوژێنێتەوە کاتێک لاپەڕەکە دادەخرێت
    super.dispose();
  }

  // فەنکشنی نوێکردنەوەی بانگەکان (ئەگەر لە شوێنێکی تر نەتناسابێت لێرە کار دەکات)
  Future<void> refreshAllAthanSchedules(dynamic times) async {
    // لێرە دەبێت لۆجیکی خشتەکردنی بانگەکانت هەبێت
    debugPrint("Updating schedules for: $_localSelectedAthan");
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.75,
      child: Drawer(
        backgroundColor: AppColors.background,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            bottomLeft: Radius.circular(20),
          ),
        ),
        child: Container(
          decoration: const BoxDecoration(
            border: Border(
              left: BorderSide(color: AppColors.primary, width: 3.0),
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 25, 8, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.mosque,
                      size: 30,
                      color: AppColors.secondary,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      "ڕێکخستنەکان",
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(
                color: AppColors.primary,
                thickness: 1,
              ),
              Expanded(
                child: ListView(
                  children: [
                    _buildExpansionTile(
                      context,
                      Icons.record_voice_over,
                      "دەنگی بانگبێژ",
                      [
                        _buildAthanOption(
                            context, "م. کمال رؤوف", "kamal_rauf.mp3"),
                        _buildAthanOption(
                            context, "بانگی مەدینە", "madina.mp3"),
                        _buildAthanOption(context, "بانگی کوەیت", "kwait.mp3"),
                      ],
                    ),
                    const Divider(
                        color: Colors.white10,
                        thickness: 2,
                        indent: 20,
                        endIndent: 20),
                    _buildExpansionTile(
                      context,
                      Icons.location_city,
                      "هەڵبژاردنی شار",
                      kurdistanCitiesData
                          .map((city) => _buildCityOption(context, city))
                          .toList(),
                    ),
                    const Divider(
                        color: Colors.white10,
                        thickness: 2,
                        indent: 20,
                        endIndent: 20),
                    _buildExpansionTile(
                      context,
                      Icons.palette,
                      "ڕووکارەکان",
                      appThemes.keys.map((themeName) {
                        return ListTile(
                          title: Text(
                            "ڕووکاری $themeName",
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13),
                          ),
                          leading: Radio<String>(
                            value: themeName,
                            groupValue: widget.selectedThemeName,
                            activeColor: appThemes[themeName],
                            onChanged: (value) {
                              widget.onThemeChanged(value!, appThemes[value]!);
                            },
                          ),
                          onTap: () {
                            widget.onThemeChanged(
                                themeName, appThemes[themeName]!);
                          },
                        );
                      }).toList(),
                    ),
                    const Divider(
                      color: Colors.white10,
                      thickness: 2,
                    ),
                    ListTile(
                      leading: const Icon(
                        Icons.play_circle_fill,
                        color: Colors.red,
                        size: 28,
                      ),
                      title: const Text(
                        "ئێمە لە یوتیوب",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onTap: () async {
                        final Uri url =
                            Uri.parse('https://www.youtube.com/@daryan111');
                        if (!await launchUrl(url,
                            mode: LaunchMode.externalApplication)) {
                          debugPrint("کێشەیەک هەیە لە کردنەوەی لینکەکە");
                        }
                      },
                    ),
                    const Divider(
                        color: Colors.white10,
                        thickness: 2,
                        indent: 20,
                        endIndent: 20),
                    _buildExpansionTile(
                      context,
                      Icons.info_outline,
                      "دەربارە",
                      [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 15),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "ئەم ئەپلیکەیشنە تایبەتە بە کاتى بانگى شارو شارۆچکەکانى هەرێمى کوردستان.",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 15),
                              Row(
                                children: [
                                  Icon(Icons.label_outline,
                                      color: widget.primaryColor, size: 16),
                                  const SizedBox(width: 8),
                                  Text(
                                    "وەشانى: $currentAppVersion",
                                    style: const TextStyle(
                                      // لێرە ئەگەر TextStyle تەواو جێگیر بێت const ئاساییە
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.brush_outlined,
                                      color: widget.primaryColor, size: 16),
                                  const SizedBox(width: 8),
                                  const Text("دیزاینەر: داریان مەزهەر",
                                      style: TextStyle(
                                          color: Colors.white70, fontSize: 14)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCityOption(BuildContext context, String cityName) {
    return ListTile(
      title: Text(cityName,
          style: const TextStyle(color: Colors.white, fontSize: 13)),
      leading: Radio<String>(
        value: cityName,
        groupValue: widget.currentCity,
        activeColor: AppColors.primary,
        onChanged: (value) {
          widget.onCityChanged(value!);
        },
      ),
      onTap: () {
        widget.onCityChanged(cityName);
      },
    );
  }

Widget _buildAthanOption(BuildContext context, String title, String fileName) {
  bool isSelected = _localSelectedAthan == fileName;
  bool isPlaying = _currentlyPlaying == fileName;

  return ListTile(
    title: Text(
      title,
      style: TextStyle(
        color: isSelected ? widget.primaryColor : Colors.white,
        fontSize: 13,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    ),
    leading: IconButton(
      icon: Icon(
        isPlaying ? Icons.stop_circle : Icons.play_circle_fill,
        color: isPlaying ? Colors.redAccent : Colors.lightBlueAccent,
        size: 30,
      ),
      onPressed: () async {
        if (isPlaying) {
          await _testPlayer.stop();
          if (mounted) setState(() => _currentlyPlaying = null);
        } else {
          try {
            if (mounted) setState(() => _currentlyPlaying = fileName);
            await _testPlayer.stop();
            await _testPlayer.play(AssetSource('audio/$fileName.mp3'));
            
            _testPlayer.onPlayerComplete.listen((event) {
              if (mounted) setState(() => _currentlyPlaying = null);
            });
          } catch (e) {
            debugPrint("Error: $e");
          }
        }
      },
    ),
    trailing: Radio<String>(
      value: fileName,
      groupValue: _localSelectedAthan,
      activeColor: widget.primaryColor,
      onChanged: (value) async {
        if (value != null) {
          if (mounted) setState(() => _localSelectedAthan = value);
          widget.onAthanChanged(value);
          
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('selected_sound', value);
          
          if (widget.prayerTimes != null) {
            await refreshAllAthanSchedules(widget.prayerTimes);
          }
        }
      },
    ), // لێرە داخراوەتەوە بە دروستی
    onTap: () async {
      // ئەگەر کلیکی لەسەر ناوەکە کرد، با هەمان کاری ڕادیۆکە بکات
      if (mounted) setState(() => _localSelectedAthan = fileName);
      widget.onAthanChanged(fileName);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_sound', fileName);
      
      if (widget.prayerTimes != null) {
        await refreshAllAthanSchedules(widget.prayerTimes);
      }
    },
  );
}

  Widget _buildExpansionTile(BuildContext context, IconData icon, String title,
      List<Widget> children) {
    return ExpansionTile(
      leading: Icon(icon, color: widget.primaryColor, size: 22),
      title: Text(title,
          style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
      iconColor: widget.primaryColor,
      collapsedIconColor: Colors.white70,
      children: children,
    );
  }
}
