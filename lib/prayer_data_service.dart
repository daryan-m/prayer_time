
import 'package:adhan/adhan.dart';

class City {
  final String name;
  final double lat;
  final double lng;

  City(this.name, this.lat, this.lng);
}

// A list of cities in Kurdistan with their coordinates
final List<City> kurdistanCitiesData = [
  City("سلێمانی", 35.56, 45.43),
  City("هەولێر", 36.19, 44.00),
  City("دهۆک", 36.86, 42.99),
  City("کەرکوک", 35.46, 44.39),
  City("هەڵەبجە", 35.18, 45.98),
  City("پێنجوێن", 35.62, 45.98),
  City("رانیە", 36.25, 44.88),
  City("کەلار", 34.63, 45.32),
  City("سەیدسادق", 35.35, 45.87),
];

class PrayerDataService {
  PrayerTimes getPrayerTimes(String cityName, DateTime date) {
    // Default to the first city in the list if the city name is not found
    final city = kurdistanCitiesData.firstWhere((c) => c.name == cityName,
        orElse: () => kurdistanCitiesData.first);

    final coordinates = Coordinates(city.lat, city.lng);

    // Calculation parameters - Muslim World League is a common standard.
    // These parameters are widely used and should be very close to official times.
    final params = CalculationMethod.muslim_world_league.getParameters();
    params.madhab = Madhab.shafi; // Most Kurds are Shafi'i, so Asr is later.

    final prayerTimes = PrayerTimes(
      coordinates,
      DateComponents.from(date),
      params,
    );

    return prayerTimes;
  }
}
