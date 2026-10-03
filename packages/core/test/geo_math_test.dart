import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:tshk_core/tshk_core.dart';

void main() {
  group('GeoMath', () {
    test('same-point distance and bearing have deterministic results', () {
      const GeoPoint point = GeoPoint(latitude: -29.0, longitude: 27.0);
      expect(GeoMath.haversineDistanceKm(point, point), closeTo(0, 1e-10));
      expect(GeoMath.initialBearingDeg(point, point), 0);
    });

    test('antipodal distance is half the great-circle circumference', () {
      const GeoPoint origin = GeoPoint(latitude: 0, longitude: 0);
      const GeoPoint opposite = GeoPoint(latitude: 0, longitude: 180);
      expect(
        GeoMath.haversineDistanceKm(origin, opposite),
        closeTo(math.pi * 6371.0088, 1e-8),
      );
      expect(GeoMath.initialBearingDeg(origin, opposite), 0);
    });

    test('one equatorial degree is approximately 111.195 kilometres', () {
      const GeoPoint west = GeoPoint(latitude: 0, longitude: 0);
      const GeoPoint east = GeoPoint(latitude: 0, longitude: 1);
      expect(GeoMath.haversineDistanceKm(west, east), closeTo(111.195, 0.002));
      expect(GeoMath.initialBearingDeg(west, east), closeTo(90, 1e-10));
    });

    test('invalid coordinates are rejected', () {
      const GeoPoint invalid = GeoPoint(latitude: 91, longitude: 0);
      expect(() => GeoMath.haversineDistanceKm(invalid, invalid), throwsArgumentError);
    });
  });

  group('heading math', () {
    test('normalizes negative and wrapped angles', () {
      expect(normalizeDegrees(-1), 359);
      expect(normalizeDegrees(721), 1);
      expect(shortestSignedDifference(359, 1), 2);
      expect(shortestSignedDifference(1, 359), -2);
    });

    test('circular low-pass filtering handles 359 to 1 degrees', () {
      final CircularHeadingFilter filter = CircularHeadingFilter(alpha: 0.5);
      expect(filter.add(359), closeTo(359, 1e-10));
      final double result = filter.add(1);
      expect(result < 1 || result > 359, isTrue);
    });

    test('alignment uses four degree entry and six degree exit hysteresis', () {
      final AlignmentHysteresis alignment = AlignmentHysteresis();
      expect(alignment.update(4), isTrue);
      expect(alignment.update(5.9), isTrue);
      expect(alignment.update(6), isTrue);
      expect(alignment.update(6.01), isFalse);
      expect(alignment.update(-4.01), isFalse);
      expect(alignment.update(-4), isTrue);
    });

    test('magnetic heading is corrected; GPS true course is not corrected', () {
      final WmmResult declination = WmmResult(
        declinationDeg: 12,
        modelExpired: false,
        modelName: 'test',
        decimalYear: 2026,
      );
      const GeoPoint point = GeoPoint(latitude: 0, longitude: 0);
      const GeoPoint target = GeoPoint(latitude: 0, longitude: 1);
      final CompassState magnetic = CompassState.calculate(
        from: point,
        target: target,
        heading: HeadingReading(
          headingDeg: 78,
          source: HeadingSource.nativeMagnetometer,
          at: DateTime.utc(2026),
        ),
        declination: declination,
        isAligned: false,
      );
      expect(magnetic.trueHeadingDeg, closeTo(90, 1e-12));
      expect(magnetic.relativeNeedleAngleDeg, closeTo(0, 1e-12));
      expect(magnetic.magneticBearingDeg, closeTo(78, 1e-12));

      final CompassState gps = CompassState.calculate(
        from: point,
        target: target,
        heading: HeadingReading(
          headingDeg: 90,
          source: HeadingSource.gpsCourse,
          reference: HeadingReference.trueNorth,
          at: DateTime.utc(2026),
        ),
        declination: declination,
        isAligned: true,
      );
      expect(gps.trueHeadingDeg, closeTo(90, 1e-12));
      expect(gps.isAligned, isTrue);
    });
  });
}
