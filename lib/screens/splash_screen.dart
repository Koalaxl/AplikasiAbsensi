import 'package:flutter/material.dart';
import 'school_selection_screen.dart';
import 'login_screen.dart';
import 'home_screen.dart';
import '../services/api_service.dart';
import '../services/school_config.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeAnimation =
        CurvedAnimation(parent: _controller, curve: Curves.easeIn);

    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _controller.forward();

    // Update: Check school selection and login status
    Future.delayed(const Duration(seconds: 5), _checkInitialRoute);
  }

  // New method: Check routing based on school selection and login status
  Future<void> _checkInitialRoute() async {
    if (!mounted) return;

    // 1. Cek apakah sudah memilih sekolah
    final hasSchool = await SchoolConfig.hasSelectedSchool();

    if (!hasSchool) {
      // Belum pilih sekolah -> ke School Selection
      _navigateTo(const SchoolSelectionScreen());
      return;
    }

    // 2. Sudah pilih sekolah, cek apakah sudah login
    final isLoggedIn = await ApiService.isLoggedIn();

    if (!mounted) return;

    if (isLoggedIn) {
      // Sudah login -> ke Home
      _navigateTo(const HomeScreen());
    } else {
      // Belum login -> ke Login
      _navigateTo(const LoginScreen());
    }
  }

  // Updated navigation method with same animation
  void _navigateTo(Widget destination) {
    if (!mounted) return;
    
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (_, __, ___) => destination,
        transitionsBuilder: (_, animation, __, child) {
          final curved =
              CurvedAnimation(parent: animation, curve: Curves.easeInOut);
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.08),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFC107),
      body: Stack(
        children: [
          Positioned(
            top: -140,
            right: -140,
            child: _circle(300),
          ),
          Positioned(
            bottom: -160,
            left: -160,
            child: _circle(340),
          ),
          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(
                      Icons.school,
                      size: 64,
                      color: Colors.black,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'ABSENSI SISWA',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Mudah • Cepat • Akurat',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _circle(double size) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFFFFE000),
        shape: BoxShape.circle,
      ),
    );
  }
}