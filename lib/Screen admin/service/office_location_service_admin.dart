import 'dart:convert';
import 'package:absensikaryawan/Services/config.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

class LocationService {
  static const String _baseUrl = '$baseURL/api';

  // Get user's current location
  static Future<Position?> getCurrentLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled');
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied');
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      return position;
    } catch (e) {
      return null;
    }
  }

  // Check if current location is within office area
  static Future<LocationCheckResult?> checkOfficeLocation(
    double latitude,
    double longitude,
    String token,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/office-locations/check-location'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'latitude': latitude, 'longitude': longitude}),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success']) {
          return LocationCheckResult.fromJson(result['data']);
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Get all active office locations
  static Future<List<OfficeLocation>> getActiveOfficeLocations(
    String token,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/office-locations/active'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success']) {
          return (result['data'] as List)
              .map((json) => OfficeLocation.fromJson(json))
              .toList();
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // Calculate distance between two points using Haversine formula
  static double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }
}

// Models
class LocationCheckResult {
  final bool isWithinOffice;
  final OfficeLocationCheck? nearestOffice;
  final List<OfficeLocationCheck> allOffices;

  LocationCheckResult({
    required this.isWithinOffice,
    this.nearestOffice,
    required this.allOffices,
  });

  factory LocationCheckResult.fromJson(Map<String, dynamic> json) {
    return LocationCheckResult(
      isWithinOffice: json['isWithinOffice'] ?? false,
      nearestOffice: json['nearestOffice'] != null
          ? OfficeLocationCheck.fromJson(json['nearestOffice'])
          : null,
      allOffices: (json['allOffices'] as List? ?? [])
          .map((e) => OfficeLocationCheck.fromJson(e))
          .toList(),
    );
  }
}

class OfficeLocationCheck {
  final int id;
  final String officeName;
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final double distanceMeters;
  final bool isWithinRange;

  OfficeLocationCheck({
    required this.id,
    required this.officeName,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.distanceMeters,
    required this.isWithinRange,
  });

  factory OfficeLocationCheck.fromJson(Map<String, dynamic> json) {
    return OfficeLocationCheck(
      id: json['id'] ?? 0,
      officeName: json['officeName'] ?? '',
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
      radiusMeters: (json['radiusMeters'] ?? 0.0).toDouble(),
      distanceMeters: (json['distanceMeters'] ?? 0.0).toDouble(),
      isWithinRange: json['isWithinRange'] ?? false,
    );
  }

  String get formattedDistance {
    if (distanceMeters < 1000) {
      return '${distanceMeters.round()} m';
    } else {
      return '${(distanceMeters / 1000).toStringAsFixed(2)} km';
    }
  }
}

class OfficeLocation {
  final int id;
  final String officeName;
  final double latitude;
  final double longitude;
  final double radiusMeters;

  OfficeLocation({
    required this.id,
    required this.officeName,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
  });

  factory OfficeLocation.fromJson(Map<String, dynamic> json) {
    return OfficeLocation(
      id: json['id'] ?? 0,
      officeName: json['officeName'] ?? '',
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
      radiusMeters: (json['radiusMeters'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'officeName': officeName,
      'latitude': latitude,
      'longitude': longitude,
      'radiusMeters': radiusMeters,
    };
  }
}

// Enhanced LocationManager class for better integration
class LocationManager {
  static LocationManager? _instance;
  static LocationManager get instance => _instance ??= LocationManager._();
  LocationManager._();

  Position? _lastKnownPosition;
  List<OfficeLocation> _officeLocations = [];
  bool _isLocationServiceEnabled = false;

  Position? get lastKnownPosition => _lastKnownPosition;
  List<OfficeLocation> get officeLocations => _officeLocations;
  bool get isLocationServiceEnabled => _isLocationServiceEnabled;

  // Initialize location manager
  Future<void> initialize(String token) async {
    await _checkLocationService();
    await loadOfficeLocations(token);
  }

  Future<void> _checkLocationService() async {
    _isLocationServiceEnabled = await Geolocator.isLocationServiceEnabled();
  }

  // Load office locations from API
  Future<void> loadOfficeLocations(String token) async {
    _officeLocations = await LocationService.getActiveOfficeLocations(token);
  }

  // Get current location with caching
  Future<Position?> getCurrentLocation({bool forceRefresh = false}) async {
    if (!forceRefresh && _lastKnownPosition != null) {
      // Return cached position if it's less than 1 minute old
      final now = DateTime.now();
      final positionTime = DateTime.fromMillisecondsSinceEpoch(
        _lastKnownPosition!.timestamp.millisecondsSinceEpoch,
      );
      if (now.difference(positionTime).inMinutes < 1) {
        return _lastKnownPosition;
      }
    }

    final position = await LocationService.getCurrentLocation();
    if (position != null) {
      _lastKnownPosition = position;
    }
    return position;
  }

  // Check if current location is within any office
  Future<LocationValidationResult> validateCurrentLocation(String token) async {
    final position = await getCurrentLocation();
    if (position == null) {
      return LocationValidationResult(
        isValid: false,
        errorMessage: 'Tidak dapat mendapatkan lokasi saat ini',
      );
    }

    final checkResult = await LocationService.checkOfficeLocation(
      position.latitude,
      position.longitude,
      token,
    );

    if (checkResult == null) {
      return LocationValidationResult(
        isValid: false,
        errorMessage: 'Gagal memvalidasi lokasi',
      );
    }

    return LocationValidationResult(
      isValid: checkResult.isWithinOffice,
      position: position,
      checkResult: checkResult,
      errorMessage: checkResult.isWithinOffice
          ? null
          : 'Anda berada di luar area kantor',
    );
  }

  // Get nearest office location
  OfficeLocation? getNearestOffice(double latitude, double longitude) {
    if (_officeLocations.isEmpty) return null;

    OfficeLocation? nearest;
    double minDistance = double.infinity;

    for (final office in _officeLocations) {
      final distance = LocationService.calculateDistance(
        latitude,
        longitude,
        office.latitude,
        office.longitude,
      );

      if (distance < minDistance) {
        minDistance = distance;
        nearest = office;
      }
    }

    return nearest;
  }

  // Format location for display
  String formatLocation(Position position) {
    return '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
  }

  // Get location accuracy description
  String getAccuracyDescription(Position position) {
    if (position.accuracy < 5) return 'Sangat Tepat';
    if (position.accuracy < 10) return 'Tepat';
    if (position.accuracy < 20) return 'Cukup Tepat';
    return 'Kurang Tepat';
  }
}

class LocationValidationResult {
  final bool isValid;
  final Position? position;
  final LocationCheckResult? checkResult;
  final String? errorMessage;

  LocationValidationResult({
    required this.isValid,
    this.position,
    this.checkResult,
    this.errorMessage,
  });

  String get formattedLocation {
    if (position == null) return '-';
    return '${position!.latitude.toStringAsFixed(6)}, ${position!.longitude.toStringAsFixed(6)}';
  }

  String get nearestOfficeName {
    return checkResult?.nearestOffice?.officeName ?? 'Tidak diketahui';
  }

  String get distanceToNearestOffice {
    return checkResult?.nearestOffice?.formattedDistance ?? '-';
  }
}
