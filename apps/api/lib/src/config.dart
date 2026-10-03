import 'dart:io';

class ApiConfig {
  ApiConfig({
    required this.supabaseUrl,
    required this.supabaseServiceRoleKey,
    required this.supabaseJwtSecret,
    required this.pwaOrigin,
    required this.apiBaseUrl,
    required this.payFastMerchantId,
    required this.payFastMerchantKey,
    required this.payFastPassphrase,
    required this.payFastSandbox,
    required this.payFastIpCidrs,
    required this.trustedProxyCidrs,
    required this.port,
    required this.maxBodyBytes,
    required this.environment,
  });

  final Uri supabaseUrl;
  final String supabaseServiceRoleKey;
  final String supabaseJwtSecret;
  final Uri pwaOrigin;
  final Uri apiBaseUrl;
  final String payFastMerchantId;
  final String payFastMerchantKey;
  final String payFastPassphrase;
  final bool payFastSandbox;
  final List<String> payFastIpCidrs;
  final List<String> trustedProxyCidrs;
  final int port;
  final int maxBodyBytes;
  final String environment;

  String get payFastHost =>
      payFastSandbox ? 'sandbox.payfast.co.za' : 'www.payfast.co.za';

  Uri get payFastActionUrl => Uri.https(payFastHost, '/eng/process');
  Uri get payFastValidationUrl =>
      Uri.https(payFastHost, '/eng/query/validate');

  factory ApiConfig.fromEnvironment([Map<String, String>? environment]) {
    final Map<String, String> values = environment ?? Platform.environment;
    String required(String name) {
      final String? value = values[name];
      if (value == null || value.trim().isEmpty) {
        throw StateError('Missing required environment variable: $name');
      }
      return value.trim();
    }

    Uri httpsUrl(String name, {bool allowLocalHttp = false}) {
      final Uri value = Uri.parse(required(name));
      final bool local =
          value.host == 'localhost' || value.host == '127.0.0.1' || value.host == '::1';
      if (value.host.isEmpty ||
          (value.scheme != 'https' && !(allowLocalHttp && local && value.scheme == 'http'))) {
        throw StateError('$name must be an HTTPS URL (HTTP is allowed only on localhost)');
      }
      return value;
    }

    final String environmentName = values['APP_ENV']?.trim() ?? 'production';
    final bool allowLocalHttp = environmentName != 'production';
    final Uri projectUrl = httpsUrl('SUPABASE_URL', allowLocalHttp: allowLocalHttp);
    final Uri pwa = httpsUrl('PWA_ORIGIN', allowLocalHttp: allowLocalHttp);
    if (pwa.path != '/' && pwa.path.isNotEmpty || pwa.query.isNotEmpty || pwa.fragment.isNotEmpty) {
      throw StateError('PWA_ORIGIN must be an origin without a path, query, or fragment');
    }
    final Uri apiUrl = httpsUrl('API_BASE_URL', allowLocalHttp: allowLocalHttp);
    final String sandboxValue = required('PAYFAST_SANDBOX').toLowerCase();
    if (sandboxValue != 'true' && sandboxValue != 'false') {
      throw StateError('PAYFAST_SANDBOX must be exactly true or false');
    }
    final String merchantId = required('PAYFAST_MERCHANT_ID');
    if (!RegExp(r'^\d{8}$').hasMatch(merchantId)) {
      throw StateError('PAYFAST_MERCHANT_ID must contain exactly 8 digits');
    }
    final String jwtSecret = required('SUPABASE_JWT_SECRET');
    if (jwtSecret.length < 32) {
      throw StateError('SUPABASE_JWT_SECRET must contain at least 32 characters');
    }

    const List<String> officialPayFastCidrs = <String>[
      '197.97.145.144/28',
      '41.74.179.192/27',
      '102.216.36.0/28',
      '102.216.36.128/28',
      '144.126.193.139/32',
    ];
    const List<String> googleFrontEndCidrs = <String>[
      '35.191.0.0/16',
      '130.211.0.0/22',
    ];

    final List<String> payFastCidrs =
        (values['PAYFAST_ALLOWED_CIDRS'] ?? officialPayFastCidrs.join(','))
            .split(',')
            .map((String value) => value.trim())
            .where((String value) => value.isNotEmpty)
            .toList(growable: false);
    final List<String> trustedCidrs =
        (values['TRUSTED_PROXY_CIDRS'] ?? googleFrontEndCidrs.join(','))
            .split(',')
            .map((String value) => value.trim())
            .where((String value) => value.isNotEmpty)
            .toList(growable: false);
    final int port = int.tryParse(values['PORT'] ?? '8080') ?? 8080;
    final int bodyLimit = int.tryParse(values['MAX_BODY_BYTES'] ?? '65536') ?? 65536;
    if (port < 1 || port > 65535 || bodyLimit < 1024 || bodyLimit > 1 << 20) {
      throw StateError('PORT or MAX_BODY_BYTES is outside the allowed range');
    }

    return ApiConfig(
      supabaseUrl: projectUrl,
      supabaseServiceRoleKey: required('SUPABASE_SERVICE_ROLE_KEY'),
      supabaseJwtSecret: jwtSecret,
      pwaOrigin: pwa,
      apiBaseUrl: apiUrl,
      payFastMerchantId: merchantId,
      payFastMerchantKey: required('PAYFAST_MERCHANT_KEY'),
      payFastPassphrase: required('PAYFAST_PASSPHRASE'),
      payFastSandbox: sandboxValue == 'true',
      payFastIpCidrs: payFastCidrs,
      trustedProxyCidrs: trustedCidrs,
      port: port,
      maxBodyBytes: bodyLimit,
      environment: environmentName,
    );
  }
}
