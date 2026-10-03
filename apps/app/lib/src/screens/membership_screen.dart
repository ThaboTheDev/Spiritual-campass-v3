import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tshk_core/tshk_core.dart';

import '../config/app_config.dart';
import '../data/app_models.dart';
import '../providers/app_providers.dart';
import 'checkout_screen.dart';

class MembershipScreen extends ConsumerStatefulWidget {
  const MembershipScreen({super.key});

  @override
  ConsumerState<MembershipScreen> createState() => _MembershipScreenState();
}

class _MembershipScreenState extends ConsumerState<MembershipScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _startCheckout() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final CheckoutSession checkout =
          await ref.read(appApiClientProvider).createCheckout();
      if (!mounted) return;
      context.push('/checkout', extra: CheckoutScreenArgs(checkout));
    } on AppApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Checkout could not be started. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppConfig config = ref.watch(appConfigProvider);
    final AsyncValue<MemberSnapshot> member = ref.watch(entitlementProvider);
    return member.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object error, StackTrace stackTrace) => _MembershipError(
        onRetry: () => ref.invalidate(entitlementProvider),
      ),
      data: (MemberSnapshot value) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
        children: <Widget>[
          Text('Membership', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          const Text('Manage your TSHK Compass access.'),
          const SizedBox(height: 18),
          _StatusCard(member: value),
          const SizedBox(height: 14),
          if (config.storeBuild)
            const _StoreBuildNotice()
          else ...<Widget>[
            const _WebBillingTerms(),
            const SizedBox(height: 14),
            if (value.status == MemberStatus.trialing || !value.hasAccess)
              FilledButton.icon(
                onPressed: _busy ? null : _startCheckout,
                icon: const Icon(Icons.lock_outline),
                label: Text(_busy ? 'Connecting to PayFast…' : 'Continue with PayFast'),
              ),
            if (value.hasAccess && value.status == MemberStatus.active)
              _ManageBillingNotice(supportEmail: config.supportEmail),
            if (_error != null) ...<Widget>[
              const SizedBox(height: 10),
              Semantics(
                liveRegion: true,
                child: Text(_error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'Payment status is updated after PayFast sends a verified server notification. If you just paid, return here and refresh in a moment.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.member});

  final MemberSnapshot member;

  @override
  Widget build(BuildContext context) {
    final Color color = member.hasAccess
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.error;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(member.hasAccess ? Icons.verified_outlined : Icons.lock_outline,
                    color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    member.hasAccess ? 'Access is active' : 'Access is not active',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(color: color),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Status: ${_statusLabel(member.status)}'),
            const SizedBox(height: 4),
            Text(
              member.status == MemberStatus.trialing
                  ? 'Trial ends ${_formatDate(member.trialEndsAt)}'
                  : member.paidThrough == null
                      ? 'No paid-through date is recorded.'
                      : 'Paid through ${_formatDate(member.paidThrough!)}',
            ),
            if (member.graceEndsAt != null && member.reason == 'payment_grace') ...<Widget>[
              const SizedBox(height: 4),
              Text('Payment grace ends ${_formatDate(member.graceEndsAt!)}'),
            ],
          ],
        ),
      ),
    );
  }
}

class _WebBillingTerms extends StatelessWidget {
  const _WebBillingTerms();

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Subscription details', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              const Text(
                'The initial seven-day period is R0.00. After the trial, the subscription renews at R100.00 every month until cancelled. Payment is processed securely by PayFast.',
              ),
              const SizedBox(height: 8),
              Text(
                'By continuing, you agree to the recurring billing described above. Check the PayFast page before confirming your payment method.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );
}

class _StoreBuildNotice extends StatelessWidget {
  const _StoreBuildNotice();

  @override
  Widget build(BuildContext context) => const Card(
        child: Padding(
          padding: EdgeInsets.all(18),
          child: Text(
            'Billing is managed by the store for this version of the app. Open your store account subscription settings to manage it.',
          ),
        ),
      );
}

class _ManageBillingNotice extends StatelessWidget {
  const _ManageBillingNotice({required this.supportEmail});

  final String supportEmail;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Text(supportEmail.isEmpty
              ? 'Your membership is active. To cancel a PayFast recurring subscription, contact the TSHK support team before your next renewal. Publish a monitored support contact before launch.'
              : 'Your membership is active. To cancel a PayFast recurring subscription, contact $supportEmail before your next renewal.'),
        ),
      );
}

class _MembershipError extends StatelessWidget {
  const _MembershipError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.cloud_off_outlined, size: 42),
              const SizedBox(height: 12),
              Text('Membership unavailable', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text('We could not load your account status.'),
              const SizedBox(height: 14),
              OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
            ],
          ),
        ),
      );
}

String _formatDate(DateTime value) {
  final DateTime local = value.toLocal();
  const List<String> months = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${local.day} ${months[local.month - 1]} ${local.year}';
}

String _statusLabel(MemberStatus status) => switch (status) {
      MemberStatus.trialing => 'Trial',
      MemberStatus.active => 'Active',
      MemberStatus.cancelled => 'Cancelled',
      MemberStatus.expired => 'Expired',
    };
