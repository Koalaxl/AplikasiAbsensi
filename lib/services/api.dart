class ApiConfig {
  // =====================
  // BASE URL (SATU DOMAIN UNTUK SEMUA SEKOLAH)
  // =====================
  static const String baseUrl = 'https://api-sekolahku.skyznode.my.id/api/v1';

  // =====================
  // ENDPOINTS
  // =====================
  static const String loginEndpoint = '/auth-app/login';
  static const String fcmTokenEndpoint = '/app-fcm-token';
  static const String dashboardKepsekEndpoint = '/app-dashboard/kepsek';
  static const String riwayatKehadiranOrtuEndpoint = '/app-ortu/riwayat-kehadiran';
  static const String logoutEndpoint = '/logout'; // ⚠️ belum dikonfirmasi di dokumentasi API
  static const String sekolahListEndpoint = '/sekolah';

  // ── BARU: inbox pesan (notifikasi) ────────────────────────────────────
  static const String inboxPesanEndpoint = '/app-pesan/inbox';

  // =====================
  // FULL URL HELPERS
  // =====================
  static String get loginUrl => '$baseUrl$loginEndpoint';
  static String get logoutUrl => '$baseUrl$logoutEndpoint';
  static String get saveFcmUrl => '$baseUrl$fcmTokenEndpoint';
  static String get deleteFcmUrl => '$baseUrl$fcmTokenEndpoint';
  static String get dashboardKepsekUrl => '$baseUrl$dashboardKepsekEndpoint';
  static String get riwayatKehadiranOrtuUrl => '$baseUrl$riwayatKehadiranOrtuEndpoint';
  static String get sekolahListUrl => '$baseUrl$sekolahListEndpoint';

  // ── BARU: helper URL inbox pesan ──────────────────────────────────────
  static String get inboxPesanUrl => '$baseUrl$inboxPesanEndpoint';

  /// PATCH /app-pesan/inbox/{idPenerima}/dibaca
  static String tandaiPesanDibacaUrl(int idPenerima) =>
      '$baseUrl$inboxPesanEndpoint/$idPenerima/dibaca';

  /// DELETE /app-pesan/inbox/{idPenerima}
  static String hapusPesanUrl(int idPenerima) =>
      '$baseUrl$inboxPesanEndpoint/$idPenerima';

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
  static const String tipeAkunKey = 'tipeAkun';
}