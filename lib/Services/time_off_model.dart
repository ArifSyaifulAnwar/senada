// Services/time_off_model.dart — FULL REPLACE
// ignore_for_file: prefer_const_constructors
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
  });

  factory TimeOffModel.fromJson(Map<String, dynamic> json) => TimeOffModel(
        id:            json['id'] as int?,
        userId:        json['userId']?.toString() ?? json['userid']?.toString() ?? '',
        jenisTimeOff:  json['jenisTimeOff']?.toString() ?? json['jenis_timeoff']?.toString() ?? '',
        tanggalMulai:  DateTime.parse(
                          (json['tanggalMulai'] ?? json['tanggal_mulai']).toString()),
        tanggalSelesai: DateTime.parse(
                          (json['tanggalSelesai'] ?? json['tanggal_selesai']).toString()),
        totalHari:     json['totalHari'] as int? ?? json['total_hari'] as int? ?? 0,
        catatan:       json['catatan']?.toString(),
        status:        json['status']?.toString() ?? 'Pending',
        createdAt:     _parseDate(json['createdAt'] ?? json['created_at']),
        approvedBy:    json['approvedBy']?.toString() ?? json['approved_by']?.toString(),
        approverName:  json['approverName']?.toString() ?? json['approver_name']?.toString(),
        approvedAt:    _parseDate(json['approvedAt'] ?? json['approved_at']),
        rejectionReason: json['rejectionReason']?.toString() ?? json['rejection_reason']?.toString(),
        fileName:      json['fileName']?.toString() ?? json['file_name']?.toString(),
        filePath:      json['filePath']?.toString() ?? json['file_path']?.toString(),
        fileSize:      json['fileSize'] as int? ?? json['file_size'] as int?,
        fileType:      json['fileType']?.toString() ?? json['file_type']?.toString(),
        // DL
        jenisPekerjaan:        json['jenisPekerjaan']?.toString() ?? json['jenis_pekerjaan']?.toString(),
        rabType:               json['rabType']?.toString() ?? json['rab_type']?.toString(),
        nominalUangKantor:     (json['nominalUangKantor'] ?? json['nominal_uang_kantor'] as num?)?.toDouble(),
        managerUserId:         json['managerUserId']?.toString() ?? json['manager_userid']?.toString(),
        managerApprovalStatus: json['managerApprovalStatus']?.toString() ?? json['manager_approval_status']?.toString(),
        managerApprovedAt:     _parseDate(json['managerApprovedAt'] ?? json['manager_approved_at']),
        managerRejectionReason: json['managerRejectionReason']?.toString() ?? json['manager_rejection_reason']?.toString(),
        laporanStatus:         json['laporanStatus']?.toString() ?? json['laporan_status']?.toString(),
        laporanSubmittedAt:    _parseDate(json['laporanSubmittedAt'] ?? json['laporan_submitted_at']),
        laporanFileName:       json['laporanFileName']?.toString() ?? json['laporan_file_name']?.toString(),
        anggaranFileName:      json['anggaranFileName']?.toString() ?? json['anggaran_file_name']?.toString(),
        reimbursementItems: json['reimbursementItems'] != null
            ? (json['reimbursementItems'] as List)
                .map((e) => ReimbursementItem.fromJson(e as Map<String, dynamic>))
                .toList()
            : null,
      );

  static DateTime? _parseDate(dynamic val) {
    if (val == null) return null;
    return DateTime.tryParse(val.toString());
  }

  bool get isDinasLuar        => jenisTimeOff == 'Dinas Luar';
  bool get needsLaporan       => isDinasLuar && status == 'Approved' && laporanStatus == null;
  bool get isMenungguManager  => status == 'Menunggu Manager';

  String get statusLabel {
    switch (status) {
      case 'Pending':           return 'Menunggu Persetujuan';
      case 'Menunggu Manager':  return 'Menunggu Manager';
      case 'Approved':          return 'Disetujui';
      case 'Rejected':          return 'Ditolak';
      case 'Processed':         return 'Diproses';
      default:                  return status;
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
        id:         json['id'] as int?,
        namaItem:   json['nama_item']?.toString() ?? json['namaItem']?.toString() ?? '',
        nominal:    (json['nominal'] as num?)?.toDouble() ?? 0,
        keterangan: json['keterangan']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'nama_item':  namaItem,
        'nominal':    nominal,
        'keterangan': keterangan,
      };
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

// ── Response classes ──────────────────────────────────────────────────────────

class ApiResponse<T> {
  final bool success;
  final String message;
  final T? data;

  const ApiResponse({
    required this.success,
    required this.message,
    this.data,
  });
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
    // API bisa return PascalCase (Data, TotalCount) atau camelCase (data, totalCount)
    final rawList = (json['Data'] ?? json['data']) as List? ?? [];
    return TimeOffListResponse(
      data:       rawList.map((e) => TimeOffModel.fromJson(e as Map<String, dynamic>)).toList(),
      totalCount: (json['TotalCount'] ?? json['totalCount'] ?? 0) as int,
      page:       (json['Page']       ?? json['page']       ?? 1)  as int,
      pageSize:   (json['PageSize']   ?? json['pageSize']   ?? 10) as int,
      totalPages: (json['TotalPages'] ?? json['totalPages'] ?? 0)  as int,
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
        userId:        json['userId']?.toString() ?? '',
        tahun:         json['tahun']         as int? ?? 0,
        quotaAwal:     json['quotaAwal']     as int? ?? 0,
        quotaTerpakai: json['quotaTerpakai'] as int? ?? 0,
        quotaSisa:     json['quotaSisa']     as int? ?? 0,
      );
}