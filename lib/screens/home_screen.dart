import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:intl/intl.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:ota_update/ota_update.dart';
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
  Color primaryColor = const Color(0xFF22D3EE);
  ThemePalette _palette = getThemePalette("شین");

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
      primaryColor = appThemes[selectedThemeName] ?? const Color(0xFF22D3EE);
      _palette = getThemePalette(selectedThemeName);
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

    // ── پشکنینی مۆڵەتی ئینستاڵ ──
    final bool canInstall = await Permission.requestInstallPackages.isGranted;
    if (!canInstall) {
      await WakelockPlus.disable();
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => Directionality(
          textDirection: ui.TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            title: const Text("مۆڵەتی ئینستاڵ پێویستە",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            content: const Text(
              "بۆ ئەوەی بتوانیت نوێکردنەوە ئینستاڵ بکەیت، تکایە مۆڵەتی \"ئینستاڵکردنی ئەپی نەناسراو\" بدە بە ئەپەکە لە ڕێکخستن.",
              style: TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("دواتر", style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
                onPressed: () async { Navigator.pop(ctx); await openAppSettings(); },
                child: const Text("کردنەوەی ڕێکخستن"),
              ),
            ],
          ),
        ),
      );
      return;
    }
    if (!mounted) return;

    // ── دیالۆگی پرۆگرێس ──
    double dlProgress = 0;
    String statusText  = "ئامادەکاری دەکرێت...";
    bool   hasError    = false;
    String errorText   = "";
    StateSetter? setDlState;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: StatefulBuilder(
          builder: (ctx, setSt) {
            setDlState = setSt;
            return AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              title: const Text("داگرتنی نوێکردنەوە",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 18)),
              content: hasError
                  ? Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.error, color: Colors.red, size: 50),
                      const SizedBox(height: 10),
                      Text(errorText,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70)),
                      const SizedBox(height: 15),
                      ElevatedButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text("داخستن")),
                    ])
                  : Column(mainAxisSize: MainAxisSize.min, children: [
                      LinearProgressIndicator(
                        value: dlProgress / 100,
                        color: Colors.blue,
                        backgroundColor: Colors.white24,
                        minHeight: 8,
                      ),
                      const SizedBox(height: 15),
                      Text(
                        dlProgress > 0 ? "${dlProgress.toStringAsFixed(0)}%" : "",
                        style: const TextStyle(
                            color: Colors.white, fontSize: 25, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(statusText,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    ]),
            );
          },
        ),
      ),
    );

    try {
      // ✅ ota_update: داگرتن + ئینستاڵ بە PackageInstaller
      // پرۆگرێس ئۆتۆماتیکی لە stream دێتەوە
      OtaUpdate()
          .execute(url, destinationFilename: 'update_v$version.apk')
          .listen(
        (OtaEvent event) {
          switch (event.status) {
            case OtaStatus.DOWNLOADING:
              setDlState?.call(() {
                dlProgress = double.tryParse(event.value ?? '0') ?? 0;
                statusText  = "تکایە چاوەڕوان بن...";
              });
              break;
            case OtaStatus.INSTALLING:
              setDlState?.call(() {
                dlProgress = 100;
                statusText  = "ئێستا دەست دەکات بە ئینستاڵ...";
              });
              WakelockPlus.disable();
              if (mounted) Navigator.of(context, rootNavigator: true).pop();
              break;
            case OtaStatus.ALREADY_RUNNING_ERROR:
            case OtaStatus.INTERNAL_ERROR:
            case OtaStatus.DOWNLOAD_ERROR:
            case OtaStatus.CHECKSUM_ERROR:
              setDlState?.call(() {
                hasError  = true;
                errorText = "هەڵە لە داگرتن: ${event.value}";
              });
              WakelockPlus.disable();
              break;
            default:
              break;
          }
        },
        onError: (e) {
          setDlState?.call(() {
            hasError  = true;
            errorText = "هەڵە: $e";
          });
          WakelockPlus.disable();
        },
      );
    } catch (e) {
      debugPrint("Update error: $e");
      setDlState?.call(() {
        hasError  = true;
        errorText = "هەڵە لە داگرتنی فایلەکە:\n$e";
      });
      WakelockPlus.disable();
    }
  }

  // ── خشتەکردنی بانگ بە AlarmManager + Foreground Service ────
  // AlarmManager exact alarm دادەنرێت، لە کاتی بانگ BroadcastReceiver
  // AthanService دەستپێ دەکات کە MediaPlayer بە تەواوی لێ دەدات
  Future<void> _scheduleAthanNotification(
      int id, String prayerName, DateTime prayerTime) async {

    // ── نۆتیفیکەیشنی یادکردنەوە (١ دەقە پێش) — لە flutter_local_notifications ──
    final String soundFileName = selectedAthanFile
        .replaceAll('.mp3', '')
        .replaceAll(' ', '_')
        .toLowerCase();

    final String channelId   = 'athan_$soundFileName';
    final String channelName = 'بانگ ($soundFileName)';

    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        AndroidNotificationChannel(
          channelId, channelName,
          description: 'کەناڵی نۆتیفیکەیشنی بانگ',
          importance: Importance.max,
          sound: RawResourceAndroidNotificationSound(soundFileName),
          playSound: true,
          enableVibration: true,
        ),
      );
    }

    // ── خشتەکردنی AthanService لە کاتی بانگ ──
    // AthanService.kt بە MediaPlayer + WakeLock + AudioFocus دەنگ لێ دەدات
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelId, channelName,
      channelDescription: 'کەناڵی نۆتیفیکەیشنی بانگ',
      importance: Importance.max,
      priority: Priority.high,
      sound: RawResourceAndroidNotificationSound(soundFileName),
      playSound: true,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      audioAttributesUsage: AudioAttributesUsage.alarm,
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

    // دیاریکردنی دۆخی نوێ پێش هەموو شتێک
    final bool willBeActive = !activeAthans.contains(name);

    // ١. UI دەستپێکەوە نوێ دەکرێت
    setState(() {
      if (willBeActive) {
        activeAthans.add(name);
      } else {
        activeAthans.remove(name);
      }
    });

    // ٢. Snackbar دەستپێکەوە نیشان دەدرێت — پێش هەر async کار
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          willBeActive ? "بانگی $name چالاک کرا" : "بانگی $name ناچالاک کرا",
          textAlign: TextAlign.center,
        ),
        backgroundColor:
            willBeActive ? const Color(0xFF10B981) : Colors.redAccent,
        duration: const Duration(seconds: 2),
      ),
    );

    // ٣. پاشەکەوتکردن
    await _saveSettings();

    if (willBeActive) {
      // ── چالاک: کاتی 12h بگۆڕە بۆ 24h ──
      final String cleanTime = time.replaceAllMapped(
        RegExp(r'[٠-٩]'),
        (m) => {'٠':'0','١':'1','٢':'2','٣':'3','٤':'4','٥':'5','٦':'6','٧':'7','٨':'8','٩':'9'}[m.group(0)]!,
      ).replaceAllMapped(
        RegExp(r'[۰-۹]'),
        (m) => {'۰':'0','۱':'1','۲':'2','۳':'3','۴':'4','۵':'5','۶':'6','۷':'7','۸':'8','۹':'9'}[m.group(0)]!,
      ).trim();

      final regMatch = RegExp(r'(\d+):(\d+)').firstMatch(cleanTime);
      if (regMatch == null) return;

      int hour = int.parse(regMatch.group(1)!);
      final int minute = int.parse(regMatch.group(2)!);

      if ((cleanTime.contains("د.ن") || cleanTime.toUpperCase().contains("PM")) && hour < 12) hour += 12;
      if ((cleanTime.contains("پ.ن") || cleanTime.toUpperCase().contains("AM")) && hour == 12) hour = 0;

      final now = DateTime.now();
      DateTime scheduledDate = DateTime(now.year, now.month, now.day, hour, minute);
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      await flutterLocalNotificationsPlugin.cancel(name.hashCode);
      await _scheduleAthanNotification(name.hashCode, name, scheduledDate);
    } else {
      // ── ناچالاک: دەنگ و نۆتیفیکەیشن بسڕەوە ──
      await _athanPlayer.stop();
      await flutterLocalNotificationsPlugin.cancel(name.hashCode);
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
                  _palette = getThemePalette(selectedThemeName);
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
              ClockWidget(now: _now, timeService: _timeService, palette: _palette),
              const SizedBox(height: 30),
              DatesWidget(
                timeService: _timeService,
                now: _now,
                gregorianDate: prayerTimes.gregorianDate,
                palette: _palette,
              ),
              const SizedBox(height: 30),
              NextPrayerBar(
                remainingTime: _getNextRemaining(prayerTimes),
                nextPrayerName: _getNextPrayerName(prayerTimes),
                palette: _palette,
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
              ClockWidget(now: _now, timeService: _timeService, palette: _palette),
              DatesWidget(
                timeService: _timeService,
                now: _now,
                gregorianDate: prayerTimes.gregorianDate,
                palette: _palette,
              ),
              NextPrayerBar(
                remainingTime: _getNextRemaining(prayerTimes),
                nextPrayerName: _getNextPrayerName(prayerTimes),
                palette: _palette,
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
      palette: _palette,
    );
  }
}
