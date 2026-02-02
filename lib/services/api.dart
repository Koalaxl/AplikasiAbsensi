class ApiConfig {
  // =====================
  // BASE URL API LARAVEL
  // =====================
  static const String baseUrl = 'https://projekb3.skyznode.my.id/api';

  // =====================
  // ENDPOINT
  // =====================
  static const String loginEndpoint = '/login';
  static const String kehadiranEndpoint = '/kehadiran';
  static const String logoutEndpoint = '/logout';
  // ❌ ENDPOINT /me DIHAPUS

  // =====================
  // FULL URL HELPERS
  // =====================
  static String get loginUrl => '$baseUrl$loginEndpoint';
  static String get kehadiranUrl => '$baseUrl$kehadiranEndpoint';
  static String get logoutUrl => '$baseUrl$logoutEndpoint';
  // ❌ meUrl DIHAPUS

  // =====================
  // TIMEOUT DURATION
  // =====================
  static const Duration timeout = Duration(seconds: 30);

  // =====================
  // HEADER TANPA TOKEN
  // =====================
  static Map<String, String> headers() {
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
  }

  // =====================
  // HEADER DENGAN TOKEN
  // =====================
  static Map<String, String> authHeaders(String token) {
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // =====================
  // STORAGE KEYS
  // =====================
  static const String tokenKey = 'token';
  static const String siswaKey = 'siswa';
}