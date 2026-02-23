import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'screens/home_screen.dart';
import 'package:timezone/timezone.dart' as tz;

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  // ئەم دێڕە پێویستە بۆ ئەوەی پێش دەستپێکردنی ئەپەکە، سێرڤسەکان ئامادە بن
  WidgetsFlutterBinding.ensureInitialized();

  // ١. ڕێکخستنی کات بۆ بانگدان
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Baghdad'));

  // ٢. ڕێکخستنی سەرەتایی نوتیفیکەیشن (ئایکۆنەکە)
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/launcher_icon');

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  // دەستپێکردنی ئەپەکە
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
