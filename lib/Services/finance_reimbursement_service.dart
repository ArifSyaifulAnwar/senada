// lib/Screen finance/services/finance_reimbursement_service.dart

import 'dart:convert';
import 'dart:typed_data';

import 'package:absensikaryawan/Services/config.dart';
import 'package:absensikaryawan/Services/reimbursementservice.dart' show ReimbursementAttachmentMeta;
import 'package:http/http.dart' as http;

import '../models/finance_reimbursement_model.dart';

class FinanceReimbursementService {
  FinanceReimbursementService._();
  static const Duration _timeout = Duration(seconds: 45);

  static const String _receiptDownloadEndpoint =
      '/api/asn/reimbursement/receipt/download';
  static const String _paymentProofDownloadEndpoint =
      '/api/asn/reimbursement/payment-proof/download';

  static Future<List<FinanceReimbursementItem>> getList({
    String? status,
    String? searchKeyword,
  }) async {
    final response = await http
        .post(
          Uri.parse('$baseURL/api/asn/reimbursement/finance/list'),
          headers: await _headers(),
          body: jsonEncode({'status': status, 'searchKeyword': searchKeyword}),
        )
        .timeout(_timeout);

    final body = _decodeBody(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FinanceServiceException(_messageFrom(body, response.statusCode));
    }
    if (body is! Map<String, dynamic>) {
      throw const FinanceServiceException(
        'Format respons daftar reimbursement tidak valid.',
      );
    }
    final success = body['success'] ?? body['Success'];
    if (success != true && success != 1) {
      throw FinanceServiceException(_messageFrom(body, response.statusCode));
    }
    final rawList = body['data'] ?? body['Data'] ?? const [];
    if (rawList is! List) return const [];
    return rawList
        .whereType<Map>()
        .map(
          (item) => FinanceReimbursementItem.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }
  

  /// Bukti yang diunggah user ketika mengajukan reimbursement.
  static Future<FinanceReimbursementAttachment> downloadUserReceipt({
    required int reimbursementId,
    required String viewerUserId,
    String? fallbackFileName,
  }) => _downloadAttachment(
    endpoint: _receiptDownloadEndpoint,
    reimbursementId: reimbursementId,
    viewerUserId: viewerUserId,
    fallbackFileName: fallbackFileName,
    defaultName: 'bukti_pengajuan_$reimbursementId',
  );

  /// Bukti transfer yang diunggah Head Finance setelah pembayaran dilakukan.
  static Future<FinanceReimbursementAttachment> downloadPaymentProof({
    required int reimbursementId,
    required String viewerUserId,
    String? fallbackFileName,
  }) => _downloadAttachment(
    endpoint: _paymentProofDownloadEndpoint,
    reimbursementId: reimbursementId,
    viewerUserId: viewerUserId,
    fallbackFileName: fallbackFileName,
    defaultName: 'bukti_transfer_$reimbursementId',
  );

  static Future<FinanceReimbursementAttachment> _downloadAttachment({
    required String endpoint,
    required int reimbursementId,
    required String viewerUserId,
    required String? fallbackFileName,
    required String defaultName,
  }) async {
    final response = await http
        .post(
          Uri.parse('$baseURL$endpoint'),
          headers: await _headers(),
          body: jsonEncode({'id': reimbursementId, 'userId': viewerUserId}),
        )
        .timeout(_timeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      dynamic body;
      try {
        body = response.body.trim().isEmpty ? null : jsonDecode(response.body);
      } catch (_) {
        body = null;
      }
      throw FinanceServiceException(_messageFrom(body, response.statusCode));
    }
    if (response.bodyBytes.isEmpty) {
      throw const FinanceServiceException(
        'File lampiran kosong atau tidak ditemukan.',
      );
    }
    final name = _fileNameFromContentDisposition(
      response.headers['content-disposition'],
      fallbackFileName?.trim().isNotEmpty == true
          ? fallbackFileName!.trim()
          : defaultName,
    );
    return FinanceReimbursementAttachment(
      fileName: name,
      bytes: response.bodyBytes,
      contentType: response.headers['content-type'],
    );
  }

  /// Ambil list metadata attachment (tanpa bytes) untuk finance view.
  static Future<List<ReimbursementAttachmentMeta>> getAttachmentsMeta({
    required int reimbursementId,
    required String viewerUserId,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseURL/api/asn/reimbursement/attachments/list'),
            headers: await _headers(),
            body: jsonEncode({
              'reimbursementId': reimbursementId,
              'userId': viewerUserId,
            }),
          )
          .timeout(_timeout);
      final body = _decodeBody(response);
      if (body is Map && body['success'] == true) {
        final list = (body['data'] as List<dynamic>?) ?? [];
        return list
            .whereType<Map<String, dynamic>>()
            .map(ReimbursementAttachmentMeta.fromJson)
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Download satu attachment by ID untuk preview/download.
  static Future<FinanceReimbursementAttachment> downloadAttachmentById({
    required int attachmentId,
    required String viewerUserId,
    String? fallbackFileName,
  }) async {
    final uri = Uri.parse(
      '$baseURL/api/asn/reimbursement/attachments/view/$attachmentId',
    ).replace(queryParameters: {'userId': viewerUserId});

    final response = await http
        .get(uri, headers: await _headers())
        .timeout(_timeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      dynamic body;
      try {
        body = response.body.trim().isEmpty ? null : jsonDecode(response.body);
      } catch (_) {}
      throw FinanceServiceException(_messageFrom(body, response.statusCode));
    }
    if (response.bodyBytes.isEmpty) {
      throw const FinanceServiceException('File lampiran kosong.');
    }
    final name = _fileNameFromContentDisposition(
      response.headers['content-disposition'],
      fallbackFileName?.trim().isNotEmpty == true
          ? fallbackFileName!.trim()
          : 'attachment_$attachmentId',
    );
    return FinanceReimbursementAttachment(
      fileName: name,
      bytes: response.bodyBytes,
      contentType: response.headers['content-type'],
    );
  }

  static Future<FinanceActionResult> review({
    required int reimbursementId,
    required String status,
    required String financeUserId,
    String? reviewNotes,
  }) => _postAction(
    endpoint: '/api/asn/reimbursement/finance/review',
    payload: {
      'id': reimbursementId,
      'status': status,
      'financeUserId': financeUserId,
      'reviewNotes': reviewNotes,
    },
  );

  /// Upload bukti transfer lalu server mengubah status reimbursement menjadi `paid`.
  static Future<FinanceActionResult> completePayment({
    required int reimbursementId,
    required String financeUserId,
    required Uint8List paymentProofBytes,
    required String paymentProofFileName,
    required String paymentProofContentType,
    String? paymentNotes,
  }) => _postAction(
    endpoint: '/api/asn/reimbursement/finance/complete-payment',
    payload: {
      'id': reimbursementId,
      'financeUserId': financeUserId,
      'paymentProofBase64': base64Encode(paymentProofBytes),
      'paymentProofFileName': paymentProofFileName,
      'paymentProofContentType': paymentProofContentType,
      'paymentNotes': paymentNotes,
    },
  );

  static Future<FinanceActionResult> _postAction({
    required String endpoint,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseURL$endpoint'),
            headers: await _headers(),
            body: jsonEncode(payload),
          )
          .timeout(_timeout);
      final body = _decodeBody(response);
      if (body is! Map<String, dynamic>) {
        return FinanceActionResult(
          success: false,
          message: 'Respons server tidak valid (${response.statusCode}).',
        );
      }
      final result = FinanceActionResult.fromJson(body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return FinanceActionResult(
          success: false,
          message: result.message.isNotEmpty
              ? result.message
              : _messageFrom(body, response.statusCode),
        );
      }
      return result;
    } on FinanceServiceException catch (e) {
      return FinanceActionResult(success: false, message: e.message);
    } catch (e) {
      return FinanceActionResult(
        success: false,
        message: 'Koneksi bermasalah: $e',
      );
    }
  }

  static String _fileNameFromContentDisposition(
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

  static dynamic _decodeBody(http.Response response) {
    if (response.body.trim().isEmpty) return <String, dynamic>{};
    try {
      return jsonDecode(response.body);
    } catch (_) {
      throw FinanceServiceException(
        'Server memberi respons yang tidak dapat dibaca (${response.statusCode}).',
      );
    }
  }

  static String _messageFrom(dynamic body, int statusCode) {
    if (body is Map) {
      final msg = (body['message'] ?? body['Message'] ?? '').toString().trim();
      if (msg.isNotEmpty) return msg;
    }
    return 'Permintaan gagal. Kode server: $statusCode';
  }
}

class FinanceServiceException implements Exception {
  final String message;
  const FinanceServiceException(this.message);
  @override
  String toString() => message;
}
