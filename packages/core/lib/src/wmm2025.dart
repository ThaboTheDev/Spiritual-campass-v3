import 'dart:math' as math;

import 'geo_math.dart';
import 'wmm2025_coefficients.dart';

const double _epoch = 2025.0;
const double _earthReferenceRadiusKm = 6371.2;
const double _wgs84SemiMajorKm = 6378.137;
const double _wgs84SemiMinorKm = 6356.7523142;
const int _maximumDegree = 12;

class WmmResult {
  const WmmResult({
    required this.declinationDeg,
    required this.modelExpired,
    required this.modelName,
    required this.decimalYear,
  });

  final double declinationDeg;
  final bool modelExpired;
  final String modelName;
  final double decimalYear;
}

/// Pure-Dart implementation of the WMM2025 degree/order-12 spherical harmonic
/// model with geodetic-to-geocentric coordinate conversion and secular change.
class Wmm2025 {
  const Wmm2025._();

  static const String modelName = 'WMM-2025';
  static const double validFrom = 2025.0;
  static const double validUntilExclusive = 2030.0;

  static WmmResult declination({
    required GeoPoint location,
    DateTime? date,
    double altitudeKm = 0.0,
  }) {
    if (!location.isValid) {
      throw ArgumentError.value(location, 'location', 'Invalid WGS-84 coordinate');
    }
    if (!altitudeKm.isFinite || altitudeKm < -1 || altitudeKm > 850) {
      throw ArgumentError.value(altitudeKm, 'altitudeKm', 'Expected -1 to 850 km');
    }

    final DateTime utcDate = (date ?? DateTime.now()).toUtc();
    final double year = decimalYear(utcDate);
    final double timeSinceEpoch = year - _epoch;
    final _Field field = _evaluateField(
      latitudeDeg: location.latitude,
      longitudeDeg: location.longitude,
      altitudeKm: altitudeKm,
      timeSinceEpoch: timeSinceEpoch,
    );
    final double declination = math.atan2(field.east, field.north) * 180.0 / math.pi;
    return WmmResult(
      declinationDeg: declination,
      modelExpired: year < validFrom || year >= validUntilExclusive,
      modelName: modelName,
      decimalYear: year,
    );
  }

  /// Fractional Gregorian year calculated in UTC, independent of local time
  /// zones and daylight-saving transitions.
  static double decimalYear(DateTime value) {
    final DateTime utc = value.toUtc();
    final DateTime start = DateTime.utc(utc.year);
    final DateTime end = DateTime.utc(utc.year + 1);
    final double fraction =
        utc.difference(start).inMicroseconds / end.difference(start).inMicroseconds;
    return utc.year + fraction;
  }

  static _Field _evaluateField({
    required double latitudeDeg,
    required double longitudeDeg,
    required double altitudeKm,
    required double timeSinceEpoch,
  }) {
    final double latitude = latitudeDeg * math.pi / 180.0;
    final double longitude = longitudeDeg * math.pi / 180.0;
    final double sinLatitude = math.sin(latitude);
    final double cosLatitude = math.cos(latitude);

    // Geodetic WGS-84 position to geocentric spherical coordinates.
    final double eccentricitySquared =
        1 - (_wgs84SemiMinorKm * _wgs84SemiMinorKm) /
            (_wgs84SemiMajorKm * _wgs84SemiMajorKm);
    final double primeVerticalRadius = _wgs84SemiMajorKm /
        math.sqrt(1 - eccentricitySquared * sinLatitude * sinLatitude);
    final double x = (primeVerticalRadius + altitudeKm) * cosLatitude;
    final double z =
        (primeVerticalRadius * (1 - eccentricitySquared) + altitudeKm) * sinLatitude;
    final double radius = math.sqrt(x * x + z * z);
    final double geocentricLatitude = math.atan2(z, x);
    final double colatitude = math.pi / 2 - geocentricLatitude;
    final double sinColatitude = math.sin(colatitude);
    final double cosColatitude = math.cos(colatitude);
    final double rotation = latitude - geocentricLatitude;
    final double cosRotation = math.cos(rotation);
    final double sinRotation = math.sin(rotation);
    final double safeSinColatitude = math.max(sinColatitude.abs(), 1e-12);

    final List<List<double>> legendre = List<List<double>>.generate(
      _maximumDegree + 1,
      (_) => List<double>.filled(_maximumDegree + 1, 0),
    );
    legendre[0][0] = 1;

    for (int n = 1; n <= _maximumDegree; n++) {
      for (int m = 0; m <= n; m++) {
        if (m == n) {
          // Schmidt quasi-normalization has a special degree-one base term:
          // P(1,1) = sin(theta), with no sqrt(1/2) factor.
          final double diagonalScale = n == 1
              ? 1.0
              : math.sqrt((2 * n - 1) / (2 * n));
          legendre[n][m] = sinColatitude * diagonalScale * legendre[n - 1][m - 1];
        } else if (n == 1 && m == 0) {
          legendre[n][m] = cosColatitude;
        } else if (m == n - 1) {
          legendre[n][m] = math.sqrt(2 * n - 1) *
              cosColatitude *
              legendre[n - 1][m];
        } else {
          final double nMinusM = (n - m).toDouble();
          final double nPlusM = (n + m).toDouble();
          final double a = (2 * n - 1) / math.sqrt(nMinusM * nPlusM);
          final double b = math.sqrt(
            ((n + m - 1) * (n - m - 1)) / (nPlusM * nMinusM),
          );
          legendre[n][m] = a * cosColatitude * legendre[n - 1][m] -
              b * legendre[n - 2][m];
        }
      }
    }

    final List<double> cosLongitude = List<double>.filled(_maximumDegree + 1, 0);
    final List<double> sinLongitude = List<double>.filled(_maximumDegree + 1, 0);
    for (int m = 0; m <= _maximumDegree; m++) {
      cosLongitude[m] = math.cos(m * longitude);
      sinLongitude[m] = math.sin(m * longitude);
    }

    final double radiusRatio = _earthReferenceRadiusKm / radius;
    double northSpherical = 0;
    double eastSpherical = 0;
    double radial = 0;

    for (final List<double> coefficient in wmm2025Coefficients) {
      final int n = coefficient[0].toInt();
      final int m = coefficient[1].toInt();
      final double g = coefficient[2] + timeSinceEpoch * coefficient[4];
      final double h = coefficient[3] + timeSinceEpoch * coefficient[5];
      final double term = g * cosLongitude[m] + h * sinLongitude[m];
      final double eastTerm = g * sinLongitude[m] - h * cosLongitude[m];
      final double p = legendre[n][m];
      final double previousP = m <= n - 1 ? legendre[n - 1][m] : 0;
      final double normRatio = math.sqrt((n - m) / (n + m));
      final double derivative =
          (n * cosColatitude * p - (n + m) * normRatio * previousP) /
              safeSinColatitude;
      final double radialPower = math.pow(radiusRatio, n + 2).toDouble();

      // B_theta is positive toward the geocentric south; radial is positive
      // outward. These signs follow the NOAA WMM field-component convention.
      northSpherical -= radialPower * term * derivative;
      radial += (n + 1) * radialPower * term * p;
      if (m != 0) {
        eastSpherical += m * radialPower * eastTerm * p / safeSinColatitude;
      }
    }

    // Rotate from geocentric to geodetic north/east/down components.
    final double north =
        -northSpherical * cosRotation - radial * sinRotation;
    final double east = eastSpherical;
    final double down = northSpherical * sinRotation - radial * cosRotation;
    if (!north.isFinite || !east.isFinite || !down.isFinite) {
      throw StateError('WMM2025 produced a non-finite magnetic field');
    }
    return _Field(north: north, east: east, down: down);
  }
}

class _Field {
  const _Field({required this.north, required this.east, required this.down});

  final double north;
  final double east;
  final double down;
}
