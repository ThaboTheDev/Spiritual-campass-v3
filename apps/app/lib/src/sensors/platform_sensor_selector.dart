import 'platform_sensor.dart';
import 'platform_sensor_stub.dart'
    if (dart.library.io) 'platform_sensor_native.dart'
    if (dart.library.js_interop) 'platform_sensor_web.dart' as implementation;

PlatformSensorAdapter createPlatformSensor() => implementation.createPlatformSensor();
