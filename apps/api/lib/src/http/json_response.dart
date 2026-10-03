import 'dart:convert';

import 'package:shelf/shelf.dart';

Response jsonResponse(
  int statusCode,
  Object? body, {
  Map<String, Object>? headers,
}) =>
    Response(
      statusCode,
      body: jsonEncode(body),
      headers: <String, Object>{
        'content-type': 'application/json; charset=utf-8',
        'cache-control': 'no-store',
        ...?headers,
      },
    );

class ApiException implements Exception {
  const ApiException(this.statusCode, this.code, this.message);

  final int statusCode;
  final String code;
  final String message;
}
