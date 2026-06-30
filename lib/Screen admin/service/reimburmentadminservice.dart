import 'dart:convert';
import 'dart:typed_data';
import 'package:absensikaryawan/Screen%20admin/model/reimbursementadminmodel.dart';
import 'package:absensikaryawan/Services/reimbursementservice.dart' show ReimbursementAttachmentMeta;
import 'package:http/http.dart' as http;
import 'package:absensikaryawan/Services/config.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdminReimbursementService {
  String _currentUserId = '';

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getString('UserID') ?? '';
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

  Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<AdminResponse> financeReview({
    required int id,
    required String status, // 'approved' atau 'rejected'
    required String financeUserId,
    String? reviewNotes,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseURL/api/asn/reimbursement/finance/review'),
        headers: headers,
        body: json.encode({
          'id': id,
          'status': status,
          'financeUserId': financeUserId,
          'reviewNotes': reviewNotes,
        }),
      );
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return AdminResponse.fromJson(jsonData);
      }
      final errorData = json.decode(response.body);
      return AdminResponse(
        success: false,
        message: errorData['message'] ?? 'Terjadi kesalahan server',
      );
    } catch (e) {
      return AdminResponse(
        success: false,
        message: 'Terjadi kesalahan jaringan: $e',
      );
    }
  }

  // ✅ SIMPLE SOLUTION: Setelah stored procedure diperbaiki
  Future<List<AdminReimbursementData>> getAllReimbursementsAdmin({
    required String currentUserId, // Untuk verifikasi admin
    String? status,
    DateTime? startDate,
    DateTime? endDate,
    String? searchKeyword,
  }) async {
    try {
      final headers = await _getHeaders();
      Map<String, dynamic> requestBody = {
        'userId': currentUserId, // Untuk verifikasi admin di SP
      };
      if (status != null && status.isNotEmpty) {
        requestBody['status'] = status;
      }
      if (startDate != null) {
        requestBody['startDate'] = startDate.toIso8601String();
      }
      if (endDate != null) {
        requestBody['endDate'] = endDate.toIso8601String();
      }
      if (searchKeyword != null && searchKeyword.isNotEmpty) {
        requestBody['searchKeyword'] = searchKeyword;
      }

      final url = '$baseURL/api/asn/reimbursement/admin/list-enhanced';

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
              .map((item) => AdminReimbursementData.fromJson(item))
              .toList();

          return result;
        } else {
          // Handle case ketika user bukan admin
          if (jsonData['message']?.toString().toLowerCase().contains('admin') ==
                  true ||
              jsonData['message']?.toString().toLowerCase().contains('akses') ==
                  true) {
            throw Exception(
              'Akses ditolak. User $_currentUserId bukan admin atau tidak memiliki izin.',
            );
          }

          // Jika tidak ada data, return empty list
          return [];
        }
      } else {
        try {
          final errorData = json.decode(response.body);
          throw Exception(
            errorData['message'] ?? 'HTTP Error ${response.statusCode}',
          );
        } catch (e) {
          throw Exception(
            'HTTP Error ${response.statusCode}: ${response.body}',
          );
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  // Review reimbursement (approve/reject) - TIDAK BERUBAH
  Future<AdminResponse> reviewReimbursement({
    required int id,
    required String status,
    required String reviewedBy,
    String? reviewNotes,
  }) async {
    try {
      final headers = await _getHeaders();
      final request = AdminReimbursementReviewRequest(
        id: id,
        status: status,
        reviewedBy: reviewedBy,
        reviewNotes: reviewNotes,
      );

      final response = await http.post(
        Uri.parse('$baseURL/api/asn/reimbursement/admin/review'),
        headers: headers,
        body: json.encode(request.toJson()),
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return AdminResponse.fromJson(jsonData);
      } else {
        final errorData = json.decode(response.body);
        return AdminResponse(
          success: false,
          message: errorData['message'] ?? 'Terjadi kesalahan server',
        );
      }
    } catch (e) {
      return AdminResponse(
        success: false,
        message: 'Terjadi kesalahan jaringan: $e',
      );
    }
  }

  // Mark reimbursement as paid - TIDAK BERUBAH
  Future<AdminResponse> markReimbursementPaid({
    required int id,
    required String paidBy,
  }) async {
    try {
      final headers = await _getHeaders();
      final request = AdminMarkPaidRequest(id: id, paidBy: paidBy);

      final response = await http.post(
        Uri.parse('$baseURL/api/asn/reimbursement/admin/mark-paid'),
        headers: headers,
        body: json.encode(request.toJson()),
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return AdminResponse.fromJson(jsonData);
      } else {
        final errorData = json.decode(response.body);
        return AdminResponse(
          success: false,
          message: errorData['message'] ?? 'Terjadi kesalahan server',
        );
      }
    } catch (e) {
      return AdminResponse(
        success: false,
        message: 'Terjadi kesalahan jaringan: $e',
      );
    }
  }

  // Get admin statistics dengan current date sebagai default
  Future<AdminReimbursementStatistics?> getAdminStatistics({
    int? year,
    int? month,
  }) async {
    try {
      // Gunakan tahun dan bulan saat ini jika tidak disediakan
      // final now = DateTime.now();
      // final finalYear = year ?? now.year;
      // final finalMonth = month ?? now.month;

      final headers = await _getHeaders();
      Map requestBody = {};

      // Hanya kirim parameter jika disediakan
      if (year != null) {
        requestBody['year'] = year;
      }
      if (month != null) {
        requestBody['month'] = month;
      }

      // // Selalu kirim year dan month
      // Map<String, dynamic> requestBody = {
      //   'year': finalYear,
      //   'month': finalMonth,
      // };

      final response = await http.post(
        Uri.parse('$baseURL/api/asn/reimbursement/admin/statistics'),
        headers: headers,
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData['success'] == true) {
          return AdminReimbursementStatistics.fromJson(jsonData['data']);
        } else {
          throw Exception(jsonData['message'] ?? 'Gagal mengambil statistik');
        }
      } else {
        try {
          final errorData = json.decode(response.body);
          throw Exception(
            errorData['message'] ?? 'HTTP Error ${response.statusCode}',
          );
        } catch (e) {
          throw Exception(
            'HTTP Error ${response.statusCode}: ${response.body}',
          );
        }
      }
    } catch (e) {
      // Return default statistics
      return AdminReimbursementStatistics(
        totalSubmissions: 0,
        pendingCount: 0,
        approvedCount: 0,
        rejectedCount: 0,
        paidCount: 0,
        totalApprovedAmount: 0.0,
        totalPaidAmount: 0.0,
        totalPendingAmount: 0.0,
        formattedTotalApproved: 'Rp0',
        formattedTotalPaid: 'Rp0',
        formattedTotalPending: 'Rp0',
      );
    }
  }

  // Get users with reimbursements - TIDAK BERUBAH
  Future<List<UserWithReimbursements>> getUsersWithReimbursements() async {
    try {
      final headers = await _getHeaders();

      final response = await http.post(
        Uri.parse('$baseURL/api/asn/reimbursement/admin/users'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData['success'] == true) {
          final List<dynamic> dataList = jsonData['data'] ?? [];
          return dataList
              .map((item) => UserWithReimbursements.fromJson(item))
              .toList();
        } else {
          throw Exception(jsonData['message'] ?? 'Gagal mengambil data users');
        }
      } else {
        try {
          final errorData = json.decode(response.body);
          throw Exception(
            errorData['message'] ?? 'HTTP Error ${response.statusCode}',
          );
        } catch (e) {
          throw Exception(
            'HTTP Error ${response.statusCode}: ${response.body}',
          );
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  /// URL preview bukti pengajuan user untuk HRD / Head Finance.
  /// viewerUserId wajib agar backend memvalidasi akses dari role aktif.
  String getAdminReceiptImageUrl({
    required int reimbursementId,
    required String viewerUserId,
  }) {
    return Uri.parse(
      '$baseURL/api/asn/reimbursement/admin/receipt/view/$reimbursementId',
    ).replace(queryParameters: {'viewerUserId': viewerUserId}).toString();
  }

  /// Ambil bukti reimbursement sebagai bytes untuk tombol Preview/Download.
  Future<AdminReimbursementAttachment> getAdminReceiptAttachment({
    required int reimbursementId,
    required String viewerUserId,
    String? fallbackFileName,
  }) async {
    final uri = Uri.parse(
      '$baseURL/api/asn/reimbursement/admin/receipt/view/$reimbursementId',
    ).replace(queryParameters: {'viewerUserId': viewerUserId});

    final response = await http
        .post(uri, headers: await _getHeaders())
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
      throw Exception('Bukti pembayaran kosong atau tidak ditemukan.');
    }

    final rawName = _fileNameFromContentDisposition(
      response.headers['content-disposition'],
      fallbackFileName?.trim().isNotEmpty == true
          ? fallbackFileName!.trim()
          : 'bukti_reimbursement_$reimbursementId',
    );

    return AdminReimbursementAttachment(
      bytes: Uint8List.fromList(response.bodyBytes),
      fileName: _ensureExtension(rawName, response.headers['content-type']),
      contentType: response.headers['content-type'],
    );
  }

  /// Ambil bukti transfer yang diunggah Head Finance.
  ///
  /// Endpoint memakai POST agar backend dapat memvalidasi viewerUserId:
  /// POST /api/asn/reimbursement/payment-proof/download
  Future<AdminReimbursementAttachment> getAdminPaymentProofAttachment({
    required int reimbursementId,
    required String viewerUserId,
    String? fallbackFileName,
  }) async {
    final response = await http
        .post(
          Uri.parse('$baseURL/api/asn/reimbursement/payment-proof/download'),
          headers: await _getHeaders(),
          body: jsonEncode({'id': reimbursementId, 'userId': viewerUserId}),
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

    final rawName = _fileNameFromContentDisposition(
      response.headers['content-disposition'],
      fallbackFileName?.trim().isNotEmpty == true
          ? fallbackFileName!.trim()
          : 'bukti_transfer_$reimbursementId',
    );

    return AdminReimbursementAttachment(
      bytes: Uint8List.fromList(response.bodyBytes),
      fileName: _ensureExtension(rawName, response.headers['content-type']),
      contentType: response.headers['content-type'],
    );
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

  String _ensureExtension(String fileName, String? contentType) {
    final name = fileName.trim().isEmpty ? 'bukti_reimbursement' : fileName;
    final clean = name.split('?').first;

    if (clean.contains('.') && !clean.endsWith('.')) return name;

    final mime = (contentType ?? '').split(';').first.trim().toLowerCase();
    final extension = switch (mime) {
      'image/jpeg' || 'image/jpg' => 'jpg',
      'image/png' => 'png',
      'image/webp' => 'webp',
      'image/gif' => 'gif',
      'application/pdf' => 'pdf',
      _ => '',
    };

    return extension.isEmpty ? name : '$name.$extension';
  }

  /// Ambil list metadata attachment untuk admin/HRD view.
  Future<List<ReimbursementAttachmentMeta>> getAdminAttachments({
    required int reimbursementId,
    required String viewerUserId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseURL/api/asn/reimbursement/attachments/list'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'reimbursementId': reimbursementId,
          'userId': viewerUserId,
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          final list = data['data'] as List<dynamic>? ?? [];
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

  /// Ambil bytes satu attachment untuk admin/HRD preview/download.
  Future<AdminReimbursementAttachment> getAdminAttachmentBytes({
    required int attachmentId,
    required String viewerUserId,
  }) async {
    final uri = Uri.parse(
      '$baseURL/api/asn/reimbursement/attachments/view/$attachmentId',
    ).replace(queryParameters: {'userId': viewerUserId});

    final response = await http
        .get(uri, headers: await _getHeaders())
        .timeout(const Duration(seconds: 45));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message = 'Gagal mengambil attachment.';
      try {
        final body = jsonDecode(response.body);
        if (body is Map && body['message'] != null) {
          message = body['message'].toString();
        }
      } catch (_) {}
      throw Exception(message);
    }

    if (response.bodyBytes.isEmpty) throw Exception('File kosong.');

    final fileName = _fileNameFromContentDisposition(
      response.headers['content-disposition'],
      'attachment_$attachmentId',
    );

    return AdminReimbursementAttachment(
      bytes: Uint8List.fromList(response.bodyBytes),
      fileName: _ensureExtension(fileName, response.headers['content-type']),
      contentType: response.headers['content-type'],
    );
  }

  // Get admin headers
  Future<Map<String, String>> getAdminHeaders() async {
    return await _getHeaders();
  }
}

class AdminReimbursementAttachment {
  final Uint8List bytes;
  final String fileName;
  final String? contentType;

  const AdminReimbursementAttachment({
    required this.bytes,
    required this.fileName,
    this.contentType,
  });

  String get extension {
    final value = fileName.split('?').first;
    if (!value.contains('.')) return '';
    return value.split('.').last.toLowerCase();
  }

  bool get isImage =>
      const ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(extension);
}
