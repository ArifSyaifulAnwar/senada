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

  // BUG lama: cuma cek key camelCase, padahal backend mengirim PascalCase
  // ('Id', 'OfficeName', dst) — semua field diam-diam jadi 0/kosong/false.
  static dynamic _get(Map<String, dynamic> j, String k) =>
      j[k[0].toUpperCase() + k.substring(1)] ?? j[k];

  factory OfficeLocation.fromJson(Map<String, dynamic> json) {
    return OfficeLocation(
      id: _get(json, 'id') ?? 0,
      officeName: _get(json, 'officeName') ?? '',
      latitude: (_get(json, 'latitude') ?? 0.0).toDouble(),
      longitude: (_get(json, 'longitude') ?? 0.0).toDouble(),
      radiusMeters: (_get(json, 'radiusMeters') ?? 0.0).toDouble(),
      isActive: _get(json, 'isActive') ?? false,
      createdAt: DateTime.parse(
        _get(json, 'createdAt') ?? DateTime.now().toIso8601String(),
      ),
      statusText: _get(json, 'statusText') ?? '',
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
