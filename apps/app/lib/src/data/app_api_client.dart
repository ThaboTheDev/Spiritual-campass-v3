import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import 'app_models.dart';

class AppApiClient {
  AppApiClient({
    required AppConfig config,
    required SupabaseClient supabase,
    http.Client? httpClient,
  })  : _config = config,
        _supabase = supabase,
        _httpClient = httpClient ?? http.Client();

  final AppConfig _config;
  final SupabaseClient _supabase;
  final http.Client _httpClient;
  String? _centresEtag;
  CentreCatalog? _cachedCentres;

  Future<MemberSnapshot> getMe() async {
    final http.Response response = await _send('GET', '/api/me');
    return MemberSnapshot.fromJson(_decodeObject(response.body));
  }

  Future<CentreCatalog> getCentres() async {
    final Map<String, String> headers = <String, String>{};
    if (_centresEtag != null) headers['if-none-match'] = _centresEtag!;
    final http.Response response = await _send(
      'GET',
      '/api/centres',
      extraHeaders: headers,
      allowNotModified: true,
    );
    if (response.statusCode == 304) {
      final CentreCatalog? cached = _cachedCentres;
      if (cached != null) return cached;
      throw const AppApiException(304, 'The directory cache has expired. Refresh again.');
    }
    final CentreCatalog catalog = CentreCatalog.fromJson(_decodeObject(response.body));
    _centresEtag = response.headers['etag'];
    _cachedCentres = catalog;
    return catalog;
  }

  Future<CheckoutSession> createCheckout() async {
    final http.Response response = await _send('POST', '/api/payfast/checkout');
    return CheckoutSession.fromJson(_decodeObject(response.body));
  }

  Future<void> deleteAccount() async {
    await _send('DELETE', '/api/account/delete');
  }

  void close() => _httpClient.close();

  Future<http.Response> _send(
    String method,
    String path, {
    Map<String, String> extraHeaders = const <String, String>{},
    bool allowNotModified = false,
  }) async {
    final String? accessToken = _supabase.auth.currentSession?.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      throw const AppApiException(401, 'Please sign in again.');
    }
    final Uri uri = Uri.parse(_config.apiBaseUrl).resolve(path);
    final Map<String, String> headers = <String, String>{
      'accept': 'application/json',
      'authorization': 'Bearer $accessToken',
      ...extraHeaders,
    };
    if (method == 'POST') headers['content-type'] = 'application/json';

    final http.Response response;
    try {
      switch (method) {
        case 'GET':
          response = await _httpClient
              .get(uri, headers: headers)
              .timeout(const Duration(seconds: 20));
          break;
        case 'POST':
          response = await _httpClient
              .post(uri, headers: headers, body: '{}')
              .timeout(const Duration(seconds: 20));
          break;
        case 'DELETE':
          response = await _httpClient
              .delete(uri, headers: headers)
              .timeout(const Duration(seconds: 20));
          break;
        default:
          throw ArgumentError.value(method, 'method');
      }
    } on TimeoutException {
      throw const AppApiException(0, 'The server took too long to respond. Try again.');
    } on http.ClientException {
      throw const AppApiException(0, 'Could not connect. Check your connection and try again.');
    }

    if (allowNotModified && response.statusCode == 304) return response;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message = 'Request failed (${response.statusCode}).';
      try {
        final Map<String, Object?> error = _decodeObject(response.body);
        final Object? nested = error['error'];
        if (nested is Map<String, Object?> && nested['message'] is String) {
          message = nested['message']! as String;
        } else if (error['message'] is String) {
          message = error['message']! as String;
        }
      } catch (_) {
        // Keep a safe generic message when the server response is not JSON.
      }
      throw AppApiException(response.statusCode, message);
    }
    return response;
  }

  static Map<String, Object?> _decodeObject(String body) {
    final Object? decoded = jsonDecode(body);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('Expected a JSON object from the API.');
    }
    return decoded;
  }
}
