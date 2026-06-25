class FinanceReimbursementItem {
  final int id;
  final String userId;
  final String userName;
  final String? userEmail;
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

  // Review HRD
  final String? reviewedBy;
  final String? reviewNotes;
  final DateTime? reviewedAt;

  // Review Finance
  final String? financeReviewedBy;
  final String? financeReviewNotes;
  final DateTime? financeReviewedAt;

  // Pembayaran Finance
  final DateTime? paidAt;
  final String? paidBy;
  final String? paymentNotes;

  // Bukti pengajuan user
  final bool hasReceipt;
  final String? receiptFilename;
  final String? receiptContentType;

  // Bukti transfer yang diunggah Finance
  final bool hasPaymentProof;
  final String? paymentProofFilename;
  final String? paymentProofContentType;
  final DateTime? paymentProofUploadedAt;
  final String? paymentProofUploadedBy;

  final int daysSinceSubmitted;

  const FinanceReimbursementItem({
    required this.id,
    required this.userId,
    required this.userName,
    this.userEmail,
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
    this.reviewedBy,
    this.reviewNotes,
    this.reviewedAt,
    this.financeReviewedBy,
    this.financeReviewNotes,
    this.financeReviewedAt,
    this.paidAt,
    this.paidBy,
    this.paymentNotes,
    required this.hasReceipt,
    this.receiptFilename,
    this.receiptContentType,
    required this.hasPaymentProof,
    this.paymentProofFilename,
    this.paymentProofContentType,
    this.paymentProofUploadedAt,
    this.paymentProofUploadedBy,
    required this.daysSinceSubmitted,
  });

  factory FinanceReimbursementItem.fromJson(Map<String, dynamic> json) {
    return FinanceReimbursementItem(
      id: _asInt(_read(json, 'id')),
      userId: _asString(_read(json, 'userId')),
      userName: _asString(_read(json, 'userName')),
      userEmail: _asNullableString(_read(json, 'userEmail')),
      userJob: _asNullableString(_read(json, 'userJob')),
      title: _asString(_read(json, 'title')),
      category: _asString(_read(json, 'category')),
      amount: _asDouble(_read(json, 'amount')),
      formattedAmount: _asString(_read(json, 'formattedAmount')),
      expenseDate: _asDate(_read(json, 'expenseDate')),
      formattedDate: _asString(_read(json, 'formattedDate')),
      description: _asNullableString(_read(json, 'description')),
      status: _asString(_read(json, 'status')),
      statusText: _asString(_read(json, 'statusText')),
      statusColor: _asString(_read(json, 'statusColor')),
      submittedAt: _asDate(_read(json, 'submittedAt')),
      reviewedBy: _asNullableString(
        _read(json, 'reviewedBy', alternatives: const ['reviewed_by']),
      ),
      reviewNotes: _asNullableString(
        _read(json, 'reviewNotes', alternatives: const ['review_notes']),
      ),
      reviewedAt: _asNullableDate(
        _read(json, 'reviewedAt', alternatives: const ['reviewed_at']),
      ),
      financeReviewedBy: _asNullableString(
        _read(
          json,
          'financeReviewedBy',
          alternatives: const ['finance_reviewed_by'],
        ),
      ),
      financeReviewNotes: _asNullableString(
        _read(
          json,
          'financeReviewNotes',
          alternatives: const ['finance_review_notes'],
        ),
      ),
      financeReviewedAt: _asNullableDate(
        _read(
          json,
          'financeReviewedAt',
          alternatives: const ['finance_reviewed_at'],
        ),
      ),
      paidAt: _asNullableDate(
        _read(json, 'paidAt', alternatives: const ['paid_at']),
      ),
      paidBy: _asNullableString(
        _read(json, 'paidBy', alternatives: const ['paid_by']),
      ),
      paymentNotes: _asNullableString(
        _read(json, 'paymentNotes', alternatives: const ['payment_notes']),
      ),
      hasReceipt: _asBool(_read(json, 'hasReceipt')),
      receiptFilename: _asNullableString(_read(json, 'receiptFilename')),
      receiptContentType: _asNullableString(_read(json, 'receiptContentType')),
      hasPaymentProof: _asBool(_read(json, 'hasPaymentProof')),
      paymentProofFilename: _asNullableString(
        _read(json, 'paymentProofFilename'),
      ),
      paymentProofContentType: _asNullableString(
        _read(json, 'paymentProofContentType'),
      ),
      paymentProofUploadedAt: _asNullableDate(
        _read(
          json,
          'paymentProofUploadedAt',
          alternatives: const ['payment_proof_uploaded_at'],
        ),
      ),
      paymentProofUploadedBy: _asNullableString(
        _read(
          json,
          'paymentProofUploadedBy',
          alternatives: const ['payment_proof_uploaded_by'],
        ),
      ),
      daysSinceSubmitted: _asInt(_read(json, 'daysSinceSubmitted')),
    );
  }

  String get normalizedStatus => status.trim().toLowerCase();

  bool get isPendingFinance => normalizedStatus == 'pending_finance';
  bool get isApproved => normalizedStatus == 'approved';
  bool get isRejected => normalizedStatus == 'rejected';
  bool get isPaid =>
      const {'paid', 'done', 'completed', 'selesai'}.contains(normalizedStatus);

  bool get needsFinanceReview => isPendingFinance;
  bool get canCompletePayment => isApproved && !hasPaymentProof;
  bool get isCompleted => isPaid && hasPaymentProof;
  bool get isUrgent => isPendingFinance && daysSinceSubmitted >= 3;

  String get paymentStatusLabel {
    if (isCompleted) return 'Selesai';
    if (isPaid) return 'Dibayar';
    if (isApproved) return 'Menunggu Transfer';
    return statusText.isNotEmpty ? statusText : status;
  }

  String get initials {
    final words = userName
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    if (words.isEmpty) return 'U';
    if (words.length == 1) return words.first.substring(0, 1).toUpperCase();
    return '${words.first.substring(0, 1)}${words.last.substring(0, 1)}'
        .toUpperCase();
  }

  static dynamic _read(
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

  static String _asString(dynamic value) => value?.toString().trim() ?? '';
  static String? _asNullableString(dynamic value) {
    final result = _asString(value);
    return result.isEmpty || result.toLowerCase() == 'null' ? null : result;
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return 0;
    final normalized = raw
        .replaceAll('Rp', '')
        .replaceAll('rp', '')
        .replaceAll(RegExp(r'[^0-9,.\-]'), '');
    if (normalized.contains(',') && normalized.contains('.')) {
      final comma = normalized.lastIndexOf(',');
      final dot = normalized.lastIndexOf('.');
      final decimal = comma > dot ? ',' : '.';
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

  static bool _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value == 1;
    final raw = value?.toString().trim().toLowerCase();
    return raw == 'true' || raw == '1' || raw == 'yes';
  }

  static DateTime _asDate(dynamic value) =>
      _asNullableDate(value) ?? DateTime.now();
  static DateTime? _asNullableDate(dynamic value) {
    final raw = value?.toString().trim();
    return raw == null || raw.isEmpty || raw.toLowerCase() == 'null'
        ? null
        : DateTime.tryParse(raw);
  }
}

class FinanceReimbursementAttachment {
  final String fileName;
  final List<int> bytes;
  final String? contentType;
  const FinanceReimbursementAttachment({
    required this.fileName,
    required this.bytes,
    this.contentType,
  });

  String get extension {
    final cleanName = fileName.split('?').first;
    if (!cleanName.contains('.')) return '';
    return cleanName.split('.').last.toLowerCase();
  }

  bool get isImage =>
      const ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(extension);
  bool get isPdf => extension == 'pdf';
  String get mimeType {
    final headerType = contentType?.split(';').first.trim();
    if (headerType != null && headerType.isNotEmpty) return headerType;
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'pdf':
        return 'application/pdf';
      default:
        return 'application/octet-stream';
    }
  }
}

class FinanceActionResult {
  final bool success;
  final String message;
  const FinanceActionResult({required this.success, required this.message});
  factory FinanceActionResult.fromJson(Map<String, dynamic> json) {
    final success =
        json['success'] == true ||
        json['Success'] == true ||
        json['success'] == 1 ||
        json['Success'] == 1;
    final message = (json['message'] ?? json['Message'] ?? '').toString();
    return FinanceActionResult(success: success, message: message);
  }
}
