import 'package:tshk_core/tshk_core.dart';

enum LocationStatus {
  unknown,
  permissionRequired,
  denied,
  permanentlyDenied,
  servicesDisabled,
  lowAccuracy,
  active,
  unavailable,
}

class LocationFix {
  const LocationFix({
    required this.point,
    required this.accuracyMeters,
    required this.speedMetersPerSecond,
    required this.headingDeg,
    required this.headingAccuracyDeg,
    required this.at,
  });

  final GeoPoint point;
  final double accuracyMeters;
  final double speedMetersPerSecond;
  final double headingDeg;
  final double headingAccuracyDeg;
  final DateTime at;
}

class LocationSnapshot {
  const LocationSnapshot({
    required this.status,
    this.fix,
    this.message,
  });

  final LocationStatus status;
  final LocationFix? fix;
  final String? message;

  LocationSnapshot copyWith({
    LocationStatus? status,
    LocationFix? fix,
    String? message,
  }) =>
      LocationSnapshot(
        status: status ?? this.status,
        fix: fix ?? this.fix,
        message: message ?? this.message,
      );
}
