import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/app_models.dart';
import 'checkout_launcher_stub.dart'
    if (dart.library.io) 'checkout_launcher_native.dart'
    if (dart.library.js_interop) 'checkout_launcher_web.dart' as implementation;

class CheckoutScreenArgs {
  const CheckoutScreenArgs(this.session);

  final CheckoutSession session;
}

class CheckoutScreen extends StatelessWidget {
  const CheckoutScreen({super.key, required this.args});

  final CheckoutScreenArgs args;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Secure PayFast checkout'),
          leading: IconButton(
            tooltip: 'Close checkout',
            onPressed: () => context.pop(),
            icon: const Icon(Icons.close),
          ),
        ),
        body: SafeArea(
          child: implementation.CheckoutFormView(
            session: args.session,
            onResult: (String result) => context.go('/app?checkout=$result'),
          ),
        ),
      );
}
