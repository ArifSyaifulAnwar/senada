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

      final requestBody = AdminStatisticsRequest();

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
