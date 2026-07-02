import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:absensikaryawan/Services/config.dart';

class AttendanceOutsideRadiusService {
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
        return json.decode(response.body)['access_token'];
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Submit absensi luar radius -> masuk antrian approval Head HRD
  static Future<Map<String, dynamic>> submit({
    required String userId,
    required String attendanceType, // checkin / checkout
    required double latitude,
    required double longitude,
    double? distanceFromOffice,
    int? nearestOfficeId,
    required String faceImageBase64,
    double? detScore,
    double? livenessScore,
    double? bestDistance,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'Gagal mendapatkan token akses'};
      }

      final requestBody = {
        'UserId': userId.trim(),
        'AttendanceType': attendanceType.trim().toLowerCase(),
        'Latitude': latitude,
        'Longitude': longitude,
        'DistanceFromOffice': distanceFromOffice,
        'NearestOfficeId': nearestOfficeId,
        'FaceImageBase64': faceImageBase64.trim(),
        'DetScore': detScore,
        'LivenessScore': livenessScore,
        'BestDistance': bestDistance,
      };

      final response = await http
          .post(
            Uri.parse('$baseURL/api/asn/attendance/outside-radius/submit'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode(requestBody),
          )
          .timeout(const Duration(seconds: 45));

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': responseData['success'] ?? false,
          'message': responseData['message'] ?? 'Pengajuan berhasil dikirim',
          'request_id': responseData['requestId'],
        };
      } else {
        return {
          'success': false,
          'message': responseData['message'] ?? 'Gagal mengirim pengajuan',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Terjadi kesalahan koneksi: ${e.toString()}',
      };
    }
  }

  /// List antrian approval (untuk Head HRD, atau riwayat pengajuan karyawan)
  static Future<Map<String, dynamic>> getList({
    String? status,
    String? userId,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Gagal mendapatkan token akses',
          'data': [],
        };
      }

      final response = await http
          .post(
            Uri.parse('$baseURL/api/asn/attendance/outside-radius/list'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode({'Status': status, 'UserId': userId}),
          )
          .timeout(const Duration(seconds: 20));

      final responseData = json.decode(response.body);

      return {
        'success': responseData['success'] ?? false,
        'data': responseData['data'] ?? [],
        'message': responseData['message'] ?? '',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Terjadi kesalahan koneksi: ${e.toString()}',
        'data': [],
      };
    }
  }

  static Future<Map<String, dynamic>> approve({
    required int id,
    required String reviewedBy,
    String? reviewNotes,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'Gagal mendapatkan token akses'};
      }

      final response = await http
          .post(
            Uri.parse('$baseURL/api/asn/attendance/outside-radius/approve'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode({
              'Id': id,
              'ReviewedBy': reviewedBy,
              'ReviewNotes': reviewNotes,
            }),
          )
          .timeout(const Duration(seconds: 30));

      final responseData = json.decode(response.body);
      return {
        'success': responseData['success'] ?? false,
        'message': responseData['message'] ?? '',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Terjadi kesalahan koneksi: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> reject({
    required int id,
    required String reviewedBy,
    String? reviewNotes,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'Gagal mendapatkan token akses'};
      }

      final response = await http
          .post(
            Uri.parse('$baseURL/api/asn/attendance/outside-radius/reject'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode({
              'Id': id,
              'ReviewedBy': reviewedBy,
              'ReviewNotes': reviewNotes,
            }),
          )
          .timeout(const Duration(seconds: 30));

      final responseData = json.decode(response.body);
      return {
        'success': responseData['success'] ?? false,
        'message': responseData['message'] ?? '',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Terjadi kesalahan koneksi: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> isHeadHrd(String userId) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'isHeadHrd': false};

      final response = await http
          .post(
            Uri.parse('$baseURL/api/asn/attendance/outside-radius/is-head-hrd'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode({'UserId': userId}),
          )
          .timeout(const Duration(seconds: 15));

      final responseData = json.decode(response.body);
      return {
        'success': responseData['success'] ?? false,
        'isHeadHrd': responseData['isHeadHrd'] ?? false,
      };
    } catch (_) {
      return {'success': false, 'isHeadHrd': false};
    }
  }
}
