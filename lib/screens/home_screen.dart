import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:intl/intl.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:ota_update/ota_update.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/prayer_service.dart';
import '../widgets/prayer_widgets.dart';
import '../widgets/drawer_widget.dart';
import '../utils/constants.dart';
import '../main.dart';
import 'package:permission_handler/permission_handler.dart';

class PrayerHomePage extends StatefulWidget {
  const PrayerHomePage({super.key});

  @override
  State<PrayerHomePage> createState() => _PrayerHomePageState();
}

class _PrayerHomePageState extends State<PrayerHomePage>
    with TickerProviderStateMixin {
  // --- SERVICES ---
  final TimeService _timeService = TimeService();
  final PrayerDataService _prayerDataService = PrayerDataService();
  final AudioPlayer _audioPlayer = AudioPlayer();

  late Future<PrayerTimes> _prayerTimesFuture;
  late AnimationController _sunController;

  // --- STATE ---
  DateTime _now = DateTime.now();
  String currentCity = "پێنجوێن";
  Set<String> activeAthans = {}; // گۆڕدرا بۆ Set بۆ چەندین بانگ
  String selectedAthanFile = "kamal_rauf.mp3";
  String? _previewingSound;
  String selectedThemeName = "شین";
  Color primaryColor = Colors.blue;
  List<String> todayTimes = [
    "--:--",
    "--:--",
    "--:--",
    "--:--",
    "--:--",
    "--:--"
  ];
  Timer? _ticker;
  Timer? _updateCheckTimer;

  @override
  void initState() {
    super.initState();

    _sunController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // Timer بۆ کاتژمێر
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _now = DateTime.now();
        });
      }
    });

    // بارکردنی زانیارییە پاشەکەوتکراوەکان
    _loadSavedSettings();

    _prayerTimesFuture = _prayerDataService.getPrayerTimes(currentCity, _now);

    // پشکنینی ئەپدەیت لە دەستپێک
    Future.delayed(Duration.zero, () => _checkForUpdate());

    // پشکنینی ئەپدەیت هەر ٢٤ کاتژمێر
    _updateCheckTimer = Timer.periodic(const Duration(hours: 24), (timer) {
      _checkForUpdate();
    });
  }

  // بارکردنی زانیارییە پاشەکەوتکراوەکان
  Future<void> _loadSavedSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    // بارکردنی زانیارییە پاشەکەوتکراوەکان
    final savedPrayers = prefs.getStringList('activePrayers');

    setState(() {
      // بارکردنی شار
      currentCity = prefs.getString('selectedCity') ?? 'پێنجوێن';

      // بارکردنی دەنگ
      selectedAthanFile = prefs.getString('selectedAthan') ?? 'kamal_rauf.mp3';

      // بارکردنی ڕووکار
      selectedThemeName = prefs.getString('selectedTheme') ?? 'شین';
      primaryColor = appThemes[selectedThemeName] ?? Colors.blue;

      // بارکردنی کارتە ئەکتیڤەکان
      if (savedPrayers != null) {
        activeAthans = savedPrayers.toSet();
      }
    });

    // دووبارە ڕێکخستنی نوتیفیکەیشن لە دەرەوەی setState
    if (savedPrayers != null) {
      for (String prayerName in savedPrayers) {
        await _reSchedulePrayer(prayerName);
      }
    }
  }

  // پاشەکەوتکردنی ڕێکخستنەکان
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('selectedCity', currentCity);
    await prefs.setString('selectedAthan', selectedAthanFile);
    await prefs.setString('selectedTheme', selectedThemeName);

    // پاشەکەوتکردنی هەموو کارتە ئەکتیڤەکان
    await prefs.setStringList('activePrayers', activeAthans.toList());
  }

  // دووبارە ڕێکخستنی notification بۆ کارتێکی تایبەت
  // دووبارە ڕێکخستنی notification بۆ کارتێکی تایبەت
  Future<void> _reSchedulePrayer(String prayerName) async {
    try {
      // چاوەڕێ دەکەین کاتەکان بە تەواوی باربن
      final times = await _prayerTimesFuture;
      final now = DateTime.now();

      // ناوی بانگەکە دەگۆڕین بۆ ژمارە (index)
      int index = prayerNames.indexOf(prayerName);
      if (index == -1) return; // ئەگەر نەدۆزرایەوە, هیچ مەکە
      if (index == 1) return;
      // کاتەکان دەهێنین
      final allTimes = [
        times.fajr,
        times.sunrise, // ئەمە گرنگ نییە بەڵام با بمێنێت بۆ ڕیزبەندی
        times.dhuhr,
        times.asr,
        times.maghrib,
        times.isha
      ];
      DateTime prayerTime = allTimes[index];

      // دڵنیادەبینەوە کاتەکە بۆ داهاتووە
      if (prayerTime.isBefore(now)) {
        prayerTime = prayerTime.add(const Duration(days: 1));
      }

      // تەنها ئاگادارکردنەوەکە دادەنێینەوە، دەستکاری هیچی تر ناکەین
      await _scheduleAthanBackground(
        prayerName.hashCode,
        prayerName,
        prayerTime,
      );
    } catch (e) {
      debugPrint("Error rescheduling prayer '$prayerName': $e");
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _updateCheckTimer?.cancel();
    _sunController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  // --- UPDATE CHECK ---
  Future<void> _checkForUpdate() async {
    try {
      final response = await http.get(Uri.parse(
          'https://raw.githubusercontent.com/daryan-m/prayer_time/refs/heads/main/version.json'));

      if (!mounted) return;
      if (!context.mounted) return;
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        String newVersion = data['version'];
        String downloadUrl = data['url'];

        if (!mounted) return;

        // بەکارهێنانی فەنکشنی بەراوردکردن
        if (isNewerVersion(currentAppVersion, newVersion)) {
          _showUpdateDialog(downloadUrl, newVersion);
        }
      }
    } catch (e) {
      debugPrint("کێشە لە پشکنینی ئەپدەیت: $e");
    }
  }

  bool isNewerVersion(String currentVersion, String newVersion) {
    final currentParts = currentVersion
        .split('.')
        .map((part) => int.tryParse(part) ?? 0)
        .toList();
    final newParts =
        newVersion.split('.').map((part) => int.tryParse(part) ?? 0).toList();

    final maxLength = currentParts.length > newParts.length
        ? currentParts.length
        : newParts.length;

    for (int i = 0; i < maxLength; i++) {
      final current = i < currentParts.length ? currentParts[i] : 0;
      final newV = i < newParts.length ? newParts[i] : 0;

      if (newV > current) {
        return true;
      }
      if (newV < current) {
        return false;
      }
    }
    return false;
  }

  void _showUpdateDialog(String url, String version) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("وەشانێکی نوێ بەردەستە",
            textAlign: TextAlign.center, style: TextStyle(color: Colors.white)),
        content: Text(
            "وەشانی $version ئێستا بەردەستە، ئایا دەتەوێت نوێی بکەیتەوە؟",
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("بۆ کاتێکی تر",
                style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
            onPressed: () {
              Navigator.pop(context);
              _startUpdate(url);
            },
            child: const Text("نوێکردنەوە"),
          ),
        ],
      ),
    );
  }

  void _startUpdate(String url) async {
    if (await Permission.requestInstallPackages.isDenied) {
      await Permission.requestInstallPackages.request();
    }

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text(
          "داگرتنی نوێکردنەوە",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white),
        ),
        content: StreamBuilder<OtaEvent>(
          stream:
              OtaUpdate().execute(url, destinationFilename: 'athan_app.apk'),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 50),
                  const SizedBox(height: 10),
                  Text(
                    "کێشەیەک هەیە:\n${snapshot.error}",
                    style: const TextStyle(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("داخستن"),
                  ),
                ],
              );
            }

            if (snapshot.data?.status == OtaStatus.INSTALLATION_DONE) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!context.mounted) return;
                Navigator.pop(context);
                if (!context.mounted) return;
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: const Color(0xFF1E293B),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15)),
                    title: const Text("تەواو بوو!",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white)),
                    content: const Text("تکایە ئەپەکە دامەزرێنە",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70)),
                    actions: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary),
                        onPressed: () => Navigator.pop(context),
                        child: const Text("باشە"),
                      ),
                    ],
                  ),
                );
              });
              return const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 50),
                  SizedBox(height: 10),
                  Text("تەواو بوو! تکایە دامەزرێنە",
                      style: TextStyle(color: Colors.white, fontSize: 16)),
                ],
              );
            }

            if (snapshot.data?.status == OtaStatus.INSTALLATION_DONE) {
              return const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 50),
                  SizedBox(height: 10),
                  Text("تەواو بوو!",
                      style: TextStyle(color: Colors.white, fontSize: 16)),
                ],
              );
            }

            double progress = double.tryParse(snapshot.data?.value ?? '0') ?? 0;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 5),
                LinearProgressIndicator(
                  value: progress / 100,
                  color: AppColors.primary,
                  backgroundColor: Colors.white24,
                  minHeight: 8,
                ),
                const SizedBox(height: 15),
                Text(
                  "${progress.toStringAsFixed(0)}%",
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 5),
                const Text("داگرتنی نوێکردنەوە...",
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            );
          },
        ),
      ),
    );
  }

  // --- NOTIFICATION ---
  Future<void> _scheduleAthanBackground(
      int id, String prayerName, DateTime prayerTime) async {
    String soundFileName = selectedAthanFile.replaceAll('.mp3', '');

    AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'athan_channel_id',
      'Notifications',
      importance: Importance.max,
      priority: Priority.high,
      sound: RawResourceAndroidNotificationSound(soundFileName),
      playSound: true,
    );

    // ✅ هەمیشەیی - هەر ڕۆژ هەمان کات بانگ دەدات
    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      'کاتی بانگی $prayerName',
      'ئێستا کاتی بانگی $prayerNameەیە',
      _nextInstanceOfTime(prayerTime),
      NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // ✅ هەر ڕۆژ
    );
  }

// ✅ فەنکشنی نوێ - کاتی داهاتووی بانگ دیاری دەکات
  tz.TZDateTime _nextInstanceOfTime(DateTime prayerTime) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      prayerTime.hour,
      prayerTime.minute,
    );
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  // --- HELPER METHODS ---
  void _refreshData() {
    if (!mounted) return;
    setState(() {
      _prayerTimesFuture = _prayerDataService.getPrayerTimes(currentCity, _now);
    });
  }

  String _getNextRemaining(PrayerTimes times) {
    final now = DateTime.now();

    // ڕیزبەندی بانگەکان (بەبێ خۆرهەڵاتن)
    final prayerTimesList = [
      times.fajr,
      times.dhuhr,
      times.asr,
      times.maghrib,
      times.isha,
    ];

    DateTime? nextPrayerTime;

    // دۆزینەوەی یەکەم بانگ لە ڕیزبەندییەکەدا کە دوای کاتی ئێستایە
    for (final prayerTime in prayerTimesList) {
      if (prayerTime.isAfter(now)) {
        nextPrayerTime = prayerTime;
        break;
      }
    }

    nextPrayerTime ??= DateTime(
      now.year,
      now.month,
      now.day,
      times.fajr.hour,
      times.fajr.minute,
    ).add(const Duration(days: 1));

    final Duration diff = nextPrayerTime.difference(now);
    final int hours = diff.inHours;
    final int minutes = diff.inMinutes.remainder(60);
    final int seconds = diff.inSeconds.remainder(60);

    final String h = hours.toString().padLeft(2, '0');
    final String m = minutes.toString().padLeft(2, '0');
    final String s = seconds.toString().padLeft(2, '0');

    return _timeService.toKu("$h:$m:$s");
  }

  String _getNextPrayerName(PrayerTimes times) {
    final now = DateTime.now();

    // بەپێی کاتی ئێستا، ناوی بانگی داهاتوو دیاری دەکات
    if (now.isBefore(times.fajr)) return "بەیانی";
    if (now.isBefore(times.dhuhr)) return "نیوەڕۆ";
    if (now.isBefore(times.asr)) return "عەسر";
    if (now.isBefore(times.maghrib)) return "ئێوارە";
    if (now.isBefore(times.isha)) return "خەوتنان";

    // ئەگەر هەمووی تەواو بوو، چاوەڕێی بەیانی ڕۆژی دواتر بە
    return "بەیانی";
  }

  Future<void> _handlePrayerCardTap(String name, String time) async {
    if (name == "خۆرهەڵاتن") return;
    if (activeAthans.contains(name)) {
      // ناچالاککردن
      await _audioPlayer.stop();
      await flutterLocalNotificationsPlugin.cancel(name.hashCode);
      setState(() => activeAthans.remove(name));
      await _saveSettings();
    } else {
      // چالاککردن - سەرەتا schedule، دواتر state
      try {
        final now = DateTime.now();
        final cleanTime = time
            .replaceAll('٠', '0')
            .replaceAll('١', '1')
            .replaceAll('٢', '2')
            .replaceAll('٣', '3')
            .replaceAll('٤', '4')
            .replaceAll('٥', '5')
            .replaceAll('٦', '6')
            .replaceAll('٧', '7')
            .replaceAll('٨', '8')
            .replaceAll('٩', '9')
            .replaceAll('۰', '0')
            .replaceAll('۱', '1')
            .replaceAll('۲', '2')
            .replaceAll('۳', '3')
            .replaceAll('۴', '4')
            .replaceAll('۵', '5')
            .replaceAll('۶', '6')
            .replaceAll('۷', '7')
            .replaceAll('۸', '8')
            .replaceAll('۹', '9');

        final timeParts = cleanTime.split(':');
        if (timeParts.length < 2) return;

        DateTime scheduledDate = DateTime(
          now.year,
          now.month,
          now.day,
          int.parse(timeParts[0]),
          int.parse(timeParts[1]),
        );
        if (scheduledDate.isBefore(now)) {
          scheduledDate = scheduledDate.add(const Duration(days: 1));
        }
        await flutterLocalNotificationsPlugin.cancel(name.hashCode);
        await _scheduleAthanBackground(name.hashCode, name, scheduledDate);
        // تەنها دوای سەرکەوتن state دەستکاری دەکەین
        setState(() => activeAthans.add(name));
        await _saveSettings();
      } catch (e) {
        debugPrint("❌ کێشە لە schedule: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: FutureBuilder<PrayerTimes>(
        future: _prayerTimesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: AppColors.background,
              body: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            );
          }

          if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
            return Scaffold(
              backgroundColor: AppColors.background,
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "کێشەیەک لە بارکردنی کاتەکاندا هەیە\nتکایە دووبارە هەوڵ بدەرەوە",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _refreshData,
                      child: const Text("دووبارە هەوڵ بدەرەوە"),
                    ),
                  ],
                ),
              ),
            );
          }

          final prayerTimes = snapshot.data!;
          final DateFormat formatter = DateFormat('HH:mm');
          todayTimes = [
            formatter.format(prayerTimes.fajr),
            formatter.format(prayerTimes.sunrise),
            formatter.format(prayerTimes.dhuhr),
            formatter.format(prayerTimes.asr),
            formatter.format(prayerTimes.maghrib),
            formatter.format(prayerTimes.isha),
          ];

          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              backgroundColor: AppColors.nily,
              elevation: 0,
              automaticallyImplyLeading: false,
              title: Row(
                children: [
                  const Icon(Icons.mosque,
                      color: AppColors.secondary, size: 30),
                  const SizedBox(width: 10),
                  const Text(
                    "کاتەکانى بانگ",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    "($currentCity)",
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.secondary,
                    ),
                  ),
                ],
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(4),
                child: Container(
                  height: 2.0,
                  color: Colors.amber,
                ),
              ),
              actions: [
                Builder(
                  builder: (context) => IconButton(
                    icon: const Icon(
                      Icons.menu_open,
                      color: AppColors.primary,
                      size: 40,
                    ),
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  ),
                ),
              ],
            ),
            drawerEnableOpenDragGesture: true,
            drawerEdgeDragWidth: 50,
            drawer: PrayerDrawer(
              currentCity: currentCity,
              onCityChanged: (city) {
                setState(() {
                  currentCity = city;
                  _refreshData();
                });
                _saveSettings(); // پاشەکەوتکردن
              },
              selectedThemeName: selectedThemeName,
              primaryColor: primaryColor,
              onThemeChanged: (name, color) {
                setState(() {
                  selectedThemeName = name;
                  primaryColor = color;
                });
                _saveSettings(); // پاشەکەوتکردن
              },
              selectedAthanFile: selectedAthanFile,
              onAthanChanged: (file) {
                setState(() => selectedAthanFile = file);
                _saveSettings(); // پاشەکەوتکردن
              },
              previewingSound: _previewingSound,
              onPreviewChanged: (sound) {
                setState(() => _previewingSound = sound);
              },
              audioPlayer: _audioPlayer,
            ),
            body: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 600) {
                  // WIDE LAYOUT (TABLET)
                  return Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                          child: ListView.builder(
                            itemCount: prayerNames.length,
                            itemBuilder: (context, i) {
                              return PrayerCard(
                                name: prayerNames[i],
                                time: todayTimes[i],
                                isSun: i == 1,
                                isActive: activeAthans.contains(prayerNames[i]),
                                sunAnimation: i == 1 ? _sunController : null,
                                onTap: () async => await _handlePrayerCardTap(
                                    prayerNames[i], todayTimes[i]),
                                timeService: _timeService,
                              );
                            },
                          ),
                        ),
                      ),
                      const VerticalDivider(
                          color: Colors.amber, width: 1, thickness: 1),
                      Expanded(
                        flex: 3,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ClockWidget(now: _now, timeService: _timeService),
                            const SizedBox(height: 30),
                            DatesWidget(
                              timeService: _timeService,
                              now: _now,
                              gregorianDate: prayerTimes.gregorianDate,
                            ),
                            const SizedBox(height: 30),
                            NextPrayerBar(
                              remainingTime: _getNextRemaining(prayerTimes),
                              nextPrayerName: _getNextPrayerName(prayerTimes),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                } else {
                  // NARROW LAYOUT (PHONE)
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: IntrinsicHeight(
                        child: Column(
                          children: [
                            const SizedBox(height: 3),
                            ClockWidget(now: _now, timeService: _timeService),
                            DatesWidget(
                              timeService: _timeService,
                              now: _now,
                              gregorianDate: prayerTimes.gregorianDate,
                            ),
                            NextPrayerBar(
                              remainingTime: _getNextRemaining(prayerTimes),
                              nextPrayerName: _getNextPrayerName(prayerTimes),
                            ),
                            const Divider(color: Colors.amber, height: 10),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 10),
                              child: Column(
                                children: List.generate(6, (i) {
                                  return PrayerCard(
                                    name: prayerNames[i],
                                    time: todayTimes[i],
                                    isSun: i == 1,
                                    isActive:
                                        activeAthans.contains(prayerNames[i]),
                                    sunAnimation:
                                        i == 1 ? _sunController : null,
                                    onTap: () async =>
                                        await _handlePrayerCardTap(
                                            prayerNames[i], todayTimes[i]),
                                    timeService: _timeService,
                                  );
                                }),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }
              },
            ),
          );
        },
      ),
    );
  }
}
