import 'school_config.dart';

class ApiConfig {
  // =====================
  // GET DYNAMIC BASE URL
  // =====================
  static Future<String> getBaseUrl() async {
    final school = await SchoolConfig.getSelectedSchool();
    
    // Fallback ke testing jika belum ada sekolah yang dipilih
    return school?.baseUrl ?? 'https://projekb3.skyznode.my.id/api';
  }

  // =====================
  // ENDPOINT (tetap sama)
  // =====================
  static const String loginEndpoint = '/login';
  static const String kehadiranEndpoint = '/kehadiran';
  static const String logoutEndpoint = '/logout';

  // =====================
  // FULL URL HELPERS (async karena perlu get baseUrl)
  // =====================
  static Future<String> get loginUrl async {
    final base = await getBaseUrl();
    return '$base$loginEndpoint';
  }

  static Future<String> get kehadiranUrl async {
    final base = await getBaseUrl();
    return '$base$kehadiranEndpoint';
  }

  static Future<String> get logoutUrl async {
    final base = await getBaseUrl();
    return '$base$logoutEndpoint';
  }

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