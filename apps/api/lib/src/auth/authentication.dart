import 'package:shelf/shelf.dart';
import 'package:tshk_core/tshk_core.dart';

import '../http/json_response.dart';
import 'jwt_verifier.dart';

Future<AuthPrincipal> requirePrincipal(
  Request request,
  JwtVerifier verifier, {
  required Clock clock,
}) async {
  final String? authorization = request.headers['authorization'];
  if (authorization == null || !authorization.startsWith('Bearer ')) {
    throw const ApiException(401, 'unauthorized', 'Sign in to continue.');
  }
  final String token = authorization.substring('Bearer '.length).trim();
  if (token.isEmpty || token.length > 8192) {
    throw const ApiException(401, 'unauthorized', 'Sign in to continue.');
  }
  try {
    return verifier.verify(token, now: clock.now().toUtc());
  } on JwtVerificationException {
    throw const ApiException(401, 'unauthorized', 'Your session is invalid or has expired.');
  }
}
