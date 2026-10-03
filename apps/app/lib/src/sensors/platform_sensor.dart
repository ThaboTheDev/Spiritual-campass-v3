import 'dart:async';

import 'package:tshk_core/tshk_core.dart';

class PlatformHeading {
  const PlatformHeading({
    required this.headingDeg,
    required this.source,
    required this.reference,
    this.accuracyDeg,
    this.at,
  });

  final double? headingDeg;
  final HeadingSource source;
  final HeadingReference reference;
  final double? accuracyDeg;
  final DateTime? at;
}

abstract interface class PlatformSensorAdapter {
  bool get isWeb;
  bool get isSecureContext;
  bool get permissionRequired;
  Stream<PlatformHeading?> get headings;

  Future<void> start();
  Future<void> stop();
  Future<PermissionResult> requestWebSensorPermission();
}
