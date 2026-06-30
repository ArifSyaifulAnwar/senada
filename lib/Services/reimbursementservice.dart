// lib/services/reimbursement_service.dart
// ignore_for_file:

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:absensikaryawan/Services/reimbursementmodel.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:absensikaryawan/Services/config.dart';
import 'package:open_file/open_file.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// Lampiran reimbursement dalam bentuk bytes.
/// Dipakai oleh halaman detail agar gambar bisa dipreview penuh dan file
/// bisa diunduh di Web maupun mobile tanpa bergantung pada path fisik.
class ReimbursementAttachment {
  final Uint8List bytes;
  final String fileName;
  final String? contentType;

  const ReimbursementAttachment({
    required this.bytes,
    required this.fileName,
    this.contentType,
  });

  String get extension {
    final cleanName = fileName.split('?').first;
    if (!cleanName.contains('.')) return '';
    return cleanName.split('.').last.toLowerCase();
  }

  bool get isImage =>
      const ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(extension);

  String get mimeType {
    final headerType = contentType?.split(';').first.trim();
    if (headerType != null && headerType.isNotEmpty) return headerType;

    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'pdf':
        return 'application/pdf';
      default:
        return 'application/octet-stream';
    }
  }
}
// =============================================
// lib/Services/reimbursementservice.dart
// Tambahkan di class ReimbursementService
// =============================================

// Model attachment metadata
class ReimbursementAttachmentMeta {
  final int id;
  final int reimbursementId;
  final String fileName;
  final String contentType;
  final int fileSize;
  final double fileSizeMb;
  final int sortOrder;
  final DateTime uploadedAt;
  final String viewUrl;

  const ReimbursementAttachmentMeta({
    required this.id,
    required this.reimbursementId,
    required this.fileName,
    required this.contentType,
    required this.fileSize,
    required this.fileSizeMb,
    required this.sortOrder,
    required this.uploadedAt,
    required this.viewUrl,
  });

  factory ReimbursementAttachmentMeta.fromJson(Map<String, dynamic> json) {
    return ReimbursementAttachmentMeta(
      id: json['id'] as int,
      reimbursementId: json['reimbursementId'] as int,
      fileName: json['fileName'] as String? ?? '',
      contentType: json['contentType'] as String? ?? '',
      fileSize: json['fileSize'] as int? ?? 0,
      fileSizeMb: (json['fileSizeMb'] as num?)?.toDouble() ?? 0.0,
      sortOrder: json['sortOrder'] as int? ?? 1,
      uploadedAt:
          DateTime.tryParse(json['uploadedAt'] as String? ?? '') ??
          DateTime.now(),
      viewUrl: json['viewUrl'] as String? ?? '',
    );
  }

  String get extension {
    if (!fileName.contains('.')) return '';
    return fileName.split('.').last.toLowerCase();
  }

  bool get isImage => const ['jpg', 'jpeg', 'png'].contains(extension);
}

// Model untuk file yang dipilih user (belum diupload)
class PendingAttachmentFile {
  final Uint8List bytes;
  final String fileName;
  final String extension;
  final String mimeType;

  const PendingAttachmentFile({
    required this.bytes,
    required this.fileName,
    required this.extension,
    required this.mimeType,
  });

  int get size => bytes.length;
  double get sizeMb => size / (1024 * 1024);
  bool get isImage => const ['jpg', 'jpeg', 'png'].contains(extension);
}

class ReimbursementService {
  // Private method untuk internal use
  Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }
  // =============================================
  // Method baru di ReimbursementService
  // =============================================

  /// Upload satu attachment. Dipanggil per file setelah submit berhasil.
  Future<ReimbursementResponse> uploadAttachment({
    required int reimbursementId,
    required String userId,
    required Uint8List fileBytes,
    required String fileName,
    required String contentType,
    int sortOrder = 1,
  }) async {
    try {
      final uri = Uri.parse(
        '$baseURL/api/asn/reimbursement/attachments/upload',
      );
      final request = http.MultipartRequest('POST', uri);

      final headers = await _getMultipartHeaders();
      request.headers.addAll(headers);

      request.fields['ReimbursementId'] = reimbursementId.toString();
      request.fields['UserId'] = userId;
      request.fields['SortOrder'] = sortOrder.toString();

      request.files.add(
        http.MultipartFile.fromBytes(
          'AttachmentFile',
          fileBytes,
          filename: fileName,
          contentType: _parseMediaType(contentType),
        ),
      );

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return ReimbursementResponse(
          success: json['success'] == true,
          message: json['message'] as String? ?? '',
          reimbursementId: json['attachmentId'] as int?,
        );
      }

      try {
        final err = jsonDecode(response.body) as Map<String, dynamic>;
        return ReimbursementResponse(
          success: false,
          message: err['message'] as String? ?? 'Gagal upload attachment.',
        );
      } catch (_) {
        return ReimbursementResponse(
          success: false,
          message: 'HTTP ${response.statusCode}: ${response.reasonPhrase}',
        );
      }
    } catch (e) {
      return ReimbursementResponse(
        success: false,
        message: 'Terjadi kesalahan jaringan: $e',
      );
    }
  }

  /// Submit reimbursement + upload semua attachment secara berurutan.
  /// Mengembalikan (success, message, failedFiles, reimbursementId).
  Future<({bool success, String message, List<String> failedFiles, int? reimbursementId})>
  submitWithAttachments({
    required String userId,
    required String title,
    required String category,
    required double amount,
    required DateTime expenseDate,
    String? description,
    required List<PendingAttachmentFile> attachments,
  }) async {
    // 1. Submit reimbursement (file pertama → field lama untuk compat)
    final first = attachments.first;

    final submitResult = await submitReimbursement(
      userId: userId,
      title: title,
      category: category,
      amount: amount,
      expenseDate: expenseDate,
      description: description,
      receiptBytes: first.bytes,
      receiptFileName: first.fileName,
      receiptContentType: first.mimeType,
      status: 'pending',
    );

    if (!submitResult.success || submitResult.reimbursementId == null) {
      return (
        success: false,
        message: submitResult.message,
        failedFiles: <String>[],
        reimbursementId: null,
      );
    }

    final reimbursementId = submitResult.reimbursementId!;
    final failedFiles = <String>[];

    // 2. Upload semua attachment ke tabel baru (termasuk file pertama)
    for (int i = 0; i < attachments.length; i++) {
      final file = attachments[i];
      final result = await uploadAttachment(
        reimbursementId: reimbursementId,
        userId: userId,
        fileBytes: file.bytes,
        fileName: file.fileName,
        contentType: file.mimeType,
        sortOrder: i + 1,
      );

      if (!result.success) {
        failedFiles.add(file.fileName);
      }
    }

    if (failedFiles.isEmpty) {
      return (
        success: true,
        message: submitResult.message,
        failedFiles: <String>[],
        reimbursementId: reimbursementId,
      );
    }

    return (
      success: true,
      message:
          '${submitResult.message} (${failedFiles.length} file gagal diupload)',
      failedFiles: failedFiles,
      reimbursementId: reimbursementId,
    );
  }

  /// Ambil list metadata attachment tanpa bytes.
  Future<List<ReimbursementAttachmentMeta>> getAttachments({
    required int reimbursementId,
    String? userId,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseURL/api/asn/reimbursement/attachments/list'),
        headers: headers,
        body: jsonEncode({
          'reimbursementId': reimbursementId,
          'userId': userId,
        }),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        if (json['success'] == true) {
          final list = json['data'] as List<dynamic>? ?? [];
          return list
              .map(
                (e) => ReimbursementAttachmentMeta.fromJson(
                  e as Map<String, dynamic>,
                ),
              )
              .toList();
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Ambil bytes satu attachment untuk preview.
  Future<ReimbursementAttachment> getAttachmentBytes({
    required int attachmentId,
    String? userId,
  }) async {
    try {
      final headers = await _getHeaders();
      final query = userId != null ? '?userId=$userId' : '';
      final uri = Uri.parse(
        '$baseURL/api/asn/reimbursement/attachments/view/$attachmentId$query',
      );

      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 45));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Gagal mengambil attachment.');
      }

      if (response.bodyBytes.isEmpty) {
        throw Exception('File kosong.');
      }

      final fallback = 'attachment_$attachmentId';
      final fileName = _fileNameFromContentDisposition(
        response.headers['content-disposition'],
        fallback,
      );

      return ReimbursementAttachment(
        bytes: Uint8List.fromList(response.bodyBytes),
        fileName: fileName,
        contentType: response.headers['content-type'],
      );
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Gagal mengambil attachment: $e');
    }
  }

  /// Soft delete satu attachment.
  Future<ReimbursementResponse> deleteAttachment({
    required int attachmentId,
    required String userId,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseURL/api/asn/reimbursement/attachments/delete'),
        headers: headers,
        body: jsonEncode({'attachmentId': attachmentId, 'userId': userId}),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return ReimbursementResponse(
          success: json['success'] == true,
          message: json['message'] as String? ?? '',
        );
      }

      return ReimbursementResponse(
        success: false,
        message: 'Gagal menghapus attachment.',
      );
    } catch (e) {
      return ReimbursementResponse(success: false, message: 'Error: $e');
    }
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
        if (data.containsKey('access_token') && data['access_token'] != null) {
          return data['access_token'];
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // PUBLIC method untuk external access
  Future<Map<String, String>> getHeaders() async {
    return await _getHeaders();
  }

  Future<Map<String, String>> _getMultipartHeaders() async {
    final token = await _getToken();
    return {'Authorization': 'Bearer $token'};
  }

  // Submit reimbursement dengan file
  // Submit reimbursement dengan file - Updated version
  Future<ReimbursementResponse> submitReimbursement({
    required String userId,
    required String title,
    required String category,
    required double amount,
    required DateTime expenseDate,
    String? description,

    // Dipakai Flutter Web dan mobile terbaru: file dikirim sebagai bytes.
    Uint8List? receiptBytes,
    String? receiptFileName,
    String? receiptContentType,

    // Tetap disediakan agar pemanggil lama di Android/iOS tidak langsung rusak.
    File? receiptFile,

    String status = 'pending',
  }) async {
    try {
      final uri = Uri.parse('$baseURL/api/asn/reimbursement/submit');
      final request = http.MultipartRequest('POST', uri);

      // Add headers
      final headers = await _getMultipartHeaders();
      request.headers.addAll(headers);

      // Add fields
      request.fields['userId'] = userId;
      request.fields['title'] = title;
      request.fields['category'] = category;
      request.fields['amount'] = amount.toString();
      request.fields['expenseDate'] = expenseDate.toIso8601String();
      request.fields['status'] = status;

      if (description != null && description.isNotEmpty) {
        request.fields['description'] = description;
      }

      // File upload:
      // - Web: gunakan bytes, karena browser tidak memiliki path file fisik.
      // - Android/iOS lama: tetap mendukung File bila masih ada pemanggil lama.
      if (receiptBytes != null && receiptBytes.isNotEmpty) {
        final fileName =
            (receiptFileName == null || receiptFileName.trim().isEmpty)
            ? 'bukti_reimbursement_${DateTime.now().millisecondsSinceEpoch}'
            : receiptFileName.trim();

        request.files.add(
          http.MultipartFile.fromBytes(
            'ReceiptFile',
            receiptBytes,
            filename: fileName,
            contentType: _parseMediaType(receiptContentType),
          ),
        );
      } else if (receiptFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath('ReceiptFile', receiptFile.path),
        );
      } else {
        return ReimbursementResponse(
          success: false,
          message: 'Bukti pembayaran wajib dipilih.',
        );
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        try {
          final jsonData = json.decode(response.body);

          // Validasi structure response
          if (jsonData is Map<String, dynamic>) {
            return ReimbursementResponse(
              success: jsonData['success'] ?? false,
              message: jsonData['message'] ?? 'Response berhasil',
              reimbursementId: jsonData['reimbursementId'] as int?,
            );
          } else {
            return ReimbursementResponse(
              success: false,
              message: 'Format response tidak valid',
            );
          }
        } catch (e) {
          return ReimbursementResponse(
            success: false,
            message: 'Error parsing response: $e',
          );
        }
      } else {
        try {
          final errorData = json.decode(response.body);
          return ReimbursementResponse(
            success: false,
            message: errorData['message'] ?? 'Terjadi kesalahan server',
          );
        } catch (e) {
          return ReimbursementResponse(
            success: false,
            message:
                'HTTP Error ${response.statusCode}: ${response.reasonPhrase}',
          );
        }
      }
    } catch (e) {
      return ReimbursementResponse(
        success: false,
        message: 'Terjadi kesalahan jaringan: $e',
      );
    }
  }

  // Get reimbursement list
  // Enhanced getReimbursementList dengan debugging
  Future<List<ReimbursementData>> getReimbursementList({
    required String userId,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final headers = await _getHeaders();

      final request = ReimbursementListRequest(
        userId: userId,
        status: status,
        startDate: startDate,
        endDate: endDate,
      );

      final requestBody = request.toJson();

      final url = '$baseURL/api/asn/reimbursement/list';

      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);

        if (jsonData['success'] == true) {
          final List<dynamic> dataList = jsonData['data'] ?? [];

          if (dataList.isNotEmpty) {}

          final result = dataList
              .map((item) => ReimbursementData.fromJson(item))
              .toList();

          return result;
        } else {}
      } else {}

      return [];
    } catch (e) {
      return [];
    }
  }

  // Get reimbursement detail
  Future<ReimbursementData?> getReimbursementDetail({
    required int id,
    String? userId,
  }) async {
    try {
      final headers = await _getHeaders();
      final request = ReimbursementDetailRequest(id: id, userId: userId);

      final response = await http.post(
        Uri.parse('$baseURL/api/asn/reimbursement/detail'),
        headers: headers,
        body: json.encode(request.toJson()),
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData['success'] == true) {
          return ReimbursementData.fromJson(jsonData['data']);
        } else {}
      } else {}

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Mengambil bukti reimbursement sebagai bytes agar dapat dipreview penuh
  /// dan didownload pada Flutter Web maupun mobile.
  Future<ReimbursementAttachment> getReceiptAttachment({
    required int id,
    String? userId,
  }) async {
    try {
      final headers = await _getHeaders();

      final query = <String, String>{};
      if (userId != null && userId.trim().isNotEmpty) {
        query['userId'] = userId.trim();
      }

      final uri = Uri.parse(
        '$baseURL/api/asn/reimbursement/receipt/view/$id',
      ).replace(queryParameters: query.isEmpty ? null : query);

      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 45));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        String message = 'Gagal mengambil bukti pembayaran.';
        try {
          final body = jsonDecode(response.body);
          if (body is Map && body['message'] != null) {
            message = body['message'].toString();
          }
        } catch (_) {}
        throw Exception(message);
      }

      if (response.bodyBytes.isEmpty) {
        throw Exception('File bukti pembayaran kosong atau tidak ditemukan.');
      }

      final fallbackName = 'bukti_reimbursement_$id';
      final fileName = _fileNameFromContentDisposition(
        response.headers['content-disposition'],
        fallbackName,
      );

      return ReimbursementAttachment(
        bytes: Uint8List.fromList(response.bodyBytes),
        fileName: fileName,
        contentType: response.headers['content-type'],
      );
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Gagal mengambil bukti pembayaran: $e');
    }
  }

  /// Mengambil bukti transfer yang diunggah Head Finance.
  ///
  /// Endpoint memakai POST supaya userId pengaju dapat divalidasi oleh API:
  /// POST /api/asn/reimbursement/payment-proof/download
  Future<ReimbursementAttachment> getPaymentProofAttachment({
    required int id,
    String? userId,
    String? fallbackFileName,
  }) async {
    if (userId == null || userId.trim().isEmpty) {
      throw Exception('User login tidak ditemukan.');
    }

    try {
      final response = await http
          .post(
            Uri.parse('$baseURL/api/asn/reimbursement/payment-proof/download'),
            headers: await _getHeaders(),
            body: jsonEncode({'id': id, 'userId': userId.trim()}),
          )
          .timeout(const Duration(seconds: 45));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        String message = 'Gagal mengambil bukti transfer Finance.';
        try {
          final body = jsonDecode(response.body);
          if (body is Map && body['message'] != null) {
            message = body['message'].toString();
          }
        } catch (_) {}
        throw Exception(message);
      }

      if (response.bodyBytes.isEmpty) {
        throw Exception('Bukti transfer Finance kosong atau tidak ditemukan.');
      }

      final rawFileName = _fileNameFromContentDisposition(
        response.headers['content-disposition'],
        fallbackFileName?.trim().isNotEmpty == true
            ? fallbackFileName!.trim()
            : 'bukti_transfer_$id',
      );

      return ReimbursementAttachment(
        bytes: Uint8List.fromList(response.bodyBytes),
        fileName: rawFileName,
        contentType: response.headers['content-type'],
      );
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Gagal mengambil bukti transfer Finance: $e');
    }
  }

  String _fileNameFromContentDisposition(
    String? contentDisposition,
    String fallback,
  ) {
    if (contentDisposition == null || contentDisposition.trim().isEmpty) {
      return fallback;
    }

    final utf8Match = RegExp(
      r"filename\*\s*=\s*(?:UTF-8'')?([^;]+)",
      caseSensitive: false,
    ).firstMatch(contentDisposition);

    if (utf8Match != null) {
      final raw = utf8Match.group(1)!.trim().replaceAll('"', '');
      try {
        return Uri.decodeComponent(raw);
      } catch (_) {
        return raw;
      }
    }

    final normalMatch = RegExp(
      r'filename\s*=\s*"?([^";]+)"?',
      caseSensitive: false,
    ).firstMatch(contentDisposition);

    final name = normalMatch?.group(1)?.trim();
    return name == null || name.isEmpty ? fallback : name;
  }

  String getReceiptImageUrl(int reimbursementId, {String? userId}) {
    final userParam = userId != null ? '?userId=$userId' : '';
    final url =
        '$baseURL/api/asn/reimbursement/receipt/view/$reimbursementId$userParam';

    return url;
  }

  Future<void> testReceiptImageAccess(
    int reimbursementId, {
    String? userId,
  }) async {
    try {
      final url = getReceiptImageUrl(reimbursementId, userId: userId);

      // Get headers
      final headers = await _getHeaders();

      // Test with GET request
      final response = await http.get(Uri.parse(url), headers: headers);

      if (response.statusCode == 200) {
        // Akses berhasil
      } else {
        // Bisa tambahkan logika error handling berdasarkan statusCode
      }
    } catch (e) {
      ScaffoldMessenger.of(context as BuildContext).showSnackBar(
        SnackBar(
          content: Text('Gagal mengakses gambar kwitansi.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Download receipt
  Future<File?> downloadReceipt({required int id, String? userId}) async {
    try {
      // Request storage permission
      bool hasPermission = await _requestStoragePermission();
      if (!hasPermission) {
        return null;
      }

      final headers = await _getHeaders();
      final userParam = userId != null ? '?userId=$userId' : '';

      final response = await http.get(
        Uri.parse('$baseURL/api/asn/reimbursement/receipt/view/$id$userParam'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        // Get content type from headers
        final contentType =
            response.headers['content-type'] ?? 'application/octet-stream';

        // Determine file extension
        String extension = 'file';
        if (contentType.contains('image/jpeg') ||
            contentType.contains('image/jpg')) {
          extension = 'jpg';
        } else if (contentType.contains('image/png')) {
          extension = 'png';
        } else if (contentType.contains('application/pdf')) {
          extension = 'pdf';
        }

        // Get Downloads directory
        Directory? downloadsDir = await _getDownloadsDirectory();
        if (downloadsDir == null) {
          return null;
        }

        // Create filename
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = 'receipt_${id}_$timestamp.$extension';
        final file = File('${downloadsDir.path}/$fileName');

        // Write file
        await file.writeAsBytes(response.bodyBytes);

        return file;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  Future<bool> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      // For Android 13+ (API 33+)
      if (await Permission.photos.request().isGranted ||
          await Permission.storage.request().isGranted ||
          await Permission.manageExternalStorage.request().isGranted) {
        return true;
      }

      // For older Android versions
      var status = await Permission.storage.status;
      if (status.isDenied) {
        status = await Permission.storage.request();
      }
      return status.isGranted;
    }
    return true; // iOS doesn't need this permission for app documents
  }

  // Get categories
  Future<List<ReimbursementCategory>> getCategories() async {
    try {
      final headers = await _getHeaders();

      final response = await http.post(
        Uri.parse('$baseURL/api/asn/reimbursement/categories'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData['success'] == true) {
          final List<dynamic> dataList = jsonData['data'];
          return dataList
              .map((item) => ReimbursementCategory.fromJson(item))
              .toList();
        }
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  Future<Directory?> _getDownloadsDirectory() async {
    try {
      if (Platform.isAndroid) {
        // Try to get the Downloads directory
        Directory? downloadsDir = Directory('/storage/emulated/0/Download');
        if (await downloadsDir.exists()) {
          return downloadsDir;
        }

        // Fallback to external storage
        Directory? externalDir = await getExternalStorageDirectory();
        if (externalDir != null) {
          Directory downloadsDir = Directory('${externalDir.path}/Download');
          if (!await downloadsDir.exists()) {
            await downloadsDir.create(recursive: true);
          }
          return downloadsDir;
        }
      } else if (Platform.isIOS) {
        // For iOS, use documents directory
        return await getApplicationDocumentsDirectory();
      }

      // Fallback
      return await getApplicationDocumentsDirectory();
    } catch (e) {
      return await getApplicationDocumentsDirectory();
    }
  }

  Future<void> openDownloadedFile(File file) async {
    try {
      final result = await OpenFile.open(file.path);

      if (result.type != ResultType.done) {}
    } catch (e) {
      ScaffoldMessenger.of(context as BuildContext).showSnackBar(
        SnackBar(
          content: Text('Gagal mengakses download.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Get statistics
  Future<ReimbursementStatistics?> getStatistics({
    String? userId,
    int? year,
  }) async {
    try {
      final headers = await _getHeaders();
      final requestBody = {'userId': userId, 'year': year};

      final response = await http.post(
        Uri.parse('$baseURL/api/asn/reimbursement/statistics'),
        headers: headers,
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData['success'] == true) {
          return ReimbursementStatistics.fromJson(jsonData['data']);
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  // Admin methods

  // Get all reimbursements for admin
  Future<List<ReimbursementData>> getAllReimbursementsAdmin({
    String? status,
    DateTime? startDate,
    DateTime? endDate,
    String? userId,
  }) async {
    try {
      final headers = await _getHeaders();
      final request = ReimbursementListRequest(
        userId: userId ?? '',
        status: status,
        startDate: startDate,
        endDate: endDate,
      );

      final response = await http.post(
        Uri.parse('$baseURL/api/asn/reimbursement/admin/list'),
        headers: headers,
        body: json.encode(request.toJson()),
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData['success'] == true) {
          final List<dynamic> dataList = jsonData['data'];
          return dataList
              .map((item) => ReimbursementData.fromJson(item))
              .toList();
        }
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  // Review reimbursement (approve/reject)
  Future<ReimbursementResponse> reviewReimbursement({
    required int id,
    required String status, // 'approved' or 'rejected'
    required String reviewedBy,
    String? reviewNotes,
  }) async {
    try {
      final headers = await _getHeaders();
      final requestBody = {
        'id': id,
        'status': status,
        'reviewedBy': reviewedBy,
        'reviewNotes': reviewNotes,
      };

      final response = await http.post(
        Uri.parse('$baseURL/api/asn/reimbursement/review'),
        headers: headers,
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return ReimbursementResponse.fromJson(jsonData);
      } else {
        final errorData = json.decode(response.body);
        return ReimbursementResponse(
          success: false,
          message: errorData['message'] ?? 'Terjadi kesalahan',
        );
      }
    } catch (e) {
      return ReimbursementResponse(
        success: false,
        message: 'Terjadi kesalahan: $e',
      );
    }
  }

  // Mark as paid
  Future<ReimbursementResponse> markAsPaid({
    required int id,
    required String paidBy,
  }) async {
    try {
      final headers = await _getHeaders();
      final requestBody = {'id': id, 'paidBy': paidBy};

      final response = await http.post(
        Uri.parse('$baseURL/api/asn/reimbursement/mark-paid'),
        headers: headers,
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return ReimbursementResponse.fromJson(jsonData);
      } else {
        final errorData = json.decode(response.body);
        return ReimbursementResponse(
          success: false,
          message: errorData['message'] ?? 'Terjadi kesalahan',
        );
      }
    } catch (e) {
      return ReimbursementResponse(
        success: false,
        message: 'Terjadi kesalahan: $e',
      );
    }
  }

  MediaType _parseMediaType(String? contentType) {
    final value = contentType?.trim();

    if (value == null || value.isEmpty) {
      return MediaType('application', 'octet-stream');
    }

    try {
      return MediaType.parse(value);
    } catch (_) {
      return MediaType('application', 'octet-stream');
    }
  }
}

class ReimbursementServicePatch {
  static const String _base = '/api/asn/reimbursement';

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
        return d['access_token'] as String?;
      }
    } catch (_) {}
    return null;
  }

  static Future<Map<String, String>> _headers() async {
    final tok = await _getToken();
    return {'Content-Type': 'application/json', 'Authorization': 'Bearer $tok'};
  }

  // ── Tambahkan method ini ke ReimbursementService ──────────────────

  /// Finance approve atau reject reimbursement yang sudah di-approve HRD.
  /// [status] = 'approved' atau 'rejected'
  static Future<ReimbursementResponse> financeReview({
    required int id,
    required String status,
    required String financeUserId,
    String? reviewNotes,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseURL$_base/finance/review'),
        headers: await _headers(),
        body: json.encode({
          'id': id,
          'status': status,
          'financeUserId': financeUserId,
          'reviewNotes': reviewNotes,
        }),
      );
      final body = json.decode(res.body) as Map<String, dynamic>;
      return ReimbursementResponse(
        success: body['success'] == true,
        message: (body['message'] ?? '') as String,
      );
    } catch (e) {
      return ReimbursementResponse(
        success: false,
        message: 'Koneksi bermasalah: $e',
      );
    }
  }

  /// List reimbursement untuk tampilan Finance.
  /// Hanya mengembalikan status pending_finance, approved, rejected, paid.
  static Future<List<Map<String, dynamic>>> getFinanceList({
    String? status,
    DateTime? startDate,
    DateTime? endDate,
    String? searchKeyword,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseURL$_base/finance/list'),
        headers: await _headers(),
        body: json.encode({
          'status': status,
          'startDate': startDate?.toIso8601String(),
          'endDate': endDate?.toIso8601String(),
          'searchKeyword': searchKeyword,
        }),
      );
      final body = json.decode(res.body) as Map<String, dynamic>;
      if (body['success'] == true) {
        return List<Map<String, dynamic>>.from(body['data'] ?? []);
      }
      return [];
    } catch (_) {
      return [];
    }
  }
}
