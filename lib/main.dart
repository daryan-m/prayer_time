import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'screens/home_screen.dart';

// ==================== MAIN ====================

// گلۆبەل — بە home_screen.dart هاوبەشە
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── کات ──
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Baghdad'));

  // ── سێ کەناڵی نۆتیفیکەیشن — یەکێک بۆ هەر دەنگێک ──
  // bypassDnd: true — لە DND (سایلەنت مۆد) یش کار دەکات
  const List<AndroidNotificationChannel> channels = [
    AndroidNotificationChannel(
      'athan_madina',
      'بانگ - madina',
      description: 'کەناڵی نۆتیفیکەیشنی بانگ',
      importance: Importance.max,
      sound: RawResourceAndroidNotificationSound('madina'),
      playSound: true,
      enableVibration: true,
      // لێرەدا چیتر bypassDnd نانووسین، لە جیاتی ئەو ئەمە زیاد دەکەین:
      audioAttributesUsage: AudioAttributesUsage.alarm,
    ),
    AndroidNotificationChannel(
      'athan_macca',
      'بانگ - macca',
      description: 'کەناڵی نۆتیفیکەیشنی بانگ',
      importance: Importance.max,
      sound: RawResourceAndroidNotificationSound('macca'),
      playSound: true,
      enableVibration: true,
      audioAttributesUsage: AudioAttributesUsage.alarm,
    ),
    AndroidNotificationChannel(
      'athan_kwait',
      'بانگ - kwait',
      description: 'کەناڵی نۆتیفیکەیشنی بانگ',
      importance: Importance.max,
      sound: RawResourceAndroidNotificationSound('kwait'),
      playSound: true,
      enableVibration: true,
      audioAttributesUsage: AudioAttributesUsage.alarm,
    ),
  ];

  final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
      flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  if (androidPlugin != null) {
    for (final ch in channels) {
      await androidPlugin.createNotificationChannel(ch);
    }
  }

  // ── ئامادەکردنی نۆتیفیکەیشن ──
  const AndroidInitializationSettings initAndroid =
      AndroidInitializationSettings('@mipmap/launcher_icon');

  const InitializationSettings initSettings =
      InitializationSettings(android: initAndroid);

  await flutterLocalNotificationsPlugin.initialize(initSettings);

  runApp(const PrayerTimesApp());
}

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

      // ✅ زیادکرا — فۆنت سیستەم ئیگنۆر دەکرێت
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.noScaling,
          ),
          child: child!,
        );
      },
      home: const PrayerHomePage(),
    );
  }
}
