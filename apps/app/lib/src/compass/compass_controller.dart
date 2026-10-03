import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tshk_core/tshk_core.dart';

import '../location/location_models.dart';
import '../location/location_service.dart';
import '../sensors/sensor_service.dart';

class CompassController extends ChangeNotifier {
  CompassController({
    required SensorService sensorService,
    required LocationService locationService,
  })  : _sensorService = sensorService,
        _locationService = locationService {
    _headingSubscription = _sensorService.readings.listen((HeadingReading value) {
      _heading = value;
      _recompute();
    });
    _sensorStatusSubscription = _sensorService.statuses.listen((SensorStatus value) {
      _sensorStatus = value;
      notifyListeners();
    });
    _locationSubscription = _locationService.states.listen((LocationSnapshot value) {
      _locationSnapshot = value;
      _recompute();
    });
    _locationSnapshot = _locationService.snapshot;
    unawaited(_sensorService.start());
    unawaited(_loadSavedCoordinates());
  }

  static const String _latitudeKey = 'manual_latitude_v1';
  static const String _longitudeKey = 'manual_longitude_v1';

  final SensorService _sensorService;
  final LocationService _locationService;
  final AlignmentHysteresis _alignment = AlignmentHysteresis();
  StreamSubscription<HeadingReading>? _headingSubscription;
  StreamSubscription<SensorStatus>? _sensorStatusSubscription;
  StreamSubscription<LocationSnapshot>? _locationSubscription;

  HeadingReading? _heading;
  SensorStatus _sensorStatus = SensorStatus.initialising;
  LocationSnapshot _locationSnapshot =
      const LocationSnapshot(status: LocationStatus.unknown);
  GeoPoint? _manualPoint;
  CompassState? _compassState;
  GeoPoint? _declinationPoint;
  DateTime? _declinationDate;
  WmmResult? _cachedDeclination;
  bool _isAligned = false;
  bool _disposed = false;

  HeadingReading? get heading => _heading ?? _sensorService.latest;
  SensorStatus get sensorStatus => _sensorStatus;
  LocationSnapshot get locationSnapshot => _locationSnapshot;
  GeoPoint? get manualPoint => _manualPoint;
  bool get hasManualPoint => _manualPoint != null;
  CompassState? get compassState => _compassState;
  bool get isAligned => _isAligned;
  bool get isWeb => _sensorService.isWeb;
  bool get secureContext => _sensorService.secureContext;
  bool get needsWebPermission => _sensorService.needsWebPermission;
  GeoPoint? get currentPoint => _manualPoint ?? _locationSnapshot.fix?.point;
  double? get locationAccuracy => _locationSnapshot.fix?.accuracyMeters;
  bool get isLocationManual => _manualPoint != null;
  bool get isStationary =>
      _locationSnapshot.fix != null &&
      _locationSnapshot.fix!.speedMetersPerSecond <= 1;

  Future<LocationStatus> requestDeviceLocation() =>
      _locationService.requestWhileInUseAndStart();

  Future<bool> setManualCoordinates(String latitudeText, String longitudeText) async {
    final double? latitude = double.tryParse(latitudeText.trim());
    final double? longitude = double.tryParse(longitudeText.trim());
    if (latitude == null || longitude == null) return false;
    final GeoPoint point = GeoPoint(latitude: latitude, longitude: longitude);
    if (!point.isValid) return false;

    _manualPoint = point;
    _recompute(resetAlignment: true);
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.setDouble(_latitudeKey, latitude);
    await preferences.setDouble(_longitudeKey, longitude);
    return true;
  }

  Future<void> clearManualCoordinates() async {
    _manualPoint = null;
    _recompute(resetAlignment: true);
    await clearSavedManualCoordinates();
  }

  static Future<void> clearSavedManualCoordinates() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.remove(_latitudeKey);
    await preferences.remove(_longitudeKey);
  }

  Future<PermissionResult> requestWebSensorPermission() =>
      _sensorService.requestWebSensorPermission();

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(_headingSubscription?.cancel());
    unawaited(_sensorStatusSubscription?.cancel());
    unawaited(_locationSubscription?.cancel());
    super.dispose();
  }

  Future<void> _loadSavedCoordinates() async {
    try {
      final SharedPreferences preferences = await SharedPreferences.getInstance();
      final double? latitude = preferences.getDouble(_latitudeKey);
      final double? longitude = preferences.getDouble(_longitudeKey);
      if (latitude == null || longitude == null) return;
      final GeoPoint point = GeoPoint(latitude: latitude, longitude: longitude);
      if (!point.isValid || _disposed) return;
      _manualPoint = point;
      _recompute(resetAlignment: true);
    } catch (_) {
      // A missing local preference should not block live compass use.
    }
  }

  void _recompute({bool resetAlignment = false}) {
    if (_disposed) return;
    final GeoPoint? from = currentPoint;
    final HeadingReading? currentHeading = heading;
    if (resetAlignment) _alignment.reset();
    if (from == null || currentHeading == null) {
      _compassState = null;
      _isAligned = false;
      notifyListeners();
      return;
    }

    final DateTime now = DateTime.now().toUtc();
    final DateTime dateKey = DateTime.utc(now.year, now.month, now.day);
    if (_cachedDeclination == null ||
        _declinationPoint?.latitude != from.latitude ||
        _declinationPoint?.longitude != from.longitude ||
        _declinationDate != dateKey) {
      _cachedDeclination = Wmm2025.declination(location: from, date: now);
      _declinationPoint = from;
      _declinationDate = dateKey;
    }
    final WmmResult declination = _cachedDeclination!;
    final GeoPoint target =
        const GeoPoint(latitude: kTargetLat, longitude: kTargetLng);
    final CompassState provisional = CompassState.calculate(
      from: from,
      target: target,
      heading: currentHeading,
      declination: declination,
      isAligned: false,
    );
    _isAligned = _alignment.update(provisional.relativeNeedleAngleDeg);
    _compassState = CompassState.calculate(
      from: from,
      target: target,
      heading: currentHeading,
      declination: declination,
      isAligned: _isAligned,
    );
    notifyListeners();
  }
}
