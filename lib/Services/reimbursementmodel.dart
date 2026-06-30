// lib/Services/reimbursementmodel.dart
//
// MODEL REIMBURSEMENT PENGAJU
// Sudah mendukung metadata bukti transfer yang diunggah Head Finance.

import 'package:flutter/material.dart';

class ReimbursementData {
  final int id;
  final String userId;
  final String? userName;
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

  // Bukti pengajuan user.
  final bool hasReceipt;
  final String? receiptFilename;
  final String? receiptContentType;

  // Bukti transfer yang diunggah Head Finance.
  final bool hasPaymentProof;
  final String? paymentProofFilename;
  final String? paymentProofContentType;
  final DateTime? paymentProofUploadedAt;
  final String? paymentProofUploadedBy;
  final String? paymentNotes;

  final int daysSinceSubmitted;

  const ReimbursementData({
    required this.id,
    required this.userId,
    this.userName,
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

  factory ReimbursementData.fromJson(Map<String, dynamic> json) {
    final expenseDate =
        _nullableDate(
          _read(
            json,
            'expenseDate',
            alternatives: const ['expense_date', 'tanggalPengeluaran'],
          ),
        ) ??
        DateTime.now();

    final submittedAt =
        _nullableDate(
          _read(
            json,
            'submittedAt',
            alternatives: const ['submitted_at', 'createdAt', 'created_at'],
          ),
        ) ??
        DateTime.now();

    final status = _string(_read(json, 'status')).toLowerCase();
    final amount = _double(_read(json, 'amount'));

    return ReimbursementData(
      id: _int(_read(json, 'id')),
      userId: _string(_read(json, 'userId', alternatives: const ['user_id'])),
      userName: _nullableString(
        _read(json, 'userName', alternatives: const ['user_name', 'name']),
      ),
      userEmail: _nullableString(
        _read(json, 'userEmail', alternatives: const ['user_email', 'email']),
      ),
      userPhone: _nullableString(
        _read(json, 'userPhone', alternatives: const ['user_phone', 'phone']),
      ),
      userJob: _nullableString(
        _read(json, 'userJob', alternatives: const ['user_job', 'job']),
      ),
      title: _string(_read(json, 'title')),
      category: _string(_read(json, 'category')),
      amount: amount,
      formattedAmount:
          _nullableString(_read(json, 'formattedAmount')) ??
          _formatRupiah(amount),
      expenseDate: expenseDate,
      formattedDate:
          _nullableString(_read(json, 'formattedDate')) ??
          _formatDate(expenseDate),
      description: _nullableString(_read(json, 'description')),
      status: status,
      statusText:
          _nullableString(_read(json, 'statusText')) ?? _statusLabel(status),
      statusColor: _nullableString(_read(json, 'statusColor')),
      submittedAt: submittedAt,
      reviewedAt: _nullableDate(
        _read(json, 'reviewedAt', alternatives: const ['reviewed_at']),
      ),
      reviewedBy: _nullableString(
        _read(json, 'reviewedBy', alternatives: const ['reviewed_by']),
      ),
      reviewNotes: _nullableString(
        _read(json, 'reviewNotes', alternatives: const ['review_notes']),
      ),
      paidAt: _nullableDate(
        _read(json, 'paidAt', alternatives: const ['paid_at']),
      ),
      paidBy: _nullableString(
        _read(json, 'paidBy', alternatives: const ['paid_by']),
      ),

      hasReceipt: _bool(
        _read(json, 'hasReceipt', alternatives: const ['has_receipt']),
      ),
      receiptFilename: _nullableString(
        _read(
          json,
          'receiptFilename',
          alternatives: const ['receipt_filename'],
        ),
      ),
      receiptContentType: _nullableString(
        _read(
          json,
          'receiptContentType',
          alternatives: const ['receipt_content_type'],
        ),
      ),

      // ===== FIELD BARU NOMOR 7: BUKTI TRANSFER FINANCE =====
      hasPaymentProof: _bool(
        _read(
          json,
          'hasPaymentProof',
          alternatives: const ['has_payment_proof'],
        ),
      ),
      paymentProofFilename: _nullableString(
        _read(
          json,
          'paymentProofFilename',
          alternatives: const ['payment_proof_filename'],
        ),
      ),
      paymentProofContentType: _nullableString(
        _read(
          json,
          'paymentProofContentType',
          alternatives: const ['payment_proof_content_type'],
        ),
      ),
      paymentProofUploadedAt: _nullableDate(
        _read(
          json,
          'paymentProofUploadedAt',
          alternatives: const ['payment_proof_uploaded_at'],
        ),
      ),
      paymentProofUploadedBy: _nullableString(
        _read(
          json,
          'paymentProofUploadedBy',
          alternatives: const ['payment_proof_uploaded_by'],
        ),
      ),
      paymentNotes: _nullableString(
        _read(json, 'paymentNotes', alternatives: const ['payment_notes']),
      ),

      daysSinceSubmitted: _int(
        _read(
          json,
          'daysSinceSubmitted',
          alternatives: const ['days_since_submitted'],
        ),
      ),
    );
  }

  String get normalizedStatus => status.trim().toLowerCase();

  String get statusLabel {
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
    if (knownStatuses.contains(normalizedStatus)) {
      return _statusLabel(normalizedStatus);
    }
    return statusText.trim().isNotEmpty
        ? statusText
        : _statusLabel(normalizedStatus);
  }

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

  bool get isPaid =>
      const {'paid', 'done', 'completed', 'selesai'}.contains(normalizedStatus);

  bool get hasTransferProof =>
      hasPaymentProof ||
      (paymentProofFilename != null && paymentProofFilename!.trim().isNotEmpty);

  ReimbursementData copyWith({
    bool? hasPaymentProof,
    String? paymentProofFilename,
    String? paymentProofContentType,
    DateTime? paymentProofUploadedAt,
    String? paymentProofUploadedBy,
    String? paymentNotes,
  }) {
    return ReimbursementData(
      id: id,
      userId: userId,
      userName: userName,
      userEmail: userEmail,
      userPhone: userPhone,
      userJob: userJob,
      title: title,
      category: category,
      amount: amount,
      formattedAmount: formattedAmount,
      expenseDate: expenseDate,
      formattedDate: formattedDate,
      description: description,
      status: status,
      statusText: statusText,
      statusColor: statusColor,
      submittedAt: submittedAt,
      reviewedAt: reviewedAt,
      reviewedBy: reviewedBy,
      reviewNotes: reviewNotes,
      paidAt: paidAt,
      paidBy: paidBy,
      hasReceipt: hasReceipt,
      receiptFilename: receiptFilename,
      receiptContentType: receiptContentType,
      hasPaymentProof: hasPaymentProof ?? this.hasPaymentProof,
      paymentProofFilename: paymentProofFilename ?? this.paymentProofFilename,
      paymentProofContentType:
          paymentProofContentType ?? this.paymentProofContentType,
      paymentProofUploadedAt:
          paymentProofUploadedAt ?? this.paymentProofUploadedAt,
      paymentProofUploadedBy:
          paymentProofUploadedBy ?? this.paymentProofUploadedBy,
      paymentNotes: paymentNotes ?? this.paymentNotes,
      daysSinceSubmitted: daysSinceSubmitted,
    );
  }
}

class ReimbursementResponse {
  final bool success;
  final String message;
  final int? reimbursementId;

  const ReimbursementResponse({
    required this.success,
    required this.message,
    this.reimbursementId,
  });

  factory ReimbursementResponse.fromJson(Map<String, dynamic> json) {
    return ReimbursementResponse(
      success: _bool(_read(json, 'success')),
      message: _nullableString(_read(json, 'message')) ?? '',
      reimbursementId: _nullableInt(
        _read(
          json,
          'reimbursementId',
          alternatives: const ['reimbursement_id', 'id'],
        ),
      ),
    );
  }
}

class ReimbursementListRequest {
  final String userId;
  final String? status;
  final DateTime? startDate;
  final DateTime? endDate;

  const ReimbursementListRequest({
    required this.userId,
    this.status,
    this.startDate,
    this.endDate,
  });

  Map<String, dynamic> toJson() => {
    'userId': userId,
    if (status != null && status!.trim().isNotEmpty) 'status': status,
    if (startDate != null) 'startDate': startDate!.toIso8601String(),
    if (endDate != null) 'endDate': endDate!.toIso8601String(),
  };
}

class ReimbursementDetailRequest {
  final int id;
  final String? userId;

  const ReimbursementDetailRequest({required this.id, this.userId});

  Map<String, dynamic> toJson() => {
    'id': id,
    if (userId != null && userId!.trim().isNotEmpty) 'userId': userId,
  };
}

class ReimbursementCategory {
  final int id;
  final String name;
  final String? description;

  const ReimbursementCategory({
    required this.id,
    required this.name,
    this.description,
  });

  factory ReimbursementCategory.fromJson(Map<String, dynamic> json) {
    return ReimbursementCategory(
      id: _int(_read(json, 'id')),
      name:
          _nullableString(
            _read(
              json,
              'name',
              alternatives: const ['category', 'categoryName'],
            ),
          ) ??
          '',
      description: _nullableString(_read(json, 'description')),
    );
  }
}

class ReimbursementStatistics {
  final int totalSubmissions;
  final int pendingCount;
  final int approvedCount;
  final int rejectedCount;
  final int paidCount;
  final double totalAmount;
  final double totalApprovedAmount;
  final double totalPaidAmount;
  final String formattedTotalAmount;
  final String formattedTotalApproved;
  final String formattedTotalPaid;

  const ReimbursementStatistics({
    required this.totalSubmissions,
    required this.pendingCount,
    required this.approvedCount,
    required this.rejectedCount,
    required this.paidCount,
    required this.totalAmount,
    required this.totalApprovedAmount,
    required this.totalPaidAmount,
    required this.formattedTotalAmount,
    required this.formattedTotalApproved,
    required this.formattedTotalPaid,
  });

  factory ReimbursementStatistics.fromJson(Map<String, dynamic> json) {
    final totalAmount = _double(_read(json, 'totalAmount'));
    final totalApprovedAmount = _double(_read(json, 'totalApprovedAmount'));
    final totalPaidAmount = _double(_read(json, 'totalPaidAmount'));

    return ReimbursementStatistics(
      totalSubmissions: _int(_read(json, 'totalSubmissions')),
      pendingCount: _int(_read(json, 'pendingCount')),
      approvedCount: _int(_read(json, 'approvedCount')),
      rejectedCount: _int(_read(json, 'rejectedCount')),
      paidCount: _int(_read(json, 'paidCount')),
      totalAmount: totalAmount,
      totalApprovedAmount: totalApprovedAmount,
      totalPaidAmount: totalPaidAmount,
      formattedTotalAmount:
          _nullableString(_read(json, 'formattedTotalAmount')) ??
          _formatRupiah(totalAmount),
      formattedTotalApproved:
          _nullableString(_read(json, 'formattedTotalApproved')) ??
          _formatRupiah(totalApprovedAmount),
      formattedTotalPaid:
          _nullableString(_read(json, 'formattedTotalPaid')) ??
          _formatRupiah(totalPaidAmount),
    );
  }
}

// ====================== PARSER INTERNAL ======================

dynamic _read(
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
    final value = lowerKeys[candidate.toLowerCase()];
    if (value != null) return value;

    final snake = candidate.replaceAllMapped(
      RegExp(r'([a-z])([A-Z])'),
      (match) => '${match.group(1)}_${match.group(2)!.toLowerCase()}',
    );

    final snakeValue = lowerKeys[snake.toLowerCase()];
    if (snakeValue != null) return snakeValue;
  }

  return null;
}

String _string(dynamic value) => value?.toString().trim() ?? '';

String? _nullableString(dynamic value) {
  final result = _string(value);
  return result.isEmpty || result.toLowerCase() == 'null' ? null : result;
}

int _int(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

int? _nullableInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

double _double(dynamic value) {
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

bool _bool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value == 1;

  final raw = value?.toString().trim().toLowerCase();
  return raw == 'true' || raw == '1' || raw == 'yes';
}

DateTime? _nullableDate(dynamic value) {
  final raw = value?.toString().trim();
  if (raw == null || raw.isEmpty || raw.toLowerCase() == 'null') {
    return null;
  }
  return DateTime.tryParse(raw);
}

String _formatDate(DateTime value) {
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

String _formatRupiah(double value) {
  final number = value.round().toString();
  final result = StringBuffer();

  for (var i = 0; i < number.length; i++) {
    final left = number.length - i;
    result.write(number[i]);
    if (left > 1 && left % 3 == 1) result.write('.');
  }

  return 'Rp${result.toString()}';
}

String _statusLabel(String value) {
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
