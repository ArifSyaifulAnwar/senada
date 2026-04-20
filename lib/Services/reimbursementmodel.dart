import 'package:flutter/material.dart';

class ReimbursementSubmitRequest {
  final String userId;
  final String title;
  final String category;
  final double amount;
  final DateTime expenseDate;
  final String? description;
  final String status;

  ReimbursementSubmitRequest({
    required this.userId,
    required this.title,
    required this.category,
    required this.amount,
    required this.expenseDate,
    this.description,
    this.status = 'pending',
  });

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'title': title,
      'category': category,
      'amount': amount,
      'expenseDate': expenseDate.toIso8601String(),
      'description': description,
      'status': status,
    };
  }
}

class ReimbursementListRequest {
  final String userId;
  final String? status;
  final DateTime? startDate;
  final DateTime? endDate;

  ReimbursementListRequest({
    required this.userId,
    this.status,
    this.startDate,
    this.endDate,
  });

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'status': status,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
    };
  }
}

class ReimbursementDetailRequest {
  final int id;
  final String? userId;

  ReimbursementDetailRequest({required this.id, this.userId});

  Map<String, dynamic> toJson() {
    return {'id': id, 'userId': userId};
  }
}

class ReimbursementResponse {
  final bool success;
  final String message;
  final int? reimbursementId;
  final ReimbursementData? data;

  ReimbursementResponse({
    required this.success,
    required this.message,
    this.reimbursementId,
    this.data,
  });

  factory ReimbursementResponse.fromJson(Map<String, dynamic> json) {
    return ReimbursementResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? 'Unknown error', // Pastikan ada fallback
      reimbursementId: json['reimbursementId'] as int?,
      data: json['data'] != null
          ? ReimbursementData.fromJson(json['data'])
          : null,
    );
  }
}

class ReimbursementData {
  final int id;
  final String? userId;
  final String? userName;
  final String? userEmail;
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

  ReimbursementData({
    required this.id,
    this.userId,
    this.userName,
    this.userEmail,
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
  });

  factory ReimbursementData.fromJson(Map<String, dynamic> json) {
    return ReimbursementData(
      id: json['Id'] ?? 0,
      userId: json['UserId'] as String?,
      userName: json['UserName'] as String?,
      userEmail: json['userEmail'] as String?,
      title: json['Title'] ?? '', // Pastikan tidak null
      category: json['Category'] ?? '', // Pastikan tidak null
      amount: (json['Amount'] as num?)?.toDouble() ?? 0.0,
      formattedAmount: json['FormattedAmount'] ?? '0',
      expenseDate: json['ExpenseDate'] != null
          ? DateTime.tryParse(json['ExpenseDate']) ?? DateTime.now()
          : DateTime.now(),
      formattedDate: json['FormattedDate'] ?? '',
      description: json['Description'] as String?,
      status: json['Status'] ?? 'pending', // Default status
      statusText: json['StatusText'], // Default status text
      statusColor: json['StatusColor'] ?? '#FFA500', // Default color
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
}

class ReimbursementCategory {
  final int id;
  final String name;
  final String? description;

  ReimbursementCategory({
    required this.id,
    required this.name,
    this.description,
  });

  factory ReimbursementCategory.fromJson(Map<String, dynamic> json) {
    return ReimbursementCategory(
      id: json['Id'],
      name: json['Name'],
      description: json['Description'],
    );
  }
}

class ReimbursementStatistics {
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

  ReimbursementStatistics({
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

  factory ReimbursementStatistics.fromJson(Map<String, dynamic> json) {
    return ReimbursementStatistics(
      totalSubmissions: json['totalSubmissions'],
      pendingCount: json['pendingCount'],
      approvedCount: json['approvedCount'],
      rejectedCount: json['rejectedCount'],
      paidCount: json['paidCount'],
      totalApprovedAmount: (json['totalApprovedAmount'] as num).toDouble(),
      totalPaidAmount: (json['totalPaidAmount'] as num).toDouble(),
      totalPendingAmount: (json['totalPendingAmount'] as num).toDouble(),
      formattedTotalApproved: json['formattedTotalApproved'],
      formattedTotalPaid: json['formattedTotalPaid'],
      formattedTotalPending: json['formattedTotalPending'],
    );
  }
}
