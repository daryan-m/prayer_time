import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/constants.dart';

class PrayerDrawer extends StatelessWidget {
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
  });

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
                padding: const EdgeInsets.fromLTRB(
                    16, 25, 8, 10), // بۆشایی دەوری هیدەر
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment
                      .center, // بۆ ئەوەی هەمووی لە یەک ئاست بن
                  children: [
                    // --- بەشی چەپ: ئایکۆن و نووسین ---
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

                    const Spacer(), // ئەمە هەموو بۆشایی نێوانەکە پڕ دەکاتەوە

                    // --- بەشی ڕاست: دوگمەی داخستن ---
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
              ), // هێڵێکی جوان لە ژێر هیدەر
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
                            groupValue: selectedThemeName,
                            activeColor: appThemes[themeName],
                            onChanged: (value) {
                              onThemeChanged(value!, appThemes[value]!);
                            },
                          ),
                          onTap: () {
                            onThemeChanged(themeName, appThemes[themeName]!);
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
                                       color: primaryColor, size: 16),
                                  const SizedBox(width: 8),
                                  Text("وەشانى: $currentAppVersion",
                                      style: const TextStyle(
                                          color: Colors.white70, fontSize: 14)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.brush_outlined,
                                      color: primaryColor, size: 16),
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
        groupValue: currentCity,
        activeColor: AppColors.primary,
        onChanged: (value) {
          onCityChanged(value!);
        },
      ),
      onTap: () {
        onCityChanged(cityName);
      },
    );
  }

  Widget _buildAthanOption(BuildContext context, String name, String fileName) {
    bool isPlayingPreview = previewingSound == fileName;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      title:
          Text(name, style: const TextStyle(color: Colors.white, fontSize: 13)),
      leading: Radio<String>(
        value: fileName,
        groupValue: selectedAthanFile,
        activeColor: AppColors.primary,
        onChanged: (value) {
          onAthanChanged(value!);
        },
      ),
      trailing: IconButton(
        icon: Icon(
          isPlayingPreview ? Icons.stop_circle : Icons.play_circle_fill,
          color: isPlayingPreview ? Colors.red : AppColors.secondary,
          size: 28,
        ),
        onPressed: () async {
          if (isPlayingPreview) {
            await audioPlayer.stop();
            onPreviewChanged(null);
          } else {
            await audioPlayer.stop();
            await audioPlayer.play(AssetSource('audio/$fileName'));
            onPreviewChanged(fileName);

            audioPlayer.onPlayerComplete.listen((event) {
              onPreviewChanged(null);
            });
          }
        },
      ),
    );
  }

  Widget _buildExpansionTile(BuildContext context, IconData icon, String title,
      List<Widget> children) {
    return ExpansionTile(
      leading: Icon(icon, color: primaryColor, size: 22),
      title: Text(title,
          style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
      iconColor: primaryColor,
      collapsedIconColor: Colors.white70,
      children: children,
    );
  }
}
