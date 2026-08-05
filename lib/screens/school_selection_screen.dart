import 'package:flutter/material.dart';
import 'package:absensi_siswa/services/school_config.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'login_screen.dart';

class SchoolSelectionScreen extends StatefulWidget {
  const SchoolSelectionScreen({super.key});

  @override
  State<SchoolSelectionScreen> createState() => _SchoolSelectionScreenState();
}

class _SchoolSelectionScreenState extends State<SchoolSelectionScreen> {
  School? _selectedSchool;
  bool _isLoading = false;

  // Fetch state daftar sekolah
  bool _isLoadingSchools = true;
  String? _loadError;
  List<School> _schools = [];

  @override
  void initState() {
    super.initState();
    requestNotificationPermission();
    _loadSchools();
  }

  // ===== REQUEST NOTIFICATION PERMISSION =====
  Future<void> requestNotificationPermission() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted notification permission');
    } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
      print('User granted provisional notification permission');
    } else {
      print('User declined or has not accepted notification permission');
    }
  }

  // ===== LOAD DAFTAR SEKOLAH DARI API =====
  Future<void> _loadSchools({bool forceRefresh = false}) async {
    setState(() {
      _isLoadingSchools = true;
      _loadError = null;
    });

    try {
      final schools = await SchoolConfig.fetchSchoolList(forceRefresh: forceRefresh);

      if (!mounted) return;

      setState(() {
        _schools = schools;
        _isLoadingSchools = false;
        // reset pilihan kalau sekolah yang sebelumnya dipilih sudah tidak ada di list baru
        if (_selectedSchool != null &&
            !_schools.any((s) => s.idSekolah == _selectedSchool!.idSekolah)) {
          _selectedSchool = null;
        }
        if (schools.isEmpty) {
          _loadError = 'Gagal memuat daftar sekolah';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingSchools = false;
        _loadError = 'Gagal memuat daftar sekolah, periksa koneksi internet';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFC107),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Lebar maksimum konten supaya di tablet/desktop tidak melebar penuh
            final maxContentWidth = constraints.maxWidth > 600 ? 480.0 : double.infinity;

            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      // ===== HEADER =====
                      Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: maxContentWidth),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Icon(Icons.school, size: 48),
                                SizedBox(height: 16),
                                Text(
                                  'Pilih Sekolah',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Silakan pilih sekolah Anda',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const Spacer(),

                      // ===== SCHOOL SELECTION CARD =====
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFF3B0),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(32),
                            topRight: Radius.circular(32),
                          ),
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: maxContentWidth),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Daftar Sekolah',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (!_isLoadingSchools)
                                      IconButton(
                                        onPressed: () => _loadSchools(forceRefresh: true),
                                        icon: const Icon(Icons.refresh, size: 20),
                                        tooltip: 'Muat ulang',
                                      ),
                                  ],
                                ),

                                const SizedBox(height: 16),

                                // ===== LOADING / ERROR / DROPDOWN STATE =====
                                if (_isLoadingSchools)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 32),
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        color: Colors.black54,
                                      ),
                                    ),
                                  )
                                else if (_loadError != null)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 24),
                                    child: Column(
                                      children: [
                                        const Icon(Icons.error_outline,
                                            color: Colors.redAccent, size: 32),
                                        const SizedBox(height: 8),
                                        Text(
                                          _loadError!,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(color: Colors.black54),
                                        ),
                                        const SizedBox(height: 12),
                                        TextButton(
                                          onPressed: () => _loadSchools(forceRefresh: true),
                                          child: const Text('Coba lagi'),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  _buildSchoolDropdown(),

                                const SizedBox(height: 32),

                                // ===== CONTINUE BUTTON =====
                                SizedBox(
                                  width: double.infinity,
                                  height: 52,
                                  child: ElevatedButton(
                                    onPressed: _selectedSchool == null || _isLoading
                                        ? null
                                        : _continueToLogin,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFFFE000),
                                      disabledBackgroundColor:
                                          const Color(0xFFFFE000).withOpacity(0.5),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      elevation: 0,
                                    ),
                                    child: _isLoading
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.black,
                                            ),
                                          )
                                        : const Text(
                                            'Lanjutkan',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.black,
                                            ),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ===== DROPDOWN SEKOLAH =====
  Widget _buildSchoolDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _selectedSchool != null
              ? const Color(0xFFFFC107)
              : Colors.transparent,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<School>(
          value: _selectedSchool,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          borderRadius: BorderRadius.circular(16),
          decoration: const InputDecoration(
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 14),
          ),
          hint: const Text(
            'Pilih sekolah Anda',
            style: TextStyle(fontSize: 16, color: Colors.black54),
          ),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
          selectedItemBuilder: (context) {
            return _schools.map((school) {
              return Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  school.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              );
            }).toList();
          },
          items: _schools.map((school) {
            final isSelected = _selectedSchool?.idSekolah == school.idSekolah;
            return DropdownMenuItem<School>(
              value: school,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      school.name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                  if (isSelected)
                    const Icon(
                      Icons.check_circle,
                      color: Color(0xFFFFC107),
                      size: 20,
                    ),
                ],
              ),
            );
          }).toList(),
          onChanged: _isLoading
              ? null
              : (School? value) {
                  setState(() {
                    _selectedSchool = value;
                  });
                },
        ),
      ),
    );
  }

  Future<void> _continueToLogin() async {
    if (_selectedSchool == null) return;

    setState(() {
      _isLoading = true;
    });

    // Simpan pilihan sekolah
    final success = await SchoolConfig.setSelectedSchool(_selectedSchool!.idSekolah);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (success) {
      // Navigate ke login screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } else {
      // Show error
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal menyimpan pilihan sekolah'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}