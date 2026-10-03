import 'package:http/http.dart' as http;
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:supabase/supabase.dart';
import 'package:tshk_core/tshk_core.dart';
import 'package:uuid/uuid.dart';

import 'src/auth/jwt_verifier.dart';
import 'src/config.dart';
import 'src/data/compass_repository.dart';
import 'src/handlers/centres_handler.dart';
import 'src/handlers/delete_account_handler.dart';
import 'src/handlers/healthz_handler.dart';
import 'src/handlers/me_handler.dart';
import 'src/handlers/payfast_checkout_handler.dart';
import 'src/handlers/payfast_notify_handler.dart';
import 'src/http/json_response.dart';
import 'src/http/middleware.dart';
import 'src/payfast/checkout.dart';
import 'src/payfast/itn_processor.dart';
import 'src/payfast/server_validator.dart';
import 'src/security/client_ip.dart';

Handler createApiHandler({
  required ApiConfig config,
  required CompassRepository repository,
  required PayFastServerValidator serverValidator,
  Clock clock = const SystemClock(),
  Uuid? uuid,
}) {
  final JwtVerifier jwtVerifier = JwtVerifier(secret: config.supabaseJwtSecret);
  final ClientIpResolver ipResolver =
      ClientIpResolver(trustedProxyCidrs: config.trustedProxyCidrs);
  final PayFastCheckout checkout = PayFastCheckout(config, clock, uuid: uuid);
  final PayFastItnProcessor itnProcessor = PayFastItnProcessor(
    config: config,
    repository: repository,
    serverValidator: serverValidator,
    clock: clock,
  );

  final Router router = Router()
    ..get('/healthz', healthzHandler())
    ..get(
      '/api/me',
      meHandler(jwtVerifier: jwtVerifier, repository: repository, clock: clock),
    )
    ..get(
      '/api/centres',
      centresHandler(jwtVerifier: jwtVerifier, repository: repository, clock: clock),
    )
    ..post(
      '/api/payfast/checkout',
      payFastCheckoutHandler(
        config: config,
        jwtVerifier: jwtVerifier,
        repository: repository,
        checkout: checkout,
        clock: clock,
      ),
    )
    ..post(
      '/api/payfast/notify',
      payFastNotifyHandler(processor: itnProcessor, ipResolver: ipResolver),
    )
    ..delete(
      '/api/account/delete',
      deleteAccountHandler(
        jwtVerifier: jwtVerifier,
        repository: repository,
        clock: clock,
      ),
    );

  Future<Response> withJsonNotFound(Request request) async {
    final Response response = await router(request);
    if (response.statusCode != 404) return response;
    return jsonResponse(404, <String, Object?>{
      'error': <String, Object?>{
        'code': 'not_found',
        'message': 'The requested endpoint was not found.',
      },
    });
  }

  final ServerMiddleware middleware = ServerMiddleware(
    config: config,
    ipResolver: ipResolver,
    clock: clock,
  );
  return const Pipeline()
      .addMiddleware(middleware.requestId)
      .addMiddleware(middleware.errorEnvelope)
      .addMiddleware(middleware.cors)
      .addMiddleware(middleware.bodySizeLimit)
      .addMiddleware(middleware.rateLimit)
      .addMiddleware(middleware.requestLogger)
      .addHandler(withJsonNotFound);
}

Handler createProductionHandler({
  required ApiConfig config,
  Clock clock = const SystemClock(),
}) {
  final SupabaseClient client = SupabaseClient(
    config.supabaseUrl.toString(),
    config.supabaseServiceRoleKey,
  );
  final CompassRepository repository = SupabaseCompassRepository(client);
  final http.Client httpClient = http.Client();
  return createApiHandler(
    config: config,
    repository: repository,
    serverValidator: HttpPayFastServerValidator(httpClient),
    clock: clock,
  );
}
