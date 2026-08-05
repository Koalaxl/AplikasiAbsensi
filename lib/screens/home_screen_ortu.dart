import 'dart:async';
import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'school_selection_screen.dart';
import 'package:absensi_siswa/services/school_config.dart';
import '../services/api_service.dart';
import '../models/pesan.dart';

class HomeScreenOrtu extends StatefulWidget {
  const HomeScreenOrtu({super.key});

  @override
  State<HomeScreenOrtu> createState() => _HomeScreenOrtuState();
}

class _HomeScreenOrtuState extends State<HomeScreenOrtu> {
  bool _loading = true;
  String _errorMessage = '';
  String _schoolName = '';

  // Data dari API
  String _namaSiswa = '-';
  String _namaKelas = '-';
  List<dynamic> _riwayat = [];

  // Bulan yang sedang ditampilkan
  late DateTime _selectedMonth;

  // ── Auto-refresh & info waktu update ─────────────────────────────────
  Timer? _refreshTimer;
  DateTime? _lastUpdated;
  bool _isSilentRefreshing = false;

  // ── BARU: Inbox pesan (dropdown, bukan halaman terpisah) ────────────
  List<Pesan> _inbox = [];
  bool _inboxOpen = false;
  bool _inboxLoading = false;
  String? _inboxError;

  int get _unreadCount => _inbox.where((p) => !p.dibaca).length;

  static const List<String> _bulanIndo = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
  ];

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
    _loadSchoolInfo();
    _loadRiwayat();
    _loadInbox(silent: true);
    _startAutoRefresh();

    // BARU: simpan/sinkron token FCM device begitu halaman ortu terbuka
    // (dipanggil tanpa await — jalan di background, tidak menghambat UI).
    ApiService.initAndSyncFcmToken();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  // ── Auto-refresh tiap 30 detik ────────────────────────────────────────
  // Riwayat kehadiran hanya di-refresh kalau lagi lihat bulan berjalan.
  // Inbox pesan SELALU di-refresh setiap tick, tidak tergantung bulan yang
  // sedang dilihat, supaya badge notifikasi tetap update.
  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (!mounted) return;
      if (!_loading && _isCurrentMonth) {
        _loadRiwayat(silentRefresh: true);
      }
      _loadInbox(silent: true);
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

  String get _bulanParam {
    // format "yyyy-MM" contoh "2026-07"
    final mm = _selectedMonth.month.toString().padLeft(2, '0');
    return '${_selectedMonth.year}-$mm';
  }

  Future<void> _loadRiwayat({bool silentRefresh = false}) async {
    if (silentRefresh) {
      setState(() => _isSilentRefreshing = true);
    } else {
      setState(() {
        _loading = true;
        _errorMessage = '';
      });
    }

    final result = await ApiService.getRiwayatKehadiranOrtu(bulan: _bulanParam);

    if (!mounted) return;

    if (result['success'] == true) {
      final data = result['data'] ?? {};

      // 'kelas' berbentuk object di response, coba beberapa kemungkinan key
      String namaKelas = '-';
      final kelasData = data['kelas'];
      if (kelasData is Map) {
        namaKelas = (kelasData['namaKelas'] ??
                kelasData['nama_kelas'] ??
                kelasData['nama'] ??
                '-')
            .toString();
      } else if (kelasData is String) {
        namaKelas = kelasData;
      }

      setState(() {
        _namaSiswa = data['namaSiswa'] ?? '-';
        _namaKelas = namaKelas;
        _riwayat = data['riwayat'] ?? [];
        _loading = false;
        _isSilentRefreshing = false;
        _lastUpdated = DateTime.now();
      });
    } else {
      setState(() {
        _loading = false;
        _isSilentRefreshing = false;
        // Kalau silent refresh gagal, jangan timpa layar dengan error —
        // data lama tetap ditampilkan, coba lagi di siklus berikutnya.
        if (!silentRefresh) {
          _errorMessage = result['message'] ?? 'Gagal memuat data';
        }
      });

      if (result['unauthorized'] == true) {
        _logout();
      }
    }
  }

  // ── BARU: Inbox pesan ─────────────────────────────────────────────────

  Future<void> _loadInbox({bool silent = false}) async {
    if (!silent) setState(() => _inboxLoading = true);

    final result = await ApiService.getInboxPesan();

    if (!mounted) return;

    if (result['success'] == true) {
      final data = result['data'];
      setState(() {
        _inbox = data is List<Pesan> ? data : <Pesan>[];
        _inboxLoading = false;
        _inboxError = null;
      });
    } else {
      setState(() {
        _inboxLoading = false;
        // Silent refresh gagal -> jangan ganggu badge/panel yang sudah ada,
        // data lama tetap ditampilkan.
        if (!silent) {
          _inboxError = result['message'] ?? 'Gagal memuat pesan';
        }
      });

      if (result['unauthorized'] == true) {
        _logout();
      }
    }
  }

  void _toggleInbox() {
    setState(() => _inboxOpen = !_inboxOpen);
    if (_inboxOpen) {
      _loadInbox();
    }
  }

  Future<void> _tandaiDibaca(Pesan pesan) async {
    if (pesan.dibaca) return;

    // Optimistic update: langsung update UI, panggil API di background.
    setState(() {
      _inbox = _inbox
          .map((p) => p.idPenerima == pesan.idPenerima ? p.copyWith(dibaca: true) : p)
          .toList();
    });

    final result = await ApiService.tandaiPesanDibaca(pesan.idPenerima);
    if (!mounted) return;

    if (result['success'] != true) {
      // Gagal -> kembalikan status seperti semula.
      setState(() {
        _inbox = _inbox
            .map((p) => p.idPenerima == pesan.idPenerima ? p.copyWith(dibaca: false) : p)
            .toList();
      });
      if (result['unauthorized'] == true) _logout();
    }
  }

  Future<void> _hapusPesanItem(Pesan pesan) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Pesan'),
        content: const Text('Yakin mau hapus pesan ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ya, Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final previousInbox = List<Pesan>.from(_inbox);
    setState(() {
      _inbox = _inbox.where((p) => p.idPenerima != pesan.idPenerima).toList();
    });

    final result = await ApiService.hapusPesan(pesan.idPenerima);
    if (!mounted) return;

    if (result['success'] != true) {
      // Gagal hapus -> kembalikan item ke list.
      setState(() => _inbox = previousInbox);
      if (result['unauthorized'] == true) {
        _logout();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Gagal menghapus pesan')),
        );
      }
    }
  }

  void _goToPreviousMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
    });
    _loadRiwayat();
  }

  void _goToNextMonth() {
    final now = DateTime.now();
    final nextMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);

    // Cegah maju ke bulan depan dari bulan berjalan
    if (nextMonth.isAfter(DateTime(now.year, now.month))) return;

    setState(() {
      _selectedMonth = nextMonth;
    });
    _loadRiwayat();
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _selectedMonth.year == now.year && _selectedMonth.month == now.month;
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

  AttendanceStatus _mapStatus(String status) {
    switch (status.toLowerCase()) {
      case 'hadir':
        return AttendanceStatus.hadir;
      case 'izin':
        return AttendanceStatus.izin;
      case 'sakit':
        return AttendanceStatus.sakit;
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
      const List<String> days = [
        'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'
      ];
      final dayName = days[parsedDate.weekday - 1];
      return '$dayName, ${parsedDate.day} ${_bulanIndo[parsedDate.month - 1]} ${parsedDate.year}';
    } catch (e) {
      return date;
    }
  }

  // ── Format jam terakhir update, contoh "14:05" ───────────────────────
  String _formatJam(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  // ── BARU: format waktu relatif untuk pesan, contoh "5 menit lalu" ────
  String _formatRelatif(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    if (diff.inDays < 7) return '${diff.inDays} hari lalu';
    return '${dt.day} ${_bulanIndo[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFC107),
      body: Stack(
        children: [
          SafeArea(
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
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          Row(
                            children: [
                              _buildBellButton(),
                              const SizedBox(width: 4),
                              TextButton(
                                onPressed: _logout,
                                child: const Text(
                                  'Logout',
                                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
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

                      // Info Siswa
                      if (!_loading && _errorMessage.isEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          _namaSiswa,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          'Kelas $_namaKelas',
                          style: const TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                      ],
                    ],
                  ),
                ),

                // ===== CONTENT =====
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFF3B0),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(32),
                        topRight: Radius.circular(32),
                      ),
                    ),
                    child: Column(
                      children: [
                        // ===== MONTH SELECTOR =====
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                onPressed: _loading ? null : _goToPreviousMonth,
                                icon: const Icon(Icons.chevron_left),
                              ),
                              Text(
                                '${_bulanIndo[_selectedMonth.month - 1]} ${_selectedMonth.year}',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              IconButton(
                                onPressed:
                                    (_loading || _isCurrentMonth) ? null : _goToNextMonth,
                                icon: const Icon(Icons.chevron_right),
                              ),
                            ],
                          ),
                        ),

                        // ── Indikator terakhir diperbarui ─────────────
                        if (!_loading && _errorMessage.isEmpty && _lastUpdated != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 300),
                                  child: _isSilentRefreshing
                                      ? const SizedBox(
                                          key: ValueKey('refreshing'),
                                          width: 12,
                                          height: 12,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.black45,
                                          ),
                                        )
                                      : const Icon(
                                          key: ValueKey('idle'),
                                          Icons.check_circle,
                                          size: 14,
                                          color: Colors.black45,
                                        ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _isSilentRefreshing
                                      ? 'Memperbarui data...'
                                      : 'Diperbarui pukul ${_formatJam(_lastUpdated!)}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.black45,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        Expanded(child: _buildContent()),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── BARU: Dropdown panel inbox pesan ──────────────────────────
          if (_inboxOpen) ..._buildInboxDropdown(),
        ],
      ),
    );
  }

  // ── BARU: tombol lonceng + badge jumlah pesan belum dibaca ────────────
  Widget _buildBellButton() {
    return InkWell(
      onTap: _toggleInbox,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(
              _inboxOpen ? Icons.notifications : Icons.notifications_none,
              color: Colors.black87,
              size: 24,
            ),
            if (_unreadCount > 0)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    _unreadCount > 9 ? '9+' : '$_unreadCount',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── BARU: overlay backdrop + panel dropdown inbox ──────────────────────
  // Dibungkus List supaya bisa dipakai dengan spread (..._buildInboxDropdown())
  // di dalam Stack: [0] backdrop transparan buat nutup panel kalau di-tap
  // di luar, [1] panel dropdown-nya sendiri.
  List<Widget> _buildInboxDropdown() {
    final topOffset = MediaQuery.of(context).padding.top + 56;

    return [
      // Backdrop — tap di luar panel buat nutup
      Positioned.fill(
        child: GestureDetector(
          onTap: () => setState(() => _inboxOpen = false),
          child: Container(color: Colors.black.withOpacity(0.15)),
        ),
      ),
      // Panel
      Positioned(
        top: topOffset,
        right: 16,
        left: 16,
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxHeight: 420),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Pesan',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        onPressed: () => setState(() => _inboxOpen = false),
                        icon: const Icon(Icons.close, size: 20),
                        splashRadius: 18,
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Flexible(child: _buildInboxBody()),
              ],
            ),
          ),
        ),
      ),
    ];
  }

  Widget _buildInboxBody() {
    if (_inboxLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFFFFC107)),
        ),
      );
    }

    if (_inboxError != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              _inboxError!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => _loadInbox(),
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }

    if (_inbox.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Text(
            'Belum ada pesan',
            style: TextStyle(color: Colors.black54),
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      itemCount: _inbox.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final pesan = _inbox[index];
        return InkWell(
          onTap: () => _tandaiDibaca(pesan),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: pesan.dibaca ? Colors.transparent : const Color(0xFFFFC107),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pesan.judul,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: pesan.dibaca ? FontWeight.w500 : FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      if (pesan.isi.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          pesan.isi,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (pesan.pengirim != null) ...[
                            Text(
                              pesan.pengirim!,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.black38,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Text(' • ', style: TextStyle(fontSize: 11, color: Colors.black38)),
                          ],
                          Text(
                            _formatRelatif(pesan.createdAt),
                            style: const TextStyle(fontSize: 11, color: Colors.black38),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () => _hapusPesanItem(pesan),
                  borderRadius: BorderRadius.circular(16),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.delete_outline, size: 18, color: Colors.black38),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
              onPressed: () => _loadRiwayat(),
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

    if (_riwayat.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _loadRiwayat(),
        color: const Color(0xFFFFC107),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 80),
            Icon(Icons.inbox_outlined, size: 64, color: Colors.black38),
            SizedBox(height: 16),
            Center(
              child: Text(
                'Belum ada data kehadiran bulan ini',
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadRiwayat(),
      color: const Color(0xFFFFC107),
      child: ListView.builder(
        itemCount: _riwayat.length,
        itemBuilder: (context, index) {
          final item = _riwayat[index];
          final tanggal = item['tanggal'] ?? '-';
          final status = item['status'] ?? 'alpha';

          // 'keterangan' berbentuk object generik, coba ambil teksnya kalau ada
          String? keterangan;
          final ketData = item['keterangan'];
          if (ketData is String && ketData.isNotEmpty) {
            keterangan = ketData;
          } else if (ketData is Map && ketData.isNotEmpty) {
            keterangan = (ketData['catatan'] ?? ketData['text'] ?? '').toString();
            if (keterangan.isEmpty) keterangan = null;
          }

          return AttendanceCard(
            tanggal: _formatDate(tanggal),
            status: _mapStatus(status),
            keterangan: keterangan,
          );
        },
      ),
    );
  }
}

/* =========================
   ATTENDANCE CARD
========================= */

enum AttendanceStatus { hadir, izin, sakit, alpha }

class AttendanceCard extends StatelessWidget {
  final String tanggal;
  final AttendanceStatus status;
  final String? keterangan;

  const AttendanceCard({
    super.key,
    required this.tanggal,
    required this.status,
    this.keterangan,
  });

  @override
  Widget build(BuildContext context) {
    final statusStyle = _statusStyle(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tanggal,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                if (keterangan != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    keterangan!,
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
    );
  }

  _StatusStyle _statusStyle(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.hadir:
        return _StatusStyle(
          label: 'Hadir',
          background: const Color(0xFFE6F4EA),
          text: const Color(0xFF1E8E3E),
        );
      case AttendanceStatus.izin:
        return _StatusStyle(
          label: 'Izin',
          background: const Color(0xFFFFF4E5),
          text: const Color(0xFFE65100),
        );
      case AttendanceStatus.sakit:
        return _StatusStyle(
          label: 'Sakit',
          background: const Color(0xFFE3F2FD),
          text: const Color(0xFF1565C0),
        );
      case AttendanceStatus.alpha:
        return _StatusStyle(
          label: 'Alpha',
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