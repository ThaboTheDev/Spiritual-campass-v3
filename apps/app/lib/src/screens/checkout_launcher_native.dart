import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

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
  late final WebViewController _controller;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _loading = true),
          onPageFinished: (_) => setState(() => _loading = false),
          onWebResourceError: (WebResourceError error) {
            if (!error.isForMainFrame) return;
            setState(() {
              _loading = false;
              _error = 'The secure payment page could not be loaded.';
            });
          },
          onNavigationRequest: (NavigationRequest request) {
            final Uri uri = Uri.tryParse(request.url) ?? Uri();
            final String? result = uri.queryParameters['checkout'];
            if (result == 'return' || result == 'cancel') {
              widget.onResult(result);
              return NavigationDecision.prevent;
            }
            if (uri.scheme != 'https' && uri.scheme != 'about') {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      );
    _submitForm();
  }

  Future<void> _submitForm() async {
    try {
      final String body = _encodeForm(widget.session.fields);
      await _controller.loadRequest(
        widget.session.actionUrl,
        method: LoadRequestMethod.post,
        headers: const <String, String>{
          'content-type': 'application/x-www-form-urlencoded',
        },
        body: Uint8List.fromList(utf8.encode(body)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Checkout could not be opened. Return to Membership and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => Stack(
        children: <Widget>[
          if (_error == null) WebViewWidget(controller: _controller),
          if (_loading && _error == null)
            const ColoredBox(
              color: Colors.white,
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_error != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!, textAlign: TextAlign.center),
              ),
            ),
        ],
      );
}

String _encodeForm(Map<String, String> fields) => fields.entries
    .map((MapEntry<String, String> entry) =>
        '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(entry.value)}')
    .join('&');
