import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';

class SchoolConfig {
  // =====================
  // STORAGE KEYS
  // =====================
  static const String _selectedSchoolKey = 'selected_school_id';
  static const String _cachedSchoolListKey = 'cached_school_list';

  // =====================
  // FETCH LIST SEKOLAH DARI API
  // =====================
  static Future<List<School>> fetchSchoolList({bool forceRefresh = false}) async {
    try {
      if (!forceRefresh) {
        final cached = await _getCachedSchoolList();
        if (cached != null && cached.isNotEmpty) {
          _refreshInBackground();
          return cached;
        }
      }

      print('Fetching school list from: ${ApiConfig.sekolahListUrl}');

      final response = await http
          .get(
            Uri.parse(ApiConfig.sekolahListUrl),
            headers: ApiConfig.headers(),
          )
          .timeout(ApiConfig.timeout);

      print('School List Response Status: ${response.statusCode}');
      print('School List Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final schools = _parseSchoolListResponse(response.body);
        await _cacheSchoolList(schools);
        return schools;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        // ⚠️ Endpoint /sekolah butuh auth padahal dipanggil sebelum login.
        // Ini perlu dikonfirmasi ke backend: endpoint list sekolah harusnya
        // public (@Public()), karena user belum punya token di titik ini.
        print(
          '⚠️ Endpoint sekolah butuh autentikasi (${response.statusCode}). '
          'Cek ke backend apakah endpoint ini seharusnya public.',
        );
        final cached = await _getCachedSchoolList();
        return cached ?? [];
      } else {
        final cached = await _getCachedSchoolList();
        return cached ?? [];
      }
    } catch (e) {
      print('Error fetching school list: $e');
      final cached = await _getCachedSchoolList();
      return cached ?? [];
    }
  }

  static Future<void> _refreshInBackground() async {
    try {
      final response = await http
          .get(Uri.parse(ApiConfig.sekolahListUrl), headers: ApiConfig.headers())
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        final schools = _parseSchoolListResponse(response.body);
        await _cacheSchoolList(schools);
      }
    } catch (_) {
      // silent fail, cache lama tetap dipakai
    }
  }

  // ─── Parse response body, toleran terhadap beberapa bentuk envelope ──────
  // Bisa berupa: [ {...}, {...} ]  ATAU  { data: [ {...}, {...} ] }
  // ATAU  { data: { data: [ {...} ] } } (nested envelope interceptor NestJS)
  static List<School> _parseSchoolListResponse(String body) {
    final decoded = json.decode(body);

    List<dynamic> rawList;
    if (decoded is List) {
      rawList = decoded;
    } else if (decoded is Map<String, dynamic>) {
      final inner = decoded['data'];
      if (inner is List) {
        rawList = inner;
      } else if (inner is Map<String, dynamic> && inner['data'] is List) {
        rawList = inner['data'] as List<dynamic>;
      } else {
        rawList = [];
      }
    } else {
      rawList = [];
    }

    return rawList
        .map((e) => School.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> _cacheSchoolList(List<School> schools) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = schools.map((s) => s.toJson()).toList();
    await prefs.setString(_cachedSchoolListKey, json.encode(jsonList));
  }

  static Future<List<School>?> _getCachedSchoolList() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_cachedSchoolListKey);
    if (cached == null) return null;

    final List<dynamic> jsonList = json.decode(cached);
    return jsonList.map((e) => School.fromJson(e)).toList();
  }

  // =====================
  // GET SELECTED SCHOOL
  // =====================
  static Future<School?> getSelectedSchool() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final idSekolah = prefs.getInt(_selectedSchoolKey);
      if (idSekolah == null) return null;

      final cached = await _getCachedSchoolList();
      if (cached == null) return null;

      try {
        return cached.firstWhere((school) => school.idSekolah == idSekolah);
      } catch (_) {
        return null;
      }
    } catch (e) {
      print('Error getting selected school: $e');
      return null;
    }
  }

  // =====================
  // SET SELECTED SCHOOL
  // =====================
  static Future<bool> setSelectedSchool(int idSekolah) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_selectedSchoolKey, idSekolah);
      return true;
    } catch (e) {
      print('Error setting selected school: $e');
      return false;
    }
  }

  // =====================
  // CLEAR SELECTED SCHOOL
  // =====================
  static Future<void> clearSelectedSchool() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_selectedSchoolKey);
    } catch (e) {
      print('Error clearing selected school: $e');
    }
  }

  // =====================
  // CHECK IF SCHOOL SELECTED
  // =====================
  static Future<bool> hasSelectedSchool() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey(_selectedSchoolKey);
    } catch (e) {
      print('Error checking selected school: $e');
      return false;
    }
  }
}

// =====================
// SCHOOL MODEL
// =====================
class School {
  final int idSekolah;
  final String name;

  const School({
    required this.idSekolah,
    required this.name,
  });

  Map<String, dynamic> toJson() => {
        'idSekolah': idSekolah,
        'name': name,
      };

  // Toleran terhadap beberapa kemungkinan nama field dari backend,
  // karena belum ada konfirmasi pasti bentuk response GET /sekolah.
  factory School.fromJson(Map<String, dynamic> json) {
    final rawId = json['idSekolah'] ?? json['id'] ?? json['id_sekolah'];
    final id = rawId is int ? rawId : int.tryParse(rawId.toString()) ?? 0;

    final rawName = json['name'] ??
        json['namaSekolah'] ??
        json['nama_sekolah'] ??
        json['nama'] ??
        '';

    return School(
      idSekolah: id,
      name: rawName.toString(),
    );
  }
}