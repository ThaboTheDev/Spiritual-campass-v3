import 'dart:async';

import 'package:flutter/widgets.dart';

import 'sensor_service.dart';

class LifecycleSensorController with WidgetsBindingObserver {
  LifecycleSensorController(this._sensorService);

  final SensorService _sensorService;
  bool _registered = false;

  void attach() {
    if (_registered) return;
    WidgetsBinding.instance.addObserver(this);
    _registered = true;
  }

  Future<void> detach() async {
    if (!_registered) return;
    WidgetsBinding.instance.removeObserver(this);
    _registered = false;
    await _sensorService.pause();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_sensorService.resume());
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      unawaited(_sensorService.pause());
    }
  }
}
