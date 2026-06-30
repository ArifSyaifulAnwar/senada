// lib/Screen admin/model/reimbursementadminmodel.dart
//
// MODEL REIMBURSEMENT HRD / ADMIN
// Sudah mendukung metadata bukti transfer yang diunggah Head Finance.

import 'package:flutter/material.dart';

class AdminReimbursementData {
  final int id;
  final String userId;
  final String userName;
  final String? userEmail;
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
  final String? statusColor;
  final DateTime submittedAt;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final String? reviewNotes;
  final DateTime? paidAt;
  final String? paidBy;

  final bool hasReceipt;
  final String? receiptFilename;
  final String? receiptContentType;

  // ===== FIELD BARU NOMOR 7: BUKTI TRANSFER FINANCE =====
  final bool hasPaymentProof;
  final String? paymentProofFilename;
  final String? paymentProofContentType;
  final DateTime? paymentProofUploadedAt;
  final String? paymentProofUploadedBy;
  final String? paymentNotes;

  final int daysSinceSubmitted;

  const AdminReimbursementData({
    required this.id,
    required this.userId,
    required this.userName,
    this.userEmail,
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
    this.statusColor,
    required this.submittedAt,
    this.reviewedAt,
    this.reviewedBy,
    this.reviewNotes,
    this.paidAt,
    this.paidBy,
    required this.hasReceipt,
    this.receiptFilename,
    this.receiptContentType,
    required this.hasPaymentProof,
    this.paymentProofFilename,
    this.paymentProofContentType,
    this.paymentProofUploadedAt,
    this.paymentProofUploadedBy,
    this.paymentNotes,
    required this.daysSinceSubmitted,
  });

  factory AdminReimbursementData.fromJson(Map<String, dynamic> json) {
    final expenseDate =
        _adminNullableDate(
          _adminRead(json, 'expenseDate', alternatives: const ['expense_date']),
        ) ??
        DateTime.now();

    final submittedAt =
        _adminNullableDate(
          _adminRead(
            json,
            'submittedAt',
            alternatives: const ['submitted_at', 'createdAt', 'created_at'],
          ),
        ) ??
        DateTime.now();

    final status = _adminString(_adminRead(json, 'status')).toLowerCase();
    final amount = _adminDouble(_adminRead(json, 'amount'));

    return AdminReimbursementData(
      id: _adminInt(_adminRead(json, 'id')),
      userId: _adminString(
        _adminRead(json, 'userId', alternatives: const ['user_id']),
      ),
      userName:
          _adminNullableString(
            _adminRead(
              json,
              'userName',
              alternatives: const ['user_name', 'name'],
            ),
          ) ??
          '-',
      userEmail: _adminNullableString(
        _adminRead(
          json,
          'userEmail',
          alternatives: const ['user_email', 'email'],
        ),
      ),
      userPhone: _adminNullableString(
        _adminRead(
          json,
          'userPhone',
          alternatives: const ['user_phone', 'phone'],
        ),
      ),
      userJob: _adminNullableString(
        _adminRead(json, 'userJob', alternatives: const ['user_job', 'job']),
      ),
      title: _adminString(_adminRead(json, 'title')),
      category: _adminString(_adminRead(json, 'category')),
      amount: amount,
      formattedAmount:
          _adminNullableString(_adminRead(json, 'formattedAmount')) ??
          _adminFormatRupiah(amount),
      expenseDate: expenseDate,
      formattedDate:
          _adminNullableString(_adminRead(json, 'formattedDate')) ??
          _adminFormatDate(expenseDate),
      description: _adminNullableString(_adminRead(json, 'description')),
      status: status,
      statusText: () {
        const knownStatuses = {
          'pending',
          'pending_finance',
          'approved',
          'rejected',
          'paid',
          'done',
          'completed',
          'selesai',
        };
        if (knownStatuses.contains(status)) return _adminStatusLabel(status);
        return _adminNullableString(_adminRead(json, 'statusText')) ??
            _adminStatusLabel(status);
      }(),
      statusColor: _adminNullableString(_adminRead(json, 'statusColor')),
      submittedAt: submittedAt,
      reviewedAt: _adminNullableDate(
        _adminRead(json, 'reviewedAt', alternatives: const ['reviewed_at']),
      ),
      reviewedBy: _adminNullableString(
        _adminRead(json, 'reviewedBy', alternatives: const ['reviewed_by']),
      ),
      reviewNotes: _adminNullableString(
        _adminRead(json, 'reviewNotes', alternatives: const ['review_notes']),
      ),
      paidAt: _adminNullableDate(
        _adminRead(json, 'paidAt', alternatives: const ['paid_at']),
      ),
      paidBy: _adminNullableString(
        _adminRead(json, 'paidBy', alternatives: const ['paid_by']),
      ),
      hasReceipt: _adminBool(
        _adminRead(json, 'hasReceipt', alternatives: const ['has_receipt']),
      ),
      receiptFilename: _adminNullableString(
        _adminRead(
          json,
          'receiptFilename',
          alternatives: const ['receipt_filename'],
        ),
      ),
      receiptContentType: _adminNullableString(
        _adminRead(
          json,
          'receiptContentType',
          alternatives: const ['receipt_content_type'],
        ),
      ),

      // ===== FIELD BARU NOMOR 7 =====
      hasPaymentProof: _adminBool(
        _adminRead(
          json,
          'hasPaymentProof',
          alternatives: const ['has_payment_proof'],
        ),
      ),
      paymentProofFilename: _adminNullableString(
        _adminRead(
          json,
          'paymentProofFilename',
          alternatives: const ['payment_proof_filename'],
        ),
      ),
      paymentProofContentType: _adminNullableString(
        _adminRead(
          json,
          'paymentProofContentType',
          alternatives: const ['payment_proof_content_type'],
        ),
      ),
      paymentProofUploadedAt: _adminNullableDate(
        _adminRead(
          json,
          'paymentProofUploadedAt',
          alternatives: const ['payment_proof_uploaded_at'],
        ),
      ),
      paymentProofUploadedBy: _adminNullableString(
        _adminRead(
          json,
          'paymentProofUploadedBy',
          alternatives: const ['payment_proof_uploaded_by'],
        ),
      ),
      paymentNotes: _adminNullableString(
        _adminRead(json, 'paymentNotes', alternatives: const ['payment_notes']),
      ),

      daysSinceSubmitted: _adminInt(
        _adminRead(
          json,
          'daysSinceSubmitted',
          alternatives: const ['days_since_submitted'],
        ),
      ),
    );
  }

  String get normalizedStatus => status.trim().toLowerCase();

  Color get statusColorValue {
    switch (normalizedStatus) {
      case 'pending':
        return const Color(0xFFF59E0B);
      case 'pending_finance':
        return const Color(0xFF8B5CF6);
      case 'approved':
        return const Color(0xFF10B981);
      case 'rejected':
        return const Color(0xFFEF4444);
      case 'paid':
      case 'done':
      case 'completed':
      case 'selesai':
        return const Color(0xFF0EA5E9);
      default:
        return const Color(0xFF64748B);
    }
  }

  Color get urgencyColor {
    if (normalizedStatus != 'pending') return const Color(0xFF64748B);
    if (daysSinceSubmitted >= 5) return const Color(0xFFEF4444);
    if (daysSinceSubmitted >= 3) return const Color(0xFFF59E0B);
    return const Color(0xFF10B981);
  }

  String get urgencyText {
    if (normalizedStatus != 'pending') return '';
    if (daysSinceSubmitted >= 5) return 'Urgent';
    if (daysSinceSubmitted >= 3) return 'Perlu Review';
    return '';
  }

  bool get hasTransferProof =>
      hasPaymentProof ||
      (paymentProofFilename != null && paymentProofFilename!.trim().isNotEmpty);
}

class AdminResponse {
  final bool success;
  final String message;

  const AdminResponse({required this.success, required this.message});

  factory AdminResponse.fromJson(Map<String, dynamic> json) {
    return AdminResponse(
      success: _adminBool(_adminRead(json, 'success')),
      message: _adminNullableString(_adminRead(json, 'message')) ?? '',
    );
  }
}

class AdminReimbursementReviewRequest {
  final int id;
  final String status;
  final String reviewedBy;
  final String? reviewNotes;

  const AdminReimbursementReviewRequest({
    required this.id,
    required this.status,
    required this.reviewedBy,
    this.reviewNotes,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'status': status,
    'reviewedBy': reviewedBy,
    'reviewNotes': reviewNotes,
  };
}

class AdminMarkPaidRequest {
  final int id;
  final String paidBy;

  const AdminMarkPaidRequest({required this.id, required this.paidBy});

  Map<String, dynamic> toJson() => {'id': id, 'paidBy': paidBy};
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

  const AdminReimbursementStatistics({
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
    final approved = _adminDouble(_adminRead(json, 'totalApprovedAmount'));
    final paid = _adminDouble(_adminRead(json, 'totalPaidAmount'));
    final pending = _adminDouble(_adminRead(json, 'totalPendingAmount'));

    return AdminReimbursementStatistics(
      totalSubmissions: _adminInt(_adminRead(json, 'totalSubmissions')),
      pendingCount: _adminInt(_adminRead(json, 'pendingCount')),
      approvedCount: _adminInt(_adminRead(json, 'approvedCount')),
      rejectedCount: _adminInt(_adminRead(json, 'rejectedCount')),
      paidCount: _adminInt(_adminRead(json, 'paidCount')),
      totalApprovedAmount: approved,
      totalPaidAmount: paid,
      totalPendingAmount: pending,
      formattedTotalApproved:
          _adminNullableString(_adminRead(json, 'formattedTotalApproved')) ??
          _adminFormatRupiah(approved),
      formattedTotalPaid:
          _adminNullableString(_adminRead(json, 'formattedTotalPaid')) ??
          _adminFormatRupiah(paid),
      formattedTotalPending:
          _adminNullableString(_adminRead(json, 'formattedTotalPending')) ??
          _adminFormatRupiah(pending),
    );
  }
}

class UserWithReimbursements {
  final String userId;
  final String name;

  // Field lama/kompatibilitas untuk halaman admin lama.
  // Non-null agar dapat dipakai langsung seperti Text(user.department).
  final String department;
  final String? mail;

  final String? jobs;
  final int totalReimbursements;
  final int pendingCount;
  final int approvedCount;
  final int rejectedCount;
  final int paidCount;
  final double totalAmount;
  final String formattedTotalAmount;

  const UserWithReimbursements({
    required this.userId,
    required this.name,
    this.department = '-',
    this.mail,
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
    final total = _adminDouble(_adminRead(json, 'totalAmount'));

    return UserWithReimbursements(
      userId: _adminString(
        _adminRead(json, 'userId', alternatives: const ['user_id']),
      ),
      name:
          _adminNullableString(
            _adminRead(json, 'name', alternatives: const ['userName']),
          ) ??
          '-',
      department:
          _adminNullableString(
            _adminRead(
              json,
              'department',
              alternatives: const ['organization', 'division', 'dept'],
            ),
          ) ??
          '-',
      mail: _adminNullableString(
        _adminRead(json, 'mail', alternatives: const ['email', 'userEmail']),
      ),
      jobs: _adminNullableString(
        _adminRead(json, 'jobs', alternatives: const ['userJob', 'job']),
      ),
      totalReimbursements: _adminInt(_adminRead(json, 'totalReimbursements')),
      pendingCount: _adminInt(_adminRead(json, 'pendingCount')),
      approvedCount: _adminInt(_adminRead(json, 'approvedCount')),
      rejectedCount: _adminInt(_adminRead(json, 'rejectedCount')),
      paidCount: _adminInt(_adminRead(json, 'paidCount')),
      totalAmount: total,
      formattedTotalAmount:
          _adminNullableString(_adminRead(json, 'formattedTotalAmount')) ??
          _adminFormatRupiah(total),
    );
  }
}

// ====================== PARSER INTERNAL ======================

dynamic _adminRead(
  Map<String, dynamic> json,
  String key, {
  List<String> alternatives = const [],
}) {
  final candidates = <String>[key, ...alternatives];

  for (final candidate in candidates) {
    if (json.containsKey(candidate)) return json[candidate];

    final pascal =
        '${candidate.substring(0, 1).toUpperCase()}${candidate.substring(1)}';
    if (json.containsKey(pascal)) return json[pascal];

    final snake = candidate.replaceAllMapped(
      RegExp(r'([a-z])([A-Z])'),
      (match) => '${match.group(1)}_${match.group(2)!.toLowerCase()}',
    );
    if (json.containsKey(snake)) return json[snake];
  }

  final lowerKeys = <String, dynamic>{
    for (final entry in json.entries) entry.key.toLowerCase(): entry.value,
  };

  for (final candidate in candidates) {
    final direct = lowerKeys[candidate.toLowerCase()];
    if (direct != null) return direct;

    final snake = candidate.replaceAllMapped(
      RegExp(r'([a-z])([A-Z])'),
      (match) => '${match.group(1)}_${match.group(2)!.toLowerCase()}',
    );
    final snakeValue = lowerKeys[snake.toLowerCase()];
    if (snakeValue != null) return snakeValue;
  }

  return null;
}

String _adminString(dynamic value) => value?.toString().trim() ?? '';

String? _adminNullableString(dynamic value) {
  final result = _adminString(value);
  return result.isEmpty || result.toLowerCase() == 'null' ? null : result;
}

int _adminInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _adminDouble(dynamic value) {
  if (value is num) return value.toDouble();

  final raw = value?.toString().trim() ?? '';
  if (raw.isEmpty) return 0;

  final normalized = raw
      .replaceAll('Rp', '')
      .replaceAll('rp', '')
      .replaceAll(RegExp(r'[^0-9,.\-]'), '');

  if (normalized.contains(',') && normalized.contains('.')) {
    final decimal = normalized.lastIndexOf(',') > normalized.lastIndexOf('.')
        ? ','
        : '.';
    final withoutThousands = normalized.replaceAll(
      decimal == ',' ? '.' : ',',
      '',
    );
    return double.tryParse(withoutThousands.replaceAll(decimal, '.')) ?? 0;
  }

  if (normalized.contains(',') && !normalized.contains('.')) {
    final parts = normalized.split(',');
    return double.tryParse(
          parts.length == 2 && parts.last.length <= 2
              ? normalized.replaceAll(',', '.')
              : normalized.replaceAll(',', ''),
        ) ??
        0;
  }

  if (normalized.contains('.') && !normalized.contains(',')) {
    final parts = normalized.split('.');
    return double.tryParse(
          parts.length == 2 && parts.last.length <= 2
              ? normalized
              : normalized.replaceAll('.', ''),
        ) ??
        0;
  }

  return double.tryParse(normalized) ?? 0;
}

bool _adminBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value == 1;

  final raw = value?.toString().trim().toLowerCase();
  return raw == 'true' || raw == '1' || raw == 'yes';
}

DateTime? _adminNullableDate(dynamic value) {
  final raw = value?.toString().trim();
  if (raw == null || raw.isEmpty || raw.toLowerCase() == 'null') {
    return null;
  }
  return DateTime.tryParse(raw);
}

String _adminFormatDate(DateTime value) {
  const months = [
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
  return '${value.day} ${months[value.month]} ${value.year}';
}

String _adminFormatRupiah(double value) {
  final number = value.round().toString();
  final result = StringBuffer();

  for (var i = 0; i < number.length; i++) {
    final left = number.length - i;
    result.write(number[i]);
    if (left > 1 && left % 3 == 1) result.write('.');
  }

  return 'Rp${result.toString()}';
}

String _adminStatusLabel(String value) {
  switch (value.trim().toLowerCase()) {
    case 'pending':
      return 'Menunggu Persetujuan HRD';
    case 'pending_finance':
      return 'Menunggu Persetujuan Finance';
    case 'approved':
      return 'Menunggu Pembayaran Finance';
    case 'rejected':
      return 'Ditolak';
    case 'paid':
    case 'done':
    case 'completed':
    case 'selesai':
      return 'Selesai';
    default:
      return value.isEmpty ? '-' : value;
  }
}
