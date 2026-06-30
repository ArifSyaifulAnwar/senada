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

  const TimeOffAdminStatistics({
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

  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  factory TimeOffAdminStatistics.fromJson(Map<String, dynamic> json) {
    return TimeOffAdminStatistics(
      totalSubmissions: _toInt(
        json['TotalSubmissions'] ?? json['totalSubmissions'],
      ),
      pendingCount: _toInt(json['PendingCount'] ?? json['pendingCount']),
      approvedCount: _toInt(json['ApprovedCount'] ?? json['approvedCount']),
      rejectedCount: _toInt(json['RejectedCount'] ?? json['rejectedCount']),
      processedCount: _toInt(json['ProcessedCount'] ?? json['processedCount']),
      totalPendingDays: _toInt(
        json['TotalPendingDays'] ?? json['totalPendingDays'],
      ),
      totalApprovedDays: _toInt(
        json['TotalApprovedDays'] ?? json['totalApprovedDays'],
      ),
      totalProcessedDays: _toInt(
        json['TotalProcessedDays'] ?? json['totalProcessedDays'],
      ),
      formattedTotalPending:
          (json['FormattedTotalPending'] ?? json['formattedTotalPending'])
              ?.toString() ??
          '0 hari',
      formattedTotalApproved:
          (json['FormattedTotalApproved'] ?? json['formattedTotalApproved'])
              ?.toString() ??
          '0 hari',
      formattedTotalProcessed:
          (json['FormattedTotalProcessed'] ?? json['formattedTotalProcessed'])
              ?.toString() ??
          '0 hari',
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
  final String? jenisPekerjaan;
  final String? rabType;
  final double? nominalUangKantor;
  final String? orgTarget;
  final String? managerApprovalStatus;
  final String? laporanStatus;
  final DateTime? laporanSubmittedAt;
  final String? laporanFileName;
  final String? laporanFilePath;
  final String? anggaranFileName;
  final String? anggaranFilePath;
  final bool requiresDirectorApproval;
  final String? directorUserId;

  const AdminTimeOffData({
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
    this.jenisPekerjaan,
    this.rabType,
    this.nominalUangKantor,
    this.orgTarget,
    this.managerApprovalStatus,
    this.laporanStatus,
    this.laporanSubmittedAt,
    this.laporanFileName,
    this.laporanFilePath,
    this.anggaranFileName,
    this.anggaranFilePath,
    this.requiresDirectorApproval = false,
    this.directorUserId,
  });

  static dynamic _f(Map<String, dynamic> json, String pascal, String snake) {
    final camel = pascal[0].toLowerCase() + pascal.substring(1);
    return json[pascal] ?? json[camel] ?? json[snake];
  }

  static String? _toNullableString(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty || text.toLowerCase() == 'null') return null;
    return text;
  }

  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static bool _toBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value?.toString().trim().toLowerCase();
    return text == 'true' || text == '1' || text == 'yes';
  }

  static DateTime _parseDateRequired(dynamic value) {
    if (value == null) return DateTime.now();
    return DateTime.tryParse(value.toString()) ?? DateTime.now();
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  static int? _toIntOrNull(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static bool _hasText(String? value) {
    final text = value?.trim();
    return text != null && text.isNotEmpty && text.toLowerCase() != 'null';
  }

  factory AdminTimeOffData.fromJson(Map<String, dynamic> json) {
    return AdminTimeOffData(
      id: _toInt(_f(json, 'Id', 'id')),
      userId: _toNullableString(_f(json, 'UserId', 'userid')) ?? '',
      userName: _toNullableString(_f(json, 'UserName', 'user_name')) ?? '',
      userEmail: _toNullableString(_f(json, 'UserEmail', 'user_email')) ?? '',
      userPhone: _toNullableString(_f(json, 'UserPhone', 'user_phone')),
      userJob: _toNullableString(_f(json, 'UserJob', 'user_job')),
      jenisTimeOff:
          _toNullableString(_f(json, 'JenisTimeOff', 'jenis_timeoff')) ?? '',
      tanggalMulai: _parseDateRequired(
        _f(json, 'TanggalMulai', 'tanggal_mulai'),
      ),
      tanggalSelesai: _parseDateRequired(
        _f(json, 'TanggalSelesai', 'tanggal_selesai'),
      ),
      totalHari: _toInt(_f(json, 'TotalHari', 'total_hari')),
      catatan: _toNullableString(_f(json, 'Catatan', 'catatan')),
      status: _toNullableString(_f(json, 'Status', 'status')) ?? '',
      submittedAt: _parseDateRequired(_f(json, 'SubmittedAt', 'created_at')),
      updatedAt: _parseDateRequired(_f(json, 'UpdatedAt', 'updated_at')),
      approvedBy: _toNullableString(_f(json, 'ApprovedBy', 'approved_by')),
      approvedAt: _parseDate(_f(json, 'ApprovedAt', 'approved_at')),
      rejectionReason: _toNullableString(
        _f(json, 'RejectionReason', 'rejection_reason'),
      ),
      filePath: _toNullableString(_f(json, 'FilePath', 'file_path')),
      fileName: _toNullableString(_f(json, 'FileName', 'file_name')),
      fileSize: _toIntOrNull(_f(json, 'FileSize', 'file_size')),
      fileType: _toNullableString(_f(json, 'FileType', 'file_type')),
      daysSinceSubmitted: _toInt(
        _f(json, 'DaysSinceSubmitted', 'days_since_submitted'),
      ),
      hasFile: _toBool(_f(json, 'HasFile', 'has_file')),
      jenisPekerjaan: _toNullableString(
        _f(json, 'JenisPekerjaan', 'jenis_pekerjaan'),
      ),
      rabType: _toNullableString(_f(json, 'RabType', 'rab_type')),
      nominalUangKantor: _toDouble(
        _f(json, 'NominalUangKantor', 'nominal_uang_kantor'),
      ),
      orgTarget: _toNullableString(_f(json, 'OrgTarget', 'org_target')),
      managerApprovalStatus: _toNullableString(
        _f(json, 'ManagerApprovalStatus', 'manager_approval_status'),
      ),
      laporanStatus: _toNullableString(
        _f(json, 'LaporanStatus', 'laporan_status'),
      ),
      laporanSubmittedAt: _parseDate(
        _f(json, 'LaporanSubmittedAt', 'laporan_submitted_at'),
      ),
      laporanFileName: _toNullableString(
        _f(json, 'LaporanFileName', 'laporan_file_name'),
      ),
      laporanFilePath: _toNullableString(
        _f(json, 'LaporanFilePath', 'laporan_file_path') ??
            json['laporanFilePath'],
      ),
      anggaranFileName: _toNullableString(
        _f(json, 'AnggaranFileName', 'anggaran_file_name'),
      ),
      anggaranFilePath: _toNullableString(
        _f(json, 'AnggaranFilePath', 'anggaran_file_path') ??
            json['anggaranFilePath'],
      ),
      requiresDirectorApproval: _toBool(
        _f(json, 'RequiresDirectorApproval', 'requires_director_approval'),
      ),
      directorUserId: _toNullableString(
        _f(json, 'DirectorUserId', 'director_user_id'),
      ),
    );
  }

  // ── Getters ──────────────────────────────────────────────────────────────

  bool get isDinasLuar => jenisTimeOff.trim().toLowerCase() == 'dinas luar';

  bool get hasLaporanFile =>
      _hasText(laporanFileName) || _hasText(laporanFilePath);

  bool get hasAnggaranFile =>
      _hasText(anggaranFileName) || _hasText(anggaranFilePath);

  bool get hasLaporanWorkflowSubmitted {
    final laporan = (laporanStatus ?? '').trim().toLowerCase();
    final currentStatus = status.trim().toLowerCase();

    if (laporan == 'submitted' ||
        laporan == 'approved' ||
        laporan == 'verified' ||
        laporan == 'completed') {
      return true;
    }

    return currentStatus == 'pending laporan head' ||
        currentStatus == 'pending laporan hrd' ||
        currentStatus == 'menunggu verifikasi head' ||
        currentStatus == 'menunggu verifikasi hrd' ||
        currentStatus == 'laporan disetujui' ||
        currentStatus == 'laporan approved';
  }

  bool get hasLaporan =>
      hasLaporanFile || hasAnggaranFile || hasLaporanWorkflowSubmitted;

  String get laporanDisplayFileName {
    if (_hasText(laporanFileName)) return laporanFileName!.trim();
    if (_hasText(laporanFilePath)) {
      final name = laporanFilePath!
          .replaceAll('\\', '/')
          .split('/')
          .last
          .trim();
      if (name.isNotEmpty) return name;
    }
    return hasLaporanWorkflowSubmitted
        ? 'Laporan Dinas Luar (sudah diupload)'
        : 'Laporan Dinas Luar';
  }

  String get anggaranDisplayFileName {
    if (_hasText(anggaranFileName)) return anggaranFileName!.trim();
    if (_hasText(anggaranFilePath)) {
      final name = anggaranFilePath!
          .replaceAll('\\', '/')
          .split('/')
          .last
          .trim();
      if (name.isNotEmpty) return name;
    }
    return 'Laporan Anggaran';
  }

  bool get isPendingHrd => status.trim().toLowerCase() == 'pending hrd';

  bool get isPendingDirector =>
      status.trim().toLowerCase() == 'pending director';

  bool get needsReview {
    final s = status.trim().toLowerCase();
    return s == 'pending' || s == 'pending hrd' || s == 'pending director';
  }

  String get statusText {
    switch (status.trim().toLowerCase()) {
      case 'pending hrd':
        return 'Menunggu HRD';
      case 'pending director':
        return 'Menunggu Direktur';
      case 'pending':
        return 'Menunggu Review';
      case 'approved':
      case 'disetujui':
        return 'Disetujui';
      case 'rejected':
      case 'ditolak':
        return 'Ditolak';
      case 'processed':
        return 'Diproses';
      case 'menunggu manager':
        return 'Menunggu Manager';
      case 'menunggu org':
        return 'Menunggu Divisi';
      case 'menunggu laporan':
        return 'Menunggu Laporan';
      case 'pending laporan head':
        return 'Menunggu Verifikasi Head';
      case 'pending laporan hrd':
        return 'Menunggu Verifikasi HRD';
      case 'laporan ditolak':
        return 'Laporan Ditolak';
      case 'menunggu verifikasi head':
        return 'Menunggu Verifikasi Head';
      case 'menunggu verifikasi hrd':
        return 'Menunggu Verifikasi HRD';
      case 'pending finance':
        return 'Menunggu Finance';
      default:
        return status;
    }
  }

  Color get statusColorValue {
    switch (status.trim().toLowerCase()) {
      case 'pending':
      case 'pending hrd':
        return const Color(0xFFF59E0B);
      case 'pending director':
        return const Color(0xFF8B5CF6);
      case 'approved':
      case 'disetujui':
        return const Color(0xFF10B981);
      case 'rejected':
      case 'ditolak':
      case 'revisi':
      case 'laporan ditolak':
        return const Color(0xFFEF4444);
      case 'processed':
        return const Color(0xFF3B82F6);
      case 'menunggu manager':
      case 'menunggu verifikasi head':
      case 'menunggu verifikasi hrd':
      case 'pending laporan head':
      case 'pending laporan hrd':
        return const Color(0xFF6366F1);
      case 'menunggu org':
        return const Color(0xFF0EA5E9);
      case 'menunggu laporan':
        return const Color(0xFF7C3AED);
      case 'pending finance':
        return const Color(0xFF14B8A6);
      default:
        return const Color(0xFF6B7280);
    }
  }

  String get formattedDate {
    String fmt(DateTime date) =>
        '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
    final start = fmt(tanggalMulai);
    final end = fmt(tanggalSelesai);
    return start == end ? start : '$start - $end';
  }

  String get urgencyText {
    if (status.trim().toLowerCase() != 'pending') return '';
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
      '${submittedAt.day.toString().padLeft(2, '0')}/'
      '${submittedAt.month.toString().padLeft(2, '0')}/'
      '${submittedAt.year} '
      '${submittedAt.hour.toString().padLeft(2, '0')}:'
      '${submittedAt.minute.toString().padLeft(2, '0')}';

  String get jenisIcon {
    switch (jenisTimeOff) {
      case 'Izin Tahunan':
      case 'Cuti Tahunan':
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

  const UserWithTimeOffs({
    required this.annualQuota,
    required this.usedDays,
    required this.remainingDays,
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
  });

  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  static String? _toStringOrNull(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty || text.toLowerCase() == 'null' ? null : text;
  }

  factory UserWithTimeOffs.fromJson(Map<String, dynamic> json) {
    final organization = _toStringOrNull(
      json['Organization'] ??
          json['organization'] ??
          json['Department'] ??
          json['department'],
    );

    final jobPosition = _toStringOrNull(
      json['JobPosition'] ?? json['jobPosition'] ?? json['job_position'],
    );

    final jobs =
        _toStringOrNull(
          json['Jobs'] ?? json['jobs'] ?? json['Job'] ?? json['job'],
        ) ??
        jobPosition;

    return UserWithTimeOffs(
      annualQuota: _toInt(json['AnnualQuota'] ?? json['annualQuota']),
      usedDays: _toInt(json['UsedDays'] ?? json['usedDays']),
      remainingDays: _toInt(json['RemainingDays'] ?? json['remainingDays']),
      userId:
          _toStringOrNull(json['UserId'] ?? json['userId'] ?? json['userid']) ??
          '',
      name: _toStringOrNull(json['Name'] ?? json['name']) ?? '',
      email:
          _toStringOrNull(json['Email'] ?? json['email'] ?? json['mail']) ?? '',
      phone: _toStringOrNull(json['Phone'] ?? json['phone']),
      jobs: jobs,
      companyName: _toStringOrNull(
        json['CompanyName'] ?? json['companyName'] ?? json['company_name'],
      ),
      department: organization,
      jobPosition: jobPosition,
      totalTimeOff: _toInt(json['TotalTimeOff'] ?? json['totalTimeOff']),
      pendingCount: _toInt(json['PendingCount'] ?? json['pendingCount']),
      approvedCount: _toInt(json['ApprovedCount'] ?? json['approvedCount']),
      rejectedCount: _toInt(json['RejectedCount'] ?? json['rejectedCount']),
      processedCount: _toInt(json['ProcessedCount'] ?? json['processedCount']),
      totalApprovedDays: _toInt(
        json['TotalApprovedDays'] ?? json['totalApprovedDays'],
      ),
      totalRequestedDays: _toInt(
        json['TotalRequestedDays'] ?? json['totalRequestedDays'],
      ),
    );
  }

  String get formattedTotalDays => '$totalApprovedDays hari disetujui';
}

class AdminStatisticsRequest {
  final String? adminId;
  final int? year;
  final int? month;

  const AdminStatisticsRequest({this.adminId, this.year, this.month});

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

  const AdminTimeOffListRequest({
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

  const ReviewTimeOffRequest({
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

  const MarkProcessedRequest({
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

class ApiResponse<T> {
  final bool success;
  final String message;
  final T? data;

  const ApiResponse({required this.success, required this.message, this.data});

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T? Function(dynamic)? fromJsonT,
  ) {
    final rawData = json['data'] ?? json['Data'];
    return ApiResponse<T>(
      success: (json['success'] ?? json['Success']) == true,
      message: (json['message'] ?? json['Message'] ?? '').toString(),
      data: rawData != null && fromJsonT != null ? fromJsonT(rawData) : null,
    );
  }
}

class TimeOffAdminListResponse {
  final List<AdminTimeOffData> data;

  const TimeOffAdminListResponse({required this.data});

  factory TimeOffAdminListResponse.fromJson(
    List<dynamic> jsonList,
  ) => TimeOffAdminListResponse(
    data: jsonList
        .map(
          (item) =>
              AdminTimeOffData.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(),
  );
}

class UserTimeOffListResponse {
  final List<UserWithTimeOffs> data;

  const UserTimeOffListResponse({required this.data});

  factory UserTimeOffListResponse.fromJson(
    List<dynamic> jsonList,
  ) => UserTimeOffListResponse(
    data: jsonList
        .map(
          (item) =>
              UserWithTimeOffs.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(),
  );
}
