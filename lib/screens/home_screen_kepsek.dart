import 'dart:async';
import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'school_selection_screen.dart';
import 'package:absensi_siswa/services/school_config.dart';
import '../services/api_service.dart';

class HomeScreenKepsek extends StatefulWidget {
  const HomeScreenKepsek({super.key});

  @override
  State<HomeScreenKepsek> createState() => _HomeScreenKepsekState();
}

class _HomeScreenKepsekState extends State<HomeScreenKepsek> {
  bool _loading = true;
  String _errorMessage = '';
  String _schoolName = '';

  // Data dashboard - siswa
  String _tanggal = '-';
  int _totalSiswa = 0;
  int _hadir = 0;
  int _izin = 0;
  int _sakit = 0;
  int _alpha = 0;
  int _belumAbsen = 0;

  // Data dashboard - guru (BARU)
  int _totalGuru = 0;
  int _hadirGuru = 0;
  int _izinGuru = 0;
  int _sakitGuru = 0;
  int _alphaGuru = 0;
  int _belumAbsenGuru = 0;

  List<dynamic> _guruAlpha = [];

  Timer? _refreshTimer;

  static const List<String> _bulanIndo = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
  ];

  @override
  void initState() {
    super.initState();
    _loadSchoolInfo();
    _loadDashboard();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    // Auto refresh tiap 30 detik (dashboard tidak butuh se-realtime kehadiran mentah)
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted && !_loading) {
        _loadDashboard(silentRefresh: true);
      }
    });
  }

  Future<void> _loadSchoolInfo() async {
    final school = await SchoolConfig.getSelectedSchool();
    if (mounted && school != null) {
      setState(() {
        _schoolName = school.name;
      });
    }
  }

  Future<void> _loadDashboard({bool silentRefresh = false}) async {
    if (!silentRefresh) {
      setState(() {
        _loading = true;
        _errorMessage = '';
      });
    }

    final result = await ApiService.getDashboardKepsek();

    if (!mounted) return;

    if (result['success'] == true) {
      final data = result['data'] ?? {};
      final statistikSiswa = data['statistikSiswa'] ?? {};
      final statistikGuru = data['statistikGuru'] ?? {}; // ← BARU

      setState(() {
        _tanggal = data['tanggal'] ?? '-';

        _totalSiswa = statistikSiswa['totalSiswa'] ?? 0;
        _hadir = statistikSiswa['hadir'] ?? 0;
        _izin = statistikSiswa['izin'] ?? 0;
        _sakit = statistikSiswa['sakit'] ?? 0;
        _alpha = statistikSiswa['alpha'] ?? 0;
        _belumAbsen = statistikSiswa['belumAbsen'] ?? 0;

        // ← BARU
        _totalGuru = statistikGuru['totalGuru'] ?? 0;
        _hadirGuru = statistikGuru['hadir'] ?? 0;
        _izinGuru = statistikGuru['izin'] ?? 0;
        _sakitGuru = statistikGuru['sakit'] ?? 0;
        _alphaGuru = statistikGuru['alpha'] ?? 0;
        _belumAbsenGuru = statistikGuru['belumAbsen'] ?? 0;

        _guruAlpha = data['guruAlpha'] ?? [];
        _loading = false;
      });
    } else {
      setState(() {
        _loading = false;
        _errorMessage = result['message'] ?? 'Gagal memuat dashboard';
      });

      if (result['unauthorized'] == true) {
        _logout();
      }
    }
  }

  String _formatTanggal(String date) {
    try {
      final parsed = DateTime.parse(date);
      const days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
      final dayName = days[parsed.weekday - 1];
      return '$dayName, ${parsed.day} ${_bulanIndo[parsed.month - 1]} ${parsed.year}';
    } catch (e) {
      return date;
    }
  }

  Future<void> _logout() async {
    _refreshTimer?.cancel();
    await ApiService.logout();
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  Future<void> _changeSchool() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ganti Sekolah'),
        content: const Text(
          'Apakah Anda yakin ingin mengganti sekolah? '
          'Anda akan keluar dari akun ini.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ya, Ganti', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _refreshTimer?.cancel();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFC107),
      body: SafeArea(
        child: Column(
          children: [
            // ===== HEADER =====
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Dashboard Sekolah',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      TextButton(
                        onPressed: _logout,
                        child: const Text(
                          'Logout',
                          style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),

                  if (_schoolName.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.school, size: 16, color: Colors.black87),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    _schoolName,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: _changeSchool,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.swap_horiz, size: 20, color: Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ],

                  if (!_loading && _errorMessage.isEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      _formatTanggal(_tanggal),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ===== CONTENT =====
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF3B0),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32),
                  ),
                ),
                child: _buildContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFFC107)),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.black54),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => _loadDashboard(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFC107),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Coba Lagi', style: TextStyle(color: Colors.black)),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadDashboard(),
      color: const Color(0xFFFFC107),
      child: ListView(
        children: [
          // ===== SECTION: SISWA =====
          const Text(
            'Kehadiran Siswa',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),

          // ===== KARTU TOTAL SISWA =====
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total Siswa',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  '$_totalSiswa',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // ===== GRID STATISTIK SISWA =====
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.6,
            children: [
              _statCard('Hadir', _hadir, const Color(0xFFE6F4EA), const Color(0xFF1E8E3E)),
              _statCard('Izin', _izin, const Color(0xFFFFF4E5), const Color(0xFFE65100)),
              _statCard('Sakit', _sakit, const Color(0xFFE3F2FD), const Color(0xFF1565C0)),
              _statCard('Alpha', _alpha, const Color(0xFFFDECEC), const Color(0xFFC62828)),
            ],
          ),

          const SizedBox(height: 12),

          // ===== BELUM ABSEN SISWA =====
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.hourglass_empty, color: Colors.black54),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Belum Absen',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                Text(
                  '$_belumAbsen',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
          ),

          // ===== SECTION: GURU (BARU) =====
          const Text(
            'Kehadiran Guru',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),

          // ===== KARTU TOTAL GURU (BARU) =====
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total Guru',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  '$_totalGuru',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // ===== GRID STATISTIK GURU (BARU) =====
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.6,
            children: [
              _statCard('Hadir', _hadirGuru, const Color(0xFFE6F4EA), const Color(0xFF1E8E3E)),
              _statCard('Izin', _izinGuru, const Color(0xFFFFF4E5), const Color(0xFFE65100)),
              _statCard('Sakit', _sakitGuru, const Color(0xFFE3F2FD), const Color(0xFF1565C0)),
              _statCard('Alpha', _alphaGuru, const Color(0xFFFDECEC), const Color(0xFFC62828)),
            ],
          ),

          const SizedBox(height: 12),

          // ===== BELUM ABSEN GURU (BARU) =====
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.hourglass_empty, color: Colors.black54),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Belum Absen',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                Text(
                  '$_belumAbsenGuru',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
          ),

          // ===== GURU ALPHA (DAFTAR NAMA) =====
          const Text(
            'Guru Alpha Hari Ini',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),

          if (_guruAlpha.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                children: [
                  Icon(Icons.check_circle_outline, size: 40, color: Colors.green),
                  SizedBox(height: 8),
                  Text(
                    'Semua guru hadir hari ini',
                    style: TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            )
          else
            ..._guruAlpha.map((guru) {
              final nama = guru['namaGuru'] ?? '-';
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDECEC),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.person_off, color: Color(0xFFC62828), size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        nama,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _statCard(String label, int value, Color bg, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$value',
            style: TextStyle(
              color: textColor,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}