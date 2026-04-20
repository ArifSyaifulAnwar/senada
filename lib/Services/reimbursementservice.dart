// lib/services/reimbursement_service.dart
// ignore_for_file:

import 'dart:convert';
import 'dart:io';
import 'package:absensikaryawan/Services/reimbursementmodel.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:absensikaryawan/Services/config.dart';
import 'package:open_file/open_file.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class ReimbursementService {
  // Private method untuk internal use
  Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
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
    required File receiptFile,
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

      // Add file
      request.files.add(
        await http.MultipartFile.fromPath('receiptFile', receiptFile.path),
      );

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

      final response = await http.get(
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
}
