// models/overtime_admin_model.dart

import 'dart:ui';

class OvertimeAdminStatistics {
  final int totalSubmissions;
  final int pendingCount;
  final int approvedCount;
  final int rejectedCount;
  final double totalPendingHours;
  final double totalApprovedHours;
  final double totalRejectedHours;
  final String formattedTotalPending;
  final String formattedTotalApproved;
  final String formattedTotalRejected;

  OvertimeAdminStatistics({
    required this.totalSubmissions,
    required this.pendingCount,
    required this.approvedCount,
    required this.rejectedCount,
    required this.totalPendingHours,
    required this.totalApprovedHours,
    required this.totalRejectedHours,
    required this.formattedTotalPending,
    required this.formattedTotalApproved,
    required this.formattedTotalRejected,
  });

  factory OvertimeAdminStatistics.fromJson(Map<String, dynamic> json) {
    return OvertimeAdminStatistics(
      totalSubmissions: json['TotalSubmissions'] ?? 0,
      pendingCount: json['PendingCount'] ?? 0,
      approvedCount: json['ApprovedCount'] ?? 0,
      rejectedCount: json['RejectedCount'] ?? 0,
      totalPendingHours: (json['TotalPendingHours'] ?? 0.0).toDouble(),
      totalApprovedHours: (json['TotalApprovedHours'] ?? 0.0).toDouble(),
      totalRejectedHours: (json['TotalRejectedHours'] ?? 0.0).toDouble(),
      formattedTotalPending: json['FormattedTotalPending'] ?? '0 jam',
      formattedTotalApproved: json['FormattedTotalApproved'] ?? '0 jam',
      formattedTotalRejected: json['FormattedTotalRejected'] ?? '0 jam',
    );
  }
}

class AdminOvertimeData {
  final int id;
  final String userId;
  final String userName;
  final String userEmail;
  final String? userPhone;
  final String? userJob;
  final DateTime tanggalOvertime;
  final Duration jamMulai;
  final Duration jamSelesai;
  final double totalJam;
  final String? catatan;
  final String status;
  final DateTime submittedAt;
  final DateTime updatedAt;
  final String? approvedBy;
  final DateTime? approvedAt;
  final String? rejectionReason;
  final int daysSinceSubmitted;
  final bool canBeModified;

  AdminOvertimeData({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    this.userPhone,
    this.userJob,
    required this.tanggalOvertime,
    required this.jamMulai,
    required this.jamSelesai,
    required this.totalJam,
    this.catatan,
    required this.status,
    required this.submittedAt,
    required this.updatedAt,
    this.approvedBy,
    this.approvedAt,
    this.rejectionReason,
    required this.daysSinceSubmitted,
    required this.canBeModified,
  });

  factory AdminOvertimeData.fromJson(Map<String, dynamic> json) {
    return AdminOvertimeData(
      id: json['Id'] ?? 0,
      userId: json['UserId'] ?? '',
      userName: json['UserName'] ?? '',
      userEmail: json['UserEmail'] ?? '',
      userPhone: json['UserPhone'],
      userJob: json['UserJob'],
      tanggalOvertime: DateTime.parse(json['TanggalOvertime']),
      jamMulai: _parseDuration(json['JamMulai']),
      jamSelesai: _parseDuration(json['JamSelesai']),
      totalJam: (json['TotalJam'] ?? 0.0).toDouble(),
      catatan: json['Catatan'],
      status: json['Status'] ?? '',
      submittedAt: DateTime.parse(json['SubmittedAt']),
      updatedAt: DateTime.parse(json['UpdatedAt']),
      approvedBy: json['ApprovedBy'],
      approvedAt: json['ApprovedAt'] != null
          ? DateTime.parse(json['ApprovedAt'])
          : null,
      rejectionReason: json['RejectionReason'],
      daysSinceSubmitted: json['DaysSinceSubmitted'] ?? 0,
      canBeModified: json['CanBeModified'] ?? false,
    );
  }

  static Duration _parseDuration(dynamic timeValue) {
    if (timeValue is String) {
      // Parse format "HH:mm:ss" or "HH:mm"
      final parts = timeValue.split(':');
      final hours = int.parse(parts[0]);
      final minutes = int.parse(parts[1]);
      final seconds = parts.length > 2 ? int.parse(parts[2]) : 0;
      return Duration(hours: hours, minutes: minutes, seconds: seconds);
    }
    return Duration.zero;
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
      default:
        return const Color(0xFF6B7280);
    }
  }

  String get formattedDate {
    return '${tanggalOvertime.day.toString().padLeft(2, '0')}/${tanggalOvertime.month.toString().padLeft(2, '0')}/${tanggalOvertime.year}';
  }

  String get formattedMulai {
    final hours = jamMulai.inHours.toString().padLeft(2, '0');
    final minutes = (jamMulai.inMinutes % 60).toString().padLeft(2, '0');
    return '$hours:$minutes';
  }

  String get formattedSelesai {
    final hours = jamSelesai.inHours.toString().padLeft(2, '0');
    final minutes = (jamSelesai.inMinutes % 60).toString().padLeft(2, '0');
    return '$hours:$minutes';
  }

  String get formattedTimeRange => '$formattedMulai - $formattedSelesai';

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

  String get formattedTotalJam => '${totalJam.toStringAsFixed(1)} jam';

  String get overtimeIcon => '⏰';
}

class UserWithOvertimes {
  final String userId;
  final String name;
  final String email;
  final String? phone;
  final String? jobs;
  final int totalOvertime;
  final int pendingCount;
  final int approvedCount;
  final int rejectedCount;
  final double totalApprovedHours;
  final double totalRequestedHours;
  final String formattedTotalHours;

  UserWithOvertimes({
    required this.userId,
    required this.name,
    required this.email,
    this.phone,
    this.jobs,
    required this.totalOvertime,
    required this.pendingCount,
    required this.approvedCount,
    required this.rejectedCount,
    required this.totalApprovedHours,
    required this.totalRequestedHours,
    required this.formattedTotalHours,
  });

  factory UserWithOvertimes.fromJson(Map<String, dynamic> json) {
    return UserWithOvertimes(
      userId: json['UserId'] ?? '',
      name: json['Name'] ?? '',
      email: json['Email'] ?? '',
      phone: json['Phone'],
      jobs: json['Jobs'],
      totalOvertime: json['TotalOvertime'] ?? 0,
      pendingCount: json['PendingCount'] ?? 0,
      approvedCount: json['ApprovedCount'] ?? 0,
      rejectedCount: json['RejectedCount'] ?? 0,
      totalApprovedHours: (json['TotalApprovedHours'] ?? 0.0).toDouble(),
      totalRequestedHours: (json['TotalRequestedHours'] ?? 0.0).toDouble(),
      formattedTotalHours: json['FormattedTotalHours'] ?? '0 jam',
    );
  }
}

// Request Models
class AdminOvertimeStatisticsRequest {
  String? adminId; // ← Pastikan ini ada
  int? year;
  int? month;

  AdminOvertimeStatisticsRequest({
    this.adminId, // ← Dan ini
    this.year,
    this.month,
  });

  Map<String, dynamic> toJson() {
    return {
      'adminId': adminId, // ← Dan ini
      'year': year,
      'month': month,
    };
  }
}

class AdminOvertimeListRequest {
  final String adminId;
  final String? status;
  final String? userId;
  final int? yearFilter;
  final int? monthFilter;

  AdminOvertimeListRequest({
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

class ReviewOvertimeRequest {
  final int id;
  final String status;
  final String approvedBy;
  final String? rejectionReason;
  final String adminId;

  ReviewOvertimeRequest({
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

class BulkActionOvertimeRequest {
  final List<int> ids;
  final String action; // "approve" or "reject"
  final String approvedBy;
  final String? rejectionReason;
  final String adminId;

  BulkActionOvertimeRequest({
    required this.ids,
    required this.action,
    required this.approvedBy,
    this.rejectionReason,
    required this.adminId,
  });

  Map<String, dynamic> toJson() {
    return {
      'ids': ids,
      'action': action,
      'approvedBy': approvedBy,
      'rejectionReason': rejectionReason,
      'adminId': adminId,
    };
  }
}

class DeleteOvertimeRequest {
  final int id;
  final String adminId;

  DeleteOvertimeRequest({required this.id, required this.adminId});

  Map<String, dynamic> toJson() {
    return {'id': id, 'adminId': adminId};
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

class OvertimeAdminListResponse {
  final List<AdminOvertimeData> data;

  OvertimeAdminListResponse({required this.data});

  factory OvertimeAdminListResponse.fromJson(List<dynamic> jsonList) {
    return OvertimeAdminListResponse(
      data: jsonList.map((item) => AdminOvertimeData.fromJson(item)).toList(),
    );
  }
}

class UserOvertimeListResponse {
  final List<UserWithOvertimes> data;

  UserOvertimeListResponse({required this.data});

  factory UserOvertimeListResponse.fromJson(List<dynamic> jsonList) {
    return UserOvertimeListResponse(
      data: jsonList.map((item) => UserWithOvertimes.fromJson(item)).toList(),
    );
  }
}

// Export Models
class ExportOvertimeRequest {
  final String adminId;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? status;
  final String? userId;

  ExportOvertimeRequest({
    required this.adminId,
    this.startDate,
    this.endDate,
    this.status,
    this.userId,
  });

  Map<String, dynamic> toJson() {
    return {
      'adminId': adminId,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'status': status,
      'userId': userId,
    };
  }
}

// Filter Options
class OvertimeFilterOptions {
  static const List<String> statusOptions = [
    'Semua Status',
    'Pending',
    'Approved',
    'Rejected',
  ];

  static const List<String> monthNames = [
    'Semua Bulan',
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

  static List<int> getAvailableYears() {
    final currentYear = DateTime.now().year;
    return List.generate(5, (index) => currentYear - 2 + index);
  }

  static String getStatusDisplayName(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Menunggu Review';
      case 'approved':
        return 'Disetujui';
      case 'rejected':
        return 'Ditolak';
      default:
        return status;
    }
  }

  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return const Color(0xFFF59E0B);
      case 'approved':
        return const Color(0xFF10B981);
      case 'rejected':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF6B7280);
    }
  }
}
