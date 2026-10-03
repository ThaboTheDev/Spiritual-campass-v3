import 'constants.dart';
import 'geo_math.dart';
import 'heading.dart';
import 'wmm2025.dart';

class CompassState {
  const CompassState({
    required this.trueBearingDeg,
    required this.magneticBearingDeg,
    required this.distanceKm,
    required this.declinationDeg,
    required this.relativeNeedleAngleDeg,
    required this.isAligned,
    required this.trueHeadingDeg,
    required this.modelExpired,
    required this.headingSource,
  });

  final double trueBearingDeg;
  final double magneticBearingDeg;
  final double distanceKm;
  final double declinationDeg;
  final double relativeNeedleAngleDeg;
  final bool isAligned;
  final double trueHeadingDeg;
  final bool modelExpired;
  final HeadingSource headingSource;

  static CompassState calculate({
    required GeoPoint from,
    required GeoPoint target,
    required HeadingReading heading,
    required WmmResult declination,
    required bool isAligned,
  }) {
    final double trueBearing = GeoMath.initialBearingDeg(from, target);
    final double trueHeading = heading.reference == HeadingReference.trueNorth
        ? heading.headingDeg
        : _normalize(heading.headingDeg + declination.declinationDeg);
    return CompassState(
      trueBearingDeg: trueBearing,
      magneticBearingDeg: _normalize(trueBearing - declination.declinationDeg),
      distanceKm: GeoMath.haversineDistanceKm(from, target),
      declinationDeg: declination.declinationDeg,
      relativeNeedleAngleDeg: _shortestDifference(trueHeading, trueBearing),
      isAligned: isAligned,
      trueHeadingDeg: trueHeading,
      modelExpired: declination.modelExpired,
      headingSource: heading.source,
    );
  }

  static double _normalize(double value) {
    final double result = value % 360.0;
    return result < 0 ? result + 360.0 : result;
  }

  static double _shortestDifference(double from, double to) {
    final double difference = _normalize(to - from);
    return difference > 180 ? difference - 360 : difference;
  }
}

/// Re-exported product tolerance for clients that need the same threshold.
const double compassAlignmentToleranceDeg = kAlignmentToleranceDeg;
