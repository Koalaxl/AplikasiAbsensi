import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';

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
  // LOGIN
  // =====================
  static Future<Map<String, dynamic>> login({
    required String nama,
    required String nisn,
  }) async {
    try {
      // Get dynamic login URL
      final loginUrl = await ApiConfig.loginUrl;
      
      final response = await http
          .post(
            Uri.parse(loginUrl),
            headers: ApiConfig.headers(),
            body: json.encode({
              'nama_siswa': nama,
              'nisn': nisn,
            }),
          )
          .timeout(ApiConfig.timeout);

      print('Login Response Status: ${response.statusCode}');
      print('Login Response Body: ${response.body}');

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        // Validasi response memiliki token
        if (responseData['token'] == null) {
          return {
            'success': false,
            'message': 'Token tidak ditemukan dalam response',
          };
        }

        // Save token
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(ApiConfig.tokenKey, responseData['token']);

        // Save siswa data jika ada
        if (responseData['siswa'] != null) {
          await prefs.setString(
            ApiConfig.siswaKey,
            json.encode(responseData['siswa']),
          );
        }

        return {
          'success': true,
          'data': responseData,
          'message': 'Login berhasil',
        };
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'message': responseData['message'] ?? 'Nama atau NISN salah',
        };
      } else {
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
  // LOGOUT
  // =====================
  static Future<Map<String, dynamic>> logout() async {
    try {
      final token = await _getToken();

      if (token != null) {
        try {
          // Get dynamic logout URL
          final logoutUrl = await ApiConfig.logoutUrl;
          
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

      // Clear local data
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(ApiConfig.tokenKey);
      await prefs.remove(ApiConfig.siswaKey);

      return {
        'success': true,
        'message': 'Logout berhasil',
      };
    } catch (e) {
      print('Logout error: $e');
      // Even if everything fails, try to clear local data
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(ApiConfig.tokenKey);
        await prefs.remove(ApiConfig.siswaKey);
      } catch (_) {}

      return {
        'success': true,
        'message': 'Logout berhasil',
      };
    }
  }

  // =====================
  // GET KEHADIRAN
  // =====================
  static Future<Map<String, dynamic>> getKehadiran() async {
    try {
      final token = await _getToken();

      if (token == null) {
        return {
          'success': false,
          'message': 'Token tidak ditemukan',
          'unauthorized': true,
        };
      }

      // Get dynamic kehadiran URL
      final kehadiranUrl = await ApiConfig.kehadiranUrl;

      final response = await http
          .get(
            Uri.parse(kehadiranUrl),
            headers: ApiConfig.authHeaders(token),
          )
          .timeout(ApiConfig.timeout);

      print('Kehadiran Response Status: ${response.statusCode}');
      print('Kehadiran Response Body: ${response.body}');

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': responseData['data'] ?? [],
        };
      } else if (response.statusCode == 401) {
        // Token expired atau invalid
        await clearAllData();
        return {
          'success': false,
          'message': 'Sesi Anda telah berakhir, silakan login kembali',
          'unauthorized': true,
        };
      } else {
        return {
          'success': false,
          'message': responseData['message'] ?? 'Gagal mengambil data kehadiran',
        };
      }
    } catch (e) {
      print('GetKehadiran error: $e');
      return {
        'success': false,
        'message': _getErrorMessage(e),
      };
    }
  }

  // =====================
  // GET SISWA FROM LOCAL STORAGE
  // =====================
  static Future<Map<String, dynamic>?> getSiswaLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final siswaJson = prefs.getString(ApiConfig.siswaKey);

      if (siswaJson != null && siswaJson.isNotEmpty) {
        return json.decode(siswaJson);
      }
      return null;
    } catch (e) {
      print('Error getting siswa from local: $e');
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
      // Cukup cek token ada atau tidak
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