import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen_ortu.dart';
import 'home_screen_kepsek.dart';
import 'school_selection_screen.dart';
import 'package:absensi_siswa/services/school_config.dart';
import '../services/api_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // 'ortu' atau 'admin'
  String _tipeAkun = 'ortu';

  bool _obscurePassword = true;
  bool _isLoading = false;
  String _schoolName = '';

  // Controller untuk ORTU
  final TextEditingController nameController = TextEditingController();
  final TextEditingController nisnController = TextEditingController();

  // Controller untuk ADMIN / KEPALA SEKOLAH
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSchoolInfo();
    _checkExistingToken();
  }

  Future<void> _loadSchoolInfo() async {
    final school = await SchoolConfig.getSelectedSchool();
    if (mounted && school != null) {
      setState(() {
        _schoolName = school.name;
      });
    }
  }

  Future<void> _checkExistingToken() async {
    final isLoggedIn = await ApiService.isLoggedIn();

    if (isLoggedIn && mounted) {
      final tipeAkun = await ApiService.getTipeAkun();
      _navigateToHome(tipeAkun);
    }
  }

  Future<void> _login() async {
    Map<String, dynamic> result;

    if (_tipeAkun == 'ortu') {
      final name = nameController.text.trim();
      final nisn = nisnController.text.trim();

      if (name.isEmpty || nisn.isEmpty) {
        _showMessage('Nama dan NISN tidak boleh kosong', isError: true);
        return;
      }

      setState(() => _isLoading = true);

      result = await ApiService.loginOrtu(nama: name, nisn: nisn);
    } else {
      final username = usernameController.text.trim();
      final password = passwordController.text.trim();

      if (username.isEmpty || password.isEmpty) {
        _showMessage('Username dan password tidak boleh kosong', isError: true);
        return;
      }

      setState(() => _isLoading = true);

      result = await ApiService.loginAdmin(username: username, password: password);
    }

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (result['success']) {
      _showMessage('Login berhasil', isError: false);

      final loginData = result['data'];
      final tipeAkunResponse = loginData['tipeAkun'] as String?;

      // Kirim FCM Token hanya untuk akun ortu (butuh idSiswa)
      // ⚠️ Untuk akun admin, mekanisme FCM token belum dikonfirmasi
      // (kemungkinan pakai idPengguna, bukan idSiswa)
      if (tipeAkunResponse == 'ortu') {
        await _sendFcmTokenAfterLogin(loginData);
      }

      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        _navigateToHome(tipeAkunResponse);
      }
    } else {
      _showMessage(result['message'], isError: true);
    }
  }

  // Kirim FCM Token setelah login (khusus ortu)
  Future<void> _sendFcmTokenAfterLogin(dynamic loginData) async {
    try {
      final siswaData = loginData['profil'];

      if (siswaData == null || siswaData['idSiswa'] == null) {
        print('⚠️ Siswa data tidak ditemukan di response login');
        return;
      }

      final rawSiswaId = siswaData['idSiswa'];
      final int? siswaId = rawSiswaId is int
          ? rawSiswaId
          : int.tryParse(rawSiswaId.toString());

      if (siswaId == null) {
        print('⚠️ idSiswa tidak valid: $rawSiswaId');
        return;
      }

      print('📱 Getting FCM token...');
      String? fcmToken = await FirebaseMessaging.instance.getToken();

      if (fcmToken == null || fcmToken.isEmpty) {
        print('⚠️ FCM Token tidak tersedia');
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('pending_fcm_sync', 'true');
        return;
      }

      print('🔄 Sending FCM token to backend...');

      final fcmResult = await ApiService.saveFcmToken(
        siswaId: siswaId,
        fcmToken: fcmToken,
      );

      final prefs = await SharedPreferences.getInstance();
      if (fcmResult['success'] == true) {
        print('✅ FCM Token berhasil dikirim ke backend');
        await prefs.remove('pending_fcm_sync');
      } else {
        print('❌ Gagal mengirim FCM Token: ${fcmResult['message']}');
        await prefs.setString('pending_fcm_token', fcmToken);
        await prefs.setString('pending_fcm_sync', 'true');
      }
    } catch (e) {
      print('❌ Error sending FCM token after login: $e');
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('pending_fcm_sync', 'true');
      } catch (_) {}
    }
  }

  void _navigateToHome(String? tipeAkun) {
    if (tipeAkun == 'admin') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreenKepsek()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreenOrtu()),
      );
    }
  }

  Future<void> _changeSchool() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ganti Sekolah'),
        content: const Text(
          'Apakah Anda yakin ingin mengganti sekolah? '
          'Data login Anda akan dihapus.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Ya, Ganti',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ApiService.clearAllData();
      await SchoolConfig.clearSelectedSchool();

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const SchoolSelectionScreen()),
        );
      }
    }
  }

  void _showMessage(String message, {required bool isError}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    nisnController.dispose();
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFFFFC107),
      body: SafeArea(
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(bottom: keyboardHeight),
          child: SingleChildScrollView(
            child: SizedBox(
              height: screenHeight,
              child: Column(
                children: [
                  // ===== HEADER =====
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Icon(Icons.school, size: 48),
                            TextButton.icon(
                              onPressed: _isLoading ? null : _changeSchool,
                              icon: const Icon(
                                Icons.swap_horiz,
                                size: 18,
                                color: Colors.black87,
                              ),
                              label: const Text(
                                'Ganti',
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Hello!',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Selamat datang kembali',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                        ),
                        if (_schoolName.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.location_on,
                                  size: 16,
                                  color: Colors.black87,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    _schoolName,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const Spacer(),

                  // ===== LOGIN CARD =====
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Login',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        const SizedBox(height: 16),

                        // ===== TAB TOGGLE TIPE AKUN =====
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: _tabButton(
                                  label: 'Orang Tua',
                                  isActive: _tipeAkun == 'ortu',
                                  onTap: () => setState(() => _tipeAkun = 'ortu'),
                                ),
                              ),
                              Expanded(
                                child: _tabButton(
                                  label: 'Kepala Sekolah',
                                  isActive: _tipeAkun == 'admin',
                                  onTap: () => setState(() => _tipeAkun = 'admin'),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // ===== FORM SESUAI TIPE AKUN =====
                        if (_tipeAkun == 'ortu') ...[
                          _inputField(
                            controller: nameController,
                            hint: 'Nama Siswa',
                            icon: Icons.person_outline,
                          ),
                          const SizedBox(height: 16),
                          _inputField(
                            controller: nisnController,
                            hint: 'NISN',
                            icon: Icons.badge_outlined,
                            obscure: _obscurePassword,
                            suffix: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                          ),
                        ] else ...[
                          _inputField(
                            controller: usernameController,
                            hint: 'Username',
                            icon: Icons.person_outline,
                          ),
                          const SizedBox(height: 16),
                          _inputField(
                            controller: passwordController,
                            hint: 'Password',
                            icon: Icons.lock_outline,
                            obscure: _obscurePassword,
                            suffix: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                          ),
                        ],

                        const SizedBox(height: 32),

                        // ===== LOGIN BUTTON =====
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFE000),
                              disabledBackgroundColor:
                                  const Color(0xFFFFE000).withOpacity(0.6),
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
                                    'Login',
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tabButton({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: _isLoading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFFFC107) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isActive ? Colors.black : Colors.black45,
          ),
        ),
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      enabled: !_isLoading,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}