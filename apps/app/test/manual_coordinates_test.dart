import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tshk_compass_app/src/compass/compass_controller.dart';
import 'package:tshk_compass_app/src/location/location_models.dart';
import 'package:tshk_compass_app/src/location/location_service.dart';
import 'package:tshk_compass_app/src/sensors/platform_sensor.dart';
import 'package:tshk_compass_app/src/sensors/sensor_service.dart';
import 'package:tshk_core/tshk_core.dart';

class _FakePlatform implements PlatformSensorAdapter {
  final StreamController<PlatformHeading?> controller =
      StreamController<PlatformHeading?>.broadcast();

  @override
  bool get isWeb => false;

  @override
  bool get isSecureContext => true;

  @override
  bool get permissionRequired => false;

  @override
  Stream<PlatformHeading?> get headings => controller.stream;

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<PermissionResult> requestWebSensorPermission() async =>
      PermissionResult.unsupported;
}

class _FakeLocationService extends LocationService {
  @override
  Stream<LocationFix> get fixes => const Stream<LocationFix>.empty();

  @override
  Future<LocationStatus> requestWhileInUseAndStart({bool requestPermission = true}) async => LocationStatus.active;

  @override
  Future<void> stop() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('manual coordinate fallback validates and persists only locally', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final _FakePlatform platform = _FakePlatform();
    final SensorService sensor = SensorService(
      platform: platform,
      locationService: _FakeLocationService(),
      firstHeadingTimeout: const Duration(hours: 1),
    );
    final CompassController controller = CompassController(
      sensorService: sensor,
      locationService: _FakeLocationService(),
    );

    expect(await controller.setManualCoordinates('-29.07547', '27.62453'), isTrue);
    expect(controller.currentPoint?.latitude, -29.07547);
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    expect(preferences.getDouble('manual_latitude_v1'), -29.07547);
    expect(preferences.getDouble('manual_longitude_v1'), 27.62453);

    expect(await controller.setManualCoordinates('91', '27'), isFalse);
    expect(controller.currentPoint?.latitude, -29.07547);
    await controller.clearManualCoordinates();
    expect(controller.currentPoint, isNull);
    expect(preferences.getDouble('manual_latitude_v1'), isNull);

    controller.dispose();
    await sensor.dispose();
    await platform.controller.close();
  });
}
