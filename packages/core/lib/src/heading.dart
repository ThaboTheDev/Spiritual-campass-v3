import 'dart:math' as math;

enum HeadingSource { nativeMagnetometer, webOrientation, gpsCourse }

enum HeadingReference { magneticNorth, trueNorth }

enum SensorStatus {
  initialising,
  needsPermission,
  active,
  degradedToGps,
  locationDenied,
  unavailable,
}

enum PermissionResult { granted, denied, unsupported, insecureContext }

/// A normalized compass sample. GPS course is true-north referenced; sensor
/// readings are magnetic-north referenced unless the platform explicitly says
/// otherwise.
class HeadingReading {
  HeadingReading({
    required double headingDeg,
    required this.source,
    required this.at,
    this.accuracyDeg,
    this.reference = HeadingReference.magneticNorth,
    this.isStale = false,
  }) : headingDeg = normalizeDegrees(headingDeg);

  final double headingDeg;
  final HeadingSource source;
  final double? accuracyDeg;
  final DateTime at;
  final HeadingReference reference;
  final bool isStale;

  HeadingReading copyWith({
    double? headingDeg,
    HeadingSource? source,
    double? accuracyDeg,
    DateTime? at,
    HeadingReference? reference,
    bool? isStale,
  }) =>
      HeadingReading(
        headingDeg: headingDeg ?? this.headingDeg,
        source: source ?? this.source,
        accuracyDeg: accuracyDeg ?? this.accuracyDeg,
        at: at ?? this.at,
        reference: reference ?? this.reference,
        isStale: isStale ?? this.isStale,
      );
}

/// Normalizes a finite angle into the half-open range [0, 360).
double normalizeDegrees(double degrees) {
  if (!degrees.isFinite) {
    throw ArgumentError.value(degrees, 'degrees', 'Must be finite');
  }
  final double normalized = degrees % 360.0;
  return normalized < 0 ? normalized + 360.0 : normalized;
}

/// Returns the signed shortest rotation from [fromDeg] to [toDeg] in
/// [-180, 180]. The exact 180-degree tie is represented as +180.
double shortestSignedDifference(double fromDeg, double toDeg) {
  final double difference = normalizeDegrees(toDeg - fromDeg);
  return difference > 180.0 ? difference - 360.0 : difference;
}

/// Circular exponential low-pass filter. It averages unit-circle components,
/// never raw degree values, so a 359° -> 1° transition stays near north.
class CircularHeadingFilter {
  CircularHeadingFilter({this.alpha = 0.25}) {
    if (alpha <= 0 || alpha > 1 || !alpha.isFinite) {
      throw ArgumentError.value(alpha, 'alpha', 'Must be in (0, 1]');
    }
  }

  final double alpha;
  double? _x;
  double? _y;

  double add(double headingDeg) {
    final double radians = normalizeDegrees(headingDeg) * math.pi / 180.0;
    final double sampleX = math.sin(radians);
    final double sampleY = math.cos(radians);
    if (_x == null || _y == null) {
      _x = sampleX;
      _y = sampleY;
    } else {
      _x = (1 - alpha) * _x! + alpha * sampleX;
      _y = (1 - alpha) * _y! + alpha * sampleY;
    }
    return normalizeDegrees(math.atan2(_x!, _y!) * 180.0 / math.pi);
  }

  void reset() {
    _x = null;
    _y = null;
  }
}

/// Stateful four/six degree alignment hysteresis.
class AlignmentHysteresis {
  AlignmentHysteresis({
    this.enterToleranceDeg = 4.0,
    this.exitToleranceDeg = 6.0,
  }) {
    if (enterToleranceDeg < 0 || exitToleranceDeg < enterToleranceDeg) {
      throw ArgumentError('Exit tolerance must be >= enter tolerance >= 0.');
    }
  }

  final double enterToleranceDeg;
  final double exitToleranceDeg;
  bool _isAligned = false;

  bool update(double signedDifferenceDeg) {
    final double absoluteDifference = signedDifferenceDeg.abs();
    if (_isAligned) {
      if (absoluteDifference > exitToleranceDeg) _isAligned = false;
    } else if (absoluteDifference <= enterToleranceDeg) {
      _isAligned = true;
    }
    return _isAligned;
  }

  void reset() => _isAligned = false;
}
