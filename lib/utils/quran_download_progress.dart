import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../main.dart';

const int kQuranDownloadNotifId = 7402;

class QuranDownloadProgress {
  static Future<void> show(int done, int total, String reciterName) async {
    final d = done.clamp(0, total);
    await flutterLocalNotificationsPlugin.show(
      kQuranDownloadNotifId,
      'داگرتنى دەنگ ',
      '$reciterName — $d / $total',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'quran_download',
          'داگرتنى دەنگ ',
          channelDescription: 'پێشەوەیی داگرتنى دەنگى قورئانخوین',
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
    await flutterLocalNotificationsPlugin
        .cancel(kQuranDownloadNotifId);
  }
}
