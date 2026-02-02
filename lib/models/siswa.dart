class Siswa {
  final int id;
  final String nisn;
  final String nama;
  final int idKelas;
  final String? noOrtu;

  Siswa({
    required this.id,
    required this.nisn,
    required this.nama,
    required this.idKelas,
    this.noOrtu,
  });

  // =====================
  // FROM JSON (API → Flutter)
  // =====================
  factory Siswa.fromJson(Map<String, dynamic> json) {
    return Siswa(
      id: json['id'],
      nisn: json['nisn'],
      nama: json['nama_siswa'],
      idKelas: json['id_kelas'],
      noOrtu: json['no_ortu'],
    );
  }

  // =====================
  // TO JSON (Flutter → API)
  // =====================
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nisn': nisn,
      'nama_siswa': nama,
      'id_kelas': idKelas,
      'no_ortu': noOrtu,
    };
  }
}
