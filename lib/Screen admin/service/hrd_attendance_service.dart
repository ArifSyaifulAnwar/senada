// File: Services/hrd_attendance_service.dart
// ignore_for_file: library_private_types_in_public_api, avoid_print

import 'dart:convert';
import 'package:absensikaryawan/Services/config.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ── Models ────────────────────────────────────────────────────────────────────

class HrdAttendanceData {
  final int id;
  final String userId;
  final String userName;
  final String? employeeId;
  final String? department;
  final String? attendanceDate;
  final String? checkInTime;
  final String? checkOutTime;
  final double? checkInLatitude;
  final double? checkInLongitude;
  final double? checkOutLatitude;
  final double? checkOutLongitude;
  final int? checkInOfficeId;
  final int? checkOutOfficeId;
  final String? checkInStatus;
  final String? checkOutStatus;
  final double? checkInFaceConfidence;
  final double? checkOutFaceConfidence;
  final int? workingHoursMinutes;
  final int? overtimeMinutes;
  final String? notes;
  final String? attendanceMode;
  final String? createdAt;
  final String? updatedAt;

  HrdAttendanceData({
    required this.id,
    required this.userId,
    required this.userName,
    this.employeeId,
    this.department,
    this.attendanceDate,
    this.checkInTime,
    this.checkOutTime,
    this.checkInLatitude,
    this.checkInLongitude,
    this.checkOutLatitude,
    this.checkOutLongitude,
    this.checkInOfficeId,
    this.checkOutOfficeId,
    this.checkInStatus,
    this.checkOutStatus,
    this.checkInFaceConfidence,
    this.checkOutFaceConfidence,
    this.workingHoursMinutes,
    this.overtimeMinutes,
    this.notes,
    this.attendanceMode,
    this.createdAt,
    this.updatedAt,
  });

  factory HrdAttendanceData.fromJson(
    Map<String, dynamic> j,
  ) => HrdAttendanceData(
    id: j['Id'] ?? j['id'] ?? 0,
    userId: j['UserId'] ?? j['user_id'] ?? '',
    userName: j['UserName'] ?? j['user_name'] ?? '',
    employeeId: j['EmployeeId'] ?? j['employee_id'],
    department: j['Department'] ?? j['department'],
    attendanceDate: j['AttendanceDate'] ?? j['attendance_date'],
    checkInTime: j['CheckInTime'] ?? j['check_in_time'],
    checkOutTime: j['CheckOutTime'] ?? j['check_out_time'],
    checkInLatitude: _toDouble(j['CheckInLatitude'] ?? j['check_in_latitude']),
    checkInLongitude: _toDouble(
      j['CheckInLongitude'] ?? j['check_in_longitude'],
    ),
    checkOutLatitude: _toDouble(
      j['CheckOutLatitude'] ?? j['check_out_latitude'],
    ),
    checkOutLongitude: _toDouble(
      j['CheckOutLongitude'] ?? j['check_out_longitude'],
    ),
    checkInOfficeId: _toInt(j['CheckInOfficeId'] ?? j['check_in_office_id']),
    checkOutOfficeId: _toInt(j['CheckOutOfficeId'] ?? j['check_out_office_id']),
    checkInStatus: j['CheckInStatus'] ?? j['check_in_status'],
    checkOutStatus: j['CheckOutStatus'] ?? j['check_out_status'],
    checkInFaceConfidence: _toDouble(
      j['CheckInFaceConfidence'] ?? j['check_in_face_confidence'],
    ),
    checkOutFaceConfidence: _toDouble(
      j['CheckOutFaceConfidence'] ?? j['check_out_face_confidence'],
    ),
    workingHoursMinutes: _toInt(
      j['WorkingHoursMinutes'] ?? j['working_hours_minutes'],
    ),
    overtimeMinutes: _toInt(j['OvertimeMinutes'] ?? j['overtime_minutes']),
    notes: j['Notes'] ?? j['notes'],
    attendanceMode: j['AttendanceMode'] ?? j['attendance_mode'],
    createdAt: j['CreatedAt'] ?? j['created_at'],
    updatedAt: j['UpdatedAt'] ?? j['updated_at'],
  );

  // Display helpers
  String get displayStatus {
    final s = (checkInStatus ?? '').toLowerCase();
    if (s.contains('tepat')) return 'Tepat Waktu';
    if (s.contains('terlambat')) return 'Terlambat';
    if (s.contains('cuti')) return 'Cuti';
    if (s.contains('absent') || s.contains('tidak hadir')) return 'Tidak Hadir';
    return checkInStatus ?? '-';
  }

  String get formattedCheckIn => _formatTime(checkInTime);
  String get formattedCheckOut => _formatTime(checkOutTime);
  String get formattedDate => _formatDate(attendanceDate);

  static String _formatTime(String? dt) {
    if (dt == null) return '-';
    try {
      return DateTime.parse(dt).toLocal().toString().substring(11, 16);
    } catch (_) {
      return '-';
    }
  }

  static String _formatDate(String? dt) {
    if (dt == null) return '-';
    try {
      final d = DateTime.parse(dt);
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'Mei',
        'Jun',
        'Jul',
        'Agu',
        'Sep',
        'Okt',
        'Nov',
        'Des',
      ];
      return '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}';
    } catch (_) {
      return dt;
    }
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString());
  }
}

class HrdAttendanceListResponse {
  final List<HrdAttendanceData> data;
  final int totalCount;
  final int totalPages;
  final int currentPage;
  final int pageSize;

  HrdAttendanceListResponse({
    required this.data,
    required this.totalCount,
    required this.totalPages,
    required this.currentPage,
    required this.pageSize,
  });

  factory HrdAttendanceListResponse.fromJson(Map<String, dynamic> j) {
    final list = (j['Data'] as List? ?? [])
        .map((e) => HrdAttendanceData.fromJson(e as Map<String, dynamic>))
        .toList();
    return HrdAttendanceListResponse(
      data: list,
      totalCount: j['TotalCount'] ?? 0,
      totalPages: j['TotalPages'] ?? 1,
      currentPage: j['CurrentPage'] ?? 1,
      pageSize: j['PageSize'] ?? 50,
    );
  }
}

class HrdAttendanceEditLog {
  final int id;
  final int attendanceId;
  final String employeeName;
  final String? employeeId;
  final String attendanceDate;
  final String editedByName;
  final String editReason;
  final String? oldCheckInTime;
  final String? oldCheckOutTime;
  final String? oldCheckInStatus;
  final String? oldCheckOutStatus;
  final String? newCheckInTime;
  final String? newCheckOutTime;
  final String? newCheckInStatus;
  final String? newCheckOutStatus;
  final String editedAt;

  HrdAttendanceEditLog({
    required this.id,
    required this.attendanceId,
    required this.employeeName,
    this.employeeId,
    required this.attendanceDate,
    required this.editedByName,
    required this.editReason,
    this.oldCheckInTime,
    this.oldCheckOutTime,
    this.oldCheckInStatus,
    this.oldCheckOutStatus,
    this.newCheckInTime,
    this.newCheckOutTime,
    this.newCheckInStatus,
    this.newCheckOutStatus,
    required this.editedAt,
  });

  factory HrdAttendanceEditLog.fromJson(Map<String, dynamic> j) =>
      HrdAttendanceEditLog(
        id: j['Id'] ?? 0,
        attendanceId: j['AttendanceId'] ?? 0,
        employeeName: j['EmployeeName'] ?? '',
        employeeId: j['EmployeeId'],
        attendanceDate: j['AttendanceDate'] ?? '',
        editedByName: j['EditedByName'] ?? '',
        editReason: j['EditReason'] ?? '',
        oldCheckInTime: j['OldCheckInTime'],
        oldCheckOutTime: j['OldCheckOutTime'],
        oldCheckInStatus: j['OldCheckInStatus'],
        oldCheckOutStatus: j['OldCheckOutStatus'],
        newCheckInTime: j['NewCheckInTime'],
        newCheckOutTime: j['NewCheckOutTime'],
        newCheckInStatus: j['NewCheckInStatus'],
        newCheckOutStatus: j['NewCheckOutStatus'],
        editedAt: j['EditedAt'] ?? '',
      );
}

// ── Service ───────────────────────────────────────────────────────────────────

class HrdAttendanceService {
  static const String _baseUrl = '$baseURL/api/hrd/attendance';

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
        final d = json.decode(res.body);
        return d['access_token'];
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

  // ── List ──────────────────────────────────────────────────────────────────

  static Future<_ApiResult<HrdAttendanceListResponse>> getList({
    String? filterUserId,
    String? startDate,
    String? endDate,
    String? statusFilter,
    String? searchTerm,
    int page = 1,
    int pageSize = 50,
  }) async {
    try {
      final hrdUserId = await _getUserId();
      if (hrdUserId == null) {
        return _ApiResult(success: false, message: 'UserID tidak ditemukan.');
      }

      final body = {
        'HrdUserId': hrdUserId,
        'FilterUserId': filterUserId,
        'StartDate': startDate,
        'EndDate': endDate,
        'StatusFilter': statusFilter,
        'SearchTerm': searchTerm,
        'Page': page,
        'PageSize': pageSize,
      };

      final res = await http
          .post(
            Uri.parse('$_baseUrl/list'),
            headers: await _getHeaders(),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));

      if (res.statusCode == 200) {
        final j = jsonDecode(res.body);
        if (j['success'] == true && j['data'] != null) {
          return _ApiResult(
            success: true,
            message: j['message'] ?? '',
            data: HrdAttendanceListResponse.fromJson(j['data']),
          );
        }
        return _ApiResult(success: false, message: j['message'] ?? 'Gagal');
      }
      return _ApiResult(success: false, message: 'HTTP ${res.statusCode}');
    } catch (e) {
      return _ApiResult(success: false, message: 'Network error: $e');
    }
  }

  // ── Detail ────────────────────────────────────────────────────────────────

  static Future<_ApiResult<HrdAttendanceData>> getDetail(
    int attendanceId,
  ) async {
    try {
      final hrdUserId = await _getUserId();
      if (hrdUserId == null) {
        return _ApiResult(success: false, message: 'UserID tidak ditemukan.');
      }

      final res = await http
          .post(
            Uri.parse('$_baseUrl/detail'),
            headers: await _getHeaders(),
            body: jsonEncode({
              'HrdUserId': hrdUserId,
              'AttendanceId': attendanceId,
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (res.statusCode == 200) {
        final j = jsonDecode(res.body);
        if (j['success'] == true && j['data'] != null) {
          return _ApiResult(
            success: true,
            message: j['message'] ?? '',
            data: HrdAttendanceData.fromJson(j['data']),
          );
        }
        return _ApiResult(
          success: false,
          message: j['message'] ?? 'Tidak ditemukan',
        );
      }
      return _ApiResult(success: false, message: 'HTTP ${res.statusCode}');
    } catch (e) {
      return _ApiResult(success: false, message: 'Network error: $e');
    }
  }

  // ── Edit ──────────────────────────────────────────────────────────────────

  static Future<_ApiResult<void>> editAttendance({
    required int attendanceId,
    required String editReason,
    String? checkInTime,
    String? checkOutTime,
    String? checkInStatus,
    String? checkOutStatus,
    String? notes,
  }) async {
    try {
      final hrdUserId = await _getUserId();
      if (hrdUserId == null) {
        return _ApiResult(success: false, message: 'UserID tidak ditemukan.');
      }

      final body = {
        'HrdUserId': hrdUserId,
        'AttendanceId': attendanceId,
        'EditReason': editReason,
        'CheckInTime': checkInTime,
        'CheckOutTime': checkOutTime,
        'CheckInStatus': checkInStatus,
        'CheckOutStatus': checkOutStatus,
        'Notes': notes,
      };

      final res = await http
          .post(
            Uri.parse('$_baseUrl/edit'),
            headers: await _getHeaders(),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));

      if (res.statusCode == 200) {
        final j = jsonDecode(res.body);
        return _ApiResult(
          success: j['success'] == true,
          message: j['message'] ?? '',
        );
      }
      return _ApiResult(success: false, message: 'HTTP ${res.statusCode}');
    } catch (e) {
      return _ApiResult(success: false, message: 'Network error: $e');
    }
  }

  // ── Edit Log ──────────────────────────────────────────────────────────────

  static Future<_ApiResult<List<HrdAttendanceEditLog>>> getEditLog({
    int? attendanceId,
  }) async {
    try {
      final hrdUserId = await _getUserId();
      if (hrdUserId == null) {
        return _ApiResult(success: false, message: 'UserID tidak ditemukan.');
      }

      final res = await http
          .post(
            Uri.parse('$_baseUrl/edit-log'),
            headers: await _getHeaders(),
            body: jsonEncode({
              'HrdUserId': hrdUserId,
              'AttendanceId': attendanceId,
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (res.statusCode == 200) {
        final j = jsonDecode(res.body);
        if (j['success'] == true) {
          final list = (j['data'] as List? ?? [])
              .map((e) => HrdAttendanceEditLog.fromJson(e))
              .toList();
          return _ApiResult(success: true, message: '', data: list);
        }
        return _ApiResult(success: false, message: j['message'] ?? '');
      }
      return _ApiResult(success: false, message: 'HTTP ${res.statusCode}');
    } catch (e) {
      return _ApiResult(success: false, message: 'Network error: $e');
    }
  }
}

// ── Generic result wrapper ────────────────────────────────────────────────────

class _ApiResult<T> {
  final bool success;
  final String message;
  final T? data;
  _ApiResult({required this.success, required this.message, this.data});
}
