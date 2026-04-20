import 'dart:convert';
import 'package:absensikaryawan/Services/config.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// Models (keep existing models)
class Overtime {
  final int id;
  final String userId;
  final String userName;
  final DateTime tanggalOvertime;
  final Duration jamMulai;
  final Duration jamSelesai;
  final double totalJam;
  final String? catatan;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? approvedBy;
  final String? approverName;
  final DateTime? approvedAt;
  final String? rejectionReason;

  Overtime({
    required this.id,
    required this.userId,
    required this.userName,
    required this.tanggalOvertime,
    required this.jamMulai,
    required this.jamSelesai,
    required this.totalJam,
    this.catatan,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.approvedBy,
    this.approverName,
    this.approvedAt,
    this.rejectionReason,
  });

  // Check if overtime can be edited/deleted (only pending status)
  bool get canBeModified => status.toLowerCase() == 'pending';

  factory Overtime.fromJson(Map<String, dynamic> json) {
    return Overtime(
      id: json['Id'] as int,
      userId: json['UserId'] as String,
      userName: json['UserName'] as String,
      tanggalOvertime: DateTime.parse(json['TanggalOvertime']),
      jamMulai: _parseDuration(json['JamMulai']),
      jamSelesai: _parseDuration(json['JamSelesai']),
      totalJam: (json['TotalJam'] as num).toDouble(),
      catatan: json['Catatan'] as String?,
      status: json['Status'] as String,
      createdAt: DateTime.parse(json['CreatedAt']),
      updatedAt: DateTime.parse(json['UpdatedAt']),
      approvedBy: json['ApprovedBy'] as String?,
      approverName: json['ApproverName'] as String?,
      approvedAt: json['ApprovedAt'] != null
          ? DateTime.parse(json['ApprovedAt'])
          : null,
      rejectionReason: json['RejectionReason'] as String?,
    );
  }

  static Duration _parseDuration(String timeString) {
    final parts = timeString.split(':');
    return Duration(
      hours: int.parse(parts[0]),
      minutes: int.parse(parts[1]),
      seconds: parts.length > 2 ? int.parse(parts[2]) : 0,
    );
  }

  String get formattedDate =>
      "${tanggalOvertime.year}-${tanggalOvertime.month.toString().padLeft(2, '0')}-${tanggalOvertime.day.toString().padLeft(2, '0')}";
  String get formattedMulai =>
      "${jamMulai.inHours.toString().padLeft(2, '0')}:${(jamMulai.inMinutes % 60).toString().padLeft(2, '0')}";
  String get formattedSelesai =>
      "${jamSelesai.inHours.toString().padLeft(2, '0')}:${(jamSelesai.inMinutes % 60).toString().padLeft(2, '0')}";
}

class OvertimeListResponse {
  final List<Overtime> data;
  final int totalCount;
  final int page;
  final int pageSize;
  final int totalPages;

  OvertimeListResponse({
    required this.data,
    required this.totalCount,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  factory OvertimeListResponse.fromJson(Map<String, dynamic> json) {
    return OvertimeListResponse(
      data: (json['Data'] as List)
          .map((item) => Overtime.fromJson(item))
          .toList(),
      totalCount: json['TotalCount'] as int,
      page: json['Page'] as int,
      pageSize: json['PageSize'] as int,
      totalPages: json['TotalPages'] as int,
    );
  }
}

class OvertimeSummary {
  final int totalPengajuan;
  final int pending;
  final int approved;
  final int rejected;
  final double totalJamDisetujui;
  final double rataRataJam;

  OvertimeSummary({
    required this.totalPengajuan,
    required this.pending,
    required this.approved,
    required this.rejected,
    required this.totalJamDisetujui,
    required this.rataRataJam,
  });

  factory OvertimeSummary.fromJson(Map<String, dynamic> json) {
    return OvertimeSummary(
      totalPengajuan: json['totalPengajuan'] as int,
      pending: json['pending'] as int,
      approved: json['approved'] as int,
      rejected: json['rejected'] as int,
      totalJamDisetujui: (json['totalJamDisetujui'] as num).toDouble(),
      rataRataJam: (json['rataRataJam'] as num).toDouble(),
    );
  }
}

class OvertimeRequest {
  final String userId;
  final DateTime tanggalOvertime;
  final Duration jamMulai;
  final Duration jamSelesai;
  final double totalJam;
  final String? catatan;

  OvertimeRequest({
    required this.userId,
    required this.tanggalOvertime,
    required this.jamMulai,
    required this.jamSelesai,
    required this.totalJam,
    this.catatan,
  });

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'tanggalOvertime': tanggalOvertime.toIso8601String(),
      'jamMulai': _formatDuration(jamMulai),
      'jamSelesai': _formatDuration(jamSelesai),
      'totalJam': totalJam,
      'catatan': catatan,
    };
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return "$hours:$minutes:$seconds";
  }
}

class ApiResponse<T> {
  final bool success;
  final String message;
  final T? data;
  final int? errorCode;

  ApiResponse({
    required this.success,
    required this.message,
    this.data,
    this.errorCode,
  });

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic)? fromJsonT,
  ) {
    return ApiResponse<T>(
      success: json['Success'] as bool,
      message: json['Message'] as String,
      data: json['Data'] != null && fromJsonT != null
          ? fromJsonT(json['Data'])
          : json['Data'],
      errorCode: json['ErrorCode'] as int?,
    );
  }
}

// Service
class OvertimeService {
  static const String _baseUrl = '$baseURL/api/overtime';

  Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
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

  Future<String?> _getUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('UserID');
    } catch (e) {
      return null;
    }
  }

  Future<ApiResponse<int>> submitOvertime(OvertimeRequest request) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/submit'),
        headers: await _getHeaders(),
        body: jsonEncode(request.toJson()),
      );

      final jsonResponse = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return ApiResponse<int>.fromJson(jsonResponse, (data) => data as int);
      } else {
        return ApiResponse<int>(
          success: false,
          message: jsonResponse['message'] ?? 'Terjadi kesalahan',
          errorCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse<int>(
        success: false,
        message: 'Kesalahan jaringan: $e',
      );
    }
  }

  Future<ApiResponse<OvertimeListResponse>> getMyOvertime({
    int page = 1,
    int pageSize = 10,
  }) async {
    try {
      final userId = await _getUserId();
      if (userId == null) {
        return ApiResponse<OvertimeListResponse>(
          success: false,
          message: 'User ID tidak ditemukan. Silakan login ulang.',
        );
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/my-overtime'),
        headers: await _getHeaders(),
        body: jsonEncode({'userId': userId}),
      );

      final jsonResponse = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return ApiResponse<OvertimeListResponse>.fromJson(
          jsonResponse,
          (data) => OvertimeListResponse.fromJson(data),
        );
      } else {
        return ApiResponse<OvertimeListResponse>(
          success: false,
          message: jsonResponse['Message'] ?? 'Terjadi kesalahan',
          errorCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse<OvertimeListResponse>(
        success: false,
        message: 'Kesalahan jaringan: $e',
      );
    }
  }

  // UPDATED: Edit overtime - send userId in body
  Future<ApiResponse<void>> updateOvertime({
    required int id,
    required OvertimeRequest request,
  }) async {
    try {
      final userId = await _getUserId();
      if (userId == null) {
        return ApiResponse<void>(
          success: false,
          message: 'User ID tidak ditemukan. Silakan login ulang.',
        );
      }

      final body = request.toJson();
      body['id'] = id;
      body['userId'] = userId; // Ensure userId is sent

      final response = await http.post(
        Uri.parse('$_baseUrl/update'),
        headers: await _getHeaders(),
        body: jsonEncode(body),
      );

      final jsonResponse = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return ApiResponse<void>.fromJson(jsonResponse, null);
      } else {
        return ApiResponse<void>(
          success: false,
          message: jsonResponse['message'] ?? 'Terjadi kesalahan',
          errorCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse<void>(
        success: false,
        message: 'Kesalahan jaringan: $e',
      );
    }
  }

  // UPDATED: Delete overtime - send userId in body
  Future<ApiResponse<void>> deleteOvertime(int id) async {
    try {
      final userId = await _getUserId();
      if (userId == null) {
        return ApiResponse<void>(
          success: false,
          message: 'User ID tidak ditemukan. Silakan login ulang.',
        );
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/delete'),
        headers: await _getHeaders(),
        body: jsonEncode({'id': id, 'userId': userId}),
      );

      final jsonResponse = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return ApiResponse<void>.fromJson(jsonResponse, null);
      } else {
        return ApiResponse<void>(
          success: false,
          message: jsonResponse['message'] ?? 'Terjadi kesalahan',
          errorCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse<void>(
        success: false,
        message: 'Kesalahan jaringan: $e',
      );
    }
  }

  Future<ApiResponse<void>> approveOvertime({
    required int id,
    required String status,
    String? rejectionReason,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/approve'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'id': id,
          'status': status,
          'rejectionReason': rejectionReason,
        }),
      );

      final jsonResponse = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return ApiResponse<void>.fromJson(jsonResponse, null);
      } else {
        return ApiResponse<void>(
          success: false,
          message: jsonResponse['message'] ?? 'Terjadi kesalahan',
          errorCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse<void>(
        success: false,
        message: 'Kesalahan jaringan: $e',
      );
    }
  }

  Future<ApiResponse<OvertimeListResponse>> getAllOvertime({
    String? status,
    int page = 1,
    int pageSize = 10,
  }) async {
    try {
      String url = '$_baseUrl/all?page=$page&pageSize=$pageSize';
      if (status != null) {
        url += '&status=$status';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: await _getHeaders(),
      );

      final jsonResponse = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return ApiResponse<OvertimeListResponse>.fromJson(
          jsonResponse,
          (data) => OvertimeListResponse.fromJson(data),
        );
      } else {
        return ApiResponse<OvertimeListResponse>(
          success: false,
          message: jsonResponse['message'] ?? 'Terjadi kesalahan',
          errorCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse<OvertimeListResponse>(
        success: false,
        message: 'Kesalahan jaringan: $e',
      );
    }
  }

  Future<ApiResponse<OvertimeSummary>> getOvertimeSummary({
    int? year,
    int? month,
    String? userId,
  }) async {
    try {
      String url = '$_baseUrl/summary?';
      List<String> params = [];

      if (year != null) params.add('year=$year');
      if (month != null) params.add('month=$month');
      if (userId != null) params.add('userId=$userId');

      url += params.join('&');

      final response = await http.get(
        Uri.parse(url),
        headers: await _getHeaders(),
      );

      final jsonResponse = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return ApiResponse<OvertimeSummary>.fromJson(
          jsonResponse,
          (data) => OvertimeSummary.fromJson(data),
        );
      } else {
        return ApiResponse<OvertimeSummary>(
          success: false,
          message: jsonResponse['message'] ?? 'Terjadi kesalahan',
          errorCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse<OvertimeSummary>(
        success: false,
        message: 'Kesalahan jaringan: $e',
      );
    }
  }

  Future<ApiResponse<Overtime>> getOvertimeById(int id) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/$id'),
        headers: await _getHeaders(),
      );

      final jsonResponse = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return ApiResponse<Overtime>.fromJson(
          jsonResponse,
          (data) => Overtime.fromJson(data),
        );
      } else {
        return ApiResponse<Overtime>(
          success: false,
          message: jsonResponse['message'] ?? 'Terjadi kesalahan',
          errorCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse<Overtime>(
        success: false,
        message: 'Kesalahan jaringan: $e',
      );
    }
  }
}
