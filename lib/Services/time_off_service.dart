// Services/time_off_service.dart — FULL REPLACE
// FIX: submitTimeOff & updateTimeOff sekarang bisa kirim file via BYTES
// (aman untuk web + mobile). Sebelumnya hanya pakai dart:io File yang
// di-guard !kIsWeb sehingga di web file tidak pernah terkirim.
import 'dart:convert';
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

      final reqData = {
        'userId': request.userId,
        'jenisTimeOff': _normalizeJenis(request.jenisTimeOff),
        'tanggalMulai': request.tanggalMulai.toIso8601String(),
        'tanggalSelesai': request.tanggalSelesai.toIso8601String(),
        'catatan': request.catatan,
        'jenisPekerjaan': request.jenisPekerjaan,
        'rabType': request.rabType,
        'nominalUangKantor': request.nominalUangKantor,
        'reimbursementItems': request.reimbursementItems
            ?.map((e) => e.toJson())
            .toList(),
      };
      mr.fields['request'] = jsonEncode(reqData);

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
          data: _get(body, 'data') as int?,
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

      // ── Laporan file ──────────────────────────────────────────────────────
      if (request.laporanBytes != null) {
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

      // ── Anggaran file ─────────────────────────────────────────────────────
      if (request.anggaranBytes != null) {
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
      } else {
        return ApiResponse(
          success: false,
          message: 'File anggaran tidak tersedia',
        );
      }

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
