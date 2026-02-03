import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'school_selection_screen.dart';
import 'package:absensi_siswa/services/school_config.dart';
import '../services/api_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _loading = true;
  bool _loadingMore = false;
  List<dynamic> _kehadiran = [];
  List<dynamic> _allKehadiran = [];
  String _errorMessage = '';
  String _schoolName = '';
  
  // Pagination variables
  int _currentPage = 1;
  final int _perPage = 10;
  int _totalPages = 1;
  bool _hasMoreData = false;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadSchoolInfo();
    _loadKehadiran();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      if (!_loadingMore && _hasMoreData) {
        _loadMoreData();
      }
    }
  }

  Future<void> _loadSchoolInfo() async {
    final school = await SchoolConfig.getSelectedSchool();
    if (mounted && school != null) {
      setState(() {
        _schoolName = school.name;
      });
    }
  }

  Future<void> _loadKehadiran() async {
    setState(() {
      _loading = true;
      _errorMessage = '';
      _currentPage = 1;
    });

    final result = await ApiService.getKehadiran();

    if (!mounted) return;

    if (result['success'] == true) {
      final allData = result['data'] ?? [];
      
      setState(() {
        _allKehadiran = allData;
        _totalPages = (allData.length / _perPage).ceil();
        _kehadiran = _getPaginatedData(1);
        _hasMoreData = _currentPage < _totalPages;
        _loading = false;
      });
    } else {
      setState(() {
        _loading = false;
        _errorMessage = result['message'] ?? 'Gagal memuat data';
      });

      if (result['unauthorized'] == true) {
        _logout();
      }
    }
  }

  List<dynamic> _getPaginatedData(int page) {
    final startIndex = (page - 1) * _perPage;
    final endIndex = startIndex + _perPage;
    
    if (startIndex >= _allKehadiran.length) {
      return [];
    }
    
    return _allKehadiran.sublist(
      startIndex,
      endIndex > _allKehadiran.length ? _allKehadiran.length : endIndex,
    );
  }

  Future<void> _loadMoreData() async {
    if (_loadingMore || !_hasMoreData) return;

    setState(() {
      _loadingMore = true;
    });

    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    setState(() {
      _currentPage++;
      final newData = _getPaginatedData(_currentPage);
      _kehadiran.addAll(newData);
      _hasMoreData = _currentPage < _totalPages;
      _loadingMore = false;
    });
  }

  Future<void> _logout() async {
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

  AttendanceStatus _mapStatus(String status) {
    switch (status.toLowerCase()) {
      case 'hadir':
        return AttendanceStatus.hadir;
      case 'izin':
        return AttendanceStatus.izin;
      case 'sakit':
        return AttendanceStatus.izin;
      case 'alpha':
      case 'alpa':
        return AttendanceStatus.alpha;
      default:
        return AttendanceStatus.alpha;
    }
  }

  String _formatDate(String date) {
    try {
      final DateTime parsedDate = DateTime.parse(date);
      final List<String> months = [
        'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
        'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
      ];
      return '${parsedDate.day} ${months[parsedDate.month - 1]} ${parsedDate.year}';
    } catch (e) {
      return date;
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
                        'Kehadiran Anak',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: _logout,
                        child: const Text(
                          'Logout',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  // Info Sekolah & Tombol Ganti
                  if (_schoolName.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.school,
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
                            child: const Icon(
                              Icons.swap_horiz,
                              size: 20,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  
                  // Pagination Info
                  if (!_loading && _allKehadiran.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Menampilkan ${_kehadiran.length} dari ${_allKehadiran.length} data',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black54,
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
        child: CircularProgressIndicator(
          color: Color(0xFFFFC107),
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadKehadiran,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFC107),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: const Text(
                'Coba Lagi',
                style: TextStyle(color: Colors.black),
              ),
            ),
          ],
        ),
      );
    }

    if (_allKehadiran.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: Colors.black38,
            ),
            SizedBox(height: 16),
            Text(
              'Belum ada data kehadiran',
              style: TextStyle(
                fontSize: 16,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadKehadiran,
      color: const Color(0xFFFFC107),
      child: ListView.builder(
        controller: _scrollController,
        itemCount: _kehadiran.length + (_hasMoreData ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _kehadiran.length) {
            return _buildLoadingMoreIndicator();
          }

          final item = _kehadiran[index];
          
          final siswaData = item['siswa'];
          final kelasData = siswaData != null ? siswaData['kelas'] : null;
          
          final nama = siswaData?['nama_siswa'] ?? '-';
          final kelas = kelasData?['nama_kelas'] ?? '-';
          final tanggal = item['tanggal'] ?? '-';
          final status = item['status'] ?? 'alpha';

          return AttendanceCard(
            nama: nama,
            kelas: kelas,
            tanggal: _formatDate(tanggal),
            status: _mapStatus(status),
          );
        },
      ),
    );
  }

  Widget _buildLoadingMoreIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      alignment: Alignment.center,
      child: _loadingMore
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFFFFC107),
              ),
            )
          : TextButton.icon(
              onPressed: _loadMoreData,
              icon: const Icon(
                Icons.refresh,
                size: 18,
                color: Color(0xFFFFC107),
              ),
              label: const Text(
                'Muat Lebih Banyak',
                style: TextStyle(
                  color: Color(0xFFFFC107),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
    );
  }
}

/* =========================
   ATTENDANCE CARD
========================= */

enum AttendanceStatus { hadir, izin, alpha }

class AttendanceCard extends StatelessWidget {
  final String nama;
  final String kelas;
  final String tanggal;
  final AttendanceStatus status;

  const AttendanceCard({
    super.key,
    required this.nama,
    required this.kelas,
    required this.tanggal,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final statusStyle = _statusStyle(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoRow(label: 'Nama', value: nama),
          const SizedBox(height: 6),
          _infoRow(label: 'Kelas', value: kelas),
          const SizedBox(height: 6),
          _infoRow(label: 'Tanggal', value: tanggal),
          const SizedBox(height: 12),

          // Status Badge
          Row(
            children: [
              const Text(
                'Status : ',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusStyle.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusStyle.label,
                  style: TextStyle(
                    color: statusStyle.text,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoRow({required String label, required String value}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 70,
          child: Text(
            '$label :',
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  _StatusStyle _statusStyle(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.hadir:
        return _StatusStyle(
          label: "Hadir",
          background: const Color(0xFFE6F4EA),
          text: const Color(0xFF1E8E3E),
        );
      case AttendanceStatus.izin:
        return _StatusStyle(
          label: "Izin",
          background: const Color(0xFFFFF4E5),
          text: const Color(0xFFE65100),
        );
      case AttendanceStatus.alpha:
        return _StatusStyle(
          label: "Alpha",
          background: const Color(0xFFFDECEC),
          text: const Color(0xFFC62828),
        );
    }
  }
}

class _StatusStyle {
  final String label;
  final Color background;
  final Color text;

  _StatusStyle({
    required this.label,
    required this.background,
    required this.text,
  });
}