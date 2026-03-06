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
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../services/prayer_service.dart';
import '../widgets/prayer_widgets.dart';
import '../widgets/drawer_widget.dart';
import '../utils/constants.dart';
import '../main.dart';

// ==================== HOME SCREEN ====================

class PrayerHomePage extends StatefulWidget {
  const PrayerHomePage({super.key});

  @override
  State<PrayerHomePage> createState() => _PrayerHomePageState();
}

class _PrayerHomePageState extends State<PrayerHomePage>
    with TickerProviderStateMixin {

  // ── Services ────────────────────────────────────
  final TimeService _timeService = TimeService();
  final PrayerDataService _prayerDataService = PrayerDataService();

  // ✅ پلەیەری سەرەکی تەنها بۆ دەنگی بانگ — تاقیکردنەوە لە drawer دەکرێت
  final AudioPlayer _athanPlayer = AudioPlayer();

  late Future<PrayerTimes> _prayerTimesFuture;
  late AnimationController _sunController;

  // ── State ────────────────────────────────────────
  DateTime _now = DateTime.now();
  String currentCity = "پێنجوێن";
  Set<String> activeAthans = {};
  String selectedAthanFile = "kamal_rauf.mp3";
  String selectedThemeName = "شین";
  Color primaryColor = Colors.blue;

  List<String> todayTimes = List.filled(6, "--:--");

  Timer? _ticker;
  Timer? _updateCheckTimer;

  // ── Init ─────────────────────────────────────────
  @override
  void initState() {
    super.initState();

    _sunController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });

    _prayerTimesFuture = _prayerDataService.getPrayerTimes(currentCity, _now);

    _loadSavedSettings();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowPermissions();
    });

    Future.delayed(Duration.zero, _checkForUpdate);
    _updateCheckTimer =
        Timer.periodic(const Duration(hours: 24), (_) => _checkForUpdate());
  }

  // ── Dispose ──────────────────────────────────────
  @override
  void dispose() {
    _ticker?.cancel();
    _updateCheckTimer?.cancel();
    _sunController.dispose();
    _athanPlayer.dispose();
    super.dispose();
  }

  // ── بارکردنی ڕێکخستنەکان ─────────────────────────
  Future<void> _loadSavedSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    final savedPrayers = prefs.getStringList('activePrayers');

    setState(() {
      currentCity = prefs.getString('selectedCity') ?? 'پێنجوێن';
      selectedAthanFile = prefs.getString('selectedAthan') ?? 'kamal_rauf.mp3';
      selectedThemeName = prefs.getString('selectedTheme') ?? 'شین';
      primaryColor = appThemes[selectedThemeName] ?? Colors.blue;
      if (savedPrayers != null) {
        activeAthans = savedPrayers.toSet();
      }
    });

    if (savedPrayers != null) {
      for (final prayerName in savedPrayers) {
        await _reSchedulePrayer(prayerName);
      }
    }
  }

  // ── پاشەکەوتکردنی ڕێکخستنەکان ───────────────────
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedCity', currentCity);
    await prefs.setString('selectedAthan', selectedAthanFile);
    await prefs.setString('selectedTheme', selectedThemeName);
    await prefs.setStringList('activePrayers', activeAthans.toList());
  }

  // ── دووبارە خشتەکردنی بانگ ────────────────────────
  Future<void> _reSchedulePrayer(String prayerName) async {
    try {
      final times = await _prayerTimesFuture;
      final now = DateTime.now();

      final int index = prayerNames.indexOf(prayerName);
      if (index == -1 || index == 1) return; // خۆرهەڵاتن بەکار ناهێنرێت

      final allTimes = [
        times.fajr,
        times.sunrise,
        times.dhuhr,
        times.asr,
        times.maghrib,
        times.isha,
      ];

      DateTime prayerTime = allTimes[index];
      if (prayerTime.isBefore(now)) {
        prayerTime = prayerTime.add(const Duration(days: 1));
      }

      await _scheduleAthanNotification(prayerName.hashCode, prayerName, prayerTime);
    } catch (e) {
      debugPrint("Error rescheduling '$prayerName': $e");
    }
  }

  // ── مۆڵەتەکان ────────────────────────────────────
  Future<void> _checkAndShowPermissions() async {
    await Future.delayed(const Duration(seconds: 2));

    final bool isNotificationDenied = await Permission.notification.isDenied;
    final bool isAlarmDenied = await Permission.scheduleExactAlarm.isDenied;

    if (!isNotificationDenied && !isAlarmDenied) return;
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text(
            "ڕێپێدانی پێویست",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          content: const Text(
            "بۆ ئەوەی ئەپەکە بتوانێت لە کاتی بانگەکاندا ئاگادارت بکاتەوە و دەنگی بانگ لێ بدات، تکایە ڕێپێدانەکان چالاک بکە.",
            style: TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                try {
                  final androidPlugin = flutterLocalNotificationsPlugin
                      .resolvePlatformSpecificImplementation<
                          AndroidFlutterLocalNotificationsPlugin>();
                  await androidPlugin?.requestNotificationsPermission();
                } catch (e) {
                  debugPrint("Permission error: $e");
                }
                await [
                  Permission.notification,
                  Permission.scheduleExactAlarm,
                  Permission.ignoreBatteryOptimizations,
                ].request();
              },
              child: const Text(
                'باشە',
                style: TextStyle(
                  color: Colors.blueAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── پشکنینی ئەپدەیت ──────────────────────────────
  Future<void> _checkForUpdate() async {
    try {
      final response = await http.get(Uri.parse(
          'https://raw.githubusercontent.com/daryan-m/prayer_time/refs/heads/main/version.json'));

      if (!mounted || response.statusCode != 200) return;

      final data = json.decode(response.body);
      final String newVersion = data['version'];
      final String downloadUrl = data['url'];

      if (_isNewerVersion(currentAppVersion, newVersion)) {
        _showUpdateDialog(downloadUrl, newVersion);
      }
    } catch (e) {
      debugPrint("کێشە لە پشکنینی ئەپدەیت: $e");
    }
  }

  bool _isNewerVersion(String current, String newer) {
    final currentParts =
        current.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final newerParts =
        newer.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final maxLen =
        currentParts.length > newerParts.length
            ? currentParts.length
            : newerParts.length;

    for (int i = 0; i < maxLen; i++) {
      final c = i < currentParts.length ? currentParts[i] : 0;
      final n = i < newerParts.length ? newerParts[i] : 0;
      if (n > c) return true;
      if (n < c) return false;
    }
    return false;
  }

  // ── دیالۆگی ئەپدەیت ──────────────────────────────
  Future<void> _showUpdateDialog(String url, String version) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text(
          "وەشانێکی نوێ بەردەستە",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          "وەشانی $version ئێستا بەردەستە، ئایا دەتەوێت نوێی بکەیتەوە؟",
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text("بۆ کاتێکی تر", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
            onPressed: () {
              Navigator.pop(context);
              _startUpdate(url, version);
            },
            child: const Text("نوێکردنەوە"),
          ),
        ],
      ),
    );
  }

  void _startUpdate(String url, String version) async {
    await WakelockPlus.enable();
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text(
            "داگرتنی نوێکردنەوە",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          content: StreamBuilder<OtaEvent>(
            stream: OtaUpdate().execute(
              url,
              destinationFilename: 'update_v$version.apk',
              usePackageInstaller: true,
            ),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                WakelockPlus.disable();
                return _buildErrorUI("کێشەیەک لە پەیوەندی ڕوویدا");
              }

              if (snapshot.hasData) {
                final status = snapshot.data!.status;
                final value = snapshot.data!.value;

                switch (status) {
                  case OtaStatus.DOWNLOADING:
                    final double progress =
                        double.tryParse(value ?? "0") ?? 0;
                    return _buildDownloadUI(progress);

                  case OtaStatus.INSTALLING:
                    WakelockPlus.disable();
                    return _buildStatusUI(
                        Icons.settings, "ئێستا دەست دەکات بە ئینستاڵ...");

                  case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
                    WakelockPlus.disable();
                    return _buildErrorUI(
                        "تکایە مۆڵەتی ئینستاڵ بدە بە ئەپەکە لە ڕێکخستن");

                  case OtaStatus.DOWNLOAD_ERROR:
                  case OtaStatus.INTERNAL_ERROR:
                    WakelockPlus.disable();
                    return _buildErrorUI("هەڵە لە داگرتنی فایلەکە");

                  default:
                    return _buildStatusUI(
                        Icons.cloud_download, "ئامادەکاری دەکرێت...");
                }
              }

              return const SizedBox(
                height: 100,
                child: Center(
                    child: CircularProgressIndicator(color: Colors.blue)),
              );
            },
          ),
        ),
      ),
    );
  }

  // ── UI یارمەتیدەرەکانی ئەپدەیت ───────────────────
  Widget _buildDownloadUI(double progress) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LinearProgressIndicator(
          value: progress / 100,
          color: Colors.blue,
          backgroundColor: Colors.white24,
          minHeight: 8,
        ),
        const SizedBox(height: 15),
        Text(
          "${progress.toStringAsFixed(0)}%",
          style: const TextStyle(
              color: Colors.white, fontSize: 25, fontWeight: FontWeight.bold),
        ),
        const Text("تکایە چاوەڕوان بن...",
            style: TextStyle(color: Colors.white70, fontSize: 13)),
      ],
    );
  }

  Widget _buildStatusUI(IconData icon, String text) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.green, size: 50),
        const SizedBox(height: 10),
        Text(text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white)),
      ],
    );
  }

  Widget _buildErrorUI(String errorText) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error, color: Colors.red, size: 50),
        const SizedBox(height: 10),
        Text(errorText,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 15),
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("داخستن"),
        ),
      ],
    );
  }

  // ── خشتەکردنی نۆتیفیکەیشن ────────────────────────
  Future<void> _scheduleAthanNotification(
      int id, String prayerName, DateTime prayerTime) async {

    // ✅ چارەسەری کێشەی دەنگ: ناوی فایل بەدروستی هاوشێوە دەکرێت بە ناوی res/raw
    final String soundFileName = selectedAthanFile
        .replaceAll('.mp3', '')
        .replaceAll(' ', '_')
        .toLowerCase();

    const String channelId = 'athan_alerts_v2';

    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      // ✅ کەناڵەکە دووبارە دروست دەکرێت بە دەنگە نوێیەکە
      await androidPlugin.deleteNotificationChannel(channelId);
      await androidPlugin.createNotificationChannel(
        AndroidNotificationChannel(
          channelId,
          'بانگ',
          description: 'کەناڵی نۆتیفیکەیشنی بانگ',
          importance: Importance.max,
          sound: RawResourceAndroidNotificationSound(soundFileName),
          playSound: true,
          enableVibration: true,
        ),
      );
    }

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      channelId,
      'بانگ',
      channelDescription: 'کەناڵی نۆتیفیکەیشنی بانگ',
      importance: Importance.max,
      priority: Priority.high,
      sound: RawResourceAndroidNotificationSound(soundFileName),
      playSound: true,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
    );

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      'کاتی بانگی $prayerName',
      'ئێستا کاتی بانگی $prayerNameەیە',
      _nextInstanceOfTime(prayerTime),
      NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  // ── دووبارە خشتەکردنی هەموو بانگەکان ──────────────
  Future<void> _refreshAllAthanSchedules(PrayerTimes times) async {
    await flutterLocalNotificationsPlugin.cancelAll();

    final prayers = [
      {'id': 1, 'name': 'بەیانی', 'time': times.fajr},
      {'id': 2, 'name': 'نیوەڕۆ', 'time': times.dhuhr},
      {'id': 3, 'name': 'عەسر', 'time': times.asr},
      {'id': 4, 'name': 'ئێوارە', 'time': times.maghrib},
      {'id': 5, 'name': 'خەوتنان', 'time': times.isha},
    ];

    for (final prayer in prayers) {
      // تەنها بانگە چالاکەکان خشتە دەکرێن
      if (activeAthans.contains(prayer['name'])) {
        await _scheduleAthanNotification(
          prayer['id'] as int,
          prayer['name'] as String,
          prayer['time'] as DateTime,
        );
      }
    }
  }

  // ── کاتی داهاتووی بانگ ────────────────────────────
  tz.TZDateTime _nextInstanceOfTime(DateTime prayerTime) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      prayerTime.hour,
      prayerTime.minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  // ── ڕیفرێش ───────────────────────────────────────
  void _refreshData() {
    if (!mounted) return;
    setState(() {
      _prayerTimesFuture =
          _prayerDataService.getPrayerTimes(currentCity, _now);
    });
  }

  // ── بانگی داهاتوو: ماوە ───────────────────────────
  String _getNextRemaining(PrayerTimes times) {
    final now = DateTime.now();
    final prayerTimesList = [
      times.fajr,
      times.dhuhr,
      times.asr,
      times.maghrib,
      times.isha,
    ];

    DateTime? nextPrayerTime;
    for (final pt in prayerTimesList) {
      if (pt.isAfter(now)) {
        nextPrayerTime = pt;
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
    final String h = diff.inHours.toString().padLeft(2, '0');
    final String m = diff.inMinutes.remainder(60).toString().padLeft(2, '0');
    final String s = diff.inSeconds.remainder(60).toString().padLeft(2, '0');

    return _timeService.toKu("$h:$m:$s");
  }

  // ── بانگی داهاتوو: ناو ────────────────────────────
  String _getNextPrayerName(PrayerTimes times) {
    final now = DateTime.now();
    if (now.isBefore(times.fajr)) return "بەیانی";
    if (now.isBefore(times.dhuhr)) return "نیوەڕۆ";
    if (now.isBefore(times.asr)) return "عەسر";
    if (now.isBefore(times.maghrib)) return "ئێوارە";
    if (now.isBefore(times.isha)) return "خەوتنان";
    return "بەیانی";
  }

  // ── هاندلی تاپ لەسەر کارت ────────────────────────
  Future<void> _handlePrayerCardTap(String name, String time) async {
    if (name == "خۆرهەڵاتن") return;

    // ✅ گۆڕینی دۆخ
    setState(() {
      if (activeAthans.contains(name)) {
        activeAthans.remove(name);
      } else {
        activeAthans.add(name);
      }
    });

    await _saveSettings();

    final bool isNowActive = activeAthans.contains(name);

    // ── گۆڕینی کاتی 12h بۆ 24h ──
    String cleanTime = time.replaceAllMapped(RegExp(r'[٠-٩]'), (m) {
      const map = {
        '٠': '0', '١': '1', '٢': '2', '٣': '3', '٤': '4',
        '٥': '5', '٦': '6', '٧': '7', '٨': '8', '٩': '9',
      };
      return map[m.group(0)]!;
    }).replaceAllMapped(RegExp(r'[۰-۹]'), (m) {
      const map = {
        '۰': '0', '۱': '1', '۲': '2', '۳': '3', '۴': '4',
        '۵': '5', '۶': '6', '۷': '7', '۸': '8', '۹': '9',
      };
      return map[m.group(0)]!;
    }).trim();

    final regExp = RegExp(r'(\d+):(\d+)');
    final match = regExp.firstMatch(cleanTime);
    if (match == null) return;

    int hour = int.parse(match.group(1)!);
    final int minute = int.parse(match.group(2)!);

    if ((cleanTime.contains("د.ن") || cleanTime.toUpperCase().contains("PM")) &&
        hour < 12) {
      hour += 12;
    }
    if ((cleanTime.contains("پ.ن") || cleanTime.toUpperCase().contains("AM")) &&
        hour == 12) {
      hour = 0;
    }

    final now = DateTime.now();
    DateTime scheduledDate =
        DateTime(now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    if (!mounted) return;

    if (isNowActive) {
      // ✅ چالاک کردن
      await flutterLocalNotificationsPlugin.cancel(name.hashCode);
      await _scheduleAthanNotification(name.hashCode, name, scheduledDate);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          // ✅ چارەسەری کێشەی پەیام: پیشاندانی "ناچالاک کرا" کاتی چالاک بوون
          content: Text("بانگی $name چالاک کرا",
              textAlign: TextAlign.center),
          backgroundColor: const Color(0xFF10B981),
          duration: const Duration(seconds: 1),
        ),
      );
    } else {
      // ✅ ناچالاک کردن
      await _athanPlayer.stop();
      await flutterLocalNotificationsPlugin.cancel(name.hashCode);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("بانگی $name ناچالاک کرا",
              textAlign: TextAlign.center),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  // ── BUILD ─────────────────────────────────────────
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

          if (snapshot.hasError ||
              !snapshot.hasData ||
              snapshot.data == null) {
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
          final formatter = DateFormat('HH:mm');

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
            appBar: _buildAppBar(),
            drawerEnableOpenDragGesture: true,
            drawerEdgeDragWidth: 50,
            drawer: PrayerDrawer(
              currentCity: currentCity,
              onCityChanged: (city) {
                setState(() => currentCity = city);
                _refreshData();
                _saveSettings();
              },
              selectedThemeName: selectedThemeName,
              primaryColor: primaryColor,
              onThemeChanged: (name, color) {
                setState(() {
                  selectedThemeName = name;
                  primaryColor = color;
                });
                _saveSettings();
              },
              selectedAthanFile: selectedAthanFile,
              onAthanChanged: (file) async {
                setState(() => selectedAthanFile = file);
                await _saveSettings();
                // ✅ دووبارە خشتەکردن بە دەنگە نوێیەکە
                await _refreshAllAthanSchedules(prayerTimes);
              },
              prayerTimes: prayerTimes,
            ),
            body: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 600) {
                  return _buildTabletLayout(prayerTimes);
                }
                return _buildPhoneLayout(prayerTimes);
              },
            ),
          );
        },
      ),
    );
  }

  // ── AppBar ────────────────────────────────────────
  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.background,
      elevation: 0,
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          const Icon(Icons.mosque, color: AppColors.secondary, size: 30),
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
            style: const TextStyle(fontSize: 15, color: AppColors.secondary),
          ),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(2),
        child: Container(height: 2.0, color: Colors.amber),
      ),
      actions: [
        Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu_open,
                color: AppColors.primary, size: 40),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ],
    );
  }

  // ── لەیاوتی تەبلێت ───────────────────────────────
  Widget _buildTabletLayout(PrayerTimes prayerTimes) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: ListView.builder(
              itemCount: prayerNames.length,
              itemBuilder: (context, i) => _buildPrayerCard(i),
            ),
          ),
        ),
        const VerticalDivider(color: Colors.amber, width: 1, thickness: 1),
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
  }

  // ── لەیاوتی مۆبایل ───────────────────────────────
  Widget _buildPhoneLayout(PrayerTimes prayerTimes) {
    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.height,
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Column(
                  children: List.generate(
                    6,
                    (i) => _buildPrayerCard(i),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── یارمەتیدەری دروستکردنی کارت ──────────────────
  Widget _buildPrayerCard(int i) {
    return PrayerCard(
      name: prayerNames[i],
      time: todayTimes[i],
      isSun: i == 1,
      isActive: activeAthans.contains(prayerNames[i]),
      sunAnimation: i == 1 ? _sunController : null,
      onTap: () async =>
          await _handlePrayerCardTap(prayerNames[i], todayTimes[i]),
      timeService: _timeService,
    );
  }
}
