// models/office_location_models.dart
class OfficeLocation {
  final int id;
  final String officeName;
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final bool isActive;
  final DateTime createdAt;
  final String statusText;

  OfficeLocation({
    required this.id,
    required this.officeName,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.isActive,
    required this.createdAt,
    required this.statusText,
  });

  factory OfficeLocation.fromJson(Map<String, dynamic> json) {
    return OfficeLocation(
      id: json['id'] ?? 0,
      officeName: json['officeName'] ?? '',
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
      radiusMeters: (json['radiusMeters'] ?? 0.0).toDouble(),
      isActive: json['isActive'] ?? false,
      createdAt: DateTime.parse(
        json['createdAt'] ?? DateTime.now().toIso8601String(),
      ),
      statusText: json['statusText'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'officeName': officeName,
      'latitude': latitude,
      'longitude': longitude,
      'radiusMeters': radiusMeters,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'statusText': statusText,
    };
  }
}

class CreateOfficeLocationRequest {
  final String officeName;
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final String adminId;

  CreateOfficeLocationRequest({
    required this.officeName,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.adminId,
  });

  Map<String, dynamic> toJson() {
    return {
      'officeName': officeName,
      'latitude': latitude,
      'longitude': longitude,
      'radiusMeters': radiusMeters,
      'adminId': adminId,
    };
  }
}

class UpdateOfficeLocationRequest {
  final int id;
  final String officeName;
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final bool isActive;
  final String adminId;

  UpdateOfficeLocationRequest({
    required this.id,
    required this.officeName,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.isActive,
    required this.adminId,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'officeName': officeName,
      'latitude': latitude,
      'longitude': longitude,
      'radiusMeters': radiusMeters,
      'isActive': isActive,
      'adminId': adminId,
    };
  }
}
