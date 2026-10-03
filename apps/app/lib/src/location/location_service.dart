import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:tshk_core/tshk_core.dart';

import 'location_models.dart';

class LocationService {
  LocationService({this.lowAccuracyThresholdMeters = 100});

  final double lowAccuracyThresholdMeters;
  final StreamController<LocationFix> _fixController =
      StreamController<LocationFix>.broadcast();
  final StreamController<LocationSnapshot> _stateController =
      StreamController<LocationSnapshot>.broadcast();
  StreamSubscription<Position>? _positionSubscription;
  LocationSnapshot _snapshot = const LocationSnapshot(status: LocationStatus.unknown);
  bool _disposed = false;
  bool _wasRequested = false;

  Stream<LocationFix> get fixes => _fixController.stream;
  Stream<LocationSnapshot> get states => _stateController.stream;
  LocationSnapshot get snapshot => _snapshot;
  bool get wasRequested => _wasRequested;

  Future<LocationStatus> requestWhileInUseAndStart({
    bool requestPermission = true,
  }) async {
    if (_positionSubscription != null) return _snapshot.status;
    _wasRequested = true;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _emitState(const LocationSnapshot(
          status: LocationStatus.servicesDisabled,
          message: 'Location services are turned off.',
        ));
        return _snapshot.status;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        _emitState(const LocationSnapshot(
          status: LocationStatus.permissionRequired,
          message: 'Allow location while using the app to find your position.',
        ));
        if (!requestPermission) return _snapshot.status;
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        _emitState(const LocationSnapshot(
          status: LocationStatus.denied,
          message: 'Location permission was denied. Enter coordinates manually instead.',
        ));
        return _snapshot.status;
      }
      if (permission == LocationPermission.deniedForever) {
        _emitState(const LocationSnapshot(
          status: LocationStatus.permanentlyDenied,
          message: 'Location is blocked in settings. Enter coordinates manually instead.',
        ));
        return _snapshot.status;
      }
      if (permission == LocationPermission.unableToDetermine) {
        _emitState(const LocationSnapshot(
          status: LocationStatus.unavailable,
          message: 'This browser or device cannot provide location.',
        ));
        return _snapshot.status;
      }

      await _positionSubscription?.cancel();
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 1,
        ),
      ).listen(
        _onPosition,
        onError: (Object error, StackTrace stackTrace) {
          _emitState(const LocationSnapshot(
            status: LocationStatus.unavailable,
            message: 'Location is temporarily unavailable.',
          ));
        },
      );
      return _snapshot.status;
    } on UnsupportedError {
      _emitState(const LocationSnapshot(
        status: LocationStatus.unavailable,
        message: 'Location is not supported on this platform.',
      ));
      return _snapshot.status;
    } catch (_) {
      _emitState(const LocationSnapshot(
        status: LocationStatus.unavailable,
        message: 'Location could not be started.',
      ));
      return _snapshot.status;
    }
  }

  Future<void> resumeIfRequested() async {
    if (!_wasRequested || _disposed) return;
    await requestWhileInUseAndStart(requestPermission: false);
  }

  Future<void> stop() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await stop();
    await _fixController.close();
    await _stateController.close();
  }

  void _onPosition(Position position) {
    final LocationFix fix = LocationFix(
      point: GeoPoint(latitude: position.latitude, longitude: position.longitude),
      accuracyMeters: position.accuracy,
      speedMetersPerSecond: position.speed,
      headingDeg: position.heading,
      headingAccuracyDeg: position.headingAccuracy,
      at: position.timestamp.toUtc(),
    );
    _fixController.add(fix);
    _emitState(LocationSnapshot(
      status: fix.accuracyMeters > lowAccuracyThresholdMeters
          ? LocationStatus.lowAccuracy
          : LocationStatus.active,
      fix: fix,
      message: fix.accuracyMeters > lowAccuracyThresholdMeters
          ? 'Location accuracy is low. Move outdoors for a better fix.'
          : null,
    ));
  }

  void _emitState(LocationSnapshot value) {
    if (_disposed) return;
    _snapshot = value;
    _stateController.add(value);
  }
}
