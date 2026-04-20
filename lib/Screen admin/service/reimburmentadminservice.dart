import 'dart:convert';
import 'package:absensikaryawan/Screen%20admin/model/reimbursementadminmodel.dart';
import 'package:http/http.dart' as http;
import 'package:absensikaryawan/Services/config.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdminReimbursementService {
  String _currentUserId = '';

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getString('UserID') ?? '';
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

  // ✅ SIMPLE SOLUTION: Setelah stored procedure diperbaiki
  Future<List<AdminReimbursementData>> getAllReimbursementsAdmin({
    required String currentUserId, // Untuk verifikasi admin
    String? status,
    DateTime? startDate,
    DateTime? endDate,
    String? searchKeyword,
  }) async {
    try {
      final headers = await _getHeaders();
      Map<String, dynamic> requestBody = {
        'userId': currentUserId, // Untuk verifikasi admin di SP
      };
      if (status != null && status.isNotEmpty) {
        requestBody['status'] = status;
      }
      if (startDate != null) {
        requestBody['startDate'] = startDate.toIso8601String();
      }
      if (endDate != null) {
        requestBody['endDate'] = endDate.toIso8601String();
      }
      if (searchKeyword != null && searchKeyword.isNotEmpty) {
        requestBody['searchKeyword'] = searchKeyword;
      }

      final url = '$baseURL/api/asn/reimbursement/admin/list-enhanced';

      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);

        if (jsonData['success'] == true) {
          final List<dynamic> dataList = jsonData['data'] ?? [];

          if (dataList.isNotEmpty) {}

          final result = dataList
              .map((item) => AdminReimbursementData.fromJson(item))
              .toList();

          return result;
        } else {
          // Handle case ketika user bukan admin
          if (jsonData['message']?.toString().toLowerCase().contains('admin') ==
                  true ||
              jsonData['message']?.toString().toLowerCase().contains('akses') ==
                  true) {
            throw Exception(
              'Akses ditolak. User $_currentUserId bukan admin atau tidak memiliki izin.',
            );
          }

          // Jika tidak ada data, return empty list
          return [];
        }
      } else {
        try {
          final errorData = json.decode(response.body);
          throw Exception(
            errorData['message'] ?? 'HTTP Error ${response.statusCode}',
          );
        } catch (e) {
          throw Exception(
            'HTTP Error ${response.statusCode}: ${response.body}',
          );
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  // Review reimbursement (approve/reject) - TIDAK BERUBAH
  Future<AdminResponse> reviewReimbursement({
    required int id,
    required String status,
    required String reviewedBy,
    String? reviewNotes,
  }) async {
    try {
      final headers = await _getHeaders();
      final request = AdminReimbursementReviewRequest(
        id: id,
        status: status,
        reviewedBy: reviewedBy,
        reviewNotes: reviewNotes,
      );

      final response = await http.post(
        Uri.parse('$baseURL/api/asn/reimbursement/admin/review'),
        headers: headers,
        body: json.encode(request.toJson()),
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return AdminResponse.fromJson(jsonData);
      } else {
        final errorData = json.decode(response.body);
        return AdminResponse(
          success: false,
          message: errorData['message'] ?? 'Terjadi kesalahan server',
        );
      }
    } catch (e) {
      return AdminResponse(
        success: false,
        message: 'Terjadi kesalahan jaringan: $e',
      );
    }
  }

  // Mark reimbursement as paid - TIDAK BERUBAH
  Future<AdminResponse> markReimbursementPaid({
    required int id,
    required String paidBy,
  }) async {
    try {
      final headers = await _getHeaders();
      final request = AdminMarkPaidRequest(id: id, paidBy: paidBy);

      final response = await http.post(
        Uri.parse('$baseURL/api/asn/reimbursement/admin/mark-paid'),
        headers: headers,
        body: json.encode(request.toJson()),
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return AdminResponse.fromJson(jsonData);
      } else {
        final errorData = json.decode(response.body);
        return AdminResponse(
          success: false,
          message: errorData['message'] ?? 'Terjadi kesalahan server',
        );
      }
    } catch (e) {
      return AdminResponse(
        success: false,
        message: 'Terjadi kesalahan jaringan: $e',
      );
    }
  }

  // Get admin statistics dengan current date sebagai default
  Future<AdminReimbursementStatistics?> getAdminStatistics({
    int? year,
    int? month,
  }) async {
    try {
      // Gunakan tahun dan bulan saat ini jika tidak disediakan
      // final now = DateTime.now();
      // final finalYear = year ?? now.year;
      // final finalMonth = month ?? now.month;

      final headers = await _getHeaders();
      Map requestBody = {};

      // Hanya kirim parameter jika disediakan
      if (year != null) {
        requestBody['year'] = year;
      }
      if (month != null) {
        requestBody['month'] = month;
      }

      // // Selalu kirim year dan month
      // Map<String, dynamic> requestBody = {
      //   'year': finalYear,
      //   'month': finalMonth,
      // };

      final response = await http.post(
        Uri.parse('$baseURL/api/asn/reimbursement/admin/statistics'),
        headers: headers,
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData['success'] == true) {
          return AdminReimbursementStatistics.fromJson(jsonData['data']);
        } else {
          throw Exception(jsonData['message'] ?? 'Gagal mengambil statistik');
        }
      } else {
        try {
          final errorData = json.decode(response.body);
          throw Exception(
            errorData['message'] ?? 'HTTP Error ${response.statusCode}',
          );
        } catch (e) {
          throw Exception(
            'HTTP Error ${response.statusCode}: ${response.body}',
          );
        }
      }
    } catch (e) {
      // Return default statistics
      return AdminReimbursementStatistics(
        totalSubmissions: 0,
        pendingCount: 0,
        approvedCount: 0,
        rejectedCount: 0,
        paidCount: 0,
        totalApprovedAmount: 0.0,
        totalPaidAmount: 0.0,
        totalPendingAmount: 0.0,
        formattedTotalApproved: 'Rp0',
        formattedTotalPaid: 'Rp0',
        formattedTotalPending: 'Rp0',
      );
    }
  }

  // Get users with reimbursements - TIDAK BERUBAH
  Future<List<UserWithReimbursements>> getUsersWithReimbursements() async {
    try {
      final headers = await _getHeaders();

      final response = await http.get(
        Uri.parse('$baseURL/api/asn/reimbursement/admin/users'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData['success'] == true) {
          final List<dynamic> dataList = jsonData['data'] ?? [];
          return dataList
              .map((item) => UserWithReimbursements.fromJson(item))
              .toList();
        } else {
          throw Exception(jsonData['message'] ?? 'Gagal mengambil data users');
        }
      } else {
        try {
          final errorData = json.decode(response.body);
          throw Exception(
            errorData['message'] ?? 'HTTP Error ${response.statusCode}',
          );
        } catch (e) {
          throw Exception(
            'HTTP Error ${response.statusCode}: ${response.body}',
          );
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  // Get receipt image URL for admin
  String getAdminReceiptImageUrl(int reimbursementId) {
    final url =
        '$baseURL/api/asn/reimbursement/admin/receipt/view/$reimbursementId';
    return url;
  }

  // Get admin headers
  Future<Map<String, String>> getAdminHeaders() async {
    return await _getHeaders();
  }
}
