import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../data/app_models.dart';

class CheckoutFormView extends StatefulWidget {
  const CheckoutFormView({
    super.key,
    required this.session,
    required this.onResult,
  });

  final CheckoutSession session;
  final ValueChanged<String> onResult;

  @override
  State<CheckoutFormView> createState() => _CheckoutFormViewState();
}

class _CheckoutFormViewState extends State<CheckoutFormView> {
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _submitForm());
  }

  void _submitForm() {
    try {
      if (!widget.session.actionUrl.isScheme('https') ||
          !<String>{'www.payfast.co.za', 'sandbox.payfast.co.za'}
              .contains(widget.session.actionUrl.host)) {
        throw StateError('Unexpected checkout host.');
      }
      final web.HTMLFormElement form =
          web.document.createElement('form') as web.HTMLFormElement
            ..action = widget.session.actionUrl.toString()
            ..method = 'POST'
            ..target = '_self';
      form.style.display = 'none';
      for (final MapEntry<String, String> entry in widget.session.fields.entries) {
        final web.HTMLInputElement input =
            web.document.createElement('input') as web.HTMLInputElement
              ..type = 'hidden'
              ..name = entry.key
              ..value = entry.value;
        form.append(input);
      }
      web.document.body!.append(form);
      form.submit();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Secure checkout could not be opened. Please try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (_error == null) ...<Widget>[
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                const Text('Connecting to secure PayFast checkout…'),
              ] else ...<Widget>[
                const Icon(Icons.error_outline, size: 42),
                const SizedBox(height: 12),
                Text(_error!, textAlign: TextAlign.center),
              ],
            ],
          ),
        ),
      );
}
