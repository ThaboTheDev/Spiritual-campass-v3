import 'dart:async';

import 'package:tshk_core/tshk_core.dart';

import 'platform_sensor.dart';

PlatformSensorAdapter createPlatformSensor() => _StubPlatformSensor();

class _StubPlatformSensor implements PlatformSensorAdapter {
  @override
  bool get isWeb => false;

  @override
  bool get isSecureContext => true;

  @override
  bool get permissionRequired => false;

  @override
  Stream<PlatformHeading?> get headings => const Stream<PlatformHeading?>.empty();

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<PermissionResult> requestWebSensorPermission() async =>
      PermissionResult.unsupported;
}
