// Services/time_off_model.dart — FULL REPLACE
import 'dart:io';

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
  final DateTime? approvedAt;
  final String? rejectionReason;
  final String? fileName;
  final String? filePath;
  final int? fileSize;
  final String? fileType;

  // DL specific
  final String? jenisPekerjaan;
  final String? rabType; // 'reimbursement' | 'uang_kantor' | null
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
    this.approvedAt,
    this.rejectionReason,
    this.fileName,
    this.filePath,
    this.fileSize,
    this.fileType,
    // DL
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
  });

  factory TimeOffModel.fromJson(Map<String, dynamic> json) => TimeOffModel(
    id: json['id'] as int?,
    userId: json['userId']?.toString() ?? '',
    jenisTimeOff: json['jenisTimeOff']?.toString() ?? '',
    tanggalMulai: DateTime.parse(json['tanggalMulai'].toString()),
    tanggalSelesai: DateTime.parse(json['tanggalSelesai'].toString()),
    totalHari: json['totalHari'] as int? ?? 0,
    catatan: json['catatan']?.toString(),
    status: json['status']?.toString() ?? 'Pending',
    createdAt: json['createdAt'] != null
        ? DateTime.tryParse(json['createdAt'].toString())
        : null,
    approvedBy: json['approvedBy']?.toString(),
    approvedAt: json['approvedAt'] != null
        ? DateTime.tryParse(json['approvedAt'].toString())
        : null,
    rejectionReason: json['rejectionReason']?.toString(),
    fileName: json['fileName']?.toString(),
    filePath: json['filePath']?.toString(),
    fileSize: json['fileSize'] as int?,
    fileType: json['fileType']?.toString(),
    // DL
    jenisPekerjaan: json['jenisPekerjaan']?.toString(),
    rabType: json['rabType']?.toString(),
    nominalUangKantor: (json['nominalUangKantor'] as num?)?.toDouble(),
    managerUserId: json['managerUserId']?.toString(),
    managerApprovalStatus: json['managerApprovalStatus']?.toString(),
    managerApprovedAt: json['managerApprovedAt'] != null
        ? DateTime.tryParse(json['managerApprovedAt'].toString())
        : null,
    managerRejectionReason: json['managerRejectionReason']?.toString(),
    laporanStatus: json['laporanStatus']?.toString(),
    laporanSubmittedAt: json['laporanSubmittedAt'] != null
        ? DateTime.tryParse(json['laporanSubmittedAt'].toString())
        : null,
    laporanFileName: json['laporanFileName']?.toString(),
    anggaranFileName: json['anggaranFileName']?.toString(),
    reimbursementItems: json['reimbursementItems'] != null
        ? (json['reimbursementItems'] as List)
              .map((e) => ReimbursementItem.fromJson(e as Map<String, dynamic>))
              .toList()
        : null,
  );

  bool get isDinasLuar => jenisTimeOff == 'Dinas Luar';
  bool get needsLaporan =>
      isDinasLuar && status == 'Approved' && laporanStatus == null;
  bool get isMenungguManager => status == 'Menunggu Manager';

  /// User-facing label untuk status
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

// ── Request classes ──────────────────────────────────────────────────────────

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

  factory TimeOffListResponse.fromJson(Map<String, dynamic> json) =>
      TimeOffListResponse(
        data: (json['data'] as List? ?? [])
            .map((e) => TimeOffModel.fromJson(e as Map<String, dynamic>))
            .toList(),
        totalCount: json['totalCount'] as int? ?? 0,
        page: json['page'] as int? ?? 1,
        pageSize: json['pageSize'] as int? ?? 10,
        totalPages: json['totalPages'] as int? ?? 0,
      );
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
