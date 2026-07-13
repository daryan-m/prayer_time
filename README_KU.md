# 🕌 Prayer Times — Bang Kurdistan (Bilingual README)

English | Kurdish (کوردی)

---

## About — دەربارە

This project is a lightweight Flutter app that displays daily prayer (adhan) times for two cities (Penjwen and Sulaymaniyah) using offline JSON data. The app includes notification scheduling, selectable athan sounds, and date formats (Gregorian, Hijri, and a Kurdish year offset).

ئەم پرۆژەیە ئەپێکی Flutter-ە و کاتەکانی بانگ (ئاذان) بۆ دوو شار — پێنجوێن و سلێمانی — پیشان دەدات بە بەکارهێنانی داتای ئۆفلاین لە فایلی JSON دا. ئەپەکە ئاگادارکردن، هەڵبژاردنی دەنگ، و فۆرماتەکانی بەروار (میلادی، کۆچی، و ساڵی کوردی) پشتیوانی دەکات.

---

## Key Features — تایبەتمەندییە سەرەکییەکان

- Offline prayer times from JSON files.
- Two cities: Penjwen and Sulaymaniyah.
- Live clock and daily schedules.
- Multiple date formats: Gregorian, Hijri, Kurdish (year +625).
- Three selectable athan sounds.
- Local notifications for adhan times.
- Automatic update-check (polls `version.json` every 24 hours).

- داتای بانگ بە شێوەی ئۆفلاین (JSON).
- دوو شار: پێنجوێن و سلێمانی.
- کاتژمێر زیندوو و خشتەی ڕۆژانە.
- فۆرماتەکانی بەروار: میلادی، کۆچی، ساڵی کوردی (+625).
- ٣ دەنگی هەڵبژێردراو.
- ئاگادارکردن بۆ کاتەکانی بانگ.
- پشکنینی ئاپدەیت هەر ٢٤ کاتژمێر.

---

## Installation — دامەزراندن

Requirements: Flutter 3.0+

Clone and install:

```bash
git clone https://github.com/daryan-m/prayer_time.git
cd prayer_time
flutter pub get
```

Add audio assets to `assets/audio/`:

```
assets/audio/
├── macca.mp3
├── madina.mp3
└── kwait.mp3
```

Run:

```bash
# Android
flutter run

# Build APK
flutter build apk --release

# Build App Bundle
flutter build appbundle --release
```

---

## Files & Structure — پێکهاتە و فایلەکان

Main folders:

```
lib/
├── main.dart
├── screens/
├── widgets/
├── services/      # JSON loading, time calculations
└── utils/

assets/
├── data/          # prayer time JSON files
└── audio/         # athan mp3 files
```

---

## Attribution & Data Sources — سەرچاوەکان و ئاماژە

- Prayer times data: Bang Kurdistan repository — https://github.com/Bang-Kurdistan
- Qur'an text used for the app's Quran section: Tanzil — https://tanzil.net/

Use of prayer times data and Qur'anic text in this project is permitted only with clear attribution to their original sources listed above. If you redistribute or reuse the data or text, include a reference to these sources.

- داتای کاتەکانی بانگ: Bang-Kurdistan — https://github.com/Bang-Kurdistan
- دەقەکانی قورئان بۆ بەشەکانی قورئان: Tanzil — https://tanzil.net/

بەکارهێنانی داتا و دەقەکان تەنها بە ئاماژەدان بە سەرچاوەکانی سەرەوە ڕێگەپێدراوە. هەر کاتێک دیتا یان دەقەکان دوبارە بەکاربهێنیت، تکایە ئەم ئاماژەیە هەبێت.

---

## Licensing & Permissions — ماف وڕێگا

This project is released under the MIT License (see the repository `LICENSE`).

Permissions and expectations:

- The app itself is free to use.
- You may use the project code without modification; if you redistribute or publish binaries, include attribution to this project and to the data sources above.
- Use of prayer times data (Bang-Kurdistan) and Qur'an text (Tanzil) must always include attribution to their respective sources.

- ئەم پرۆژەیە لە ژێر مافنامەی MIT ئازاد کراوە.
- ئەپەکە بۆ بەکارهێنەرەکان بەخۆڕاییە.
- دەتوانیت کۆدی پرۆژە بەبێ دەستکاری بەکاربهێنی؛ بەڵام هەروەها گەر داتای پرۆژە یان نەرمەکاڵاەکان دوبارە بەدابنێیت، تکایە ئاماژە بدە بە ئەسڵی پرۆژە و سەرچاوەکانی داتاکان.

---

## Disclaimer — ئاگاداری/ڕەخنە

This project is provided "as is". The authors and contributors are not responsible for any damages or losses resulting from the use of this software or from inaccurate prayer times. Users should verify critical timings from authoritative local sources when necessary.

ئەم پرۆژەیە بە "وەکە" پێشکەش دەکرێت. نووسەر و بەشداریبەران لەسەر هەر زیان یان کێشانەوەیەک کە ڕەخنە بکات بۆ بەکارهێنانی ئەم سەرچاوە یان نادروستیی کاتەکان، بەرپرسیار نییە. دەستکاریکردن یان دیاریکردنی کاتە گرنگەکان لە سەرچاوەی ناوخۆیی راستەقینە پێویستە.

---

## Contribution — بەشداریکردن

Contributions are welcome. Please open issues or pull requests on the main repository. Maintain attribution for data sources when modifying or extending data-related features.

---

## Contact — پەیوەندی

- YouTube / Author: https://www.youtube.com/@daryan111
- Repo: https://github.com/daryan-m/prayer_time

---

Thank you — سوپاس

---

**File updated:** [README_KU.md](README_KU.md)
