// Services/time_off_model.dart — FULL REPLACE
// ignore_for_file: prefer_const_constructors
import 'dart:io';
import 'dart:typed_data';

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

  // DL specific — existing
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
  final bool? requiresDirectorApproval;

  // DL specific — NEW (Fase Final)
  final String? headName;
  final String? headJobPosition;
  final String? financeUserId;
  final String? financeName;
  final String? financeJobPosition;
  final String? financeApprovalStatus;
  final String? laporanHeadStatus;
  final String? laporanHrdStatus;
  final String? transferFileName;
  final DateTime? transferUploadedAt;
  final String? suratTugasPath;
  final String? formBiayaPath;
  final String? orgTarget;
  final String? financeRejectionReason;
  final String? hrdRejectionReason;

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
    this.requiresDirectorApproval,
    // NEW
    this.headName,
    this.headJobPosition,
    this.financeUserId,
    this.financeName,
    this.financeJobPosition,
    this.financeApprovalStatus,
    this.laporanHeadStatus,
    this.laporanHrdStatus,
    this.transferFileName,
    this.transferUploadedAt,
    this.suratTugasPath,
    this.formBiayaPath,
    this.orgTarget,
    this.hrdRejectionReason,
    this.financeRejectionReason,
  });

  static dynamic _f(Map<String, dynamic> j, String camel, String snake) {
    final pascal = camel[0].toUpperCase() + camel.substring(1);
    return j[camel] ?? j[pascal] ?? j[snake];
  }

  factory TimeOffModel.fromJson(Map<String, dynamic> json) => TimeOffModel(
    id: (json['id'] ?? json['Id']) as int?,
    userId: _f(json, 'userId', 'userid')?.toString() ?? '',
    jenisTimeOff: _f(json, 'jenisTimeOff', 'jenis_timeoff')?.toString() ?? '',
    tanggalMulai: _parseDateRequired(_f(json, 'tanggalMulai', 'tanggal_mulai')),
    tanggalSelesai: _parseDateRequired(
      _f(json, 'tanggalSelesai', 'tanggal_selesai'),
    ),
    totalHari: (_f(json, 'totalHari', 'total_hari') as num?)?.toInt() ?? 0,
    catatan: json['catatan']?.toString() ?? json['Catatan']?.toString(),
    status: (json['status'] ?? json['Status'])?.toString() ?? 'Pending',
    createdAt: _parseDate(_f(json, 'createdAt', 'created_at')),
    approvedBy: _f(json, 'approvedBy', 'approved_by')?.toString(),
    approverName: _f(json, 'approverName', 'approver_name')?.toString(),
    approvedAt: _parseDate(_f(json, 'approvedAt', 'approved_at')),
    rejectionReason: _f(
      json,
      'rejectionReason',
      'rejection_reason',
    )?.toString(),
    fileName: _f(json, 'fileName', 'file_name')?.toString(),
    filePath: _f(json, 'filePath', 'file_path')?.toString(),
    fileSize: (_f(json, 'fileSize', 'file_size') as num?)?.toInt(),
    fileType: _f(json, 'fileType', 'file_type')?.toString(),
    // DL existing
    jenisPekerjaan: _f(json, 'jenisPekerjaan', 'jenis_pekerjaan')?.toString(),
    rabType: _f(json, 'rabType', 'rab_type')?.toString(),
    nominalUangKantor:
        (_f(json, 'nominalUangKantor', 'nominal_uang_kantor') as num?)
            ?.toDouble(),
    managerUserId: _f(json, 'managerUserId', 'manager_userid')?.toString(),
    managerApprovalStatus: _f(
      json,
      'managerApprovalStatus',
      'manager_approval_status',
    )?.toString(),
    managerApprovedAt: _parseDate(
      _f(json, 'managerApprovedAt', 'manager_approved_at'),
    ),
    managerRejectionReason: _f(
      json,
      'managerRejectionReason',
      'manager_rejection_reason',
    )?.toString(),
    laporanStatus: _f(json, 'laporanStatus', 'laporan_status')?.toString(),
    laporanSubmittedAt: _parseDate(
      _f(json, 'laporanSubmittedAt', 'laporan_submitted_at'),
    ),
    laporanFileName: _f(
      json,
      'laporanFileName',
      'laporan_file_name',
    )?.toString(),
    anggaranFileName: _f(
      json,
      'anggaranFileName',
      'anggaran_file_name',
    )?.toString(),
    reimbursementItems: (() {
      // C# return PascalCase: ReimbursementItems
      final raw = json['ReimbursementItems'] ?? json['reimbursementItems'];
      if (raw == null) return null;
      return (raw as List)
          .map((e) => ReimbursementItem.fromJson(e as Map<String, dynamic>))
          .toList();
    })(),
    // ── FIX: parse Files dari C# (PascalCase) atau files (camelCase) ──────
    files: (() {
      // C# return PascalCase: Files
      final raw = json['Files'] ?? json['files'];
      if (raw == null) return null;
      return (raw as List)
          .map((e) => TimeOffFileItem.fromJson(e as Map<String, dynamic>))
          .toList();
    })(),
    requiresDirectorApproval:
        (_f(json, 'requiresDirectorApproval', 'requires_director_approval')
            as bool?) ??
        false,
    // DL NEW
    headName: _f(json, 'headName', 'head_name')?.toString(),
    headJobPosition: _f(
      json,
      'headJobPosition',
      'head_job_position',
    )?.toString(),
    financeUserId: _f(json, 'financeUserId', 'finance_userid')?.toString(),
    financeName: _f(json, 'financeName', 'finance_name')?.toString(),
    financeJobPosition: _f(
      json,
      'financeJobPosition',
      'finance_job_position',
    )?.toString(),
    financeApprovalStatus: _f(
      json,
      'financeApprovalStatus',
      'finance_approval_status',
    )?.toString(),
    laporanHeadStatus: _f(
      json,
      'laporanHeadStatus',
      'laporan_head_status',
    )?.toString(),
    laporanHrdStatus: _f(
      json,
      'laporanHrdStatus',
      'laporan_hrd_status',
    )?.toString(),
    transferFileName: _f(
      json,
      'transferFileName',
      'transfer_file_name',
    )?.toString(),
    transferUploadedAt: _parseDate(
      _f(json, 'transferUploadedAt', 'transfer_uploaded_at'),
    ),
    suratTugasPath: _f(json, 'suratTugasPath', 'surat_tugas_path')?.toString(),
    formBiayaPath: _f(json, 'formBiayaPath', 'form_biaya_path')?.toString(),
    orgTarget: _f(json, 'orgTarget', 'org_target')?.toString(),
    hrdRejectionReason: _f(
      json,
      'hrdRejectionReason',
      'hrd_rejection_reason',
    )?.toString(),
    financeRejectionReason: _f(
      json,
      'financeRejectionReason',
      'finance_rejection_reason',
    )?.toString(),
  );

  static DateTime? _parseDate(dynamic val) {
    if (val == null) return null;
    return DateTime.tryParse(val.toString());
  }

  static DateTime _parseDateRequired(dynamic val) {
    if (val == null) return DateTime.now();
    return DateTime.tryParse(val.toString()) ?? DateTime.now();
  }

  bool get isDinasLuar => jenisTimeOff == 'Dinas Luar';
  bool get needsLaporan =>
      isDinasLuar && status == 'Approved' && laporanStatus == null;
  bool get isMenungguManager => status == 'Menunggu Manager';
  bool get isMenungguOrg => status == 'Menunggu Org';
  bool get isPendingHrd => status == 'Pending HRD';
  bool get isPendingDirector => status == 'Pending Director';
  bool get isPendingFinance => status == 'Pending Finance';
  bool get isMenungguLaporan => status == 'Menunggu Laporan';
  bool get isMenungguVerifikasiHead => status == 'Menunggu Verifikasi Head';
  bool get isMenungguVerifikasiHrd => status == 'Menunggu Verifikasi HRD';
  bool get isMenungguTransfer => status == 'Menunggu Transfer';
  bool get isApproved => status == 'Approved';
  bool get isRejected => status == 'Rejected';
  bool get isRevisi => status == 'Revisi';
  bool get requiresDirector => requiresDirectorApproval == true;

  bool get adaBiaya => rabType != null && rabType!.isNotEmpty;
  bool get hasSuratTugas =>
      suratTugasPath != null && suratTugasPath!.isNotEmpty;
  bool get hasFormBiaya => formBiayaPath != null && formBiayaPath!.isNotEmpty;

  String get statusLabel {
    switch (status) {
      case 'Pending':
        return 'Menunggu Persetujuan';
      case 'Pending HRD':
        return 'Menunggu HRD';
      case 'Pending Director':
        return 'Menunggu Direktur';
      case 'Menunggu Manager':
        return 'Menunggu Manager';
      case 'Menunggu Org':
        return 'Menunggu Head Divisi';
      case 'Menunggu Laporan':
        return 'Upload Laporan';
      case 'Pending Finance':
        return 'Menunggu Finance';
      case 'Menunggu Verifikasi Head':
        return 'Verifikasi Head';
      case 'Menunggu Verifikasi HRD':
        return 'Verifikasi HRD';
      case 'Menunggu Transfer':
        return 'Menunggu Transfer';
      case 'Approved':
        return 'Disetujui';
      case 'Rejected':
        return 'Ditolak';
      case 'Processed':
        return 'Diproses';
      case 'Revisi':
        return 'Perlu Revisi';
      default:
        return status;
    }
  }

  List<TimeOffFileItem> get allFiles {
    final list = <TimeOffFileItem>[];

    // Tambah semua file dari C# (sudah include file lama via fallback di repository)
    if (files != null) list.addAll(files!);

    // Safety fallback: kalau files null/kosong tapi ada fileName lama
    if (list.isEmpty && fileName != null && fileName!.isNotEmpty) {
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

  factory TimeOffFileItem.fromJson(Map<String, dynamic> json) =>
      TimeOffFileItem(
        id: (json['id'] ?? json['Id'] ?? 0) as int,
        timeOffId:
            (json['timeOffId'] ?? json['TimeOffId'] ?? json['timeoff_id'] ?? 0)
                as int,
        fileName:
            (json['fileName'] ?? json['FileName'] ?? json['file_name'] ?? '')
                as String,
        fileSize:
            ((json['fileSize'] ?? json['FileSize'] ?? json['file_size'])
                    as num?)
                ?.toInt(),
        fileType: (json['fileType'] ?? json['FileType'] ?? json['file_type'])
            ?.toString(),
        urutan: (json['urutan'] ?? json['Urutan'] ?? 1) as int,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'fileName': fileName,
    'fileSize': fileSize,
    'fileType': fileType,
    'urutan': urutan,
  };

  String get ext =>
      fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
  bool get isImage => ['jpg', 'jpeg', 'png'].contains(ext);
  bool get isPdf => ext == 'pdf';

  String get sizeLabel {
    if (fileSize == null) return '';
    final mb = fileSize! / (1024 * 1024);
    return mb >= 1
        ? '${mb.toStringAsFixed(1)} MB'
        : '${(fileSize! / 1024).toStringAsFixed(0)} KB';
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
  final File? laporanFile;
  final File? anggaranFile;
  final Uint8List? laporanBytes;
  final Uint8List? anggaranBytes;
  final String? laporanFileName;
  final String? anggaranFileName;

  const DlLaporanRequest({
    required this.timeOffId,
    required this.userId,
    this.laporanFile,
    this.anggaranFile,
    this.laporanBytes,
    this.anggaranBytes,
    this.laporanFileName,
    this.anggaranFileName,
  });
}

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
    final rawList = (json['Data'] ?? json['data']) as List? ?? [];
    return TimeOffListResponse(
      data: rawList
          .map((e) => TimeOffModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalCount: ((json['TotalCount'] ?? json['totalCount'] ?? 0) as num)
          .toInt(),
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

class WorkPeriodModel {
  final int id;
  final int tahun;
  final int bulan;
  final DateTime tanggalMulai;
  final DateTime tanggalSelesai;
  final String? keterangan;

  const WorkPeriodModel({
    required this.id,
    required this.tahun,
    required this.bulan,
    required this.tanggalMulai,
    required this.tanggalSelesai,
    this.keterangan,
  });

  String get label {
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
    final namaBulan = bulan >= 1 && bulan <= 12 ? bulanNames[bulan] : '$bulan';
    return '$namaBulan $tahun';
  }

  factory WorkPeriodModel.fromJson(Map<String, dynamic> j) => WorkPeriodModel(
    id: ((j['id'] ?? j['Id'] ?? 0) as num).toInt(),
    tahun: ((j['tahun'] ?? j['Tahun'] ?? 0) as num).toInt(),
    bulan: ((j['bulan'] ?? j['Bulan'] ?? 0) as num).toInt(),
    tanggalMulai: DateTime.parse(
      (j['tanggalMulai'] ?? j['TanggalMulai'] ?? '2000-01-01').toString(),
    ),
    tanggalSelesai: DateTime.parse(
      (j['tanggalSelesai'] ?? j['TanggalSelesai'] ?? '2000-01-31').toString(),
    ),
    keterangan: (j['keterangan'] ?? j['Keterangan'])?.toString(),
  );
}
