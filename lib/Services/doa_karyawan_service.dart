// Services/doa_karyawan_service.dart

import 'dart:convert';
import 'package:absensikaryawan/Services/config.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class DoaKaryawanItem {
  final String userId;
  final String name;
  final String? mail;
  final String? employeeId;
  final String? organization;
  final String? jobPosition;

  DoaKaryawanItem({
    required this.userId,
    required this.name,
    this.mail,
    this.employeeId,
    this.organization,
    this.jobPosition,
  });

  factory DoaKaryawanItem.fromJson(Map<String, dynamic> json) {
    return DoaKaryawanItem(
      userId:
          json['userId'] ??
          json['UserId'] ??
          json['userid'] ??
          json['Userid'] ??
          '',
      name: json['name'] ?? json['Name'] ?? '',
      mail: json['mail'] ?? json['Mail'],
      employeeId:
          json['employeeID'] ??
          json['EmployeeID'] ??
          json['employeeId'] ??
          json['EmployeeId'],
      organization: json['organization'] ?? json['Organization'],
      jobPosition:
          json['job_position'] ??
          json['jobPosition'] ??
          json['JobPosition'] ??
          json['Job_Position'],
    );
  }
}

class DoaKaryawanResponse {
  final bool success;
  final String message;
  final List<DoaKaryawanItem> data;

  DoaKaryawanResponse({
    required this.success,
    required this.message,
    required this.data,
  });
}

class DoaKaryawanService {
  static const String _baseUrl = '$baseURL/api/employee';

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
        final data = jsonDecode(res.body);
        return data['access_token'];
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static Future<String?> _getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('UserID');
  }

  static Future<DoaKaryawanResponse> getKaryawanDropdown({
    String? search,
  }) async {
    try {
      final hrdUserId = await _getUserId();

      if (hrdUserId == null || hrdUserId.isEmpty) {
        return DoaKaryawanResponse(
          success: false,
          message: 'UserID HRD tidak ditemukan. Silakan login ulang.',
          data: [],
        );
      }

      final body = {'HrdUserId': hrdUserId, 'Search': search ?? ''};

      final res = await http
          .post(
            Uri.parse('$_baseUrl/list-karyawan'),
            headers: await _getHeaders(),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));

      final json = jsonDecode(res.body);

      if (res.statusCode == 200) {
        final success = json['success'] == true || json['Success'] == true;
        final message = json['message'] ?? json['Message'] ?? '';

        final rawData = json['data'] ?? json['Data'];

        final list = (rawData as List? ?? [])
            .map((e) => DoaKaryawanItem.fromJson(e as Map<String, dynamic>))
            .where((e) => e.userId.isNotEmpty && e.name.isNotEmpty)
            .toList();

        return DoaKaryawanResponse(
          success: success,
          message: message,
          data: list,
        );
      }

      return DoaKaryawanResponse(
        success: false,
        message:
            'HTTP ${res.statusCode}: ${json['message'] ?? json['Message'] ?? 'Gagal mengambil data'}',
        data: [],
      );
    } catch (e) {
      return DoaKaryawanResponse(
        success: false,
        message: 'Terjadi kesalahan: $e',
        data: [],
      );
    }
  }
}
