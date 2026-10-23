import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:absensikaryawan/Services/config.dart';
import 'package:absensikaryawan/Services/token_service.dart';

class DinasLuarService {
  // Endpoint dinas memverifikasi UserId terhadap klaim JWT. Token aplikasi
  // umum hanya memiliki klaim sistem sehingga selalu berujung 401.
  static Future<String?> _token() => TokenService.getToken();

  // Karyawan submit absen dinas luar (hanya wajah + lokasi, belum butuh bukti)
  static Future<Map<String, dynamic>> submit({
    required String userId,
    required String attendanceType,
    required double latitude,
    required double longitude,
    required String faceImageBase64,
    String? notes,
  }) async {
    try {
      final token = await _token();
      if (token == null) return {'success': false, 'message': 'Token gagal'};

      final r = await http
          .post(
            Uri.parse('$baseURL/api/asn/dinas-luar/submit'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode({
              'UserId': userId.trim(),
              'AttendanceType': attendanceType,
              'Latitude': latitude,
              'Longitude': longitude,
              'FaceImageBase64': faceImageBase64,
              'Notes': notes,
            }),
          )
          .timeout(const Duration(seconds: 45));

      final d = json.decode(r.body);
      return {
        'success': d['success'] ?? false,
        'message': d['message'] ?? '',
        'request_id': d['request_id'],
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // Karyawan upload bukti setelah approved
  static Future<Map<String, dynamic>> uploadProof({
    required int requestId,
    required String userId,
    required String proofType,
    required String proofData,
    String? proofFilename,
    String? proofMimeType,
  }) async {
    try {
      final token = await _token();
      if (token == null) return {'success': false, 'message': 'Token gagal'};

      final r = await http
          .post(
            Uri.parse('$baseURL/api/asn/dinas-luar/upload-proof'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode({
              'RequestId': requestId,
              'UserId': userId.trim(),
              'ProofType': proofType,
              'ProofData': proofData,
              'ProofFilename': proofFilename,
              'ProofMimeType': proofMimeType,
            }),
          )
          .timeout(const Duration(seconds: 60));

      final d = json.decode(r.body);
      return {'success': d['success'] ?? false, 'message': d['message'] ?? ''};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // Cek status request hari ini
  static Future<List<dynamic>> myStatus({
    required String userId,
    String? date,
  }) async {
    try {
      final token = await _token();
      if (token == null) return [];

      final r = await http
          .post(
            Uri.parse('$baseURL/api/asn/dinas-luar/my-status'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode({'UserId': userId, 'AttendanceDate': date}),
          )
          .timeout(const Duration(seconds: 15));

      final d = json.decode(r.body);
      return d['data'] ?? [];
    } catch (_) {
      return [];
    }
  }
}
