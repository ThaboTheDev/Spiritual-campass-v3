import 'package:flutter/material.dart';

import '../data/app_models.dart';

class CheckoutFormView extends StatelessWidget {
  const CheckoutFormView({super.key, required this.session, required this.onResult});

  final CheckoutSession session;
  final ValueChanged<String> onResult;

  @override
  Widget build(BuildContext context) => const Center(
        child: Text('Secure checkout is not supported on this platform.'),
      );
}
