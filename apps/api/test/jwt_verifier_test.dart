import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:test/test.dart';
import 'package:tshk_api/tshk_api.dart';

const String _secret = 'test-secret-at-least-thirty-two-characters-long';
const String _subject = '550e8400-e29b-41d4-a716-446655440000';

String _token({
  String algorithm = 'HS256',
  String audience = 'authenticated',
  int expiry = 1900000000,
  String subject = _subject,
}) {
  final String header = _encode(<String, Object?>{'alg': algorithm, 'typ': 'JWT'});
  final String payload = _encode(<String, Object?>{
    'aud': audience,
    'exp': expiry,
    'sub': subject,
    'email': 'member@example.test',
  });
  final String signingInput = '$header.$payload';
  final String signature = base64Url
      .encode(Hmac(sha256, utf8.encode(_secret)).convert(utf8.encode(signingInput)).bytes)
      .replaceAll('=', '');
  return '$signingInput.$signature';
}

String _encode(Object value) =>
    base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');

void main() {
  final JwtVerifier verifier = JwtVerifier(secret: _secret);

  test('valid HS256 Supabase claim returns subject and email', () {
    final AuthPrincipal principal = verifier.verify(
      _token(),
      now: DateTime.utc(2026, 1, 1),
    );
    expect(principal.id, _subject);
    expect(principal.email, 'member@example.test');
  });

  test('rejects expiry, audience, algorithm, and malformed subject', () {
    expect(
      () => verifier.verify(_token(expiry: 1), now: DateTime.utc(2026)),
      throwsA(isA<JwtVerificationException>()),
    );
    expect(
      () => verifier.verify(_token(audience: 'anon'), now: DateTime.utc(2026)),
      throwsA(isA<JwtVerificationException>()),
    );
    expect(
      () => verifier.verify(_token(algorithm: 'none'), now: DateTime.utc(2026)),
      throwsA(isA<JwtVerificationException>()),
    );
    expect(
      () => verifier.verify(_token(subject: 'not-a-uuid'), now: DateTime.utc(2026)),
      throwsA(isA<JwtVerificationException>()),
    );
  });

  test('tampered payload is rejected', () {
    final String token = _token();
    final List<String> parts = token.split('.');
    final String altered = _encode(<String, Object?>{
      'aud': 'authenticated',
      'exp': 1900000000,
      'sub': _subject,
      'email': 'attacker@example.test',
    });
    expect(
      () => verifier.verify('${parts[0]}.$altered.${parts[2]}',
          now: DateTime.utc(2026)),
      throwsA(isA<JwtVerificationException>()),
    );
  });
}
