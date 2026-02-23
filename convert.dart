import 'dart:convert';
import 'dart:io';

void main() async {
  // لیستی ئەو فایلانەی دەمانەوێت ناوی کلیلەکانیان بگۆڕین
  List<String> filesToUpdate = [
    'assets/prayer_time.json',
    'assets/penjwen_time.json'
  ];

  try {
    for (String filePath in filesToUpdate) {
      final file = File(filePath);

      if (!await file.exists()) {
        stdout.writeln("فایل نەدۆزرایەوە: $filePath");
        continue;
      }

      final String content = await file.readAsString();
      List<dynamic> data = json.decode(content);
      List<Map<String, dynamic>> updatedData = [];

      for (var row in data) {
        Map<String, dynamic> newRow = {};

        row.forEach((key, value) {
          String newKey = key;
          // گۆڕینی ناوەکان لێرە ئەنجام دەدرێت
          if (key == 'مەغریب') {
            newKey = 'ئێوارە';
          } else if (key == 'عیشاء') {
            newKey = 'خەوتنان';
          }
          newRow[newKey] = value;
        });

        updatedData.add(newRow);
      }

      // پاشەکەوتکردنەوەی فایلەکە بە ناوە نوێیەکانەوە
      await file.writeAsString(json.encode(updatedData));
      stdout.writeln("سەرکەوتوو بوو: ناوی کلیلەکان لە $filePath گۆڕدرا.");
    }
  } catch (e) {
    stderr.writeln("هەڵەیەک ڕوویدا: $e");
  }
}
