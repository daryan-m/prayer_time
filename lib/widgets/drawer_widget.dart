import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import '../services/prayer_service.dart';

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
  // پلەیەری تایبەتی تاقیکردنەوە — جیاکراوەتەوە لە پلەیەری سەرەکی
  final AudioPlayer _previewPlayer = AudioPlayer();
  String? _currentlyPlaying;
  late String _localSelectedAthan;

  @override
  void initState() {
    super.initState();
    _localSelectedAthan = widget.selectedAthanFile;

    // گوێگرتن بۆ کاتێک دەنگەکە تەواو دەبێت
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

  // ── بەکارهێنانی دەنگ بۆ تاقیکردنەوە ────────────
  Future<void> _togglePreview(String fileName) async {
    if (_currentlyPlaying == fileName) {
      // ئەگەر ئێستا لێدەدات، وەستێنە
      await _previewPlayer.stop();
      if (mounted) setState(() => _currentlyPlaying = null);
      return;
    }

    // وەستاندنی دەنگی پێشوو (ئەگەر هەبوو)
    await _previewPlayer.stop();

    if (mounted) setState(() => _currentlyPlaying = fileName);

    try {
      // ✅ چارەسەری کێشەی دەنگ: ناوی فایل بەبێ .mp3 دەنێرێت بۆ AssetSource
      final String cleanName = fileName.replaceAll('.mp3', '');
      await _previewPlayer.play(AssetSource('audio/$cleanName.mp3'));
    } catch (e) {
      debugPrint("Preview error: $e");
      if (mounted) setState(() => _currentlyPlaying = null);
    }
  }

  // ── هەڵبژاردنی دەنگ ────────────────────────────
  Future<void> _selectAthan(String fileName) async {
    if (mounted) setState(() => _localSelectedAthan = fileName);
    widget.onAthanChanged(fileName);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_sound', fileName);
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
              _buildHeader(context),
              const Divider(color: AppColors.primary, thickness: 1),
              Expanded(
                child: ListView(
                  children: [
                    _buildExpansionTile(
                      Icons.record_voice_over,
                      "دەنگی بانگبێژ",
                      [
                        _buildAthanOption("م. کمال رؤوف", "kamal_rauf.mp3"),
                        _buildAthanOption("بانگی مەدینە", "madina.mp3"),
                        _buildAthanOption("بانگی کوەیت", "kwait.mp3"),
                      ],
                    ),
                    const Divider(
                        color: Colors.white10,
                        thickness: 2,
                        indent: 20,
                        endIndent: 20),
                    _buildExpansionTile(
                      Icons.location_city,
                      "هەڵبژاردنی شار",
                      kurdistanCitiesData
                          .map((city) => _buildCityOption(city))
                          .toList(),
                    ),
                    const Divider(
                        color: Colors.white10,
                        thickness: 2,
                        indent: 20,
                        endIndent: 20),
                    _buildExpansionTile(
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
                              if (value != null) {
                                widget.onThemeChanged(
                                    value, appThemes[value]!);
                              }
                            },
                          ),
                          onTap: () =>
                              widget.onThemeChanged(
                                  themeName, appThemes[themeName]!),
                        );
                      }).toList(),
                    ),
                    const Divider(color: Colors.white10, thickness: 2),
                    _buildYouTubeTile(),
                    const Divider(
                        color: Colors.white10,
                        thickness: 2,
                        indent: 20,
                        endIndent: 20),
                    _buildExpansionTile(
                      Icons.info_outline,
                      "دەربارە",
                      [_buildAboutContent()],
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

  // ── سەرپەڕەی درا ────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 25, 8, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.mosque, size: 30, color: AppColors.secondary),
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
    );
  }

  // ── ئۆپشنی دەنگی بانگ ───────────────────────────
  Widget _buildAthanOption(String title, String fileName) {
    final bool isSelected = _localSelectedAthan == fileName;
    final bool isPlaying = _currentlyPlaying == fileName;

    return ListTile(
      // ── دوگمەی پلەی تاقیکردنەوە ──
      leading: IconButton(
        icon: Icon(
          isPlaying ? Icons.stop_circle : Icons.play_circle_fill,
          color: isPlaying ? Colors.redAccent : Colors.lightBlueAccent,
          size: 30,
        ),
        onPressed: () => _togglePreview(fileName),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? widget.primaryColor : Colors.white,
          fontSize: 13,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      // ── ڕادیۆی هەڵبژاردن ──
      trailing: Radio<String>(
        value: fileName,
        groupValue: _localSelectedAthan,
        activeColor: widget.primaryColor,
        onChanged: (value) {
          if (value != null) _selectAthan(value);
        },
      ),
      onTap: () => _selectAthan(fileName),
    );
  }

  // ── ئۆپشنی شار ──────────────────────────────────
  Widget _buildCityOption(String cityName) {
    return ListTile(
      title: Text(cityName,
          style: const TextStyle(color: Colors.white, fontSize: 13)),
      leading: Radio<String>(
        value: cityName,
        groupValue: widget.currentCity,
        activeColor: AppColors.primary,
        onChanged: (value) {
          if (value != null) widget.onCityChanged(value);
        },
      ),
      onTap: () => widget.onCityChanged(cityName),
    );
  }

  // ── لینکی یوتیوب ────────────────────────────────
  Widget _buildYouTubeTile() {
    return ListTile(
      leading: const Icon(Icons.play_circle_fill, color: Colors.red, size: 28),
      title: const Text(
        "ئێمە لە یوتیوب",
        style: TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
      onTap: () async {
        final Uri url = Uri.parse('https://www.youtube.com/@daryan111');
        if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
          debugPrint("کێشەیەک هەیە لە کردنەوەی لینکەکە");
        }
      },
    );
  }

  // ── بەشی دەربارە ─────────────────────────────────
  Widget _buildAboutContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "ئەم ئەپلیکەیشنە تایبەتە بە کاتى بانگى شارو شارۆچکەکانى هەرێمى کوردستان.",
            style: TextStyle(color: Colors.white, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Icon(Icons.label_outline, color: widget.primaryColor, size: 16),
              const SizedBox(width: 8),
              Text(
                "وەشانى: $currentAppVersion",
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.brush_outlined, color: widget.primaryColor, size: 16),
              const SizedBox(width: 8),
              const Text(
                "دیزاینەر: داریان مەزهەر",
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── ExpansionTile ────────────────────────────────
  Widget _buildExpansionTile(
      IconData icon, String title, List<Widget> children) {
    return ExpansionTile(
      leading: Icon(icon, color: widget.primaryColor, size: 22),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      iconColor: widget.primaryColor,
      collapsedIconColor: Colors.white70,
      children: children,
    );
  }
}
