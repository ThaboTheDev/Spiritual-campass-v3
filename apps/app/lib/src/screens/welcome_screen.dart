import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(26),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Icon(Icons.explore,
                          size: 42, color: Theme.of(context).colorScheme.primary),
                    ),
                    const SizedBox(height: 30),
                    Text('TSHK Compass',
                        style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 12),
                    Text(
                      'A quiet guide to the place that calls you home.',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            height: 1.35,
                          ),
                    ),
                    const SizedBox(height: 28),
                    const _WelcomeFeature(
                      icon: Icons.explore_outlined,
                      title: 'Find your direction',
                      detail: 'A live compass aligned to Ekuphumuleni.',
                    ),
                    const SizedBox(height: 12),
                    const _WelcomeFeature(
                      icon: Icons.place_outlined,
                      title: 'Explore centres',
                      detail: 'A member directory when verified listings are available.',
                    ),
                    const SizedBox(height: 12),
                    const _WelcomeFeature(
                      icon: Icons.lock_outline,
                      title: 'Your choice, your data',
                      detail: 'Use device location only with permission or enter coordinates yourself.',
                    ),
                    const SizedBox(height: 32),
                    FilledButton(
                      onPressed: () => context.go('/signup'),
                      child: const Text('Create an account'),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: () => context.go('/login'),
                      child: const Text('I already have an account'),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'By continuing, you can review the privacy notice before creating an account.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

class _WelcomeFeature extends StatelessWidget {
  const _WelcomeFeature({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(detail, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      );
}
