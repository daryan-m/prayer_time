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
import 'package:http/http.dart' as http;
import 'tasbih_widget.dart';
import 'date_converter_widget.dart';

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
      width: MediaQuery.of(context).size.width * 0.84,
      child: Drawer(
        backgroundColor: pal.drawerBg,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(52),
            bottomLeft: Radius.circular(20),
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            border:
                Border(left: BorderSide(color: pal.drawerBorder, width: 2.0)),
          ),
          child: Column(
            children: [
              _buildHeader(context, pal),
              Divider(color: pal.primary, thickness: 1.5),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _buildExpansionTile(
                        Icons.record_voice_over, "دەنگی بانگبێژ", pal, [
                      _buildAthanOption("بانگى مەدینە", "madina.mp3", pal),
                      _buildAthanOption("بانگی مەککە", "macca.mp3", pal),
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
                              TasbihDialog(primaryColor: pal.primary)),
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
                          builder: (_) => DateConverterDialog(
                                primaryColor: pal.primary,
                                palette: pal,
                                dataService: PrayerDataService(),
                                timeService: TimeService(),
                                currentCity: widget.currentCity,
                              )),
                    ),
                    _divider(pal),
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
                    _divider(pal),
                    ListTile(
                      leading: Icon(Icons.feedback_outlined,
                          color: pal.primary, size: 22),
                      title: Text("پەیوەندی و راوبۆچوون",
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: pal.listText)),
                      trailing: Icon(Icons.arrow_forward_ios,
                          color: pal.listText.withOpacity(0.4), size: 14),
                      onTap: () => _showFeedbackSheet(context, pal),
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

  Widget _divider(ThemePalette pal) => Divider(
      color: pal.primary.withOpacity(0.15),
      thickness: 2,
      indent: 20,
      endIndent: 20);

  Widget _buildHeader(BuildContext context, ThemePalette pal) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 40, 10, 2),
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

  void _showFeedbackSheet(BuildContext context, ThemePalette pal) {
    String selectedRating = "";
    final TextEditingController feedbackCtrl = TextEditingController();
    bool isSending = false;
    bool sent = false;

    final List<Map<String, String>> ratings = [
      {"label": "نایاب", "emoji": "🌟"},
      {"label": "زۆر باش", "emoji": "⭐"},
      {"label": "باش", "emoji": "✅"},
      {"label": "کارى ترى ئەوێت", "emoji": "🔧"},
      {"label": "هەڵەى تێدایە", "emoji": "⚠️"},
    ];

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 40, // ئەمە وەک خۆی دەهێڵێتەوە تا دراوەرەکە نەشارێتەوە
            bottom: MediaQuery.of(ctx).viewInsets.bottom > 0
                ? 10
                : 40, // کاتێک کیبۆرد هەبوو، بۆشایی خوارەوە کەم دەکاتەوە تا دوگمەکە دەرکەوێت
          ),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.85,
            ),
            decoration: BoxDecoration(
              color: pal.drawerBg,
              borderRadius: BorderRadius.circular(24),
              border:
                  Border.all(color: pal.primary.withOpacity(0.3), width: 1.5),
            ),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: SingleChildScrollView(
              child: sent
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_outline,
                            color: pal.primary, size: 52),
                        const SizedBox(height: 12),
                        Text("سوپاس!",
                            style: TextStyle(
                                color: pal.listText,
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Text("راوبۆچوونەکەت وەرگیرا",
                            style: TextStyle(
                                color: pal.listText.withOpacity(0.5),
                                fontSize: 13)),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: pal.primary.withOpacity(0.15),
                            foregroundColor: pal.primary,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text("داخستن"),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            GestureDetector(
                              onTap: () => Navigator.pop(ctx),
                              child: Icon(Icons.close,
                                  color: pal.listText.withOpacity(0.5),
                                  size: 20),
                            ),
                            Text("پەیوەندی و راوبۆچوون",
                                style: TextStyle(
                                    color: pal.listText,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold)),
                            Icon(Icons.feedback_outlined,
                                color: pal.primary, size: 24),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // ── نرخاندن ──
                        Text("ئەم ئەپڵیکەیشنە چۆن ئەبینیت؟",
                            style: TextStyle(
                                color: pal.listText.withOpacity(0.7),
                                fontSize: 13)),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: ratings.map((r) {
                            final bool selected = selectedRating == r["label"];
                            return GestureDetector(
                              onTap: () => setDlgState(
                                  () => selectedRating = r["label"]!),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? pal.primary.withOpacity(0.2)
                                      : pal.primary.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: selected
                                        ? pal.primary
                                        : pal.primary.withOpacity(0.2),
                                    width: selected ? 1.5 : 1,
                                  ),
                                ),
                                child: Text(
                                  "${r["emoji"]} ${r["label"]}",
                                  style: TextStyle(
                                    color: selected
                                        ? pal.primary
                                        : pal.listText.withOpacity(0.6),
                                    fontSize: 12,
                                    fontWeight: selected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),

                        const SizedBox(height: 16),

                        // ── تێکستی راوبۆچوون ──
                        TextField(
                          controller: feedbackCtrl,
                          maxLines: 4,
                          textDirection: TextDirection.rtl,
                          style: TextStyle(color: pal.listText, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: "راوبۆچوون و پێشنیارەکانت بنووسە...",
                            hintTextDirection: TextDirection.rtl,
                            hintStyle: TextStyle(
                                color: pal.listText.withOpacity(0.3),
                                fontSize: 12),
                            filled: true,
                            fillColor: pal.primary.withOpacity(0.05),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                  color: pal.primary.withOpacity(0.2)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                  color: pal.primary.withOpacity(0.2)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: pal.primary),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // ── دوگمەی ناردن ──
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: pal.primary.withOpacity(0.15),
                              foregroundColor: pal.primary,
                              side: BorderSide(
                                  color: pal.primary.withOpacity(0.4)),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: isSending
                                ? null
                                : () async {
                                    if (selectedRating.isEmpty &&
                                        feedbackCtrl.text.trim().isEmpty) {
                                      return;
                                    }

                                    setDlgState(() => isSending = true);

                                    try {
                                      await http.post(
                                        Uri.parse(
                                            'https://script.google.com/macros/s/AKfycbzh9emst3Hz8JCl0DXFQwJgIuNWdDiaEjY6I3j5g9qwxILVcIUvOTpS919zzqtwRW60nQ/exec'),
                                        headers: {
                                          'Content-Type': 'application/json'
                                        },
                                        body: json.encode({
                                          'rating': selectedRating,
                                          'feedback': feedbackCtrl.text.trim(),
                                        }),
                                      );
                                      setDlgState(() {
                                        isSending = false;
                                        sent = true;
                                      });
                                    } catch (e) {
                                      setDlgState(() => isSending = false);
                                    }
                                  },
                            child: isSending
                                ? SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                        color: pal.primary, strokeWidth: 2),
                                  )
                                : const Text("ناردن",
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
