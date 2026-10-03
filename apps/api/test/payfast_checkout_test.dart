import 'package:test/test.dart';
import 'package:tshk_api/tshk_api.dart';
import 'package:tshk_core/tshk_core.dart';

void main() {
  test('checkout uses a free initial period and R100 monthly renewals', () {
    final DateTime now = DateTime.utc(2026, 1, 1, 12);
    final PayFastCheckout checkout = PayFastCheckout(
      ApiConfig(
        supabaseUrl: Uri.parse('https://project.example.test'),
        supabaseServiceRoleKey: 'server-secret',
        supabaseJwtSecret: 'test-secret-at-least-thirty-two-characters-long',
        pwaOrigin: Uri.parse('https://compass.example.test'),
        apiBaseUrl: Uri.parse('https://api.example.test'),
        payFastMerchantId: '10000100',
        payFastMerchantKey: 'merchant-key',
        payFastPassphrase: 'secret phrase',
        payFastSandbox: true,
        payFastIpCidrs: const <String>['197.97.145.144/28'],
        trustedProxyCidrs: const <String>['35.191.0.0/16'],
        port: 8080,
        maxBodyBytes: 65536,
        environment: 'test',
      ),
      FixedClock(now),
    );
    const MemberRecord member = MemberRecord(
      id: '550e8400-e29b-41d4-a716-446655440000',
      email: 'member@example.test',
      status: MemberStatus.trialing,
      trialEndsAt: DateTime.utc(2026, 1, 8, 10),
      paidThrough: null,
      isAdmin: false,
    );

    final Map<String, Object?> fields = checkout.createFields(
      member: member,
      pwaOrigin: Uri.parse('https://compass.example.test'),
    );
    expect(fields['amount'], '0.00');
    expect(fields['subscription_type'], '1');
    expect(fields['frequency'], '3');
    expect(fields['cycles'], '0');
    expect(fields['recurring_amount'], '100.00');
    expect(fields['billing_date'], '2026-01-08');
    expect(fields['custom_str1'], member.id);
    expect(fields['notify_url'], 'https://api.example.test/api/payfast/notify');
    expect(fields['return_url'], 'https://compass.example.test/?checkout=return');
    expect(fields['cancel_url'], 'https://compass.example.test/?checkout=cancel');
    expect(fields, isNot(contains('passphrase')));

    final List<FormFieldPair> pairs = <FormFieldPair>[
      for (final MapEntry<String, Object?> entry in fields.entries)
        if (entry.key != 'signature') FormFieldPair(entry.key, entry.value! as String),
    ];
    expect(
      PayFastSignature.verify(
        pairs,
        passphrase: 'secret phrase',
        receivedSignature: fields['signature']! as String,
      ),
      isTrue,
    );
  });

  test('expired trial starts billing on checkout day rather than backdating', () {
    final PayFastCheckout checkout = PayFastCheckout(
      ApiConfig(
        supabaseUrl: Uri.parse('https://project.example.test'),
        supabaseServiceRoleKey: 'server-secret',
        supabaseJwtSecret: 'test-secret-at-least-thirty-two-characters-long',
        pwaOrigin: Uri.parse('https://compass.example.test'),
        apiBaseUrl: Uri.parse('https://api.example.test'),
        payFastMerchantId: '10000100',
        payFastMerchantKey: 'merchant-key',
        payFastPassphrase: 'secret',
        payFastSandbox: false,
        payFastIpCidrs: const <String>['197.97.145.144/28'],
        trustedProxyCidrs: const <String>['35.191.0.0/16'],
        port: 8080,
        maxBodyBytes: 65536,
        environment: 'test',
      ),
      FixedClock(DateTime.utc(2026, 2, 3, 23)),
    );
    const MemberRecord member = MemberRecord(
      id: '550e8400-e29b-41d4-a716-446655440000',
      email: null,
      status: MemberStatus.expired,
      trialEndsAt: DateTime.utc(2026, 1, 8),
      paidThrough: null,
      isAdmin: false,
    );
    expect(
      checkout.createFields(member: member, pwaOrigin: Uri.parse('https://compass.example.test'))[
          'billing_date'],
      '2026-02-03',
    );
  });
}
