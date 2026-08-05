// ⚠️ Bentuk response asli GET /app-pesan/inbox belum dikonfirmasi di
//    dokumentasi API (baru terlihat endpoint + deskripsinya saja). Parsing
//    di bawah ini dibuat TOLERAN terhadap beberapa kemungkinan nama field
//    (pola yang sama seperti School.fromJson di school_config.dart).
//    Setelah endpoint ini dites dengan data asli, cek `print` response body
//    di ApiService.getInboxPesan() dan sesuaikan key di sini kalau meleset.

class Pesan {
  /// idPenerima WAJIB ada — dipakai sebagai path param untuk
  /// PATCH .../dibaca dan DELETE .../{idPenerima}.
  final int idPenerima;
  final int? idPesan;
  final String judul;
  final String isi;
  final bool dibaca;
  final DateTime? createdAt;
  final String? pengirim;

  const Pesan({
    required this.idPenerima,
    this.idPesan,
    required this.judul,
    required this.isi,
    required this.dibaca,
    this.createdAt,
    this.pengirim,
  });

  factory Pesan.fromJson(Map<String, dynamic> json) {
    final rawIdPenerima =
        json['idPenerima'] ?? json['id_penerima'] ?? json['id'];
    final idPenerima = rawIdPenerima is int
        ? rawIdPenerima
        : int.tryParse(rawIdPenerima?.toString() ?? '') ?? 0;

    final rawIdPesan = json['idPesan'] ?? json['id_pesan'];
    final idPesan = rawIdPesan == null
        ? null
        : (rawIdPesan is int
            ? rawIdPesan
            : int.tryParse(rawIdPesan.toString()));

    final judul =
        (json['judul'] ?? json['subjek'] ?? json['title'] ?? 'Pesan')
            .toString();

    final isi = (json['isi'] ??
            json['isiPesan'] ??
            json['pesan'] ??
            json['body'] ??
            json['content'] ??
            '')
        .toString();

    final rawDibaca =
        json['dibaca'] ?? json['sudahDibaca'] ?? json['isRead'] ?? json['read'];
    final dibaca = rawDibaca == true || rawDibaca == 1 || rawDibaca == '1';

    DateTime? createdAt;
    final rawDate = json['createdAt'] ??
        json['created_at'] ??
        json['tanggal'] ??
        json['tanggalKirim'];
    if (rawDate != null) {
      createdAt = DateTime.tryParse(rawDate.toString());
    }

    String? pengirim;
    final rawPengirim =
        json['pengirim'] ?? json['dari'] ?? json['sender'] ?? json['namaPengirim'];
    if (rawPengirim is String) {
      pengirim = rawPengirim;
    } else if (rawPengirim is Map) {
      pengirim = (rawPengirim['nama'] ??
              rawPengirim['namaSekolah'] ??
              rawPengirim['name'])
          ?.toString();
    }

    return Pesan(
      idPenerima: idPenerima,
      idPesan: idPesan,
      judul: judul,
      isi: isi,
      dibaca: dibaca,
      createdAt: createdAt,
      pengirim: pengirim,
    );
  }

  Pesan copyWith({bool? dibaca}) {
    return Pesan(
      idPenerima: idPenerima,
      idPesan: idPesan,
      judul: judul,
      isi: isi,
      dibaca: dibaca ?? this.dibaca,
      createdAt: createdAt,
      pengirim: pengirim,
    );
  }
}