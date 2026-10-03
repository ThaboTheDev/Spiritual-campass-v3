import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tshk_core/tshk_core.dart';

import '../compass/compass_controller.dart';
import '../location/location_models.dart';
import '../providers/app_providers.dart';
import '../providers/compass_providers.dart';
import '../sensors/lifecycle_sensor_controller.dart';

class CompassScreen extends ConsumerStatefulWidget {
  const CompassScreen({super.key});

  @override
  ConsumerState<CompassScreen> createState() => _CompassScreenState();
}

class _CompassScreenState extends ConsumerState<CompassScreen> {
  late final LifecycleSensorController _lifecycleController;

  @override
  void initState() {
    super.initState();
    _lifecycleController =
        LifecycleSensorController(ref.read(sensorServiceProvider))..attach();
  }

  @override
  void dispose() {
    unawaited(_lifecycleController.detach());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final CompassController compass = ref.watch(compassControllerProvider);
    final HeadingReading? heading = compass.heading;
    final CompassState? state = compass.compassState;
    final GeoPoint? location = compass.currentPoint;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
      children: <Widget>[
        _SensorBanner(compass: compass),
        const SizedBox(height: 14),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 330),
            child: AspectRatio(
              aspectRatio: 1,
              child: Semantics(
                container: true,
                label: _compassDescription(heading, state),
                child: CustomPaint(
                  painter: _CompassDialPainter(
                    targetAngleDeg: state?.relativeNeedleAngleDeg ?? 0,
                    trueHeadingDeg: state?.trueHeadingDeg ?? heading?.headingDeg ?? 0,
                    aligned: state?.isAligned ?? false,
                    foreground: Theme.of(context).colorScheme.onSurface,
                    accent: Theme.of(context).colorScheme.primary,
                    secondary: Theme.of(context).colorScheme.error,
                    surface: Theme.of(context).colorScheme.surface,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          state?.isAligned == true ? Icons.check_circle : Icons.explore,
                          size: 36,
                          color: state?.isAligned == true
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.error,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          state?.isAligned == true ? 'ALIGNED' : 'EKUPHUMULENI',
                          style: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(letterSpacing: 1.5, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (heading == null || location == null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              heading == null
                  ? 'Waiting for a compass heading.'
                  : 'Set your location to calculate a direction.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        const SizedBox(height: 18),
        _CompassReadout(state: state, heading: heading),
        const SizedBox(height: 16),
        _LocationCard(compass: compass),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _showManualCoordinates(context, compass),
          icon: const Icon(Icons.edit_location_alt_outlined),
          label: Text(compass.hasManualPoint ? 'Edit manual coordinates' : 'Enter coordinates manually'),
        ),
        if (compass.hasManualPoint) ...<Widget>[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => unawaited(compass.clearManualCoordinates()),
            icon: const Icon(Icons.location_searching),
            label: const Text('Use device location instead'),
          ),
        ],
        if (state?.modelExpired == true) ...<Widget>[
          const SizedBox(height: 12),
          const _ModelWarning(),
        ],
      ],
    );
  }

  Future<void> _showManualCoordinates(
    BuildContext context,
    CompassController compass,
  ) async {
    final GeoPoint? current = compass.manualPoint;
    final TextEditingController latitude = TextEditingController(
      text: current?.latitude.toStringAsFixed(6) ?? '',
    );
    final TextEditingController longitude = TextEditingController(
      text: current?.longitude.toStringAsFixed(6) ?? '',
    );
    String? error;
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) => AlertDialog(
          title: const Text('Enter coordinates'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text('Use decimal degrees. Coordinates stay on this device.'),
              const SizedBox(height: 14),
              TextField(
                controller: latitude,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                decoration: const InputDecoration(labelText: 'Latitude (−90 to 90)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: longitude,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                decoration: const InputDecoration(labelText: 'Longitude (−180 to 180)'),
              ),
              if (error != null) ...<Widget>[
                const SizedBox(height: 10),
                Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final bool saved = await compass.setManualCoordinates(
                  latitude.text,
                  longitude.text,
                );
                if (!saved) {
                  setDialogState(() => error = 'Enter valid latitude and longitude values.');
                  return;
                }
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: const Text('Save coordinates'),
            ),
          ],
        ),
      ),
    );
    latitude.dispose();
    longitude.dispose();
  }
}

class _SensorBanner extends StatelessWidget {
  const _SensorBanner({required this.compass});

  final CompassController compass;

  @override
  Widget build(BuildContext context) {
    final SensorStatus status = compass.sensorStatus;
    final bool warning = status == SensorStatus.degradedToGps ||
        status == SensorStatus.locationDenied ||
        status == SensorStatus.unavailable ||
        compass.heading?.isStale == true;
    final Color color = warning
        ? Theme.of(context).colorScheme.errorContainer
        : Theme.of(context).colorScheme.primaryContainer;
    final String message = switch (status) {
      SensorStatus.initialising => 'Starting compass sensor…',
      SensorStatus.needsPermission => 'Enable motion access to use the compass.',
      SensorStatus.active => 'Compass sensor active.',
      SensorStatus.degradedToGps => compass.isStationary
          ? 'Using GPS course. Move at least 10 m to calibrate direction.'
          : 'Using GPS course as a compass fallback.',
      SensorStatus.locationDenied =>
        'Compass and location are unavailable. Enter coordinates or review permissions.',
      SensorStatus.unavailable => compass.secureContext
          ? 'Compass sensor unavailable. GPS may be used as a fallback.'
          : 'Motion and location sensors require a secure HTTPS connection.',
    };
    return Card(
      color: color,
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  warning ? Icons.info_outline : Icons.sensors,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                const SizedBox(width: 9),
                Expanded(child: Text(message)),
              ],
            ),
            if (compass.isWeb && compass.needsWebPermission) ...<Widget>[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () async {
                    final PermissionResult result =
                        await compass.requestWebSensorPermission();
                    if (!context.mounted || result == PermissionResult.granted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(result == PermissionResult.insecureContext
                            ? 'Open the app using HTTPS to enable motion sensors.'
                            : 'Motion permission was not granted. GPS or manual coordinates remain available.'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.touch_app_outlined),
                  label: const Text('Enable compass'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CompassReadout extends StatelessWidget {
  const _CompassReadout({required this.state, required this.heading});

  final CompassState? state;
  final HeadingReading? heading;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: _Metric(
                    label: 'TURN TO TARGET',
                    value: state == null
                        ? '—'
                        : '${state!.relativeNeedleAngleDeg.abs().toStringAsFixed(0)}° ${state!.relativeNeedleAngleDeg >= 0 ? 'right' : 'left'}',
                  ),
                ),
                Container(width: 1, height: 42, color: colors.outlineVariant),
                Expanded(
                  child: _Metric(
                    label: 'DISTANCE',
                    value: state == null
                        ? '—'
                        : '${state!.distanceKm.toStringAsFixed(state!.distanceKm < 10 ? 1 : 0)} km',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Row(
              children: <Widget>[
                Expanded(
                  child: _Metric(
                    label: 'TRUE BEARING',
                    value: state == null
                        ? '—'
                        : '${state!.trueBearingDeg.toStringAsFixed(0)}°',
                  ),
                ),
                Expanded(
                  child: _Metric(
                    label: 'DECLINATION',
                    value: state == null
                        ? '—'
                        : '${state!.declinationDeg >= 0 ? '+' : ''}${state!.declinationDeg.toStringAsFixed(1)}°',
                  ),
                ),
                Expanded(
                  child: _Metric(
                    label: 'HEADING',
                    value: heading == null ? '—' : '${heading!.headingDeg.toStringAsFixed(0)}°',
                  ),
                ),
              ],
            ),
            if (heading != null) ...<Widget>[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(
                    heading!.source == HeadingSource.gpsCourse
                        ? Icons.gps_fixed
                        : Icons.explore_outlined,
                    size: 16,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${_sourceLabel(heading!.source)} • ${heading!.reference == HeadingReference.trueNorth ? 'true north' : 'magnetic north'}${heading!.isStale ? ' • stale' : ''}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
        children: <Widget>[
          Text(label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(letterSpacing: 0.6)),
          const SizedBox(height: 4),
          Text(value,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 20)),
        ],
      );
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({required this.compass});

  final CompassController compass;

  @override
  Widget build(BuildContext context) {
    final LocationSnapshot snapshot = compass.locationSnapshot;
    final GeoPoint? point = compass.currentPoint;
    final String coordinateLabel = point == null
        ? 'No location set'
        : '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: <Widget>[
            Icon(compass.isLocationManual ? Icons.edit_location_alt : Icons.my_location,
                color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(compass.isLocationManual ? 'Manual location' : 'Your location',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(coordinateLabel),
                  if (!compass.isLocationManual && snapshot.fix != null)
                    Text(
                      'Accuracy ${snapshot.fix!.accuracyMeters.toStringAsFixed(0)} m',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  if (snapshot.message != null && !compass.isLocationManual)
                    Text(snapshot.message!,
                        style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            if (!compass.isLocationManual)
              IconButton(
                tooltip: 'Request location while using the app',
                onPressed: () async {
                  final LocationStatus status = await compass.requestDeviceLocation();
                  if (!context.mounted) return;
                  if (status == LocationStatus.denied ||
                      status == LocationStatus.permanentlyDenied ||
                      status == LocationStatus.servicesDisabled ||
                      status == LocationStatus.unavailable) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(compass.locationSnapshot.message ??
                            'Location is unavailable. Enter coordinates manually instead.'),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.gps_fixed),
              ),
          ],
        ),
      ),
    );
  }
}

class _ModelWarning extends StatelessWidget {
  const _ModelWarning();

  @override
  Widget build(BuildContext context) => Card(
        color: Theme.of(context).colorScheme.tertiaryContainer,
        child: const Padding(
          padding: EdgeInsets.all(14),
          child: Text(
            'WMM-2025 is outside its published 2025–2030 validity window. Compass declination may be less reliable.',
          ),
        ),
      );
}

String _sourceLabel(HeadingSource source) => switch (source) {
      HeadingSource.nativeMagnetometer => 'Device compass',
      HeadingSource.webOrientation => 'Web compass',
      HeadingSource.gpsCourse => 'GPS course',
    };

String _compassDescription(HeadingReading? heading, CompassState? state) {
  if (heading == null || state == null) return 'Compass waiting for a heading and location.';
  final String direction = state.relativeNeedleAngleDeg.abs() < 0.5
      ? 'straight ahead'
      : '${state.relativeNeedleAngleDeg.abs().round()} degrees ${state.relativeNeedleAngleDeg > 0 ? 'right' : 'left'}';
  return 'Compass points $direction toward Ekuphumuleni. '
      'Distance ${state.distanceKm.toStringAsFixed(1)} kilometres. '
      '${state.isAligned ? 'Aligned.' : 'Not yet aligned.'}';
}

class _CompassDialPainter extends CustomPainter {
  const _CompassDialPainter({
    required this.targetAngleDeg,
    required this.trueHeadingDeg,
    required this.aligned,
    required this.foreground,
    required this.accent,
    required this.secondary,
    required this.surface,
  });

  final double targetAngleDeg;
  final double trueHeadingDeg;
  final bool aligned;
  final Color foreground;
  final Color accent;
  final Color secondary;
  final Color surface;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = math.min(size.width, size.height) * 0.45;
    final Paint outer = Paint()
      ..color = surface
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius + 7, outer);
    final Paint ring = Paint()
      ..color = foreground.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius, ring);

    for (int degree = 0; degree < 360; degree += 5) {
      final double angle = (degree - trueHeadingDeg - 90) * math.pi / 180;
      final bool major = degree % 30 == 0;
      final bool medium = degree % 10 == 0;
      final double inner = radius - (major ? 15 : medium ? 9 : 5);
      final Offset start = center + Offset(math.cos(angle) * inner, math.sin(angle) * inner);
      final Offset end = center + Offset(math.cos(angle) * radius, math.sin(angle) * radius);
      canvas.drawLine(
        start,
        end,
        Paint()
          ..color = foreground.withValues(alpha: major ? 0.78 : 0.28)
          ..strokeWidth = major ? 2 : 1,
      );
    }

    _drawCardinal(canvas, center, radius, 'N', 0 - trueHeadingDeg);
    _drawCardinal(canvas, center, radius, 'E', 90 - trueHeadingDeg);
    _drawCardinal(canvas, center, radius, 'S', 180 - trueHeadingDeg);
    _drawCardinal(canvas, center, radius, 'W', 270 - trueHeadingDeg);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(targetAngleDeg * math.pi / 180);
    final Path needle = Path()
      ..moveTo(0, -radius * 0.68)
      ..lineTo(radius * 0.12, radius * 0.02)
      ..lineTo(0, -radius * 0.08)
      ..lineTo(-radius * 0.12, radius * 0.02)
      ..close();
    canvas.drawPath(
      needle,
      Paint()
        ..color = aligned ? accent : secondary
        ..style = PaintingStyle.fill,
    );
    final Path tail = Path()
      ..moveTo(0, radius * 0.56)
      ..lineTo(radius * 0.08, radius * 0.06)
      ..lineTo(0, radius * 0.14)
      ..lineTo(-radius * 0.08, radius * 0.06)
      ..close();
    canvas.drawPath(tail, Paint()..color = foreground.withValues(alpha: 0.36));
    canvas.restore();

    canvas.drawCircle(center, 5, Paint()..color = foreground);
  }

  void _drawCardinal(Canvas canvas, Offset center, double radius, String label, double degrees) {
    final double angle = (degrees - 90) * math.pi / 180;
    final Offset position = center +
        Offset(math.cos(angle) * (radius - 30), math.sin(angle) * (radius - 30));
    final TextPainter text = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: label == 'N' ? secondary : foreground,
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(canvas, position - Offset(text.width / 2, text.height / 2));
  }

  @override
  bool shouldRepaint(_CompassDialPainter oldDelegate) =>
      targetAngleDeg != oldDelegate.targetAngleDeg ||
      trueHeadingDeg != oldDelegate.trueHeadingDeg ||
      aligned != oldDelegate.aligned ||
      foreground != oldDelegate.foreground ||
      accent != oldDelegate.accent ||
      secondary != oldDelegate.secondary ||
      surface != oldDelegate.surface;
}
