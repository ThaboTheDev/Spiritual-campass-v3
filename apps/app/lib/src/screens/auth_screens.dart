import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/app_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  bool _busy = false;
  String? _error;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(supabaseClientProvider).auth.signInWithPassword(
            email: _email.text.trim(),
            password: _password.text,
          );
      if (mounted) context.go('/app');
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = _safeAuthMessage(error.message));
    } catch (_) {
      if (mounted) setState(() => _error = 'Sign in could not be completed. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => _AuthScaffold(
        title: 'Welcome back',
        subtitle: 'Sign in to continue your journey.',
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const <String>[AutofillHints.username, AutofillHints.email],
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Email address'),
                validator: _validateEmail,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _password,
                obscureText: _obscure,
                autofillHints: const <String>[AutofillHints.password],
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => unawaited(_submit()),
                decoration: InputDecoration(
                  labelText: 'Password',
                  suffixIcon: IconButton(
                    tooltip: _obscure ? 'Show password' : 'Hide password',
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                  ),
                ),
                validator: (String? value) =>
                    value == null || value.isEmpty ? 'Enter your password.' : null,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => context.go('/reset-password'),
                  child: const Text('Forgot password?'),
                ),
              ),
              if (_error != null) _InlineError(_error!),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Sign in'),
              ),
              const SizedBox(height: 14),
              TextButton(
                onPressed: () => context.go('/signup'),
                child: const Text('New to TSHK Compass? Create an account'),
              ),
            ],
          ),
        ),
      );
}

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  bool _acceptedPrivacy = false;
  bool _busy = false;
  String? _error;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptedPrivacy) {
      setState(() => _error = 'Please review and accept the privacy notice to continue.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final String redirect = _authRedirect();
      final AuthResponse response = await ref.read(supabaseClientProvider).auth.signUp(
            email: _email.text.trim(),
            password: _password.text,
            emailRedirectTo: redirect,
            data: <String, Object?>{'privacy_notice_accepted': true},
          );
      if (!mounted) return;
      if (response.session != null) {
        context.go('/app');
      } else {
        context.go('/email-sent');
      }
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = _safeAuthMessage(error.message));
    } catch (_) {
      if (mounted) setState(() => _error = 'Account creation could not be completed. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => _AuthScaffold(
        title: 'Create your account',
        subtitle: 'Start with a personal, private compass.',
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const <String>[AutofillHints.email],
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Email address'),
                validator: _validateEmail,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _password,
                obscureText: _obscure,
                autofillHints: const <String>[AutofillHints.newPassword],
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => unawaited(_submit()),
                decoration: InputDecoration(
                  labelText: 'Password',
                  helperText: 'Use at least 8 characters.',
                  suffixIcon: IconButton(
                    tooltip: _obscure ? 'Show password' : 'Hide password',
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                  ),
                ),
                validator: (String? value) =>
                    value == null || value.length < 8 ? 'Use at least 8 characters.' : null,
              ),
              const SizedBox(height: 10),
              _PrivacyNotice(
                checked: _acceptedPrivacy,
                onChanged: (bool? value) =>
                    setState(() => _acceptedPrivacy = value ?? false),
                onRead: () => showDialog<void>(
                  context: context,
                  builder: (BuildContext context) => const _PrivacyDialog(),
                ),
              ),
              if (_error != null) _InlineError(_error!),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Create account'),
              ),
              const SizedBox(height: 14),
              TextButton(
                onPressed: () => context.go('/login'),
                child: const Text('Already registered? Sign in'),
              ),
            ],
          ),
        ),
      );
}

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final TextEditingController _email = TextEditingController();
  bool _busy = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final String? validation = _validateEmail(_email.text);
    if (validation != null) {
      setState(() => _error = validation);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(supabaseClientProvider).auth.resetPasswordForEmail(
            _email.text.trim(),
            redirectTo: _authRedirect(),
          );
      if (mounted) setState(() => _sent = true);
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = _safeAuthMessage(error.message));
    } catch (_) {
      if (mounted) setState(() => _error = 'The reset email could not be sent. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => _AuthScaffold(
        title: _sent ? 'Check your inbox' : 'Reset your password',
        subtitle: _sent
            ? 'If that address is registered, a reset link is on its way.'
            : 'We will send a secure password reset link to your email.',
        child: _sent
            ? FilledButton(
                onPressed: () => context.go('/login'),
                child: const Text('Back to sign in'),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email address'),
                  ),
                  if (_error != null) _InlineError(_error!),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Send reset link'),
                  ),
                  TextButton(
                    onPressed: () => context.go('/login'),
                    child: const Text('Back to sign in'),
                  ),
                ],
              ),
      );
}

class EmailSentScreen extends StatelessWidget {
  const EmailSentScreen({super.key});

  @override
  Widget build(BuildContext context) => _AuthScaffold(
      title: 'Check your inbox',
      subtitle: 'Confirm your email address to finish creating your account.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Icon(Icons.mark_email_read_outlined, size: 54),
          const SizedBox(height: 12),
          const Text('If the address can be registered, we sent a confirmation link.'),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () => context.go('/login'),
            child: const Text('Back to sign in'),
          ),
        ],
      ),
    );
}

class _AuthScaffold extends StatelessWidget {
  const _AuthScaffold({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Back',
            onPressed: () => context.go('/'),
            icon: const Icon(Icons.arrow_back),
          ),
          title: const Text('TSHK Compass'),
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Text(title, style: Theme.of(context).textTheme.headlineSmall),
                        const SizedBox(height: 8),
                        Text(subtitle),
                        const SizedBox(height: 24),
                        child,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

class _PrivacyNotice extends StatelessWidget {
  const _PrivacyNotice({required this.checked, required this.onChanged, required this.onRead});

  final bool checked;
  final ValueChanged<bool?> onChanged;
  final VoidCallback onRead;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Checkbox(value: checked, onChanged: onChanged),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Wrap(
                children: <Widget>[
                  const Text('I have read the '),
                  InkWell(
                    onTap: onRead,
                    child: Text(
                      'privacy notice',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        decoration: TextDecoration.underline,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Text('.'),
                ],
              ),
            ),
          ),
        ],
      );
}

class _PrivacyDialog extends StatelessWidget {
  const _PrivacyDialog();

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Privacy notice'),
        content: const SingleChildScrollView(
          child: Text(
            'TSHK Compass uses your email to sign you in and maintain your membership. '
            'Your precise location is requested only while the app is in use and is used '
            'to calculate direction to Ekuphumuleni. You may deny permission and enter '
            'coordinates manually. Manual coordinates are stored in local app preferences '
            'and may be included in device backups according to your OS settings. Compass '
            'sensor readings are processed on your device. Membership and payment references '
            'are processed by our API and PayFast. You can request account deletion from '
            'Settings; this removes your app account and linked records. PayFast may retain '
            'transaction records under its own legal and privacy obligations. Do not enter '
            'information you do not want processed.',
          ),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      );
}

class _InlineError extends StatelessWidget {
  const _InlineError(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Semantics(
          liveRegion: true,
          child: Text(
            message,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      );
}

String? _validateEmail(String? value) {
  final String email = (value ?? '').trim();
  if (email.isEmpty || !email.contains('@') || email.endsWith('@')) {
    return 'Enter a valid email address.';
  }
  return null;
}

String _safeAuthMessage(String message) {
  if (message.toLowerCase().contains('invalid login')) {
    return 'Email or password is incorrect.';
  }
  if (message.toLowerCase().contains('already registered')) {
    return 'An account already exists for this email. Try signing in.';
  }
  if (message.toLowerCase().contains('password')) {
    return 'The password does not meet the account requirements.';
  }
  return 'Authentication could not be completed. Check your details and try again.';
}

String _authRedirect() {
  if ((Uri.base.scheme == 'https' || Uri.base.scheme == 'http') &&
      Uri.base.host.isNotEmpty) {
    return Uri.base
        .replace(path: '/auth/callback', query: '', fragment: '')
        .toString();
  }
  return 'tshkcompass://auth/callback';
}
