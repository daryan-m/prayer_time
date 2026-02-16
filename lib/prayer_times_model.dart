class PrayerTimesModel {
  final String fajr;
  final String sunrise;
  final String dhuhr;
  final String asr;
  final String maghrib;
  final String isha;

  const PrayerTimesModel({
    required this.fajr,
    required this.sunrise,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
  });

  List<String> toSixTimesList() => [fajr, sunrise, dhuhr, asr, maghrib, isha];

  static PrayerTimesModel fromSixTimes(List<String> list) {
    if (list.length < 6) {
      return const PrayerTimesModel(
        fajr: "--:--",
        sunrise: "--:--",
        dhuhr: "--:--",
        asr: "--:--",
        maghrib: "--:--",
        isha: "--:--",
      );
    }

    return PrayerTimesModel(
      fajr: list[0],
      sunrise: list[1],
      dhuhr: list[2],
      asr: list[3],
      maghrib: list[4],
      isha: list[5],
    );
  }
}
