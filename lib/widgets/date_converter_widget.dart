import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/constants.dart';
import '../services/prayer_service.dart';

// ==================== ویدجەتی گۆڕینی بەروار ====================
class DateConverterDialog extends StatefulWidget {
  final Color primaryColor;
  final ThemePalette palette;
  final PrayerDataService dataService;
  final TimeService timeService;
  final String currentCity;

  const DateConverterDialog({
    super.key,
    required this.primaryColor,
    required this.palette,
    required this.dataService,
    required this.timeService,
    required this.currentCity,
  });

  @override
  State<DateConverterDialog> createState() => _DateConverterDialogState();
}

class _DateConverterDialogState extends State<DateConverterDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  final _gregDayCtrl = TextEditingController();
  final _gregMonthCtrl = TextEditingController();
  final _gregYearCtrl = TextEditingController();

  final _hijriDayCtrl = TextEditingController();
  final _hijriMonthCtrl = TextEditingController();
  final _hijriYearCtrl = TextEditingController();

  final _kurdDayCtrl = TextEditingController();
  final _kurdMonthCtrl = TextEditingController();
  final _kurdYearCtrl = TextEditingController();

  final _shamsiDayCtrl = TextEditingController();
  final _shamsiMonthCtrl = TextEditingController();
  final _shamsiYearCtrl = TextEditingController();

  String _weekdayResult = "";
  String _hijriResult = "";
  String _kurdResult = "";
  String _shamsiResult = "";

  final _prayDayCtrl = TextEditingController();
  final _prayMonthCtrl = TextEditingController();
  final _prayYearCtrl = TextEditingController();
  String? _selectedCity;
  PrayerTimes? _prayResult;
  bool _prayLoading = false;
  String _prayError = "";

  static const int _minYear = 1938;
  static const int _maxYear = 2076;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _selectedCity = widget.currentCity;
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
      _shamsiMonthCtrl,
      _shamsiYearCtrl,
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
        _weekdayResult = "";
      });
      _clearReadonlyFields();
      return;
    }
    if (y < _minYear || y > _maxYear) {
      setState(() {
        _hijriResult = "";
        _kurdResult = "";
        _shamsiResult = "";
        _weekdayResult = "";
      });
      _clearReadonlyFields();
      return;
    }
    try {
      _computeAll(DateTime(y, m, d));
    } catch (_) {}
  }

  void _clearReadonlyFields() {
    _hijriDayCtrl.text = "";
    _hijriMonthCtrl.text = "";
    _hijriYearCtrl.text = "";
    _kurdDayCtrl.text = "";
    _kurdMonthCtrl.text = "";
    _kurdYearCtrl.text = "";
    _shamsiDayCtrl.text = "";
    _shamsiMonthCtrl.text = "";
    _shamsiYearCtrl.text = "";
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
      "ئوردیبهیشت",
      "خورداد",
      "تیر",
      "مورداد",
      "شەهریوەر",
      "میهر",
      "ئابان",
      "ئازەر",
      "دەی",
      "بەهمەن",
      "ئیسفەند"
    ];
    final String mName = (shamsi[1] >= 1 && shamsi[1] <= 12)
        ? shamsiMonths[shamsi[1] - 1]
        : shamsi[1].toString();
    final String shamsiStr =
        "${widget.timeService.toKu(shamsi[2].toString())} $mNameـى ${widget.timeService.toKu(shamsi[0].toString())}";

    setState(() {
      _hijriResult = hijriStr;
      _kurdResult = kurdStr;
      _shamsiResult = shamsiStr;
      _weekdayResult = weekday;
    });

    _hijriDayCtrl.text = hijri.hDay.toString();
    _hijriMonthCtrl.text = hijri.hMonth.toString();
    _hijriYearCtrl.text = hijri.hYear.toString();

    _kurdDayCtrl.text = _kDay(dt).toString();
    _kurdMonthCtrl.text = _kMonth(dt).toString();
    _kurdYearCtrl.text = _kYear(dt).toString();

    _shamsiDayCtrl.text = shamsi[2].toString();
    _shamsiMonthCtrl.text = shamsi[1].toString();
    _shamsiYearCtrl.text = shamsi[0].toString();
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
    _clearReadonlyFields();
    setState(() {
      _hijriResult = "";
      _kurdResult = "";
      _shamsiResult = "";
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
    _prayDayCtrl.clear();
    _prayMonthCtrl.clear();
    _prayYearCtrl.clear();
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
      insetAnimationDuration: Duration.zero,
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.88 -
                MediaQuery.of(context).viewInsets.bottom),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.background,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: pc.withOpacity(0.5)),
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
              Text("گۆڕینی بەروار و دۆزینەوەى کاتى بانگ",
                  style: TextStyle(
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                      fontSize: 13,
                      fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(Icons.close,
                    color: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.color
                        ?.withOpacity(0.5),
                    size: 20),
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
              color: Theme.of(context).colorScheme.background.withOpacity(0.05),
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
              unselectedLabelColor: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.color
                  ?.withOpacity(0.38),
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
          Divider(color: Theme.of(context).dividerColor.withOpacity(0.2)),
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
    return Builder(builder: (context) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
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
              Text("لەساڵى $_minYear تا $_maxYear ئەتوانیت داخل بکەیت",
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
              child:
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.today, color: pc, size: 13),
                const SizedBox(width: 5),
                Text("ڕۆژی هەفتە: ",
                    style: TextStyle(
                        color: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.color
                            ?.withOpacity(0.38),
                        fontSize: 11)),
                Text(_weekdayResult,
                    style: TextStyle(
                        color: pc, fontSize: 12, fontWeight: FontWeight.bold)),
              ]),
            ),
            const SizedBox(height: 7),
          ] else
            const SizedBox(height: 2),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text("میلادی",
                style: TextStyle(
                    color: pc,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0)),
          ]),
          const SizedBox(height: 3),
          _row3(
              _gregDayCtrl, _gregMonthCtrl, _gregYearCtrl, pc, _convertFromGreg,
              topLabel: "میلادی"),
          const SizedBox(height: 6),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: pc.withOpacity(0.18),
                foregroundColor: pc,
                side: BorderSide(color: pc.withOpacity(0.45)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 18),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(Icons.swap_horiz, size: 15),
              label: const Text("بیگۆڕە",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              onPressed: () {
                FocusScope.of(context).unfocus();
                _convertFromGreg();
              },
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.color
                    ?.withOpacity(0.38),
                side: BorderSide(
                    color: Theme.of(context)
                        .colorScheme
                        .background
                        .withOpacity(0.12)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(Icons.delete_outline, size: 14),
              label: const Text("سڕینەوە", style: TextStyle(fontSize: 12)),
              onPressed: _clearConverter,
            ),
          ]),
          Divider(
              color: Theme.of(context).dividerColor.withOpacity(0.5),
              height: 14,
              thickness: 1.5),
          _rowLabel("کۆچی", const Color(0xFFF59E0B)),
          const SizedBox(height: 3),
          _rowDates(const Color(0xFFF59E0B),
              dayCtrl: _hijriDayCtrl,
              monthCtrl: _hijriMonthCtrl,
              yearCtrl: _hijriYearCtrl),
          if (_hijriResult.isNotEmpty) ...[
            const SizedBox(height: 4),
            _resultLine(_hijriResult, const Color(0xFFF59E0B)),
          ],
          Divider(
              color: Theme.of(context).dividerColor.withOpacity(0.5),
              height: 14,
              thickness: 1.5),
          _rowLabel("کوردی", const Color(0xFF4ADE80)),
          const SizedBox(height: 3),
          _rowDates(const Color(0xFF4ADE80),
              dayCtrl: _kurdDayCtrl,
              monthCtrl: _kurdMonthCtrl,
              yearCtrl: _kurdYearCtrl),
          if (_kurdResult.isNotEmpty) ...[
            const SizedBox(height: 4),
            _resultLine(_kurdResult, const Color(0xFF4ADE80)),
          ],
          Divider(
              color: Theme.of(context).dividerColor.withOpacity(0.5),
              height: 14,
              thickness: 1.5),
          _rowLabel("هەتاوی", const Color(0xFFF97316)),
          const SizedBox(height: 3),
          _rowDates(const Color(0xFFF97316),
              dayCtrl: _shamsiDayCtrl,
              monthCtrl: _shamsiMonthCtrl,
              yearCtrl: _shamsiYearCtrl),
          if (_shamsiResult.isNotEmpty) ...[
            const SizedBox(height: 4),
            _resultLine(_shamsiResult, const Color(0xFFF97316)),
          ],
        ]),
      );
    });
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

  Widget _rowDates(
    Color pc, {
    required TextEditingController dayCtrl,
    required TextEditingController monthCtrl,
    required TextEditingController yearCtrl,
  }) {
    return Row(children: [
      Expanded(
          child: Column(children: [
        Text("ڕۆژ", style: TextStyle(color: pc.withOpacity(0.4), fontSize: 9)),
        const SizedBox(height: 2),
        _readonlyBox(dayCtrl.text, pc),
      ])),
      const SizedBox(width: 5),
      Expanded(
          child: Column(children: [
        Text("مانگ", style: TextStyle(color: pc.withOpacity(0.4), fontSize: 9)),
        const SizedBox(height: 2),
        _readonlyBox(monthCtrl.text, pc),
      ])),
      const SizedBox(width: 5),
      Expanded(
          flex: 2,
          child: Column(children: [
            Text("ساڵ",
                style: TextStyle(color: pc.withOpacity(0.4), fontSize: 9)),
            const SizedBox(height: 2),
            _readonlyBox(yearCtrl.text, pc),
          ])),
    ]);
  }

  Widget _readonlyBox(String val, Color pc) {
    return Container(
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: pc.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: pc.withOpacity(0.3)),
      ),
      child: Text(val.isEmpty ? "—" : val,
          style: TextStyle(
              color: pc.withOpacity(0.8),
              fontSize: 13,
              fontWeight: FontWeight.bold)),
    );
  }

  Widget _rowLabel(String label, Color pc) {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(label,
          style: TextStyle(
              color: pc,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0)),
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
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final style = TextStyle(
        color: readOnly ? textColor?.withOpacity(0.12) : textColor,
        fontSize: 13,
        fontWeight: FontWeight.bold);
    final BorderRadius br = BorderRadius.circular(8);
    final Color borderColor = readOnly
        ? (textColor?.withOpacity(0.06) ?? Colors.transparent)
        : pc.withOpacity(0.35);

    InputDecoration dec(String hint) => InputDecoration(
          counterText: "",
          hintText: readOnly ? "—" : hint,
          hintStyle: TextStyle(
              color: textColor?.withOpacity(readOnly ? 0.06 : 0.2),
              fontSize: 11),
          filled: true,
          fillColor: textColor?.withOpacity(readOnly ? 0.02 : 0.06),
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
                    if (onSubmit != null) onSubmit();
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
                    if (onSubmit != null) onSubmit();
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
                        if (onSubmit != null) onSubmit();
                      }),
          ])),
    ]);
  }

  Widget _buildPrayerLookupTab(Color pc) {
    return Builder(builder: (context) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
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
            const SizedBox(width: 6),
            Expanded(child: _numField(_prayMonthCtrl, "مانگ", pc)),
            const SizedBox(width: 6),
            Expanded(
                flex: 2, child: _numField(_prayYearCtrl, "ساڵ", pc, maxLen: 4)),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
                child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color:
                    Theme.of(context).colorScheme.background.withOpacity(0.07),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: pc.withOpacity(0.35)),
              ),
              child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                value: _selectedCity,
                dropdownColor: Theme.of(context).colorScheme.background,
                style: TextStyle(
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                    fontSize: 13),
                iconEnabledColor: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.color
                    ?.withOpacity(0.54),
                isExpanded: true,
                hint: Text("شار",
                    style: TextStyle(
                        color: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.color
                            ?.withOpacity(0.38))),
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
                padding:
                    const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
              ),
              onPressed: () {
                FocusScope.of(context).unfocus();
                _lookupPrayer();
              },
              child: const Text("بدۆزەرەوە",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
            const SizedBox(width: 6),
            IconButton(
                onPressed: _clearPrayer,
                icon: Icon(Icons.clear_all,
                    color: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.color
                        ?.withOpacity(0.38))),
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
                        style:
                            const TextStyle(color: Colors.red, fontSize: 13))),
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
                            style: TextStyle(
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.color
                                    ?.withOpacity(0.54),
                                fontSize: 12),
                          ),
                        ]),
                    Divider(
                        color: Theme.of(context).dividerColor.withOpacity(0.1),
                        height: 20),
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
                              style: TextStyle(
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.color
                                      ?.withOpacity(0.7),
                                  fontSize: 14)),
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
            const SizedBox(height: 10),
            Center(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.color
                      ?.withOpacity(0.38),
                  side: BorderSide(
                      color: Theme.of(context)
                          .colorScheme
                          .background
                          .withOpacity(0.12)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  padding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.delete_outline, size: 14),
                label: const Text("سڕینەوە", style: TextStyle(fontSize: 12)),
                onPressed: _clearPrayer,
              ),
            ),
          ],
        ]),
      );
    });
  }

  Widget _numField(TextEditingController ctrl, String hint, Color pc,
      {int maxLen = 2, void Function(String)? onChanged}) {
    final border = OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: pc.withOpacity(0.35)));
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      maxLength: maxLen,
      onChanged: onChanged,
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
