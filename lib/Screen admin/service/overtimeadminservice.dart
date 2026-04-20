import 'dart:convert';
import 'package:absensikaryawan/Screen%20admin/model/overtimemodeladmin.dart';
import 'package:absensikaryawan/Services/config.dart';
import 'package:http/http.dart' as http;

class OvertimeAdminService {
  static const String adminEndpoint = '/api/overtime/admin';
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

  static Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'bearer $token',
    };
  }

  // Get admin statistics
  static Future<ApiResponse<OvertimeAdminStatistics>> getAdminStatistics({
    int? year,
    int? month,
  }) async {
    try {
      final url = Uri.parse('$baseURL$adminEndpoint/statistics');

      final requestBody = AdminOvertimeStatisticsRequest(
        year: year,
        month: month,
      );

      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode(requestBody.toJson()),
      );

      final Map<String, dynamic> jsonResponse = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return ApiResponse<OvertimeAdminStatistics>.fromJson(
          jsonResponse,
          (data) => OvertimeAdminStatistics.fromJson(data),
        );
      } else {
        return ApiResponse<OvertimeAdminStatistics>(
          success: false,
          message: jsonResponse['message'] ?? 'Terjadi kesalahan',
          data: null,
        );
      }
    } catch (e) {
      return ApiResponse<OvertimeAdminStatistics>(
        success: false,
        message: 'Koneksi bermasalah: ${e.toString()}',
        data: null,
      );
    }
  }

  // Get all overtimes for admin
  static Future<ApiResponse<List<AdminOvertimeData>>> getAllOvertimes({
    required String adminId,
    String? status,
    String? userId,
    int? yearFilter,
    int? monthFilter,
  }) async {
    try {
      final url = Uri.parse('$baseURL$adminEndpoint/getall');

      final requestBody = AdminOvertimeListRequest(
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
        return ApiResponse<List<AdminOvertimeData>>.fromJson(
          jsonResponse,
          (data) => (data as List)
              .map((item) => AdminOvertimeData.fromJson(item))
              .toList(),
        );
      } else {
        return ApiResponse<List<AdminOvertimeData>>(
          success: false,
          message: jsonResponse['message'] ?? 'Terjadi kesalahan',
          data: null,
        );
      }
    } catch (e) {
      return ApiResponse<List<AdminOvertimeData>>(
        success: false,
        message: 'Koneksi bermasalah: ${e.toString()}',
        data: null,
      );
    }
  }

  // Review overtime (approve/reject)
  static Future<ApiResponse<Map<String, dynamic>>> reviewOvertime({
    required int id,
    required String status,
    required String approvedBy,
    String? rejectionReason,
    required String adminId,
  }) async {
    try {
      final url = Uri.parse('$baseURL$adminEndpoint/review');

      final requestBody = ReviewOvertimeRequest(
        id: id,
        status: status,
        approvedBy: approvedBy,
        rejectionReason: rejectionReason,
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

  // Bulk action (approve/reject multiple)
  static Future<ApiResponse<Map<String, dynamic>>> bulkAction({
    required List<int> ids,
    required String action,
    required String approvedBy,
    String? rejectionReason,
    required String adminId,
  }) async {
    try {
      final url = Uri.parse('$baseURL$adminEndpoint/bulk-action');

      final requestBody = BulkActionOvertimeRequest(
        ids: ids,
        action: action,
        approvedBy: approvedBy,
        rejectionReason: rejectionReason,
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

  // Delete overtime
  static Future<ApiResponse<Map<String, dynamic>>> deleteOvertime({
    required int id,
    required String adminId,
  }) async {
    try {
      final url = Uri.parse('$baseURL$adminEndpoint/delete');

      final requestBody = DeleteOvertimeRequest(id: id, adminId: adminId);

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

  // Get users with overtime summary
  // Fix untuk method getUsersWithOvertimes
  static Future<ApiResponse<List<UserWithOvertimes>>> getUsersWithOvertimes({
    required String adminId,
  }) async {
    try {
      final url = Uri.parse('$baseURL$adminEndpoint/users');

      // ✅ Fix: Tambahkan adminId ke dalam request body
      final requestBody = AdminOvertimeStatisticsRequest(
        adminId: adminId, // ← Tambahkan ini
        year: null,
        month: null,
      );

      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode(requestBody.toJson()),
      );

      final Map<String, dynamic> jsonResponse = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return ApiResponse<List<UserWithOvertimes>>.fromJson(
          jsonResponse,
          (data) => (data as List)
              .map((item) => UserWithOvertimes.fromJson(item))
              .toList(),
        );
      } else {
        return ApiResponse<List<UserWithOvertimes>>(
          success: false,
          message: jsonResponse['message'] ?? 'Terjadi kesalahan',
          data: null,
        );
      }
    } catch (e) {
      return ApiResponse<List<UserWithOvertimes>>(
        success: false,
        message: 'Koneksi bermasalah: ${e.toString()}',
        data: null,
      );
    }
  }

  // Export overtime data
  static Future<ApiResponse<List<Map<String, dynamic>>>> exportOvertimeData({
    required String adminId,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
    String? userId,
  }) async {
    try {
      final url = Uri.parse('$baseURL$adminEndpoint/export');

      final requestBody = ExportOvertimeRequest(
        adminId: adminId,
        startDate: startDate,
        endDate: endDate,
        status: status,
        userId: userId,
      );

      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode(requestBody.toJson()),
      );

      final Map<String, dynamic> jsonResponse = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return ApiResponse<List<Map<String, dynamic>>>.fromJson(
          jsonResponse,
          (data) => (data as List)
              .map((item) => Map<String, dynamic>.from(item))
              .toList(),
        );
      } else {
        return ApiResponse<List<Map<String, dynamic>>>(
          success: false,
          message: jsonResponse['message'] ?? 'Terjadi kesalahan',
          data: null,
        );
      }
    } catch (e) {
      return ApiResponse<List<Map<String, dynamic>>>(
        success: false,
        message: 'Koneksi bermasalah: ${e.toString()}',
        data: null,
      );
    }
  }

  // Helper methods untuk format dan utility
  static String formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    return '$hours:$minutes';
  }

  static String formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  static String formatDateTime(DateTime dateTime) {
    return '${formatDate(dateTime)} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  static String getStatusDisplayName(String status) {
    return OvertimeFilterOptions.getStatusDisplayName(status);
  }

  static List<String> getStatusOptions() {
    return OvertimeFilterOptions.statusOptions;
  }

  static List<String> getMonthNames() {
    return OvertimeFilterOptions.monthNames;
  }

  static List<int> getAvailableYears() {
    return OvertimeFilterOptions.getAvailableYears();
  }

  static Duration parseDuration(String timeString) {
    final parts = timeString.split(':');
    final hours = int.parse(parts[0]);
    final minutes = int.parse(parts[1]);
    return Duration(hours: hours, minutes: minutes);
  }

  static String formatHours(double hours) {
    return '${hours.toStringAsFixed(1)} jam';
  }

  // Validation helpers
  static bool isValidTimeRange(Duration start, Duration end) {
    return start.inMinutes < end.inMinutes;
  }

  static double calculateTotalHours(Duration start, Duration end) {
    if (!isValidTimeRange(start, end)) return 0.0;
    final difference = end.inMinutes - start.inMinutes;
    return difference / 60.0;
  }

  // Get urgency level for pending items
  static String getUrgencyLevel(int daysSinceSubmitted) {
    if (daysSinceSubmitted > 7) return 'SANGAT URGENT';
    if (daysSinceSubmitted > 3) return 'URGENT';
    return '';
  }

  // Check if overtime can be modified
  static bool canModifyOvertime(String status) {
    return status.toLowerCase() == 'pending';
  }

  // Generate filter summary text
  static String getFilterSummary({
    String? status,
    String? userName,
    int? year,
    int? month,
  }) {
    List<String> filters = [];

    if (status != null && status != 'Semua Status') {
      filters.add(getStatusDisplayName(status));
    }

    if (userName != null && userName != 'Semua User') {
      filters.add(userName);
    }

    if (year != null) {
      final monthName = month != null && month > 0
          ? OvertimeFilterOptions.monthNames[month]
          : 'Semua Bulan';
      filters.add('$monthName $year');
    }

    return filters.isEmpty ? 'Semua Data' : filters.join(' • ');
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
