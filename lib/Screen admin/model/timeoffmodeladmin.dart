// Screen admin/model/timeoffmodeladmin.dart — FULL REPLACE
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
      totalSubmissions:
          json['TotalSubmissions'] ?? json['totalSubmissions'] ?? 0,
      pendingCount: json['PendingCount'] ?? json['pendingCount'] ?? 0,
      approvedCount: json['ApprovedCount'] ?? json['approvedCount'] ?? 0,
      rejectedCount: json['RejectedCount'] ?? json['rejectedCount'] ?? 0,
      processedCount: json['ProcessedCount'] ?? json['processedCount'] ?? 0,
      totalPendingDays:
          json['TotalPendingDays'] ?? json['totalPendingDays'] ?? 0,
      totalApprovedDays:
          json['TotalApprovedDays'] ?? json['totalApprovedDays'] ?? 0,
      totalProcessedDays:
          json['TotalProcessedDays'] ?? json['totalProcessedDays'] ?? 0,
      formattedTotalPending:
          json['FormattedTotalPending'] ??
          json['formattedTotalPending'] ??
          '0 hari',
      formattedTotalApproved:
          json['FormattedTotalApproved'] ??
          json['formattedTotalApproved'] ??
          '0 hari',
      formattedTotalProcessed:
          json['FormattedTotalProcessed'] ??
          json['formattedTotalProcessed'] ??
          '0 hari',
    );
  }
}

class AdminTimeOffData {
  // ── Field lama (tidak berubah) ─────────────────────────────────
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

  // ── Field BARU: DL ─────────────────────────────────────────────
  final String? jenisPekerjaan;
  final String? rabType;
  final double? nominalUangKantor;
  final String? orgTarget;
  final String? managerApprovalStatus;

  // ── Field BARU: Laporan DL ─────────────────────────────────────
  final String? laporanStatus;
  final DateTime? laporanSubmittedAt;
  final String? laporanFileName;
  final String? anggaranFileName;

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
    // DL
    this.jenisPekerjaan,
    this.rabType,
    this.nominalUangKantor,
    this.orgTarget,
    this.managerApprovalStatus,
    // Laporan
    this.laporanStatus,
    this.laporanSubmittedAt,
    this.laporanFileName,
    this.anggaranFileName,
  });

  // Helper: cek PascalCase, camelCase, snake_case
  static dynamic _f(Map<String, dynamic> j, String pascal, String snake) {
    final camel = pascal[0].toLowerCase() + pascal.substring(1);
    return j[pascal] ?? j[camel] ?? j[snake];
  }

  static DateTime _parseDate(dynamic v) => v == null
      ? DateTime.now()
      : DateTime.tryParse(v.toString()) ?? DateTime.now();

  static DateTime? _parseDateOpt(dynamic v) =>
      v == null ? null : DateTime.tryParse(v.toString());

  factory AdminTimeOffData.fromJson(Map<String, dynamic> json) {
    return AdminTimeOffData(
      id: (_f(json, 'Id', 'id') ?? 0) as int,
      userId: _f(json, 'UserId', 'userid')?.toString() ?? '',
      userName: _f(json, 'UserName', 'user_name')?.toString() ?? '',
      userEmail: _f(json, 'UserEmail', 'user_email')?.toString() ?? '',
      userPhone: _f(json, 'UserPhone', 'user_phone')?.toString(),
      userJob: _f(json, 'UserJob', 'user_job')?.toString(),
      jenisTimeOff: _f(json, 'JenisTimeOff', 'jenis_timeoff')?.toString() ?? '',
      tanggalMulai: _parseDate(_f(json, 'TanggalMulai', 'tanggal_mulai')),
      tanggalSelesai: _parseDate(_f(json, 'TanggalSelesai', 'tanggal_selesai')),
      totalHari: (_f(json, 'TotalHari', 'total_hari') as num?)?.toInt() ?? 0,
      catatan: _f(json, 'Catatan', 'catatan')?.toString(),
      status: _f(json, 'Status', 'status')?.toString() ?? '',
      submittedAt: _parseDate(_f(json, 'SubmittedAt', 'created_at')),
      updatedAt: _parseDate(_f(json, 'UpdatedAt', 'updated_at')),
      approvedBy: _f(json, 'ApprovedBy', 'approved_by')?.toString(),
      approvedAt: _parseDateOpt(_f(json, 'ApprovedAt', 'approved_at')),
      rejectionReason: _f(
        json,
        'RejectionReason',
        'rejection_reason',
      )?.toString(),
      filePath: _f(json, 'FilePath', 'file_path')?.toString(),
      fileName: _f(json, 'FileName', 'file_name')?.toString(),
      fileSize: (_f(json, 'FileSize', 'file_size') as num?)?.toInt(),
      fileType: _f(json, 'FileType', 'file_type')?.toString(),
      daysSinceSubmitted:
          (_f(json, 'DaysSinceSubmitted', 'days_since_submitted') as num?)
              ?.toInt() ??
          0,
      hasFile: (_f(json, 'HasFile', 'has_file') ?? false) as bool,
      // DL ← BARU
      jenisPekerjaan: _f(json, 'JenisPekerjaan', 'jenis_pekerjaan')?.toString(),
      rabType: _f(json, 'RabType', 'rab_type')?.toString(),
      nominalUangKantor:
          (_f(json, 'NominalUangKantor', 'nominal_uang_kantor') as num?)
              ?.toDouble(),
      orgTarget: _f(json, 'OrgTarget', 'org_target')?.toString(),
      managerApprovalStatus: _f(
        json,
        'ManagerApprovalStatus',
        'manager_approval_status',
      )?.toString(),
      // Laporan ← BARU
      laporanStatus: _f(json, 'LaporanStatus', 'laporan_status')?.toString(),
      laporanSubmittedAt: _parseDateOpt(
        _f(json, 'LaporanSubmittedAt', 'laporan_submitted_at'),
      ),
      laporanFileName: _f(
        json,
        'LaporanFileName',
        'laporan_file_name',
      )?.toString(),
      anggaranFileName: _f(
        json,
        'AnggaranFileName',
        'anggaran_file_name',
      )?.toString(),
    );
  }

  // ── Getters BARU ───────────────────────────────────────────────
  bool get isDinasLuar => jenisTimeOff == 'Dinas Luar';
  bool get hasLaporan => laporanFileName != null || anggaranFileName != null;
  bool get isPendingHrd => status.toLowerCase() == 'pending hrd';
  bool get isPendingDirector => status.toLowerCase() == 'pending director';
  bool get needsReview =>
      status.toLowerCase() == 'pending hrd' ||
      status.toLowerCase() == 'pending director' ||
      status.toLowerCase() == 'pending';

  // ── Getters lama (dipertahankan) ───────────────────────────────
  String get statusText {
    switch (status.toLowerCase()) {
      case 'pending hrd': // ← TAMBAH
        return 'Menunggu HRD'; // ← TAMBAH
      case 'pending director': // ← TAMBAH
        return 'Menunggu Direktur'; // ← TAMBAH
      case 'pending':
        return 'Menunggu Review';
      case 'approved':
        return 'Disetujui';
      case 'rejected':
        return 'Ditolak';
      case 'processed':
        return 'Diproses';
      case 'menunggu manager':
        return 'Menunggu Manager';
      case 'menunggu org':
        return 'Menunggu Divisi';
      case 'menunggu laporan':
        return 'Menunggu Laporan';
      default:
        return status;
    }
  }

  Color get statusColorValue {
    switch (status.toLowerCase()) {
      case 'pending hrd': // ← TAMBAH
        return const Color(0xFFF59E0B); // ← TAMBAH
      case 'pending director': // ← TAMBAH
        return const Color(0xFF8B5CF6); // ← TAMBAH
      case 'pending':
        return const Color(0xFFF59E0B);
      case 'approved':
        return const Color(0xFF10B981);
      case 'rejected':
        return const Color(0xFFEF4444);
      case 'processed':
        return const Color(0xFF3B82F6);
      case 'menunggu manager':
        return const Color(0xFF8B5CF6);
      case 'menunggu org':
        return const Color(0xFF0EA5E9);
      case 'menunggu laporan':
        return const Color(0xFF7C3AED);
      default:
        return const Color(0xFF6B7280);
    }
  }

  String get formattedDate {
    final s =
        '${tanggalMulai.day.toString().padLeft(2, '0')}/${tanggalMulai.month.toString().padLeft(2, '0')}/${tanggalMulai.year}';
    if (tanggalMulai.day == tanggalSelesai.day &&
        tanggalMulai.month == tanggalSelesai.month &&
        tanggalMulai.year == tanggalSelesai.year) {
      return s;
    }
    final e =
        '${tanggalSelesai.day.toString().padLeft(2, '0')}/${tanggalSelesai.month.toString().padLeft(2, '0')}/${tanggalSelesai.year}';
    return '$s - $e';
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

  String get formattedSubmittedDate =>
      '${submittedAt.day.toString().padLeft(2, '0')}/${submittedAt.month.toString().padLeft(2, '0')}/${submittedAt.year} ${submittedAt.hour.toString().padLeft(2, '0')}:${submittedAt.minute.toString().padLeft(2, '0')}';

  String get jenisIcon {
    switch (jenisTimeOff) {
      case 'Izin Tahunan':
        return '🏖️';
      case 'Sakit':
        return '🏥';
      case 'Umrah dan Haji':
        return '🕋';
      case 'Izin Datang Terlambat':
        return '⏰';
      case 'Izin Lahiran':
        return '👶';
      case 'Dinas Luar':
        return '🧳';
      case 'Keluarga Meninggal':
        return '🕯️';
      case 'Cuti Tahunan':
        return '🏖️';
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
  final int annualQuota;
  final int usedDays;
  final int remainingDays;
  final String userId;
  final String name;
  final String email;
  final String? phone;
  final String? jobs;

  final String? companyName;
  final String? department;
  final String? jobPosition;

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
    this.companyName,
    this.department,
    this.jobPosition,
    required this.totalTimeOff,
    required this.pendingCount,
    required this.approvedCount,
    required this.rejectedCount,
    required this.processedCount,
    required this.totalApprovedDays,
    required this.totalRequestedDays,
    required this.annualQuota,
    required this.usedDays,
    required this.remainingDays,
  });

  factory UserWithTimeOffs.fromJson(Map<String, dynamic> json) {
    int toInt(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value.toString()) ?? 0;
    }

    String? toStr(dynamic value) {
      if (value == null) return null;
      final text = value.toString().trim();
      if (text.isEmpty || text.toLowerCase() == 'null') return null;
      return text;
    }

    final organization = toStr(
      json['Organization'] ??
          json['organization'] ??
          json['Department'] ??
          json['department'],
    );

    final jobPosition = toStr(
      json['JobPosition'] ?? json['jobPosition'] ?? json['job_position'],
    );

    final jobs = toStr(
      json['Jobs'] ?? json['jobs'] ?? json['Job'] ?? json['job'] ?? jobPosition,
    );

    return UserWithTimeOffs(
      annualQuota: toInt(json['AnnualQuota'] ?? json['annualQuota']),
      usedDays: toInt(json['UsedDays'] ?? json['usedDays']),
      remainingDays: toInt(json['RemainingDays'] ?? json['remainingDays']),
      userId: toStr(json['UserId'] ?? json['userId'] ?? json['userid']) ?? '',
      name: toStr(json['Name'] ?? json['name']) ?? '',
      email: toStr(json['Email'] ?? json['email'] ?? json['mail']) ?? '',
      phone: toStr(json['Phone'] ?? json['phone']),
      jobs: jobs,

      companyName: toStr(
        json['CompanyName'] ?? json['companyName'] ?? json['company_name'],
      ),
      department: organization,
      jobPosition: jobPosition,

      totalTimeOff: toInt(json['TotalTimeOff'] ?? json['totalTimeOff']),
      pendingCount: toInt(json['PendingCount'] ?? json['pendingCount']),
      approvedCount: toInt(json['ApprovedCount'] ?? json['approvedCount']),
      rejectedCount: toInt(json['RejectedCount'] ?? json['rejectedCount']),
      processedCount: toInt(json['ProcessedCount'] ?? json['processedCount']),
      totalApprovedDays: toInt(
        json['TotalApprovedDays'] ?? json['totalApprovedDays'],
      ),
      totalRequestedDays: toInt(
        json['TotalRequestedDays'] ?? json['totalRequestedDays'],
      ),
    );
  }

  String get formattedTotalDays => '$totalApprovedDays hari disetujui';
}

// ── Request Models (tidak berubah) ─────────────────────────────────────────

class AdminStatisticsRequest {
  final String? adminId;
  final int? year;
  final int? month;

  AdminStatisticsRequest({this.adminId, this.year, this.month});

  Map<String, dynamic> toJson() => {
    'adminId': adminId,
    'year': year,
    'month': month,
  };
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
  Map<String, dynamic> toJson() => {
    'adminId': adminId,
    'status': status,
    'userId': userId,
    'yearFilter': yearFilter,
    'monthFilter': monthFilter,
  };
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
  Map<String, dynamic> toJson() => {
    'id': id,
    'status': status,
    'approvedBy': approvedBy,
    'rejectionReason': rejectionReason,
    'adminId': adminId,
  };
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
  Map<String, dynamic> toJson() => {
    'id': id,
    'processedBy': processedBy,
    'adminId': adminId,
  };
}

// ── Response Models (tidak berubah) ────────────────────────────────────────

class ApiResponse<T> {
  final bool success;
  final String message;
  final T? data;
  ApiResponse({required this.success, required this.message, this.data});
  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T? Function(dynamic)? fromJsonT,
  ) => ApiResponse<T>(
    success: json['success'] ?? json['Success'] ?? false,
    message: json['message'] ?? json['Message'] ?? '',
    data: json['data'] != null && fromJsonT != null
        ? fromJsonT(json['data'])
        : json['Data'] != null && fromJsonT != null
        ? fromJsonT(json['Data'])
        : null,
  );
}

class TimeOffAdminListResponse {
  final List<AdminTimeOffData> data;
  TimeOffAdminListResponse({required this.data});
  factory TimeOffAdminListResponse.fromJson(List<dynamic> jsonList) =>
      TimeOffAdminListResponse(
        data: jsonList.map((i) => AdminTimeOffData.fromJson(i)).toList(),
      );
}

class UserTimeOffListResponse {
  final List<UserWithTimeOffs> data;
  UserTimeOffListResponse({required this.data});
  factory UserTimeOffListResponse.fromJson(List<dynamic> jsonList) =>
      UserTimeOffListResponse(
        data: jsonList.map((i) => UserWithTimeOffs.fromJson(i)).toList(),
      );
}
