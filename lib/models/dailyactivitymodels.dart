import 'dart:typed_data';
import 'package:flutter/material.dart';

class DailyActivityAttachment {
  final int? id;
  final String fileName;
  final String fileType;
  final Uint8List? bytes; // null kalau attachment lama dari server

  DailyActivityAttachment({
    this.id,
    required this.fileName,
    required this.fileType,
    this.bytes,
  });

  bool get isImage => fileType.startsWith('image/');
  int get sizeBytes => bytes?.length ?? 0;

  factory DailyActivityAttachment.fromJson(Map<String, dynamic> json) {
    return DailyActivityAttachment(
      id: json['Id'],
      fileName: json['Name'] ?? '',
      fileType: json['FileType'] ?? '',
    );
  }
}

class DailyActivityCategory {
  final int id;
  final String key;
  final String label;
  final String iconName;

  const DailyActivityCategory({
    required this.id,
    required this.key,
    required this.label,
    required this.iconName,
  });

  factory DailyActivityCategory.fromJson(Map<String, dynamic> json) {
    return DailyActivityCategory(
      id: json['Id'] ?? 0,
      key: json['CategoryKey'] ?? '',
      label: json['Label'] ?? '',
      iconName: json['IconName'] ?? 'more_horiz_rounded',
    );
  }

  IconData get icon => _iconFromName(iconName);
}

// Mapping string nama icon -> IconData konstan Flutter.
// Wajib pakai switch, karena IconData harus dibuat dari literal const.
IconData _iconFromName(String iconName) {
  switch (iconName) {
    case 'groups_rounded':
      return Icons.groups_rounded;
    case 'directions_walk_rounded':
      return Icons.directions_walk_rounded;
    case 'description_rounded':
      return Icons.description_rounded;
    case 'connect_without_contact_rounded':
      return Icons.connect_without_contact_rounded;
    case 'school_rounded':
      return Icons.school_rounded;
    case 'more_horiz_rounded':
    default:
      return Icons.more_horiz_rounded;
  }
}

class OfficeLocation {
  final int id;
  final String officeName;
  final double latitude;
  final double longitude;
  final double radiusMeters;

  const OfficeLocation({
    required this.id,
    required this.officeName,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
  });

  factory OfficeLocation.fromJson(Map<String, dynamic> json) {
    return OfficeLocation(
      id: json['id'] ?? json['Id'] ?? 0,
      officeName:
          json['officeName'] ?? json['office_name'] ?? json['OfficeName'] ?? '',
      latitude:
          double.tryParse(
            (json['latitude'] ?? json['Latitude'])?.toString() ?? '0',
          ) ??
          0,
      longitude:
          double.tryParse(
            (json['longitude'] ?? json['Longitude'])?.toString() ?? '0',
          ) ??
          0,
      radiusMeters:
          double.tryParse(
            (json['radiusMeters'] ??
                        json['radius_meters'] ??
                        json['RadiusMeters'])
                    ?.toString() ??
                '0',
          ) ??
          0,
    );
  }
}

class TimeOfDayValue {
  final int hour;
  final int minute;
  const TimeOfDayValue(this.hour, this.minute);

  String get formatted =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  static TimeOfDayValue? tryParse(String? hhmm) {
    if (hhmm == null || hhmm.isEmpty) return null;
    final parts = hhmm.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDayValue(h, m);
  }
}

class DailyActivityItem {
  final int? id;
  final DateTime activityDate;
  final String description;
  final int categoryId;
  final String categoryKey;
  final String categoryLabel;
  final String iconName;
  final int? officeLocationId;
  final String? officeName;
  final String? locationText;
  final TimeOfDayValue? startTime;
  final TimeOfDayValue? endTime;
  final List<DailyActivityAttachment> attachments;
  final String? status;
  final String? reviewNotes;

  DailyActivityItem({
    this.id,
    required this.activityDate,
    required this.description,
    required this.categoryId,
    required this.categoryKey,
    required this.categoryLabel,
    required this.iconName,
    this.officeLocationId,
    this.officeName,
    this.locationText,
    this.startTime,
    this.endTime,
    this.attachments = const [],
    this.status,
    this.reviewNotes,
  });

  String get displayLocation =>
      (officeName?.isNotEmpty ?? false) ? officeName! : (locationText ?? '');

  IconData get icon => _iconFromName(iconName);

  factory DailyActivityItem.fromJson(Map<String, dynamic> json) {
    return DailyActivityItem(
      id: json['Id'],
      activityDate:
          DateTime.tryParse(json['ActivityDate']?.toString() ?? '') ??
          DateTime.now(),
      description: json['Description'] ?? '',
      categoryId: json['CategoryId'] ?? 0,
      categoryKey: json['CategoryKey'] ?? '',
      categoryLabel: json['CategoryLabel'] ?? '-',
      iconName: json['IconName'] ?? 'more_horiz_rounded',
      officeLocationId: json['OfficeLocationId'],
      officeName: json['OfficeName'],
      locationText: json['LocationText'],
      startTime: TimeOfDayValue.tryParse(json['StartTime']),
      endTime: TimeOfDayValue.tryParse(json['EndTime']),
      attachments: (json['Attachments'] as List<dynamic>? ?? [])
          .map((e) => DailyActivityAttachment.fromJson(e))
          .toList(),
      status: json['Status'],
      reviewNotes: json['ReviewNotes'],
    );
  }
}
// Services/dailyactivitymodels.dart — tambahkan class baru di file yang sama

class DailyActivityHRDItem extends DailyActivityItem {
  final String employeeName;
  final String jobPosition;
  final String organization;

  DailyActivityHRDItem({
    super.id,
    required super.activityDate,
    required super.description,
    required super.categoryId,
    required super.categoryKey,
    required super.categoryLabel,
    required super.iconName,
    super.officeLocationId,
    super.officeName,
    super.locationText,
    super.startTime,
    super.endTime,
    super.attachments,
    required this.employeeName,
    required this.jobPosition,
    required this.organization,
  });

  factory DailyActivityHRDItem.fromJson(Map<String, dynamic> json) {
    return DailyActivityHRDItem(
      id: json['Id'],
      activityDate:
          DateTime.tryParse(json['ActivityDate']?.toString() ?? '') ??
          DateTime.now(),
      description: json['Description'] ?? '',
      categoryId: json['CategoryId'] ?? 0,
      categoryKey: json['CategoryKey'] ?? '',
      categoryLabel: json['CategoryLabel'] ?? '-',
      iconName: json['IconName'] ?? 'more_horiz_rounded',
      officeLocationId: json['OfficeLocationId'],
      officeName: json['OfficeName'],
      locationText: json['LocationText'],
      startTime: TimeOfDayValue.tryParse(json['StartTime']),
      endTime: TimeOfDayValue.tryParse(json['EndTime']),
      attachments: (json['Attachments'] as List<dynamic>? ?? [])
          .map((e) => DailyActivityAttachment.fromJson(e))
          .toList(),
      employeeName: json['EmployeeName'] ?? '-',
      jobPosition: json['JobPosition'] ?? '-',
      organization: json['Organization'] ?? '-',
    );
  }
}
