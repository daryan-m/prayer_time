<div align="center">

# 🕌 Bang — Prayer Times Kurdistan

**Accurate offline prayer times for cities and towns across the Kurdistan Region**

[![Flutter](https://img.shields.io/badge/Flutter-3.0%2B-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?logo=android&logoColor=white)](https://www.android.com)
[![Version](https://img.shields.io/badge/Version-1.1.14-blue)](https://github.com/daryan-m/prayer_time/releases)
[![License](https://img.shields.io/badge/License-Custom-orange)](LICENSE)

*کاتەکانی بانگ بۆ شار و شارۆچکەکانی هەرێمی کوردستان*

</div>

---

## 📥 Download

| Channel | Link |
|---------|------|
| **GitHub Releases (APK)** | [Download latest release](https://github.com/daryan-m/prayer_time/releases) |
| **Google Play** | [Get it on Google Play](https://play.google.com/store/apps/details?id=com.daryan.prayer) |
| **Video preview** | [YouTube — @daryan111](https://www.youtube.com/@daryan111) |

> **Note:** The app is currently optimized for **Android**. Other platforms exist in the Flutter project but are not the primary target.

---

## 📖 About

**Bang** is a lightweight Flutter application built for Muslims in the Kurdistan Region. It displays daily prayer (adhan) times for **35 cities and towns**, works fully **offline**, and includes Islamic tools such as a Holy Qur'an reader, the 99 Names of Allah, a digital tasbih, and a multi-calendar date converter.

The app is designed with a dark, modern UI, supports multiple color themes, local notifications with selectable athan sounds, and an Android home-screen widget.

---

## ✨ Features

| Feature | Description |
|---------|-------------|
| 🕐 **Prayer times** | Fajr, Sunrise, Dhuhr, Asr, Maghrib, and Isha for 35 Kurdistan cities |
| 📴 **Offline data** | Prayer schedules loaded from bundled JSON files — no internet required |
| 📅 **Calendars** | Gregorian, Hijri, Kurdish, and Solar (Kurdish year +625 offset) |
| 🔔 **Notifications** | Scheduled adhan alerts with exact-alarm support on Android |
| 🔊 **Athan sounds** | Three selectable adhan voices (Makkah, Madinah, Kuwait) |
| 📖 **Holy Qur'an** | Full mushaf reader with page navigation, surah/juz/hizb lookup |
| 🎧 **Qur'an audio** | Online streaming and offline download with word highlighting |
| ☪️ **99 Names of Allah** | Arabic names with Kurdish meanings and audio |
| 📿 **Tasbih** | Digital counter with sound feedback |
| 🗓️ **Date converter** | Convert dates and find prayer times by date |
| 🎨 **Themes** | Six color palettes |
| 📱 **Home widget** | Android widget showing today's prayer schedule |
| 🔄 **OTA updates** | Checks for new APK releases every 24 hours |

---

## 🏙️ Supported cities

The app includes prayer data for **35 locations**, including:

> هەولێر · سلێمانی · دهۆک · کەرکووک · هەڵەبجە · کەلار · ڕانیە · کۆیە · سۆران · زاخۆ · خانەقین · چەمچەماڵ · پێنجوێن · سیدصادق · دەربەندیخان · کفری · قەڵادزێ · قەرەداغ · قەسرێ · قادرکەرەم · چوارتا · بازیان · بەرزنجە · عەربەت · ئاکرێ · ئامێدی · پیرەمەگرون · تەکیە · تەق تەق · تاسڵوجە · دوزخورماتو · دوکان · حاجیاوا · خەلەکان · هەڵەبجەی تازە

Data files are stored in [`assets/data/`](assets/data/).

---

## 🛠️ Build from source

### Requirements

- [Flutter](https://docs.flutter.dev/get-started/install) **3.0+**
- Android SDK (for Android builds)
- Java **21** (used in CI)

### Steps

```bash
git clone https://github.com/daryan-m/prayer_time.git
cd prayer_time
flutter pub get
flutter run
```

### Release builds

```bash
# APK
flutter build apk --release

# App Bundle (Google Play)
flutter build appbundle --release
```

### Athan audio assets

Ensure these files exist under `assets/audio/`:

```
assets/audio/
├── macca.mp3
├── madina.mp3
└── kwait.mp3
```

---

## 📂 Project structure

```text
lib/
├── main.dart                 # App entry & notification channels
├── screens/                  # Main UI screens
├── widgets/                  # Reusable UI components
├── services/                 # Prayer data, widgets, database logic
├── quran/                    # Qur'an reader, audio, and database
└── utils/                    # Constants, permissions, helpers

assets/
├── data/                     # Prayer time JSON (35 cities)
├── audio/                    # Athan & Allah Names audio
├── quran/                    # Qur'an SQLite databases & fonts
└── images/                   # App icons & graphics

android/
└── app/src/main/kotlin/com/daryan/prayer/
    ├── AthanService.kt       # Foreground athan playback
    ├── PrayerWidgetProvider.kt
    └── ...
```

---

## 📚 Data sources & attribution

> **Important:** The prayer schedules, Qur'an text/page layout, and Qur'an recitation audio used in this app are **not original works of the project owner, concept author, or developer**. They were obtained from third-party sources and are included for convenience inside the application.

If you reuse, redistribute, or republish **any of this data**, you **must** credit the original sources listed below.

| Data | Source | Link |
|------|--------|------|
| **Prayer times** | Bang Kurdistan | [github.com/Bang-Kurdistan](https://github.com/Bang-Kurdistan) |
| **Qur'an page & text layout** | QUL (Tarteel AI resources) | [qul.tarteel.ai/resources](https://qul.tarteel.ai/resources/) |
| **Qur'an recitation audio** | EveryAyah | [everyayah.com](https://everyayah.com/) |

Additional notes:

- Prayer JSON files in `assets/data/` are derived from the **Bang Kurdistan** project (see also [`assets/data/README.md`](assets/data/README.md)).
- Qur'an SQLite databases (`qpc-v2*.db`, metadata) come from **QUL / Tarteel AI** resources.
- Streaming and downloadable recitations are fetched from **EveryAyah.com**.
- Athan notification sounds and 99 Names audio bundled in `assets/audio/` are included as application media assets.

**Attribution is mandatory** when reusing prayer data, Qur'an text/layout data, or Qur'an audio outside this app.

---

## ⚠️ Disclaimer

This software and all included data are provided **"as is"**, without warranty of any kind.

- The **project owner, concept author, and developer** are **not responsible** for any errors, omissions, or inaccuracies in prayer times, Qur'an text, recitation timing, or any other bundled data.
- They are **not liable** for any direct or indirect loss, damage, or harm arising from the use of this application or project — including missed prayers, incorrect schedules, or device/battery issues related to alarms and notifications.
- Users should **verify critical prayer times** with local mosques or official religious authorities when accuracy is essential.

---

## 📄 License

This project is **not** released under the MIT License.

- The **application source code** is licensed under the terms in [`LICENSE`](LICENSE).
- **Third-party data** (prayer times, Qur'an text/layout, Qur'an audio) remains subject to the terms and attribution requirements of the original sources above.

The authoritative legal text is in [`LICENSE`](LICENSE) (English).

---

## 👥 Credits

| Role | Name |
|------|------|
| **Concept** | Daryan_M |
| **Developer** | M_R_M |

---

## 🤝 Contributing

Issues and pull requests are welcome on the main repository. When modifying data-related features, please preserve attribution to the original data sources.

---

## 📬 Contact

| Platform | Link |
|----------|------|
| **GitHub** | [daryan-m/prayer_time](https://github.com/daryan-m/prayer_time) |
| **YouTube** | [@daryan111](https://www.youtube.com/@daryan111) |
| **Instagram** | [@prayer_time_ku](https://www.instagram.com/prayer_time_ku/) |
| **Facebook** | [Prayer Time KU](https://www.facebook.com/profile.php?id=61590536199169) |

---

<div align="center">

**Made with ❤️ for the Kurdistan Region**

</div>
