import 'package:test/test.dart';
import 'package:tshk_core/tshk_core.dart';

void main() {
  test('heading normalization and shortest signed angle handle north wrap', () {
    expect(normalizeDegrees(-1), 359);
    expect(normalizeDegrees(721), 1);
    expect(shortestSignedDifference(359, 1), 2);
    expect(shortestSignedDifference(1, 359), -2);
  });

  test('circular smoothing does not average across zero as 180 degrees', () {
    final CircularHeadingFilter filter = CircularHeadingFilter(alpha: 0.5);
    filter.add(359);
    final double next = filter.add(1);
    expect(next < 2 || next > 358, isTrue);
  });

  test('alignment enters at four degrees and exits only past six degrees', () {
    final AlignmentHysteresis alignment = AlignmentHysteresis();
    expect(alignment.update(4), isTrue);
    expect(alignment.update(6), isTrue);
    expect(alignment.update(6.01), isFalse);
    expect(alignment.update(-4), isTrue);
  });

  test('compass state converts magnetic heading through east-positive declination', () {
    final CompassState state = CompassState.calculate(
      from: const GeoPoint(latitude: 0, longitude: 0),
      target: const GeoPoint(latitude: 0, longitude: 1),
      heading: HeadingReading(
        headingDeg: 10,
        source: HeadingSource.nativeMagnetometer,
        at: DateTime.utc(2026),
      ),
      declination: const WmmResult(
        declinationDeg: 5,
        modelExpired: false,
        modelName: 'WMM-2025',
        decimalYear: 2026,
      ),
      isAligned: false,
    );
    expect(state.trueHeadingDeg, 15);
    expect(state.trueBearingDeg, closeTo(90, 1e-9));
    expect(state.relativeNeedleAngleDeg, closeTo(75, 1e-9));
  });
}
