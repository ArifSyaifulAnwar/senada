// services/emergency_contact_service.dart
import 'dart:convert';
import 'package:absensikaryawan/Services/config.dart';
import 'package:absensikaryawan/Services/token_service.dart';
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

// Kontak darurat 1 karyawan — dipakai Head HRD untuk lihat semua karyawan
// sekaligus (endpoint admin-list).
class EmployeeEmergencyContactGroup {
  final String userId;
  final String employeeName;
  final String? employeeJob;
  final String? department;
  final List<EmergencyContact> contacts;

  EmployeeEmergencyContactGroup({
    required this.userId,
    required this.employeeName,
    this.employeeJob,
    this.department,
    required this.contacts,
  });

  factory EmployeeEmergencyContactGroup.fromJson(Map<String, dynamic> json) {
    dynamic get(String key) =>
        json[key] ?? json[key[0].toLowerCase() + key.substring(1)];
    final rawContacts = get('Contacts') as List? ?? [];
    return EmployeeEmergencyContactGroup(
      userId: get('UserId') ?? '',
      employeeName: get('EmployeeName') ?? '',
      employeeJob: get('EmployeeJob'),
      department: get('Department'),
      contacts: rawContacts
          .map((e) => EmergencyContact.fromJson(e as Map<String, dynamic>))
          .toList(),
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
  // Reuse TokenService (dedupe + cache sesuai expires_in dari server) —
  // dulu fetch token baru dari /api/auth/token setiap kali dipanggil tanpa
  // cache dan tanpa cek null sebelum dipakai di header, jadi rawan kirim
  // "Authorization: Bearer null" dan kena 401.
  Future<Map<String, String>> _getHeaders() => TokenService.jsonHeaders();

  // PUBLIC method untuk external access
  Future<Map<String, String>> getHeaders() async {
    return await _getHeaders();
  }

  // Response dari backend ini PascalCase (Success/Message/Data), tapi
  // beberapa method di bawah sempat ditulis mengakses key lowercase
  // (success/message/data) — pakai dual-fallback supaya konsisten & aman
  // dari kesalahan casing di kedua arah.
  static dynamic _get(Map<String, dynamic> body, String key) {
    if (body.containsKey(key)) return body[key];
    final lower = key[0].toLowerCase() + key.substring(1);
    if (body.containsKey(lower)) return body[lower];
    final pascal = key[0].toUpperCase() + key.substring(1);
    if (body.containsKey(pascal)) return body[pascal];
    return null;
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
        final List<dynamic> contactsJson = _get(responseData, 'Data') ?? [];
        final List<EmergencyContact> contacts = contactsJson
            .map((json) => EmergencyContact.fromJson(json))
            .toList();

        return ApiResponse<List<EmergencyContact>>(
          success: _get(responseData, 'Success') ?? false,
          message: _get(responseData, 'Message') ?? '',
          data: contacts,
          totalCount: _get(responseData, 'TotalCount'),
        );
      } else {
        return ApiResponse<List<EmergencyContact>>(
          success: false,
          message: _get(responseData, 'Message') ?? 'Failed to fetch contacts',
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
          _get(responseData, 'Data'),
        );

        return ApiResponse<EmergencyContact>(
          success: _get(responseData, 'Success') ?? false,
          message: _get(responseData, 'Message') ?? '',
          data: contact,
        );
      } else {
        return ApiResponse<EmergencyContact>(
          success: false,
          message: _get(responseData, 'Message') ?? 'Contact not found',
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
    String? actorUserId,
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
          'actorUserId': actorUserId,
        }),
      );

      final Map<String, dynamic> responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final EmergencyContact contact = EmergencyContact.fromJson(
          _get(responseData, 'Data'),
        );

        return ApiResponse<EmergencyContact>(
          success: _get(responseData, 'Success') ?? false,
          message: _get(responseData, 'Message') ?? '',
          data: contact,
          contactId: _get(responseData, 'ContactId'),
        );
      } else {
        return ApiResponse<EmergencyContact>(
          success: false,
          message: _get(responseData, 'Message') ?? 'Failed to create contact',
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
    String? actorUserId,
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
          'actorUserId': actorUserId,
        }),
      );

      final Map<String, dynamic> responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final EmergencyContact contact = EmergencyContact.fromJson(
          _get(responseData, 'Data'),
        );

        return ApiResponse<EmergencyContact>(
          success: _get(responseData, 'Success') ?? false,
          message: _get(responseData, 'Message') ?? '',
          data: contact,
        );
      } else {
        return ApiResponse<EmergencyContact>(
          success: false,
          message: _get(responseData, 'Message') ?? 'Failed to update contact',
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
    String userId, {
    String? actorUserId,
  }) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseURL/api/asn/emergency-contact/delete'),
        headers: await getHeaders(),
        body: jsonEncode({'id': id, 'userId': userId, 'actorUserId': actorUserId}),
      );

      final Map<String, dynamic> responseData = jsonDecode(response.body);

      return ApiResponse<void>(
        success: _get(responseData, 'Success') ?? false,
        message: _get(responseData, 'Message') ?? '',
      );
    } catch (e) {
      return ApiResponse<void>(success: false, message: 'Network error: $e');
    }
  }

  // POST: Set kontak sebagai primary
  Future<ApiResponse<void>> setPrimaryContact(
    int id,
    String userId, {
    String? actorUserId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseURL/api/asn/emergency-contact/set-primary'),
        headers: await getHeaders(),
        body: jsonEncode({'id': id, 'userId': userId, 'actorUserId': actorUserId}),
      );

      final Map<String, dynamic> responseData = jsonDecode(response.body);

      return ApiResponse<void>(
        success: _get(responseData, 'Success') ?? false,
        message: _get(responseData, 'Message') ?? '',
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
        final List<dynamic> categoriesJson = _get(responseData, 'Data') ?? [];
        final List<EmergencyContactCategory> categories = categoriesJson
            .map((json) => EmergencyContactCategory.fromJson(json))
            .toList();

        return ApiResponse<List<EmergencyContactCategory>>(
          success: _get(responseData, 'Success') ?? false,
          message: _get(responseData, 'Message') ?? '',
          data: categories,
        );
      } else {
        return ApiResponse<List<EmergencyContactCategory>>(
          success: false,
          message: _get(responseData, 'Message') ?? 'Failed to fetch categories',
        );
      }
    } catch (e) {
      return ApiResponse<List<EmergencyContactCategory>>(
        success: false,
        message: 'Network error: $e',
      );
    }
  }

  // GET: Kontak darurat SEMUA karyawan — khusus Head HRD.
  Future<ApiResponse<List<EmployeeEmergencyContactGroup>>> getAllContactsForHrd(
    String hrdUserId,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseURL/api/asn/emergency-contact/admin-list'),
        headers: await getHeaders(),
        body: jsonEncode({'hrdUserId': hrdUserId}),
      );

      final Map<String, dynamic> responseData = jsonDecode(response.body);

      if (response.statusCode == 200 && _get(responseData, 'Success') == true) {
        final rawList = _get(responseData, 'Data') as List? ?? [];
        final groups = rawList
            .map(
              (e) => EmployeeEmergencyContactGroup.fromJson(
                e as Map<String, dynamic>,
              ),
            )
            .toList();

        return ApiResponse<List<EmployeeEmergencyContactGroup>>(
          success: true,
          message: (_get(responseData, 'Message') ?? '') as String,
          data: groups,
        );
      }

      return ApiResponse<List<EmployeeEmergencyContactGroup>>(
        success: false,
        message:
            (_get(responseData, 'Message') ?? 'Gagal mengambil data') as String,
      );
    } catch (e) {
      return ApiResponse<List<EmployeeEmergencyContactGroup>>(
        success: false,
        message: 'Network error: $e',
      );
    }
  }
}
