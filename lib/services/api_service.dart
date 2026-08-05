import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'api.dart';
import 'school_config.dart';
import '../models/pesan.dart';

class ApiService {
  // =====================
  // GET TOKEN FROM STORAGE
  // =====================
  static Future<String?> _getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(ApiConfig.tokenKey);
    } catch (e) {
      print('Error getting token: $e');
      return null;
    }
  }

  // =====================
  // LOGIN ORTU (nama siswa + NISN)
  // =====================
  static Future<Map<String, dynamic>> loginOrtu({
    required String nama,
    required String nisn,
  }) async {
    final school = await SchoolConfig.getSelectedSchool();
    final idSekolah = school?.idSekolah;

    if (idSekolah == null) {
      return {'success': false, 'message': 'Sekolah belum dipilih'};
    }

    return _performLogin({
      'tipeAkun': 'ortu',
      'namaSiswa': nama,
      'nisn': nisn,
      'idSekolah': idSekolah,
    });
  }

  // =====================
  // LOGIN ADMIN / KEPALA SEKOLAH (username + password)
  // =====================
  static Future<Map<String, dynamic>> loginAdmin({
    required String username,
    required String password,
  }) async {
    final school = await SchoolConfig.getSelectedSchool();
    final idSekolah = school?.idSekolah;

    if (idSekolah == null) {
      return {'success': false, 'message': 'Sekolah belum dipilih'};
    }

    return _performLogin({
      'tipeAkun': 'admin',
      'username': username,
      'password': password,
      'idSekolah': idSekolah,
    });
  }

  // ─── Helper: unwrap response envelope { success, data, timestamp } ───────
  // Backend NestJS pakai global response interceptor yang selalu bungkus
  // hasil di dalam field 'data'. Kalau body-nya bukan envelope (tidak ada
  // key 'data' berupa Map), balikin apa adanya supaya tetap kompatibel.
  static Map<String, dynamic> _unwrapEnvelope(Map<String, dynamic> body) {
    final inner = body['data'];
    if (inner is Map<String, dynamic>) return inner;
    return body;
  }

  // ─── Helper: ekstrak List dari body yang mungkin berbentuk array
  // langsung, atau dibungkus di 'data' / 'data.data' / key umum lainnya.
  // Dipakai khusus untuk endpoint yang me-return list (mis. inbox pesan).
  static List<dynamic> _extractList(dynamic decoded, List<String> keys) {
    if (decoded is List) return decoded;
    if (decoded is! Map<String, dynamic>) return [];

    final inner = decoded['data'];
    if (inner is List) return inner;
    if (inner is Map<String, dynamic>) {
      if (inner['data'] is List) return inner['data'] as List<dynamic>;
      for (final key in keys) {
        if (inner[key] is List) return inner[key] as List<dynamic>;
      }
    }
    for (final key in keys) {
      if (decoded[key] is List) return decoded[key] as List<dynamic>;
    }
    return [];
  }

  // =====================
  // PROSES LOGIN BERSAMA (dipakai oleh loginOrtu & loginAdmin)
  // =====================
  static Future<Map<String, dynamic>> _performLogin(
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse(ApiConfig.loginUrl),
            headers: ApiConfig.headers(),
            body: json.encode(body),
          )
          .timeout(ApiConfig.timeout);

      print('Login Response Status: ${response.statusCode}');
      print('Login Response Body: ${response.body}');

      final rawResponseData = json.decode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        // ✅ Unwrap { success, data: {...}, timestamp } -> {...}
        final responseData = _unwrapEnvelope(rawResponseData);

        final accessToken = responseData['accessToken'];
        final tipeAkun = responseData['tipeAkun'];
        final profil = responseData['profil'];

        if (accessToken == null) {
          return {
            'success': false,
            'message': 'Token tidak ditemukan dalam response',
          };
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(ApiConfig.tokenKey, accessToken);
        await prefs.setString(ApiConfig.tipeAkunKey, tipeAkun ?? '');

        if (profil != null) {
          await prefs.setString(ApiConfig.siswaKey, json.encode(profil));
        }

        return {
          'success': true,
          'data': responseData,
          'message': 'Login berhasil',
        };
      } else if (response.statusCode == 401) {
        final responseData = _unwrapEnvelope(rawResponseData);
        return {
          'success': false,
          'message': responseData['message'] ?? 'Data login salah',
        };
      } else {
        final responseData = _unwrapEnvelope(rawResponseData);
        return {
          'success': false,
          'message': responseData['message'] ?? 'Login gagal',
        };
      }
    } catch (e) {
      print('Login error: $e');
      return {
        'success': false,
        'message': _getErrorMessage(e),
      };
    }
  }

  // =====================
  // GET TIPE AKUN YANG SEDANG LOGIN
  // =====================
  static Future<String?> getTipeAkun() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(ApiConfig.tipeAkunKey);
    } catch (e) {
      print('Error getting tipe akun: $e');
      return null;
    }
  }

  // =====================
  // LOGOUT
  // =====================
  static Future<Map<String, dynamic>> logout() async {
    try {
      final token = await _getToken();

      if (token != null) {
        try {
          // Delete FCM token before logout (khusus akun ortu, punya idSiswa)
          final tipeAkun = await getTipeAkun();
          if (tipeAkun == 'ortu') {
            final siswaData = await getProfilLocal();
            if (siswaData != null && siswaData['idSiswa'] != null) {
              final rawId = siswaData['idSiswa'];
              final siswaId =
                  rawId is int ? rawId : int.tryParse(rawId.toString());
              if (siswaId != null) {
                await deleteFcmToken(siswaId: siswaId);
              }
            }
          }

          // ⚠️ Endpoint logout belum dikonfirmasi di dokumentasi API
          final logoutUrl = ApiConfig.logoutUrl;

          await http
              .post(
                Uri.parse(logoutUrl),
                headers: ApiConfig.authHeaders(token),
              )
              .timeout(ApiConfig.timeout);
        } catch (e) {
          print('Logout API error (will clear local data anyway): $e');
        }
      }

      await clearAllData();

      return {
        'success': true,
        'message': 'Logout berhasil',
      };
    } catch (e) {
      print('Logout error: $e');
      await clearAllData();

      return {
        'success': true,
        'message': 'Logout berhasil',
      };
    }
  }

  // =====================
  // GET DASHBOARD KEPALA SEKOLAH
  // =====================
  static Future<Map<String, dynamic>> getDashboardKepsek() async {
    try {
      final token = await _getToken();

      if (token == null) {
        return {
          'success': false,
          'message': 'Token tidak ditemukan',
          'unauthorized': true,
        };
      }

      final response = await http
          .get(
            Uri.parse(ApiConfig.dashboardKepsekUrl),
            headers: ApiConfig.authHeaders(token),
          )
          .timeout(ApiConfig.timeout);

      print('Dashboard Kepsek Response Status: ${response.statusCode}');
      print('Dashboard Kepsek Response Body: ${response.body}');

      final rawResponseData = json.decode(response.body);
      final responseData = _unwrapEnvelope(rawResponseData);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': responseData,
        };
      } else if (response.statusCode == 401) {
        await clearAllData();
        return {
          'success': false,
          'message': 'Sesi Anda telah berakhir, silakan login kembali',
          'unauthorized': true,
        };
      } else {
        return {
          'success': false,
          'message': responseData['message'] ?? 'Gagal memuat dashboard',
        };
      }
    } catch (e) {
      print('GetDashboardKepsek error: $e');
      return {
        'success': false,
        'message': _getErrorMessage(e),
      };
    }
  }

  // =====================
  // GET RIWAYAT KEHADIRAN (ORTU)
  // Param bulan format: "yyyy-MM" contoh "2026-07"
  // =====================
  static Future<Map<String, dynamic>> getRiwayatKehadiranOrtu({
    String? bulan,
  }) async {
    try {
      final token = await _getToken();

      if (token == null) {
        return {
          'success': false,
          'message': 'Token tidak ditemukan',
          'unauthorized': true,
        };
      }

      final queryParams = <String, String>{};
      if (bulan != null) queryParams['bulan'] = bulan;

      final uri = Uri.parse(ApiConfig.riwayatKehadiranOrtuUrl).replace(
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      final response = await http
          .get(
            uri,
            headers: ApiConfig.authHeaders(token),
          )
          .timeout(ApiConfig.timeout);

      print('Riwayat Kehadiran Response Status: ${response.statusCode}');
      print('Riwayat Kehadiran Response Body: ${response.body}');

      final rawResponseData = json.decode(response.body);
      final responseData = _unwrapEnvelope(rawResponseData);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': responseData,
        };
      } else if (response.statusCode == 401) {
        await clearAllData();
        return {
          'success': false,
          'message': 'Sesi Anda telah berakhir, silakan login kembali',
          'unauthorized': true,
        };
      } else {
        return {
          'success': false,
          'message':
              responseData['message'] ?? 'Gagal mengambil data kehadiran',
        };
      }
    } catch (e) {
      print('GetRiwayatKehadiranOrtu error: $e');
      return {
        'success': false,
        'message': _getErrorMessage(e),
      };
    }
  }

  // =====================
  // INBOX PESAN (ORTU) — BARU
  // =====================

  /// GET /app-pesan/inbox
  /// Balikin 'data': List<Pesan> kalau sukses.
  static Future<Map<String, dynamic>> getInboxPesan() async {
    try {
      final token = await _getToken();

      if (token == null) {
        return {
          'success': false,
          'message': 'Token tidak ditemukan',
          'unauthorized': true,
        };
      }

      final response = await http
          .get(
            Uri.parse(ApiConfig.inboxPesanUrl),
            headers: ApiConfig.authHeaders(token),
          )
          .timeout(ApiConfig.timeout);

      print('Inbox Pesan Response Status: ${response.statusCode}');
      print('Inbox Pesan Response Body: ${response.body}');

      final rawResponseData = json.decode(response.body);

      if (response.statusCode == 200) {
        final rawList = _extractList(
          rawResponseData,
          ['inbox', 'pesan', 'items', 'results'],
        );
        final pesanList = rawList
            .map((e) => Pesan.fromJson(e as Map<String, dynamic>))
            .toList();
        return {'success': true, 'data': pesanList};
      } else if (response.statusCode == 401) {
        await clearAllData();
        return {
          'success': false,
          'message': 'Sesi Anda telah berakhir, silakan login kembali',
          'unauthorized': true,
        };
      } else {
        final responseData = _unwrapEnvelope(
          rawResponseData is Map<String, dynamic> ? rawResponseData : {},
        );
        return {
          'success': false,
          'message': responseData['message'] ?? 'Gagal memuat kotak masuk',
        };
      }
    } catch (e) {
      print('GetInboxPesan error: $e');
      return {
        'success': false,
        'message': _getErrorMessage(e),
      };
    }
  }

  /// PATCH /app-pesan/inbox/{idPenerima}/dibaca
  static Future<Map<String, dynamic>> tandaiPesanDibaca(
    int idPenerima,
  ) async {
    try {
      final token = await _getToken();

      if (token == null) {
        return {
          'success': false,
          'message': 'Token tidak ditemukan',
          'unauthorized': true,
        };
      }

      final response = await http
          .patch(
            Uri.parse(ApiConfig.tandaiPesanDibacaUrl(idPenerima)),
            headers: ApiConfig.authHeaders(token),
          )
          .timeout(ApiConfig.timeout);

      print('Tandai Dibaca Response Status: ${response.statusCode}');
      print('Tandai Dibaca Response Body: ${response.body}');

      final rawResponseData = json.decode(response.body);
      final responseData = _unwrapEnvelope(
        rawResponseData is Map<String, dynamic> ? rawResponseData : {},
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': responseData['message'] ?? 'Pesan ditandai sudah dibaca',
        };
      } else if (response.statusCode == 401) {
        await clearAllData();
        return {
          'success': false,
          'message': 'Sesi Anda telah berakhir, silakan login kembali',
          'unauthorized': true,
        };
      } else {
        return {
          'success': false,
          'message': responseData['message'] ?? 'Gagal menandai pesan',
        };
      }
    } catch (e) {
      print('TandaiPesanDibaca error: $e');
      return {
        'success': false,
        'message': _getErrorMessage(e),
      };
    }
  }

  /// DELETE /app-pesan/inbox/{idPenerima}
  static Future<Map<String, dynamic>> hapusPesan(int idPenerima) async {
    try {
      final token = await _getToken();

      if (token == null) {
        return {
          'success': false,
          'message': 'Token tidak ditemukan',
          'unauthorized': true,
        };
      }

      final response = await http
          .delete(
            Uri.parse(ApiConfig.hapusPesanUrl(idPenerima)),
            headers: ApiConfig.authHeaders(token),
          )
          .timeout(ApiConfig.timeout);

      print('Hapus Pesan Response Status: ${response.statusCode}');
      print('Hapus Pesan Response Body: ${response.body}');

      final rawResponseData = json.decode(response.body);
      final responseData = _unwrapEnvelope(
        rawResponseData is Map<String, dynamic> ? rawResponseData : {},
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': responseData['message'] ?? 'Pesan berhasil dihapus',
        };
      } else if (response.statusCode == 401) {
        await clearAllData();
        return {
          'success': false,
          'message': 'Sesi Anda telah berakhir, silakan login kembali',
          'unauthorized': true,
        };
      } else {
        return {
          'success': false,
          'message': responseData['message'] ?? 'Gagal menghapus pesan',
        };
      }
    } catch (e) {
      print('HapusPesan error: $e');
      return {
        'success': false,
        'message': _getErrorMessage(e),
      };
    }
  }

  // =====================
  // SAVE FCM TOKEN
  // =====================
  static Future<Map<String, dynamic>> saveFcmToken({
    required int siswaId,
    required String fcmToken,
  }) async {
    try {
      final token = await _getToken();

      if (token == null) {
        return {
          'success': false,
          'message': 'Token tidak ditemukan',
        };
      }

      final fcmUrl = ApiConfig.saveFcmUrl;

      print('Saving FCM Token to: $fcmUrl');
      print('Siswa ID: $siswaId');

      final response = await http
          .post(
            Uri.parse(fcmUrl),
            headers: ApiConfig.authHeaders(token),
            body: json.encode({
              // ⚠️ siswaId TIDAK dikirim — backend ambil identitas dari JWT
              // (@CurrentAppUser()), DTO pakai forbidNonWhitelisted jadi
              // field asing di luar DTO ditolak dengan 400.
              'fcmToken': fcmToken,
            }),
          )
          .timeout(ApiConfig.timeout);

      print('Save FCM Response Status: ${response.statusCode}');
      print('Save FCM Response Body: ${response.body}');

      final rawResponseData = json.decode(response.body);
      final responseData = _unwrapEnvelope(rawResponseData);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'message': responseData['message'] ?? 'FCM token berhasil disimpan',
        };
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        return {
          'success': false,
          'message': responseData['message'] ?? 'Unauthorized',
          'unauthorized': true,
        };
      } else {
        return {
          'success': false,
          'message': responseData['message'] ?? 'Gagal menyimpan FCM token',
        };
      }
    } catch (e) {
      print('Save FCM Token error: $e');
      return {
        'success': false,
        'message': _getErrorMessage(e),
      };
    }
  }

  // =====================
  // DELETE FCM TOKEN
  // =====================
  static Future<Map<String, dynamic>> deleteFcmToken({
    required int siswaId,
  }) async {
    try {
      final token = await _getToken();

      if (token == null) {
        return {
          'success': false,
          'message': 'Token tidak ditemukan',
        };
      }

      final fcmUrl = ApiConfig.saveFcmUrl;

      final response = await http
          .delete(
            Uri.parse(fcmUrl),
            headers: ApiConfig.authHeaders(token),
          )
          .timeout(ApiConfig.timeout);

      print('Delete FCM Response Status: ${response.statusCode}');
      print('Delete FCM Response Body: ${response.body}');

      final rawResponseData = json.decode(response.body);
      final responseData = _unwrapEnvelope(rawResponseData);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': responseData['message'] ?? 'FCM token berhasil dihapus',
        };
      } else {
        return {
          'success': false,
          'message': responseData['message'] ?? 'Gagal menghapus FCM token',
        };
      }
    } catch (e) {
      print('Delete FCM Token error: $e');
      return {
        'success': false,
        'message': _getErrorMessage(e),
      };
    }
  }

  // =====================
  // SINKRONISASI TOKEN FCM (BARU)
  // =====================
  // Dipanggil dari HomeScreenOrtu.initState(). Hanya jalan untuk akun
  // 'ortu' (yang berhak terima notifikasi pesan). Ambil FCM token
  // perangkat, simpan ke backend, lalu pasang listener supaya kalau
  // token berubah (mis. reinstall app), backend otomatis diupdate juga.
  static Future<void> initAndSyncFcmToken() async {
    try {
      final tipeAkun = await getTipeAkun();
      if (tipeAkun != 'ortu') return;

      final profil = await getProfilLocal();
      final rawId = profil?['idSiswa'];
      final siswaId =
          rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
      if (siswaId == null) {
        print('initAndSyncFcmToken: idSiswa tidak ditemukan di profil lokal');
        return;
      }

      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken != null) {
        await saveFcmToken(siswaId: siswaId, fcmToken: fcmToken);
      }

      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        saveFcmToken(siswaId: siswaId, fcmToken: newToken);
      });
    } catch (e) {
      print('initAndSyncFcmToken error: $e');
    }
  }

  // =====================
  // GET PROFIL (SISWA/ADMIN) DARI LOCAL STORAGE
  // =====================
  static Future<Map<String, dynamic>?> getProfilLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final profilJson = prefs.getString(ApiConfig.siswaKey);

      if (profilJson != null && profilJson.isNotEmpty) {
        return json.decode(profilJson);
      }
      return null;
    } catch (e) {
      print('Error getting profil from local: $e');
      return null;
    }
  }

  // =====================
  // CHECK IF USER IS LOGGED IN
  // =====================
  static Future<bool> isLoggedIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(ApiConfig.tokenKey);
      return token != null && token.isNotEmpty;
    } catch (e) {
      print('Error checking login status: $e');
      return false;
    }
  }

  // =====================
  // CLEAR ALL DATA
  // =====================
  static Future<void> clearAllData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(ApiConfig.tokenKey);
      await prefs.remove(ApiConfig.siswaKey);
      await prefs.remove(ApiConfig.tipeAkunKey);
      await prefs.remove('pending_fcm_token');
      await prefs.remove('pending_fcm_sync');
    } catch (e) {
      print('Error clearing data: $e');
    }
  }

  // =====================
  // GET ERROR MESSAGE
  // =====================
  static String _getErrorMessage(dynamic error) {
    if (error.toString().contains('SocketException') ||
        error.toString().contains('Failed host lookup')) {
      return 'Tidak ada koneksi internet';
    } else if (error.toString().contains('TimeoutException')) {
      return 'Koneksi timeout, silakan coba lagi';
    } else {
      return 'Terjadi kesalahan: ${error.toString()}';
    }
  }
}