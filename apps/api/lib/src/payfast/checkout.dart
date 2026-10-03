import 'package:uuid/uuid.dart';

import 'package:tshk_core/tshk_core.dart';

import '../config.dart';
import 'signature.dart';

class PayFastCheckout {
  PayFastCheckout(this._config, this._clock, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final ApiConfig _config;
  final Clock _clock;
  final Uuid _uuid;

  Map<String, Object?> createFields({
    required MemberRecord member,
    required Uri pwaOrigin,
  }) {
    final DateTime now = _clock.now().toUtc();
    final DateTime trialEnd = member.trialEndsAt.toUtc();
    final DateTime chargeDate = trialEnd.isAfter(now) ? trialEnd : now;
    final String billingDate = _dateOnly(chargeDate);
    final List<FormFieldPair> fields = <FormFieldPair>[
      FormFieldPair('merchant_id', _config.payFastMerchantId),
      FormFieldPair('merchant_key', _config.payFastMerchantKey),
      FormFieldPair('return_url', _returnUri(pwaOrigin, 'return').toString()),
      FormFieldPair('cancel_url', _returnUri(pwaOrigin, 'cancel').toString()),
      FormFieldPair(
        'notify_url',
        _config.apiBaseUrl.resolve('/api/payfast/notify').toString(),
      ),
      if (member.email != null && member.email!.isNotEmpty)
        FormFieldPair('email_address', member.email!),
      FormFieldPair('m_payment_id', 'tshk-${_uuid.v4()}'),
      FormFieldPair('amount', '0.00'),
      FormFieldPair('item_name', 'TSHK Compass monthly subscription'),
      FormFieldPair('item_description', 'Seven-day free trial, then R100 monthly'),
      FormFieldPair('custom_str1', member.id),
      FormFieldPair('subscription_type', '1'),
      FormFieldPair('billing_date', billingDate),
      FormFieldPair('recurring_amount', '100.00'),
      FormFieldPair('frequency', '3'),
      FormFieldPair('cycles', '0'),
    ];
    final String signature =
        PayFastSignature.sign(fields, passphrase: _config.payFastPassphrase);
    final Map<String, Object?> result = <String, Object?>{
      for (final FormFieldPair field in fields) field.name: field.value,
      'signature': signature,
    };
    return result;
  }

  static Uri _returnUri(Uri origin, String state) =>
      origin.replace(queryParameters: <String, String>{'checkout': state});

  static String _dateOnly(DateTime value) {
    final DateTime utc = value.toUtc();
    final String month = utc.month.toString().padLeft(2, '0');
    final String day = utc.day.toString().padLeft(2, '0');
    return '${utc.year}-$month-$day';
  }
}
