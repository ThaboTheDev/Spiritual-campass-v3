import 'dart:math' as math;

import 'constants.dart';

class GeoPoint {
  const GeoPoint({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  bool get isValid =>
      latitude.isFinite &&
      longitude.isFinite &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;
}

class GeoMath {
  const GeoMath._();

  /// Great-circle distance using the mean Earth radius specified by IUGG.
  static double haversineDistanceKm(GeoPoint from, GeoPoint to) {
    _validate(from, 'from');
    _validate(to, 'to');
    final double latitudeDelta = _radians(to.latitude - from.latitude);
    final double longitudeDelta = _radians(to.longitude - from.longitude);
    final double fromLatitude = _radians(from.latitude);
    final double toLatitude = _radians(to.latitude);
    final double sinLatitude = math.sin(latitudeDelta / 2);
    final double sinLongitude = math.sin(longitudeDelta / 2);
    final double a = (sinLatitude * sinLatitude) +
        math.cos(fromLatitude) *
            math.cos(toLatitude) *
            sinLongitude *
            sinLongitude;
    final double clamped = a.clamp(0.0, 1.0).toDouble();
    return 2 * kEarthMeanRadiusKm * math.atan2(math.sqrt(clamped), math.sqrt(1 - clamped));
  }

  /// Initial great-circle bearing from north, in [0, 360).
  /// Same-point and exactly antipodal cases have no unique bearing; this
  /// implementation returns 0° deterministically for both.
  static double initialBearingDeg(GeoPoint from, GeoPoint to) {
    _validate(from, 'from');
    _validate(to, 'to');
    final double distanceKm = haversineDistanceKm(from, to);
    if (distanceKm < 1e-9 ||
        (math.pi * kEarthMeanRadiusKm - distanceKm).abs() < 1e-7) {
      return 0.0;
    }
    final double fromLatitude = _radians(from.latitude);
    final double toLatitude = _radians(to.latitude);
    final double longitudeDelta = _radians(to.longitude - from.longitude);
    final double y = math.sin(longitudeDelta) * math.cos(toLatitude);
    final double x = math.cos(fromLatitude) * math.sin(toLatitude) -
        math.sin(fromLatitude) * math.cos(toLatitude) * math.cos(longitudeDelta);
    return _normalize(math.atan2(y, x) * 180.0 / math.pi);
  }

  static void _validate(GeoPoint point, String argument) {
    if (!point.isValid) {
      throw ArgumentError.value(point, argument, 'Invalid WGS-84 coordinate');
    }
  }

  static double _radians(double degrees) => degrees * math.pi / 180.0;

  static double _normalize(double degrees) {
    final double value = degrees % 360;
    return value < 0 ? value + 360 : value;
  }
}
