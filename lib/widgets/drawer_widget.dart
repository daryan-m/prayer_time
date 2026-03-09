import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hijri/hijri_calendar.dart';
import '../utils/constants.dart';
import '../services/prayer_service.dart';
import 'allah_names_widget.dart';

// ==================== داتای تەسبیح ====================

class _ZikrItem {
  final String arabic;
  final String kurdish;
  final int target;
  _ZikrItem(this.arabic, this.kurdish, this.target);
}

final List<_ZikrItem> _zikrList = [
  _ZikrItem("سُبْحَانَ اللَّهِ",                          "پیرۆزی خوا",                         33),
  _ZikrItem("الْحَمْدُ لِلَّهِ",                          "ستایش بۆ خوا",                       33),
  _ZikrItem("اللَّهُ أَكْبَرُ",                           "خوا گەورەترە",                       34),
  _ZikrItem("لَا إِلَٰهَ إِلَّا اللَّهُ",                "هیچ خوایەک نییە جگە لە خوا",        100),
  _ZikrItem("أَسْتَغْفِرُ اللَّهَ",                       "داوای لێخۆشی لە خوا دەکەم",         100),
  _ZikrItem("سُبْحَانَ اللَّهِ وَبِحَمْدِهِ",            "پیرۆزی خوا و ستایشی",               100),
  _ZikrItem("لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ","هیچ هێز و توانایەک نییە جگە بە خوا",  33),
  _ZikrItem("اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ",          "خودایا درود لە سەر محمد بنێرە",       10),
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
            border: Border(left: BorderSide(color: pal.drawerBorder, width: 3.0)),
          ),
          child: Column(
            children: [
              _buildHeader(context, pal),
              Divider(color: pal.primary, thickness: 1),
              Expanded(
                child: ListView(
                  children: [
                    _buildExpansionTile(Icons.record_voice_over, "دەنگی بانگبێژ", pal, [
                      _buildAthanOption("م. کمال رؤوف", "kamal_rauf.mp3", pal),
                      _buildAthanOption("بانگی مەدینە",  "madina.mp3",    pal),
                      _buildAthanOption("بانگی کوەیت",  "kwait.mp3",     pal),
                    ]),
                    _divider(pal),
                    _buildExpansionTile(Icons.location_city, "هەڵبژاردنی شار", pal,
                      kurdistanCitiesData.map((c) => _buildCityOption(c, pal)).toList()),
                    _divider(pal),
                    // ── ڕووکارەکان ──
                    _buildExpansionTile(Icons.palette, "ڕووکارەکان", pal,
                      appThemes.keys.map((themeName) => ListTile(
                        title: Text("ڕووکاری $themeName",
                            style: TextStyle(color: pal.listText, fontSize: 13)),
                        leading: Radio<String>(
                          value: themeName,
                          groupValue: widget.selectedThemeName,
                          activeColor: appThemes[themeName],
                          onChanged: (v) { if (v != null) widget.onThemeChanged(v, appThemes[v]!); },
                        ),
                        onTap: () => widget.onThemeChanged(themeName, appThemes[themeName]!),
                      )).toList(),
                    ),
                    _divider(pal),
                    // ── تەسبیح ──
                    ListTile(
                      leading: Icon(Icons.grain, color: pal.primary, size: 22),
                      title: Text("تەسبیح",
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: pal.listText)),
                      trailing: Icon(Icons.arrow_forward_ios, color: pal.listText.withOpacity(0.4), size: 14),
                      onTap: () => showDialog(context: context,
                          builder: (_) => _TasbihDialog(primaryColor: pal.primary)),
                    ),
                    _divider(pal),
                    // ── ناوەکانی خوا ──
                    ListTile(
                      leading: Icon(Icons.auto_awesome, color: pal.primary, size: 22),
                      title: Text("ناوەکانی خوای گەورە",
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: pal.listText)),
                      trailing: Icon(Icons.arrow_forward_ios, color: pal.listText.withOpacity(0.4), size: 14),
                      onTap: () => showDialog(context: context,
                          builder: (_) => AllahNamesDialog(primaryColor: pal.primary)),
                    ),
                    _divider(pal),
                    // ── گۆڕینی بەروار ──
                    ListTile(
                      leading: Icon(Icons.calendar_month, color: pal.primary, size: 22),
                      title: Text("گۆڕینی بەروار",
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: pal.listText)),
                      trailing: Icon(Icons.arrow_forward_ios, color: pal.listText.withOpacity(0.4), size: 14),
                      onTap: () => showDialog(context: context,
                          builder: (_) => _DateConverterDialog(
                            primaryColor: pal.primary, palette: pal,
                            dataService: PrayerDataService(), timeService: TimeService(),
                            currentCity: widget.currentCity,
                          )),
                    ),
                    Divider(color: pal.primary.withOpacity(0.15), thickness: 2),
                    // ── یوتیوب ──
                    ListTile(
                      leading: const Icon(Icons.play_circle_fill, color: Colors.red, size: 28),
                      title: Text("ئێمە لە یوتیوب",
                          style: TextStyle(color: pal.listText, fontSize: 14, fontWeight: FontWeight.bold)),
                      onTap: () async {
                        final Uri url = Uri.parse('https://www.youtube.com/@daryan111');
                        if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
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
      color: pal.primary.withOpacity(0.15), thickness: 2, indent: 20, endIndent: 20);

  Widget _buildHeader(BuildContext context, ThemePalette pal) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 25, 8, 10),
      child: Row(children: [
        Icon(Icons.mosque, size: 30, color: pal.secondary),
        const SizedBox(width: 12),
        Text("ڕێکخستنەکان",
            style: TextStyle(color: pal.headerText, fontSize: 18, fontWeight: FontWeight.bold)),
        const Spacer(),
        IconButton(icon: const Icon(Icons.close, color: Colors.red),
            onPressed: () => Navigator.pop(context)),
      ]),
    );
  }

  Widget _buildAthanOption(String title, String fileName, ThemePalette pal) {
    final bool isSelected = _localSelectedAthan == fileName;
    final bool isPlaying  = _currentlyPlaying   == fileName;
    return ListTile(
      leading: IconButton(
        icon: Icon(isPlaying ? Icons.stop_circle : Icons.play_circle_fill,
            color: isPlaying ? Colors.redAccent : Colors.lightBlueAccent, size: 30),
        onPressed: () => _togglePreview(fileName),
      ),
      title: Text(title,
          style: TextStyle(
            color: isSelected ? pal.primary : pal.listText,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          )),
      trailing: Radio<String>(
        value: fileName, groupValue: _localSelectedAthan,
        activeColor: pal.primary,
        onChanged: (v) { if (v != null) _selectAthan(v); },
      ),
      onTap: () => _selectAthan(fileName),
    );
  }

  Widget _buildCityOption(String cityName, ThemePalette pal) {
    return ListTile(
      title: Text(cityName, style: TextStyle(color: pal.listText, fontSize: 13)),
      leading: Radio<String>(
        value: cityName, groupValue: widget.currentCity,
        activeColor: pal.primary,
        onChanged: (v) { if (v != null) widget.onCityChanged(v); },
      ),
      onTap: () => widget.onCityChanged(cityName),
    );
  }

  Widget _buildAboutContent(ThemePalette pal) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text("ئەم ئەپلیکەیشنە تایبەتە بە کاتى بانگى شارو شارۆچکەکانى هەرێمى کوردستان.",
            style: TextStyle(color: pal.listText, fontSize: 13, height: 1.5)),
        const SizedBox(height: 15),
        Row(children: [
          Icon(Icons.label_outline, color: pal.primary, size: 16),
          const SizedBox(width: 8),
          Text("وەشانى: $currentAppVersion",
              style: TextStyle(color: pal.listText.withOpacity(0.7), fontSize: 14)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Icon(Icons.brush_outlined, color: pal.primary, size: 16),
          const SizedBox(width: 8),
          Text("دیزاینەر: داریان مەزهەر",
              style: TextStyle(color: pal.listText.withOpacity(0.7), fontSize: 14)),
        ]),
      ]),
    );
  }

  Widget _buildExpansionTile(IconData icon, String title, ThemePalette pal, List<Widget> children) {
    return ExpansionTile(
      leading: Icon(icon, color: pal.primary, size: 22),
      title: Text(title,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: pal.listText)),
      iconColor: pal.primary,
      collapsedIconColor: pal.listText.withOpacity(0.6),
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

class _TasbihDialogState extends State<_TasbihDialog> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  int _count = 0;
  int _totalCount = 0;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 120));
    _pulseAnim = Tween<double>(begin: 1.0, end: 0.93)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _pulseCtrl.dispose(); super.dispose(); }

  _ZikrItem get _current => _zikrList[_selectedIndex];

  void _tap() async {
    await _pulseCtrl.forward(); await _pulseCtrl.reverse();
    setState(() { _count++; _totalCount++; });
    if (_count >= _current.target) {
      await Future.delayed(const Duration(milliseconds: 150));
      if (mounted) { setState(() => _count = 0); _showRoundComplete(); }
    }
  }

  void _reset() => setState(() { _count = 0; _totalCount = 0; });

  void _showRoundComplete() {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text("${_current.target} جار تەواو بوو ✓",
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      backgroundColor: Colors.green.shade700,
      duration: const Duration(seconds: 1),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
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
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0F1E),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: pc.withOpacity(0.3)),
          boxShadow: [BoxShadow(color: pc.withOpacity(0.2), blurRadius: 30, spreadRadius: 2)],
        ),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 12, 10),
            child: Row(children: [
              Icon(Icons.grain, color: pc, size: 22),
              const SizedBox(width: 10),
              const Text("تەسبیح",
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: pc.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: pc.withOpacity(0.3))),
                child: Text("کۆی: $_totalCount", style: TextStyle(color: pc, fontSize: 12)),
              ),
              const SizedBox(width: 8),
              IconButton(icon: const Icon(Icons.close, color: Colors.white54),
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
                  onTap: () => setState(() { _selectedIndex = i; _count = 0; }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected ? pc : Colors.white.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: selected ? pc : Colors.white24),
                    ),
                    child: Text(_zikrList[i].kurdish,
                        style: TextStyle(
                          color: selected ? Colors.black87 : Colors.white70,
                          fontSize: 12,
                          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                        )),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(_current.arabic, textAlign: TextAlign.center,
                style: TextStyle(color: pc, fontSize: 22, fontWeight: FontWeight.bold, height: 1.6)),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text("$_count",
                    style: TextStyle(color: pc, fontSize: 13, fontWeight: FontWeight.bold)),
                Text("$target", style: const TextStyle(color: Colors.white38, fontSize: 13)),
              ]),
              const SizedBox(height: 6),
              ClipRRect(borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(value: progress, minHeight: 8,
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation<Color>(pc))),
            ]),
          ),
          const SizedBox(height: 28),
          GestureDetector(
            onTap: _tap,
            child: ScaleTransition(
              scale: _pulseAnim,
              child: Container(
                width: 160, height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                      colors: [pc.withOpacity(0.35), pc.withOpacity(0.08)]),
                  border: Border.all(color: pc.withOpacity(0.6), width: 2.5),
                  boxShadow: [BoxShadow(color: pc.withOpacity(0.3), blurRadius: 25, spreadRadius: 4)],
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text("$_count",
                      style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold)),
                  Text("/ $target",
                      style: TextStyle(color: pc.withOpacity(0.7), fontSize: 16)),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 24),
          TextButton.icon(
            onPressed: _reset,
            icon: const Icon(Icons.refresh, color: Colors.white54, size: 18),
            label: const Text("ڕیست", style: TextStyle(color: Colors.white54, fontSize: 13)),
          ),
          const SizedBox(height: 16),
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
    required this.primaryColor, required this.palette,
    required this.dataService, required this.timeService,
    required this.currentCity,
  });

  @override
  State<_DateConverterDialog> createState() => _DateConverterDialogState();
}

class _DateConverterDialogState extends State<_DateConverterDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  final _gregDayCtrl    = TextEditingController();
  final _gregMonthCtrl  = TextEditingController();
  final _gregYearCtrl   = TextEditingController();
  final _hijriDayCtrl   = TextEditingController();
  final _hijriMonthCtrl = TextEditingController();
  final _hijriYearCtrl  = TextEditingController();
  final _kurdDayCtrl    = TextEditingController();
  final _kurdMonthCtrl  = TextEditingController();
  final _kurdYearCtrl   = TextEditingController();

  String _gregResult  = "";
  String _hijriResult = "";
  String _kurdResult  = "";

  final _prayDayCtrl   = TextEditingController();
  final _prayMonthCtrl = TextEditingController();
  final _prayYearCtrl  = TextEditingController();
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
    final now = DateTime.now();
    _gregYearCtrl.text  = now.year.toString();
    _hijriYearCtrl.text = HijriCalendar.now().hYear.toString();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    for (final c in [_gregDayCtrl,_gregMonthCtrl,_gregYearCtrl,
                     _hijriDayCtrl,_hijriMonthCtrl,_hijriYearCtrl,
                     _kurdDayCtrl,_kurdMonthCtrl,_kurdYearCtrl,
                     _prayDayCtrl,_prayMonthCtrl,_prayYearCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  void _convertFromGreg() {
    final d = int.tryParse(_gregDayCtrl.text.trim());
    final m = int.tryParse(_gregMonthCtrl.text.trim());
    final y = int.tryParse(_gregYearCtrl.text.trim());
    if (d == null || m == null || y == null || d < 1 || d > 31 || m < 1 || m > 12) {
      setState(() { _gregResult = ""; _hijriResult = ""; _kurdResult = ""; });
      return;
    }
    try { _computeAll(DateTime(y, m, d)); } catch (_) {}
  }

  void _convertFromHijri() {
    final d = int.tryParse(_hijriDayCtrl.text.trim());
    final m = int.tryParse(_hijriMonthCtrl.text.trim());
    final y = int.tryParse(_hijriYearCtrl.text.trim());
    if (d == null || m == null || y == null || d < 1 || d > 30 || m < 1 || m > 12) return;
    try {
      final hijri = HijriCalendar()..hDay = d..hMonth = m..hYear = y;
      final dt = hijri.hijriToGregorian(y, m, d);
      _gregDayCtrl.text   = dt.day.toString();
      _gregMonthCtrl.text = dt.month.toString();
      _gregYearCtrl.text  = dt.year.toString();
      _computeAll(dt);
    } catch (_) {}
  }

  void _computeAll(DateTime dt) {
    final gregStr  = "${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year}";
    final hijri    = HijriCalendar.fromDate(dt);
    final hijriStr = "${widget.timeService.toKu(hijri.hDay.toString())}ـى ${hijri.toFormat("MMMM")} ${widget.timeService.toKu(hijri.hYear.toString())}";
    final kurdStr  = widget.timeService.kurdishDateString(dt);

    setState(() { _gregResult = gregStr; _hijriResult = hijriStr; _kurdResult = kurdStr; });

    _hijriDayCtrl.text   = hijri.hDay.toString();
    _hijriMonthCtrl.text = hijri.hMonth.toString();
    _hijriYearCtrl.text  = hijri.hYear.toString();
    _kurdDayCtrl.text    = _kDay(dt).toString();
    _kurdMonthCtrl.text  = _kMonth(dt).toString();
    _kurdYearCtrl.text   = _kYear(dt).toString();
  }

  int _kDay(DateTime dt) {
    final base = _kBase(dt); final diff = dt.difference(base).inDays;
    return diff < 186 ? (diff % 31) + 1 : ((diff - 186) % 30) + 1;
  }
  int _kMonth(DateTime dt) {
    final base = _kBase(dt); final diff = dt.difference(base).inDays;
    int km = diff < 186 ? (diff ~/ 31) + 1 : ((diff - 186) ~/ 30) + 7;
    return km > 12 ? 12 : km;
  }
  int _kYear(DateTime dt) {
    final noroz = DateTime(dt.year, 3, 21);
    return (dt.isBefore(noroz) ? dt.year - 1 : dt.year) - 621;
  }
  DateTime _kBase(DateTime dt) {
    final noroz = DateTime(dt.year, 3, 21);
    return dt.isBefore(noroz) ? DateTime(dt.year - 1, 3, 21) : noroz;
  }

  void _clearConverter() {
    _gregDayCtrl.clear(); _gregMonthCtrl.clear();
    _hijriDayCtrl.clear(); _hijriMonthCtrl.clear();
    _kurdDayCtrl.clear(); _kurdMonthCtrl.clear(); _kurdYearCtrl.clear();
    _gregYearCtrl.text  = DateTime.now().year.toString();
    _hijriYearCtrl.text = HijriCalendar.now().hYear.toString();
    setState(() { _gregResult = ""; _hijriResult = ""; _kurdResult = ""; });
  }

  Future<void> _lookupPrayer() async {
    final d = int.tryParse(_prayDayCtrl.text.trim());
    final m = int.tryParse(_prayMonthCtrl.text.trim());
    final y = int.tryParse(_prayYearCtrl.text.trim());

    if (d == null || m == null || d < 1 || d > 31 || m < 1 || m > 12) {
      setState(() { _prayError = "ڕۆژ و مانگ بنووسە"; _prayResult = null; }); return;
    }
    if (_selectedCity == null) {
      setState(() { _prayError = "شار هەڵبژێرە"; _prayResult = null; }); return;
    }
    final int year = y ?? DateTime.now().year;
    if (year < _minYear) {
      setState(() {
        _prayError = "تکایە لە ١/١/$_minYear ەوە گەران بکە بۆ کاتی بانگ";
        _prayResult = null;
      }); return;
    }
    if (year > _maxYear) {
      setState(() {
        _prayError = "تەنها تاکو بەروارى ٣١/١٢/$_maxYear ئەتوانیت بگەڕیت بۆ کاتی بانگ";
        _prayResult = null;
      }); return;
    }

    setState(() { _prayLoading = true; _prayError = ""; _prayResult = null; });
    try {
      final times = await widget.dataService.getPrayerTimes(_selectedCity!, DateTime(year, m, d));
      setState(() { _prayResult = times; _prayLoading = false; });
    } catch (e) {
      setState(() { _prayError = "هەڵە لە دۆزینەوە"; _prayLoading = false; });
    }
  }

  void _clearPrayer() {
    _prayDayCtrl.clear(); _prayMonthCtrl.clear(); _prayYearCtrl.clear();
    setState(() { _prayResult = null; _prayError = ""; _selectedCity = widget.currentCity; });
  }

  @override
  Widget build(BuildContext context) {
    final pc = widget.primaryColor;
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
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 10, 10),
            child: Row(children: [
              Icon(Icons.calendar_month, color: pc, size: 22),
              const SizedBox(width: 10),
              const Text("گۆڕینی بەروار",
                  style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white54),
                onPressed: () { _clearConverter(); _clearPrayer(); Navigator.pop(context); },
              ),
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
                borderRadius: BorderRadius.circular(12),
                color: pc.withOpacity(0.25),
                border: Border.all(color: pc.withOpacity(0.5)),
              ),
              labelColor: pc,
              unselectedLabelColor: Colors.white54,
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              dividerColor: Colors.transparent,
              tabs: const [Tab(text: "گۆڕینی بەروار"), Tab(text: "کاتی بانگ")],
            ),
          ),
          const SizedBox(height: 4),
          const Divider(color: Colors.white12),
          Expanded(child: TabBarView(controller: _tabCtrl, children: [
            _buildConverterTab(pc),
            _buildPrayerLookupTab(pc),
          ])),
        ]),
      ),
    );
  }

  Widget _buildConverterTab(Color pc) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _row3("میلادی", _gregDayCtrl,  _gregMonthCtrl,  _gregYearCtrl,  pc, _convertFromGreg),
        const SizedBox(height: 12),
        _row3("کۆچی",  _hijriDayCtrl, _hijriMonthCtrl, _hijriYearCtrl, pc, _convertFromHijri),
        const SizedBox(height: 12),
        _row3("کوردی", _kurdDayCtrl,  _kurdMonthCtrl,  _kurdYearCtrl,  pc, null, readOnly: true),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: pc.withOpacity(0.2), foregroundColor: pc,
              side: BorderSide(color: pc.withOpacity(0.5)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            icon: const Icon(Icons.swap_horiz, size: 18),
            label: const Text("بیگۆڕە", style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: _convertFromGreg,
          )),
          const SizedBox(width: 10),
          IconButton(onPressed: _clearConverter,
              icon: const Icon(Icons.clear_all, color: Colors.white38)),
        ]),
        if (_gregResult.isNotEmpty) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: pc.withOpacity(0.07), borderRadius: BorderRadius.circular(14),
              border: Border.all(color: pc.withOpacity(0.25)),
            ),
            child: Column(children: [
              _resultRow(Icons.calendar_today,   "میلادی", _gregResult,  pc),
              const Divider(color: Colors.white10, height: 20),
              _resultRow(Icons.nightlight_round,  "کۆچی",  _hijriResult, const Color(0xFFF59E0B)),
              const Divider(color: Colors.white10, height: 20),
              _resultRow(Icons.landscape,         "کوردی", _kurdResult,  const Color(0xFF4ADE80)),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _row3(String label, TextEditingController d, TextEditingController m,
      TextEditingController y, Color pc, VoidCallback? onSubmit, {bool readOnly = false}) {
    final style = TextStyle(color: readOnly ? Colors.white38 : Colors.white,
        fontSize: 14, fontWeight: FontWeight.bold);
    BorderRadius br = BorderRadius.circular(10);
    InputDecoration dec(String hint) => InputDecoration(
      counterText: "", hintText: hint,
      hintStyle: const TextStyle(color: Colors.white24, fontSize: 11),
      filled: true, fillColor: Colors.white.withOpacity(readOnly ? 0.03 : 0.07),
      border: OutlineInputBorder(borderRadius: br,
          borderSide: BorderSide(color: readOnly ? Colors.white12 : pc.withOpacity(0.4))),
      enabledBorder: OutlineInputBorder(borderRadius: br,
          borderSide: BorderSide(color: readOnly ? Colors.white12 : pc.withOpacity(0.4))),
      focusedBorder: OutlineInputBorder(borderRadius: br,
          borderSide: BorderSide(color: pc, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(vertical: 10),
    );
    sep() => Padding(padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text("/", style: TextStyle(color: pc, fontSize: 20, fontWeight: FontWeight.bold)));

    return Row(children: [
      SizedBox(width: 46, child: Text(label,
          style: const TextStyle(color: Colors.white60, fontSize: 11), textAlign: TextAlign.center)),
      const SizedBox(width: 5),
      Expanded(child: TextField(controller: d, readOnly: readOnly,
          keyboardType: TextInputType.number, textAlign: TextAlign.center,
          maxLength: 2, style: style, decoration: dec("ڕۆژ"),
          onSubmitted: (_) { if (onSubmit != null) onSubmit(); })),
      sep(),
      Expanded(child: TextField(controller: m, readOnly: readOnly,
          keyboardType: TextInputType.number, textAlign: TextAlign.center,
          maxLength: 2, style: style, decoration: dec("مانگ"),
          onSubmitted: (_) { if (onSubmit != null) onSubmit(); })),
      sep(),
      Expanded(flex: 2, child: TextField(controller: y, readOnly: readOnly,
          keyboardType: TextInputType.number, textAlign: TextAlign.center,
          maxLength: 4, style: style, decoration: dec("ساڵ"),
          onSubmitted: (_) { if (onSubmit != null) onSubmit(); })),
    ]);
  }

  Widget _resultRow(IconData icon, String label, String value, Color color) {
    return Row(children: [
      Icon(icon, color: color, size: 16), const SizedBox(width: 8),
      Text("$label:  ", style: const TextStyle(color: Colors.white54, fontSize: 13)),
      Expanded(child: Text(value,
          style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold),
          textAlign: TextAlign.end)),
    ]);
  }

  Widget _buildPrayerLookupTab(Color pc) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: _numField(_prayDayCtrl,   "ڕۆژ",  pc)),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Text("/", style: TextStyle(color: pc, fontSize: 20, fontWeight: FontWeight.bold))),
          Expanded(child: _numField(_prayMonthCtrl, "مانگ", pc)),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Text("/", style: TextStyle(color: pc, fontSize: 20, fontWeight: FontWeight.bold))),
          Expanded(flex: 2, child: _numField(_prayYearCtrl, "ساڵ", pc, maxLen: 4)),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.07), borderRadius: BorderRadius.circular(10),
              border: Border.all(color: pc.withOpacity(0.35)),
            ),
            child: DropdownButtonHideUnderline(child: DropdownButton<String>(
              value: _selectedCity, dropdownColor: const Color(0xFF0F172A),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              iconEnabledColor: Colors.white54, isExpanded: true,
              hint: const Text("شار", style: TextStyle(color: Colors.white38)),
              items: kurdistanCitiesData
                  .map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() => _selectedCity = v),
            )),
          )),
          const SizedBox(width: 10),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: pc.withOpacity(0.2), foregroundColor: pc,
              side: BorderSide(color: pc.withOpacity(0.5)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
            ),
            onPressed: _lookupPrayer,
            child: const Text("بدۆزەرەوە",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          const SizedBox(width: 6),
          IconButton(onPressed: _clearPrayer,
              icon: const Icon(Icons.clear_all, color: Colors.white38)),
        ]),
        const SizedBox(height: 16),
        if (_prayLoading)
          Center(child: CircularProgressIndicator(color: pc))
        else if (_prayError.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.info_outline, color: Colors.orange, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(_prayError,
                  style: const TextStyle(color: Colors.orange, fontSize: 13))),
            ]),
          )
        else if (_prayResult != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: pc.withOpacity(0.07), borderRadius: BorderRadius.circular(14),
              border: Border.all(color: pc.withOpacity(0.25)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Row(children: [
                  Icon(Icons.location_city, color: pc, size: 16), const SizedBox(width: 6),
                  Text(_selectedCity ?? "",
                      style: TextStyle(color: pc, fontWeight: FontWeight.bold, fontSize: 14)),
                ]),
                Text(
                  "${_prayDayCtrl.text.padLeft(2,'0')}/${_prayMonthCtrl.text.padLeft(2,'0')}/${_prayYearCtrl.text.isNotEmpty ? _prayYearCtrl.text : DateTime.now().year}",
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ]),
              const Divider(color: Colors.white10, height: 20),
              ...[
                ["بەیانی",    _prayResult!.fajr,    Icons.wb_twilight,  const Color(0xFF818CF8)],
                ["خۆرهەڵاتن",_prayResult!.sunrise, Icons.wb_sunny,     Colors.orange],
                ["نیوەڕۆ",   _prayResult!.dhuhr,   Icons.light_mode,   const Color(0xFFFBBF24)],
                ["عەسر",     _prayResult!.asr,     Icons.wb_cloudy,    const Color(0xFF34D399)],
                ["ئێوارە",   _prayResult!.maghrib, Icons.nights_stay,  const Color(0xFFF97316)],
                ["خەوتنان",  _prayResult!.isha,    Icons.dark_mode,    const Color(0xFF818CF8)],
              ].map((row) {
                final name   = row[0] as String;
                final dt     = row[1] as DateTime;
                final icon   = row[2] as IconData;
                final color  = row[3] as Color;
                final ts = "${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}";
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(children: [
                    Icon(icon, color: color, size: 18), const SizedBox(width: 10),
                    Text(name, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                    const Spacer(),
                    Text(widget.timeService.formatTo12Hr(ts),
                        style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.bold)),
                  ]),
                );
              }).toList(),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _numField(TextEditingController ctrl, String hint, Color pc, {int maxLen = 2}) {
    final border = OutlineInputBorder(borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: pc.withOpacity(0.35)));
    return TextField(
      controller: ctrl, keyboardType: TextInputType.number,
      textAlign: TextAlign.center, maxLength: maxLen,
      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        counterText: "", hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
        filled: true, fillColor: Colors.white.withOpacity(0.07),
        border: border, enabledBorder: border,
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: pc, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }
}
