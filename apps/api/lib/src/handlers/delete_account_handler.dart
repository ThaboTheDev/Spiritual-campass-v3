import 'package:shelf/shelf.dart';
import 'package:tshk_core/tshk_core.dart';

import '../auth/jwt_verifier.dart';
import '../data/compass_repository.dart';
import '../http/handler_auth.dart';
import '../http/json_response.dart';

Handler deleteAccountHandler({
  required JwtVerifier jwtVerifier,
  required CompassRepository repository,
  required Clock clock,
}) =>
    (Request request) async {
      final AuthenticatedMember authenticated = await authenticatedMember(
        request: request,
        jwtVerifier: jwtVerifier,
        repository: repository,
        clock: clock,
      );
      await repository.deleteAuthUser(authenticated.principal.id);
      return jsonResponse(200, <String, Object?>{'deleted': true});
    };
