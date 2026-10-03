import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../data/app_api_client.dart';
import '../data/app_models.dart';
import '../location/location_service.dart';
import '../sensors/sensor_service.dart';

final appConfigProvider = Provider<AppConfig>((ref) => AppConfig.fromEnvironment());

final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(supabaseClientProvider).auth.onAuthStateChange;
});

final appApiClientProvider = Provider<AppApiClient>((ref) {
  final AppApiClient client = AppApiClient(
    config: ref.watch(appConfigProvider),
    supabase: ref.watch(supabaseClientProvider),
  );
  ref.onDispose(client.close);
  return client;
});

final entitlementProvider = FutureProvider.autoDispose<MemberSnapshot>(
  (ref) => ref.watch(appApiClientProvider).getMe(),
);

final centresProvider = FutureProvider.autoDispose<CentreCatalog>(
  (ref) => ref.watch(appApiClientProvider).getCentres(),
);

final locationServiceProvider = Provider<LocationService>((ref) {
  final LocationService service = LocationService();
  ref.onDispose(() => unawaited(service.dispose()));
  return service;
});

final sensorServiceProvider = Provider<SensorService>((ref) {
  final SensorService service = SensorService(
    locationService: ref.watch(locationServiceProvider),
  );
  ref.onDispose(() => unawaited(service.dispose()));
  return service;
});
