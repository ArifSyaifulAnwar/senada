// services/attendance_service.dart
// ignore_for_file: prefer_interpolation_to_compose_strings

import 'dart:async';
import 'dart:convert';
import 'package:absensikaryawan/models/attendancemodel.dart';
import 'package:absensikaryawan/Services/config.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AttendanceService {
  Future<String?> _getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('UserID');
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

  // Fungsi untuk menghitung range tanggal yang benar
  // Perbaiki fungsi _calculateDateRange
  Map<String, DateTime> _calculateDateRange(String timeRange) {
    final now = DateTime.now();
    DateTime startDate;
    DateTime endDate;

    // Set endDate ke akhir hari ini (23:59:59)
    endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);

    switch (timeRange) {
      case '1 Hari':
        // PERBAIKAN: Untuk 1 hari, ambil dari awal hari ini sampai akhir hari ini
        startDate = DateTime(now.year, now.month, now.day, 0, 0, 0);
        endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case '7 Hari Terakhir':
        // 7 hari terakhir termasuk hari ini
        startDate = DateTime(
          now.year,
          now.month,
          now.day,
          0,
          0,
          0,
        ).subtract(Duration(days: 6));
        break;
      case '30 Hari Terakhir':
        // 30 hari terakhir termasuk hari ini
        startDate = DateTime(
          now.year,
          now.month,
          now.day,
          0,
          0,
          0,
        ).subtract(Duration(days: 29));
        break;
      case '1 Tahun Terakhir':
        // 1 tahun terakhir
        startDate = DateTime(now.year - 1, now.month, now.day, 0, 0, 0);
        break;
      default:
        // Default ke 1 tahun terakhir
        startDate = DateTime(now.year - 1, now.month, now.day, 0, 0, 0);
        break;
    }

    return {'startDate': startDate, 'endDate': endDate};
  }

  // Convert timeRange to English for backend compatibility
  String? _mapTimeRangeToEnglish(String? timeRange) {
    if (timeRange == null) return null;

    switch (timeRange) {
      case '1 Hari':
        return '1_day';
      case '7 Hari Terakhir':
        return '7_days';
      case '30 Hari Terakhir':
        return '30_days';
      case '1 Tahun Terakhir':
        return '1_year';
      case 'Pilih Periode':
        return 'custom';
      default:
        return timeRange;
    }
  }

  Future<ApiResponse<AttendanceHistoryResponse>> getAttendanceHistory({
    String? timeRange,
    DateTime? startDate,
    DateTime? endDate,
    String? statusFilter,
    int page = 1,
    int pageSize = 10000,
  }) async {
    try {
      final userId = await _getUserId();
      if (userId == null) {
        return ApiResponse<AttendanceHistoryResponse>(
          success: false,
          message: 'User ID tidak ditemukan. Silakan login ulang.',
        );
      }

      // Calculate date range berdasarkan timeRange
      DateTime? requestStartDate = startDate;
      DateTime? requestEndDate = endDate;

      if (timeRange != null && timeRange != 'Pilih Periode') {
        final dateRange = _calculateDateRange(timeRange);
        requestStartDate = dateRange['startDate'];
        requestEndDate = dateRange['endDate'];
      }

      final request = AttendanceHistoryRequest(
        userId: userId,
        timeRange: _mapTimeRangeToEnglish(timeRange),
        startDate: requestStartDate,
        endDate: requestEndDate,
        statusFilter: statusFilter,
        page: page,
        pageSize: pageSize,
      );

      final requestBody = jsonEncode(request.toJson());

      final response = await http
          .post(
            Uri.parse('$baseURL/api/attendance/history'),
            headers: await _getHeaders(),
            body: requestBody,
          )
          .timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        return ApiResponse<AttendanceHistoryResponse>(
          success: jsonData['Success'] ?? false,
          message: jsonData['Message'] ?? 'Data berhasil diambil',
          data: AttendanceHistoryResponse.fromJson(jsonData['Data'] ?? {}),
        );
      } else if (response.statusCode == 500) {
        return await _getFallbackAttendanceHistory(userId, page, pageSize);
      } else if (response.statusCode == 401) {
        return ApiResponse<AttendanceHistoryResponse>(
          success: false,
          message: 'Token tidak valid atau sudah expired. Silakan login ulang.',
        );
      } else if (response.statusCode == 404) {
        return ApiResponse<AttendanceHistoryResponse>(
          success: false,
          message: 'Data tidak ditemukan',
        );
      } else {
        final errorData = jsonDecode(response.body);
        return ApiResponse<AttendanceHistoryResponse>(
          success: false,
          message:
              errorData['Message'] ?? 'Gagal mengambil data riwayat absensi',
          error: errorData,
        );
      }
    } on TimeoutException {
      return ApiResponse<AttendanceHistoryResponse>(
        success: false,
        message: 'Koneksi timeout. Periksa koneksi internet Anda.',
      );
    } catch (e) {
      return ApiResponse<AttendanceHistoryResponse>(
        success: false,
        message: 'Terjadi kesalahan: ${e.toString()}',
        error: e.toString(),
      );
    }
  }

  // Fallback method dengan parameter minimal
  Future<ApiResponse<AttendanceHistoryResponse>> _getFallbackAttendanceHistory(
    String userId,
    int page,
    int pageSize,
  ) async {
    try {
      final fallbackRequest = {
        'userId': userId,
        'page': page,
        'pageSize': pageSize,
      };

      final requestBody = jsonEncode(fallbackRequest);

      final response = await http
          .post(
            Uri.parse('$baseURL/api/attendance/history'),
            headers: await _getHeaders(),
            body: requestBody,
          )
          .timeout(Duration(seconds: 30));
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        return ApiResponse<AttendanceHistoryResponse>(
          success: jsonData['Success'] ?? false,
          message:
              (jsonData['Message'] ?? 'Data berhasil diambil') +
              ' (fallback mode)',
          data: AttendanceHistoryResponse.fromJson(jsonData['Data'] ?? {}),
        );
      } else {
        final errorData = jsonDecode(response.body);
        return ApiResponse<AttendanceHistoryResponse>(
          success: false,
          message:
              'Fallback request juga gagal: ' +
              (errorData['Message'] ?? 'Unknown error'),
          error: errorData,
        );
      }
    } catch (e) {
      return ApiResponse<AttendanceHistoryResponse>(
        success: false,
        message: 'Fallback request error: ${e.toString()}',
        error: e.toString(),
      );
    }
  }

  Future<ApiResponse<AttendanceData>> getAttendanceDetail(
    int attendanceId,
  ) async {
    try {
      final userId = await _getUserId();
      if (userId == null) {
        return ApiResponse<AttendanceData>(
          success: false,
          message: 'User ID tidak ditemukan. Silakan login ulang.',
        );
      }

      final request = AttendanceDetailRequest(id: attendanceId, userId: userId);
      final response = await http
          .post(
            Uri.parse('$baseURL/api/attendance/detail'),
            headers: await _getHeaders(),
            body: jsonEncode(request.toJson()),
          )
          .timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        return ApiResponse<AttendanceData>(
          success: jsonData['Success'] ?? false,
          message: jsonData['Message'] ?? 'Detail berhasil diambil',
          data: AttendanceData.fromJson(jsonData['Data'] ?? {}),
        );
      } else if (response.statusCode == 404) {
        return ApiResponse<AttendanceData>(
          success: false,
          message: 'Data absensi tidak ditemukan',
        );
      } else if (response.statusCode == 401) {
        return ApiResponse<AttendanceData>(
          success: false,
          message: 'Token tidak valid atau sudah expired. Silakan login ulang.',
        );
      } else {
        final errorData = jsonDecode(response.body);
        return ApiResponse<AttendanceData>(
          success: false,
          message: errorData['Message'] ?? 'Gagal mengambil detail absensi',
          error: errorData,
        );
      }
    } on TimeoutException {
      return ApiResponse<AttendanceData>(
        success: false,
        message: 'Koneksi timeout. Periksa koneksi internet Anda.',
      );
    } catch (e) {
      return ApiResponse<AttendanceData>(
        success: false,
        message: 'Terjadi kesalahan: ${e.toString()}',
        error: e.toString(),
      );
    }
  }

  Future<ApiResponse<AttendanceStats>> getAttendanceStats({
    String? timeRange,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final userId = await _getUserId();
      if (userId == null) {
        return ApiResponse<AttendanceStats>(
          success: false,
          message: 'User ID tidak ditemukan. Silakan login ulang.',
        );
      }

      // Calculate date range berdasarkan timeRange
      DateTime? requestStartDate = startDate;
      DateTime? requestEndDate = endDate;

      if (timeRange != null && timeRange != 'Pilih Periode') {
        final dateRange = _calculateDateRange(timeRange);
        requestStartDate = dateRange['startDate'];
        requestEndDate = dateRange['endDate'];
      }

      final request = AttendanceHistoryRequest(
        userId: userId,
        timeRange: _mapTimeRangeToEnglish(timeRange) ?? '1_year',
        startDate: requestStartDate,
        endDate: requestEndDate,
        page: 1,
        pageSize: 1000,
      );

      final response = await http
          .post(
            Uri.parse('$baseURL/api/attendance/stats'),
            headers: await _getHeaders(),
            body: jsonEncode(request.toJson()),
          )
          .timeout(Duration(seconds: 30));
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        return ApiResponse<AttendanceStats>(
          success: jsonData['Success'] ?? false,
          message: jsonData['Message'] ?? 'Statistik berhasil diambil',
          data: AttendanceStats.fromJson(jsonData['Data'] ?? {}),
        );
      } else if (response.statusCode == 500) {
        return await _getFallbackAttendanceStats(userId);
      } else if (response.statusCode == 401) {
        return ApiResponse<AttendanceStats>(
          success: false,
          message: 'Token tidak valid atau sudah expired. Silakan login ulang.',
        );
      } else {
        final errorData = jsonDecode(response.body);
        return ApiResponse<AttendanceStats>(
          success: false,
          message: errorData['Message'] ?? 'Gagal mengambil statistik absensi',
          error: errorData,
        );
      }
    } on TimeoutException {
      return ApiResponse<AttendanceStats>(
        success: false,
        message: 'Koneksi timeout. Periksa koneksi internet Anda.',
      );
    } catch (e) {
      return ApiResponse<AttendanceStats>(
        success: false,
        message: 'Terjadi kesalahan: ${e.toString()}',
        error: e.toString(),
      );
    }
  }

  // Fallback method untuk stats dengan parameter minimal
  Future<ApiResponse<AttendanceStats>> _getFallbackAttendanceStats(
    String userId,
  ) async {
    try {
      final fallbackRequest = {'userId': userId, 'page': 1, 'pageSize': 1000};
      final requestBody = jsonEncode(fallbackRequest);
      final response = await http
          .post(
            Uri.parse('$baseURL/api/attendance/stats'),
            headers: await _getHeaders(),
            body: requestBody,
          )
          .timeout(Duration(seconds: 30));
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        return ApiResponse<AttendanceStats>(
          success: jsonData['Success'] ?? false,
          message:
              (jsonData['Message'] ?? 'Statistik berhasil diambil') +
              ' (fallback mode)',
          data: AttendanceStats.fromJson(jsonData['Data'] ?? {}),
        );
      } else {
        return ApiResponse<AttendanceStats>(
          success: true,
          message: 'Menggunakan statistik default karena server error',
          data: AttendanceStats(
            masukKantor: 0,
            tepatWaktu: 0,
            terlambat: 0,
            cutiKaryawan: 0,
          ),
        );
      }
    } catch (e) {
      // Return default stats sebagai last resort
      return ApiResponse<AttendanceStats>(
        success: true,
        message: 'Menggunakan statistik default karena error',
        data: AttendanceStats(
          masukKantor: 0,
          tepatWaktu: 0,
          terlambat: 0,
          cutiKaryawan: 0,
        ),
      );
    }
  }
}
