// admin_reimbursement_models.dart
import 'package:flutter/material.dart';

class AdminReimbursementListRequest {
  final String? status;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? userId;
  final String? searchKeyword;

  AdminReimbursementListRequest({
    this.status,
    this.startDate,
    this.endDate,
    this.userId,
    this.searchKeyword,
  });

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'userId': userId,
      'searchKeyword': searchKeyword,
    };
  }
}

class AdminReimbursementReviewRequest {
  final int id;
  final String status; // "approved" or "rejected"
  final String reviewedBy;
  final String? reviewNotes;

  AdminReimbursementReviewRequest({
    required this.id,
    required this.status,
    required this.reviewedBy,
    this.reviewNotes,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'status': status,
      'reviewedBy': reviewedBy,
      'reviewNotes': reviewNotes,
    };
  }
}

class AdminMarkPaidRequest {
  final int id;
  final String paidBy;

  AdminMarkPaidRequest({required this.id, required this.paidBy});

  Map<String, dynamic> toJson() {
    return {'id': id, 'paidBy': paidBy};
  }
}

class AdminStatisticsRequest {
  final int? year;
  final int? month;

  AdminStatisticsRequest({this.year, this.month});

  Map<String, dynamic> toJson() {
    return {'year': year, 'month': month};
  }
}

class AdminReimbursementData {
  final int id;
  final String userId;
  final String userName;
  final String userEmail;
  final String? userPhone;
  final String? userJob;
  final String title;
  final String category;
  final double amount;
  final String formattedAmount;
  final DateTime expenseDate;
  final String formattedDate;
  final String? description;
  final String status;
  final String statusText;
  final String statusColor;
  final DateTime submittedAt;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final String? reviewNotes;
  final DateTime? paidAt;
  final String? paidBy;
  final bool hasReceipt;
  final String? receiptFilename;
  final String? receiptContentType;
  final int daysSinceSubmitted;

  AdminReimbursementData({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    this.userPhone,
    this.userJob,
    required this.title,
    required this.category,
    required this.amount,
    required this.formattedAmount,
    required this.expenseDate,
    required this.formattedDate,
    this.description,
    required this.status,
    required this.statusText,
    required this.statusColor,
    required this.submittedAt,
    this.reviewedAt,
    this.reviewedBy,
    this.reviewNotes,
    this.paidAt,
    this.paidBy,
    required this.hasReceipt,
    this.receiptFilename,
    this.receiptContentType,
    required this.daysSinceSubmitted,
  });

  factory AdminReimbursementData.fromJson(Map<String, dynamic> json) {
    return AdminReimbursementData(
      id: json['Id'] ?? 0,
      userId: json['UserId'] ?? '',
      userName: json['UserName'] ?? '',
      userEmail: json['UserEmail'] ?? '',
      userPhone: json['UserPhone'] as String?,
      userJob: json['UserJob'] as String?,
      title: json['Title'] ?? '',
      category: json['Category'] ?? '',
      amount: (json['Amount'] as num?)?.toDouble() ?? 0.0,
      formattedAmount: json['FormattedAmount'] ?? '0',
      expenseDate: json['ExpenseDate'] != null
          ? DateTime.tryParse(json['ExpenseDate']) ?? DateTime.now()
          : DateTime.now(),
      formattedDate: json['FormattedDate'] ?? '',
      description: json['Description'] as String?,
      status: json['Status'] ?? 'pending',
      statusText: json['StatusText'] ?? 'Menunggu',
      statusColor: json['StatusColor'] ?? '#FFA500',
      submittedAt: json['SubmittedAt'] != null
          ? DateTime.tryParse(json['SubmittedAt']) ?? DateTime.now()
          : DateTime.now(),
      reviewedAt: json['ReviewedAt'] != null
          ? DateTime.tryParse(json['ReviewedAt'])
          : null,
      reviewedBy: json['ReviewedBy'] as String?,
      reviewNotes: json['ReviewNotes'] as String?,
      paidAt: json['PaidAt'] != null ? DateTime.tryParse(json['PaidAt']) : null,
      paidBy: json['PaidBy'] as String?,
      hasReceipt: json['HasReceipt'] ?? false,
      receiptFilename: json['ReceiptFilename'] as String?,
      receiptContentType: json['ReceiptContentType'] as String?,
      daysSinceSubmitted: json['DaysSinceSubmitted'] ?? 0,
    );
  }

  Color get statusColorValue {
    switch (status.toLowerCase()) {
      case 'draft':
        return Colors.grey;
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'paid':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Color get urgencyColor {
    if (status.toLowerCase() == 'pending') {
      if (daysSinceSubmitted > 7) return Colors.red;
      if (daysSinceSubmitted > 3) return Colors.orange;
    }
    return Colors.grey;
  }

  String get urgencyText {
    if (status.toLowerCase() == 'pending') {
      if (daysSinceSubmitted > 7) return 'Urgent';
      if (daysSinceSubmitted > 3) return 'Perlu Perhatian';
    }
    return '';
  }
}

class AdminReimbursementStatistics {
  final int totalSubmissions;
  final int pendingCount;
  final int approvedCount;
  final int rejectedCount;
  final int paidCount;
  final double totalApprovedAmount;
  final double totalPaidAmount;
  final double totalPendingAmount;
  final String formattedTotalApproved;
  final String formattedTotalPaid;
  final String formattedTotalPending;

  AdminReimbursementStatistics({
    required this.totalSubmissions,
    required this.pendingCount,
    required this.approvedCount,
    required this.rejectedCount,
    required this.paidCount,
    required this.totalApprovedAmount,
    required this.totalPaidAmount,
    required this.totalPendingAmount,
    required this.formattedTotalApproved,
    required this.formattedTotalPaid,
    required this.formattedTotalPending,
  });

  factory AdminReimbursementStatistics.fromJson(Map<String, dynamic> json) {
    return AdminReimbursementStatistics(
      totalSubmissions: json['TotalSubmissions'] ?? 0,
      pendingCount: json['PendingCount'] ?? 0,
      approvedCount: json['ApprovedCount'] ?? 0,
      rejectedCount: json['RejectedCount'] ?? 0,
      paidCount: json['PaidCount'] ?? 0,
      totalApprovedAmount:
          (json['TotalApprovedAmount'] as num?)?.toDouble() ?? 0.0,
      totalPaidAmount: (json['TotalPaidAmount'] as num?)?.toDouble() ?? 0.0,
      totalPendingAmount:
          (json['TotalPendingAmount'] as num?)?.toDouble() ?? 0.0,
      formattedTotalApproved: json['FormattedTotalApproved'] ?? '0',
      formattedTotalPaid: json['FormattedTotalPaid'] ?? '0',
      formattedTotalPending: json['FormattedTotalPending'] ?? '0',
    );
  }
}

class UserWithReimbursements {
  final String userId;
  final String name;
  final String mail;
  final String? jobs;
  final int totalReimbursements;
  final int pendingCount;
  final int approvedCount;
  final int rejectedCount;
  final int paidCount;
  final double totalAmount;
  final String formattedTotalAmount;

  UserWithReimbursements({
    required this.userId,
    required this.name,
    required this.mail,
    this.jobs,
    required this.totalReimbursements,
    required this.pendingCount,
    required this.approvedCount,
    required this.rejectedCount,
    required this.paidCount,
    required this.totalAmount,
    required this.formattedTotalAmount,
  });

  factory UserWithReimbursements.fromJson(Map<String, dynamic> json) {
    return UserWithReimbursements(
      userId: json['UserId'] ?? '',
      name: json['Name'] ?? '',
      mail: json['Mail'] ?? '',
      jobs: json['Jobs'] as String?,
      totalReimbursements: json['TotalReimbursements'] ?? 0,
      pendingCount: json['PendingCount'] ?? 0,
      approvedCount: json['ApprovedCount'] ?? 0,
      rejectedCount: json['RejectedCount'] ?? 0,
      paidCount: json['PaidCount'] ?? 0,
      totalAmount: (json['TotalAmount'] as num?)?.toDouble() ?? 0.0,
      formattedTotalAmount: json['FormattedTotalAmount'] ?? '0',
    );
  }

  get department => null;
}

class AdminResponse {
  final bool success;
  final String message;
  final dynamic data;

  AdminResponse({required this.success, required this.message, this.data});

  factory AdminResponse.fromJson(Map<String, dynamic> json) {
    return AdminResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? 'Unknown error',
      data: json['data'],
    );
  }
}
