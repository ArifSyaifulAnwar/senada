// lib/Services/teguran_service.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:absensikaryawan/Services/config.dart';

class TeguranData {
  final int id;
  final String userId;
  final String? userName;
  final String? jobPosition;
  final String? department;
  final String level;
  final String judul;
  final String? deskripsi;
  final DateTime tanggal;
  final String noSurat;
  final String? issuedBy;
  final String? issuedByName;
  final DateTime createdAt;

  const TeguranData({
    required this.id,
    required this.userId,
    this.userName,
    this.jobPosition,
    this.department,
    required this.level,
    required this.judul,
    this.deskripsi,
    required this.tanggal,
    required this.noSurat,
    this.issuedBy,
    this.issuedByName,
    required this.createdAt,
  });

  static dynamic _j(Map<String, dynamic> json, String camelKey, String snakeKey) {
    if (json.containsKey(camelKey) && json[camelKey] != null) return json[camelKey];
    if (json.containsKey(snakeKey) && json[snakeKey] != null) return json[snakeKey];
    final pascalKey = camelKey[0].toUpperCase() + camelKey.substring(1);
    if (json.containsKey(pascalKey) && json[pascalKey] != null) return json[pascalKey];
    return null;
  }

  factory TeguranData.fromJson(Map<String, dynamic> json) {
    return TeguranData(
      id: (_j(json, 'id', 'id') as num?)?.toInt() ?? 0,
      userId: _j(json, 'userId', 'userid')?.toString() ?? '',
      userName: _j(json, 'userName', 'user_name')?.toString(),
      jobPosition: _j(json, 'jobPosition', 'job_position')?.toString(),
      department: _j(json, 'department', 'department')?.toString(),
      level: _j(json, 'level', 'level')?.toString() ?? 'Verbal',
      judul: _j(json, 'judul', 'judul')?.toString() ?? '',
      deskripsi: _j(json, 'deskripsi', 'deskripsi')?.toString(),
      tanggal: DateTime.tryParse(_j(json, 'tanggal', 'tanggal')?.toString() ?? '') ?? DateTime.now(),
      noSurat: _j(json, 'noSurat', 'no_surat')?.toString() ?? '',
      issuedBy: _j(json, 'issuedBy', 'issued_by')?.toString(),
      issuedByName: _j(json, 'issuedByName', 'issued_by_name')?.toString(),
      createdAt: DateTime.tryParse(_j(json, 'createdAt', 'created_at')?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

class TeguranService {
  /// Ambil field dari response JSON tanpa peduli casing (backend ASN kadang
  /// balikin PascalCase mentah `Success`/`Message`/`Data`, bukan camelCase).
  static dynamic _r(Map<String, dynamic> json, String camelKey) {
    if (json.containsKey(camelKey) && json[camelKey] != null) return json[camelKey];
    final pascalKey = camelKey[0].toUpperCase() + camelKey.substring(1);
    if (json.containsKey(pascalKey) && json[pascalKey] != null) return json[pascalKey];
    return null;
  }

  static Future<String?> _getToken() async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseURL/api/auth/token'),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: {'grant_type': 'password', 'password': 'ASN_DBS'},
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['access_token'] as String?;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, String>> _headers() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// HRD membuat teguran baru untuk seorang karyawan.
  static Future<({bool success, String message, TeguranData? data})> createTeguran({
    required String userId,
    required String level,
    required String judul,
    String? deskripsi,
    required DateTime tanggal,
    String? issuedBy,
    String? issuedByName,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseURL/api/teguran/create'),
        headers: await _headers(),
        body: json.encode({
          'userId': userId,
          'level': level,
          'judul': judul,
          'deskripsi': deskripsi,
          'tanggal': tanggal.toIso8601String(),
          'issuedBy': issuedBy,
          'issuedByName': issuedByName,
        }),
      );

      final body = json.decode(response.body) as Map<String, dynamic>;
      final success = _r(body, 'success') == true;
      final message = (_r(body, 'message') ?? '').toString();
      final dataJson = _r(body, 'data');

      return (
        success: success,
        message: message.isNotEmpty ? message : (success ? 'Teguran berhasil dibuat.' : 'Gagal membuat teguran.'),
        data: dataJson != null ? TeguranData.fromJson(dataJson as Map<String, dynamic>) : null,
      );
    } catch (e) {
      return (success: false, message: 'Terjadi kesalahan jaringan: $e', data: null);
    }
  }

  /// Koreksi teguran yang sudah dibuat (level/judul/deskripsi/tanggal).
  /// UserId/issuedBy/noSurat tidak berubah.
  static Future<({bool success, String message, TeguranData? data})> updateTeguran({
    required int id,
    required String level,
    required String judul,
    String? deskripsi,
    required DateTime tanggal,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseURL/api/teguran/update'),
        headers: await _headers(),
        body: json.encode({
          'id': id,
          'level': level,
          'judul': judul,
          'deskripsi': deskripsi,
          'tanggal': tanggal.toIso8601String(),
        }),
      );

      final body = json.decode(response.body) as Map<String, dynamic>;
      final success = _r(body, 'success') == true;
      final message = (_r(body, 'message') ?? '').toString();
      final dataJson = _r(body, 'data');

      return (
        success: success,
        message: message.isNotEmpty ? message : (success ? 'Teguran berhasil diperbarui.' : 'Gagal memperbarui teguran.'),
        data: dataJson != null ? TeguranData.fromJson(dataJson as Map<String, dynamic>) : null,
      );
    } catch (e) {
      return (success: false, message: 'Terjadi kesalahan jaringan: $e', data: null);
    }
  }

  /// Karyawan melihat daftar teguran miliknya sendiri.
  static Future<List<TeguranData>> getMyTeguran(String userId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseURL/api/teguran/my-list'),
        headers: await _headers(),
        body: json.encode({'userId': userId}),
      );

      if (response.statusCode == 200) {
        final body = json.decode(response.body) as Map<String, dynamic>;
        if (_r(body, 'success') == true) {
          final list = _r(body, 'data') as List<dynamic>? ?? [];
          return list
              .map((e) => TeguranData.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// HRD melihat semua teguran yang pernah dibuat (karyawan di perusahaan
  /// yang sama saja).
  static Future<List<TeguranData>> getAllTeguran(String hrdUserId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseURL/api/teguran/list'),
        headers: await _headers(),
        body: json.encode({'HrdUserId': hrdUserId}),
      );

      if (response.statusCode == 200) {
        final body = json.decode(response.body) as Map<String, dynamic>;
        if (_r(body, 'success') == true) {
          final list = _r(body, 'data') as List<dynamic>? ?? [];
          return list
              .map((e) => TeguranData.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Cek apakah user adalah Head (job_position 'HEAD OF...') — dipakai untuk
  /// menampilkan/menyembunyikan menu "Teguran" secara kondisional.
  static Future<({bool isHead, bool isHrdHead, String? name, String? jobPosition})> checkIsHead(
    String userId,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseURL/api/teguran/check-head'),
        headers: await _headers(),
        body: json.encode({'userId': userId}),
      );

      if (response.statusCode == 200) {
        final body = json.decode(response.body) as Map<String, dynamic>;
        if (_r(body, 'success') == true) {
          return (
            isHead: _r(body, 'isHead') == true,
            isHrdHead: _r(body, 'isHrdHead') == true,
            name: _r(body, 'name')?.toString(),
            jobPosition: _r(body, 'jobPosition')?.toString(),
          );
        }
      }
      return (isHead: false, isHrdHead: false, name: null, jobPosition: null);
    } catch (_) {
      return (isHead: false, isHrdHead: false, name: null, jobPosition: null);
    }
  }

  /// Unduh surat PDF teguran (generate on-demand di server).
  ///
  /// Nama file SENGAJA tidak diambil dari header Content-Disposition —
  /// di Flutter Web, browser menyembunyikan header itu dari JS kecuali
  /// server expose eksplisit (Access-Control-Expose-Headers), jadi tidak
  /// reliable lintas platform. Nama file dibangun di client lewat
  /// [buildSuratFileName] dari data yang sudah ada di memory (userName +
  /// level), dipanggil terpisah oleh caller.
  static Future<Uint8List> downloadTeguranPdf(int id) async {
    final response = await http
        .post(
          Uri.parse('$baseURL/api/teguran/download'),
          headers: await _headers(),
          body: json.encode({'id': id}),
        )
        .timeout(const Duration(seconds: 45));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message = 'Gagal membuat surat PDF.';
      try {
        final body = jsonDecode(response.body);
        if (body is Map) {
          final msg = _r(body.cast<String, dynamic>(), 'message');
          if (msg != null) message = msg.toString();
        }
      } catch (_) {}
      throw Exception(message);
    }

    if (response.bodyBytes.isEmpty) {
      throw Exception('File PDF kosong.');
    }

    return Uint8List.fromList(response.bodyBytes);
  }

  /// Bangun nama file surat: SuratTeguran_{NamaKaryawan}_{Level}.pdf
  /// (dibersihkan dari spasi/karakter yang tidak aman untuk nama file).
  static String buildSuratFileName({
    String? userName,
    String? userId,
    required String level,
  }) {
    String sanitize(String s) =>
        s.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');

    final namePart = sanitize(userName ?? userId ?? '');
    final levelPart = sanitize(level);
    final parts = [namePart, levelPart].where((p) => p.isNotEmpty).join('_');

    return parts.isEmpty ? 'SuratTeguran.pdf' : 'SuratTeguran_$parts.pdf';
  }
}
