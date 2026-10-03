import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:tshk_core/tshk_core.dart';
import 'package:web/web.dart' as web;

import 'platform_sensor.dart';

@JS('globalThis')
external JSObject get _globalThis;

@JS()
extension type _WebkitOrientationEvent(web.DeviceOrientationEvent _)
    implements web.DeviceOrientationEvent {
  external double? get webkitCompassHeading;
}

PlatformSensorAdapter createPlatformSensor() => _WebPlatformSensor();

class _WebPlatformSensor implements PlatformSensorAdapter {
  final StreamController<PlatformHeading?> _controller =
      StreamController<PlatformHeading?>.broadcast();
  JSFunction? _absoluteListener;
  JSFunction? _regularListener;
  bool _absoluteSeen = false;
  bool _permissionGranted = false;
  bool _started = false;
  bool _secure = false;
  bool _requiresPermission = false;

  @override
  bool get isWeb => true;

  @override
  bool get isSecureContext => _secure;

  @override
  bool get permissionRequired => _requiresPermission && !_permissionGranted;

  @override
  Stream<PlatformHeading?> get headings => _controller.stream;

  @override
  Future<void> start() async {
    _secure = web.window.isSecureContext;
    _detectPermissionApi();
    if (!_secure || permissionRequired) return;
    _attachListeners();
  }

  @override
  Future<PermissionResult> requestWebSensorPermission() async {
    _secure = web.window.isSecureContext;
    if (!_secure) return PermissionResult.insecureContext;

    final JSAny? constructorValue =
        _globalThis.getProperty<JSAny?>('DeviceOrientationEvent'.toJS);
    if (constructorValue == null) return PermissionResult.unsupported;
    final JSObject constructor = constructorValue as JSObject;
    final JSAny? requestValue =
        constructor.getProperty<JSAny?>('requestPermission'.toJS);
    if (requestValue == null) {
      // Browsers without the gated iOS API need no explicit permission method.
      _permissionGranted = true;
      _requiresPermission = false;
      _attachListeners();
      return PermissionResult.granted;
    }

    _requiresPermission = true;
    try {
      final JSAny? promiseValue = (requestValue as JSFunction).callAsFunction(constructor);
      if (promiseValue == null) return PermissionResult.unsupported;
      final JSString permission =
          await (promiseValue as JSPromise<JSString>).toDart;
      if (permission.toDart == 'granted') {
        _permissionGranted = true;
        _attachListeners();
        return PermissionResult.granted;
      }
      return PermissionResult.denied;
    } catch (_) {
      return PermissionResult.denied;
    }
  }

  @override
  Future<void> stop() async {
    if (_absoluteListener != null) {
      web.window.removeEventListener('deviceorientationabsolute', _absoluteListener!);
    }
    if (_regularListener != null) {
      web.window.removeEventListener('deviceorientation', _regularListener!);
    }
    _absoluteListener = null;
    _regularListener = null;
    _absoluteSeen = false;
    _started = false;
  }

  void _detectPermissionApi() {
    final JSAny? constructorValue =
        _globalThis.getProperty<JSAny?>('DeviceOrientationEvent'.toJS);
    if (constructorValue == null) {
      _requiresPermission = false;
      return;
    }
    final JSObject constructor = constructorValue as JSObject;
    _requiresPermission =
        constructor.getProperty<JSAny?>('requestPermission'.toJS) != null;
  }

  void _attachListeners() {
    if (_started || !_secure || permissionRequired) return;
    _started = true;
    _absoluteListener = ((web.Event event) {
      _absoluteSeen = true;
      final web.DeviceOrientationEvent orientation =
          event as web.DeviceOrientationEvent;
      _process(orientation, absoluteEvent: true);
    }).toJS;
    _regularListener = ((web.Event event) {
      if (_absoluteSeen) return;
      final web.DeviceOrientationEvent orientation =
          event as web.DeviceOrientationEvent;
      _process(orientation, absoluteEvent: false);
    }).toJS;
    web.window.addEventListener('deviceorientationabsolute', _absoluteListener!);
    web.window.addEventListener('deviceorientation', _regularListener!);
  }

  void _process(web.DeviceOrientationEvent event, {required bool absoluteEvent}) {
    final _WebkitOrientationEvent extended =
        event as _WebkitOrientationEvent;
    final double? webkitHeading = extended.webkitCompassHeading;
    double? rawHeading;
    if (webkitHeading != null && webkitHeading.isFinite) {
      rawHeading = webkitHeading;
    } else if (event.absolute && event.alpha != null && event.alpha!.isFinite) {
      rawHeading = 360.0 - event.alpha!;
    } else if (absoluteEvent && event.alpha != null && event.alpha!.isFinite) {
      // The dedicated event is the absolute channel in browsers that omit the
      // boolean flag; it remains preferable to the relative orientation event.
      rawHeading = 360.0 - event.alpha!;
    }
    if (rawHeading == null || !rawHeading.isFinite) {
      _controller.add(null);
      return;
    }

    final double screenAngle = web.window.screen.orientation.angle.toDouble();
    _controller.add(PlatformHeading(
      headingDeg: normalizeDegrees(rawHeading - screenAngle),
      source: HeadingSource.webOrientation,
      reference: HeadingReference.magneticNorth,
      at: DateTime.now().toUtc(),
    ));
  }
}
