import 'package:flutter/material.dart';
import 'home_screen.dart';
import '../services/api_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _obscurePassword = true;
  bool _isLoading = false;

  final TextEditingController nameController = TextEditingController();
  final TextEditingController nisnController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkExistingToken();
  }

  Future<void> _checkExistingToken() async {
    final isLoggedIn = await ApiService.isLoggedIn();
    
    if (isLoggedIn && mounted) {
      // Langsung ke home, tidak perlu validasi token lagi
      _navigateToHome();
    }
  }

  Future<void> _login() async {
    final name = nameController.text.trim();
    final nisn = nisnController.text.trim();

    if (name.isEmpty || nisn.isEmpty) {
      _showMessage('Nama dan NISN tidak boleh kosong', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final result = await ApiService.login(
      nama: name,
      nisn: nisn,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (result['success']) {
      _showMessage('Login berhasil', isError: false);
      
      // Tunggu sebentar agar snackbar terlihat
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (mounted) {
        _navigateToHome();
      }
    } else {
      _showMessage(result['message'], isError: true);
    }
  }

  void _navigateToHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
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
          child: SizedBox(
            height: screenHeight,
            child: Column(
              children: [
                // ===== HEADER =====
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Icon(Icons.school, size: 48),
                        SizedBox(height: 16),
                        Text(
                          'Hello!',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Welcome Student',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const Spacer(),

                // ===== LOGIN CARD =====
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
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

                      const SizedBox(height: 24),

                      // ===== NAME INPUT =====
                      _inputField(
                        controller: nameController,
                        hint: 'Nama Siswa',
                        icon: Icons.person_outline,
                      ),

                      const SizedBox(height: 16),

                      // ===== NISN INPUT =====
                      _inputField(
                        controller: nisnController,
                        hint: 'Password (NISN)',
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

                      const SizedBox(height: 32),

                      // ===== LOGIN BUTTON =====
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFE000),
                            disabledBackgroundColor: const Color(0xFFFFE000).withOpacity(0.6),
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