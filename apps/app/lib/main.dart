import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'src/app.dart';
import 'src/config/app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final AppConfig config = AppConfig.fromEnvironment();
  if (!config.isConfigured) {
    runApp(const _ConfigurationRequiredApp());
    return;
  }

  try {
    await Supabase.initialize(
      url: config.supabaseUrl,
      publishableKey: config.supabaseAnonKey,
    );
  } catch (_) {
    runApp(const _ConfigurationRequiredApp());
    return;
  }
  runApp(const ProviderScope(child: TshkCompassApp()));
}

class _ConfigurationRequiredApp extends StatelessWidget {
  const _ConfigurationRequiredApp();

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'TSHK Compass setup',
        theme: ThemeData(colorSchemeSeed: const Color(0xFF376C5A)),
        home: Scaffold(
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Icon(Icons.explore_outlined, size: 42),
                    const SizedBox(height: 20),
                    Text('Configuration required',
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 12),
                    const Text(
                      'Build the app with SUPABASE_URL, SUPABASE_ANON_KEY, and '
                      'API_BASE_URL using --dart-define. Only the public Supabase '
                      'anon key belongs in the client. Keep service-role, JWT, and '
                      'PayFast passphrase values on the API server.',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}
