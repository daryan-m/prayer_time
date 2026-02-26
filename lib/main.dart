import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz; // ئەم دووانە وەک یەک ناویان لێنراوە، کێشە نییە
import 'package:permission_handler/permission_handler.dart';
import 'screens/home_screen.dart';

// ئەم دێڕە پێویستە لە دەرەوەی main بێت
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  // ١. دڵنیابوونەوە لەوەی سێرڤسەکان ئامادەن
  WidgetsFlutterBinding.ensureInitialized();

  // ٢. کات و نۆتیفیکەیشن چەناڵ
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Baghdad'));

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'athan_channel_v1',
    'Athan Notifications',
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

  // ٣. ڕێکخستنی ئایکۆنی نۆتیفیکەیشن
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/launcher_icon');

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

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
      home: const PrayerHomePage(),
    );
  }
}
