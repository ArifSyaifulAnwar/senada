// FIX: submitTimeOff & updateTimeOff sekarang bisa kirim file via BYTES
// (aman untuk web + mobile). Sebelumnya hanya pakai dart:io File yang
// di-guard !kIsWeb sehingga di web file tidak pernah terkirim.
import 'dart:convert';
import 'dart:typed_data';
import 'package:absensikaryawan/Services/config.dart';
import 'package:absensikaryawan/Services/time_off_model.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as path;

import '../Screen User/fitur/org_approval_screen.dart';

class TimeOffService {
  static const String _base = '/api/timeoff';

  // ── Auth token ─────────────────────────────────────────────────────────────
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

  static Future<ApiResponse<List<int>>> dlDownloadLaporan({
    required int timeOffId,
    required String userId,
    required String fileType, // 'laporan' atau 'anggaran'
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseURL$_base/dl-download-laporan'),
        headers: await _jsonHeaders(),
        body: jsonEncode({
          'timeOffId': timeOffId,
          'userId': userId,
          'fileType': fileType,
        }),
      );
      if (res.statusCode == 200) {
        return ApiResponse(success: true, message: 'OK', data: res.bodyBytes);
      }
      String msg = 'Gagal download laporan';
      try {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        msg = (_get(body, 'message') ?? msg) as String;
      } catch (_) {}
      return ApiResponse(success: false, message: msg);
    } catch (e) {
      return ApiResponse(success: false, message: 'Koneksi bermasalah: $e');
    }
  }

  static Future<ApiResponse<List<int>>> dlExportFinal({
    required int timeOffId,
    required String userId,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseURL$_base/dl-export-final'),
        headers: await _jsonHeaders(),
        body: jsonEncode({'timeOffId': timeOffId, 'userId': userId}),
      );
      if (res.statusCode == 200) {
        return ApiResponse(success: true, message: 'OK', data: res.bodyBytes);
      }
      String msg = 'Gagal export dokumen';
      try {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        msg = (_get(body, 'message') ?? msg) as String;
      } catch (_) {}
      return ApiResponse(success: false, message: msg);
    } catch (e) {
      return ApiResponse(success: false, message: 'Koneksi bermasalah: $e');
    }
  }

  static Future<ApiResponse<List<dynamic>>> getReimburseItems(
    int timeOffId,
    String userId,
  ) async {
    try {
      final res = await http.post(
        Uri.parse('$baseURL$_base/reimburse-items'),
        headers: await _jsonHeaders(),
        body: jsonEncode({'timeOffId': timeOffId, 'userId': userId}),
      );
      if (res.body.isEmpty) {
        return ApiResponse(success: false, message: 'Response kosong');
      }
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && _get(body, 'success') == true) {
        final raw = _get(body, 'data') as List? ?? [];
        return ApiResponse(success: true, message: '', data: raw);
      }
      return ApiResponse(
        success: false,
        message: (_get(body, 'message') ?? 'Terjadi kesalahan') as String,
      );
    } catch (e) {
      return ApiResponse(success: false, message: 'Koneksi bermasalah: $e');
    }
  }

  static Future<ApiResponse<void>> dlHeadVerify({
    required int timeOffId,
    required String headUserId,
    required String status,
    String? rejectionReason,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseURL$_base/dl-head-verify'),
        headers: await _jsonHeaders(),
        body: jsonEncode({
          'id': timeOffId,
          'headUserId': headUserId,
          'status': status,
          'rejectionReason': rejectionReason,
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

  static Future<ApiResponse<void>> financeReview({
    required int id,
    required String status,
    required String financeUserId,
    String? rejectionReason,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseURL$_base/finance-review'),
        headers: await _jsonHeaders(),
        body: jsonEncode({
          'id': id,
          'status': status,
          'financeUserId': financeUserId,
          'rejectionReason': rejectionReason,
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

  static Future<ApiResponse<List<PendingOrgItem>>> getPendingFinance(
    String userId,
  ) async {
    try {
      final res = await http.post(
        Uri.parse('$baseURL$_base/pending-finance'),
        headers: await _jsonHeaders(),
        body: jsonEncode({'userId': userId}),
      );
      if (res.body.isEmpty) {
        return ApiResponse(success: false, message: 'Response kosong');
      }
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && _get(body, 'success') == true) {
        final rawData = _get(body, 'data') as Map<String, dynamic>?;
        final rawList = rawData?['items'] as List? ?? [];
        return ApiResponse(
          success: true,
          message: '',
          data: rawList
              .map((e) => PendingOrgItem.fromJson(e as Map<String, dynamic>))
              .toList(),
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

  static Future<ApiResponse<void>> dlHrdVerify({
    required int timeOffId,
    required String hrdUserId,
    required String status,
    String? rejectionReason,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseURL$_base/dl-hrd-verify'),
        headers: await _jsonHeaders(),
        body: jsonEncode({
          'id': timeOffId,
          'hrdUserId': hrdUserId,
          'status': status,
          'rejectionReason': rejectionReason,
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

  static Future<ApiResponse<void>> dlUploadTransfer({
    required int timeOffId,
    required String financeUserId,
    required List<int> fileBytes,
    required String fileName,
  }) async {
    try {
      final url = Uri.parse('$baseURL$_base/dl-upload-transfer');
      final mr = http.MultipartRequest('POST', url);
      mr.headers.addAll(await _multipartHeaders());
      mr.fields['timeOffId'] = timeOffId.toString();
      mr.fields['financeUserId'] = financeUserId;
      mr.files.add(
        http.MultipartFile.fromBytes(
          'transferFile',
          fileBytes,
          filename: fileName,
          contentType: _mediaTypeFromName(fileName),
        ),
      );
      final res = await http.Response.fromStream(await mr.send());
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return ApiResponse(
        success: _get(body, 'success') == true,
        message: (_get(body, 'message') ?? '') as String,
      );
    } catch (e) {
      return ApiResponse(success: false, message: 'Koneksi bermasalah: $e');
    }
  }

  static Future<ApiResponse<List<PendingOrgItem>>> getPendingHeadVerify(
    String userId,
  ) async {
    try {
      final res = await http.post(
        Uri.parse('$baseURL$_base/pending-head-verify'),
        headers: await _jsonHeaders(),
        body: jsonEncode({'userId': userId}),
      );
      if (res.body.isEmpty) {
        return ApiResponse(success: false, message: 'Response kosong');
      }
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && _get(body, 'success') == true) {
        final rawData = _get(body, 'data') as Map<String, dynamic>?;
        final rawList = rawData?['items'] as List? ?? [];
        return ApiResponse(
          success: true,
          message: '',
          data: rawList
              .map((e) => PendingOrgItem.fromJson(e as Map<String, dynamic>))
              .toList(),
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

  // ── PENDING HRD VERIFY — list untuk HRD ──────────────────────────────────
  static Future<ApiResponse<List<PendingOrgItem>>> getPendingHrdVerify(
    String userId,
  ) async {
    try {
      final res = await http.post(
        Uri.parse('$baseURL$_base/pending-hrd-verify'),
        headers: await _jsonHeaders(),
        body: jsonEncode({'userId': userId}),
      );
      if (res.body.isEmpty) {
        return ApiResponse(success: false, message: 'Response kosong');
      }
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && _get(body, 'success') == true) {
        final rawData = _get(body, 'data') as Map<String, dynamic>?;
        final rawList = rawData?['items'] as List? ?? [];
        return ApiResponse(
          success: true,
          message: '',
          data: rawList
              .map((e) => PendingOrgItem.fromJson(e as Map<String, dynamic>))
              .toList(),
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

  // ── PENDING TRANSFER — list untuk Finance ────────────────────────────────
  static Future<ApiResponse<List<PendingOrgItem>>> getPendingTransfer(
    String userId,
  ) async {
    try {
      final res = await http.post(
        Uri.parse('$baseURL$_base/pending-transfer'),
        headers: await _jsonHeaders(),
        body: jsonEncode({'userId': userId}),
      );
      if (res.body.isEmpty) {
        return ApiResponse(success: false, message: 'Response kosong');
      }
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && _get(body, 'success') == true) {
        final rawData = _get(body, 'data') as Map<String, dynamic>?;
        final rawList = rawData?['items'] as List? ?? [];
        return ApiResponse(
          success: true,
          message: '',
          data: rawList
              .map((e) => PendingOrgItem.fromJson(e as Map<String, dynamic>))
              .toList(),
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

  // ── DL DOWNLOAD DOC — download Surat Tugas / Form Biaya / Template Laporan
  static Future<ApiResponse<List<int>>> dlDownloadDoc({
    required int timeOffId,
    required String userId,
    required String
    docType, // 'surat_tugas' | 'form_biaya' | 'template_laporan'
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseURL$_base/dl-download-doc'),
        headers: await _jsonHeaders(),
        body: jsonEncode({
          'timeOffId': timeOffId,
          'userId': userId,
          'docType': docType,
        }),
      );
      if (res.statusCode == 200) {
        return ApiResponse(success: true, message: 'OK', data: res.bodyBytes);
      }
      String msg = 'Gagal download dokumen';
      try {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        msg = (_get(body, 'message') ?? msg) as String;
      } catch (_) {}
      return ApiResponse(success: false, message: msg);
    } catch (e) {
      return ApiResponse(success: false, message: 'Koneksi bermasalah: $e');
    }
  }

  static Future<ApiResponse<Uint8List>> exportTimeOffFormUser({
    required int timeOffId,
    required String userId,
  }) async {
    try {
      final token = await _getToken();

      if (token == null || token.isEmpty) {
        return ApiResponse<Uint8List>(
          success: false,
          message: 'Token tidak ditemukan. Silakan login ulang.',
          data: null,
        );
      }

      final response = await http
          .post(
            Uri.parse('$baseURL$_base/export-form'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'timeOffId': timeOffId, 'userId': userId}),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        return ApiResponse<Uint8List>(
          success: true,
          message: 'Formulir berhasil diexport',
          data: response.bodyBytes,
        );
      }

      String msg = 'Gagal export formulir';
      try {
        final body = jsonDecode(response.body);
        msg = (body['message'] ?? body['Message'] ?? msg).toString();
      } catch (_) {}

      return ApiResponse<Uint8List>(success: false, message: msg, data: null);
    } catch (e) {
      return ApiResponse<Uint8List>(
        success: false,
        message: 'Koneksi bermasalah: $e',
        data: null,
      );
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

  static String _normalizeJenis(String j) =>
      j.trim().replaceAll(RegExp(r'\s+'), ' ');

  static MediaType _mediaType(String filePath) {
    final ext = path.extension(filePath).toLowerCase();
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
  // time_off_service.dart — tambah 3 method ini di dalam class TimeOffService

  // ── HRD Review ────────────────────────────────────────────────────────────────
  static Future<ApiResponse<void>> hrdReview({
    required int id,
    required String status,
    required String hrdUserId,
    String? rejectionReason,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseURL$_base/hrd-review'),
        headers: await _jsonHeaders(),
        body: jsonEncode({
          'id': id,
          'status': status,
          'hrdUserId': hrdUserId,
          'rejectionReason': rejectionReason,
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

  // ── Director Review ───────────────────────────────────────────────────────────
  static Future<ApiResponse<void>> directorReview({
    required int id,
    required String status,
    required String directorUserId,
    String? rejectionReason,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseURL$_base/director-review'),
        headers: await _jsonHeaders(),
        body: jsonEncode({
          'id': id,
          'status': status,
          'directorUserId': directorUserId,
          'rejectionReason': rejectionReason,
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

  // ── Pending Director List ─────────────────────────────────────────────────────
  static Future<ApiResponse<List<TimeOffModel>>> getPendingDirector(
    String directorUserId,
  ) async {
    try {
      final res = await http.post(
        Uri.parse('$baseURL$_base/pending-director'),
        headers: await _jsonHeaders(),
        body: jsonEncode({'userId': directorUserId}),
      );
      if (res.body.isEmpty) {
        return ApiResponse(success: false, message: 'Response kosong');
      }
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (_get(body, 'success') == true) {
        final rawData = _get(body, 'data') as Map<String, dynamic>?;
        final rawList = rawData?['items'] as List? ?? [];
        return ApiResponse(
          success: true,
          message: '',
          data: rawList
              .map((e) => TimeOffModel.fromJson(e as Map<String, dynamic>))
              .toList(),
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

  /// Helper: baca value dari JSON yang bisa PascalCase atau camelCase
  static dynamic _get(Map<String, dynamic> json, String key) =>
      json[key[0].toUpperCase() + key.substring(1)] ?? json[key];

  // ── SUBMIT ─────────────────────────────────────────────────────────────────
  // receiptBytes/receiptFileName → jalur web + mobile (diprioritaskan).
  // request.receiptFile (dart:io File) → fallback mobile.
  static Future<ApiResponse<int>> submitTimeOff(
    TimeOffRequest request, {
    List<int>? receiptBytes,
    String? receiptFileName,
  }) async {
    try {
      final url = Uri.parse('$baseURL$_base/submit');

      final mr = http.MultipartRequest('POST', url);
      mr.headers.addAll(await _multipartHeaders());

      // ── Reimbursement untuk dimasukkan ke request JSON ───────────────
      // PENTING: ini harus LIST, bukan jsonEncode string.
      final List<Map<String, dynamic>>? reimbursementList =
          request.reimbursementItems != null &&
              request.reimbursementItems!.isNotEmpty
          ? request.reimbursementItems!.map((e) => e.toJson()).toList()
          : null;

      // Ini hanya untuk field tambahan form-data, kalau API baca langsung dari form.
      final String? reimbursementJson = reimbursementList != null
          ? jsonEncode(reimbursementList)
          : null;

      // ── Data utama yang dikirim ke API ───────────────────────────────
      final reqData = {
        'userId': request.userId,
        'jenisTimeOff': _normalizeJenis(request.jenisTimeOff),
        'tanggalMulai': request.tanggalMulai.toIso8601String(),
        'tanggalSelesai': request.tanggalSelesai.toIso8601String(),
        'catatan': request.catatan,
        'jenisPekerjaan': request.jenisPekerjaan,
        'rabType': request.rabType,
        'nominalUangKantor': request.nominalUangKantor,

        // INI YANG DIPERBAIKI:
        // sebelumnya reimbursementJson, sekarang reimbursementList.
        'reimbursementItems': reimbursementList,
      };

      // Request utama dikirim sebagai JSON di field "request"
      mr.fields['request'] = jsonEncode(reqData);

      // Field tambahan supaya tetap aman kalau API baca form-data langsung
      if (request.rabType != null && request.rabType!.trim().isNotEmpty) {
        mr.fields['rabType'] = request.rabType!.trim();
      }

      if (request.nominalUangKantor != null) {
        mr.fields['nominalUangKantor'] = request.nominalUangKantor!
            .toStringAsFixed(0);
      }

      if (reimbursementJson != null && reimbursementJson.isNotEmpty) {
        mr.fields['reimbursementItems'] = reimbursementJson;
      }

      // ── Attach file: prioritas BYTES untuk web + mobile ─────────────
      if (receiptBytes != null &&
          receiptBytes.isNotEmpty &&
          receiptFileName != null &&
          receiptFileName.isNotEmpty) {
        mr.files.add(
          http.MultipartFile.fromBytes(
            'receiptFile',
            receiptBytes,
            filename: receiptFileName,
            contentType: _mediaTypeFromName(receiptFileName),
          ),
        );
      } else if (request.receiptFile != null) {
        mr.files.add(
          await http.MultipartFile.fromPath(
            'receiptFile',
            request.receiptFile!.path,
            filename: path.basename(request.receiptFile!.path),
            contentType: _mediaType(request.receiptFile!.path),
          ),
        );
      }

      final streamed = await mr.send();
      final res = await http.Response.fromStream(streamed);

      if (res.body.isEmpty) {
        return const ApiResponse(
          success: false,
          message: 'Response kosong dari server',
        );
      }

      final body = jsonDecode(res.body) as Map<String, dynamic>;

      final success = _get(body, 'success') == true;
      final message = (_get(body, 'message') ?? 'Terjadi kesalahan').toString();

      if (res.statusCode == 200 && success) {
        final rawId = _get(body, 'id') ?? _get(body, 'data');

        int? newId;
        if (rawId is int) {
          newId = rawId;
        } else if (rawId != null) {
          newId = int.tryParse(rawId.toString());
        }

        return ApiResponse<int>(success: true, message: message, data: newId);
      }

      return ApiResponse<int>(success: false, message: message);
    } catch (e) {
      return ApiResponse<int>(
        success: false,
        message: 'Koneksi bermasalah: $e',
      );
    }
  }

  // ── UPDATE ─────────────────────────────────────────────────────────────────
  static Future<ApiResponse<Map<String, dynamic>>> updateTimeOff(
    UpdateTimeOffRequest request, {
    List<int>? receiptBytes,
    String? receiptFileName,
  }) async {
    try {
      final url = Uri.parse('$baseURL$_base/update');
      final mr = http.MultipartRequest('POST', url);
      mr.headers.addAll(await _multipartHeaders());

      mr.fields['id'] = request.id.toString();
      mr.fields['userId'] = request.userId;
      mr.fields['jenisTimeOff'] = _normalizeJenis(request.jenisTimeOff);
      mr.fields['tanggalMulai'] = request.tanggalMulai.toIso8601String();
      mr.fields['tanggalSelesai'] = request.tanggalSelesai.toIso8601String();
      if (request.catatan != null) mr.fields['catatan'] = request.catatan!;
      if (request.jenisPekerjaan != null) {
        mr.fields['jenisPekerjaan'] = request.jenisPekerjaan!;
      }
      if (request.rabType != null) mr.fields['rabType'] = request.rabType!;
      if (request.nominalUangKantor != null) {
        mr.fields['nominalUangKantor'] = request.nominalUangKantor.toString();
      }
      if (request.reimbursementItems != null) {
        mr.fields['reimbursementItems'] = jsonEncode(
          request.reimbursementItems!.map((e) => e.toJson()).toList(),
        );
      }

      // ── Attach file: prioritas BYTES (web + mobile), fallback File path ──
      if (receiptBytes != null &&
          receiptBytes.isNotEmpty &&
          receiptFileName != null &&
          receiptFileName.isNotEmpty) {
        mr.files.add(
          http.MultipartFile.fromBytes(
            'receiptFile',
            receiptBytes,
            filename: receiptFileName,
            contentType: _mediaTypeFromName(receiptFileName),
          ),
        );
      } else if (request.receiptFile != null) {
        mr.files.add(
          await http.MultipartFile.fromPath(
            'receiptFile',
            request.receiptFile!.path,
            filename: path.basename(request.receiptFile!.path),
            contentType: _mediaType(request.receiptFile!.path),
          ),
        );
      }

      final res = await http.Response.fromStream(await mr.send());
      if (res.body.isEmpty) {
        return ApiResponse(success: false, message: 'Response kosong');
      }

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && _get(body, 'success') == true) {
        return ApiResponse(
          success: true,
          message: (_get(body, 'message') ?? '') as String,
          data: _get(body, 'data') as Map<String, dynamic>?,
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

  // ── DL SUBMIT LAPORAN ──────────────────────────────────────────────────────
  // Support semua platform: mobile (File), web (bytes)
  static Future<ApiResponse<void>> submitDlLaporan(
    DlLaporanRequest request,
  ) async {
    try {
      final url = Uri.parse('$baseURL$_base/dl-submit-laporan');
      final mr = http.MultipartRequest('POST', url);
      mr.headers.addAll(await _multipartHeaders());

      mr.fields['timeOffId'] = request.timeOffId.toString();
      mr.fields['userId'] = request.userId;

      // ── Laporan file (WAJIB) ──────────────────────────────────────────────
      if (request.laporanBytes != null && request.laporanBytes!.isNotEmpty) {
        mr.files.add(
          http.MultipartFile.fromBytes(
            'laporanFile',
            request.laporanBytes!,
            filename: request.laporanFileName ?? 'laporan.pdf',
            contentType: _mediaTypeFromName(request.laporanFileName ?? ''),
          ),
        );
      } else if (request.laporanFile != null) {
        final lFile = request.laporanFile!;
        mr.files.add(
          await http.MultipartFile.fromPath(
            'laporanFile',
            lFile.path,
            filename: path.basename(lFile.path),
            contentType: _mediaType(lFile.path),
          ),
        );
      } else {
        return ApiResponse(
          success: false,
          message: 'File laporan tidak tersedia',
        );
      }

      // ── Anggaran file (OPSIONAL — hanya attach kalau ada) ────────────────
      // Tidak return error kalau null — validasi wajib sudah di screen Flutter
      // dan di server SP (hanya wajib kalau rab_type = reimbursement)
      if (request.anggaranBytes != null && request.anggaranBytes!.isNotEmpty) {
        mr.files.add(
          http.MultipartFile.fromBytes(
            'anggaranFile',
            request.anggaranBytes!,
            filename: request.anggaranFileName ?? 'anggaran.pdf',
            contentType: _mediaTypeFromName(request.anggaranFileName ?? ''),
          ),
        );
      } else if (request.anggaranFile != null) {
        final aFile = request.anggaranFile!;
        mr.files.add(
          await http.MultipartFile.fromPath(
            'anggaranFile',
            aFile.path,
            filename: path.basename(aFile.path),
            contentType: _mediaType(aFile.path),
          ),
        );
      }
      // Kalau null → tidak di-attach, server terima anggaranFile = NULL (aman)

      final res = await http.Response.fromStream(await mr.send());
      final body = jsonDecode(res.body) as Map<String, dynamic>;

      final successField = _get(body, 'success');
      final msgField =
          (_get(body, 'message') ?? _get(body, 'Message') ?? '') as String;

      if (successField != null) {
        return ApiResponse(success: successField == true, message: msgField);
      }
      final httpOk = res.statusCode >= 200 && res.statusCode < 300;
      return ApiResponse(success: httpOk, message: msgField);
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

  // ── GET MY TIMEOFF ─────────────────────────────────────────────────────────
  static Future<ApiResponse<TimeOffListResponse>> getMyTimeOff(
    String userId,
  ) async {
    try {
      final res = await http.post(
        Uri.parse('$baseURL$_base/my-timeoff'),
        headers: await _jsonHeaders(),
        body: jsonEncode({'userId': userId}),
      );

      if (res.body.isEmpty) {
        return ApiResponse(success: false, message: 'Response kosong');
      }

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && _get(body, 'success') == true) {
        final rawData = _get(body, 'data');
        return ApiResponse(
          success: true,
          message: '',
          data: TimeOffListResponse.fromJson(rawData as Map<String, dynamic>),
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

  // ── DELETE ─────────────────────────────────────────────────────────────────
  static Future<ApiResponse<Map<String, dynamic>>> deleteTimeOff(
    int id,
    String userId,
  ) async {
    try {
      final res = await http.post(
        Uri.parse('$baseURL$_base/delete'),
        headers: await _jsonHeaders(),
        body: jsonEncode({'id': id, 'userId': userId}),
      );
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && _get(body, 'success') == true) {
        return ApiResponse(
          success: true,
          message: (_get(body, 'message') ?? '') as String,
          data: _get(body, 'data') as Map<String, dynamic>?,
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

  // ── DOWNLOAD FILE ──────────────────────────────────────────────────────────
  static Future<ApiResponse<List<int>>> downloadFile(
    int timeOffId,
    String userId,
  ) async {
    try {
      final res = await http.post(
        Uri.parse('$baseURL$_base/download-file'),
        headers: await _jsonHeaders(),
        body: jsonEncode({'TimeOffId': timeOffId, 'UserId': userId}),
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

  // ── ANNUAL QUOTA ───────────────────────────────────────────────────────────
  static Future<ApiResponse<AnnualQuota>> getAnnualQuota(
    String userId, {
    int? tahun,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseURL$_base/annual-quota'),
        headers: await _jsonHeaders(),
        body: jsonEncode({'userId': userId, 'tahun': tahun}),
      );
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && _get(body, 'success') == true) {
        return ApiResponse(
          success: true,
          message: '',
          data: AnnualQuota.fromJson(
            _get(body, 'data') as Map<String, dynamic>,
          ),
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

  // ── ORGANIZATION LIST (untuk dropdown DL) ──────────────────────────────────
  static Future<ApiResponse<List<String>>> getOrganizationList(
    String userId,
  ) async {
    try {
      final res = await http.post(
        Uri.parse('$baseURL$_base/organization-list'),
        headers: await _jsonHeaders(),
        body: jsonEncode({'userId': userId}),
      );
      if (res.body.isEmpty) {
        return ApiResponse(success: false, message: 'Response kosong');
      }

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && _get(body, 'success') == true) {
        final raw = _get(body, 'data') as List? ?? [];
        return ApiResponse(
          success: true,
          message: '',
          data: raw.map((e) => e.toString()).toList(),
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

  // ── ORG REVIEW (anggota divisi approve/reject DL) ─────────────────────────
  static Future<ApiResponse<void>> orgReview({
    required int timeOffId,
    required String reviewerUserId,
    required String status, // 'Approved' | 'Rejected'
    String? rejectionReason,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseURL$_base/org-review'),
        headers: await _jsonHeaders(),
        body: jsonEncode({
          'id': timeOffId,
          'reviewerUserId': reviewerUserId,
          'status': status,
          'rejectionReason': rejectionReason,
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

  // ── PENDING ORG REVIEW (list DL yang perlu di-approve user) ──────────────
  static Future<ApiResponse<List<PendingOrgItem>>> getPendingOrgReview(
    String userId,
  ) async {
    try {
      final res = await http.post(
        Uri.parse('$baseURL$_base/pending-org-review'),
        headers: await _jsonHeaders(),
        body: jsonEncode({'userId': userId}),
      );
      if (res.body.isEmpty) {
        return ApiResponse(success: false, message: 'Response kosong');
      }

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && _get(body, 'success') == true) {
        final rawData = _get(body, 'data') as Map<String, dynamic>?;
        final rawList = rawData?['items'] as List? ?? [];
        return ApiResponse(
          success: true,
          message: '',
          data: rawList
              .map((e) => PendingOrgItem.fromJson(e as Map<String, dynamic>))
              .toList(),
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
}
