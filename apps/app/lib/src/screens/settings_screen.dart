import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';


import '../compass/compass_controller.dart';
import '../data/app_models.dart';
import '../providers/app_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
        children: <Widget>[
          Text('Settings & privacy', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          const Text('Control your account and personal information.'),
          const SizedBox(height: 18),
          Card(
            child: Column(
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('Privacy notice'),
                  subtitle: const Text('How account, location and payment data are used'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showDialog<void>(
                    context: context,
                    builder: (BuildContext context) => const _PrivacyDialog(),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: const Text('Delete account'),
                  subtitle: const Text('Permanently remove your account and linked app records'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showDialog<void>(
                    context: context,
                    builder: (BuildContext context) => const _DeleteAccountDialog(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () async {
              await ref.read(supabaseClientProvider).auth.signOut();
              if (context.mounted) context.go('/');
            },
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
          ),
          const SizedBox(height: 18),
          Text(
            'Version 1.0.0 • TSHK Compass Subscription Edition',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      );
}

class _DeleteAccountDialog extends ConsumerStatefulWidget {
  const _DeleteAccountDialog();

  @override
  ConsumerState<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends ConsumerState<_DeleteAccountDialog> {
  final TextEditingController _confirmation = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (_confirmation.text.trim() != 'DELETE') {
      setState(() => _error = 'Type DELETE to confirm.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(appApiClientProvider).deleteAccount();
      await CompassController.clearSavedManualCoordinates();
      try {
        await ref.read(supabaseClientProvider).auth.signOut();
      } catch (_) {
        // The account has already been deleted; some providers reject remote sign-out.
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      context.go('/');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your TSHK Compass account has been deleted.')),
      );
    } on AppApiException catch (error) {
      setState(() => _error = error.message);
    } catch (_) {
      setState(() => _error = 'Account deletion could not be completed. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Delete your account?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'This permanently deletes your TSHK Compass account, membership profile, and linked payment records from the app database. It cannot be undone. PayFast may retain transaction records under its own legal and privacy obligations.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _confirmation,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'Type DELETE to confirm'),
              ),
              if (_error != null) ...<Widget>[
                const SizedBox(height: 10),
                Semantics(
                  liveRegion: true,
                  child: Text(_error!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
              ],
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: const Text('Keep account'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: _busy ? null : _delete,
            child: _busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Delete account'),
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
            'TSHK Compass uses your email to authenticate and maintain your membership. '
            'Precise location is requested only while the app is in use and is used on-device '
            'to calculate direction to Ekuphumuleni. If location permission is denied, you can '
            'enter coordinates manually. Manual coordinates are stored in local app preferences '
            'and may be included in device backups according to your OS settings. Raw compass '
            'sensor readings are processed on your device. Membership and payment references '
            'are processed by the API and PayFast. Account deletion removes your app account and '
            'linked database records; PayFast may retain transaction records separately under its '
            'own legal and privacy obligations. You can change or withdraw location permission '
            'in your device settings.',
          ),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      );
}
