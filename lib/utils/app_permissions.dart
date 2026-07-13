import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

/// مۆڵەتەکانی میدیا/ئاگادارکردنەوە (بانگ + قورئان) — بێ دووبارە داوا لە کاتێکدا تەواوبوو.
class AppPermissions {
  static Future<void> requestNotificationAndBatteryIfMissing() async {
    if (!Platform.isAndroid) return;
    if (!await Permission.notification.isGranted) {
      await Permission.notification.request();
    }
    if (!await Permission.ignoreBatteryOptimizations.isGranted) {
      await Permission.ignoreBatteryOptimizations.request();
    }
  }
}
