import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tshk_compass_app/src/location/location_models.dart';
import 'package:tshk_compass_app/src/location/location_service.dart';
import 'package:tshk_compass_app/src/sensors/platform_sensor.dart';
import 'package:tshk_compass_app/src/sensors/sensor_service.dart';
import 'package:tshk_core/tshk_core.dart';

class _FakePlatform implements PlatformSensorAdapter {
  final StreamController<PlatformHeading?> controller =
      StreamController<PlatformHeading?>.broadcast();
  int starts = 0;
  int stops = 0;
  PermissionResult permissionResult = PermissionResult.granted;
  void Function()? onStart;

  @override
  bool isWeb = false;

  @override
  bool isSecureContext = true;

  @override
  bool permissionRequired = false;

  @override
  Stream<PlatformHeading?> get headings => controller.stream;

  @override
  Future<void> start() async {
    starts++;
    onStart?.call();
  }

  @override
  Future<void> stop() async => stops++;

  @override
  Future<PermissionResult> requestWebSensorPermission() async => permissionResult;

  Future<void> close() => controller.close();
}

class _FakeLocationService extends LocationService {
  final StreamController<LocationFix> controller =
      StreamController<LocationFix>.broadcast();
  int starts = 0;
  int permissionPrompts = 0;
  LocationStatus result = LocationStatus.active;

  @override
  Stream<LocationFix> get fixes => controller.stream;

  @override
  Future<LocationStatus> requestWhileInUseAndStart({
    bool requestPermission = true,
  }) async {
    starts++;
    if (requestPermission) permissionPrompts++;
    return result;
  }

  @override
  Future<void> stop() async {}

  Future<void> close() => controller.close();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakePlatform platform;
  late _FakeLocationService location;
  late SensorService service;
  final List<HeadingReading> readings = <HeadingReading>[];
  StreamSubscription<HeadingReading>? readingSubscription;

  setUp(() {
    platform = _FakePlatform();
    location = _FakeLocationService();
    service = SensorService(
      platform: platform,
      locationService: location,
      firstHeadingTimeout: const Duration(milliseconds: 100),
      invalidZeroDuration: const Duration(milliseconds: 50),
      staleAfter: const Duration(milliseconds: 100),
      reprobeInterval: const Duration(seconds: 10),
    );
    readingSubscription = service.readings.listen(readings.add);
  });

  tearDown(() async {
    await readingSubscription?.cancel();
    await service.dispose();
    await platform.close();
    await location.close();
    readings.clear();
  });

  test('uses the native heading stream and preserves north wrap with circular smoothing', () async {
    await service.start();
    platform.controller.add(PlatformHeading(
      headingDeg: 359,
      source: HeadingSource.nativeMagnetometer,
      reference: HeadingReference.magneticNorth,
    ));
    await Future<void>.delayed(const Duration(milliseconds: 40));
    platform.controller.add(PlatformHeading(
      headingDeg: 1,
      source: HeadingSource.nativeMagnetometer,
      reference: HeadingReference.magneticNorth,
    ));
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(readings, hasLength(2));
    expect(readings.last.headingDeg < 5 || readings.last.headingDeg > 355, isTrue);
    expect(service.status, SensorStatus.active);
    expect(location.starts, 0);
  });

  test('three empty sensor events switch to while-in-use GPS fallback', () async {
    await service.start();
    platform.controller
      ..add(null)
      ..add(null)
      ..add(null);
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(service.status, SensorStatus.degradedToGps);
    expect(platform.stops, 1);
    expect(location.starts, 1);
  });

  test('missing first heading triggers GPS fallback and denied permission is explicit', () async {
    location.result = LocationStatus.denied;
    await service.start();
    await Future<void>.delayed(const Duration(milliseconds: 140));

    expect(location.starts, 1);
    expect(service.status, SensorStatus.locationDenied);
  });

  test('resume restarts GPS fallback without requesting location permission again', () async {
    await service.start();
    await Future<void>.delayed(const Duration(milliseconds: 140));
    expect(location.permissionPrompts, 1);

    await service.pause();
    await service.resume();

    expect(location.starts, 2);
    expect(location.permissionPrompts, 1);
  });

  test('stuck zero heading falls back after the invalid interval', () async {
    await service.start();
    platform.controller.add(PlatformHeading(
      headingDeg: 0,
      source: HeadingSource.nativeMagnetometer,
      reference: HeadingReference.magneticNorth,
    ));
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(service.status, SensorStatus.degradedToGps);
    expect(location.starts, 1);
  });

  test('GPS course is true-north referenced and stale readings are marked', () async {
    await service.start();
    await Future<void>.delayed(const Duration(milliseconds: 140));
    location.controller.add(LocationFix(
      point: const GeoPoint(latitude: -29.0, longitude: 27.0),
      accuracyMeters: 5,
      speedMetersPerSecond: 2,
      headingDeg: 87,
      headingAccuracyDeg: 4,
      at: DateTime.now().toUtc(),
    ));
    await Future<void>.delayed(const Duration(milliseconds: 5));

    expect(readings.last.source, HeadingSource.gpsCourse);
    expect(readings.last.reference, HeadingReference.trueNorth);
    await Future<void>.delayed(const Duration(milliseconds: 130));
    expect(readings.last.isStale, isTrue);
  });

  test('ignores GPS course after the native heading stream recovers', () async {
    await readingSubscription?.cancel();
    await service.dispose();
    await platform.close();
    await location.close();

    platform = _FakePlatform();
    location = _FakeLocationService();
    service = SensorService(
      platform: platform,
      locationService: location,
      firstHeadingTimeout: const Duration(milliseconds: 10),
      reprobeInterval: const Duration(milliseconds: 80),
    );
    readingSubscription = service.readings.listen(readings.add);

    await service.start();
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(service.status, SensorStatus.degradedToGps);

    platform.onStart = () {
      platform.controller.add(PlatformHeading(
        headingDeg: 90,
        source: HeadingSource.nativeMagnetometer,
        reference: HeadingReference.magneticNorth,
      ));
    };
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(service.status, SensorStatus.active);

    location.controller.add(LocationFix(
      point: const GeoPoint(latitude: -29.0, longitude: 27.0),
      accuracyMeters: 5,
      speedMetersPerSecond: 2,
      headingDeg: 180,
      headingAccuracyDeg: 4,
      at: DateTime.now().toUtc(),
    ));
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(readings.any((HeadingReading value) =>
        value.source == HeadingSource.nativeMagnetometer), isTrue);
    expect(readings.any((HeadingReading value) =>
        value.source == HeadingSource.gpsCourse), isFalse);
  });

  test('web permission is requested through the platform adapter', () async {
    platform
      ..isWeb = true
      ..permissionRequired = true;
    await service.start();
    expect(service.status, SensorStatus.needsPermission);

    final PermissionResult result = await service.requestWebSensorPermission();
    expect(result, PermissionResult.granted);
  });
}
