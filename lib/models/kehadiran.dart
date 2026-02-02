class Kehadiran {
  final int id;
  final int siswaId;
  final String tanggal;
  final String status;
  final String? keterangan;
  final String? jamMasuk;
  final String? jamKeluar;

  Kehadiran({
    required this.id,
    required this.siswaId,
    required this.tanggal,
    required this.status,
    this.keterangan,
    this.jamMasuk,
    this.jamKeluar,
  });

  // =====================
  // FROM JSON (API → Flutter)
  // =====================
  factory Kehadiran.fromJson(Map<String, dynamic> json) {
    return Kehadiran(
      id: json['id'],
      siswaId: json['siswa_id'],
      tanggal: json['tanggal'],
      status: json['status'],
      keterangan: json['keterangan'],
      jamMasuk: json['jam_masuk'],
      jamKeluar: json['jam_keluar'],
    );
  }

  // =====================
  // TO JSON (Flutter → API)
  // =====================
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'siswa_id': siswaId,
      'tanggal': tanggal,
      'status': status,
      'keterangan': keterangan,
      'jam_masuk': jamMasuk,
      'jam_keluar': jamKeluar,
    };
  }
}
