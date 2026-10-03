import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';

import '../payfast/itn_processor.dart';
import '../payfast/signature.dart';
import '../security/client_ip.dart';
import '../http/json_response.dart';

Handler payFastNotifyHandler({
  required PayFastItnProcessor processor,
  required ClientIpResolver ipResolver,
}) =>
    (Request request) async {
      final String mediaType =
          (request.headers['content-type'] ?? '').split(';').first.trim().toLowerCase();
      if (mediaType != 'application/x-www-form-urlencoded') {
        return jsonResponse(415, <String, Object?>{
          'error': <String, Object?>{'code': 'unsupported_media_type'},
        });
      }

      late final List<FormFieldPair> fields;
      try {
        fields = PayFastSignature.parseOrderedForm(await request.readAsString());
      } on FormatException {
        return jsonResponse(400, <String, Object?>{
          'error': <String, Object?>{'code': 'malformed_form'},
        });
      }

      final String sourceIp = ipResolver.resolve(request);
      try {
        final ItnOutcome outcome = await processor.process(
          fields: fields,
          sourceIp: sourceIp,
        );
        _logOutcome(request, sourceIp, outcome.reason, outcome.paymentId, outcome.status);
      } catch (error) {
        stderr.writeln(jsonEncode(<String, Object?>{
          'event': 'payfast_itn',
          'requestId': request.context['requestId'] ?? 'unknown',
          'sourceIp': sourceIp,
          'outcome': 'processing_error',
          'errorType': error.runtimeType.toString(),
        }));
      }

      // PayFast treats a non-200 response as a retry request. Once the form is
      // syntactically valid, all verification failures are logged and acked.
      return Response.ok(
        'OK',
        headers: const <String, Object>{'content-type': 'text/plain; charset=utf-8'},
      );
    };

void _logOutcome(
  Request request,
  String sourceIp,
  String outcome,
  String? paymentId,
  String? status,
) {
  stderr.writeln(jsonEncode(<String, Object?>{
    'event': 'payfast_itn',
    'requestId': request.context['requestId'] ?? 'unknown',
    'sourceIp': sourceIp,
    'outcome': outcome,
    'paymentId': paymentId,
    'status': status,
  }));
}
