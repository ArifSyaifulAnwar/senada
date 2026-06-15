// ============================================================
// lib/Services/signature_service.dart — NEW FILE
// Service untuk upload, check, dan preview TTD karyawan
// ============================================================
// ignore_for_file: deprecated_member_use

import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'config.dart';

class SignatureInfo {
  final String userId;
  final bool hasTtd;
  final int? fileSize;
  final DateTime? updatedAt;

  const SignatureInfo({
    required this.userId,
    required this.hasTtd,
    this.fileSize,
    this.updatedAt,
  });

  factory SignatureInfo.fromJson(Map<String, dynamic> j) => SignatureInfo(
    userId: j['userId']?.toString() ?? '',
    hasTtd: j['hasTtd'] == true,
    fileSize: j['fileSize'] as int?,
    updatedAt: j['updatedAt'] == null
        ? null
        : DateTime.tryParse(j['updatedAt'].toString()),
  );

  String get sizeLabel {
    if (fileSize == null || fileSize! <= 0) return '';
    return fileSize! >= 1024 * 1024
        ? '${(fileSize! / (1024 * 1024)).toStringAsFixed(1)} MB'
        : '${(fileSize! / 1024).toStringAsFixed(0)} KB';
  }
}

class SignatureService {
  static const String _base = '/api/signature';

  static Future<String?> _getToken() async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseURL/api/auth/token'),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: {'grant_type': 'password', 'password': 'ASN_DBS'},
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        return jsonDecode(res.body)['access_token'];
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ── Check apakah TTD sudah ada ────────────────────────────────────────
  static Future<SignatureInfo?> check(String userId) async {
    try {
      final tok = await _getToken();
      final res = await http
          .post(
            Uri.parse('$baseURL$_base/check'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $tok',
            },
            body: jsonEncode({'userId': userId}),
          )
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final data = body['data'] ?? body['Data'];
        if (data != null) return SignatureInfo.fromJson(data);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ── Upload TTD (single) ───────────────────────────────────────────────
  // fileBytes + fileName: dari FilePicker (web + mobile)
  static Future<({bool success, String message})> upload({
    required String userId,
    required List<int> fileBytes,
    required String fileName,
  }) async {
    try {
      final tok = await _getToken();
      final url = Uri.parse('$baseURL$_base/upload');
      final mr = http.MultipartRequest('POST', url)
        ..headers['Authorization'] = 'Bearer $tok'
        ..fields['userId'] = userId
        ..files.add(
          http.MultipartFile.fromBytes(
            'ttdFile',
            fileBytes,
            filename: fileName,
            contentType: _mediaType(fileName),
          ),
        );

      final res = await http.Response.fromStream(await mr.send());
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final success = body['success'] == true || body['Success'] == true;
      final message =
          (body['message'] ?? body['Message'] ?? 'Terjadi kesalahan')
              .toString();
      return (success: success, message: message);
    } catch (e) {
      return (success: false, message: 'Koneksi bermasalah: $e');
    }
  }

  // ── Upload Bulk ───────────────────────────────────────────────────────
  // files: list of {userId, bytes, fileName}
  static Future<({bool success, String message, int sukses, int gagal})>
  uploadBulk({
    required String adminId,
    required List<({String userId, List<int> bytes, String fileName})> files,
  }) async {
    try {
      final tok = await _getToken();
      final url = Uri.parse('$baseURL$_base/upload-bulk');
      final mr = http.MultipartRequest('POST', url)
        ..headers['Authorization'] = 'Bearer $tok'
        ..fields['adminId'] = adminId;

      for (final f in files) {
        // Nama file = userId.ext (server pakai nama file sebagai userId)
        final ext = f.fileName.contains('.')
            ? '.${f.fileName.split('.').last}'
            : '.png';
        mr.files.add(
          http.MultipartFile.fromBytes(
            'ttdFiles',
            f.bytes,
            filename: '${f.userId}$ext',
            contentType: _mediaType(f.fileName),
          ),
        );
      }

      final res = await http.Response.fromStream(await mr.send());
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final success = body['success'] == true || body['Success'] == true;
      final message = (body['message'] ?? body['Message'] ?? '').toString();
      final data = body['data'] ?? body['Data'] ?? {};
      return (
        success: success,
        message: message,
        sukses: (data['successCount'] ?? 0) as int,
        gagal: (data['failCount'] ?? 0) as int,
      );
    } catch (e) {
      return (
        success: false,
        message: 'Koneksi bermasalah: $e',
        sukses: 0,
        gagal: files.length,
      );
    }
  }

  // ── Download/preview TTD ─────────────────────────────────────────────
  static Future<Uint8List?> getImage(String userId) async {
    try {
      final tok = await _getToken();
      final res = await http
          .post(
            Uri.parse('$baseURL$_base/get'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $tok',
            },
            body: jsonEncode({'userId': userId}),
          )
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) return res.bodyBytes;
      return null;
    } catch (_) {
      return null;
    }
  }

  // ── Delete TTD ───────────────────────────────────────────────────────
  static Future<({bool success, String message})> delete({
    required String userId,
    required String adminId,
  }) async {
    try {
      final tok = await _getToken();
      final res = await http
          .post(
            Uri.parse('$baseURL$_base/delete'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $tok',
            },
            body: jsonEncode({'userId': userId, 'adminId': adminId}),
          )
          .timeout(const Duration(seconds: 15));
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final success = body['success'] == true || body['Success'] == true;
      final message = (body['message'] ?? body['Message'] ?? '').toString();
      return (success: success, message: message);
    } catch (e) {
      return (success: false, message: 'Koneksi bermasalah: $e');
    }
  }

  static MediaType _mediaType(String fileName) {
    final ext = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : 'png';
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return MediaType('image', 'jpeg');
      default:
        return MediaType('image', 'png');
    }
  }
}
