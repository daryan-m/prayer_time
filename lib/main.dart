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

  // ── کات و کەناڵ ──
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Baghdad'));

  // ── دروستکردنی کەناڵی سەرەتایی (kamal_rauf) ──
  // ✅ ئەمە تەنها بۆ دەستپێک — کاتی هەڵبژاردنی دەنگی تر، کەناڵ دووبارە دروست دەکرێت
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'athan_alerts_v2',
    'بانگ',
    description: 'کەناڵی نۆتیفیکەیشنی بانگ',
    importance: Importance.max,
    sound: RawResourceAndroidNotificationSound('kamal_rauf'),
    playSound: true,
  );

  final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
      flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  if (androidPlugin != null) {
    await androidPlugin.createNotificationChannel(channel);
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
        textTheme:
            ThemeData.dark().textTheme.apply(fontFamily: 'NotoNaskh'),
      ),
      home: const PrayerHomePage(),
    );
  }
}
