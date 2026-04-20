

class AdminAttendanceRequest {
  final String adminUserId;
  final String? filterUserId;
  final String? timeRange;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? statusFilter;
  final int? officeId;
  final String? searchTerm;
  final int page;
  final int pageSize;

  AdminAttendanceRequest({
    required this.adminUserId,
    this.filterUserId,
    this.timeRange,
    this.startDate,
    this.endDate,
    this.statusFilter,
    this.officeId,
    this.searchTerm,
    this.page = 1,
    this.pageSize = 20,
  });

  Map<String, dynamic> toJson() {
    return {
      'adminUserId': adminUserId,
      'filterUserId': filterUserId,
      'timeRange': timeRange,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'statusFilter': statusFilter == 'Semua' ? null : statusFilter,
      'officeId': officeId,
      'searchTerm': searchTerm,
      'page': page,
      'pageSize': pageSize,
    };
  }
}

class AdminAttendanceData {
  final int id;
  final String userId;
  final String userName;
  final String? employeeId;
  final String? department;
  final DateTime attendanceDate;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final double? checkInLatitude;
  final double? checkInLongitude;
  final double? checkOutLatitude;
  final double? checkOutLongitude;
  final int? checkInOfficeId;
  final int? checkOutOfficeId;
  final String? checkInOfficeName;
  final String? checkOutOfficeName;
  final String checkInStatus;
  final String checkOutStatus;
  final double? checkInFaceConfidence;
  final double? checkOutFaceConfidence;
  final int? workingHoursMinutes;
  final int? overtimeMinutes;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String displayStatus;
  final String formattedCheckIn;
  final String formattedCheckOut;

  AdminAttendanceData({
    required this.id,
    required this.userId,
    required this.userName,
    this.employeeId,
    this.department,
    required this.attendanceDate,
    this.checkInTime,
    this.checkOutTime,
    this.checkInLatitude,
    this.checkInLongitude,
    this.checkOutLatitude,
    this.checkOutLongitude,
    this.checkInOfficeId,
    this.checkOutOfficeId,
    this.checkInOfficeName,
    this.checkOutOfficeName,
    required this.checkInStatus,
    required this.checkOutStatus,
    this.checkInFaceConfidence,
    this.checkOutFaceConfidence,
    this.workingHoursMinutes,
    this.overtimeMinutes,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
    required this.displayStatus,
    required this.formattedCheckIn,
    required this.formattedCheckOut,
  });

  factory AdminAttendanceData.fromJson(Map<String, dynamic> json) {
    try {

      final result = AdminAttendanceData(
        id: _parseInt(json['Id']) ?? 0,
        userId: _parseString(json['UserId']) ?? '',
        userName: _parseString(json['UserName']) ?? 'Unknown User',
        employeeId: _parseString(json['EmployeeId']),
        department: _parseString(json['Department']),
        attendanceDate:
            _parseDateTime(json['AttendanceDate']) ?? DateTime.now(),
        checkInTime: _parseDateTime(json['CheckInTime']),
        checkOutTime: _parseDateTime(json['CheckOutTime']),
        checkInLatitude: _parseDouble(json['CheckInLatitude']),
        checkInLongitude: _parseDouble(json['CheckInLongitude']),
        checkOutLatitude: _parseDouble(json['CheckOutLatitude']),
        checkOutLongitude: _parseDouble(json['CheckOutLongitude']),
        checkInOfficeId: _parseInt(json['CheckInOfficeId']) ?? 0,
        checkOutOfficeId: _parseInt(json['CheckOutOfficeId']) ?? 0,
        checkInOfficeName: _parseString(json['CheckInOfficeName']),
        checkOutOfficeName: _parseString(json['CheckOutOfficeName']),
        checkInStatus: _parseString(json['CheckInStatus']) ?? '',
        checkOutStatus: _parseString(json['CheckOutStatus']) ?? '',
        checkInFaceConfidence: _parseDouble(json['CheckInFaceConfidence']),
        checkOutFaceConfidence: _parseDouble(json['CheckOutFaceConfidence']),
        workingHoursMinutes: _parseInt(json['WorkingHoursMinutes']) ?? 0,
        overtimeMinutes: _parseInt(json['OvertimeMinutes']) ?? 0,
        notes: _parseString(json['Notes']) ?? '',
        createdAt: _parseDateTime(json['CreatedAt']) ?? DateTime.now(),
        updatedAt: _parseDateTime(json['UpdatedAt']) ?? DateTime.now(),
        displayStatus: _parseString(json['DisplayStatus']) ?? 'Tidak Diketahui',
        formattedCheckIn: _parseString(json['FormattedCheckIn']) ?? '-',
        formattedCheckOut: _parseString(json['FormattedCheckOut']) ?? '-',
      );

      return result;
    } catch (e) {

      // Return null instead of default object to identify failed parsing
      throw Exception('Failed to parse AdminAttendanceData: $e');
    }
  }

  // Helper parsing methods
  static String? _parseString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value.isEmpty ? null : value;
    return value.toString();
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      try {
        return int.parse(value);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      try {
        return double.parse(value);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    try {
      if (value is String) return DateTime.parse(value);
      if (value is DateTime) return value;
      return null;
    } catch (e) {
      return null;
    }
  }
}

class AdminAttendanceStats {
  final int totalRecords;
  final int tepatWaktu;
  final int terlambat;
  final int cuti;
  final int tidakHadir;
  final int masukKantor;
  final int totalKaryawan;
  final double? avgWorkingHours;
  final int totalOvertime;

  AdminAttendanceStats({
    this.totalRecords = 0,
    this.tepatWaktu = 0,
    this.terlambat = 0,
    this.cuti = 0,
    this.tidakHadir = 0,
    this.masukKantor = 0,
    this.totalKaryawan = 0,
    this.avgWorkingHours,
    this.totalOvertime = 0,
  });

  factory AdminAttendanceStats.fromJson(Map<String, dynamic> json) {
    try {
      return AdminAttendanceStats(
        totalRecords:
            _parseIntSafe(json['TotalRecords'] ?? json['totalRecords']) ?? 0,
        tepatWaktu:
            _parseIntSafe(json['TepatWaktu'] ?? json['tepatWaktu']) ?? 0,
        terlambat: _parseIntSafe(json['Terlambat'] ?? json['terlambat']) ?? 0,
        cuti: _parseIntSafe(json['Cuti'] ?? json['cuti']) ?? 0,
        tidakHadir:
            _parseIntSafe(json['TidakHadir'] ?? json['tidakHadir']) ?? 0,
        masukKantor:
            _parseIntSafe(json['MasukKantor'] ?? json['masukKantor']) ?? 0,
        totalKaryawan:
            _parseIntSafe(json['TotalKaryawan'] ?? json['totalKaryawan']) ?? 0,
        avgWorkingHours: _parseDoubleSafe(
          json['AvgWorkingHours'] ?? json['avgWorkingHours'],
        ),
        totalOvertime:
            _parseIntSafe(json['TotalOvertime'] ?? json['totalOvertime']) ?? 0,
      );
    } catch (e) {
      return AdminAttendanceStats(); // Return default stats
    }
  }

  static int? _parseIntSafe(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      try {
        return int.parse(value);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  static double? _parseDoubleSafe(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      try {
        return double.parse(value);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  Map<String, dynamic> toMap() {
    return {
      'Total Records': totalRecords,
      'Tepat Waktu': tepatWaktu,
      'Terlambat': terlambat,
      'Cuti': cuti,
      'Tidak Hadir': tidakHadir,
      'Masuk Kantor': masukKantor,
      'Total Karyawan': totalKaryawan,
      'Rata-rata Jam Kerja': avgWorkingHours != null
          ? '${(avgWorkingHours! / 60).toStringAsFixed(1)} jam'
          : '0 jam',
      'Total Lembur': '${(totalOvertime / 60).toStringAsFixed(1)} jam',
    };
  }
}

// models/admin_attendance_model.dart - PERBAIKAN AdminAttendanceResponse
class AdminAttendanceResponse {
  final List<AdminAttendanceData> data;
  final AdminAttendanceStats stats;
  final int totalRecords;
  final int currentPage;
  final int totalPages;
  final int pageSize;

  AdminAttendanceResponse({
    this.data = const [],
    AdminAttendanceStats? stats,
    this.totalRecords = 0,
    this.currentPage = 1,
    this.totalPages = 1,
    this.pageSize = 20,
  }) : stats = stats ?? AdminAttendanceStats();

  factory AdminAttendanceResponse.fromJson(Map<String, dynamic> json) {
    try {

      final dataList = json['Data'] as List?;

      final statsJson = json['Stats'] as Map<String, dynamic>?;

      List<AdminAttendanceData> parsedData = [];

      if (dataList != null) {
        for (int i = 0; i < dataList.length; i++) {
          try {
            final item = dataList[i] as Map<String, dynamic>;
            final attendanceData = AdminAttendanceData.fromJson(item);
            parsedData.add(attendanceData);
          } catch (e) {
            // Continue parsing other items instead of stopping
          }
        }
      }


      return AdminAttendanceResponse(
        data: parsedData,
        stats: statsJson != null
            ? AdminAttendanceStats.fromJson(statsJson)
            : AdminAttendanceStats(),
        totalRecords: json['TotalCount'] ?? 0,
        currentPage: json['Page'] ?? 1,
        totalPages: json['TotalPages'] ?? 1,
        pageSize: json['PageSize'] ?? 20,
      );
    } catch (e) {
      return AdminAttendanceResponse();
    }
  }
}

class Employee {
  final String userId;
  final String name;
  final String? employeeId;
  final String? department;
  final String? position;
  final String? email;
  final String? phone;
  final bool isActive;

  Employee({
    required this.userId,
    required this.name,
    this.employeeId,
    this.department,
    this.position,
    this.email,
    this.phone,
    this.isActive = true,
  });

  factory Employee.fromJson(Map<String, dynamic> json) {
    try {
      return Employee(
        userId: json['user_id'] ?? json['UserId'] ?? '',
        name: json['Name'] ?? '',
        employeeId: json['employee_id'] ?? json['EmployeeId'],
        department: json['Department'],
        position: json['Position'],
        email: json['Email'],
        phone: json['Phone'],
        isActive: json['is_active'] ?? json['IsActive'] ?? true,
      );
    } catch (e) {
      return Employee(userId: '', name: 'Parse Error');
    }
  }
}

class Office {
  final int id;
  final String officeName;
  final String? address;
  final double? latitude;
  final double? longitude;
  final bool isActive;

  Office({
    required this.id,
    required this.officeName,
    this.address,
    this.latitude,
    this.longitude,
    this.isActive = true,
  });

  factory Office.fromJson(Map<String, dynamic> json) {
    try {
      return Office(
        id: json['Id'] ?? 0,
        officeName: json['Office_name'] ?? json['OfficeName'] ?? '',

        latitude: _parseDoubleOffice(json['Latitude']),
        longitude: _parseDoubleOffice(json['Longitude']),
        isActive: json['Is_active'] ?? json['IsActive'] ?? true,
      );
    } catch (e) {
      return Office(id: 0, officeName: 'Parse Error');
    }
  }

  static double? _parseDoubleOffice(dynamic value) {
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
}
