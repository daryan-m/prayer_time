import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hijri/hijri_calendar.dart';
import '../utils/constants.dart';
import '../services/prayer_service.dart';

// ==================== داتای تەسبیح ====================

class _ZikrItem {
  final String arabic;
  final String kurdish;
  final int target; // ژمارەی ئامانج (33، 99، هتد)
  _ZikrItem(this.arabic, this.kurdish, this.target);
}

final List<_ZikrItem> _zikrList = [
  _ZikrItem("سُبْحَانَ اللَّهِ",          "پیرۆزی خوا",         33),
  _ZikrItem("الْحَمْدُ لِلَّهِ",          "ستایش بۆ خوا",       33),
  _ZikrItem("اللَّهُ أَكْبَرُ",           "خوا گەورەترە",       34),
  _ZikrItem("لَا إِلَٰهَ إِلَّا اللَّهُ", "هیچ خوایەک نییە جگە لە خوا", 100),
  _ZikrItem("أَسْتَغْفِرُ اللَّهَ",      "داوای لێخۆشی لە خوا دەکەم", 100),
  _ZikrItem("سُبْحَانَ اللَّهِ وَبِحَمْدِهِ", "پیرۆزی خوا و ستایشی", 100),
  _ZikrItem("لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ", "هیچ هێز و توانایەک نییە جگە بە خوا", 33),
  _ZikrItem("اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ", "خودایا درود لە سەر محمد بنێرە", 10),
];

// ==================== داتای ناوەکانی خوا ====================

class _AllahName {
  final String name;
  final String meaning;
  final Color color;
  _AllahName(this.name, this.meaning, this.color);
}

final List<_AllahName> _allahNames = [
  _AllahName("اللَّهُ",       "خوا",                   const Color(0xFF6366F1)),
  _AllahName("الرَّحْمَٰنُ", "زۆر بەخشەندە",          const Color(0xFF8B5CF6)),
  _AllahName("الرَّحِيمُ",   "بەخشەندەی هەمیشەیی",   const Color(0xFF0EA5E9)),
  _AllahName("الْمَلِكُ",    "پاشا",                  const Color(0xFFF59E0B)),
  _AllahName("الْقُدُّوسُ", "پیرۆز",                 const Color(0xFF10B981)),
  _AllahName("السَّلَامُ",   "ئاشتی و سەلامەتی",      const Color(0xFF22D3EE)),
  _AllahName("الْمُؤْمِنُ", "پشتیوانی دەربەندەر",    const Color(0xFF14B8A6)),
  _AllahName("الْعَزِيزُ",   "بەهێز و بەکار",        const Color(0xFFEF4444)),
  _AllahName("الْخَالِقُ",   "دروستکەر",              const Color(0xFF84CC16)),
  _AllahName("الرَّزَّاقُ",  "رزق دەرەوەکەر",        const Color(0xFFF97316)),
  _AllahName("الْغَفُورُ",   "زۆر خەیرخوازانە دەبەخشێت", const Color(0xFF8B5CF6)),
  _AllahName("الشَّكُورُ",   "قەدردانی",              const Color(0xFF0EA5E9)),
  _AllahName("الْحَكِيمُ",   "زیرەک",                const Color(0xFF10B981)),
  _AllahName("الْوَدُودُ",   "خاوەن خۆشەویستی",      const Color(0xFFEC4899)),
  _AllahName("الْكَرِيمُ",   "سەخی",                 const Color(0xFFFFD700)),
  _AllahName("الْقَرِيبُ",   "نزیک",                 const Color(0xFF22D3EE)),
  _AllahName("السَّمِيعُ",   "گوێگر",                const Color(0xFF6366F1)),
  _AllahName("الْبَصِيرُ",   "بینا",                 const Color(0xFF14B8A6)),
  _AllahName("الْعَلِيمُ",   "زانا",                 const Color(0xFFF59E0B)),
  _AllahName("الْقَدِيرُ",   "توانا",                const Color(0xFFEF4444)),
  _AllahName("الْأَوَّلُ",   "یەکەم",                const Color(0xFF84CC16)),
  _AllahName("الْآخِرُ",     "کۆتایی",               const Color(0xFF8B5CF6)),
  _AllahName("الظَّاهِرُ",   "ئاشکرا",              const Color(0xFF0EA5E9)),
  _AllahName("الْبَاطِنُ",   "نهێنی",                const Color(0xFF6366F1)),
  _AllahName("اللَّطِيفُ",   "نەرم و باریک",         const Color(0xFFEC4899)),
  _AllahName("الْحَيُّ",     "ژیوا",                 const Color(0xFF10B981)),
  _AllahName("الْقَيُّومُ",  "هەمیشە ئایەندەیی",    const Color(0xFFF97316)),
  _AllahName("الْغَنِيُّ",   "بێ پێویست",            const Color(0xFFFFD700)),
  _AllahName("الصَّبُورُ",   "سەبرکار",              const Color(0xFF22D3EE)),
  _AllahName("الشَّهِيدُ",   "شایەت",                const Color(0xFFEF4444)),
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
                    const Divider(color: Colors.white10, thickness: 2, indent: 20, endIndent: 20),
                    _buildExpansionTile(
                      Icons.location_city,
                      "هەڵبژاردنی شار",
                      kurdistanCitiesData.map((city) => _buildCityOption(city)).toList(),
                    ),
                    const Divider(color: Colors.white10, thickness: 2, indent: 20, endIndent: 20),
                    _buildExpansionTile(
                      Icons.palette,
                      "ڕووکارەکان",
                      appThemes.keys.map((themeName) {
                        return ListTile(
                          title: Text("ڕووکاری $themeName",
                              style: const TextStyle(color: Colors.white, fontSize: 13)),
                          leading: Radio<String>(
                            value: themeName,
                            groupValue: widget.selectedThemeName,
                            activeColor: appThemes[themeName],
                            onChanged: (value) {
                              if (value != null) widget.onThemeChanged(value, appThemes[value]!);
                            },
                          ),
                          onTap: () => widget.onThemeChanged(themeName, appThemes[themeName]!),
                        );
                      }).toList(),
                    ),
                    const Divider(color: Colors.white10, thickness: 2, indent: 20, endIndent: 20),
                    // ── تەسبیح ──────────────────────────────
                    _buildTasbihTile(),
                    const Divider(color: Colors.white10, thickness: 2, indent: 20, endIndent: 20),
                    // ── ناوەکانی خوا ─────────────────────────
                    _buildAllahNamesTile(),
                    const Divider(color: Colors.white10, thickness: 2, indent: 20, endIndent: 20),
                    // ── گۆڕینی بەروار ────────────────────────
                    _buildDateConverterTile(),
                    const Divider(color: Colors.white10, thickness: 2),
                    _buildYouTubeTile(),
                    const Divider(color: Colors.white10, thickness: 2, indent: 20, endIndent: 20),
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

  // ── تەسبیح — ListTile ────────────────────────────
  Widget _buildTasbihTile() {
    return ListTile(
      leading: Icon(Icons.grain, color: widget.primaryColor, size: 22),
      title: const Text(
        "تەسبیح",
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
      ),
      trailing: Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 14),
      onTap: () => _showTasbihDialog(context),
    );
  }

  // ── ناوەکانی خوا — ListTile ──────────────────────
  Widget _buildAllahNamesTile() {
    return ListTile(
      leading: Icon(Icons.auto_awesome, color: widget.primaryColor, size: 22),
      title: const Text(
        "ناوەکانی خوای گەورە",
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
      ),
      trailing: Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 14),
      onTap: () => _showAllahNamesDialog(context),
    );
  }

  // ── گۆڕینی بەروار — ListTile ───────────────────
  Widget _buildDateConverterTile() {
    return ListTile(
      leading: Icon(Icons.calendar_month, color: widget.primaryColor, size: 22),
      title: const Text(
        "گۆڕینی بەروار",
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 14),
      onTap: () => _showDateConverterDialog(context),
    );
  }

  void _showDateConverterDialog(BuildContext ctx) {
    showDialog(
      context: ctx,
      builder: (_) => _DateConverterDialog(
        primaryColor: widget.primaryColor,
        dataService: PrayerDataService(),
        timeService: TimeService(),
        currentCity: widget.currentCity,
      ),
    );
  }

  // ==================== دیالۆگی تەسبیح ====================
  void _showTasbihDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => _TasbihDialog(primaryColor: widget.primaryColor),
    );
  }

  // ==================== دیالۆگی ناوەکانی خوا ====================
  void _showAllahNamesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: widget.primaryColor.withOpacity(0.4)),
            boxShadow: [
              BoxShadow(
                color: widget.primaryColor.withOpacity(0.15),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            children: [
              // ── هیدەر ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 16, 12),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome, color: widget.primaryColor, size: 24),
                    const SizedBox(width: 10),
                    const Text(
                      "ناوەکانی خوای گەورە",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white12),
              // ── گریدی ناوەکان ──
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.6,
                  ),
                  itemCount: _allahNames.length,
                  itemBuilder: (ctx, i) {
                    final item = _allahNames[i];
                    return Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            item.color.withOpacity(0.25),
                            item.color.withOpacity(0.08),
                          ],
                        ),
                        border: Border.all(color: item.color.withOpacity(0.4)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            item.name,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: item.color,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.meaning,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
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
            style: TextStyle(color: AppColors.primary, fontSize: 18, fontWeight: FontWeight.bold),
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

  Widget _buildAthanOption(String title, String fileName) {
    final bool isSelected = _localSelectedAthan == fileName;
    final bool isPlaying = _currentlyPlaying == fileName;
    return ListTile(
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

  Widget _buildCityOption(String cityName) {
    return ListTile(
      title: Text(cityName, style: const TextStyle(color: Colors.white, fontSize: 13)),
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

  Widget _buildYouTubeTile() {
    return ListTile(
      leading: const Icon(Icons.play_circle_fill, color: Colors.red, size: 28),
      title: const Text(
        "ئێمە لە یوتیوب",
        style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
      ),
      onTap: () async {
        final Uri url = Uri.parse('https://www.youtube.com/@daryan111');
        if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
          debugPrint("کێشەیەک هەیە لە کردنەوەی لینکەکە");
        }
      },
    );
  }

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
          Row(children: [
            Icon(Icons.label_outline, color: widget.primaryColor, size: 16),
            const SizedBox(width: 8),
            Text("وەشانى: $currentAppVersion",
                style: const TextStyle(color: Colors.white70, fontSize: 14)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Icon(Icons.brush_outlined, color: widget.primaryColor, size: 16),
            const SizedBox(width: 8),
            const Text("دیزاینەر: داریان مەزهەر",
                style: TextStyle(color: Colors.white70, fontSize: 14)),
          ]),
        ],
      ),
    );
  }

  Widget _buildExpansionTile(IconData icon, String title, List<Widget> children) {
    return ExpansionTile(
      leading: Icon(icon, color: widget.primaryColor, size: 22),
      title: Text(title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
      iconColor: widget.primaryColor,
      collapsedIconColor: Colors.white70,
      children: children,
    );
  }
}

// ==================== ویدجەتی تەسبیح ====================

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

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _pulseAnim = Tween<double>(begin: 1.0, end: 0.93).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  _ZikrItem get _current => _zikrList[_selectedIndex];

  void _tap() async {
    // ئەنیمەیشنی کلیک
    await _pulseCtrl.forward();
    await _pulseCtrl.reverse();

    setState(() {
      _count++;
      _totalCount++;
    });

    // گاتێک ئامانج تەواو بووە
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "${_current.target} جار تەواو بوو ✓",
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green.shade700,
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color pc = widget.primaryColor;
    final int target = _current.target;
    final double progress = _count / target;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0F1E),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: pc.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(color: pc.withOpacity(0.2), blurRadius: 30, spreadRadius: 2),
          ],
        ),
        child: Column(
          children: [
            // ── هیدەر ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 10),
              child: Row(
                children: [
                  Icon(Icons.grain, color: pc, size: 22),
                  const SizedBox(width: 10),
                  const Text(
                    "تەسبیح",
                    style: TextStyle(
                        color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  // ژمارەی کلی
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: pc.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: pc.withOpacity(0.3)),
                    ),
                    child: Text(
                      "کۆی: $_totalCount",
                      style: TextStyle(color: pc, fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white12),

            // ── لیستی زیکر ─────────────────────────────
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
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected ? pc : Colors.white.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: selected ? pc : Colors.white24),
                      ),
                      child: Text(
                        _zikrList[i].kurdish,
                        style: TextStyle(
                          color: selected ? Colors.black87 : Colors.white70,
                          fontSize: 12,
                          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // ── دەق عەرەبی ────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _current.arabic,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: pc,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  height: 1.6,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── بارێکی پرۆگرێس ────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("$_count",
                          style: TextStyle(
                              color: pc, fontSize: 13, fontWeight: FontWeight.bold)),
                      Text("$target",
                          style: const TextStyle(color: Colors.white38, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: Colors.white12,
                      valueColor: AlwaysStoppedAnimation<Color>(pc),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ── دوگمەی تەسبیح ─────────────────────────
            GestureDetector(
              onTap: _tap,
              child: ScaleTransition(
                scale: _pulseAnim,
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        pc.withOpacity(0.35),
                        pc.withOpacity(0.08),
                      ],
                    ),
                    border: Border.all(color: pc.withOpacity(0.6), width: 2.5),
                    boxShadow: [
                      BoxShadow(color: pc.withOpacity(0.3), blurRadius: 25, spreadRadius: 4),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "$_count",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "/ $target",
                        style: TextStyle(color: pc.withOpacity(0.7), fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── دوگمەی ڕیست ───────────────────────────
            TextButton.icon(
              onPressed: _reset,
              icon: const Icon(Icons.refresh, color: Colors.white54, size: 18),
              label: const Text("ڕیست", style: TextStyle(color: Colors.white54, fontSize: 13)),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ==================== ویدجەتی گۆڕینی بەروار ====================

class _DateConverterDialog extends StatefulWidget {
  final Color primaryColor;
  final PrayerDataService dataService;
  final TimeService timeService;
  final String currentCity;

  const _DateConverterDialog({
    required this.primaryColor,
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

  // ── بەش ١: گۆڕینی بەروار ──
  final _gregDayCtrl   = TextEditingController();
  final _gregMonthCtrl = TextEditingController();
  final _hijriDayCtrl  = TextEditingController();
  final _hijriMonthCtrl= TextEditingController();
  final _kurdDayCtrl   = TextEditingController();
  final _kurdMonthCtrl = TextEditingController();

  String _gregResult  = "";
  String _hijriResult = "";
  String _kurdResult  = "";

  // ── بەش ٢: کاتی بانگ ──
  final _prayDayCtrl   = TextEditingController();
  final _prayMonthCtrl = TextEditingController();
  final _prayYearCtrl  = TextEditingController();
  String? _selectedCity;
  PrayerTimes? _prayResult;
  bool _prayLoading = false;
  String _prayError = "";

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _selectedCity = widget.currentCity;
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _gregDayCtrl.dispose(); _gregMonthCtrl.dispose();
    _hijriDayCtrl.dispose(); _hijriMonthCtrl.dispose();
    _kurdDayCtrl.dispose(); _kurdMonthCtrl.dispose();
    _prayDayCtrl.dispose(); _prayMonthCtrl.dispose(); _prayYearCtrl.dispose();
    super.dispose();
  }

  // ────────────────────────────────────────────────
  // بەش ١: گۆڕینی بەروار
  // ────────────────────────────────────────────────

  void _convertFromGreg() {
    final int? d = int.tryParse(_gregDayCtrl.text.trim());
    final int? m = int.tryParse(_gregMonthCtrl.text.trim());
    if (d == null || m == null || d < 1 || d > 31 || m < 1 || m > 12) {
      setState(() { _gregResult = ""; _hijriResult = ""; _kurdResult = ""; });
      return;
    }
    final dt = DateTime(DateTime.now().year, m, d);
    _computeAll(dt);
  }

  void _computeAll(DateTime dt) {
    // ── میلادی ──
    final gregStr = "${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year}";

    // ── کۆچی — بە HijriCalendar ──
    final hijri = HijriCalendar.fromDate(dt);
    final hDay   = widget.timeService.toKu(hijri.hDay.toString());
    final hMonth = hijri.toFormat("MMMM");
    final hYear  = widget.timeService.toKu(hijri.hYear.toString());
    final hijriStr = "$hDayـى $hMonth $hYear";

    // ── کوردی — هەمان ئەلگۆریتمی TimeService.kurdishDateString ──
    final kurdStr = widget.timeService.kurdishDateString(dt);

    setState(() {
      _gregResult  = gregStr;
      _hijriResult = hijriStr;
      _kurdResult  = kurdStr;
    });

    // ناو تێکستبۆکسەکانی تری پڕ بکە
    _hijriDayCtrl.text  = hijri.hDay.toString();
    _hijriMonthCtrl.text = hijri.hMonth.toString();
    _kurdDayCtrl.text   = _extractKurdDay(dt);
    _kurdMonthCtrl.text = _extractKurdMonth(dt);
  }

  String _extractKurdDay(DateTime dt) {
    final DateTime noroz = DateTime(dt.year, 3, 21);
    final bool before = dt.isBefore(noroz);
    final DateTime base = before ? DateTime(dt.year - 1, 3, 21) : noroz;
    final int diff = dt.difference(base).inDays;
    int kDay;
    if (diff < 186) {
      kDay = (diff % 31) + 1;
    } else {
      kDay = ((diff - 186) % 30) + 1;
    }
    return kDay.toString();
  }

  String _extractKurdMonth(DateTime dt) {
    final DateTime noroz = DateTime(dt.year, 3, 21);
    final bool before = dt.isBefore(noroz);
    final DateTime base = before ? DateTime(dt.year - 1, 3, 21) : noroz;
    final int diff = dt.difference(base).inDays;
    int kMonth;
    if (diff < 186) {
      kMonth = (diff ~/ 31) + 1;
    } else {
      kMonth = ((diff - 186) ~/ 30) + 7;
    }
    if (kMonth > 12) kMonth = 12;
    return kMonth.toString();
  }

  void _convertFromHijri() {
    final int? d = int.tryParse(_hijriDayCtrl.text.trim());
    final int? m = int.tryParse(_hijriMonthCtrl.text.trim());
    if (d == null || m == null || d < 1 || d > 30 || m < 1 || m > 12) return;
    try {
      final hijri = HijriCalendar()..hDay = d..hMonth = m..hYear = HijriCalendar.now().hYear;
      final dt = hijri.hijriToGregorian(hijri.hYear, hijri.hMonth, hijri.hDay);
      _gregDayCtrl.text   = dt.day.toString();
      _gregMonthCtrl.text = dt.month.toString();
      _computeAll(dt);
    } catch (_) {}
  }

  void _clearConverter() {
    _gregDayCtrl.clear(); _gregMonthCtrl.clear();
    _hijriDayCtrl.clear(); _hijriMonthCtrl.clear();
    _kurdDayCtrl.clear(); _kurdMonthCtrl.clear();
    setState(() { _gregResult = ""; _hijriResult = ""; _kurdResult = ""; });
  }

  // ────────────────────────────────────────────────
  // بەش ٢: دۆزینەوەی کاتی بانگ
  // ────────────────────────────────────────────────

  Future<void> _lookupPrayer() async {
    final int? d = int.tryParse(_prayDayCtrl.text.trim());
    final int? m = int.tryParse(_prayMonthCtrl.text.trim());
    if (d == null || m == null || d < 1 || d > 31 || m < 1 || m > 12) {
      setState(() { _prayError = "ڕۆژ و مانگ بنووسە"; _prayResult = null; });
      return;
    }
    if (_selectedCity == null) {
      setState(() { _prayError = "شار هەڵبژێرە"; _prayResult = null; });
      return;
    }
    final int year = int.tryParse(_prayYearCtrl.text.trim()) ?? DateTime.now().year;
    setState(() { _prayLoading = true; _prayError = ""; _prayResult = null; });
    try {
      final dt = DateTime(year, m, d);
      final times = await widget.dataService.getPrayerTimes(_selectedCity!, dt);
      setState(() { _prayResult = times; _prayLoading = false; });
    } catch (e) {
      setState(() { _prayError = "هەڵە لە دۆزینەوە"; _prayLoading = false; });
    }
  }

  void _clearPrayer() {
    _prayDayCtrl.clear(); _prayMonthCtrl.clear(); _prayYearCtrl.clear();
    setState(() { _prayResult = null; _prayError = ""; _selectedCity = widget.currentCity; });
  }

  // ────────────────────────────────────────────────
  // BUILD
  // ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final Color pc = widget.primaryColor;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(12),
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0F1E),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: pc.withOpacity(0.3)),
          boxShadow: [BoxShadow(color: pc.withOpacity(0.15), blurRadius: 25, spreadRadius: 2)],
        ),
        child: Column(
          children: [
            // ── هیدەر ──
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 10, 10),
              child: Row(
                children: [
                  Icon(Icons.calendar_month, color: pc, size: 22),
                  const SizedBox(width: 10),
                  const Text("گۆڕینی بەروار",
                      style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () { _clearConverter(); _clearPrayer(); Navigator.pop(context); },
                  ),
                ],
              ),
            ),

            // ── تابەکان ──
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabCtrl,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: pc.withOpacity(0.25),
                  border: Border.all(color: pc.withOpacity(0.5)),
                ),
                labelColor: pc,
                unselectedLabelColor: Colors.white54,
                labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: "گۆڕینی بەروار"),
                  Tab(text: "کاتی بانگ"),
                ],
              ),
            ),

            const SizedBox(height: 4),
            const Divider(color: Colors.white12),

            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  _buildConverterTab(pc),
                  _buildPrayerLookupTab(pc),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────
  // تابی گۆڕینی بەروار
  // ────────────────────────────────────────────────
  Widget _buildConverterTab(Color pc) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── سێ ڕیزی تێکستبۆکس ──
          _buildDateRow("میلادی",  _gregDayCtrl,  _gregMonthCtrl,  pc, _convertFromGreg),
          const SizedBox(height: 12),
          _buildDateRow("کۆچی",   _hijriDayCtrl, _hijriMonthCtrl, pc, _convertFromHijri),
          const SizedBox(height: 12),
          _buildDateRow("کوردی",  _kurdDayCtrl,  _kurdMonthCtrl,  pc, null, readOnly: true),

          const SizedBox(height: 20),

          // ── دوگمەی گۆڕین ──
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: pc.withOpacity(0.2),
                    foregroundColor: pc,
                    side: BorderSide(color: pc.withOpacity(0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.swap_horiz, size: 18),
                  label: const Text("بیگۆڕە", style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: _convertFromGreg,
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                onPressed: _clearConverter,
                icon: const Icon(Icons.clear_all, color: Colors.white38),
                tooltip: "پاک بکەرەوە",
              ),
            ],
          ),

          // ── ئەنجامەکان ──
          if (_gregResult.isNotEmpty) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: pc.withOpacity(0.07),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: pc.withOpacity(0.25)),
              ),
              child: Column(
                children: [
                  _buildResultRow(Icons.calendar_today, "میلادی",  _gregResult,  pc),
                  const Divider(color: Colors.white10, height: 20),
                  _buildResultRow(Icons.nightlight_round, "کۆچی", _hijriResult, const Color(0xFFF59E0B)),
                  const Divider(color: Colors.white10, height: 20),
                  _buildResultRow(Icons.landscape, "کوردی",       _kurdResult,  const Color(0xFF4ADE80)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDateRow(String label, TextEditingController dayCtrl,
      TextEditingController monthCtrl, Color pc, VoidCallback? onSubmit,
      {bool readOnly = false}) {
    final style = TextStyle(
      color: readOnly ? Colors.white38 : Colors.white,
      fontSize: 16,
      fontWeight: FontWeight.bold,
    );
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: readOnly ? Colors.white12 : pc.withOpacity(0.4)),
    );

    return Row(
      children: [
        // لەیبڵی جۆری بەروار
        SizedBox(
          width: 52,
          child: Text(label,
              style: const TextStyle(color: Colors.white60, fontSize: 12),
              textAlign: TextAlign.center),
        ),
        const SizedBox(width: 8),
        // تێکستبۆکسی ڕۆژ
        Expanded(
          child: TextField(
            controller: dayCtrl,
            readOnly: readOnly,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 2,
            style: style,
            decoration: InputDecoration(
              counterText: "",
              hintText: "ڕۆژ",
              hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
              filled: true,
              fillColor: Colors.white.withOpacity(readOnly ? 0.03 : 0.07),
              border: border,
              enabledBorder: border,
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: pc, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onSubmitted: (_) { if (onSubmit != null) onSubmit(); },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text("/", style: TextStyle(color: pc, fontSize: 22, fontWeight: FontWeight.bold)),
        ),
        // تێکستبۆکسی مانگ
        Expanded(
          child: TextField(
            controller: monthCtrl,
            readOnly: readOnly,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 2,
            style: style,
            decoration: InputDecoration(
              counterText: "",
              hintText: "مانگ",
              hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
              filled: true,
              fillColor: Colors.white.withOpacity(readOnly ? 0.03 : 0.07),
              border: border,
              enabledBorder: border,
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: pc, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onSubmitted: (_) { if (onSubmit != null) onSubmit(); },
          ),
        ),
      ],
    );
  }

  Widget _buildResultRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Text("$label:  ", style: const TextStyle(color: Colors.white54, fontSize: 13)),
        Expanded(
          child: Text(value,
              style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold),
              textAlign: TextAlign.end),
        ),
      ],
    );
  }

  // ────────────────────────────────────────────────
  // تابی کاتی بانگ
  // ────────────────────────────────────────────────
  Widget _buildPrayerLookupTab(Color pc) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── ڕیزی ڕۆژ / مانگ / ساڵ ──
          Row(
            children: [
              Expanded(child: _buildNumField(_prayDayCtrl,   "ڕۆژ",  pc)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text("/", style: TextStyle(color: pc, fontSize: 22, fontWeight: FontWeight.bold)),
              ),
              Expanded(child: _buildNumField(_prayMonthCtrl, "مانگ", pc)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text("/", style: TextStyle(color: pc, fontSize: 22, fontWeight: FontWeight.bold)),
              ),
              Expanded(
                flex: 2,
                child: _buildNumField(_prayYearCtrl, "ساڵ", pc, maxLen: 4),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ── هەڵبژاردنی شار + دوگمە ──
          Row(
            children: [
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
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: pc.withOpacity(0.2),
                  foregroundColor: pc,
                  side: BorderSide(color: pc.withOpacity(0.5)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
                ),
                onPressed: _lookupPrayer,
                child: const Text("بدۆزەرەوە", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
              const SizedBox(width: 6),
              IconButton(
                onPressed: _clearPrayer,
                icon: const Icon(Icons.clear_all, color: Colors.white38),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── ئەنجام ──
          if (_prayLoading)
            Center(child: CircularProgressIndicator(color: pc))
          else if (_prayError.isNotEmpty)
            Center(child: Text(_prayError, style: const TextStyle(color: Colors.redAccent)))
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
                  // ناوی شار و بەروار
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [
                        Icon(Icons.location_city, color: pc, size: 16),
                        const SizedBox(width: 6),
                        Text(_selectedCity ?? "",
                            style: TextStyle(color: pc, fontWeight: FontWeight.bold, fontSize: 14)),
                      ]),
                      Text(
                        "${_prayDayCtrl.text.padLeft(2,'0')}/${_prayMonthCtrl.text.padLeft(2,'0')}/${_prayYearCtrl.text.isNotEmpty ? _prayYearCtrl.text : DateTime.now().year}",
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white10, height: 20),
                  // کاتەکانی بانگ
                  ...[
                    ["بەیانی",     _prayResult!.fajr,    Icons.wb_twilight,    const Color(0xFF818CF8)],
                    ["خۆرهەڵاتن", _prayResult!.sunrise, Icons.wb_sunny,       Colors.orange],
                    ["نیوەڕۆ",    _prayResult!.dhuhr,   Icons.light_mode,     const Color(0xFFFBBF24)],
                    ["عەسر",      _prayResult!.asr,     Icons.wb_cloudy,      const Color(0xFF34D399)],
                    ["ئێوارە",    _prayResult!.maghrib, Icons.nights_stay,    const Color(0xFFF97316)],
                    ["خەوتنان",   _prayResult!.isha,    Icons.dark_mode,      const Color(0xFF818CF8)],
                  ].map((row) {
                    final name   = row[0] as String;
                    final dt     = row[1] as DateTime;
                    final icon   = row[2] as IconData;
                    final color  = row[3] as Color;
                    final timeStr = "${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}";
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          Icon(icon, color: color, size: 18),
                          const SizedBox(width: 10),
                          Text(name, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                          const Spacer(),
                          Text(
                            widget.timeService.formatTo12Hr(timeStr),
                            style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNumField(TextEditingController ctrl, String hint, Color pc, {int maxLen = 2}) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: pc.withOpacity(0.35)),
    );
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      maxLength: maxLen,
      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
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
          borderSide: BorderSide(color: pc, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }
}
