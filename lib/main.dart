import 'package:flutter/material.dart';
import 'dart:async';

import 'time_service.dart';
import 'kurdistan_cities.dart';
import 'prayer_calc_service.dart';
import 'prayer_times_model.dart';

void main() => runApp(const PrayerTimesApp());

class PrayerTimesApp extends StatelessWidget {
  const PrayerTimesApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF020617),
        textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'NotoNaskh'),
      ),
      home: const PrayerHomePage(),
    );
  }
}

class PrayerHomePage extends StatefulWidget {
  const PrayerHomePage({super.key});
  @override
  State<PrayerHomePage> createState() => _PrayerHomePageState();
}

class _PrayerHomePageState extends State<PrayerHomePage>
    with TickerProviderStateMixin {
  final TimeService _timeService = TimeService();
  final PrayerCalcService _prayerCalc = PrayerCalcService();

  DateTime _now = DateTime.now();
  String currentCity = "پێنجوێن";
  String? activeAthan;

  final List<String> prayerNames = [
    "بەیانی",
    "خۆرهەڵاتن",
    "نیوەڕۆ",
    "عەسر",
    "ئێوارە",
    "خەوتنان"
  ];

  List<String> todayTimes = [
    "--:--",
    "--:--",
    "--:--",
    "--:--",
    "--:--",
    "--:--"
  ];

  late AnimationController _sunController;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();

    _sunController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    // ✅ چارەسەری جولەی کاتژمێر:
    // تەنها چرکە نوێ دەکاتەوە، بەڵام UI نەلەرزێت
    _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
      final now = DateTime.now();
      if (!mounted) return;
      if (now.second != _now.second) setState(() => _now = now);
    });

    _recalculateForCity();
  }

  void _recalculateForCity() {
    final city = kurdistanCities.firstWhere((c) => c.name == currentCity);

    final times = _prayerCalc.calculateForDate(
      date: DateTime(_now.year, _now.month, _now.day),
      latitude: city.lat,
      longitude: city.lng,
      timeZoneHours: _timeService.timeZoneHours(),
    );

    setState(() {
      todayTimes = times.toSixTimesList();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _sunController.dispose();
    super.dispose();
  }

  String toKu(String n) => _timeService.toKu(n);

  String get hijriDate => _timeService.hijriDateString(_now);
  String get gregorianDate => _timeService.gregorianDateString(_now);
  String get kurdishDate {
    // offline calculation sample
    int kMonth = (_now.month + 8) % 12 + 1;
    int kDay = _now.day;
    int kYear = 2725;
    return "$kDay / $kMonth / $kYear";
  }

  String getNextPrayerRemaining() {
    final times = PrayerTimesModel.fromSixTimes(todayTimes);
    return toKu(_timeService.nextPrayerRemaining(_now, times));
  }

  String getNextPrayerName() {
    final times = PrayerTimesModel.fromSixTimes(todayTimes);
    return _timeService.nextPrayerName(_now, times);
  }

  String formatTo12Hr(String time24) => _timeService.formatTo12Hr(time24);

  @override
  Widget build(BuildContext context) {
    // ئەگەر ڕۆژ گۆڕا، کاتەکان نوێ بکەوە (ئۆفلاین)
    if (_now.hour == 0 && _now.minute == 0 && _now.second == 1) {
      Future.microtask(_recalculateForCity);
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF0F172A),
          elevation: 0,
          leadingWidth: 120,
          leading: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: 15),
              Icon(Icons.mosque, color: Color(0xFF10B981), size: 22),
              SizedBox(width: 6),
              Flexible(
                child: Text(
                  "کاتەکان",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          title: Text(currentCity,
              style: const TextStyle(
                  fontSize: 18,
                  color: Colors.white,
                  fontWeight: FontWeight.w500)),
          centerTitle: true,
          actions: [
            Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu_open,
                    color: Color(0xFF22D3EE), size: 30),
                onPressed: () => Scaffold.of(context).openEndDrawer(),
              ),
            ),
          ],
        ),
        endDrawer: _buildPremiumDrawer(),
        body: Column(
          children: [
            const SizedBox(height: 10),
            _buildClockSection(),
            _buildDatesSection(),
            _buildNextBar(),
            Expanded(
              child: ListView.builder(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                itemCount: 6,
                itemBuilder: (context, i) {
                  return _buildPrayerCard(prayerNames[i], todayTimes[i],
                      isSun: i == 1);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- UI (هەمووی هەمانە) ----------------

  Widget _buildClockSection() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              toKu(
                "${(_now.hour % 12 == 0 ? 12 : _now.hour % 12).toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}:${_now.second.toString().padLeft(2, '0')}",
              ),
              style: const TextStyle(
                  fontSize: 52,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
            const SizedBox(width: 12),
            Text(
              _now.hour >= 12 ? "د.ن" : "پ.ن",
              style: const TextStyle(
                  color: Color(0xFF22D3EE),
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
        Container(
          width: 200,
          height: 2,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [
              Colors.transparent,
              Color(0xFF22D3EE),
              Colors.transparent
            ]),
            boxShadow: [
              BoxShadow(
                  color: const Color(0xFF22D3EE).withValues(alpha: 0.7),
                  blurRadius: 12)
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDatesSection() {
    return Column(
      children: [
        const SizedBox(height: 10),
        Text(
          hijriDate,
          style: const TextStyle(
              color: Color(0xFF10B981),
              fontWeight: FontWeight.bold,
              fontSize: 18),
        ),
        const Divider(
            color: Colors.white10, indent: 100, endIndent: 100, height: 15),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("میلادی: ${toKu(gregorianDate)}",
                style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13)),
            const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text("|", style: TextStyle(color: Color(0xFF22D3EE)))),
            Text("کوردی: ${toKu(kurdishDate)}",
                style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13)),
          ],
        ),
      ],
    );
  }

  Widget _buildNextBar() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 15),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(15),
        border:
            Border.all(color: const Color(0xFF22D3EE).withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(getNextPrayerRemaining(),
              style: const TextStyle(
                  color: Color(0xFF4ADE80),
                  fontSize: 22,
                  fontWeight: FontWeight.bold)),
          const SizedBox(width: 15),
          Text(toKu(getNextPrayerRemaining())),
          Text("ماوە بۆ بانگی ${getNextPrayerName()}",
              style: const TextStyle(color: Colors.white, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildPrayerCard(String name, String time, {bool isSun = false}) {
    bool isActive = activeAthan == name;
    List<Shadow>? embossedShadow = isActive
        ? null
        : const [
            Shadow(offset: Offset(1, 1), blurRadius: 2, color: Colors.black),
            Shadow(
                offset: Offset(-0.5, -0.5),
                blurRadius: 1,
                color: Colors.white10),
          ];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 7),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF080D1A) : const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(15),
        boxShadow: isActive
            ? null
            : const [
                BoxShadow(
                    color: Colors.black, offset: Offset(5, 5), blurRadius: 10),
                BoxShadow(
                    color: Color(0x0AFFFFFF),
                    offset: Offset(-2, -2),
                    blurRadius: 5),
              ],
        border: Border.all(
          color: isActive
              ? const Color(0xFF22D3EE).withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.03),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              isSun
                  ? AnimatedBuilder(
                      animation: _sunController,
                      builder: (context, child) => Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color: Colors.orange.withValues(
                                    alpha: _sunController.value * 0.8),
                                blurRadius: 20)
                          ],
                        ),
                        child: const Icon(Icons.wb_sunny,
                            color: Colors.orange, size: 28),
                      ),
                    )
                  : GestureDetector(
                      onTap: () =>
                          setState(() => activeAthan = isActive ? null : name),
                      child: Icon(isActive ? Icons.volume_up : Icons.volume_off,
                          color: isActive ? Colors.yellow : Colors.blueGrey,
                          size: 24),
                    ),
              const SizedBox(width: 15),
              Text(isSun ? name : "بانگی $name",
                  style: TextStyle(
                      color: isSun ? Colors.orange : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      shadows: embossedShadow)),
            ],
          ),
          Text(formatTo12Hr(time),
              style: TextStyle(
                  fontSize: 18,
                  color: isSun ? Colors.orange : Colors.white70,
                  shadows: embossedShadow,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildPremiumDrawer() {
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.7,
      child: Drawer(
        backgroundColor: const Color(0xFF020617),
        child: Container(
          decoration: const BoxDecoration(
              border: Border(
                  left: BorderSide(color: Color(0xFF22D3EE), width: 1.5))),
          child: Column(
            children: [
              DrawerHeader(
                child: Stack(children: [
                  const Center(
                      child: Column(children: [
                    Icon(Icons.mosque, size: 50, color: Color(0xFF10B981)),
                    SizedBox(height: 10),
                    Text("ڕێکخستنەکان",
                        style: TextStyle(
                            color: Color(0xFF22D3EE),
                            fontWeight: FontWeight.bold))
                  ])),
                  Align(
                      alignment: Alignment.topLeft,
                      child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          onPressed: () => Navigator.pop(context)))
                ]),
              ),
              Expanded(
                child: ListView(
                  children: [
                    _buildExpansionTile(
                      Icons.location_city,
                      "هەڵبژاردنی شار",
                      kurdistanCities
                          .map((c) => ListTile(
                                title: Text(c.name),
                                onTap: () {
                                  Navigator.pop(context);
                                  setState(() => currentCity = c.name);
                                  _recalculateForCity();
                                },
                              ))
                          .toList(),
                    ),
                    _buildExpansionTile(
                        Icons.record_voice_over, "دەنگی بانگبێژ", [
                      ListTile(
                          title: const Text("م. کمال رؤوف"),
                          trailing: const Icon(Icons.play_circle_fill,
                              color: Color(0xFF10B981)),
                          onTap: () {}),
                      const ListTile(title: Text("بانگبێژی مەککە")),
                    ]),
                    _buildExpansionTile(
                        Icons.palette,
                        "ڕووکارەکان",
                        List.generate(
                            10,
                            (i) => ListTile(
                                title: Text(
                                    "ڕووکاری ${toKu((i + 1).toString())}")))),
                    const ListTile(
                        leading:
                            Icon(Icons.play_circle_fill, color: Colors.red),
                        title: Text("ئێمە لە یوتیوب")),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpansionTile(
      IconData icon, String title, List<Widget> children) {
    return ExpansionTile(
      leading: Icon(icon, color: const Color(0xFF22D3EE), size: 22),
      title: Text(title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      iconColor: const Color(0xFF22D3EE),
      collapsedIconColor: Colors.white70,
      children: children,
    );
  }
}
