import 'package:shelf/shelf.dart';
import 'package:tshk_core/tshk_core.dart';

import '../auth/jwt_verifier.dart';
import '../config.dart';
import '../data/compass_repository.dart';
import '../http/handler_auth.dart';
import '../http/json_response.dart';
import '../payfast/checkout.dart';

Handler payFastCheckoutHandler({
  required ApiConfig config,
  required JwtVerifier jwtVerifier,
  required CompassRepository repository,
  required PayFastCheckout checkout,
  required Clock clock,
}) =>
    (Request request) async {
      final AuthenticatedMember authenticated = await authenticatedMember(
        request: request,
        jwtVerifier: jwtVerifier,
        repository: repository,
        clock: clock,
      );
      final Map<String, Object?> fields = checkout.createFields(
        member: authenticated.member,
        pwaOrigin: config.pwaOrigin,
      );
      return jsonResponse(
        200,
        <String, Object?>{
          'actionUrl': config.payFastActionUrl.toString(),
          'fields': fields,
        },
      );
    };
