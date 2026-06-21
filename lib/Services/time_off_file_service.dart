// Services/time_off_file_service.dart — FILE BARU
import 'dart:convert';
import 'package:absensikaryawan/Services/config.dart';
import 'package:absensikaryawan/Services/time_off_model.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as p;

class TimeOffFileService {
  static const String _base = '/api/timeoff/files';

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
        final d = json.decode(res.body);
        if (d['access_token'] != null) return d['access_token'];
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, String>> _jsonHeaders() async {
    final tok = await _getToken();
    return {'Content-Type': 'application/json', 'Authorization': 'bearer $tok'};
  }

  static Future<Map<String, String>> _multipartHeaders() async {
    final tok = await _getToken();
    return {'Authorization': 'bearer $tok'};
  }

  static Future<ApiResponse<List<TimeOffFileItem>>> uploadFilesBytes({
    required int timeOffId,
    required String userId,
    required List<Map<String, dynamic>> files,
  }) async {
    try {
      final url = Uri.parse('$baseURL$_base/upload');
      final mr = http.MultipartRequest('POST', url);
      mr.headers.addAll(await _multipartHeaders());

      mr.fields['timeOffId'] = timeOffId.toString();
      mr.fields['userId'] = userId;

      for (final f in files) {
        final bytes = f['bytes'] as List<int>;
        final name = f['name'] as String;
        mr.files.add(
          http.MultipartFile.fromBytes(
            'files',
            bytes,
            filename: name,
            contentType: _mediaTypeFromName(name),
          ),
        );
      }

      final res = await http.Response.fromStream(await mr.send());
      if (res.body.isEmpty) {
        return ApiResponse(success: false, message: 'Response kosong');
      }

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && _get(body, 'success') == true) {
        final rawData = _get(body, 'data') as Map<String, dynamic>?;
        final uploaded = (rawData?['uploaded'] as List? ?? [])
            .map((e) => TimeOffFileItem.fromJson(e as Map<String, dynamic>))
            .toList();
        return ApiResponse(
          success: true,
          message: (_get(body, 'message') ?? '') as String,
          data: uploaded,
        );
      }
      return ApiResponse(
        success: false,
        message: (_get(body, 'message') ?? 'Terjadi kesalahan') as String,
      );
    } catch (e) {
      return ApiResponse(success: false, message: 'Koneksi bermasalah: $e');
    }
  }

  static MediaType _mediaTypeFromName(String name) {
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    switch (ext) {
      case 'pdf':
        return MediaType('application', 'pdf');
      case 'png':
        return MediaType('image', 'png');
      case 'jpg':
      case 'jpeg':
        return MediaType('image', 'jpeg');
      default:
        return MediaType('application', 'octet-stream');
    }
  }

  static MediaType _mediaType(String filePath) {
    final ext = p.extension(filePath).toLowerCase();
    switch (ext) {
      case '.pdf':
        return MediaType('application', 'pdf');
      case '.jpg':
      case '.jpeg':
        return MediaType('image', 'jpeg');
      case '.png':
        return MediaType('image', 'png');
      default:
        return MediaType('application', 'octet-stream');
    }
  }

  static dynamic _get(Map<String, dynamic> json, String key) =>
      json[key[0].toUpperCase() + key.substring(1)] ?? json[key];

  // ── Upload multiple files ──────────────────────────────────────────────────
  /// Upload satu atau lebih file ke time off yang sudah ada.
  /// Return: list file yang berhasil diupload.
  static Future<ApiResponse<List<TimeOffFileItem>>> uploadFiles(
    UploadTimeOffFilesRequest request,
  ) async {
    try {
      final url = Uri.parse('$baseURL$_base/upload');
      final mr = http.MultipartRequest('POST', url);
      mr.headers.addAll(await _multipartHeaders());

      mr.fields['timeOffId'] = request.timeOffId.toString();
      mr.fields['userId'] = request.userId;

      for (final file in request.files) {
        mr.files.add(
          await http.MultipartFile.fromPath(
            'files',
            file.path,
            filename: p.basename(file.path),
            contentType: _mediaType(file.path),
          ),
        );
      }

      final res = await http.Response.fromStream(await mr.send());
      if (res.body.isEmpty) {
        return ApiResponse(success: false, message: 'Response kosong');
      }

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && _get(body, 'success') == true) {
        final rawData = _get(body, 'data') as Map<String, dynamic>?;
        final uploaded = (rawData?['uploaded'] as List? ?? [])
            .map((e) => TimeOffFileItem.fromJson(e as Map<String, dynamic>))
            .toList();
        return ApiResponse(
          success: true,
          message: (_get(body, 'message') ?? '') as String,
          data: uploaded,
        );
      }
      return ApiResponse(
        success: false,
        message: (_get(body, 'message') ?? 'Terjadi kesalahan') as String,
      );
    } catch (e) {
      return ApiResponse(success: false, message: 'Koneksi bermasalah: $e');
    }
  }

  // ── Delete satu file ───────────────────────────────────────────────────────
  static Future<ApiResponse<void>> deleteFile(
    DeleteTimeOffFileRequest request,
  ) async {
    try {
      final res = await http.post(
        Uri.parse('$baseURL$_base/delete'),
        headers: await _jsonHeaders(),
        body: jsonEncode({
          'fileId': request.fileId,
          'timeOffId': request.timeOffId,
          'userId': request.userId,
        }),
      );
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return ApiResponse(
        success: _get(body, 'success') == true,
        message: (_get(body, 'message') ?? '') as String,
      );
    } catch (e) {
      return ApiResponse(success: false, message: 'Koneksi bermasalah: $e');
    }
  }

  // ── Download satu file ─────────────────────────────────────────────────────
  static Future<ApiResponse<List<int>>> downloadFile(
    int fileId,
    int timeOffId,
    String userId,
  ) async {
    try {
      final res = await http.post(
        Uri.parse('$baseURL$_base/download'),
        headers: await _jsonHeaders(),
        body: jsonEncode({
          'fileId': fileId,
          'timeOffId': timeOffId,
          'userId': userId,
        }),
      );
      if (res.statusCode == 200) {
        return ApiResponse(success: true, message: 'OK', data: res.bodyBytes);
      }
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return ApiResponse(
        success: false,
        message: (_get(body, 'message') ?? 'Gagal download') as String,
      );
    } catch (e) {
      return ApiResponse(success: false, message: 'Koneksi bermasalah: $e');
    }
  }

  // ── Get list files ─────────────────────────────────────────────────────────
  static Future<ApiResponse<List<TimeOffFileItem>>> getFiles(
    int timeOffId,
    String userId,
  ) async {
    try {
      final res = await http.post(
        Uri.parse('$baseURL$_base/list'),
        headers: await _jsonHeaders(),
        body: jsonEncode({'timeOffId': timeOffId, 'userId': userId}),
      );
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && _get(body, 'success') == true) {
        final rawData = _get(body, 'data') as List? ?? [];
        final files = rawData
            .map((e) => TimeOffFileItem.fromJson(e as Map<String, dynamic>))
            .toList();
        return ApiResponse(success: true, message: '', data: files);
      }
      return ApiResponse(
        success: false,
        message: (_get(body, 'message') ?? 'Terjadi kesalahan') as String,
      );
    } catch (e) {
      return ApiResponse(success: false, message: 'Koneksi bermasalah: $e');
    }
  }
}
