// models/time_off_admin_model.dart

import 'dart:ui';

class TimeOffAdminStatistics {
  final int totalSubmissions;
  final int pendingCount;
  final int approvedCount;
  final int rejectedCount;
  final int processedCount;
  final int totalPendingDays;
  final int totalApprovedDays;
  final int totalProcessedDays;
  final String formattedTotalPending;
  final String formattedTotalApproved;
  final String formattedTotalProcessed;

  TimeOffAdminStatistics({
    required this.totalSubmissions,
    required this.pendingCount,
    required this.approvedCount,
    required this.rejectedCount,
    required this.processedCount,
    required this.totalPendingDays,
    required this.totalApprovedDays,
    required this.totalProcessedDays,
    required this.formattedTotalPending,
    required this.formattedTotalApproved,
    required this.formattedTotalProcessed,
  });

  factory TimeOffAdminStatistics.fromJson(Map<String, dynamic> json) {
    return TimeOffAdminStatistics(
      totalSubmissions: json['TotalSubmissions'] ?? 0,
      pendingCount: json['PendingCount'] ?? 0,
      approvedCount: json['ApprovedCount'] ?? 0,
      rejectedCount: json['RejectedCount'] ?? 0,
      processedCount: json['ProcessedCount'] ?? 0,
      totalPendingDays: json['TotalPendingDays'] ?? 0,
      totalApprovedDays: json['TotalApprovedDays'] ?? 0,
      totalProcessedDays: json['TotalProcessedDays'] ?? 0,
      formattedTotalPending: json['FormattedTotalPending'] ?? '0 hari',
      formattedTotalApproved: json['FormattedTotalApproved'] ?? '0 hari',
      formattedTotalProcessed: json['FormattedTotalProcessed'] ?? '0 hari',
    );
  }
}

class AdminTimeOffData {
  final int id;
  final String userId;
  final String userName;
  final String userEmail;
  final String? userPhone;
  final String? userJob;
  final String jenisTimeOff;
  final DateTime tanggalMulai;
  final DateTime tanggalSelesai;
  final int totalHari;
  final String? catatan;
  final String status;
  final DateTime submittedAt;
  final DateTime updatedAt;
  final String? approvedBy;
  final DateTime? approvedAt;
  final String? rejectionReason;
  final String? filePath;
  final String? fileName;
  final int? fileSize;
  final String? fileType;
  final int daysSinceSubmitted;
  final bool hasFile;

  AdminTimeOffData({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    this.userPhone,
    this.userJob,
    required this.jenisTimeOff,
    required this.tanggalMulai,
    required this.tanggalSelesai,
    required this.totalHari,
    this.catatan,
    required this.status,
    required this.submittedAt,
    required this.updatedAt,
    this.approvedBy,
    this.approvedAt,
    this.rejectionReason,
    this.filePath,
    this.fileName,
    this.fileSize,
    this.fileType,
    required this.daysSinceSubmitted,
    required this.hasFile,
  });

  factory AdminTimeOffData.fromJson(Map<String, dynamic> json) {
    return AdminTimeOffData(
      id: json['Id'] ?? 0,
      userId: json['UserId'] ?? '',
      userName: json['UserName'] ?? '',
      userEmail: json['UserEmail'] ?? '',
      userPhone: json['UserPhone'],
      userJob: json['UserJob'],
      jenisTimeOff: json['JenisTimeOff'] ?? '',
      tanggalMulai: DateTime.parse(json['TanggalMulai']),
      tanggalSelesai: DateTime.parse(json['TanggalSelesai']),
      totalHari: json['TotalHari'] ?? 0,
      catatan: json['Catatan'],
      status: json['Status'] ?? '',
      submittedAt: DateTime.parse(json['SubmittedAt']),
      updatedAt: DateTime.parse(json['UpdatedAt']),
      approvedBy: json['ApprovedBy'],
      approvedAt: json['ApprovedAt'] != null
          ? DateTime.parse(json['ApprovedAt'])
          : null,
      rejectionReason: json['RejectionReason'],
      filePath: json['FilePath'],
      fileName: json['FileName'],
      fileSize: json['FileSize'],
      fileType: json['FileType'],
      daysSinceSubmitted: json['DaysSinceSubmitted'] ?? 0,
      hasFile: json['HasFile'] ?? false,
    );
  }

  // Computed properties
  String get statusText {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Menunggu Review';
      case 'approved':
        return 'Disetujui';
      case 'rejected':
        return 'Ditolak';
      case 'processed':
        return 'Diproses';
      default:
        return status;
    }
  }

  Color get statusColorValue {
    switch (status.toLowerCase()) {
      case 'pending':
        return const Color(0xFFF59E0B);
      case 'approved':
        return const Color(0xFF10B981);
      case 'rejected':
        return const Color(0xFFEF4444);
      case 'processed':
        return const Color(0xFF3B82F6);
      default:
        return const Color(0xFF6B7280);
    }
  }

  String get formattedDate {
    final startDate =
        '${tanggalMulai.day.toString().padLeft(2, '0')}/${tanggalMulai.month.toString().padLeft(2, '0')}/${tanggalMulai.year}';
    if (tanggalMulai.day == tanggalSelesai.day &&
        tanggalMulai.month == tanggalSelesai.month &&
        tanggalMulai.year == tanggalSelesai.year) {
      return startDate;
    } else {
      final endDate =
          '${tanggalSelesai.day.toString().padLeft(2, '0')}/${tanggalSelesai.month.toString().padLeft(2, '0')}/${tanggalSelesai.year}';
      return '$startDate - $endDate';
    }
  }

  String get urgencyText {
    if (status.toLowerCase() != 'pending') return '';
    if (daysSinceSubmitted > 7) return 'SANGAT URGENT';
    if (daysSinceSubmitted > 3) return 'URGENT';
    return '';
  }

  Color get urgencyColor {
    if (daysSinceSubmitted > 7) return const Color(0xFFDC2626);
    if (daysSinceSubmitted > 3) return const Color(0xFFEF4444);
    return const Color(0xFFF59E0B);
  }

  String get formattedSubmittedDate {
    return '${submittedAt.day.toString().padLeft(2, '0')}/${submittedAt.month.toString().padLeft(2, '0')}/${submittedAt.year} ${submittedAt.hour.toString().padLeft(2, '0')}:${submittedAt.minute.toString().padLeft(2, '0')}';
  }

  String get jenisIcon {
    switch (jenisTimeOff) {
      case 'Cuti Tahunan':
        return '🏖️';
      case 'Sakit':
        return '🏥';
      case 'Cuti Khusus':
        return '🎉';
      case 'Izin Pribadi':
        return '👤';
      default:
        return '📅';
    }
  }
}

class UserWithTimeOffs {
  final String userId;
  final String name;
  final String email;
  final String? phone;
  final String? jobs;
  final int totalTimeOff;
  final int pendingCount;
  final int approvedCount;
  final int rejectedCount;
  final int processedCount;
  final int totalApprovedDays;
  final int totalRequestedDays;

  UserWithTimeOffs({
    required this.userId,
    required this.name,
    required this.email,
    this.phone,
    this.jobs,
    required this.totalTimeOff,
    required this.pendingCount,
    required this.approvedCount,
    required this.rejectedCount,
    required this.processedCount,
    required this.totalApprovedDays,
    required this.totalRequestedDays,
  });

  factory UserWithTimeOffs.fromJson(Map<String, dynamic> json) {
    return UserWithTimeOffs(
      userId: json['UserId'] ?? '',
      name: json['Name'] ?? '',
      email: json['Email'] ?? '',
      phone: json['Phone'],
      jobs: json['Jobs'],
      totalTimeOff: json['TotalTimeOff'] ?? 0,
      pendingCount: json['PendingCount'] ?? 0,
      approvedCount: json['ApprovedCount'] ?? 0,
      rejectedCount: json['PejectedCount'] ?? 0,
      processedCount: json['ProcessedCount'] ?? 0,
      totalApprovedDays: json['TotalApprovedDays'] ?? 0,
      totalRequestedDays: json['TotalRequestedDays'] ?? 0,
    );
  }

  String get formattedTotalDays => '$totalApprovedDays hari disetujui';
}

// Request Models
class AdminStatisticsRequest {
  final int? year;
  final int? month;

  AdminStatisticsRequest({this.year, this.month});

  Map<String, dynamic> toJson() {
    return {'year': year, 'month': month};
  }
}

class AdminTimeOffListRequest {
  final String adminId;
  final String? status;
  final String? userId;
  final int? yearFilter;
  final int? monthFilter;

  AdminTimeOffListRequest({
    required this.adminId,
    this.status,
    this.userId,
    this.yearFilter,
    this.monthFilter,
  });

  Map<String, dynamic> toJson() {
    return {
      'adminId': adminId,
      'status': status,
      'userId': userId,
      'yearFilter': yearFilter,
      'monthFilter': monthFilter,
    };
  }
}

class ReviewTimeOffRequest {
  final int id;
  final String status;
  final String approvedBy;
  final String? rejectionReason;
  final String adminId;

  ReviewTimeOffRequest({
    required this.id,
    required this.status,
    required this.approvedBy,
    this.rejectionReason,
    required this.adminId,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'status': status,
      'approvedBy': approvedBy,
      'rejectionReason': rejectionReason,
      'adminId': adminId,
    };
  }
}

class MarkProcessedRequest {
  final int id;
  final String processedBy;
  final String adminId;

  MarkProcessedRequest({
    required this.id,
    required this.processedBy,
    required this.adminId,
  });

  Map<String, dynamic> toJson() {
    return {'id': id, 'processedBy': processedBy, 'adminId': adminId};
  }
}

// Response Models
class ApiResponse<T> {
  final bool success;
  final String message;
  final T? data;

  ApiResponse({required this.success, required this.message, this.data});

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T? Function(dynamic)? fromJsonT,
  ) {
    return ApiResponse<T>(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: json['data'] != null && fromJsonT != null
          ? fromJsonT(json['data'])
          : json['data'],
    );
  }
}

class TimeOffAdminListResponse {
  final List<AdminTimeOffData> data;

  TimeOffAdminListResponse({required this.data});

  factory TimeOffAdminListResponse.fromJson(List<dynamic> jsonList) {
    return TimeOffAdminListResponse(
      data: jsonList.map((item) => AdminTimeOffData.fromJson(item)).toList(),
    );
  }
}

class UserTimeOffListResponse {
  final List<UserWithTimeOffs> data;

  UserTimeOffListResponse({required this.data});

  factory UserTimeOffListResponse.fromJson(List<dynamic> jsonList) {
    return UserTimeOffListResponse(
      data: jsonList.map((item) => UserWithTimeOffs.fromJson(item)).toList(),
    );
  }
}
