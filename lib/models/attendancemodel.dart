class AttendanceHistoryRequest {
  final String userId;
  final String? timeRange;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? statusFilter;
  final int page;
  final int pageSize;

  AttendanceHistoryRequest({
    required this.userId,
    this.timeRange,
    this.startDate,
    this.endDate,
    this.statusFilter,
    this.page = 1,
    this.pageSize = 20,
  });

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'timeRange': timeRange,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'statusFilter': statusFilter == 'Semua' ? null : statusFilter,
      'page': page,
      'pageSize': pageSize,
    };
  }
}

class AttendanceDetailRequest {
  final int id;
  final String userId;

  AttendanceDetailRequest({required this.id, required this.userId});

  Map<String, dynamic> toJson() {
    return {'id': id, 'userId': userId};
  }
}

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

class AttendanceHistoryResponse {
  final List<AttendanceData> data;
  final AttendanceStats stats;
  final int totalRecords;
  final int currentPage;
  final int totalPages;

  AttendanceHistoryResponse({
    required this.data,
    required this.stats,
    required this.totalRecords,
    required this.currentPage,
    required this.totalPages,
  });

  factory AttendanceHistoryResponse.fromJson(Map<String, dynamic> json) {
    return AttendanceHistoryResponse(
      data:
          (json['Data'] as List?)
              ?.map((item) => AttendanceData.fromJson(item))
              .toList() ??
          [],
      stats: AttendanceStats.fromJson(json['Stats'] ?? {}),
      totalRecords:
          json['totalRecords'] ?? json['TotalCount'] ?? json['totalCount'] ?? 0,
      currentPage: json['currentPage'] ?? json['Page'] ?? json['page'] ?? 1,
      totalPages:
          json['totalPages'] ?? json['TotalPages'] ?? json['totalPages'] ?? 1,
    );
  }
}

class AttendanceStats {
  final int masukKantor;
  final int tepatWaktu;
  final int terlambat;
  final int cutiKaryawan;

  AttendanceStats({
    required this.masukKantor,
    required this.tepatWaktu,
    required this.terlambat,
    required this.cutiKaryawan,
  });

  factory AttendanceStats.fromJson(Map<String, dynamic> json) {
    return AttendanceStats(
      masukKantor:
          json['masukKantor'] ??
          json['Masuk Kantor'] ??
          json['MasukKantor'] ??
          0,
      tepatWaktu:
          json['tepatWaktu'] ?? json['Tepat Waktu'] ?? json['TepatWaktu'] ?? 0,
      terlambat: json['terlambat'] ?? json['Terlambat'] ?? 0,
      cutiKaryawan:
          json['cutiKaryawan'] ??
          json['Cuti Karyawan'] ??
          json['Cuti'] ??
          json['CutiKaryawan'] ??
          0,
    );
  }

  Map<String, int> toMap() {
    return {
      'Masuk Kantor': masukKantor,
      'Tepat Waktu': tepatWaktu,
      'Terlambat': terlambat,
      'Cuti Karyawan': cutiKaryawan,
    };
  }
}

class AttendanceData {
  final int id;
  final String userId;
  final DateTime attendanceDate;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final String checkInStatus;
  final String checkOutStatus;
  final String officeName;
  final String notes;
  final int? workingHoursMinutes;
  final int? overtimeMinutes;
  final double? checkInFaceConfidence;
  final double? checkOutFaceConfidence;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Properties yang akan diisi dari response API atau digenerate
  late final String tanggal;
  late final String jamMasuk;
  late final String jamKeluar;
  late final String status;
  late final String keterangan;
  late final String lokasi;
  late final String foto;

  AttendanceData({
    required this.id,
    required this.userId,
    required this.attendanceDate,
    this.checkInTime,
    this.checkOutTime,
    required this.checkInStatus,
    required this.checkOutStatus,
    required this.officeName,
    required this.notes,
    this.workingHoursMinutes,
    this.overtimeMinutes,
    this.checkInFaceConfidence,
    this.checkOutFaceConfidence,
    required this.createdAt,
    required this.updatedAt,
    String? status,
    String? jamMasuk,
    String? jamKeluar,
    String? tanggal,
    String? keterangan,
    String? lokasi,
    String? foto,
  }) {
    // Menggunakan data yang sudah diformat dari API atau generate sendiri
    this.tanggal = tanggal ?? attendanceDate.toIso8601String().split('T')[0];
    this.jamMasuk =
        jamMasuk ??
        (checkInTime != null
            ? "${checkInTime!.hour.toString().padLeft(2, '0')}:${checkInTime!.minute.toString().padLeft(2, '0')}"
            : '-');
    this.jamKeluar =
        jamKeluar ??
        (checkOutTime != null
            ? "${checkOutTime!.hour.toString().padLeft(2, '0')}:${checkOutTime!.minute.toString().padLeft(2, '0')}"
            : '-');
    this.status = status ?? _generateStatus();
    this.keterangan = keterangan ?? notes;
    this.lokasi = lokasi ?? officeName;
    this.foto = foto ?? '';
  }

  String _generateStatus() {
    // Map API status codes ke display status
    switch (checkInStatus.toLowerCase()) {
      case 'on_time':
        return 'Tepat Waktu';
      case 'late':
      case 'very_late':
        return 'Terlambat';
      case 'cuti':
      case 'leave':
        return 'Cuti';
      default:
        // Fallback logic
        if (checkInStatus.toLowerCase().contains('cuti') ||
            checkOutStatus.toLowerCase().contains('cuti')) {
          return 'Cuti';
        } else if (checkInStatus.toLowerCase().contains('terlambat') ||
            checkInStatus.toLowerCase().contains('late')) {
          return 'Terlambat';
        } else if (checkInTime != null) {
          return 'Tepat Waktu';
        } else {
          return checkInStatus.isNotEmpty ? checkInStatus : 'Tidak Diketahui';
        }
    }
  }

  factory AttendanceData.fromJson(Map<String, dynamic> json) {
    try {
      return AttendanceData(
        id: json['id'] ?? json['Id'] ?? 0,
        userId: json['userId'] ?? json['UserId'] ?? json['user_id'] ?? '',
        attendanceDate:
            _parseDateTime(
              json['attendanceDate'] ??
                  json['AttendanceDate'] ??
                  json['attendance_date'],
            ) ??
            DateTime.now(),
        checkInTime: _parseDateTime(
          json['checkInTime'] ?? json['CheckInTime'] ?? json['check_in_time'],
        ),
        checkOutTime: _parseDateTime(
          json['checkOutTime'] ??
              json['CheckOutTime'] ??
              json['check_out_time'],
        ),
        checkInStatus:
            json['checkInStatus'] ??
            json['CheckInStatus'] ??
            json['check_in_status'] ??
            '',
        checkOutStatus:
            json['checkOutStatus'] ??
            json['CheckOutStatus'] ??
            json['check_out_status'] ??
            '',
        officeName:
            json['officeName'] ??
            json['OfficeName'] ??
            json['office_name'] ??
            'Tidak Diketahui',
        notes:
            json['notes'] ??
            json['Notes'] ??
            json['keterangan'] ??
            json['description'] ??
            '',
        workingHoursMinutes:
            json['workingHoursMinutes'] ??
            json['WorkingHoursMinutes'] ??
            json['working_hours_minutes'],
        overtimeMinutes:
            json['overtimeMinutes'] ??
            json['OvertimeMinutes'] ??
            json['overtime_minutes'],
        checkInFaceConfidence: _parseDouble(
          json['checkInFaceConfidence'] ??
              json['CheckInFaceConfidence'] ??
              json['check_in_face_confidence'],
        ),
        checkOutFaceConfidence: _parseDouble(
          json['checkOutFaceConfidence'] ??
              json['CheckOutFaceConfidence'] ??
              json['check_out_face_confidence'],
        ),
        createdAt:
            _parseDateTime(
              json['createdAt'] ?? json['CreatedAt'] ?? json['created_at'],
            ) ??
            DateTime.now(),
        updatedAt:
            _parseDateTime(
              json['updatedAt'] ?? json['UpdatedAt'] ?? json['updated_at'],
            ) ??
            DateTime.now(),
        // Gunakan data yang sudah diformat dari API jika tersedia
        status: json['status'],
        jamMasuk: json['jamMasuk'],
        jamKeluar: json['jamKeluar'],
        tanggal: json['tanggal'],
        keterangan: json['keterangan'],
        lokasi: json['lokasi'],
        foto: json['foto'],
      );
    } catch (e) {
      rethrow;
    }
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;

    try {
      if (value is String) {
        return DateTime.parse(value);
      } else if (value is DateTime) {
        return value;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;

    try {
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.parse(value);
      return null;
    } catch (e) {
      return null;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'attendanceDate': attendanceDate.toIso8601String(),
      'checkInTime': checkInTime?.toIso8601String(),
      'checkOutTime': checkOutTime?.toIso8601String(),
      'checkInStatus': checkInStatus,
      'checkOutStatus': checkOutStatus,
      'officeName': officeName,
      'notes': notes,
      'workingHoursMinutes': workingHoursMinutes,
      'overtimeMinutes': overtimeMinutes,
      'checkInFaceConfidence': checkInFaceConfidence,
      'checkOutFaceConfidence': checkOutFaceConfidence,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
