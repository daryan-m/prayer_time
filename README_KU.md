# 🕌 ئەپی کاتەکانی بانگ بۆ کوردستان

ئەپێکی تەواو بۆ پیشاندانی کاتەکانی بانگ لە پێنجوێن و سلێمانی بە ئۆفلاین.

---

## ✨ تایبەتمەندییەکان

✅ **کاتەکانی بانگ بە ئۆفلاین** - داتا لە JSON فایلەکانەوە
✅ **دوو شار** - پێنجوێن و سلێمانی
✅ **کاتژمێری زیندوو** - هەر چرکەیەک نوێ دەبێتەوە
✅ **سێ بەروار:**
   - بەروارى کۆچى (لە JSON)
   - بەروارى میلادى (بە فۆرماتى /)
   - بەروارى کوردى (بە حیسابی +625)
✅ **٣ دەنگی جیاواز بۆ بانگ:**
   - بانگى مەککە
   - بانگی مەدینە
   - بانگی کوەیت
✅ **ئاگادارکردنەوە** - لە کاتی داخراندا بانگ دەدات
✅ **پشکنینی ئەپدەیت** - هەر ٢٤ کاتژمێر جارێک
✅ **Responsive Design** - بۆ هەموو شاشەیەک

---

## 📂 پێکهاتەی پرۆژە

```
lib/
├── main.dart                   # دەستپێکردنی ئەپ
├── screens/
│   └── home_screen.dart       # پەڕەی سەرەکی
├── widgets/
│   ├── prayer_widgets.dart    # کارتەکان، کاتژمێر، بەروار
│   └── drawer_widget.dart     # Drawer
├── services/
│   └── prayer_service.dart    # خوێندنەوەی JSON + تایمەکان
└── utils/
    └── constants.dart         # ڕەنگ، data، بەراوردکردنی وەشان

assets/
├── data/
│   ├── penjwen_time.json      # کاتەکانی پێنجوێن (٣٦٦ ڕۆژ)
│   └── prayer_time.json       # کاتەکانی سلێمانی (٣٦٦ ڕۆژ)
└── audio/
    ├── bang.mp3         # دەنگی یەکەم
    ├── madina.mp3             # دەنگی دووەم
    └── kwait.mp3              # دەنگی سێیەم
```

---

## 🚀 چۆنیەتی دامەزراندن

### ١. **پێداویستییەکان:**
```bash
flutter --version  # Flutter 3.0+
```

### ٢. **دابەزاندنی پرۆژە:**
```bash
git clone https://github.com/daryan-m/prayer_time.git
cd prayer_time
```

### ٣. **دامەزراندنی پاکێجەکان:**
```bash
flutter pub get
```

### ٤. **زیادکردنی فایلە دەنگییەکان:**
```
assets/audio/
├── macca.mp3
├── madina.mp3
└── kwait.mp3
```

⚠️ **گرنگ:** دەنگەکان دەبێت لە فۆڵدەری `assets/audio/` دابنرێن!

### ٥. **جێبەجێکردن:**
```bash
# بۆ ئەندرۆید
flutter run

# بۆ دروستکردنی APK
flutter build apk --release

# بۆ دروستکردنی App Bundle
flutter build appbundle --release
```

---

## 📦 پاکێجەکان

لە `pubspec.yaml`:

```yaml
dependencies:
  intl: ^0.19.0                           # بەروار و فۆرماتکردن
  hijri: ^3.0.0                           # بەرواری کۆچی
  timezone: ^0.9.2                        # کاتەکان
  audioplayers: ^5.2.1                    # لێدانی دەنگ
  flutter_local_notifications: ^16.3.0    # ئاگادارکردنەوە
  http: ^1.1.2                            # پشکنینی ئەپدەیت
  url_launcher: ^6.2.2                    # کردنەوەی لینکەکان
  ota_update: ^6.0.0                      # نوێکردنەوەی ئەپ
```

زیادکردن:
```bash
flutter pub add intl hijri timezone audioplayers flutter_local_notifications http url_launcher ota_update
```

---

## 🔄 سیستەمی ئەپدەیت

### چۆن کاردەکات:

1. **ئەپەکە** هەر ٢٤ کاتژمێر جارێک پشکنین دەکات
2. **فایلی `version.json`** لە GitHub دەخوێنێتەوە:
   ```json
   {
     "version": "1.0.1",
     "url": "https://github.com/daryan-m/prayer_time/releases/download/v1.0.1/prayer_app.apk"
   }
   ```
3. **بەراوردکردن:** ئەگەر وەشانی نوێ > وەشانی ئێستا
4. **پەیامی نوێکردنەوە** پیشان دەدات

### چۆنیەتی دانانی وەشانی نوێ:

**لە GitHub:**

1. **دروستکردنی APK:**
   ```bash
   flutter build apk --release
   ```

2. **دروستکردنی Release لە GitHub:**
   - بڕۆ بۆ: `Releases` > `Create new release`
   - Tag: `v1.0.1`
   - Upload: `app-release.apk`

3. **نوێکردنەوەی `version.json`:**
   ```json
   {
     "version": "1.0.1",
     "url": "https://github.com/daryan-m/prayer_time/releases/download/v1.0.1/prayer_app.apk"
   }
   ```

4. **Commit & Push:**
   ```bash
   git add version.json
   git commit -m "Update version to 1.0.1"
   git push
   ```

✅ **ئێستا بەکارهێنەران پەیامی ئەپدەیت دەبینن!**

---

## 📱 تایبەتمەندییە تایبەتەکان

### ١. **کاتەکانی بانگ لە JSON:**
```dart
// لە prayer_service.dart
Future<PrayerTimes> getPrayerTimes(String city, DateTime date) async {
  String fileName = city == "پێنجوێن"
      ? "penjwen_time.json"
      : "prayer_time.json";

  String jsonString = await rootBundle.loadString('assets/data/$fileName');
  // ...
}
```

### ٢. **بەرواری کوردی:**
```dart
// لە prayer_service.dart
String kurdishDateString(DateTime dt) {
  int kurdishYear = dt.year + 625;
  final months = ["خاکەلێوە", "گوڵان", ...];
  return "${dt.day}ی ${months[dt.month-1]} $kurdishYear";
}
```

### ٣. **هەڵبژاردنی دەنگ:**
```dart
// لە home_screen.dart
Future<void> _scheduleAthanBackground(...) async {
  String soundFileName = selectedAthanFile.replaceAll('.mp3', '');
  // بەکارهێنانی دەنگی هەڵبژێردراو
}
```

### ٤. **بەراوردکردنی وەشان:**
```dart
// لە constants.dart
bool isNewerVersion(String current, String newVer) {
  // بەراوردکردنی "1.0.0" لەگەڵ "1.0.1"
  // ئەگەر newVer > current → true
}
```

---

## 🐛 چارەسەری کێشەکان

### کێشە: JSON بارنابێت
```bash
flutter clean
flutter pub get
flutter run
```

### کێشە: دەنگ نایە
- دڵنیابە فایلەکان لە `assets/audio/` دایە
- لە `pubspec.yaml` چک بکە:
  ```yaml
  assets:
    - assets/audio/
  ```

### کێشە: Notification کارناکات
```dart
// لە AndroidManifest.xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
```

### کێشە: OTA Update کارناکات
```dart
// لە AndroidManifest.xml
<uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES"/>
```

---

## 📸 Screenshot-ەکان

```
[شاشەی سەرەکی]    [Drawer]    [Notification]
```

---

## 🤝 بەشداریکردن

بەخێرهاتن! Pull Request بنێرە یان Issue دروست بکە.

---

## 📞 پەیوەندی

- **YouTube:** [@daryan111](https://www.youtube.com/@daryan111)
- **GitHub:** [daryan-m/prayer_time](https://github.com/daryan-m/prayer_time)

---

## 📜 لایسێنس

MIT License - بەخۆڕایی بەکاری بهێنە و بیگۆڕە.

---

**دروستکراوە بە ❤️ بۆ خەڵکی کوردستان**

🕌 **کاتەکانی بانگ - پێنجوێن و سلێمانی** 🕌
