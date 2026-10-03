import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../compass/compass_controller.dart';
import 'app_providers.dart';

final compassControllerProvider = ChangeNotifierProvider<CompassController>((ref) {
  return CompassController(
    sensorService: ref.watch(sensorServiceProvider),
    locationService: ref.watch(locationServiceProvider),
  );
});
