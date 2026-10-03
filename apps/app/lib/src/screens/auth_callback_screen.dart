import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AuthCallbackScreen extends StatefulWidget {
  const AuthCallbackScreen({super.key});

  @override
  State<AuthCallbackScreen> createState() => _AuthCallbackScreenState();
}

class _AuthCallbackScreenState extends State<AuthCallbackScreen> {
  Timer? _timeout;
  bool _timedOut = false;

  @override
  void initState() {
    super.initState();
    _timeout = Timer(const Duration(seconds: 12), () {
      if (mounted) setState(() => _timedOut = true);
    });
  }

  @override
  void dispose() {
    _timeout?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Confirming your account')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _timedOut
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(Icons.error_outline, size: 44),
                      const SizedBox(height: 12),
                      Text('The sign-in link could not be completed.',
                          style: Theme.of(context).textTheme.titleLarge,
                          textAlign: TextAlign.center),
                      const SizedBox(height: 8),
                      const Text('Try signing in again or request a fresh link.',
                          textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => context.go('/login'),
                        child: const Text('Go to sign in'),
                      ),
                    ],
                  )
                : const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      CircularProgressIndicator(),
                      SizedBox(height: 14),
                      Text('Securely completing sign in…'),
                    ],
                  ),
          ),
        ),
      );
}
