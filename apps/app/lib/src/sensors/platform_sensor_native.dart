import 'dart:async';

import 'package:flutter_compass/flutter_compass.dart';
import 'package:native_device_orientation/native_device_orientation.dart';
import 'package:tshk_core/tshk_core.dart';

import 'platform_sensor.dart';

PlatformSensorAdapter createPlatformSensor() => _NativePlatformSensor();

class _NativePlatformSensor implements PlatformSensorAdapter {
  final StreamController<PlatformHeading?> _controller =
      StreamController<PlatformHeading?>.broadcast();
  final NativeDeviceOrientationCommunicator _orientationCommunicator =
      NativeDeviceOrientationCommunicator();
  StreamSubscription<CompassEvent?>? _compassSubscription;
  StreamSubscription<NativeDeviceOrientation>? _orientationSubscription;
  int _screenRotationDegrees = 0;

  @override
  bool get isWeb => false;

  @override
  bool get isSecureContext => true;

  @override
  bool get permissionRequired => false;

  @override
  Stream<PlatformHeading?> get headings => _controller.stream;

  @override
  Future<void> start() async {
    if (_compassSubscription != null) return;
    _orientationSubscription ??= _orientationCommunicator
        .onOrientationChanged(useSensor: true)
        .listen((NativeDeviceOrientation orientation) {
      _screenRotationDegrees = _rotationFor(orientation);
    }, onError: (Object error, StackTrace stackTrace) {});

    final Stream<CompassEvent?>? events = FlutterCompass.events;
    if (events == null) {
      _controller.addError(UnsupportedError('No magnetometer stream is available.'));
      return;
    }
    _compassSubscription = events.listen(
      (CompassEvent? event) {
        if (event == null || event.heading == null || !event.heading!.isFinite) {
          _controller.add(null);
          return;
        }
        final double adjusted = event.heading! - _screenRotationDegrees;
        _controller.add(PlatformHeading(
          headingDeg: normalizeDegrees(adjusted),
          source: HeadingSource.nativeMagnetometer,
          reference: HeadingReference.magneticNorth,
          accuracyDeg: event.accuracy,
          at: DateTime.now().toUtc(),
        ));
      },
      onError: (Object error, StackTrace stackTrace) => _controller.addError(error, stackTrace),
    );
  }

  @override
  Future<void> stop() async {
    await _compassSubscription?.cancel();
    await _orientationSubscription?.cancel();
    _compassSubscription = null;
    _orientationSubscription = null;
  }

  @override
  Future<PermissionResult> requestWebSensorPermission() async =>
      PermissionResult.unsupported;

  static int _rotationFor(NativeDeviceOrientation orientation) => switch (orientation) {
        NativeDeviceOrientation.landscapeLeft => 90,
        NativeDeviceOrientation.landscapeRight => -90,
        NativeDeviceOrientation.portraitDown => 180,
        NativeDeviceOrientation.portraitUp || NativeDeviceOrientation.unknown => 0,
      };
}
