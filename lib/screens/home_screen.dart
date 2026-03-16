import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http_parser/src/scan.dart';
import 'dart:async';
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
  final TimeService _timeService = TimeService();
  final PrayerDataService _prayerDataService = PrayerDataService();
  final AudioPlayer _athanPlayer = AudioPlayer();

  static const _athanChannel = MethodChannel('com.daryan.prayer/athan');

  late Future<PrayerTimes> _prayerTimesFuture;
  late AnimationController _sunController;

  DateTime _now = DateTime.now();
  String currentCity = "سلێمانی";
  Set<String> activeAthans = {};
  String selectedAthanFile = "kamal_rauf.mp3";
  String selectedThemeName = "شین";
  Color primaryColor = const Color(0xFF22D3EE);
  ThemePalette _palette = getThemePalette("شین");

  List<String> todayTimes = List.filled(6, "--:--");

  Timer? _ticker;
  Timer? _updateCheckTimer;

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

    // ١. لێرەدا سەرەتا بانگی ناکەین بە سلێمانی
    // ٢. یەکەمجار ڕێکخستنەکان بار دەکەین
    _loadSavedSettings().then((_) {
      // ٣. دوای ئەوەی دڵنیا بووینەوە کە شارەکە لە میمۆری هاتەوە، کاتەکان نوێ دەکەینەوە
      setState(() {
        _prayerTimesFuture =
            _prayerDataService.getPrayerTimes(currentCity, _now);
      });
    });

    Future.delayed(Duration.zero, _checkForUpdate);
    _updateCheckTimer =
        Timer.periodic(const Duration(hours: 24), (_) => _checkForUpdate());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _updateCheckTimer?.cancel();
    _sunController.dispose();
    _athanPlayer.dispose();
    super.dispose();
  }

  // ── ڕێکخستنەکان بارکردن ──────────────────────────
  Future<void> _loadSavedSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    final savedPrayers = prefs.getStringList('activePrayers');
    final bool isFirstRun = prefs.getBool('hasLaunched') != true;

    setState(() {
      currentCity = prefs.getString('selectedCity') ?? 'سلێمانی';
      selectedAthanFile = prefs.getString('selected_sound') ?? 'kamal_rauf.mp3';
      selectedThemeName = prefs.getString('selectedTheme') ?? 'شین';
      primaryColor = appThemes[selectedThemeName] ?? const Color(0xFF22D3EE);
      _palette = getThemePalette(selectedThemeName);
      if (savedPrayers != null) activeAthans = savedPrayers.toSet();
      _prayerTimesFuture = _prayerDataService.getPrayerTimes(currentCity, _now);
    });

    if (savedPrayers != null) {
      for (final prayerName in savedPrayers) {
        await _reSchedulePrayer(prayerName);
      }
    }

    if (isFirstRun) {
      await prefs.setBool('hasLaunched', true);
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      await _requestPermissions();
    }
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedCity', currentCity);
    await prefs.setString('selected_sound', selectedAthanFile);
    await prefs.setString('selectedTheme', selectedThemeName);
    await prefs.setStringList('activePrayers', activeAthans.toList());
  }

  // ── دووبارە خشتەکردنی بانگ ───────────────────────
  Future<void> _reSchedulePrayer(String prayerName) async {
    try {
      final times = await _prayerTimesFuture;
      final now = DateTime.now();
      final int index = prayerNames.indexOf(prayerName);
      if (index == -1 || index == 1) return;

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
      await _scheduleAthan(prayerName.hashCode, prayerName, prayerTime);
    } catch (e) {
      debugPrint("Error rescheduling '$prayerName': $e");
    }
  }

  // ── خشتەکردنی بانگ ───────────────────────────────
  Future<void> _scheduleAthan(
      int id, String prayerName, DateTime prayerTime) async {
    final String soundFileName = selectedAthanFile
        .replaceAll('.mp3', '')
        .replaceAll(' ', '_')
        .toLowerCase();

    try {
      await _athanChannel.invokeMethod('scheduleAthan', {
        'id': id,
        'prayerName': prayerName,
        'soundFile': soundFileName,
        'scheduledTime': _nextInstanceOfTime(prayerTime).millisecondsSinceEpoch,
      });
      debugPrint("✅ scheduleAthan: $prayerName ($soundFileName) @ $prayerTime");
    } catch (e) {
      debugPrint("❌ scheduleAthan channel error: $e");
    }
  }

  Future<void> _cancelAthan(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id);
    try {
      await _athanChannel.invokeMethod('cancelAthan', {'id': id});
    } catch (e) {
      debugPrint("cancelAthan channel error: $e");
    }
  }

  Future<void> _cancelAllAthans() async {
    await flutterLocalNotificationsPlugin.cancelAll();
    try {
      await _athanChannel.invokeMethod('cancelAll');
    } catch (e) {
      debugPrint("cancelAll channel error: $e");
    }
  }

  // ── داوای مۆڵەت ──────────────────────────────────
  Future<bool> _requestPermissions() async {
    if (!mounted) return false;

    final bool notifOk = await Permission.notification.isGranted;
    final bool batteryOk =
        await Permission.ignoreBatteryOptimizations.isGranted;

    if (notifOk && batteryOk) return true;

    if (!mounted) return false;
    final bool? agreed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text("ڕێپێدانی پێویست",
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
          content: const Text(
            "بۆ ئەوەی بانگەکان کار بکەن، پێویستە ڕێپێدانی ئاگادارکردنەوە و باکگراوند بدەیت.",
            style: TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("بۆ کاتێکى تر",
                  style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("باشە",
                  style: TextStyle(
                      color: Colors.blueAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
            ),
          ],
        ),
      ),
    );

    if (agreed != true) return false;

    // --- لێرەدا گۆڕانکارییەکەمان کردووە بۆ ئەوەی یەک یەک دەربکەون ---

    // سەرەتا داوای نۆتیفیکەیشن دەکەین
    final notificationStatus = await Permission.notification.request();

    // تەنها ئەگەر نۆتیفیکەیشنی قبوڵ کرد، ئینجا داوای Battery Optimization دەکەین
    if (notificationStatus.isGranted) {
      await Permission.ignoreBatteryOptimizations.request();
    }

    // لە کۆتاییدا ئەنجامی نۆتیفیکەیشنەکە دەگەڕێنینەوە بۆ ئەوەی بزانین کارتەکە چالاک بکەین یان نا
    return await Permission.notification.isGranted;
  }

  // ── پشکنینی نوێکردنەوە ───────────────────────────
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
    final c = current.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final n = newer.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final maxLen = c.length > n.length ? c.length : n.length;
    for (int i = 0; i < maxLen; i++) {
      final cv = i < c.length ? c[i] : 0;
      final nv = i < n.length ? n[i] : 0;
      if (nv > cv) return true;
      if (nv < cv) return false;
    }
    return false;
  }

  Future<void> _showUpdateDialog(String url, String version) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text("وەشانێکی نوێ بەردەستە",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white)),
          content: Text(
            "وەشانی $version ئێستا بەردەستە، ئایا دەتەوێت نوێی بکەیتەوە؟",
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
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
                _startUpdate(url, version);
              },
              child: const Text("نوێکردنەوە"),
            ),
          ],
        ),
      ),
    );
  }

  // ── داگرتن و ئینستاڵی نوێکردنەوە ────────────────
  void _startUpdate(String url, String version) async {
    await WakelockPlus.enable();
    if (!mounted) return;

    bool canInstall = await Permission.requestInstallPackages.isGranted;
    if (!canInstall) {
      final status = await Permission.requestInstallPackages.request();
      canInstall = status.isGranted;
    }

    if (!canInstall) {
      await WakelockPlus.disable();
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) => Directionality(
          textDirection: ui.TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            title: const Text("مۆڵەتی ئینستاڵ پێویستە",
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            content: const Text(
              "تکایە لە ڕێکخستن مۆڵەتی \"ئینستاڵکردنی ئەپی نەناسراو\" بدە بە ئەپەکە، پاشان دووبارە هەوڵ بدەرەوە.",
              style: TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child:
                    const Text("دواتر", style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
                onPressed: () async {
                  Navigator.pop(ctx);
                  await openAppSettings();
                  if (mounted) _startUpdate(url, version);
                },
                child: const Text("کردنەوەی ڕێکخستن"),
              ),
            ],
          ),
        ),
      );
      return;
    }
    if (!mounted) return;

    double dlProgress = 0;
    String statusText = "ئامادەکاری دەکرێت...";
    bool hasError = false;
    String errorText = "";
    bool dialogOpen = true;
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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
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
                        color: primaryColor,
                        backgroundColor: Colors.white24,
                        minHeight: 8,
                      ),
                      const SizedBox(height: 15),
                      Text(
                        dlProgress > 0
                            ? "${dlProgress.toStringAsFixed(0)}%"
                            : "",
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 25,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(statusText,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13)),
                    ]),
            );
          },
        ),
      ),
    ).then((_) => dialogOpen = false);

    try {
      OtaUpdate()
          .execute(url, destinationFilename: 'update_v$version.apk')
          .listen(
        (OtaEvent event) {
          if (!mounted) return;
          switch (event.status) {
            case OtaStatus.DOWNLOADING:
              setDlState?.call(() {
                dlProgress = double.tryParse(event.value ?? '0') ?? 0;
                statusText = "تکایە چاوەڕوان بن...";
              });
              break;
            case OtaStatus.INSTALLING:
              setDlState?.call(() {
                dlProgress = 100;
                statusText = "ئێستا ئینستاڵ دەست پێ دەکات...";
              });
              WakelockPlus.disable();
              Future.delayed(const Duration(milliseconds: 500), () {
                if (mounted && dialogOpen) {
                  Navigator.of(context, rootNavigator: true).pop();
                }
              });
              break;
            case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
              setDlState?.call(() {
                hasError = true;
                errorText = "مۆڵەتی ئینستاڵ نەدرا — تکایە لە ڕێکخستن چالاک بکە";
              });
              WakelockPlus.disable();
              break;
            case OtaStatus.ALREADY_RUNNING_ERROR:
            case OtaStatus.INTERNAL_ERROR:
            case OtaStatus.DOWNLOAD_ERROR:
            case OtaStatus.CHECKSUM_ERROR:
              setDlState?.call(() {
                hasError = true;
                errorText = "هەڵە لە داگرتن: ${event.value}";
              });
              WakelockPlus.disable();
              break;
            default:
              break;
          }
        },
        onError: (e) {
          if (!mounted) return;
          setDlState?.call(() {
            hasError = true;
            errorText = "هەڵە: $e";
          });
          WakelockPlus.disable();
        },
      );
    } catch (e) {
      debugPrint("Update error: $e");
      setDlState?.call(() {
        hasError = true;
        errorText = "هەڵە لە داگرتنی فایلەکە:\n$e";
      });
      WakelockPlus.disable();
    }
  }

  // ── دووبارە خشتەکردنی هەموو بانگەکان ────────────
  Future<void> _refreshAllAthanSchedules(PrayerTimes times) async {
    await _cancelAllAthans();

    final prayers = [
      {'id': 1, 'name': 'بەیانی', 'time': times.fajr},
      {'id': 2, 'name': 'نیوەڕۆ', 'time': times.dhuhr},
      {'id': 3, 'name': 'عەسر', 'time': times.asr},
      {'id': 4, 'name': 'ئێوارە', 'time': times.maghrib},
      {'id': 5, 'name': 'خەوتنان', 'time': times.isha},
    ];

    for (final prayer in prayers) {
      if (activeAthans.contains(prayer['name'])) {
        await _scheduleAthan(
          prayer['id'] as int,
          prayer['name'] as String,
          prayer['time'] as DateTime,
        );
      }
    }
  }

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

  void _refreshData() {
    if (!mounted) return;
    setState(() {
      _prayerTimesFuture = _prayerDataService.getPrayerTimes(currentCity, _now);
    });
  }

  // ── ماوەی بانگی داهاتوو ──────────────────────────
  String _getNextRemaining(PrayerTimes times) {
    final now = DateTime.now();
    final list = [
      times.fajr,
      times.dhuhr,
      times.asr,
      times.maghrib,
      times.isha,
    ];

    DateTime? next;
    for (final pt in list) {
      if (pt.isAfter(now)) {
        next = pt;
        break;
      }
    }
    next ??= DateTime(
            now.year, now.month, now.day, times.fajr.hour, times.fajr.minute)
        .add(const Duration(days: 1));

    final diff = next.difference(now);
    final h = diff.inHours.toString().padLeft(2, '0');
    final m = diff.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = diff.inSeconds.remainder(60).toString().padLeft(2, '0');
    return _timeService.toKu("$h:$m:$s");
  }

  String _getNextPrayerName(PrayerTimes times) {
    final now = DateTime.now();
    if (now.isBefore(times.fajr)) return "بەیانی";
    if (now.isBefore(times.dhuhr)) return "نیوەڕۆ";
    if (now.isBefore(times.asr)) return "عەسر";
    if (now.isBefore(times.maghrib)) return "ئێوارە";
    if (now.isBefore(times.isha)) return "خەوتنان";
    return "بەیانی";
  }

  // ── تاپ لەسەر کارتی بانگ ─────────────────────────
  Future<void> _handlePrayerCardTap(String name, String time) async {
    if (name == "خۆرهەڵاتن") return;

    final bool willBeActive = !activeAthans.contains(name);

    if (willBeActive) {
      // لێرەدا هەم پشکنین دەکات هەم داوای ڕێپێدان، ئەگەر "بۆ کاتێکی تر" دابگرێت لێرەدا دەوەستێت
      final bool hasPermission = await _requestPermissions();
      if (!hasPermission) return;
    }

    setState(() {
      if (willBeActive) {
        activeAthans.add(name);
      } else {
        activeAthans.remove(name);
      }
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          willBeActive ? "بانگی $name چالاک کرا" : "بانگی $name ناچالاک کرا",
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
          ),
        ),
        backgroundColor:
            willBeActive ? const Color(0xFF10B981) : Colors.redAccent,
        duration: const Duration(seconds: 2),
      ),
    );

    await _saveSettings();

    if (willBeActive) {
      final String cleanTime = time
          .replaceAllMapped(
              RegExp(r'[٠-٩]'),
              (m) => {
                    '٠': '0',
                    '١': '1',
                    '٢': '2',
                    '٣': '3',
                    '٤': '4',
                    '٥': '5',
                    '٦': '6',
                    '٧': '7',
                    '٨': '8',
                    '٩': '9',
                  }[m.group(0)]!)
          .replaceAllMapped(
              RegExp(r'[۰-۹]'),
              (m) => {
                    '۰': '0',
                    '۱': '1',
                    '۲': '2',
                    '۳': '3',
                    '۴': '4',
                    '۵': '5',
                    '۶': '6',
                    '۷': '7',
                    '۸': '8',
                    '۹': '9',
                  }[m.group(0)]!)
          .trim();

      final regMatch = RegExp(r'(\d+):(\d+)').firstMatch(cleanTime);
      if (regMatch == null) return;

      int hour = int.parse(regMatch.group(1)!);
      final int minute = int.parse(regMatch.group(2)!);

      if ((cleanTime.contains("د.ن") ||
              cleanTime.toUpperCase().contains("PM")) &&
          hour < 12) {
        hour += 12;
      }
      if ((cleanTime.contains("پ.ن") ||
              cleanTime.toUpperCase().contains("AM")) &&
          hour == 12) {
        hour = 0;
      }

      final now = DateTime.now();
      DateTime scheduledDate =
          DateTime(now.year, now.month, now.day, hour, minute);
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      await _cancelAthan(name.hashCode);
      await _scheduleAthan(name.hashCode, name, scheduledDate);
    } else {
      await _athanPlayer.stop();
      await _cancelAthan(name.hashCode);
    }
  }

  // ══════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: FutureBuilder<PrayerTimes>(
        future: _prayerTimesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(
              backgroundColor: _palette.background,
              body: Center(
                child: CircularProgressIndicator(color: _palette.primary),
              ),
            );
          }

          if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
            return Scaffold(
              backgroundColor: _palette.background,
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
            backgroundColor: _palette.background,
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

  // ── AppBar ─────────────────────────────────────────
  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: _palette.background,
      elevation: 0,
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          Icon(Icons.mosque, color: _palette.secondary, size: 30),
          const SizedBox(width: 10),
          const Text("کاتەکانى بانگ",
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          const SizedBox(width: 10),
          Text("($currentCity)",
              style: TextStyle(fontSize: 15, color: _palette.secondary)),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(2),
        child: Container(height: 2.0, color: _palette.divider),
      ),
      actions: [
        Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu_open, color: _palette.primary, size: 40),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ],
    );
  }

  // ── لەیاوتی تەبلێت ────────────────────────────────
  Widget _buildTabletLayout(PrayerTimes prayerTimes) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: ListView.builder(
              itemCount: prayerNames.length,
              itemBuilder: (context, i) => _buildPrayerCard(i),
            ),
          ),
        ),
        VerticalDivider(color: _palette.divider, width: 1, thickness: 1),
        Expanded(
          flex: 3,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ClockWidget(
                  now: _now, timeService: _timeService, palette: _palette),
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

  // ── لەیاوتی مۆبایل ────────────────────────────────
  Widget _buildPhoneLayout(PrayerTimes prayerTimes) {
    return Column(
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
        Divider(color: _palette.divider, height: 10),
        Expanded(
          child: Column(
            children: List.generate(6, (i) => _buildPrayerCard(i)),
          ),
        ),
      ],
    );
  }

  // ── دروستکردنی کارتی بانگ ─────────────────────────
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
