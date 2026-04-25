import 'dart:io';
import 'package:flutter/services.dart';

/// پلەیبەکی نەیتیڤ (Android) — service ـی foreground بۆ داگەڕا لەسەر باکگراوند
class QuranAudioBridge {
  static const _method = MethodChannel('com.daryan.prayer/quran_media');
  static const _event = EventChannel('com.daryan.prayer/quran_media_events');

  static Stream<dynamic> get eventStream => _event.receiveBroadcastStream();

  static bool get isNativeAndroid => Platform.isAndroid;

  static Future<void> play(
      {required bool isFile,
      required String source,
      required String title}) async {
    if (!isNativeAndroid) return;
    await _method.invokeMethod('play', {
      'isFile': isFile,
      'source': source,
      'title': title,
    });
  }

  static Future<void> pause() async {
    if (!isNativeAndroid) return;
    await _method.invokeMethod('pause');
  }

  static Future<void> resume() async {
    if (!isNativeAndroid) return;
    await _method.invokeMethod('resume');
  }

  static Future<void> stop() async {
    if (!isNativeAndroid) return;
    await _method.invokeMethod('stop');
  }
}
