import 'dart:io';

class TimeOffModel {
  final int? id;
  final String userId;
  final String userName;
  final String jenisTimeOff;
  final DateTime tanggalMulai;
  final DateTime tanggalSelesai;
  final int totalHari;
  final String? catatan;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? approvedBy;
  final String? approverName;
  final DateTime? approvedAt;
  final String? rejectionReason;
  final String? filePath; // Tambahan untuk file path
  final String? fileName; // Tambahan untuk nama file

  TimeOffModel({
    this.id,
    required this.userId,
    required this.userName,
    required this.jenisTimeOff,
    required this.tanggalMulai,
    required this.tanggalSelesai,
    required this.totalHari,
    this.catatan,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.approvedBy,
    this.approverName,
    this.approvedAt,
    this.rejectionReason,
    this.filePath,
    this.fileName,
  });

  factory TimeOffModel.fromJson(Map<String, dynamic> json) {
    return TimeOffModel(
      id: json['Id'],
      userId: json['UserId'] ?? '',
      userName: json['UserName'] ?? '',
      jenisTimeOff: json['JenisTimeOff'] ?? '',
      tanggalMulai: DateTime.parse(json['TanggalMulai']),
      tanggalSelesai: DateTime.parse(json['TanggalSelesai']),
      totalHari: json['TotalHari'] ?? 0,
      catatan: json['Catatan'],
      status: json['Status'] ?? 'Pending',
      createdAt: DateTime.parse(json['CreatedAt']),
      updatedAt: DateTime.parse(json['UpdatedAt']),
      approvedBy: json['ApprovedBy'],
      approverName: json['ApproverName'],
      approvedAt: json['ApprovedAt'] != null
          ? DateTime.parse(json['ApprovedAt'])
          : null,
      rejectionReason: json['RejectionReason'],
      filePath: json['FilePath'],
      fileName: json['FileName'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'jenisTimeOff': jenisTimeOff,
      'tanggalMulai': tanggalMulai.toIso8601String(),
      'tanggalSelesai': tanggalSelesai.toIso8601String(),
      'totalHari': totalHari,
      'catatan': catatan,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'approvedBy': approvedBy,
      'approverName': approverName,
      'approvedAt': approvedAt?.toIso8601String(),
      'rejectionReason': rejectionReason,
      'filePath': filePath,
      'fileName': fileName,
    };
  }
}

// Request models
class TimeOffRequest {
  final String userId;
  final String jenisTimeOff;
  final DateTime tanggalMulai;
  final DateTime tanggalSelesai;
  final String? catatan;
  final File? receiptFile; // Tambahan untuk file

  TimeOffRequest({
    required this.userId,
    required this.jenisTimeOff,
    required this.tanggalMulai,
    required this.tanggalSelesai,
    this.catatan,
    this.receiptFile,
  });

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'jenisTimeOff': jenisTimeOff,
      'tanggalMulai': tanggalMulai.toIso8601String(),
      'tanggalSelesai': tanggalSelesai.toIso8601String(),
      'catatan': catatan,
    };
  }
}

class UpdateTimeOffRequest {
  final int id;
  final String userId;
  final String jenisTimeOff;
  final DateTime tanggalMulai;
  final DateTime tanggalSelesai;
  final String? catatan;
  final File? receiptFile;

  UpdateTimeOffRequest({
    required this.id,
    required this.userId,
    required this.jenisTimeOff,
    required this.tanggalMulai,
    required this.tanggalSelesai,
    this.catatan,
    this.receiptFile,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'jenisTimeOff': jenisTimeOff,
      'tanggalMulai': tanggalMulai.toIso8601String(),
      'tanggalSelesai': tanggalSelesai.toIso8601String(),
      'catatan': catatan,
    };
  }
}

class DeleteTimeOffRequest {
  final int id;
  final String userId;

  DeleteTimeOffRequest({required this.id, required this.userId});

  Map<String, dynamic> toJson() {
    return {'id': id, 'userId': userId};
  }
}

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
      success: json['Success'] ?? false,
      message: json['Message'] ?? '',
      data: json['Data'] != null && fromJsonT != null
          ? fromJsonT(json['Data'])
          : json['Data'],
    );
  }
}

class TimeOffListResponse {
  final List<TimeOffModel> data;
  final int totalCount;
  final int page;
  final int pageSize;
  final int totalPages;

  TimeOffListResponse({
    required this.data,
    required this.totalCount,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  factory TimeOffListResponse.fromJson(Map<String, dynamic> json) {
    return TimeOffListResponse(
      data: (json['Data'] as List? ?? [])
          .map((item) => TimeOffModel.fromJson(item))
          .toList(),
      totalCount: json['TotalCount'] ?? 0,
      page: json['Page'] ?? 1,
      pageSize: json['PageSize'] ?? 10,
      totalPages: json['TotalPages'] ?? 0,
    );
  }
}
