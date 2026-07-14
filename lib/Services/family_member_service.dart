// services/family_member_service.dart
import 'dart:convert';
import 'package:absensikaryawan/Services/config.dart';
import 'package:absensikaryawan/Services/token_service.dart';
import 'package:http/http.dart' as http;

class FamilyMember {
  final int id;
  final String userId;
  final String name;
  final String relationship;
  final String phoneNumber;
  final DateTime? birthDate;
  final String? address;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  FamilyMember({
    required this.id,
    required this.userId,
    required this.name,
    required this.relationship,
    required this.phoneNumber,
    this.birthDate,
    this.address,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FamilyMember.fromJson(Map<String, dynamic> json) {
    dynamic get(String key) =>
        json[key] ?? json[key[0].toLowerCase() + key.substring(1)];
    final birthDateRaw = get('BirthDate');
    return FamilyMember(
      id: get('Id'),
      userId: get('UserId') ?? '',
      name: get('Name') ?? '',
      relationship: get('Relationship') ?? '',
      phoneNumber: get('PhoneNumber') ?? '',
      birthDate: birthDateRaw != null ? DateTime.tryParse(birthDateRaw) : null,
      address: get('Address'),
      isActive: get('IsActive') ?? true,
      createdAt: DateTime.tryParse(get('CreatedAt') ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(get('UpdatedAt') ?? '') ?? DateTime.now(),
    );
  }
}

// Anggota keluarga 1 karyawan — dipakai Head HRD untuk lihat semua karyawan
// sekaligus (endpoint admin-list).
class EmployeeFamilyMemberGroup {
  final String userId;
  final String employeeName;
  final String? employeeJob;
  final String? department;
  final List<FamilyMember> members;

  EmployeeFamilyMemberGroup({
    required this.userId,
    required this.employeeName,
    this.employeeJob,
    this.department,
    required this.members,
  });

  factory EmployeeFamilyMemberGroup.fromJson(Map<String, dynamic> json) {
    dynamic get(String key) =>
        json[key] ?? json[key[0].toLowerCase() + key.substring(1)];
    final rawMembers = get('Members') as List? ?? [];
    return EmployeeFamilyMemberGroup(
      userId: get('UserId') ?? '',
      employeeName: get('EmployeeName') ?? '',
      employeeJob: get('EmployeeJob'),
      department: get('Department'),
      members: rawMembers
          .map((e) => FamilyMember.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ApiResponse<T> {
  final bool success;
  final String message;
  final T? data;

  ApiResponse({required this.success, required this.message, this.data});
}

class FamilyMemberService {
  static const String _base = '/api/asn/family-member';

  Future<Map<String, String>> _getHeaders() => TokenService.jsonHeaders();

  // Response backend PascalCase (Success/Message/Data) — dual-fallback biar
  // aman kalau suatu saat ada penyesuaian casing.
  static dynamic _get(Map<String, dynamic> body, String key) {
    if (body.containsKey(key)) return body[key];
    final lower = key[0].toLowerCase() + key.substring(1);
    if (body.containsKey(lower)) return body[lower];
    return null;
  }

  Future<ApiResponse<List<FamilyMember>>> getFamilyMembers(
    String userId, {
    bool includeInactive = false,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseURL$_base/list'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'userId': userId,
          'includeInactive': includeInactive,
        }),
      );

      final Map<String, dynamic> body = jsonDecode(response.body);

      if (response.statusCode == 200 && _get(body, 'Success') == true) {
        final rawList = _get(body, 'Data') as List? ?? [];
        final members = rawList
            .map((e) => FamilyMember.fromJson(e as Map<String, dynamic>))
            .toList();
        return ApiResponse(success: true, message: '', data: members);
      }

      return ApiResponse(
        success: false,
        message: (_get(body, 'Message') ?? 'Gagal mengambil data') as String,
      );
    } catch (e) {
      return ApiResponse(success: false, message: 'Network error: $e');
    }
  }

  Future<ApiResponse<FamilyMember>> createFamilyMember({
    required String userId,
    required String name,
    required String relationship,
    required String phoneNumber,
    DateTime? birthDate,
    String? address,
    String? actorUserId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseURL$_base/create'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'userId': userId,
          'name': name,
          'relationship': relationship,
          'phoneNumber': phoneNumber,
          'birthDate': birthDate?.toIso8601String(),
          'address': address,
          'actorUserId': actorUserId,
        }),
      );

      final Map<String, dynamic> body = jsonDecode(response.body);

      if (response.statusCode == 200 && _get(body, 'Success') == true) {
        final data = _get(body, 'Data');
        return ApiResponse(
          success: true,
          message: (_get(body, 'Message') ?? '') as String,
          data: data != null ? FamilyMember.fromJson(data) : null,
        );
      }

      return ApiResponse(
        success: false,
        message: (_get(body, 'Message') ?? 'Gagal menambah data') as String,
      );
    } catch (e) {
      return ApiResponse(success: false, message: 'Network error: $e');
    }
  }

  Future<ApiResponse<FamilyMember>> updateFamilyMember({
    required int id,
    required String userId,
    required String name,
    required String relationship,
    required String phoneNumber,
    DateTime? birthDate,
    String? address,
    String? actorUserId,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseURL$_base/update'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'id': id,
          'userId': userId,
          'name': name,
          'relationship': relationship,
          'phoneNumber': phoneNumber,
          'birthDate': birthDate?.toIso8601String(),
          'address': address,
          'actorUserId': actorUserId,
        }),
      );

      final Map<String, dynamic> body = jsonDecode(response.body);

      if (response.statusCode == 200 && _get(body, 'Success') == true) {
        final data = _get(body, 'Data');
        return ApiResponse(
          success: true,
          message: (_get(body, 'Message') ?? '') as String,
          data: data != null ? FamilyMember.fromJson(data) : null,
        );
      }

      return ApiResponse(
        success: false,
        message: (_get(body, 'Message') ?? 'Gagal memperbarui data') as String,
      );
    } catch (e) {
      return ApiResponse(success: false, message: 'Network error: $e');
    }
  }

  Future<ApiResponse<void>> deleteFamilyMember(
    int id,
    String userId, {
    String? actorUserId,
  }) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseURL$_base/delete'),
        headers: await _getHeaders(),
        body: jsonEncode({'id': id, 'userId': userId, 'actorUserId': actorUserId}),
      );

      final Map<String, dynamic> body = jsonDecode(response.body);

      return ApiResponse(
        success: _get(body, 'Success') == true,
        message: (_get(body, 'Message') ?? '') as String,
      );
    } catch (e) {
      return ApiResponse(success: false, message: 'Network error: $e');
    }
  }

  // GET: Info keluarga SEMUA karyawan — khusus Head HRD.
  Future<ApiResponse<List<EmployeeFamilyMemberGroup>>> getAllFamilyMembersForHrd(
    String hrdUserId,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseURL$_base/admin-list'),
        headers: await _getHeaders(),
        body: jsonEncode({'hrdUserId': hrdUserId}),
      );

      final Map<String, dynamic> body = jsonDecode(response.body);

      if (response.statusCode == 200 && _get(body, 'Success') == true) {
        final rawList = _get(body, 'Data') as List? ?? [];
        final groups = rawList
            .map(
              (e) => EmployeeFamilyMemberGroup.fromJson(
                e as Map<String, dynamic>,
              ),
            )
            .toList();
        return ApiResponse(success: true, message: '', data: groups);
      }

      return ApiResponse(
        success: false,
        message: (_get(body, 'Message') ?? 'Gagal mengambil data') as String,
      );
    } catch (e) {
      return ApiResponse(success: false, message: 'Network error: $e');
    }
  }
}
