import 'package:test/test.dart';
import 'package:tshk_core/tshk_core.dart';

void main() {
  group('WMM2025 NOAA reference values', () {
    // NOAA/NCEI WMM2025_TEST_VALUES.txt. The source publishes the displayed
    // declinations to 0.01 degrees; the required acceptance tolerance is 0.1.
    const List<({double year, double altitudeKm, double lat, double lng, double d})>
        cases = <({double year, double altitudeKm, double lat, double lng, double d})>[
      (year: 2025.0, altitudeKm: 0, lat: 80, lng: 0, d: 1.28),
      (year: 2025.0, altitudeKm: 0, lat: 0, lng: 120, d: -0.16),
      (year: 2025.0, altitudeKm: 0, lat: -80, lng: 240, d: 68.78),
      (year: 2025.0, altitudeKm: 100, lat: 80, lng: 0, d: 0.85),
      (year: 2025.0, altitudeKm: 100, lat: 0, lng: 120, d: -0.15),
      (year: 2025.0, altitudeKm: 100, lat: -80, lng: 240, d: 68.21),
      (year: 2027.5, altitudeKm: 0, lat: 80, lng: 0, d: 2.59),
      (year: 2027.5, altitudeKm: 0, lat: 0, lng: 120, d: -0.24),
      (year: 2027.5, altitudeKm: 0, lat: -80, lng: 240, d: 68.49),
      (year: 2027.5, altitudeKm: 100, lat: 80, lng: 0, d: 2.16),
      (year: 2027.5, altitudeKm: 100, lat: 0, lng: 120, d: -0.23),
      (year: 2027.5, altitudeKm: 100, lat: -80, lng: 240, d: 67.93),
    ];

    for (final value in cases) {
      test('${value.year} ${value.lat},${value.lng} at ${value.altitudeKm} km', () {
        final DateTime date = value.year == 2025.0
            ? DateTime.utc(2025)
            : DateTime.utc(2027, 7, 2, 12);
        final WmmResult result = Wmm2025.declination(
          location: GeoPoint(latitude: value.lat, longitude: value.lng),
          date: date,
          altitudeKm: value.altitudeKm,
        );
        expect(result.modelName, 'WMM-2025');
        expect(result.modelExpired, isFalse);
        expect(result.declinationDeg, closeTo(value.d, 0.1));
      });
    }
  });

  test('decimal year and expiry are timezone independent', () {
    final DateTime localOffset = DateTime.parse('2025-01-01T02:00:00+02:00');
    expect(Wmm2025.decimalYear(localOffset), closeTo(2025.0, 1e-12));
    final WmmResult afterValidity = Wmm2025.declination(
      location: const GeoPoint(latitude: -29.07547, longitude: 27.62453),
      date: DateTime.utc(2030),
    );
    expect(afterValidity.modelExpired, isTrue);
    expect(afterValidity.declinationDeg.isFinite, isTrue);
  });
}
