import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shelf/shelf.dart';
import 'package:tshk_core/tshk_core.dart';

import '../auth/jwt_verifier.dart';
import '../data/compass_repository.dart';
import '../http/handler_auth.dart';

Handler centresHandler({
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
      requireAccess(authenticated.member, clock);

      final List<CentreRow> rows = await repository.listCentres();
      final Map<String, List<Map<String, Object?>>> groups =
          <String, List<Map<String, Object?>>>{};
      for (final CentreRow row in rows) {
        groups.putIfAbsent(row.region, () => <Map<String, Object?>>[]).add(row.toJson());
      }
      final Map<String, Object?> payload = <String, Object?>{
        'regions': <Map<String, Object?>>[
          for (final String region in (groups.keys.toList()..sort()))
            <String, Object?>{'region': region, 'centres': groups[region]},
        ],
        'count': rows.length,
      };
      final String body = jsonEncode(payload);
      final String etag = '"${sha256.convert(utf8.encode(body))}"';
      if (request.headers['if-none-match'] == etag) {
        return Response.notModified(
          headers: <String, Object>{
            'etag': etag,
            'cache-control': 'private, max-age=300',
            'vary': 'Authorization',
          },
        );
      }
      return Response.ok(
        body,
        headers: <String, Object>{
          'content-type': 'application/json; charset=utf-8',
          'cache-control': 'private, max-age=300',
          'etag': etag,
          'vary': 'Authorization',
        },
      );
    };
