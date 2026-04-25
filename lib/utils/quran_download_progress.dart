import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:bang/main.dart' as main_entry;

const int kQuranDownloadNotifId = 7402;

class QuranDownloadProgress {
  static Future<void> show(int done, int total, String reciterName) async {
    final d = done.clamp(0, total);
    await main_entry.flutterLocalNotificationsPlugin.show(
      kQuranDownloadNotifId,
      'داگیردانی قورئان',
      '$reciterName — $d / $total',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'quran_download',
          'داگیردانی قورئان',
          channelDescription: 'پێشەوەیی داگیردانی دێنگی قارەکان',
          importance: Importance.low,
          priority: Priority.low,
          onlyAlertOnce: true,
          showProgress: true,
          maxProgress: total,
          progress: d,
        ),
      ),
    );
  }

  static Future<void> cancel() async {
    await main_entry.flutterLocalNotificationsPlugin.cancel(
        kQuranDownloadNotifId);
  }
}
