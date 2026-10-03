import 'dart:async';

import 'package:tshk_core/tshk_core.dart';

import '../location/location_models.dart';
import '../location/location_service.dart';
import 'platform_sensor.dart';
import 'platform_sensor_selector.dart';

class SensorService {
  SensorService({
    required LocationService locationService,
    PlatformSensorAdapter? platform,
    Clock clock = const SystemClock(),
    this.firstHeadingTimeout = const Duration(seconds: 2),
    this.reprobeInterval = const Duration(seconds: 60),
    this.staleAfter = const Duration(seconds: 5),
    this.invalidZeroDuration = const Duration(seconds: 3),
    this.gpsHeadingAccuracyLimitDeg = 30,
    this.gpsPositionAccuracyLimitMeters = 50,
    this.gpsMovingThresholdMps = 1,
    this.minimumGpsBearingDistanceMeters = 10,
  })  : _locationService = locationService,
        _platform = platform ?? createPlatformSensor(),
        _clock = clock;

  final LocationService _locationService;
  final PlatformSensorAdapter _platform;
  final Clock _clock;
  final Duration firstHeadingTimeout;
  final Duration reprobeInterval;
  final Duration staleAfter;
  final Duration invalidZeroDuration;
  final double gpsHeadingAccuracyLimitDeg;
  final double gpsPositionAccuracyLimitMeters;
  final double gpsMovingThresholdMps;
  final double minimumGpsBearingDistanceMeters;

  final StreamController<HeadingReading> _readingController =
      StreamController<HeadingReading>.broadcast();
  final StreamController<SensorStatus> _statusController =
      StreamController<SensorStatus>.broadcast();
  final CircularHeadingFilter _filter = CircularHeadingFilter(alpha: 0.25);

  StreamSubscription<PlatformHeading?>? _platformSubscription;
  StreamSubscription<LocationFix>? _locationSubscription;
  Timer? _firstHeadingTimer;
  Timer? _probeTimer;
  Timer? _probeTimeout;
  Timer? _invalidTimer;
  Timer? _staleTimer;
  HeadingReading? _lastGoodReading;
  DateTime? _lastEmissionAt;
  LocationFix? _previousFix;
  int _consecutiveEmptyEvents = 0;
  bool _sawHeadingThisStart = false;
  bool _running = false;
  bool _paused = false;
  bool _usingGps = false;
  bool _probing = false;
  bool _disposed = false;
  SensorStatus _status = SensorStatus.initialising;

  Stream<HeadingReading> get readings => _readingController.stream;
  Stream<SensorStatus> get statuses => _statusController.stream;
  HeadingReading? get latest => _lastGoodReading;
  SensorStatus get status => _status;
  bool get isWeb => _platform.isWeb;
  bool get secureContext => !_platform.isWeb || _platform.isSecureContext;
  bool get needsWebPermission => _platform.permissionRequired;

  Future<void> start() async {
    if (_disposed || _running) return;
    _running = true;
    _paused = false;
    _sawHeadingThisStart = false;
    _setStatus(SensorStatus.initialising);
    if (_platform.isWeb && !_platform.isSecureContext) {
      _setStatus(SensorStatus.unavailable);
      _startFirstHeadingTimer();
      return;
    }
    await _startPlatformStream();
    if (_platform.permissionRequired && !_usingGps) {
      _setStatus(SensorStatus.needsPermission);
    }
    _startFirstHeadingTimer();
  }

  Future<PermissionResult> requestWebSensorPermission() async {
    if (!_platform.isWeb) return PermissionResult.unsupported;
    if (!_platform.isSecureContext) {
      _setStatus(SensorStatus.unavailable);
      return PermissionResult.insecureContext;
    }
    if (_usingGps) {
      _probeTimer?.cancel();
      if (!_probing) {
        _probing = true;
        _platformSubscription = _platform.headings.listen(
          _onPlatformHeading,
          onError: (Object error, StackTrace stackTrace) => _keepGpsAfterProbe(),
        );
      }
      _probeTimeout?.cancel();
      _probeTimeout = null;
    }
    final PermissionResult result = await _platform.requestWebSensorPermission();
    switch (result) {
      case PermissionResult.granted:
        if (_usingGps && !_probing) {
          _probing = true;
          await _startPlatformStream();
        }
        if (_usingGps && _probing) {
          _probeTimeout = Timer(const Duration(seconds: 2), _keepGpsAfterProbe);
          if (_status != SensorStatus.locationDenied) {
            _setStatus(SensorStatus.degradedToGps);
          }
        } else {
          _setStatus(_usingGps ? SensorStatus.degradedToGps : SensorStatus.initialising);
        }
        if (!_running) await start();
        break;
      case PermissionResult.denied:
        if (_usingGps) {
          _keepGpsAfterProbe();
        } else {
          _setStatus(SensorStatus.needsPermission);
          await _switchToGps();
        }
        break;
      case PermissionResult.unsupported:
      case PermissionResult.insecureContext:
        if (_usingGps) {
          _keepGpsAfterProbe();
        } else {
          _setStatus(SensorStatus.unavailable);
        }
        break;
    }
    return result;
  }

  Future<void> pause() async {
    if (!_running || _paused) return;
    _paused = true;
    _cancelTimers();
    await _platformSubscription?.cancel();
    _platformSubscription = null;
    await _platform.stop();
    await _locationSubscription?.cancel();
    _locationSubscription = null;
    await _locationService.stop();
  }

  Future<void> resume() async {
    if (!_running || !_paused || _disposed) return;
    _paused = false;
    if (_usingGps) {
      await _startGpsStream(requestPermission: false);
      _scheduleProbe();
    } else {
      _sawHeadingThisStart = false;
      await _startPlatformStream();
      _startFirstHeadingTimer();
      await _locationService.resumeIfRequested();
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _running = false;
    _cancelTimers();
    await _platformSubscription?.cancel();
    await _locationSubscription?.cancel();
    await _platform.stop();
    await _locationService.stop();
    await _readingController.close();
    await _statusController.close();
  }

  Future<void> _startPlatformStream() async {
    await _platformSubscription?.cancel();
    _platformSubscription = _platform.headings.listen(
      _onPlatformHeading,
      onError: (Object error, StackTrace stackTrace) {
        _consecutiveEmptyEvents = 0;
        unawaited(_switchToGps());
      },
    );
    try {
      await _platform.start();
    } catch (_) {
      await _switchToGps();
    }
  }

  void _startFirstHeadingTimer() {
    _firstHeadingTimer?.cancel();
    _firstHeadingTimer = Timer(firstHeadingTimeout, () {
      if (!_disposed && !_paused && !_sawHeadingThisStart && !_usingGps) {
        unawaited(_switchToGps());
      }
    });
  }

  void _onPlatformHeading(PlatformHeading? value) {
    if (_disposed || _paused) return;
    if (value == null || value.headingDeg == null || !value.headingDeg!.isFinite) {
      _consecutiveEmptyEvents++;
      if (_consecutiveEmptyEvents >= 3 && !_usingGps) {
        unawaited(_switchToGps());
      }
      return;
    }
    _consecutiveEmptyEvents = 0;
    if (_usingGps && !_probing) return;
    _sawHeadingThisStart = true;
    final double heading = normalizeDegrees(value.headingDeg!);
    if (heading == 0.0) {
      _invalidTimer ??= Timer(invalidZeroDuration, () {
        if (!_usingGps && !_disposed) unawaited(_switchToGps());
      });
    } else {
      _invalidTimer?.cancel();
      _invalidTimer = null;
    }

    _firstHeadingTimer?.cancel();
    _firstHeadingTimer = null;
    _probeTimeout?.cancel();
    _probeTimeout = null;
    _probing = false;
    _usingGps = false;
    _setStatus(SensorStatus.active);
    _emit(HeadingReading(
      headingDeg: heading,
      source: value.source,
      accuracyDeg: value.accuracyDeg,
      reference: value.reference,
      at: (value.at ?? _clock.now()).toUtc(),
    ));
  }

  Future<void> _switchToGps() async {
    if (_disposed || _paused || _usingGps) return;
    _usingGps = true;
    _probing = false;
    _firstHeadingTimer?.cancel();
    _firstHeadingTimer = null;
    _probeTimeout?.cancel();
    _probeTimeout = null;
    await _platformSubscription?.cancel();
    _platformSubscription = null;
    await _platform.stop();
    _setStatus(SensorStatus.degradedToGps);
    await _startGpsStream(requestPermission: true);
    _scheduleProbe();
  }

  Future<void> _startGpsStream({required bool requestPermission}) async {
    await _locationSubscription?.cancel();
    _locationSubscription = _locationService.fixes.listen(_onLocationFix);
    final LocationStatus result = await _locationService.requestWhileInUseAndStart(
      requestPermission: requestPermission,
    );
    if (result == LocationStatus.permissionRequired ||
        result == LocationStatus.denied ||
        result == LocationStatus.permanentlyDenied ||
        result == LocationStatus.servicesDisabled ||
        result == LocationStatus.unavailable) {
      _setStatus(SensorStatus.locationDenied);
      if (_lastGoodReading != null) _emit(_lastGoodReading!.copyWith(isStale: true));
    } else {
      _setStatus(SensorStatus.degradedToGps);
    }
  }

  void _onLocationFix(LocationFix fix) {
    if (_disposed || _paused || !_usingGps) return;
    final LocationFix? previous = _previousFix;
    _previousFix = fix;

    final double headingAccuracy = fix.headingAccuracyDeg;
    final bool positionIsAccurate =
        fix.accuracyMeters.isFinite &&
            fix.accuracyMeters >= 0 &&
            fix.accuracyMeters <= gpsPositionAccuracyLimitMeters;
    final bool headingIsValid =
        fix.headingDeg.isFinite && fix.headingDeg >= 0 && fix.headingDeg < 360;
    final bool accurateMovingCourse =
        positionIsAccurate &&
            fix.speedMetersPerSecond > gpsMovingThresholdMps &&
            headingAccuracy.isFinite &&
            headingAccuracy >= 0 &&
            headingAccuracy <= gpsHeadingAccuracyLimitDeg &&
            headingIsValid;
    if (accurateMovingCourse) {
      _emit(HeadingReading(
        headingDeg: fix.headingDeg,
        source: HeadingSource.gpsCourse,
        accuracyDeg: headingAccuracy,
        reference: HeadingReference.trueNorth,
        at: fix.at,
      ));
      _setStatus(SensorStatus.degradedToGps);
      return;
    }

    if (previous != null &&
        positionIsAccurate &&
        previous.accuracyMeters <= gpsPositionAccuracyLimitMeters) {
      final double movedMeters =
          GeoMath.haversineDistanceKm(previous.point, fix.point) * 1000;
      if (movedMeters >= minimumGpsBearingDistanceMeters) {
        _emit(HeadingReading(
          headingDeg: GeoMath.initialBearingDeg(previous.point, fix.point),
          source: HeadingSource.gpsCourse,
          accuracyDeg: fix.accuracyMeters,
          reference: HeadingReference.trueNorth,
          at: fix.at,
        ));
        _setStatus(SensorStatus.degradedToGps);
      }
    }
    // Without a fresh course, keep the previous reading untouched. The shared
    // stale timer marks it after five seconds, and the UI prompts movement.
  }

  void _scheduleProbe() {
    _probeTimer?.cancel();
    if (_disposed || _paused) return;
    _probeTimer = Timer(reprobeInterval, () => unawaited(_probePlatform()));
  }

  Future<void> _probePlatform() async {
    if (_disposed || _paused || !_usingGps) return;
    _probing = true;
    await _startPlatformStream();
    _probeTimeout?.cancel();
    _probeTimeout = Timer(const Duration(seconds: 2), _keepGpsAfterProbe);
  }

  void _keepGpsAfterProbe() {
    _probeTimeout?.cancel();
    _probeTimeout = null;
    _probing = false;
    if (_disposed || _paused || !_usingGps) return;
    final StreamSubscription<PlatformHeading?>? subscription =
        _platformSubscription;
    _platformSubscription = null;
    if (subscription != null) unawaited(subscription.cancel());
    unawaited(_platform.stop());
    if (_status != SensorStatus.locationDenied) {
      _setStatus(SensorStatus.degradedToGps);
    }
    _scheduleProbe();
  }

  void _emit(HeadingReading raw) {
    if (_disposed || _paused) return;
    final DateTime now = _clock.now().toUtc();
    final DateTime? previousAt = _lastEmissionAt;
    if (previousAt != null && now.difference(previousAt) < const Duration(milliseconds: 33)) {
      return;
    }
    if (_lastGoodReading?.source != raw.source) _filter.reset();
    final double smoothedHeading = _filter.add(raw.headingDeg);
    final HeadingReading reading = raw.copyWith(headingDeg: smoothedHeading);
    _lastEmissionAt = now;
    if (!reading.isStale) _lastGoodReading = reading;
    _readingController.add(reading);
    _scheduleStaleTimer();
  }

  void _scheduleStaleTimer() {
    _staleTimer?.cancel();
    _staleTimer = Timer(staleAfter, () {
      if (_disposed || _paused || _lastGoodReading == null) return;
      final DateTime now = _clock.now().toUtc();
      if (now.difference(_lastGoodReading!.at.toUtc()) < staleAfter) return;
      final HeadingReading stale = _lastGoodReading!.copyWith(isStale: true, at: now);
      _readingController.add(stale);
    });
  }

  void _setStatus(SensorStatus value) {
    if (_status == value || _disposed) return;
    _status = value;
    _statusController.add(value);
  }

  void _cancelTimers() {
    _firstHeadingTimer?.cancel();
    _probeTimer?.cancel();
    _probeTimeout?.cancel();
    _invalidTimer?.cancel();
    _staleTimer?.cancel();
    _firstHeadingTimer = null;
    _probeTimer = null;
    _probeTimeout = null;
    _invalidTimer = null;
    _staleTimer = null;
  }
}
