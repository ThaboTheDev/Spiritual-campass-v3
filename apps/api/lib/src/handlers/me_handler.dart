import 'package:shelf/shelf.dart';
import 'package:tshk_core/tshk_core.dart';

import '../auth/jwt_verifier.dart';
import '../data/compass_repository.dart';
import '../http/handler_auth.dart';
import '../http/json_response.dart';

Handler meHandler({
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
      final EntitlementResult entitlement = const EntitlementPolicy().evaluate(
        authenticated.member,
        now: clock.now().toUtc(),
      );
      return jsonResponse(200, entitlement.toJson());
    };
