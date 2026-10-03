import 'package:test/test.dart';
import 'package:tshk_api/tshk_api.dart';
import 'package:tshk_core/tshk_core.dart';

const String _memberId = '550e8400-e29b-41d4-a716-446655440000';
const String _passphrase = 'integration-test-passphrase';

ApiConfig _config() => ApiConfig(
      supabaseUrl: Uri.parse('https://project.example.test'),
      supabaseServiceRoleKey: 'server-only-key',
      supabaseJwtSecret: 'test-secret-at-least-thirty-two-characters-long',
      pwaOrigin: Uri.parse('https://compass.example.test'),
      apiBaseUrl: Uri.parse('https://api.example.test'),
      payFastMerchantId: '10000100',
      payFastMerchantKey: 'merchant-key',
      payFastPassphrase: _passphrase,
      payFastSandbox: true,
      payFastIpCidrs: const <String>['197.97.145.144/28'],
      trustedProxyCidrs: const <String>['35.191.0.0/16'],
      port: 8080,
      maxBodyBytes: 65536,
      environment: 'test',
    );

List<FormFieldPair> _notification({
  String merchant = '10000100',
  String status = 'COMPLETE',
  String amount = '0.00',
  String memberId = _memberId,
  String paymentId = 'pf-payment-1',
}) {
  final List<FormFieldPair> fields = <FormFieldPair>[
    FormFieldPair('m_payment_id', 'tshk-attempt-1'),
    FormFieldPair('pf_payment_id', paymentId),
    FormFieldPair('payment_status', status),
    const FormFieldPair('item_name', 'TSHK Compass'),
    FormFieldPair('amount_gross', amount),
    const FormFieldPair('amount_fee', '0.00'),
    FormFieldPair('amount_net', amount),
    FormFieldPair('custom_str1', memberId),
    const FormFieldPair('token', '00000000-0000-4000-8000-000000000001'),
    FormFieldPair('merchant_id', merchant),
  ];
  return <FormFieldPair>[
    ...fields,
    FormFieldPair(
      'signature',
      PayFastSignature.sign(fields, passphrase: _passphrase),
    ),
  ];
}

class _FakeValidator implements PayFastServerValidator {
  _FakeValidator(this.valid);

  bool valid;
  int calls = 0;
  String? lastParameterString;

  @override
  Future<bool> validate(Uri endpoint, String orderedParameterString) async {
    calls++;
    lastParameterString = orderedParameterString;
    return valid;
  }
}

class _FakeRepository implements CompassRepository {
  final Set<String> seen = <String>{};
  final List<Map<String, Object?>> saved = <Map<String, Object?>>[];

  @override
  Future<MemberRecord> ensureMember(AuthPrincipal principal) async => MemberRecord(
        id: principal.id,
        email: principal.email,
        status: MemberStatus.trialing,
        trialEndsAt: DateTime.utc(2026, 1, 8),
        paidThrough: null,
        isAdmin: false,
      );

  @override
  Future<List<CentreRow>> listCentres() async => const <CentreRow>[];

  @override
  Future<bool> applyPayFastItn({
    required String paymentId,
    required String memberId,
    required int amountCents,
    required String status,
    required Map<String, Object?> raw,
    required String? token,
    required bool trialSetup,
    required DateTime now,
  }) async {
    saved.add(<String, Object?>{
      'paymentId': paymentId,
      'memberId': memberId,
      'amountCents': amountCents,
      'status': status,
      'raw': raw,
      'token': token,
      'trialSetup': trialSetup,
      'now': now,
    });
    return seen.add(paymentId);
  }

  @override
  Future<void> deleteAuthUser(String memberId) async {}
}

void main() {
  late _FakeRepository repository;
  late _FakeValidator validator;
  late PayFastItnProcessor processor;
  final FixedClock clock = FixedClock(DateTime.utc(2026, 1, 4, 10));

  setUp(() {
    repository = _FakeRepository();
    validator = _FakeValidator(true);
    processor = PayFastItnProcessor(
      config: _config(),
      repository: repository,
      serverValidator: validator,
      clock: clock,
    );
  });

  test('valid free-trial ITN is verified then atomically recorded once', () async {
    final ItnOutcome outcome = await processor.process(
      fields: _notification(),
      sourceIp: '197.97.145.150',
    );
    expect(outcome.accepted, isTrue);
    expect(outcome.duplicate, isFalse);
    expect(outcome.reason, 'applied');
    expect(validator.calls, 1);
    expect(repository.saved, hasLength(1));
    expect(repository.saved.single['amountCents'], 0);
    expect(repository.saved.single['trialSetup'], isTrue);
    expect(repository.saved.single['now'], clock.now());
    expect(repository.saved.single['raw'], isNot(contains('signature')));
    expect(validator.lastParameterString, isNot(contains('signature=')));
  });

  test('valid paid renewal extends access through the transaction RPC', () async {
    final ItnOutcome outcome = await processor.process(
      fields: _notification(amount: '100.00', paymentId: 'pf-payment-2'),
      sourceIp: '197.97.145.150',
    );
    expect(outcome.accepted, isTrue);
    expect(repository.saved.single['amountCents'], 10000);
    expect(repository.saved.single['trialSetup'], isFalse);
  });

  test('duplicate ITN replay is harmless and does not apply twice', () async {
    final List<FormFieldPair> fields = _notification();
    final ItnOutcome first = await processor.process(
      fields: fields,
      sourceIp: '197.97.145.150',
    );
    final ItnOutcome second = await processor.process(
      fields: fields,
      sourceIp: '197.97.145.150',
    );
    expect(first.duplicate, isFalse);
    expect(second.duplicate, isTrue);
    expect(second.reason, 'duplicate');
    expect(repository.saved, hasLength(2));
  });

  test('FAILED, PENDING, and CANCELLED notifications are recorded without trial grant', () async {
    for (final String status in <String>['FAILED', 'PENDING', 'CANCELLED']) {
      final ItnOutcome outcome = await processor.process(
        fields: _notification(
          status: status,
          amount: '100.00',
          paymentId: 'pf-$status',
        ),
        sourceIp: '197.97.145.150',
      );
      expect(outcome.accepted, isTrue);
    }
    expect(repository.saved.map((Map<String, Object?> row) => row['status']),
        <String>['FAILED', 'PENDING', 'CANCELLED']);
    expect(repository.saved.every((Map<String, Object?> row) => row['trialSetup'] == false),
        isTrue);
  });

  test('bad signature rejects before IP or remote validation', () async {
    final List<FormFieldPair> invalid = <FormFieldPair>[
      ..._notification().take(10),
      const FormFieldPair('signature', '00000000000000000000000000000000'),
    ];
    final ItnOutcome outcome = await processor.process(
      fields: invalid,
      sourceIp: '197.97.145.150',
    );
    expect(outcome.reason, 'signature_mismatch');
    expect(validator.calls, 0);
    expect(repository.saved, isEmpty);
  });

  test('non-final signature is rejected', () async {
    final List<FormFieldPair> valid = _notification();
    final List<FormFieldPair> outOfOrder = <FormFieldPair>[
      ...valid.take(valid.length - 1),
      valid.last,
      const FormFieldPair('extra', 'changed'),
    ];
    final ItnOutcome outcome = await processor.process(
      fields: outOfOrder,
      sourceIp: '197.97.145.150',
    );
    expect(outcome.reason, 'invalid_signature_order');
  });

  test('rejects source IP not in the published PayFast ranges', () async {
    final ItnOutcome outcome = await processor.process(
      fields: _notification(),
      sourceIp: '8.8.8.8',
    );
    expect(outcome.reason, 'source_ip_rejected');
    expect(validator.calls, 0);
  });

  test('rejects merchant, amount, invalid member, and unknown statuses', () async {
    final List<({List<FormFieldPair> fields, String reason})> invalidCases =
        <({List<FormFieldPair> fields, String reason})>[
      (fields: _notification(merchant: '99999999'), reason: 'merchant_mismatch'),
      (fields: _notification(amount: '99.99'), reason: 'amount_mismatch'),
      (fields: _notification(memberId: 'not-a-uuid'), reason: 'invalid_member_id'),
      (fields: _notification(status: 'REFUNDED'), reason: 'unsupported_payment_status'),
    ];
    for (final value in invalidCases) {
      final ItnOutcome outcome = await processor.process(
        fields: value.fields,
        sourceIp: '197.97.145.150',
      );
      expect(outcome.reason, value.reason);
    }
    expect(validator.calls, 0);
    expect(repository.saved, isEmpty);
  });

  test('requires PayFast server validation to return VALID', () async {
    validator.valid = false;
    final ItnOutcome outcome = await processor.process(
      fields: _notification(),
      sourceIp: '197.97.145.150',
    );
    expect(outcome.reason, 'payfast_validation_failed');
    expect(validator.calls, 1);
    expect(repository.saved, isEmpty);
  });
}
