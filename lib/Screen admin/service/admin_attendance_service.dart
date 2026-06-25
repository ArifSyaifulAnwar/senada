import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../Services/token_service.dart';
import '../../Services/config.dart';
import '../model/admin_attendance_model.dart';

class HrdWorkPeriod {
  final int id;
  final int tahun;
  final int bulan;
  final DateTime tanggalMulai;
  final DateTime tanggalSelesai;
  final String keterangan;

  const HrdWorkPeriod({
    required this.id,
    required this.tahun,
    required this.bulan,
    required this.tanggalMulai,
    required this.tanggalSelesai,
    required this.keterangan,
  });

  factory HrdWorkPeriod.fromJson(Map<String, dynamic> json) {
    return HrdWorkPeriod(
      id: json['Id'] ?? json['id'] ?? 0,
      tahun: json['Tahun'] ?? json['tahun'] ?? 0,
      bulan: json['Bulan'] ?? json['bulan'] ?? 0,
      tanggalMulai:
          DateTime.tryParse(
            (json['TanggalMulai'] ??
                    json['tanggalMulai'] ??
                    json['tanggal_mulai'] ??
                    '')
                .toString(),
          ) ??
          DateTime.now(),
      tanggalSelesai:
          DateTime.tryParse(
            (json['TanggalSelesai'] ??
                    json['tanggalSelesai'] ??
                    json['tanggal_selesai'] ??
                    '')
                .toString(),
          ) ??
          DateTime.now(),
      keterangan: (json['Keterangan'] ?? json['keterangan'] ?? '').toString(),
    );
  }

  String get bulanLabel {
    const bulanNames = [
      '',
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];

    if (bulan >= 1 && bulan <= 12) {
      return '${bulanNames[bulan]} $tahun';
    }

    return '$bulan/$tahun';
  }
}

class AdminAttendanceService {
  Future<String?> _getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('UserID');
  }

  Future<ApiResponse<List<HrdWorkPeriod>>> getWorkPeriodsByYear({
    required int tahun,
  }) async {
    try {
      final response = await TokenService.authorizedPost(
        Uri.parse('$baseURL/api/calendar/period/list'),
        body: jsonEncode({'tahun': tahun}),
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body) as Map<String, dynamic>;

        final success =
            jsonData['Success'] == true || jsonData['success'] == true;

        if (!success) {
          return ApiResponse<List<HrdWorkPeriod>>(
            success: false,
            message:
                jsonData['Message'] ??
                jsonData['message'] ??
                'Gagal mengambil periode kerja',
          );
        }

        final rawData = jsonData['Data'] ?? jsonData['data'] ?? [];

        final periods = rawData is List
            ? rawData
                  .whereType<Map<String, dynamic>>()
                  .map((e) => HrdWorkPeriod.fromJson(e))
                  .toList()
            : <HrdWorkPeriod>[];

        periods.sort((a, b) => a.bulan.compareTo(b.bulan));

        return ApiResponse<List<HrdWorkPeriod>>(
          success: true,
          message: 'Periode kerja berhasil diambil',
          data: periods,
        );
      }

      return ApiResponse<List<HrdWorkPeriod>>(
        success: false,
        message: 'Server error (${response.statusCode})',
      );
    } catch (e) {
      return ApiResponse<List<HrdWorkPeriod>>(
        success: false,
        message: 'Terjadi kesalahan: $e',
      );
    }
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
      case 'Semua Data':
        return null; // Untuk semua data, jangan kirim time range
      default:
        return timeRange;
    }
  }

  // services/admin_attendance_service.dart - PERBAIKAN
  // services/admin_attendance_service.dart - PERBAIKAN
  Future<ApiResponse<AdminAttendanceResponse>> getAllAttendanceData({
    String? filterUserId,
    String? timeRange,
    DateTime? startDate,
    DateTime? endDate,
    String? statusFilter,
    int? officeId,
    String? searchTerm,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final adminUserId = await _getUserId();
      if (adminUserId == null) {
        return ApiResponse<AdminAttendanceResponse>(
          success: false,
          message: 'User ID tidak ditemukan. Silakan login ulang.',
        );
      }

      // Gunakan model request yang sudah diperbaiki
      final request = AdminAttendanceRequest(
        adminUserId: adminUserId,
        filterUserId: filterUserId,
        timeRange: _mapTimeRangeToEnglish(timeRange),
        startDate: startDate,
        endDate: endDate,
        statusFilter: statusFilter,
        officeId: officeId,
        searchTerm: searchTerm,
        page: page,
        pageSize: pageSize,
      );

      final requestBody = jsonEncode(request.toJson());
      // Debug log

      final response = await TokenService.authorizedPost(
        Uri.parse('$baseURL/api/admin/attendance/all'),
        body: requestBody,
      );
      if (response.statusCode == 200) {
        try {
          final jsonData = jsonDecode(response.body) as Map<String, dynamic>;

          if (jsonData['Success'] != true) {
            return ApiResponse<AdminAttendanceResponse>(
              success: false,
              message: jsonData['Message'] ?? 'Request tidak berhasil',
              error: jsonData['Data'],
            );
          }

          final responseData = jsonData['Data'] as Map<String, dynamic>?;
          if (responseData == null) {
            return ApiResponse<AdminAttendanceResponse>(
              success: true,
              message: 'Data kosong',
              data: AdminAttendanceResponse(),
            );
          }

          final attendanceResponse = AdminAttendanceResponse.fromJson(
            responseData,
          );

          return ApiResponse<AdminAttendanceResponse>(
            success: true,
            message: jsonData['Message'] ?? 'Data berhasil diambil',
            data: attendanceResponse,
          );
        } catch (parseError) {
          return ApiResponse<AdminAttendanceResponse>(
            success: false,
            message: 'Error parsing response: ${parseError.toString()}',
            error: parseError.toString(),
          );
        }
      } else if (response.statusCode == 400) {
        // Handle validation errors
        try {
          final errorData = jsonDecode(response.body);
          final errors = errorData['Data'] as List?;
          final errorMessage =
              errors?.join(', ') ?? errorData['Message'] ?? 'Validasi gagal';

          return ApiResponse<AdminAttendanceResponse>(
            success: false,
            message: 'Validasi error: $errorMessage',
            error: errorData,
          );
        } catch (e) {
          return ApiResponse<AdminAttendanceResponse>(
            success: false,
            message: 'Bad Request: ${response.body}',
          );
        }
      } else {
        try {
          final errorData = jsonDecode(response.body);
          return ApiResponse<AdminAttendanceResponse>(
            success: false,
            message: errorData['Message'] ?? 'Gagal mengambil data absensi',
            error: errorData,
          );
        } catch (e) {
          return ApiResponse<AdminAttendanceResponse>(
            success: false,
            message: 'Server error (${response.statusCode}): ${response.body}',
          );
        }
      }
    } on TimeoutException {
      return ApiResponse<AdminAttendanceResponse>(
        success: false,
        message: 'Koneksi timeout. Periksa koneksi internet Anda.',
      );
    } catch (e) {
      return ApiResponse<AdminAttendanceResponse>(
        success: false,
        message: 'Terjadi kesalahan: ${e.toString()}',
        error: e.toString(),
      );
    }
  }

  /// Mengambil periode yang benar-benar aktif berdasarkan rentang tanggal.
  ///
  /// Jangan memilih hanya dari field `bulan`, karena periode berikutnya bisa
  /// mulai sebelum pergantian bulan kalender. Contoh:
  /// Periode Juli dapat dimulai pada 25 Juni, sedangkan Periode Juni telah
  /// berakhir pada 24 Juni.
  Future<ApiResponse<DateTimeRange>> getCurrentWorkPeriod() async {
    try {
      final adminUserId = await _getUserId();
      if (adminUserId == null) {
        return ApiResponse<DateTimeRange>(
          success: false,
          message: 'User ID tidak ditemukan. Silakan login ulang.',
        );
      }

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final response = await TokenService.authorizedPost(
        Uri.parse('$baseURL/api/calendar/period/list'),
        body: jsonEncode({'tahun': now.year}),
      );

      if (response.statusCode != 200) {
        return ApiResponse<DateTimeRange>(
          success: false,
          message: 'Server error (${response.statusCode})',
        );
      }

      final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
      final success =
          jsonData['Success'] == true || jsonData['success'] == true;

      if (!success) {
        return ApiResponse<DateTimeRange>(
          success: false,
          message:
              jsonData['Message'] ??
              jsonData['message'] ??
              'Gagal mengambil periode kerja',
        );
      }

      final rawData = jsonData['Data'] ?? jsonData['data'] ?? [];
      if (rawData is! List) {
        return ApiResponse<DateTimeRange>(
          success: false,
          message: 'Format periode kerja tidak valid.',
        );
      }

      final ranges = <DateTimeRange>[];

      for (final row in rawData) {
        if (row is! Map<String, dynamic>) continue;

        final startRaw =
            row['TanggalMulai'] ?? row['tanggalMulai'] ?? row['tanggal_mulai'];
        final endRaw =
            row['TanggalSelesai'] ??
            row['tanggalSelesai'] ??
            row['tanggal_selesai'];

        final parsedStart = DateTime.tryParse(startRaw?.toString() ?? '');
        final parsedEnd = DateTime.tryParse(endRaw?.toString() ?? '');

        if (parsedStart == null || parsedEnd == null) continue;

        final start = DateTime(
          parsedStart.year,
          parsedStart.month,
          parsedStart.day,
        );
        final end = DateTime(parsedEnd.year, parsedEnd.month, parsedEnd.day);

        if (end.isBefore(start)) continue;

        ranges.add(DateTimeRange(start: start, end: end));
      }

      // Ambil periode yang mencakup hari ini, bukan sekadar `bulan == now.month`.
      final activeRanges =
          ranges
              .where(
                (range) =>
                    !today.isBefore(range.start) && !today.isAfter(range.end),
              )
              .toList()
            ..sort((a, b) => b.start.compareTo(a.start));

      if (activeRanges.isNotEmpty) {
        return ApiResponse<DateTimeRange>(
          success: true,
          message: 'Periode kerja aktif ditemukan',
          data: activeRanges.first,
        );
      }

      return ApiResponse<DateTimeRange>(
        success: false,
        message: 'Tidak ada periode kerja aktif untuk hari ini.',
      );
    } catch (e) {
      return ApiResponse<DateTimeRange>(
        success: false,
        message: 'Terjadi kesalahan: $e',
      );
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> notifyBelumAbsenWa({
    required DateTime tanggal,
  }) async {
    try {
      final adminUserId = await _getUserId();

      if (adminUserId == null || adminUserId.isEmpty) {
        return ApiResponse<Map<String, dynamic>>(
          success: false,
          message: 'User ID tidak ditemukan. Silakan login ulang.',
        );
      }

      final request = {
        'adminUserId': adminUserId,
        'tanggal': DateFormat('yyyy-MM-dd').format(tanggal),
      };

      final response = await TokenService.authorizedPost(
        Uri.parse('$baseURL/api/admin/attendance/notify-belum-absen-wa'),
        body: jsonEncode(request),
      ).timeout(const Duration(seconds: 120));

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body) as Map<String, dynamic>;

        final success =
            jsonData['Success'] == true || jsonData['success'] == true;

        final message =
            jsonData['Message'] ??
            jsonData['message'] ??
            (success
                ? 'Notifikasi WA sedang diproses.'
                : 'Gagal memproses notifikasi WA.');

        return ApiResponse<Map<String, dynamic>>(
          success: success,
          message: message.toString(),
          data: jsonData,
        );
      }

      return ApiResponse<Map<String, dynamic>>(
        success: false,
        message: 'Server error (${response.statusCode})',
      );
    } catch (e) {
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        message: 'Gagal memproses notifikasi WA: $e',
      );
    }
  }

  Future<ApiResponse<List<Employee>>> getEmployees({String? searchTerm}) async {
    try {
      final adminUserId = await _getUserId();
      if (adminUserId == null) {
        return ApiResponse<List<Employee>>(
          success: false,
          message: 'User ID tidak ditemukan. Silakan login ulang.',
        );
      }

      final request = {'adminUserId': adminUserId, 'searchTerm': searchTerm};

      final response = await TokenService.authorizedPost(
        Uri.parse('$baseURL/api/admin/attendance/employees'),
        body: jsonEncode(request),
      );
      if (response.statusCode == 200) {
        try {
          final jsonData = jsonDecode(response.body) as Map<String, dynamic>;

          if (jsonData['Success'] != true) {
            return ApiResponse<List<Employee>>(
              success: false,
              message: jsonData['Message'] ?? 'Request tidak berhasil',
            );
          }

          final dataList = jsonData['Data'] as List?;
          final employeesList =
              dataList
                  ?.map((item) {
                    try {
                      return Employee.fromJson(item as Map<String, dynamic>);
                    } catch (e) {
                      return null;
                    }
                  })
                  .where((item) => item != null)
                  .cast<Employee>()
                  .toList() ??
              [];

          return ApiResponse<List<Employee>>(
            success: true,
            message: jsonData['Message'] ?? 'Daftar karyawan berhasil diambil',
            data: employeesList,
          );
        } catch (parseError) {
          return ApiResponse<List<Employee>>(
            success: false,
            message: 'Error parsing response: ${parseError.toString()}',
          );
        }
      } else {
        try {
          final errorData = jsonDecode(response.body);
          return ApiResponse<List<Employee>>(
            success: false,
            message: errorData['Message'] ?? 'Gagal mengambil daftar karyawan',
          );
        } catch (e) {
          return ApiResponse<List<Employee>>(
            success: false,
            message: 'Server error (${response.statusCode})',
          );
        }
      }
    } catch (e) {
      return ApiResponse<List<Employee>>(
        success: false,
        message: 'Terjadi kesalahan: ${e.toString()}',
      );
    }
  }

  Future<ApiResponse<List<Office>>> getOffices() async {
    try {
      final adminUserId = await _getUserId();
      if (adminUserId == null) {
        return ApiResponse<List<Office>>(
          success: false,
          message: 'User ID tidak ditemukan. Silakan login ulang.',
        );
      }

      final request = {'adminUserId': adminUserId};

      final response = await TokenService.authorizedPost(
        Uri.parse('$baseURL/api/admin/attendance/offices'),
        body: jsonEncode(request),
      );

      if (response.statusCode == 200) {
        try {
          final jsonData = jsonDecode(response.body) as Map<String, dynamic>;

          if (jsonData['Success'] != true) {
            return ApiResponse<List<Office>>(
              success: false,
              message: jsonData['Message'] ?? 'Request tidak berhasil',
            );
          }

          final dataList = jsonData['Data'] as List?;
          final officesList =
              dataList
                  ?.map((item) {
                    try {
                      return Office.fromJson(item as Map<String, dynamic>);
                    } catch (e) {
                      return null;
                    }
                  })
                  .where((item) => item != null)
                  .cast<Office>()
                  .toList() ??
              [];

          return ApiResponse<List<Office>>(
            success: true,
            message: jsonData['Message'] ?? 'Daftar kantor berhasil diambil',
            data: officesList,
          );
        } catch (parseError) {
          return ApiResponse<List<Office>>(
            success: false,
            message: 'Error parsing response: ${parseError.toString()}',
          );
        }
      } else {
        try {
          final errorData = jsonDecode(response.body);
          return ApiResponse<List<Office>>(
            success: false,
            message: errorData['message'] ?? 'Gagal mengambil daftar kantor',
          );
        } catch (e) {
          return ApiResponse<List<Office>>(
            success: false,
            message: 'Server error (${response.statusCode})',
          );
        }
      }
    } catch (e) {
      return ApiResponse<List<Office>>(
        success: false,
        message: 'Terjadi kesalahan: ${e.toString()}',
      );
    }
  }

  Future<ApiResponse<AdminAttendanceStats>> getDashboardStats({
    String? timeRange,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final adminUserId = await _getUserId();
      if (adminUserId == null) {
        return ApiResponse<AdminAttendanceStats>(
          success: false,
          message: 'User ID tidak ditemukan. Silakan login ulang.',
        );
      }

      // PERBAIKAN: Jangan set default time range, biarkan null jika tidak ada
      final mappedTimeRange = _mapTimeRangeToEnglish(timeRange);

      final request = AdminAttendanceRequest(
        adminUserId: adminUserId,
        timeRange: mappedTimeRange, // Bisa null untuk semua data
        startDate: startDate,
        endDate: endDate,
        page: 1,
        pageSize: 10000,
      );
      final response = await TokenService.authorizedPost(
        Uri.parse('$baseURL/api/admin/attendance/dashboard-stats'),
        body: jsonEncode(request.toJson()),
      );

      if (response.statusCode == 200) {
        try {
          final jsonData = jsonDecode(response.body) as Map<String, dynamic>;

          if (jsonData['Success'] != true) {
            return ApiResponse<AdminAttendanceStats>(
              success: false,
              message: jsonData['Message'] ?? 'Request tidak berhasil',
            );
          }

          final statsData = jsonData['Data'] as Map<String, dynamic>?;
          final stats = statsData != null
              ? AdminAttendanceStats.fromJson(statsData)
              : AdminAttendanceStats();

          return ApiResponse<AdminAttendanceStats>(
            success: true,
            message: jsonData['Message'] ?? 'Statistik berhasil diambil',
            data: stats,
          );
        } catch (parseError) {
          return ApiResponse<AdminAttendanceStats>(
            success: false,
            message: 'Error parsing response: ${parseError.toString()}',
          );
        }
      } else {
        try {
          final errorData = jsonDecode(response.body);
          return ApiResponse<AdminAttendanceStats>(
            success: false,
            message: errorData['message'] ?? 'Gagal mengambil statistik',
          );
        } catch (e) {
          return ApiResponse<AdminAttendanceStats>(
            success: false,
            message: 'Server error (${response.statusCode})',
          );
        }
      }
    } catch (e) {
      return ApiResponse<AdminAttendanceStats>(
        success: false,
        message: 'Terjadi kesalahan: ${e.toString()}',
      );
    }
  }

  Future<ApiResponse<String>> exportAttendanceData({
    String? filterUserId,
    String? timeRange,
    DateTime? startDate,
    DateTime? endDate,
    String? statusFilter,
    int? officeId,
    String? searchTerm,
  }) async {
    try {
      final adminUserId = await _getUserId();
      if (adminUserId == null) {
        return ApiResponse<String>(
          success: false,
          message: 'User ID tidak ditemukan. Silakan login ulang.',
        );
      }

      final request = AdminAttendanceRequest(
        adminUserId: adminUserId,
        filterUserId: filterUserId,
        timeRange: _mapTimeRangeToEnglish(timeRange),
        startDate: startDate,
        endDate: endDate,
        statusFilter: statusFilter,
        officeId: officeId,
        searchTerm: searchTerm,
        page: 1,
        pageSize: 10000,
      );

      final response = await TokenService.authorizedPost(
        Uri.parse('$baseURL/api/admin/attendance/export'),
        body: jsonEncode(request.toJson()),
      );
      if (response.statusCode == 200) {
        return ApiResponse<String>(
          success: true,
          message: 'Data berhasil diekspor',
          data: response.body,
        );
      } else {
        try {
          final errorData = jsonDecode(response.body);
          return ApiResponse<String>(
            success: false,
            message: errorData['message'] ?? 'Gagal mengekspor data',
          );
        } catch (e) {
          return ApiResponse<String>(
            success: false,
            message: 'Server error (${response.statusCode})',
          );
        }
      }
    } catch (e) {
      return ApiResponse<String>(
        success: false,
        message: 'Terjadi kesalahan: ${e.toString()}',
      );
    }
  }
}

// ApiResponse class
class ApiResponse<T> {
  final bool success;
  final String message;
  final T? data;
  final dynamic error;

  ApiResponse({
    required this.success,
    required this.message,
    this.data,
    this.error,
  });

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic)? fromJsonT,
  ) {
    return ApiResponse<T>(
      success: json['Success'] ?? false,
      message: json['Message'] ?? '',
      data: json['Data'] != null && fromJsonT != null
          ? fromJsonT(json['Data'])
          : null,
      error: json['ErrorCode'],
    );
  }
}
