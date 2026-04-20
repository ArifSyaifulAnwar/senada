// Services/notification_models.dart
class NotificationItem {
  final int id;
  final String userId;
  final String title;
  final String message;
  final String type;
  final String? typeDisplay;
  final String? iconName;
  final String? colorCode;
  final String? referenceId;
  final String? referenceType;
  final bool isRead;
  final bool isImportant;
  final String? actionText;
  final String? actionUrl;
  final DateTime createdAt;
  final DateTime? readAt;
  final DateTime? expiresAt;

  NotificationItem({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    this.typeDisplay,
    this.iconName,
    this.colorCode,
    this.referenceId,
    this.referenceType,
    required this.isRead,
    required this.isImportant,
    this.actionText,
    this.actionUrl,
    required this.createdAt,
    this.readAt,
    this.expiresAt,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['Id'] ?? 0,
      userId: json['UserId'] ?? '',
      title: json['Title'] ?? '',
      message: json['Message'] ?? '',
      type: json['Type'] ?? '',
      typeDisplay: json['TypeDisplay'],
      iconName: json['IconName'],
      colorCode: json['ColorCode'],
      referenceId: json['ReferenceId'],
      referenceType: json['ReferenceType'],
      isRead: json['IsRead'] ?? false,
      isImportant: json['IsImportant'] ?? false,
      actionText: json['ActionText'],
      actionUrl: json['ActionUrl'],
      createdAt: DateTime.parse(json['CreatedAt']),
      readAt: json['ReadAt'] != null ? DateTime.parse(json['ReadAt']) : null,
      expiresAt: json['ExpiresAt'] != null
          ? DateTime.parse(json['ExpiresAt'])
          : null,
    );
  }

  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} menit yang lalu';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} jam yang lalu';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} hari yang lalu';
    } else {
      return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
    }
  }
}

class NotificationStats {
  final int totalNotifications;
  final int unreadCount;
  final int unreadImportantCount;
  final int thisWeekCount;
  final List<NotificationTypeStats> typeStats;

  NotificationStats({
    required this.totalNotifications,
    required this.unreadCount,
    required this.unreadImportantCount,
    required this.thisWeekCount,
    required this.typeStats,
  });

  factory NotificationStats.fromJson(Map<String, dynamic> json) {
    return NotificationStats(
      totalNotifications: json['TotalNotifications'] ?? 0,
      unreadCount: json['UnreadCount'] ?? 0,
      unreadImportantCount: json['UnreadImportantCount'] ?? 0,
      thisWeekCount: json['ThisWeekCount'] ?? 0,
      typeStats:
          (json['TypeStats'] as List<dynamic>?)
              ?.map((item) => NotificationTypeStats.fromJson(item))
              .toList() ??
          [],
    );
  }
}

class NotificationTypeStats {
  final String type;
  final String displayName;
  final int count;
  final int unreadCount;

  NotificationTypeStats({
    required this.type,
    required this.displayName,
    required this.count,
    required this.unreadCount,
  });

  factory NotificationTypeStats.fromJson(Map<String, dynamic> json) {
    return NotificationTypeStats(
      type: json['Type'] ?? '',
      displayName: json['DisplayName'] ?? '',
      count: json['Count'] ?? 0,
      unreadCount: json['UnreadCount'] ?? 0,
    );
  }
}

class NotificationListResponse {
  final List<NotificationItem> data;
  final int currentPage;
  final int pageSize;
  final int totalCount;
  final int totalPages;
  final NotificationStats? stats;

  NotificationListResponse({
    required this.data,
    required this.currentPage,
    required this.pageSize,
    required this.totalCount,
    required this.totalPages,
    this.stats,
  });

  factory NotificationListResponse.fromJson(Map<String, dynamic> json) {
    return NotificationListResponse(
      data:
          (json['Data'] as List<dynamic>?)
              ?.map((item) => NotificationItem.fromJson(item))
              .toList() ??
          [],
      currentPage: json['CurrentPage'] ?? 1,
      pageSize: json['PageSize'] ?? 10,
      totalCount: json['TotalCount'] ?? 0,
      totalPages: json['TotalPages'] ?? 0,
      stats: json['Stats'] != null
          ? NotificationStats.fromJson(json['Stats'])
          : null,
    );
  }
}

class NotificationCategory {
  final int id;
  final String name;
  final String displayName;
  final String? iconName;
  final String? colorCode;
  final bool isActive;

  NotificationCategory({
    required this.id,
    required this.name,
    required this.displayName,
    this.iconName,
    this.colorCode,
    required this.isActive,
  });

  factory NotificationCategory.fromJson(Map<String, dynamic> json) {
    return NotificationCategory(
      id: json['Id'] ?? 0,
      name: json['Name'] ?? '',
      displayName: json['DisplayName'] ?? '',
      iconName: json['IconName'],
      colorCode: json['ColorCode'],
      isActive: json['IsActive'] ?? true,
    );
  }
}
