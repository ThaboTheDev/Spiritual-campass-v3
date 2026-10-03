import 'dart:async';

import 'package:http/http.dart' as http;

abstract interface class PayFastServerValidator {
  Future<bool> validate(Uri endpoint, String orderedParameterString);
}

class HttpPayFastServerValidator implements PayFastServerValidator {
  HttpPayFastServerValidator(this._client, {this.timeout = const Duration(seconds: 4)});

  final http.Client _client;
  final Duration timeout;

  @override
  Future<bool> validate(Uri endpoint, String orderedParameterString) async {
    try {
      final http.Response response = await _client
          .post(
            endpoint,
            headers: const <String, String>{
              'content-type': 'application/x-www-form-urlencoded',
              'accept': 'text/plain',
            },
            body: orderedParameterString,
          )
          .timeout(timeout);
      return response.statusCode == 200 && response.body.trim() == 'VALID';
    } on TimeoutException {
      return false;
    } on http.ClientException {
      return false;
    }
  }
}
