import 'dart:convert';

import 'package:crypto/crypto.dart';

class AuthPrincipal {
  const AuthPrincipal({required this.id, required this.email});

  final String id;
  final String? email;
}

class JwtVerificationException implements Exception {
  const JwtVerificationException(this.reason);

  final String reason;
}

class JwtVerifier {
  JwtVerifier({required this.secret, this.expectedAudience = 'authenticated'});

  final String secret;
  final String expectedAudience;

  AuthPrincipal verify(String token, {required DateTime now}) {
    final List<String> parts = token.split('.');
    if (parts.length != 3) throw const JwtVerificationException('malformed_token');

    final Map<String, Object?> header = _decodeObject(parts[0]);
    if (header['alg'] != 'HS256' || header['typ'] != 'JWT') {
      throw const JwtVerificationException('unsupported_algorithm');
    }
    final Hmac hmac = Hmac(sha256, utf8.encode(secret));
    final String expected = base64Url
        .encode(hmac.convert(utf8.encode('${parts[0]}.${parts[1]}')).bytes)
        .replaceAll('=', '');
    if (!_constantTimeEquals(expected, parts[2])) {
      throw const JwtVerificationException('invalid_signature');
    }

    final Map<String, Object?> claims = _decodeObject(parts[1]);
    final Object? audience = claims['aud'];
    final bool audienceValid = switch (audience) {
      String value => value == expectedAudience,
      List<Object?> values => values.contains(expectedAudience),
      _ => false,
    };
    if (!audienceValid) throw const JwtVerificationException('invalid_audience');

    final Object? subject = claims['sub'];
    if (subject is! String || !_isUuid(subject)) {
      throw const JwtVerificationException('invalid_subject');
    }
    final Object? expiry = claims['exp'];
    if (expiry is! num || !expiry.isFinite) {
      throw const JwtVerificationException('missing_expiry');
    }
    final int nowSeconds = now.toUtc().millisecondsSinceEpoch ~/ 1000;
    if (expiry.toInt() <= nowSeconds) {
      throw const JwtVerificationException('expired_token');
    }
    final Object? notBefore = claims['nbf'];
    if (notBefore is num && notBefore.toInt() > nowSeconds) {
      throw const JwtVerificationException('token_not_yet_valid');
    }

    final Object? emailClaim = claims['email'];
    return AuthPrincipal(
      id: subject,
      email: emailClaim is String ? emailClaim : null,
    );
  }

  static Map<String, Object?> _decodeObject(String segment) {
    try {
      final List<int> bytes = base64Url.decode(base64Url.normalize(segment));
      final Object? decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is Map<String, Object?>) return decoded;
    } on FormatException {
      throw const JwtVerificationException('malformed_token');
    }
    throw const JwtVerificationException('malformed_token');
  }

  static bool _constantTimeEquals(String left, String right) {
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

  static bool _isUuid(String value) => RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
      ).hasMatch(value);
}
