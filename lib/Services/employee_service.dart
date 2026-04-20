// File: Services/employee_service.dart


import 'dart:convert';
import 'package:absensikaryawan/Services/config.dart';
import 'package:absensikaryawan/models/employee_models.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class EmployeeService {
  static const String _baseUrl = '$baseURL/api/employee';

  static Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'bearer $token',
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

  /// Ambil userId dari SharedPreferences
  static Future<String?> _getCurrentUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('UserID');
    } catch (e) {
      return null;
    }
  }

  /// Get employee list dengan filter by company (berdasarkan userId yang login)
  static Future<ApiResponse<EmployeeListResponse>> getEmployeeList({
    String? searchQuery,
    String? department,
    String? status,
    String? sortBy,
    int? page,
    int? pageSize,
  }) async {
    try {
      // Get userId dari SharedPreferences
      final userId = await _getCurrentUserId();

      if (userId == null || userId.isEmpty) {
        return ApiResponse<EmployeeListResponse>(
          success: false,
          message: 'UserId tidak ditemukan. Silakan login ulang.',
        );
      }

      // Buat request body - SIMPLE dan sesuai struktur API
      final requestBody = {
        'UserId': userId, // Penting: sesuaikan case dengan yang diharapkan API
        if (searchQuery != null && searchQuery.isNotEmpty)
          'SearchQuery': searchQuery,
        if (department != null && department.isNotEmpty)
          'Department': department,
        if (status != null && status.isNotEmpty) 'Status': status,
        'SortBy': sortBy ?? 'name_asc',
        'Page': page ?? 1,
        'PageSize': pageSize ?? 1000,
      };


      final response = await http
          .post(
            Uri.parse('$_baseUrl/list'),
            headers: await _getHeaders(),
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 30));


      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);

        if (jsonData['Success'] == true && jsonData['Data'] != null) {
          final employeeListResponse = EmployeeListResponse.fromJson(
            jsonData['Data'],
          );
          return ApiResponse<EmployeeListResponse>(
            success: true,
            message: jsonData['Message'] ?? 'Success',
            data: employeeListResponse,
          );
        } else {
          return ApiResponse<EmployeeListResponse>(
            success: false,
            message: jsonData['Message'] ?? 'Failed to get employee list',
          );
        }
      } else if (response.statusCode == 401) {
        return ApiResponse<EmployeeListResponse>(
          success: false,
          message: 'Unauthorized. Silakan login ulang.',
        );
      } else if (response.statusCode == 400) {
        try {
          final jsonData = jsonDecode(response.body);
          return ApiResponse<EmployeeListResponse>(
            success: false,
            message:
                jsonData['Message'] ?? 'Bad Request: ${response.statusCode}',
          );
        } catch (e) {
          return ApiResponse<EmployeeListResponse>(
            success: false,
            message: 'Bad Request: ${response.body}',
          );
        }
      } else {
        try {
          final jsonData = jsonDecode(response.body);
          return ApiResponse<EmployeeListResponse>(
            success: false,
            message:
                jsonData['Message'] ?? 'HTTP Error: ${response.statusCode}',
          );
        } catch (e) {
          return ApiResponse<EmployeeListResponse>(
            success: false,
            message: 'HTTP Error: ${response.statusCode} - ${response.body}',
          );
        }
      }
    } catch (e) {
      return ApiResponse<EmployeeListResponse>(
        success: false,
        message: 'Network error: $e',
      );
    }
  }

  /// Get employee detail dengan support Id, UserId, atau EmployeeId
  /// Prioritas: UserId > Id > EmployeeId (sesuai API specification)
  static Future<ApiResponse<EmployeeApiData>> getEmployeeDetail({
    int? id,
    String? userId,
    String? employeeId,
  }) async {
    try {
      // Validasi minimal satu parameter harus ada
      if ((id == null || id == 0) &&
          (userId == null || userId.isEmpty) &&
          (employeeId == null || employeeId.isEmpty)) {
        return ApiResponse<EmployeeApiData>(
          success: false,
          message:
              'Minimal salah satu identifier (Id, UserId, atau EmployeeId) harus diisi',
        );
      }

      final requestBody = <String, dynamic>{};

      // Sesuaikan case dengan API specification
      if (userId != null && userId.isNotEmpty) {
        requestBody['UserId'] = userId;
      } else if (id != null && id > 0) {
        requestBody['Id'] = id;
      } else if (employeeId != null && employeeId.isNotEmpty) {
        requestBody['EmployeeId'] = employeeId;
      }


      final response = await http.post(
        Uri.parse('$_baseUrl/detail'),
        headers: await _getHeaders(),
        body: jsonEncode(requestBody),
      );


      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);

        if (jsonData['Success'] == true && jsonData['Data'] != null) {
          final employeeData = EmployeeApiData.fromJson(jsonData['Data']);
          return ApiResponse<EmployeeApiData>(
            success: true,
            message: jsonData['Message'] ?? 'Success',
            data: employeeData,
          );
        } else {
          return ApiResponse<EmployeeApiData>(
            success: false,
            message: jsonData['Message'] ?? 'Failed to get employee detail',
          );
        }
      } else if (response.statusCode == 401) {
        return ApiResponse<EmployeeApiData>(
          success: false,
          message: 'Unauthorized. Silakan login ulang.',
        );
      } else if (response.statusCode == 404) {
        return ApiResponse<EmployeeApiData>(
          success: false,
          message: 'Employee not found',
        );
      } else {
        try {
          final jsonData = jsonDecode(response.body);
          return ApiResponse<EmployeeApiData>(
            success: false,
            message:
                jsonData['Message'] ?? 'HTTP Error: ${response.statusCode}',
          );
        } catch (e) {
          return ApiResponse<EmployeeApiData>(
            success: false,
            message: 'HTTP Error: ${response.statusCode} - ${response.body}',
          );
        }
      }
    } catch (e) {
      return ApiResponse<EmployeeApiData>(
        success: false,
        message: 'Network error: $e',
      );
    }
  }

  /// Get employee statistics (optional, jika dibutuhkan)
  static Future<ApiResponse<EmployeeStats>> getEmployeeStats() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/stats'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);

        if (jsonData['Success'] == true && jsonData['Data'] != null) {
          final stats = EmployeeStats.fromJson(jsonData['Data']);
          return ApiResponse<EmployeeStats>(
            success: true,
            message: jsonData['Message'] ?? 'Success',
            data: stats,
          );
        } else {
          return ApiResponse<EmployeeStats>(
            success: false,
            message: jsonData['Message'] ?? 'Failed to get statistics',
          );
        }
      } else {
        try {
          final jsonData = jsonDecode(response.body);
          return ApiResponse<EmployeeStats>(
            success: false,
            message:
                jsonData['Message'] ?? 'HTTP Error: ${response.statusCode}',
          );
        } catch (e) {
          return ApiResponse<EmployeeStats>(
            success: false,
            message: 'HTTP Error: ${response.statusCode}',
          );
        }
      }
    } catch (e) {
      return ApiResponse<EmployeeStats>(
        success: false,
        message: 'Network error: $e',
      );
    }
  }
}
