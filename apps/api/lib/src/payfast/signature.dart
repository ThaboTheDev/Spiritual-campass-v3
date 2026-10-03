import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

class FormFieldPair {
  const FormFieldPair(this.name, this.value);

  final String name;
  final String value;
}

class PayFastSignature {
  const PayFastSignature._();

  /// Builds the documented custom-checkout signature string in the exact
  /// insertion order supplied. Empty values are omitted; values and the
  /// passphrase are trimmed and encoded as application/x-www-form-urlencoded.
  static String parameterString(
    Iterable<FormFieldPair> fields, {
    String? passphrase,
    bool includeSignature = false,
  }) {
    final List<String> parts = <String>[];
    for (final FormFieldPair field in fields) {
      if (!includeSignature && field.name == 'signature') continue;
      final String value = field.value.trim();
      if (value.isEmpty) continue;
      parts.add('${field.name}=${formUrlEncode(value)}');
    }
    if (passphrase != null) {
      parts.add('passphrase=${formUrlEncode(passphrase.trim())}');
    }
    return parts.join('&');
  }

  static String sign(
    Iterable<FormFieldPair> fields, {
    required String passphrase,
  }) {
    final String input = parameterString(fields, passphrase: passphrase);
    return md5.convert(utf8.encode(input)).toString();
  }

  static bool verify(
    Iterable<FormFieldPair> fields, {
    required String passphrase,
    required String receivedSignature,
  }) {
    return constantTimeEquals(
      sign(fields, passphrase: passphrase),
      receivedSignature.toLowerCase(),
    );
  }

  static String formUrlEncode(String value) {
    const String hex = '0123456789ABCDEF';
    final Uint8List bytes = Uint8List.fromList(utf8.encode(value));
    final StringBuffer output = StringBuffer();
    for (final int byte in bytes) {
      final bool unreserved =
          (byte >= 0x41 && byte <= 0x5A) ||
          (byte >= 0x61 && byte <= 0x7A) ||
          (byte >= 0x30 && byte <= 0x39) ||
          byte == 0x2D ||
          byte == 0x2E ||
          byte == 0x5F;
      if (byte == 0x20) {
        output.write('+');
      } else if (unreserved) {
        output.writeCharCode(byte);
      } else {
        output
          ..write('%')
          ..write(hex[(byte >> 4) & 0x0F])
          ..write(hex[byte & 0x0F]);
      }
    }
    return output.toString();
  }

  static List<FormFieldPair> parseOrderedForm(String body) {
    if (body.isEmpty) throw const FormatException('Empty form body');
    final List<FormFieldPair> fields = <FormFieldPair>[];
    final Set<String> names = <String>{};
    for (final String component in body.split('&')) {
      if (component.isEmpty) throw const FormatException('Empty form field');
      final int separator = component.indexOf('=');
      if (separator <= 0) throw const FormatException('Malformed form field');
      final String name;
      final String value;
      try {
        name = Uri.decodeQueryComponent(component.substring(0, separator));
        value = Uri.decodeQueryComponent(component.substring(separator + 1));
      } on ArgumentError {
        throw FormatException('Invalid URL encoding in form field', component);
      }
      if (name.isEmpty || !names.add(name)) {
        throw const FormatException('Empty or duplicate form field name');
      }
      fields.add(FormFieldPair(name, value));
    }
    return List<FormFieldPair>.unmodifiable(fields);
  }

  static bool constantTimeEquals(String left, String right) {
    final List<int> a = utf8.encode(left);
    final List<int> b = utf8.encode(right);
    int difference = a.length ^ b.length;
    final int length = a.length > b.length ? a.length : b.length;
    for (int index = 0; index < length; index++) {
      difference |= (index < a.length ? a[index] : 0) ^
          (index < b.length ? b[index] : 0);
    }
    return difference == 0;
  }
}
