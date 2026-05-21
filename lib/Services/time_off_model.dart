// Services/time_off_model.dart — FULL REPLACE
// ignore_for_file: prefer_const_constructors
import 'dart:io';
import 'dart:convert';

class TimeOffModel {
  final int? id;
  final String userId;
  final String jenisTimeOff;
  final DateTime tanggalMulai;
  final DateTime tanggalSelesai;
  final int totalHari;
  final String? catatan;
  final String status;
  final DateTime? createdAt;
  final String? approvedBy;
  final String? approverName;
  final DateTime? approvedAt;
  final String? rejectionReason;
  final String? fileName;
  final String? filePath;
  final int? fileSize;
  final String? fileType;

  // DL specific
  final String? jenisPekerjaan;
  final String? rabType;
  final double? nominalUangKantor;
  final String? managerUserId;
  final String? managerApprovalStatus;
  final DateTime? managerApprovedAt;
  final String? managerRejectionReason;
  final String? laporanStatus;
  final DateTime? laporanSubmittedAt;
  final String? laporanFileName;
  final String? anggaranFileName;
  final List<ReimbursementItem>? reimbursementItems;
  final List<TimeOffFileItem>? files;

  const TimeOffModel({
    this.id,
    required this.userId,
    required this.jenisTimeOff,
    required this.tanggalMulai,
    required this.tanggalSelesai,
    required this.totalHari,
    this.catatan,
    this.status = 'Pending',
    this.createdAt,
    this.approvedBy,
    this.approverName,
    this.approvedAt,
    this.rejectionReason,
    this.fileName,
    this.filePath,
    this.fileSize,
    this.fileType,
    this.jenisPekerjaan,
    this.rabType,
    this.nominalUangKantor,
    this.managerUserId,
    this.managerApprovalStatus,
    this.managerApprovedAt,
    this.managerRejectionReason,
    this.laporanStatus,
    this.laporanSubmittedAt,
    this.laporanFileName,
    this.anggaranFileName,
    this.reimbursementItems,
    this.files,
  });

  factory TimeOffModel.fromJson(Map<String, dynamic> json) {
    final reimbursementList = _parseJsonList(
      json['reimbursementItems'] ?? json['reimbursement_items'],
    );

    final fileList = _parseJsonList(json['files']);

    return TimeOffModel(
      id: _toInt(json['id'] ?? json['Id']),

      userId:
          json['userId']?.toString() ??
          json['UserId']?.toString() ??
          json['userid']?.toString() ??
          '',

      jenisTimeOff:
          json['jenisTimeOff']?.toString() ??
          json['JenisTimeOff']?.toString() ??
          json['jenis_timeoff']?.toString() ??
          '',

      tanggalMulai: _parseRequiredDate(
        json['tanggalMulai'] ?? json['TanggalMulai'] ?? json['tanggal_mulai'],
      ),

      tanggalSelesai: _parseRequiredDate(
        json['tanggalSelesai'] ??
            json['TanggalSelesai'] ??
            json['tanggal_selesai'],
      ),

      totalHari:
          _toInt(
            json['totalHari'] ?? json['TotalHari'] ?? json['total_hari'],
          ) ??
          0,

      catatan: json['catatan']?.toString() ?? json['Catatan']?.toString(),

      status:
          json['status']?.toString() ?? json['Status']?.toString() ?? 'Pending',

      createdAt: _parseDate(
        json['createdAt'] ?? json['CreatedAt'] ?? json['created_at'],
      ),

      approvedBy:
          json['approvedBy']?.toString() ??
          json['ApprovedBy']?.toString() ??
          json['approved_by']?.toString(),

      approverName:
          json['approverName']?.toString() ??
          json['ApproverName']?.toString() ??
          json['approver_name']?.toString(),

      approvedAt: _parseDate(
        json['approvedAt'] ?? json['ApprovedAt'] ?? json['approved_at'],
      ),

      rejectionReason:
          json['rejectionReason']?.toString() ??
          json['RejectionReason']?.toString() ??
          json['rejection_reason']?.toString(),

      fileName:
          json['fileName']?.toString() ??
          json['FileName']?.toString() ??
          json['file_name']?.toString(),

      filePath:
          json['filePath']?.toString() ??
          json['FilePath']?.toString() ??
          json['file_path']?.toString(),

      fileSize: _toInt(
        json['fileSize'] ?? json['FileSize'] ?? json['file_size'],
      ),

      fileType:
          json['fileType']?.toString() ??
          json['FileType']?.toString() ??
          json['file_type']?.toString(),

      jenisPekerjaan:
          json['jenisPekerjaan']?.toString() ??
          json['JenisPekerjaan']?.toString() ??
          json['jenis_pekerjaan']?.toString(),

      rabType:
          json['rabType']?.toString() ??
          json['RabType']?.toString() ??
          json['rab_type']?.toString(),

      nominalUangKantor: _toDouble(
        json['nominalUangKantor'] ??
            json['NominalUangKantor'] ??
            json['nominal_uang_kantor'],
      ),

      managerUserId:
          json['managerUserId']?.toString() ??
          json['ManagerUserId']?.toString() ??
          json['manager_userid']?.toString(),

      managerApprovalStatus:
          json['managerApprovalStatus']?.toString() ??
          json['ManagerApprovalStatus']?.toString() ??
          json['manager_approval_status']?.toString(),

      managerApprovedAt: _parseDate(
        json['managerApprovedAt'] ??
            json['ManagerApprovedAt'] ??
            json['manager_approved_at'],
      ),

      managerRejectionReason:
          json['managerRejectionReason']?.toString() ??
          json['ManagerRejectionReason']?.toString() ??
          json['manager_rejection_reason']?.toString(),

      laporanStatus:
          json['laporanStatus']?.toString() ??
          json['LaporanStatus']?.toString() ??
          json['laporan_status']?.toString(),

      laporanSubmittedAt: _parseDate(
        json['laporanSubmittedAt'] ??
            json['LaporanSubmittedAt'] ??
            json['laporan_submitted_at'],
      ),

      laporanFileName:
          json['laporanFileName']?.toString() ??
          json['LaporanFileName']?.toString() ??
          json['laporan_file_name']?.toString(),

      anggaranFileName:
          json['anggaranFileName']?.toString() ??
          json['AnggaranFileName']?.toString() ??
          json['anggaran_file_name']?.toString(),

      reimbursementItems: reimbursementList
          ?.map(
            (e) =>
                ReimbursementItem.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),

      files: fileList
          ?.map(
            (e) =>
                TimeOffFileItem.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
    );
  }

  static List<dynamic>? _parseJsonList(dynamic value) {
    if (value == null) return null;

    if (value is List) return value;

    if (value is String && value.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) return decoded;
      } catch (_) {
        return null;
      }
    }

    return null;
  }

  static DateTime _parseRequiredDate(dynamic value) {
    if (value == null || value.toString().isEmpty) {
      return DateTime.now();
    }

    return DateTime.tryParse(value.toString()) ?? DateTime.now();
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null || value.toString().isEmpty) return null;
    return DateTime.tryParse(value.toString());
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  bool get isDinasLuar => jenisTimeOff == 'Dinas Luar';

  bool get needsLaporan =>
      isDinasLuar && status == 'Approved' && laporanStatus == null;

  bool get isMenungguManager => status == 'Menunggu Manager';

  List<TimeOffFileItem> get allFiles {
    final list = <TimeOffFileItem>[];

    if (files != null && files!.isNotEmpty) {
      list.addAll(files!);
    }

    if (fileName != null && fileName!.isNotEmpty && list.isEmpty) {
      list.add(
        TimeOffFileItem(
          id: 0,
          timeOffId: id ?? 0,
          fileName: fileName!,
          fileSize: fileSize,
          fileType: fileType,
          urutan: 1,
        ),
      );
    }

    return list;
  }

  String get statusLabel {
    switch (status) {
      case 'Pending':
        return 'Menunggu Persetujuan';
      case 'Menunggu Manager':
        return 'Menunggu Manager';
      case 'Approved':
        return 'Disetujui';
      case 'Rejected':
        return 'Ditolak';
      case 'Processed':
        return 'Diproses';
      default:
        return status;
    }
  }
}
// ── Reimbursement item ────────────────────────────────────────────────────────

class ReimbursementItem {
  final int? id;
  final String namaItem;
  final double nominal;
  final String? keterangan;

  const ReimbursementItem({
    this.id,
    required this.namaItem,
    required this.nominal,
    this.keterangan,
  });

  factory ReimbursementItem.fromJson(Map<String, dynamic> json) =>
      ReimbursementItem(
        id: json['id'] as int?,
        namaItem:
            json['nama_item']?.toString() ?? json['namaItem']?.toString() ?? '',
        nominal: (json['nominal'] as num?)?.toDouble() ?? 0,
        keterangan: json['keterangan']?.toString(),
      );

  Map<String, dynamic> toJson() => {
    'nama_item': namaItem,
    'nominal': nominal,
    'keterangan': keterangan,
  };
}

// ── TimeOffFileItem ───────────────────────────────────────────────────────────

class TimeOffFileItem {
  final int id;
  final int timeOffId;
  final String fileName;
  final int? fileSize;
  final String? fileType;
  final int urutan;

  const TimeOffFileItem({
    required this.id,
    required this.timeOffId,
    required this.fileName,
    this.fileSize,
    this.fileType,
    required this.urutan,
  });

  factory TimeOffFileItem.fromJson(Map<String, dynamic> json) {
    return TimeOffFileItem(
      id: _toInt(json['id'] ?? json['Id']) ?? 0,
      timeOffId:
          _toInt(
            json['timeOffId'] ??
                json['TimeOffId'] ??
                json['timeoff_id'] ??
                json['timeoffId'],
          ) ??
          0,
      fileName:
          (json['fileName'] ?? json['FileName'] ?? json['file_name'] ?? '')
              .toString(),
      fileSize: _toInt(
        json['fileSize'] ?? json['FileSize'] ?? json['file_size'],
      ),
      fileType: (json['fileType'] ?? json['FileType'] ?? json['file_type'])
          ?.toString(),
      urutan: _toInt(json['urutan'] ?? json['Urutan']) ?? 1,
    );
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'timeOffId': timeOffId,
    'fileName': fileName,
    'fileSize': fileSize,
    'fileType': fileType,
    'urutan': urutan,
  };

  String get ext {
    if (!fileName.contains('.')) return '';
    return fileName.split('.').last.toLowerCase();
  }

  bool get isImage => ['jpg', 'jpeg', 'png'].contains(ext);

  bool get isPdf => ext == 'pdf';

  String get sizeLabel {
    if (fileSize == null || fileSize == 0) return '';

    final mb = fileSize! / (1024 * 1024);

    if (mb >= 1) {
      return '${mb.toStringAsFixed(1)} MB';
    }

    return '${(fileSize! / 1024).toStringAsFixed(0)} KB';
  }
}
// ── Request classes ───────────────────────────────────────────────────────────

class TimeOffRequest {
  final String userId;
  final String jenisTimeOff;
  final DateTime tanggalMulai;
  final DateTime tanggalSelesai;
  final String? catatan;
  final File? receiptFile;
  // DL
  final String? jenisPekerjaan;
  final String? rabType;
  final double? nominalUangKantor;
  final List<ReimbursementItem>? reimbursementItems;

  const TimeOffRequest({
    required this.userId,
    required this.jenisTimeOff,
    required this.tanggalMulai,
    required this.tanggalSelesai,
    this.catatan,
    this.receiptFile,
    this.jenisPekerjaan,
    this.rabType,
    this.nominalUangKantor,
    this.reimbursementItems,
  });
}

class UpdateTimeOffRequest {
  final int id;
  final String userId;
  final String jenisTimeOff;
  final DateTime tanggalMulai;
  final DateTime tanggalSelesai;
  final String? catatan;
  final File? receiptFile;
  // DL
  final String? jenisPekerjaan;
  final String? rabType;
  final double? nominalUangKantor;
  final List<ReimbursementItem>? reimbursementItems;

  const UpdateTimeOffRequest({
    required this.id,
    required this.userId,
    required this.jenisTimeOff,
    required this.tanggalMulai,
    required this.tanggalSelesai,
    this.catatan,
    this.receiptFile,
    this.jenisPekerjaan,
    this.rabType,
    this.nominalUangKantor,
    this.reimbursementItems,
  });
}

class DlLaporanRequest {
  final int timeOffId;
  final String userId;
  final File laporanFile;
  final File anggaranFile;

  const DlLaporanRequest({
    required this.timeOffId,
    required this.userId,
    required this.laporanFile,
    required this.anggaranFile,
  });
}

/// Upload satu atau lebih file ke time off yang sudah ada
class UploadTimeOffFilesRequest {
  final int timeOffId;
  final String userId;
  final List<File> files;

  const UploadTimeOffFilesRequest({
    required this.timeOffId,
    required this.userId,
    required this.files,
  });
}

/// Hapus satu file dari time off
class DeleteTimeOffFileRequest {
  final int fileId;
  final int timeOffId;
  final String userId;

  const DeleteTimeOffFileRequest({
    required this.fileId,
    required this.timeOffId,
    required this.userId,
  });
}

// ── Response classes ──────────────────────────────────────────────────────────

class ApiResponse<T> {
  final bool success;
  final String message;
  final T? data;

  const ApiResponse({required this.success, required this.message, this.data});
}

class TimeOffListResponse {
  final List<TimeOffModel> data;
  final int totalCount;
  final int page;
  final int pageSize;
  final int totalPages;

  const TimeOffListResponse({
    required this.data,
    required this.totalCount,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  factory TimeOffListResponse.fromJson(Map<String, dynamic> json) {
    // API return PascalCase (Data, TotalCount) atau camelCase (data, totalCount)
    final rawList = (json['Data'] ?? json['data']) as List? ?? [];
    return TimeOffListResponse(
      data: rawList
          .map((e) => TimeOffModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalCount: (json['TotalCount'] ?? json['totalCount'] ?? 0) as int,
      page: (json['Page'] ?? json['page'] ?? 1) as int,
      pageSize: (json['PageSize'] ?? json['pageSize'] ?? 10) as int,
      totalPages: (json['TotalPages'] ?? json['totalPages'] ?? 0) as int,
    );
  }
}

class AnnualQuota {
  final String userId;
  final int tahun;
  final int quotaAwal;
  final int quotaTerpakai;
  final int quotaSisa;

  const AnnualQuota({
    required this.userId,
    required this.tahun,
    required this.quotaAwal,
    required this.quotaTerpakai,
    required this.quotaSisa,
  });

  factory AnnualQuota.fromJson(Map<String, dynamic> json) => AnnualQuota(
    userId: json['userId']?.toString() ?? '',
    tahun: json['tahun'] as int? ?? 0,
    quotaAwal: json['quotaAwal'] as int? ?? 0,
    quotaTerpakai: json['quotaTerpakai'] as int? ?? 0,
    quotaSisa: json['quotaSisa'] as int? ?? 0,
  );
}
