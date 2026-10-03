class AppConfig {
  const AppConfig({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.apiBaseUrl,
    required this.storeBuild,
    required this.supportEmail,
  });

  factory AppConfig.fromEnvironment() => const AppConfig(
        supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
        supabaseAnonKey: String.fromEnvironment('SUPABASE_ANON_KEY'),
        apiBaseUrl: String.fromEnvironment('API_BASE_URL'),
        storeBuild: bool.fromEnvironment('STORE_BUILD', defaultValue: false),
        supportEmail: String.fromEnvironment('SUPPORT_EMAIL'),
      );

  final String supabaseUrl;
  final String supabaseAnonKey;
  final String apiBaseUrl;
  final bool storeBuild;
  final String supportEmail;

  bool get isConfigured =>
      supabaseUrl.startsWith('https://') &&
      supabaseAnonKey.isNotEmpty &&
      apiBaseUrl.startsWith('https://');
}
