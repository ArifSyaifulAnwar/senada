import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:absensikaryawan/Services/config.dart';

class CompanyInviteInfo {
  final String companyName;
  final String inviteCode;
  const CompanyInviteInfo({required this.companyName, required this.inviteCode});
}

class CompanyService {
  static Future<String?> _getToken() async {
    try {
      final r = await http
          .post(
            Uri.parse('$baseURL/api/auth/token'),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: {'grant_type': 'password', 'password': 'ASN_DBS'},
          )
          .timeout(const Duration(seconds: 15));
      if (r.statusCode == 200) return json.decode(r.body)['access_token'];
    } catch (_) {}
    return null;
  }

  static dynamic _get(Map<String, dynamic> j, String k) =>
      j[k[0].toUpperCase() + k.substring(1)] ?? j[k];

  /// Kode undangan perusahaan milik [userId] sendiri — dipakai untuk
  /// membagikan ke calon rekan kerja baru supaya mereka bergabung ke
  /// perusahaan yang sama saat registrasi.
  static Future<CompanyInviteInfo?> getInviteCode(String userId) async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final r = await http
          .post(
            Uri.parse('$baseURL/api/asn/company/invite-code'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: json.encode({'UserId': userId}),
          )
          .timeout(const Duration(seconds: 15));

      if (r.statusCode == 200) {
        final body = json.decode(r.body);
        if (_get(body, 'success') == true) {
          final companyName = _get(body, 'companyName')?.toString();
          final inviteCode = _get(body, 'inviteCode')?.toString();
          if (companyName != null && inviteCode != null) {
            return CompanyInviteInfo(
              companyName: companyName,
              inviteCode: inviteCode,
            );
          }
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
