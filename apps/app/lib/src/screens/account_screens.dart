import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class InvalidCheckoutScreen extends StatelessWidget {
  const InvalidCheckoutScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Secure checkout')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.info_outline, size: 42),
                const SizedBox(height: 12),
                Text('Checkout session expired',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                const Text('Return to Membership and start a new checkout.'),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => context.go('/app?tab=membership'),
                  child: const Text('Back to membership'),
                ),
              ],
            ),
          ),
        ),
      );
}
