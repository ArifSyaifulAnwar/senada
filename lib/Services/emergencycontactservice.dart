// services/emergency_contact_service.dart
import 'dart:convert';
import 'package:absensikaryawan/Services/config.dart';
import 'package:http/http.dart' as http;

// Models
class EmergencyContact {
  final int id;
  final String userId;
  final String name;
  final String relationship;
  final String phoneNumber;
  final String? email;
  final String? address;
  final bool isPrimary;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  EmergencyContact({
    required this.id,
    required this.userId,
    required this.name,
    required this.relationship,
    required this.phoneNumber,
    this.email,
    this.address,
    required this.isPrimary,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      id: json['Id'],
      userId: json['UserId'],
      name: json['Name'],
      relationship: json['Relationship'],
      phoneNumber: json['PhoneNumber'],
      email: json['Email'],
      address: json['Address'],
      isPrimary: json['IsPrimary'],
      isActive: json['IsActive'],
      createdAt: DateTime.parse(json['CreatedAt']),
      updatedAt: DateTime.parse(json['UpdatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'relationship': relationship,
      'phoneNumber': phoneNumber,
      'email': email,
      'address': address,
      'isPrimary': isPrimary,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

class EmergencyContactCategory {
  final int id;
  final String name;
  final String? description;

  EmergencyContactCategory({
    required this.id,
    required this.name,
    this.description,
  });

  factory EmergencyContactCategory.fromJson(Map<String, dynamic> json) {
    return EmergencyContactCategory(
      id: json['Id'],
      name: json['Name'],
      description: json['Description'],
    );
  }
}

class ApiResponse<T> {
  final bool success;
  final String message;
  final T? data;
  final int? totalCount;
  final int? contactId;

  ApiResponse({
    required this.success,
    required this.message,
    this.data,
    this.totalCount,
    this.contactId,
  });
}

class EmergencyContactService {
  // static Map<String, String> get _headers => {
  //   'Content-Type': 'application/json',
  //   if (_authToken != null) 'Authorization': 'Bearer $_authToken',
  // };
  static Future<String?> _getToken() async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseURL/api/auth/token'),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: {'grant_type': 'password', 'password': 'ASN_DBS'},
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data.containsKey('access_token') && data['access_token'] != null) {
          return data['access_token'];
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // PUBLIC method untuk external access
  Future<Map<String, String>> getHeaders() async {
    return await _getHeaders();
  }

  // GET: Daftar kontak darurat
  Future<ApiResponse<List<EmergencyContact>>> getEmergencyContacts(
    String userId, {
    bool includeInactive = false,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseURL/api/asn/emergency-contact/list'),
        headers: await getHeaders(),
        body: jsonEncode({
          'userId': userId,
          'includeInactive': includeInactive,
        }),
      );

      final Map<String, dynamic> responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final List<dynamic> contactsJson = responseData['Data'] ?? [];
        final List<EmergencyContact> contacts = contactsJson
            .map((json) => EmergencyContact.fromJson(json))
            .toList();

        return ApiResponse<List<EmergencyContact>>(
          success: responseData['Success'] ?? false,
          message: responseData['Message'] ?? '',
          data: contacts,
          totalCount: responseData['TotalCount'],
        );
      } else {
        return ApiResponse<List<EmergencyContact>>(
          success: false,
          message: responseData['Message'] ?? 'Failed to fetch contacts',
        );
      }
    } catch (e) {
      return ApiResponse<List<EmergencyContact>>(
        success: false,
        message: 'Network error: $e',
      );
    }
  }

  // GET: Detail kontak darurat
  Future<ApiResponse<EmergencyContact>> getEmergencyContactDetail(
    int id, {
    String? userId,
  }) async {
    try {
      final uri = Uri.parse('$baseURL/api/asn/emergency-contact/detail/$id');
      final uriWithQuery = userId != null
          ? uri.replace(queryParameters: {'userId': userId})
          : uri;

      final response = await http.get(
        uriWithQuery,
        headers: await getHeaders(),
      );
      final Map<String, dynamic> responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final EmergencyContact contact = EmergencyContact.fromJson(
          responseData['data'],
        );

        return ApiResponse<EmergencyContact>(
          success: responseData['success'] ?? false,
          message: responseData['message'] ?? '',
          data: contact,
        );
      } else {
        return ApiResponse<EmergencyContact>(
          success: false,
          message: responseData['message'] ?? 'Contact not found',
        );
      }
    } catch (e) {
      return ApiResponse<EmergencyContact>(
        success: false,
        message: 'Network error: $e',
      );
    }
  }

  // POST: Buat kontak darurat baru
  Future<ApiResponse<EmergencyContact>> createEmergencyContact({
    required String userId,
    required String name,
    required String relationship,
    required String phoneNumber,
    String? email,
    String? address,
    bool isPrimary = false,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseURL/api/asn/emergency-contact/create'),
        headers: await getHeaders(),
        body: jsonEncode({
          'userId': userId,
          'name': name,
          'relationship': relationship,
          'phoneNumber': phoneNumber,
          'email': email,
          'address': address,
          'isPrimary': isPrimary,
        }),
      );

      final Map<String, dynamic> responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final EmergencyContact contact = EmergencyContact.fromJson(
          responseData['Data'],
        );

        return ApiResponse<EmergencyContact>(
          success: responseData['Success'] ?? false,
          message: responseData['Message'] ?? '',
          data: contact,
          contactId: responseData['ContactId'],
        );
      } else {
        return ApiResponse<EmergencyContact>(
          success: false,
          message: responseData['Message'] ?? 'Failed to create contact',
        );
      }
    } catch (e) {
      return ApiResponse<EmergencyContact>(
        success: false,
        message: 'Network error: $e',
      );
    }
  }

  // PUT: Update kontak darurat
  Future<ApiResponse<EmergencyContact>> updateEmergencyContact({
    required int id,
    required String userId,
    required String name,
    required String relationship,
    required String phoneNumber,
    String? email,
    String? address,
    bool isPrimary = false,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseURL/api/asn/emergency-contact/update'),
        headers: await getHeaders(),
        body: jsonEncode({
          'id': id,
          'userId': userId,
          'name': name,
          'relationship': relationship,
          'phoneNumber': phoneNumber,
          'email': email,
          'address': address,
          'isPrimary': isPrimary,
        }),
      );

      final Map<String, dynamic> responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final EmergencyContact contact = EmergencyContact.fromJson(
          responseData['data'],
        );

        return ApiResponse<EmergencyContact>(
          success: responseData['success'] ?? false,
          message: responseData['message'] ?? '',
          data: contact,
        );
      } else {
        return ApiResponse<EmergencyContact>(
          success: false,
          message: responseData['message'] ?? 'Failed to update contact',
        );
      }
    } catch (e) {
      return ApiResponse<EmergencyContact>(
        success: false,
        message: 'Network error: $e',
      );
    }
  }

  // DELETE: Hapus kontak darurat
  Future<ApiResponse<void>> deleteEmergencyContact(
    int id,
    String userId,
  ) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseURL/api/asn/emergency-contact/delete'),
        headers: await getHeaders(),
        body: jsonEncode({'id': id, 'userId': userId}),
      );

      final Map<String, dynamic> responseData = jsonDecode(response.body);

      return ApiResponse<void>(
        success: responseData['success'] ?? false,
        message: responseData['message'] ?? '',
      );
    } catch (e) {
      return ApiResponse<void>(success: false, message: 'Network error: $e');
    }
  }

  // POST: Set kontak sebagai primary
  Future<ApiResponse<void>> setPrimaryContact(int id, String userId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseURL/api/asn/emergency-contact/set-primary'),
        headers: await getHeaders(),
        body: jsonEncode({'id': id, 'userId': userId}),
      );

      final Map<String, dynamic> responseData = jsonDecode(response.body);

      return ApiResponse<void>(
        success: responseData['success'] ?? false,
        message: responseData['message'] ?? '',
      );
    } catch (e) {
      return ApiResponse<void>(success: false, message: 'Network error: $e');
    }
  }

  // GET: Kategori hubungan
  Future<ApiResponse<List<EmergencyContactCategory>>> getCategories() async {
    try {
      final response = await http.get(
        Uri.parse('$baseURL/api/asn/emergency-contact/categories'),
        headers: await getHeaders(),
      );

      final Map<String, dynamic> responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final List<dynamic> categoriesJson = responseData['data'] ?? [];
        final List<EmergencyContactCategory> categories = categoriesJson
            .map((json) => EmergencyContactCategory.fromJson(json))
            .toList();

        return ApiResponse<List<EmergencyContactCategory>>(
          success: responseData['success'] ?? false,
          message: responseData['message'] ?? '',
          data: categories,
        );
      } else {
        return ApiResponse<List<EmergencyContactCategory>>(
          success: false,
          message: responseData['message'] ?? 'Failed to fetch categories',
        );
      }
    } catch (e) {
      return ApiResponse<List<EmergencyContactCategory>>(
        success: false,
        message: 'Network error: $e',
      );
    }
  }
}
