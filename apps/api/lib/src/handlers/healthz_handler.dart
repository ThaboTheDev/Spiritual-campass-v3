import 'package:shelf/shelf.dart';

import '../http/json_response.dart';

Handler healthzHandler() => (Request request) => jsonResponse(
      200,
      <String, Object?>{'status': 'ok'},
      headers: <String, Object>{'cache-control': 'no-store'},
    );
