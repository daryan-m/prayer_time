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
import 'package:wakelock_plus/wakelock_plus.dart';

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowPermissions();
    });

    // ئەم بەشە زیاد بکە
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

  Future<void> _checkAndShowPermissions() async {
    // نیو چرکە چاوەڕێ دەکات تا شاشە جێگیر بێت
    await Future.delayed(const Duration(seconds: 2));

    // ١. پشکنین بەبێ داواکردن (Request ناگۆڕین تەنها Check دەکەین)
    bool isNotificationDenied = await Permission.notification.isDenied;
    bool isAlarmDenied = await Permission.scheduleExactAlarm.isDenied;

    // ئەگەر یەکێکیان ڕەتکرابووەوە، نامەکەی خۆت نیشان بدە
    if (isNotificationDenied || isAlarmDenied) {
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
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
                  // ١. یەکەمجار نامە شینەکەی خۆت دایدەخەین
                  Navigator.pop(context);

                  // ٢. بانگکردنی ڕێپێدانی نۆتیفیکەیشن بەو فەنکشنە تایبەتەی خۆت (بۆ ئەندرۆید ١٣+)
                  try {
                    final androidPlugin = flutterLocalNotificationsPlugin
                        .resolvePlatformSpecificImplementation<
                            AndroidFlutterLocalNotificationsPlugin>();
                    await androidPlugin?.requestNotificationsPermission();
                  } catch (e) {
                    debugPrint("Error requesting notification permission: $e");
                  }

                  // ٣. داواکردنی هەموو مۆڵەتەکان بەیەکەوە (ئەمە پەنجەرە سپییە فەرمییەکان دەهێنێت)
                  Map<Permission, PermissionStatus> statuses = await [
                    Permission.notification,
                    Permission.scheduleExactAlarm,
                    Permission.ignoreBatteryOptimizations,
                  ].request();

                  // ٤. پشکنین: ئەگەر بەکارهێنەر بە تەواوی ڕەستی کردەوە (Permanently Denied)
                  if (statuses[Permission.notification]!.isPermanentlyDenied ||
                      statuses[Permission.scheduleExactAlarm]!
                          .isPermanentlyDenied) {
                    // کردنەوەی پەڕەی ڕێکخستنی ئەپەکە بۆ ئەوەی بە دەست چالاکی بکات
                    await openAppSettings();
                  }
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

  Future<void> _showUpdateDialog(String url, String version) async {
    await showDialog(
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
              // ✅ چارەسەر: لێرە version تێپەڕێنرا
              _startUpdate(url, version);
            },
            child: const Text("نوێکردنەوە"),
          ),
        ],
      ),
    );
  }

  // ✅ تێبینی: پارامێتەری version زیادکرا
  void _startUpdate(String url, String version) async {
    // ڕێگری لە کوژانەوەی شاشە
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
              // ئەگەر هەڵەیەک ڕوو بدات (وەک نەبوونی ئینتەرنێت)
              if (snapshot.hasError) {
                WakelockPlus.disable();
                return _buildErrorUI("کێشەیەک لە پەیوەندی ڕوویدا");
              }

              if (snapshot.hasData) {
                final status = snapshot.data!.status;
                final value = snapshot.data!.value;

                switch (status) {
                  case OtaStatus.DOWNLOADING:
                    double progress = double.tryParse(value ?? "0") ?? 0;
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

// --- فەنکشنە یارمەتیدەرەکان بۆ ئەوەی کۆدەکەت خاوێن بێت ---

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

  // --- NOTIFICATION ---
  Future<void> _scheduleAthanBackground(
      int id, String prayerName, DateTime prayerTime) async {
    // 1️⃣ خاوێنکردنەوەی ناوی فایل (لادانی سپەیس و گۆڕین بۆ پیتی بچووک)
    // زۆر گرنگە: ناوی فایلەکە لە ناو res/raw دەبێت تەنها پیت و ژمارە و _ بێت
    String soundFileName = selectedAthanFile
        .replaceAll('.mp3', '')
        .replaceAll(' ', '_') // سپەیس دەکاتە _
        .toLowerCase();

    // 2️⃣ بەکارهێنانی هەمان ئەو ناوەی لە مانیفێست دامان ناوە
    const String channelId = 'athan_alerts_v2';

    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      // 🔹 سڕینەوەی کەناڵە کۆنەکە بۆ ئەوەی ئەندرۆید دەنگە نوێیەکە قبوڵ بکات
      await androidPlugin.deleteNotificationChannel(channelId);

      // 🔹 دروستکردنی کەناڵەکە بە هەمان ID ی ناو مانیفێست
      await androidPlugin.createNotificationChannel(
        AndroidNotificationChannel(
          channelId,
          'بانگ', // ناوێکی سابت و جوان بۆ سێتینگ
          description: 'کەناڵی نۆتیفیکەیشنی بانگ',
          importance: Importance.max,
          sound: RawResourceAndroidNotificationSound(soundFileName),
          playSound: true,
          enableVibration: true,
        ),
      );
    }

    // 3️⃣ دیاریکردنی وردەکارییەکان
    AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelId,
      'بانگ',
      channelDescription: 'کەناڵی نۆتیفیکەیشنی بانگ',
      importance: Importance.max,
      priority: Priority.high,
      sound: RawResourceAndroidNotificationSound(soundFileName),
      playSound: true,
      fullScreenIntent: true, // بۆ ئەوەی لە شاشەی قفڵیش نیشانی بدات
      category:
          AndroidNotificationCategory.alarm, // وەک ئەلارم مامەڵەی لەگەڵ بکات
    );

    // 4️⃣ خشتەکردن (Schedule)
    await flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        'کاتی بانگی $prayerName',
        'ئێستا کاتی بانگی $prayerNameەیە',
        _nextInstanceOfTime(prayerTime),
        NotificationDetails(android: androidDetails),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time);
  }

  Future<void> refreshAllAthanSchedulesFromJson(
      Map<String, dynamic> todayJson) async {
    // ١. سڕینەوەی هەموو بانگە کۆنەکان
    await flutterLocalNotificationsPlugin.cancelAll();

    // ٢. لیستێک دروست دەکەین بۆ ناوەکان و کاتەکان ڕێک بەپێی کلیلەکانی ناو JSONەکەت
    final prayerMapping = [
      {'id': 1, 'name': 'بەیانی', 'key': 'بەیانی'},
      {'id': 2, 'name': 'نیوەڕۆ', 'key': 'نیوەڕۆ'},
      {'id': 3, 'name': 'عەسر', 'key': 'عەسر'},
      {
        'id': 4,
        'name': 'مەغریب',
        'key': 'ئێوارە'
      }, // لێرە 'ئێوارە' کلیلی ناو JSONەکەتە
      {
        'id': 5,
        'name': 'عیشا',
        'key': 'خەوتنان'
      }, // لێرە 'خەوتنان' کلیلی ناو JSONەکەتە
    ];

    final now = DateTime.now();

    for (var prayer in prayerMapping) {
      String timeString = todayJson[prayer['key']]; // بۆ نموونە "05:00"

      // ٣. گۆڕینی "05:00" بۆ DateTime ی تەواوی ئەمڕۆ
      List<String> parts = timeString.split(':');
      DateTime prayerDateTime = DateTime(
        now.year,
        now.month,
        now.day,
        int.parse(parts[0]),
        int.parse(parts[1]),
      );

      // ٤. ئەگەر کاتی بانگەکە بەسەرچووبوو، بۆ بەیانی خشتەی بکە
      if (prayerDateTime.isBefore(now)) {
        prayerDateTime = prayerDateTime.add(const Duration(days: 1));
      }

      // ٥. بانگی فەنکشنی ئەسڵ دەکەین بۆ دانانی نۆتیفیکەیشنەکە
      await _scheduleAthanBackground(
        prayer['id'] as int,
        prayer['name'] as String,
        prayerDateTime,
      );
    }
  }

  Future<void> refreshAllAthanSchedules(PrayerTimes times) async {
    // ١. سڕینەوەی هەموو بانگە کۆنەکان
    await flutterLocalNotificationsPlugin.cancelAll();

    // ٢. دیاریکردنی بانگەکان (بەبێ خۆرهەڵاتن)
    final prayers = [
      {'id': 1, 'name': 'بەیانی', 'time': times.fajr},
      {'id': 2, 'name': 'نیوەڕۆ', 'time': times.dhuhr},
      {'id': 3, 'name': 'عەسر', 'time': times.asr},
      {'id': 4, 'name': 'مەغریب', 'time': times.maghrib},
      {'id': 5, 'name': 'عیشا', 'time': times.isha},
    ];

    // ٣. دووبارە خشتەکردنەوە بە دەنگە نوێیەکە
    for (var prayer in prayers) {
      await _scheduleAthanBackground(
        prayer['id'] as int,
        prayer['name'] as String,
        prayer['time'] as DateTime,
      );
    }
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
    // ❌ ئەگەر کارت خۆرهەڵاتنە، هیچ کارێک مەکە
    if (name == "خۆرهەڵاتن") {
      return;
    }

    // 🔴 Update UI
    setState(() {
      if (activeAthans.contains(name)) {
        activeAthans.remove(name); // ناچالاک
      } else {
        activeAthans.add(name); // چالاک
      }
    });

    // پاشەکەوتکردنی دۆخ
    await _saveSettings();

    final now = DateTime.now();

    // پاککردن ژمارەکان و گۆڕینی بۆ 24h format
    String cleanTime = time.replaceAllMapped(RegExp(r'[٠-٩]'), (match) {
      const arabicToEnglish = {
        '٠': '0',
        '١': '1',
        '٢': '2',
        '٣': '3',
        '٤': '4',
        '٥': '5',
        '٦': '6',
        '٧': '7',
        '٨': '8',
        '٩': '9'
      };
      return arabicToEnglish[match.group(0)]!;
    }).replaceAllMapped(RegExp(r'[۰-۹]'), (match) {
      const persianToEnglish = {
        '۰': '0',
        '۱': '1',
        '۲': '2',
        '۳': '3',
        '۴': '4',
        '۵': '5',
        '۶': '6',
        '۷': '7',
        '۸': '8',
        '۹': '9'
      };
      return persianToEnglish[match.group(0)]!;
    }).trim();

    final regExp = RegExp(r'(\d+):(\d+)');
    final match = regExp.firstMatch(cleanTime);
    if (match == null) return;

    int hour = int.parse(match.group(1)!);
    int minute = int.parse(match.group(2)!);

    // AM/PM to 24h
    if ((cleanTime.contains("د.ن") || cleanTime.toUpperCase().contains("PM")) &&
        hour < 12) {
      hour += 12;
    }
    if ((cleanTime.contains("پ.ن") || cleanTime.toUpperCase().contains("AM")) &&
        hour == 12) {
      hour = 0;
    }

    DateTime scheduledDate =
        DateTime(now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    // ⚡ پێش بەکارهێنانی context یا UI چک بکە widget هەیە
    // ⚡ پێش بەکارهێنانی context چک بکە widget هەیە
    if (!mounted) {
      return;
    }

    if (activeAthans.contains(name)) {
      // ✅ کارت چالاک: هەموو ڕۆژ notification + دەنگ
      // ⚡ پێش بەکارهێنانی context چک بکە widget هەیە
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "بانگی $name چالاک کرا",
            textAlign: TextAlign.center,
          ),
          backgroundColor: const Color(0xFF10B981),
          duration: const Duration(seconds: 1),
        ),
      );

      // پێش schedule، cancel بکە بۆ جلوگیری duplicate
      await flutterLocalNotificationsPlugin.cancel(name.hashCode);

      // schedule notification هەموو ڕۆژ
      await _scheduleAthanBackground(name.hashCode, name, scheduledDate);
    } else {
      // ❌ کارت ناچالاک: notification + دەنگ بسڕە
      await _audioPlayer.stop();
      await flutterLocalNotificationsPlugin.cancel(name.hashCode);

      // اگر پێویست بە async function هەیە
      // await someAsyncFunction(); // اگر نییە، ڕەوانە بکە

      // دوبارە چک بکە widget هەیە پێش UI
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("بانگی $name ناچالاک کرا", textAlign: TextAlign.center),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 1),
        ),
      );
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
              backgroundColor: AppColors.background,
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
                preferredSize: const Size.fromHeight(2),
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
} // ئەمە کۆتا کەوانەیە و کڵاسەکە دادەخات (تەنها یەک دانە بێت)
