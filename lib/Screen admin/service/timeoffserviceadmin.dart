import 'dart:convert';
import 'dart:typed_data';
import 'package:absensikaryawan/Screen%20admin/model/timeoffmodeladmin.dart';
import 'package:absensikaryawan/Services/config.dart';
import 'package:http/http.dart' as http;

class TimeOffAdminService {
  static const String adminEndpoint = '/api/timeoff/admin';

  static Future<Map<String, String>> _getHeaders() async {
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

  // Get admin statistics
  static Future<ApiResponse<TimeOffAdminStatistics>> getAdminStatistics({
    int? year,
    int? month,
  }) async {
    try {
      final url = Uri.parse('$baseURL$adminEndpoint/statistics');

      final requestBody = AdminStatisticsRequest(year: year, month: month);

      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode(requestBody.toJson()),
      );

      final Map<String, dynamic> jsonResponse = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return ApiResponse<TimeOffAdminStatistics>.fromJson(
          jsonResponse,
          (data) => TimeOffAdminStatistics.fromJson(data),
        );
      } else {
        return ApiResponse<TimeOffAdminStatistics>(
          success: false,
          message: jsonResponse['message'] ?? 'Terjadi kesalahan',
          data: null,
        );
      }
    } catch (e) {
      return ApiResponse<TimeOffAdminStatistics>(
        success: false,
        message: 'Koneksi bermasalah: ${e.toString()}',
        data: null,
      );
    }
  }

  // Set kuota semua tipe sekaligus
  static Future<ApiResponse<bool>> setUserQuotaAll({
    required String adminId,
    required String userId,
    required int year,
    required int annualDays,
    required int birthDays,
    required int bereavDays,
  }) async {
    try {
      final token = await _getToken();

      if (token == null || token.isEmpty) {
        return ApiResponse<bool>(
          success: false,
          message: 'Token tidak ditemukan. Silakan login ulang.',
          data: false,
        );
      }

      final response = await http
          .post(
            Uri.parse('$baseURL/api/timeoff/admin/set-user-quota'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: json.encode({
              'adminId': adminId,
              'userId': userId,
              'year': year,
              'annualDays': annualDays,
              'birthDays': birthDays,
              'bereavDays': bereavDays,
            }),
          )
          .timeout(const Duration(seconds: 30));

      final body = json.decode(response.body);

      final success = body['success'] == true || body['Success'] == true;
      final message =
          (body['message'] ?? body['Message'] ?? 'Response tidak valid')
              .toString();

      if (response.statusCode == 200 && success) {
        return ApiResponse<bool>(success: true, message: message, data: true);
      }

      return ApiResponse<bool>(success: false, message: message, data: false);
    } catch (e) {
      return ApiResponse<bool>(
        success: false,
        message: 'Gagal menyimpan kuota: $e',
        data: false,
      );
    }
  }

  // Ambil detail karyawan: kuota + riwayat izin
  static Future<Map<String, dynamic>> getEmployeeDetail({
    required String adminId,
    required String userId,
    required int year,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseURL$adminEndpoint/employee-detail'),
            headers: await _getHeaders(),
            body: jsonEncode({
              'adminId': adminId,
              'userId': userId,

              // kirim semua versi agar aman dengan model C#
              'year': year,
              'tahun': year,
              'Tahun': year,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.body.isEmpty) {
        return {
          'success': false,
          'message': 'Response kosong dari server',
          'quotas': [],
          'history': [],
        };
      }

      final root = jsonDecode(response.body) as Map<String, dynamic>;

      final success = root['success'] == true || root['Success'] == true;
      final message = (root['message'] ?? root['Message'] ?? '').toString();

      final data = root['data'] ?? root['Data'] ?? root;

      List<dynamic> quotas = [];
      List<dynamic> history = [];

      if (data is Map<String, dynamic>) {
        quotas =
            (data['quotas'] ??
                    data['Quotas'] ??
                    data['quota'] ??
                    data['Quota'] ??
                    [])
                as List<dynamic>;

        history =
            (data['history'] ??
                    data['History'] ??
                    data['histories'] ??
                    data['Histories'] ??
                    [])
                as List<dynamic>;
      }

      Map<String, dynamic> normalizeQuota(dynamic e) {
        final q = e as Map<String, dynamic>;
        return {
          'userId': q['userId'] ?? q['UserId'] ?? q['userid'],
          'tahun': q['tahun'] ?? q['Tahun'],
          'quotaType': q['quotaType'] ?? q['QuotaType'] ?? q['quota_type'],
          'quotaName': q['quotaName'] ?? q['QuotaName'] ?? q['quota_name'],
          'quotaAwal': q['quotaAwal'] ?? q['QuotaAwal'] ?? q['quota_awal'] ?? 0,
          'quotaTerpakai':
              q['quotaTerpakai'] ??
              q['QuotaTerpakai'] ??
              q['quota_terpakai'] ??
              0,
          'quotaSisa': q['quotaSisa'] ?? q['QuotaSisa'] ?? q['quota_sisa'] ?? 0,
        };
      }

      Map<String, dynamic> normalizeHistory(dynamic e) {
        final h = e as Map<String, dynamic>;
        return {
          'id': h['id'] ?? h['Id'] ?? 0,
          'userId': h['userId'] ?? h['UserId'] ?? h['userid'],
          'jenisTimeOff':
              h['jenisTimeOff'] ?? h['JenisTimeOff'] ?? h['jenis_timeoff'],
          'tanggalMulai':
              h['tanggalMulai'] ?? h['TanggalMulai'] ?? h['tanggal_mulai'],
          'tanggalSelesai':
              h['tanggalSelesai'] ??
              h['TanggalSelesai'] ??
              h['tanggal_selesai'],
          'totalHari': h['totalHari'] ?? h['TotalHari'] ?? h['total_hari'] ?? 0,
          'status': h['status'] ?? h['Status'] ?? '',
          'createdAt': h['createdAt'] ?? h['CreatedAt'] ?? h['created_at'],
          'approvedAt': h['approvedAt'] ?? h['ApprovedAt'] ?? h['approved_at'],
          'usesQuota':
              h['usesQuota'] ?? h['UsesQuota'] ?? h['uses_quota'] ?? false,
          'quotaType': h['quotaType'] ?? h['QuotaType'] ?? h['quota_type'],
          'catatan': h['catatan'] ?? h['Catatan'],
        };
      }

      return {
        'success': success,
        'message': message,
        'quotas': quotas.map(normalizeQuota).toList(),
        'history': history.map(normalizeHistory).toList(),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Koneksi bermasalah: $e',
        'quotas': [],
        'history': [],
      };
    }
  }

  static Future<ApiResponse<Uint8List>> exportTimeOffForm({
    required int timeOffId,
    required String adminId,
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
            Uri.parse('$baseURL$adminEndpoint/export-form'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'timeOffId': timeOffId, 'adminId': adminId}),
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

  static Future<ApiResponse<Uint8List>> exportTimeOffFormAdmin({
    required int timeOffId,
    required String adminId,
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
            Uri.parse('$baseURL$adminEndpoint/export-form'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'timeOffId': timeOffId, 'adminId': adminId}),
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

  // Get all time offs for admin
  static Future<ApiResponse<List<AdminTimeOffData>>> getAllTimeOffs({
    required String adminId,
    String? status,
    String? userId,
    int? yearFilter,
    int? monthFilter,
  }) async {
    try {
      final url = Uri.parse('$baseURL$adminEndpoint/getall');

      final requestBody = AdminTimeOffListRequest(
        adminId: adminId,
        status: status,
        userId: userId,
        yearFilter: yearFilter,
        monthFilter: monthFilter,
      );

      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode(requestBody.toJson()),
      );

      final Map<String, dynamic> jsonResponse = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return ApiResponse<List<AdminTimeOffData>>.fromJson(
          jsonResponse,
          (data) => (data as List)
              .map((item) => AdminTimeOffData.fromJson(item))
              .toList(),
        );
      } else {
        return ApiResponse<List<AdminTimeOffData>>(
          success: false,
          message: jsonResponse['message'] ?? 'Terjadi kesalahan',
          data: null,
        );
      }
    } catch (e) {
      return ApiResponse<List<AdminTimeOffData>>(
        success: false,
        message: 'Koneksi bermasalah: ${e.toString()}',
        data: null,
      );
    }
  }

  // Review time off (approve/reject)
  static Future<ApiResponse<Map<String, dynamic>>> reviewTimeOff({
    required int id,
    required String status,
    required String approvedBy,
    String? rejectionReason,
    required String adminId,
  }) async {
    try {
      final url = Uri.parse('$baseURL$adminEndpoint/review');

      final requestBody = ReviewTimeOffRequest(
        id: id,
        status: status,
        approvedBy: approvedBy,
        rejectionReason: rejectionReason,
        adminId: adminId,
      );

      // Debug log
      // Debug log

      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode(requestBody.toJson()),
      );

      // Debug log
      // Debug log

      final Map<String, dynamic> jsonResponse = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return ApiResponse<Map<String, dynamic>>.fromJson(
          jsonResponse,
          (data) => data as Map<String, dynamic>,
        );
      } else {
        // Perbaiki handling error response
        String errorMessage = 'Terjadi kesalahan';

        if (jsonResponse.containsKey('message')) {
          errorMessage = jsonResponse['message'];
        } else if (jsonResponse.containsKey('Message')) {
          errorMessage = jsonResponse['Message'];
        } else if (response.statusCode == 400) {
          errorMessage = jsonResponse.toString();
        }

        return ApiResponse<Map<String, dynamic>>(
          success: false,
          message: errorMessage,
          data: null,
        );
      }
    } catch (e) {
      // Debug log
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        message: 'Koneksi bermasalah: ${e.toString()}',
        data: null,
      );
    }
  }

  // Mark time off as processed
  static Future<ApiResponse<Map<String, dynamic>>> markAsProcessed({
    required int id,
    required String processedBy,
    required String adminId,
  }) async {
    try {
      final url = Uri.parse('$baseURL$adminEndpoint/mark-processed');

      final requestBody = MarkProcessedRequest(
        id: id,
        processedBy: processedBy,
        adminId: adminId,
      );

      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode(requestBody.toJson()),
      );

      final Map<String, dynamic> jsonResponse = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return ApiResponse<Map<String, dynamic>>.fromJson(
          jsonResponse,
          (data) => data as Map<String, dynamic>,
        );
      } else {
        return ApiResponse<Map<String, dynamic>>(
          success: false,
          message: jsonResponse['message'] ?? 'Terjadi kesalahan',
          data: null,
        );
      }
    } catch (e) {
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        message: 'Koneksi bermasalah: ${e.toString()}',
        data: null,
      );
    }
  }

  // Get users with time off summary
  static Future<ApiResponse<List<UserWithTimeOffs>>> getUsersWithTimeOffs({
    required String adminId,
  }) async {
    try {
      final url = Uri.parse('$baseURL$adminEndpoint/users');

      final requestBody = AdminStatisticsRequest(adminId: adminId);

      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode(requestBody.toJson()),
      );

      final Map<String, dynamic> jsonResponse = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return ApiResponse<List<UserWithTimeOffs>>.fromJson(
          jsonResponse,
          (data) => (data as List)
              .map((item) => UserWithTimeOffs.fromJson(item))
              .toList(),
        );
      } else {
        return ApiResponse<List<UserWithTimeOffs>>(
          success: false,
          message: jsonResponse['message'] ?? 'Terjadi kesalahan',
          data: null,
        );
      }
    } catch (e) {
      return ApiResponse<List<UserWithTimeOffs>>(
        success: false,
        message: 'Koneksi bermasalah: ${e.toString()}',
        data: null,
      );
    }
  }

  static Future<ApiResponse<Map<String, dynamic>>> setUserAnnualQuota({
    required String adminId,
    required String userId,
    required int year,
    required int quotaDays,
  }) async {
    try {
      final url = Uri.parse('$baseURL$adminEndpoint/set-user-quota');

      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({
          'adminId': adminId,
          'userId': userId,
          'year': year,
          'quotaDays': quotaDays,
        }),
      );

      final Map<String, dynamic> jsonResponse = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return ApiResponse<Map<String, dynamic>>.fromJson(
          jsonResponse,
          (data) => data as Map<String, dynamic>? ?? {},
        );
      } else {
        return ApiResponse<Map<String, dynamic>>(
          success: false,
          message:
              jsonResponse['message'] ??
              jsonResponse['Message'] ??
              'Gagal menyimpan kuota cuti',
          data: null,
        );
      }
    } catch (e) {
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        message: 'Koneksi bermasalah: ${e.toString()}',
        data: null,
      );
    }
  }

  // Download file
  static Future<ApiResponse<Uint8List>> downloadFile({
    required int timeOffId,
    required String adminId,
  }) async {
    try {
      final url = Uri.parse('$baseURL$adminEndpoint/download-file');

      final requestBody = {'timeOffId': timeOffId, 'adminId': adminId};

      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        return ApiResponse<Uint8List>(
          success: true,
          message: 'File downloaded successfully',
          data: response.bodyBytes,
        );
      } else {
        final Map<String, dynamic> jsonResponse = jsonDecode(response.body);
        return ApiResponse<Uint8List>(
          success: false,
          message: jsonResponse['message'] ?? 'Gagal download file',
          data: null,
        );
      }
    } catch (e) {
      return ApiResponse<Uint8List>(
        success: false,
        message: 'Koneksi bermasalah: ${e.toString()}',
        data: null,
      );
    }
  }

  // Get file image URL for preview
  static String getFileImageUrl(int timeOffId) {
    return '$baseURL$adminEndpoint/file-image/$timeOffId';
  }

  // Get headers for network images
  static Future<Map<String, String>> getAdminHeaders() async {
    return await _getHeaders();
  }

  // Helper method untuk format status
  static String getStatusDisplayName(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Menunggu Review';
      case 'approved':
        return 'Disetujui';
      case 'rejected':
        return 'Ditolak';
      case 'processed':
        return 'Diproses';
      default:
        return status;
    }
  }

  // Helper method untuk get available years
  static List<int> getAvailableYears() {
    final currentYear = DateTime.now().year;
    return List.generate(5, (index) => currentYear - 2 + index);
  }

  // Helper method untuk get month names
  static List<String> getMonthNames() {
    return [
      'Semua Bulan',
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
  }

  // Test database connection
  static Future<ApiResponse<Map<String, dynamic>>> testConnection() async {
    try {
      final url = Uri.parse('$baseURL$adminEndpoint/test-connection');

      final response = await http.post(url, headers: await _getHeaders());

      final Map<String, dynamic> jsonResponse = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return ApiResponse<Map<String, dynamic>>.fromJson(
          jsonResponse,
          (data) => data as Map<String, dynamic>,
        );
      } else {
        return ApiResponse<Map<String, dynamic>>(
          success: false,
          message: jsonResponse['message'] ?? 'Connection failed',
          data: null,
        );
      }
    } catch (e) {
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        message: 'Network error: ${e.toString()}',
        data: null,
      );
    }
  }
}
