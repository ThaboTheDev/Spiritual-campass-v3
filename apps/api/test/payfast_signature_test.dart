import 'package:test/test.dart';
import 'package:tshk_api/tshk_api.dart';

void main() {
  test('documented custom form signature vector uses ordered fields and plus spaces', () {
    final List<FormFieldPair> fields = <FormFieldPair>[
      const FormFieldPair('merchant_id', '10000100'),
      const FormFieldPair('name_first', 'A B'),
      const FormFieldPair('empty', ''),
      const FormFieldPair('email_address', 'user+tag@example.org'),
      const FormFieldPair('amount', '100.00'),
      const FormFieldPair('item_name', 'TSHK Compass'),
    ];
    expect(
      PayFastSignature.parameterString(fields, passphrase: 'salt phrase'),
      'merchant_id=10000100&name_first=A+B&email_address=user%2Btag%40example.org&amount=100.00&item_name=TSHK+Compass&passphrase=salt+phrase',
    );
    expect(
      PayFastSignature.sign(fields, passphrase: 'salt phrase'),
      '9b65199d297d268bbbca9a53a02d2d9c',
    );
  });

  test('URL encoding matches form encoding for UTF-8 and reserved characters', () {
    expect(PayFastSignature.formUrlEncode('x y+z'), 'x+y%2Bz');
    expect(PayFastSignature.formUrlEncode('Māori'), 'M%C4%81ori');
    expect(PayFastSignature.formUrlEncode("~!()'"), '%7E%21%28%29%27');
  });

  test('ordered URL-encoded fields parse with spaces and retain order', () {
    final List<FormFieldPair> fields = PayFastSignature.parseOrderedForm(
      'name_first=First+Last&item_name=Compass%2BSubscription&amount=100.00',
    );
    expect(fields.map((FormFieldPair field) => field.name),
        <String>['name_first', 'item_name', 'amount']);
    expect(fields[0].value, 'First Last');
    expect(fields[1].value, 'Compass+Subscription');
  });

  test('duplicate and malformed form fields are rejected', () {
    expect(
      () => PayFastSignature.parseOrderedForm('amount=1&amount=2'),
      throwsFormatException,
    );
    expect(
      () => PayFastSignature.parseOrderedForm('amount'),
      throwsFormatException,
    );
    expect(
      () => PayFastSignature.parseOrderedForm('amount=%XY'),
      throwsFormatException,
    );
  });

  test('signature check detects tampering and runs constant-time comparison', () {
    final List<FormFieldPair> fields = <FormFieldPair>[
      const FormFieldPair('amount', '100.00'),
    ];
    final String signature = PayFastSignature.sign(fields, passphrase: 'secret');
    expect(
      PayFastSignature.verify(fields,
          passphrase: 'secret', receivedSignature: signature),
      isTrue,
    );
    expect(
      PayFastSignature.verify(<FormFieldPair>[
        const FormFieldPair('amount', '100.01'),
      ], passphrase: 'secret', receivedSignature: signature),
      isFalse,
    );
  });
}
