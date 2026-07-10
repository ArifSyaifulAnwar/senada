// lib/Services/office_file_service.dart
// Fitur "Berkas Kantor" — dokumen kantor company-wide (bukan per-karyawan),
// akses terbatas Head HRD + Finance. Lihat OfficeFileController.cs (backend).
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:absensikaryawan/Services/config.dart';

class OfficeFileCategory {
  final int id;
  final String name;

  const OfficeFileCategory({required this.id, required this.name});

  factory OfficeFileCategory.fromJson(Map<String, dynamic> json) {
    return OfficeFileCategory(
      id: (OfficeFileService._r(json, 'id') as num?)?.toInt() ?? 0,
      name: OfficeFileService._r(json, 'name')?.toString() ?? '',
    );
  }
}

class OfficeFileItem {
  final int id;
  final String name;
  final String category;
  final String? description;
  final String fileType;
  final int fileSize;
  final String uploadedByUserId;
  final String? uploadedByName;
  final DateTime createdAt;
  final DateTime updatedAt;

  const OfficeFileItem({
    required this.id,
    required this.name,
    required this.category,
    this.description,
    required this.fileType,
    required this.fileSize,
    required this.uploadedByUserId,
    this.uploadedByName,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isImage =>
      fileType.toLowerCase().startsWith('image/');

  factory OfficeFileItem.fromJson(Map<String, dynamic> json) {
    dynamic r(String key) => OfficeFileService._r(json, key);
    return OfficeFileItem(
      id: (r('id') as num?)?.toInt() ?? 0,
      name: r('name')?.toString() ?? '',
      category: r('category')?.toString() ?? '',
      description: r('description')?.toString(),
      fileType: r('fileType')?.toString() ?? '',
      fileSize: (r('fileSize') as num?)?.toInt() ?? 0,
      uploadedByUserId: r('uploadedByUserId')?.toString() ?? '',
      uploadedByName: r('uploadedByName')?.toString(),
      createdAt: DateTime.tryParse(r('createdAt')?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(r('updatedAt')?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

class OfficeFileService {
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

  /// Cek apakah user berhak mengakses Berkas Kantor (Head HRD atau Finance).
  static Future<({bool allowed, bool isHrdHead, bool isFinance})> checkAccess(
    String userId,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseURL/api/officefile/check-access'),
        headers: await _headers(),
        body: json.encode({'userId': userId}),
      );

      if (response.statusCode == 200) {
        final body = json.decode(response.body) as Map<String, dynamic>;
        return (
          allowed: _r(body, 'allowed') == true,
          isHrdHead: _r(body, 'isHrdHead') == true,
          isFinance: _r(body, 'isFinance') == true,
        );
      }
      return (allowed: false, isHrdHead: false, isFinance: false);
    } catch (_) {
      return (allowed: false, isHrdHead: false, isFinance: false);
    }
  }

  static Future<List<OfficeFileCategory>> getCategories(String userId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseURL/api/officefile/category/all'),
        headers: await _headers(),
        body: json.encode({'userId': userId}),
      );

      if (response.statusCode == 200) {
        final body = json.decode(response.body) as Map<String, dynamic>;
        if (_r(body, 'success') == true) {
          final list = _r(body, 'data') as List<dynamic>? ?? [];
          return list
              .map((e) => OfficeFileCategory.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  static Future<({bool success, String message})> addCategory({
    required String userId,
    required String name,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseURL/api/officefile/category/add'),
        headers: await _headers(),
        body: json.encode({'userId': userId, 'name': name}),
      );
      final body = json.decode(response.body) as Map<String, dynamic>;
      final success = _r(body, 'success') == true;
      return (
        success: success,
        message: (_r(body, 'message') ?? (success ? 'Kategori berhasil disimpan.' : 'Gagal menyimpan kategori.')).toString(),
      );
    } catch (e) {
      return (success: false, message: 'Terjadi kesalahan jaringan: $e');
    }
  }

  static Future<({bool success, String message})> updateCategory({
    required String userId,
    required int id,
    required String name,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseURL/api/officefile/category/update'),
        headers: await _headers(),
        body: json.encode({'userId': userId, 'id': id, 'name': name}),
      );
      final body = json.decode(response.body) as Map<String, dynamic>;
      final success = _r(body, 'success') == true;
      return (
        success: success,
        message: (_r(body, 'message') ?? (success ? 'Kategori berhasil diperbarui.' : 'Gagal memperbarui kategori.')).toString(),
      );
    } catch (e) {
      return (success: false, message: 'Terjadi kesalahan jaringan: $e');
    }
  }

  static Future<({bool success, String message})> deactivateCategory({
    required String userId,
    required int id,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseURL/api/officefile/category/deactivate'),
        headers: await _headers(),
        body: json.encode({'userId': userId, 'id': id}),
      );
      final body = json.decode(response.body) as Map<String, dynamic>;
      final success = _r(body, 'success') == true;
      return (
        success: success,
        message: (_r(body, 'message') ?? (success ? 'Kategori berhasil dinonaktifkan.' : 'Gagal menonaktifkan kategori.')).toString(),
      );
    } catch (e) {
      return (success: false, message: 'Terjadi kesalahan jaringan: $e');
    }
  }

  static Future<List<OfficeFileItem>> getAllFiles(String userId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseURL/api/officefile/list'),
        headers: await _headers(),
        body: json.encode({'userId': userId}),
      );

      if (response.statusCode == 200) {
        final body = json.decode(response.body) as Map<String, dynamic>;
        if (_r(body, 'success') == true) {
          final list = _r(body, 'data') as List<dynamic>? ?? [];
          return list
              .map((e) => OfficeFileItem.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  static Future<({bool success, String message})> uploadFile({
    required String userId,
    required String name,
    required String category,
    String? description,
    required Uint8List fileContent,
    required String fileType,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseURL/api/officefile/upload'),
        headers: await _headers(),
        body: json.encode({
          'userId': userId,
          'name': name,
          'category': category,
          'description': description,
          'fileContent': base64Encode(fileContent),
          'fileType': fileType,
        }),
      );
      final body = json.decode(response.body) as Map<String, dynamic>;
      final success = _r(body, 'success') == true;
      return (
        success: success,
        message: (_r(body, 'message') ?? (success ? 'Berkas berhasil diunggah.' : 'Gagal mengunggah berkas.')).toString(),
      );
    } catch (e) {
      return (success: false, message: 'Terjadi kesalahan jaringan: $e');
    }
  }

  static Future<({bool success, String message})> updateFile({
    required String userId,
    required int id,
    required String name,
    required String category,
    String? description,
    Uint8List? fileContent,
    String? fileType,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseURL/api/officefile/update'),
        headers: await _headers(),
        body: json.encode({
          'userId': userId,
          'id': id,
          'name': name,
          'category': category,
          'description': description,
          'fileContent': fileContent != null ? base64Encode(fileContent) : null,
          'fileType': fileType,
        }),
      );
      final body = json.decode(response.body) as Map<String, dynamic>;
      final success = _r(body, 'success') == true;
      return (
        success: success,
        message: (_r(body, 'message') ?? (success ? 'Berkas berhasil diperbarui.' : 'Gagal memperbarui berkas.')).toString(),
      );
    } catch (e) {
      return (success: false, message: 'Terjadi kesalahan jaringan: $e');
    }
  }

  static Future<({bool success, String message})> deleteFile({
    required String userId,
    required int id,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseURL/api/officefile/delete'),
        headers: await _headers(),
        body: json.encode({'userId': userId, 'id': id}),
      );
      final body = json.decode(response.body) as Map<String, dynamic>;
      final success = _r(body, 'success') == true;
      return (
        success: success,
        message: (_r(body, 'message') ?? (success ? 'Berkas berhasil dihapus.' : 'Gagal menghapus berkas.')).toString(),
      );
    } catch (e) {
      return (success: false, message: 'Terjadi kesalahan jaringan: $e');
    }
  }

  static Future<Uint8List> downloadFile({
    required String userId,
    required int id,
  }) async {
    final response = await http
        .post(
          Uri.parse('$baseURL/api/officefile/download'),
          headers: await _headers(),
          body: json.encode({'userId': userId, 'id': id}),
        )
        .timeout(const Duration(seconds: 45));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message = 'Gagal mengunduh berkas.';
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
      throw Exception('Berkas kosong.');
    }

    return Uint8List.fromList(response.bodyBytes);
  }
}
