// models/admin_notification_models.dart

// Backend ini kadang balikin JSON PascalCase (mis. "Id", "UserId") dan kadang
// camelCase tergantung endpoint — helper ini coba dua-duanya supaya parsing
// tidak crash kalau formatnya PascalCase.
dynamic _j(Map<String, dynamic> json, String camelKey) {
  if (json.containsKey(camelKey) && json[camelKey] != null) {
    return json[camelKey];
  }
  final pascalKey = camelKey[0].toUpperCase() + camelKey.substring(1);
  return json[pascalKey];
}

class AdminNotification {
  final int id;
  final String userId;
  final String userName;
  final String? employeeNumber;
  final String? department;
  final String title;
  final String message;
  final String type;
  final String typeDisplay;
  final String? referenceId;
  final String? referenceType;
  final bool isRead;
  final bool isImportant;
  final String? actionText;
  final String? actionUrl;
  final DateTime createdAt;
  final DateTime? readAt;
  final DateTime? expiresAt;
  final String timeAgo;

  // PDF attachment fields
  final String? pdfFileName;
  final String? pdfFilePath;
  final int? pdfFileSize;
  final DateTime? pdfUploadedAt;
  final String? pdfUploadedBy;

  AdminNotification({
    required this.id,
    required this.userId,
    required this.userName,
    this.employeeNumber,
    this.department,
    required this.title,
    required this.message,
    required this.type,
    required this.typeDisplay,
    this.referenceId,
    this.referenceType,
    required this.isRead,
    required this.isImportant,
    this.actionText,
    this.actionUrl,
    required this.createdAt,
    this.readAt,
    this.expiresAt,
    required this.timeAgo,
    this.pdfFileName,
    this.pdfFilePath,
    this.pdfFileSize,
    this.pdfUploadedAt,
    this.pdfUploadedBy,
  });

  bool get hasPdfAttachment => pdfFileName != null && pdfFileName!.isNotEmpty;

  String get formattedFileSize {
    if (pdfFileSize == null) return '';
    if (pdfFileSize! < 1024) return '$pdfFileSize B';
    if (pdfFileSize! < 1024 * 1024) {
      return '${(pdfFileSize! / 1024).toStringAsFixed(1)} KB';
    }
    return '${(pdfFileSize! / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  factory AdminNotification.fromJson(Map<String, dynamic> json) {
    return AdminNotification(
      id: _j(json, 'id'),
      userId: _j(json, 'userId'),
      userName: _j(json, 'userName'),
      employeeNumber: _j(json, 'employeeNumber'),
      department: _j(json, 'department'),
      title: _j(json, 'title'),
      message: _j(json, 'message'),
      type: _j(json, 'type'),
      typeDisplay: _j(json, 'typeDisplay'),
      referenceId: _j(json, 'referenceId'),
      referenceType: _j(json, 'referenceType'),
      isRead: _j(json, 'isRead') ?? false,
      isImportant: _j(json, 'isImportant') ?? false,
      actionText: _j(json, 'actionText'),
      actionUrl: _j(json, 'actionUrl'),
      createdAt: DateTime.parse(_j(json, 'createdAt')),
      readAt: _j(json, 'readAt') != null
          ? DateTime.parse(_j(json, 'readAt'))
          : null,
      expiresAt: _j(json, 'expiresAt') != null
          ? DateTime.parse(_j(json, 'expiresAt'))
          : null,
      timeAgo: _j(json, 'timeAgo') ?? '',
      pdfFileName: _j(json, 'pdfFileName'),
      pdfFilePath: _j(json, 'pdfFilePath'),
      pdfFileSize: _j(json, 'pdfFileSize'),
      pdfUploadedAt: _j(json, 'pdfUploadedAt') != null
          ? DateTime.parse(_j(json, 'pdfUploadedAt'))
          : null,
      pdfUploadedBy: _j(json, 'pdfUploadedBy'),
    );
  }
}

class AdminNotificationRequest {
  final int page;
  final int pageSize;
  final String? typeFilter;
  final String? userIdFilter;
  final bool? isReadFilter;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? searchText;
  final String? requesterUserId;
  final String? requesterRole;

  AdminNotificationRequest({
    this.page = 1,
    this.pageSize = 20,
    this.typeFilter,
    this.userIdFilter,
    this.isReadFilter,
    this.dateFrom,
    this.dateTo,
    this.searchText,
    this.requesterUserId,
    this.requesterRole,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'page': page, 'pageSize': pageSize};
    if (typeFilter != null) map['typeFilter'] = typeFilter;
    if (userIdFilter != null) map['userIdFilter'] = userIdFilter;
    if (isReadFilter != null) map['isReadFilter'] = isReadFilter;
    if (dateFrom != null) map['dateFrom'] = dateFrom!.toIso8601String();
    if (dateTo != null) map['dateTo'] = dateTo!.toIso8601String();
    if (searchText != null) map['searchText'] = searchText;
    if (requesterUserId != null) map['requesterUserId'] = requesterUserId;
    if (requesterRole != null) map['requesterRole'] = requesterRole;
    return map;
  }
}

class AdminNotificationResponse {
  final List<AdminNotification> data;
  final int totalCount;
  final int page;
  final int pageSize;
  final int totalPages;
  final AdminNotificationStats stats;

  AdminNotificationResponse({
    required this.data,
    required this.totalCount,
    required this.page,
    required this.pageSize,
    required this.totalPages,
    required this.stats,
  });

  factory AdminNotificationResponse.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'] ?? json['Data'] ?? [];
    final rawStats = json['stats'] ?? json['Stats'];
    return AdminNotificationResponse(
      data: (rawData as List)
          .map((item) => AdminNotification.fromJson(item))
          .toList(),
      totalCount: json['totalCount'] ?? json['TotalCount'] ?? 0,
      page: json['page'] ?? json['Page'] ?? 1,
      pageSize: json['pageSize'] ?? json['PageSize'] ?? 20,
      totalPages: json['totalPages'] ?? json['TotalPages'] ?? 0,
      stats: rawStats != null
          ? AdminNotificationStats.fromJson(rawStats)
          : AdminNotificationStats(
              totalNotifications: 0,
              unreadCount: 0,
              readCount: 0,
              importantCount: 0,
              expiredCount: 0,
              todayCount: 0,
              weekCount: 0,
              typeStats: [],
            ),
    );
  }
}

class AdminNotificationStats {
  final int totalNotifications;
  final int unreadCount;
  final int readCount;
  final int importantCount;
  final int expiredCount;
  final int todayCount;
  final int weekCount;
  final List<NotificationTypeStats> typeStats;

  AdminNotificationStats({
    required this.totalNotifications,
    required this.unreadCount,
    required this.readCount,
    required this.importantCount,
    required this.expiredCount,
    required this.todayCount,
    required this.weekCount,
    required this.typeStats,
  });

  factory AdminNotificationStats.fromJson(Map<String, dynamic> json) {
    return AdminNotificationStats(
      totalNotifications: json['totalNotifications'] ?? json['TotalNotifications'] ?? 0,
      unreadCount: json['unreadCount'] ?? json['UnreadCount'] ?? 0,
      readCount: json['readCount'] ?? json['ReadCount'] ?? 0,
      importantCount: json['importantCount'] ?? json['ImportantCount'] ?? 0,
      expiredCount: json['expiredCount'] ?? json['ExpiredCount'] ?? 0,
      todayCount: json['todayCount'] ?? json['TodayCount'] ?? 0,
      weekCount: json['weekCount'] ?? json['WeekCount'] ?? 0,
      typeStats: ((json['typeStats'] ?? json['TypeStats']) as List?)
              ?.map((item) => NotificationTypeStats.fromJson(item))
              .toList() ??
          [],
    );
  }
}

class NotificationTypeStats {
  final String type;
  final String typeDisplay;
  final int count;
  final int unreadCount;

  NotificationTypeStats({
    required this.type,
    required this.typeDisplay,
    required this.count,
    required this.unreadCount,
  });

  factory NotificationTypeStats.fromJson(Map<String, dynamic> json) {
    return NotificationTypeStats(
      type: _j(json, 'type') ?? '',
      typeDisplay: _j(json, 'typeDisplay') ?? '',
      count: _j(json, 'count') ?? 0,
      unreadCount: _j(json, 'unreadCount') ?? 0,
    );
  }
}

class CreateNotificationRequest {
  final String? userId;
  final String title;
  final String message;
  final String type;
  final String? referenceId;
  final String? referenceType;
  final bool isImportant;
  final String? actionText;
  final String? actionUrl;
  final DateTime? expiresAt;
  final bool sendToAll;
  final String? createdBy;
  final String? requesterRole;

  CreateNotificationRequest({
    this.userId,
    required this.title,
    required this.message,
    required this.type,
    this.referenceId,
    this.referenceType,
    this.isImportant = false,
    this.actionText,
    this.actionUrl,
    this.expiresAt,
    this.sendToAll = false,
    this.createdBy,
    this.requesterRole,
  });

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'title': title,
      'message': message,
      'type': type,
      'referenceId': referenceId,
      'referenceType': referenceType,
      'isImportant': isImportant,
      'actionText': actionText,
      'actionUrl': actionUrl,
      'expiresAt': expiresAt?.toIso8601String(),
      'sendToAll': sendToAll,
      'createdBy': createdBy,
      'requesterRole': requesterRole,
    };
  }
}

class UpdateNotificationRequest {
  final int id;
  final String title;
  final String message;
  final String type;
  final bool isImportant;
  final String? actionText;
  final String? actionUrl;
  final DateTime? expiresAt;
  final String? requesterRole;

  UpdateNotificationRequest({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    this.isImportant = false,
    this.actionText,
    this.actionUrl,
    this.expiresAt,
    this.requesterRole,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'type': type,
      'isImportant': isImportant,
      'actionText': actionText,
      'actionUrl': actionUrl,
      'expiresAt': expiresAt?.toIso8601String(),
      'requesterRole': requesterRole,
    };
  }
}

class UserForNotification {
  final String userId;
  final String name;
  final String? employeeNumber;
  final String? department;
  final String? position;
  final String mail;

  UserForNotification({
    required this.userId,
    required this.name,
    this.employeeNumber,
    this.department,
    this.position,
    required this.mail,
  });

  factory UserForNotification.fromJson(Map<String, dynamic> json) {
    return UserForNotification(
      userId: _j(json, 'userId') ?? '',
      name: _j(json, 'name') ?? '',
      employeeNumber: _j(json, 'employeeNumber'),
      department: _j(json, 'department'),
      position: _j(json, 'position'),
      mail: _j(json, 'mail') ?? '',
    );
  }
}

class NotificationTypeOption {
  final String value;
  final String display;

  NotificationTypeOption({required this.value, required this.display});

  factory NotificationTypeOption.fromJson(Map<String, dynamic> json) {
    return NotificationTypeOption(
      value: _j(json, 'value') ?? '',
      display: _j(json, 'display') ?? '',
    );
  }
}

class ApiResponse<T> {
  final bool success;
  final String message;
  final T? data;

  ApiResponse({required this.success, required this.message, this.data});

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T? Function(Map<String, dynamic>)? fromJsonT,
  ) {
    return ApiResponse<T>(
      success: json['success'],
      message: json['message'],
      data: json['data'] != null && fromJsonT != null
          ? fromJsonT(json['data'])
          : json['data'],
    );
  }
}
