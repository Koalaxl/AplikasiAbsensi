import 'package:shared_preferences/shared_preferences.dart';

class SchoolConfig {
  // =====================
  // DAFTAR SEKOLAH
  // =====================
  static const List<School> availableSchools = [
    School(
      id: 'testing',
      name: 'Testing Environment',
      baseUrl: 'https://projekb3.skyznode.my.id/api',
    ),
    School(
      id: 'smpn1_cicalengka',
      name: 'SMPN 1 CICALENGKA',
      baseUrl: 'https://clkabsensi.skyznode.my.id/api',
    ),
    School(
      id: 'smpn1_nagreg',
      name: 'SMPN 1 NAGREG',
      baseUrl: 'https://nasa.skyznode.my.id/api',
    ),
  ];

  // =====================
  // STORAGE KEY
  // =====================
  static const String _selectedSchoolKey = 'selected_school_id';

  // =====================
  // GET SELECTED SCHOOL
  // =====================
  static Future<School?> getSelectedSchool() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final schoolId = prefs.getString(_selectedSchoolKey);

      if (schoolId == null) return null;

      return availableSchools.firstWhere(
        (school) => school.id == schoolId,
        orElse: () => availableSchools.first,
      );
    } catch (e) {
      print('Error getting selected school: $e');
      return null;
    }
  }

  // =====================
  // SET SELECTED SCHOOL
  // =====================
  static Future<bool> setSelectedSchool(String schoolId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_selectedSchoolKey, schoolId);
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

  // =====================
  // GET SCHOOL BY ID
  // =====================
  static School? getSchoolById(String schoolId) {
    try {
      return availableSchools.firstWhere(
        (school) => school.id == schoolId,
      );
    } catch (e) {
      return null;
    }
  }
}

// =====================
// SCHOOL MODEL
// =====================
class School {
  final String id;
  final String name;
  final String baseUrl;

  const School({
    required this.id,
    required this.name,
    required this.baseUrl,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'baseUrl': baseUrl,
    };
  }

  factory School.fromJson(Map<String, dynamic> json) {
    return School(
      id: json['id'] as String,
      name: json['name'] as String,
      baseUrl: json['baseUrl'] as String,
    );
  }
}