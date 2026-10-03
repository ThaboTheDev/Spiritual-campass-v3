import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:shelf/shelf.dart';
import 'package:tshk_core/tshk_core.dart';
import 'package:uuid/uuid.dart';

import '../config.dart';
import '../security/client_ip.dart';
import 'json_response.dart';

class ServerMiddleware {
  ServerMiddleware({
    required ApiConfig config,
    required ClientIpResolver ipResolver,
    this.clock = const SystemClock(),
    this.window = const Duration(minutes: 1),
    this.maxRequestsPerWindow = 120,
  })  : _config = config,
        _ipResolver = ipResolver;

  final ApiConfig _config;
  final ClientIpResolver _ipResolver;
  final Clock clock;
  final Duration window;
  final int maxRequestsPerWindow;
  final Map<String, _RateWindow> _rateWindows = <String, _RateWindow>{};
  final Uuid _uuid = const Uuid();

  Middleware get requestId => (Handler innerHandler) {
        return (Request request) async {
          final String? supplied = request.headers['x-request-id'];
          final String id = supplied != null &&
                  RegExp(r'^[A-Za-z0-9._-]{1,80}$').hasMatch(supplied)
              ? supplied
              : _uuid.v4();
          final Request updated = request.change(
            context: <String, Object?>{...request.context, 'requestId': id},
          );
          final Response response = await innerHandler(updated);
          return response.change(
            headers: <String, Object>{...response.headers, 'x-request-id': id},
          );
        };
      };

  Middleware get errorEnvelope => (Handler innerHandler) {
        return (Request request) async {
          try {
            return await innerHandler(request);
          } on ApiException catch (error) {
            return _errorResponse(request, error.statusCode, error.code, error.message);
          } catch (error) {
            stderr.writeln(jsonEncode(<String, Object?>{
              'event': 'request_error',
              'requestId': request.context['requestId'] ?? 'unknown',
              'errorType': error.runtimeType.toString(),
            }));
            return _errorResponse(
              request,
              500,
              'internal_error',
              'The request could not be completed. Try again later.',
            );
          }
        };
      };

  Middleware get cors => (Handler innerHandler) {
        return (Request request) async {
          final String? origin = request.headers['origin'];
          if (origin != null && origin != _config.pwaOrigin.origin) {
            return _errorResponse(request, 403, 'origin_not_allowed', 'Origin is not allowed.');
          }
          if (request.method == 'OPTIONS') {
            final String? requestedMethod =
                request.headers['access-control-request-method']?.toUpperCase();
            if (requestedMethod != null &&
                !const <String>{'GET', 'POST', 'DELETE', 'OPTIONS'}
                    .contains(requestedMethod)) {
              return _errorResponse(
                request,
                403,
                'method_not_allowed',
                'Requested method is not allowed.',
              );
            }
            return _corsHeaders(Response(204), origin);
          }
          final Response response = await innerHandler(request);
          return _corsHeaders(response, origin);
        };
      };

  Middleware get bodySizeLimit => (Handler innerHandler) {
        return (Request request) async {
          if (!const <String>{'POST', 'PUT', 'PATCH'}.contains(request.method)) {
            return innerHandler(request);
          }
          final int? declaredLength =
              int.tryParse(request.headers['content-length'] ?? '');
          if (declaredLength != null && declaredLength > _config.maxBodyBytes) {
            return _errorResponse(request, 413, 'body_too_large', 'Request body is too large.');
          }
          final BytesBuilder builder = BytesBuilder(copy: false);
          int length = 0;
          await for (final List<int> chunk in request.read()) {
            length += chunk.length;
            if (length > _config.maxBodyBytes) {
              return _errorResponse(
                request,
                413,
                'body_too_large',
                'Request body is too large.',
              );
            }
            builder.add(chunk);
          }
          final Request replayable = request.change(body: builder.takeBytes());
          return innerHandler(replayable);
        };
      };

  Middleware get rateLimit => (Handler innerHandler) {
        return (Request request) async {
          // PayFast ITNs are authenticated by signature, allowlisted source IP,
          // and server-to-server confirmation; they must not be dropped with 429.
          if (request.url.path == 'api/payfast/notify') {
            return innerHandler(request);
          }
          final DateTime now = clock.now().toUtc();
          final String ip = _ipResolver.resolve(request);
          final _RateWindow? current = _rateWindows[ip];
          final _RateWindow updated;
          if (current == null || now.difference(current.startedAt) >= window) {
            updated = _RateWindow(startedAt: now, count: 1);
          } else {
            updated = _RateWindow(
              startedAt: current.startedAt,
              count: current.count + 1,
            );
          }
          _rateWindows[ip] = updated;
          if (updated.count > maxRequestsPerWindow) {
            return _errorResponse(
              request,
              429,
              'rate_limited',
              'Too many requests. Please wait and try again.',
              headers: <String, Object>{'retry-after': window.inSeconds.toString()},
            );
          }
          if (_rateWindows.length > 10000) {
            _rateWindows.removeWhere(
              (String _, _RateWindow value) =>
                  now.difference(value.startedAt) > window * 2,
            );
          }
          return innerHandler(request);
        };
      };

  Middleware get requestLogger => (Handler innerHandler) {
        return (Request request) async {
          final Stopwatch stopwatch = Stopwatch()..start();
          final Response response = await innerHandler(request);
          stopwatch.stop();
          stdout.writeln(jsonEncode(<String, Object?>{
            'event': 'http_request',
            'requestId': request.context['requestId'] ?? 'unknown',
            'method': request.method,
            'path': '/${request.url.path}',
            'status': response.statusCode,
            'durationMs': stopwatch.elapsedMilliseconds,
          }));
          return response;
        };
      };

  Response _corsHeaders(Response response, String? origin) {
    final Map<String, Object> headers = <String, Object>{
      ...response.headers,
      'vary': 'Origin',
    };
    if (origin == _config.pwaOrigin.origin) {
      headers.addAll(<String, Object>{
        'access-control-allow-origin': origin!,
        'access-control-allow-methods': 'GET, POST, DELETE, OPTIONS',
        'access-control-allow-headers': 'authorization, content-type, if-none-match',
        'access-control-max-age': '600',
      });
    }
    return response.change(headers: headers);
  }

  Response _errorResponse(
    Request request,
    int status,
    String code,
    String message, {
    Map<String, Object> headers = const <String, Object>{},
  }) =>
      jsonResponse(
        status,
        <String, Object?>{
          'error': <String, Object?>{
            'code': code,
            'message': message,
            'requestId': request.context['requestId'],
          },
        },
        headers: headers,
      );
}

class _RateWindow {
  const _RateWindow({required this.startedAt, required this.count});

  final DateTime startedAt;
  final int count;
}
