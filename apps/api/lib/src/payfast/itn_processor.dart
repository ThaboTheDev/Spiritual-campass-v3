import 'dart:convert';

import 'package:tshk_core/tshk_core.dart';

import '../config.dart';
import '../data/compass_repository.dart';
import '../security/ip_network.dart';
import 'field_parser.dart';
import 'server_validator.dart';
import 'signature.dart';

class ItnOutcome {
  const ItnOutcome({
    required this.accepted,
    required this.duplicate,
    required this.reason,
    required this.paymentId,
    required this.status,
  });

  final bool accepted;
  final bool duplicate;
  final String reason;
  final String? paymentId;
  final String? status;
}

class PayFastItnProcessor {
  PayFastItnProcessor({
    required ApiConfig config,
    required CompassRepository repository,
    required PayFastServerValidator serverValidator,
    required Clock clock,
  })  : _config = config,
        _repository = repository,
        _serverValidator = serverValidator,
        _clock = clock,
        _allowedIps = IpAllowList(config.payFastIpCidrs);

  final ApiConfig _config;
  final CompassRepository _repository;
  final PayFastServerValidator _serverValidator;
  final Clock _clock;
  final IpAllowList _allowedIps;

  Future<ItnOutcome> process({
    required List<FormFieldPair> fields,
    required String sourceIp,
  }) async {
    final String? signature = fieldValue(fields, 'signature');
    if (signature == null || signature.isEmpty || fields.last.name != 'signature') {
      return _reject('invalid_signature_order', fields);
    }
    if (!PayFastSignature.verify(
      fields,
      passphrase: _config.payFastPassphrase,
      receivedSignature: signature,
    )) {
      return _reject('signature_mismatch', fields);
    }

    if (!_allowedIps.contains(sourceIp)) {
      return _reject('source_ip_rejected', fields);
    }

    final Map<String, String> values = fieldMap(fields);
    if (values['merchant_id'] != _config.payFastMerchantId) {
      return _reject('merchant_mismatch', fields);
    }
    final int? amountCents = _parseCents(values['amount_gross']);
    if (amountCents == null || (amountCents != 0 && amountCents != 10000)) {
      return _reject('amount_mismatch', fields);
    }
    final String? status = values['payment_status'];
    if (status == null ||
        !const <String>{'COMPLETE', 'FAILED', 'PENDING', 'CANCELLED'}
            .contains(status)) {
      return _reject('unsupported_payment_status', fields);
    }
    final String? paymentId = values['pf_payment_id'];
    final String? memberId = values['custom_str1'];
    if (paymentId == null || paymentId.isEmpty || paymentId.length > 100) {
      return _reject('missing_payment_id', fields);
    }
    if (memberId == null || !_isUuid(memberId)) {
      return _reject('invalid_member_id', fields);
    }

    final String parameterString = PayFastSignature.parameterString(fields);
    final bool remotelyValid = await _serverValidator.validate(
      _config.payFastValidationUrl,
      parameterString,
    );
    if (!remotelyValid) return _reject('payfast_validation_failed', fields);

    final bool trialSetup = status == 'COMPLETE' && amountCents == 0;
    final Map<String, Object?> safeRaw = _safeRawFields(fields);
    final bool inserted = await _repository.applyPayFastItn(
      paymentId: paymentId,
      memberId: memberId,
      amountCents: amountCents,
      status: status,
      raw: safeRaw,
      token: values['token'],
      trialSetup: trialSetup,
      now: _clock.now().toUtc(),
    );
    return ItnOutcome(
      accepted: true,
      duplicate: !inserted,
      reason: inserted ? 'applied' : 'duplicate',
      paymentId: paymentId,
      status: status,
    );
  }

  ItnOutcome _reject(String reason, List<FormFieldPair> fields) => ItnOutcome(
        accepted: false,
        duplicate: false,
        reason: reason,
        paymentId: fieldValue(fields, 'pf_payment_id'),
        status: fieldValue(fields, 'payment_status'),
      );

  static int? _parseCents(String? value) {
    if (value == null || !RegExp(r'^\d{1,8}(?:\.\d{1,2})?$').hasMatch(value)) {
      return null;
    }
    final List<String> parts = value.split('.');
    final int? units = int.tryParse(parts[0]);
    if (units == null) return null;
    final String decimals = (parts.length == 1 ? '' : parts[1]).padRight(2, '0');
    return units * 100 + (decimals.isEmpty ? 0 : int.parse(decimals));
  }

  static bool _isUuid(String value) => RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
      ).hasMatch(value);

  static Map<String, Object?> _safeRawFields(List<FormFieldPair> fields) {
    final Map<String, Object?> raw = <String, Object?>{};
    for (final FormFieldPair field in fields) {
      final String key = field.name.toLowerCase();
      if (key == 'signature' ||
          key.contains('card') ||
          key.contains('cvv') ||
          key.contains('cvc') ||
          key.contains('pan') ||
          key.contains('passphrase')) {
        continue;
      }
      raw[field.name] = field.value;
    }
    // Ensure this stays JSON-compatible before passing the payload to Postgres.
    jsonEncode(raw);
    return raw;
  }
}
