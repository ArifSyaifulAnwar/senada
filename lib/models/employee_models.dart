// models/employee_models.dart — FULL REPLACE
import 'package:absensikaryawan/Screen%20User/fitur/profile%20fitur/listkaryawan.dart';

// ── ApiResponse ───────────────────────────────────────────────────────────────
class ApiResponse<T> {
  final bool success;
  final String message;
  final T? data;
  final String? errorCode;

  ApiResponse({
    required this.success,
    required this.message,
    this.data,
    this.errorCode,
  });

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic)? fromJsonT,
  ) {
    return ApiResponse<T>(
      success: json['Success'] ?? json['success'] ?? false,
      message: json['Message'] ?? json['message'] ?? '',
      data: json['Data'] != null && fromJsonT != null
          ? fromJsonT(json['Data'])
          : null,
      errorCode: json['ErrorCode'] ?? json['errorCode'],
    );
  }
}

// ── EmployeeListResponse ──────────────────────────────────────────────────────
class EmployeeListResponse {
  final List<EmployeeApiData> data;
  final int totalCount;
  final int totalPages;
  final int currentPage;
  final int pageSize;
  final EmployeeStats stats;

  EmployeeListResponse({
    required this.data,
    required this.totalCount,
    required this.totalPages,
    required this.currentPage,
    required this.pageSize,
    required this.stats,
  });

  factory EmployeeListResponse.fromJson(Map<String, dynamic> json) {
    dynamic g(String k) => json[k] ?? json[k[0].toLowerCase() + k.substring(1)];

    return EmployeeListResponse(
      data: ((g('Data') as List?) ?? [])
          .map((item) => EmployeeApiData.fromJson(item as Map<String, dynamic>))
          .toList(),
      totalCount: (g('TotalCount') as int?) ?? 0,
      totalPages: (g('TotalPages') as int?) ?? 0,
      currentPage: (g('CurrentPage') as int?) ?? 1,
      pageSize: (g('PageSize') as int?) ?? 10,
      stats: EmployeeStats.fromJson(
        (g('Stats') as Map<String, dynamic>?) ?? {},
      ),
    );
  }
}

// ── EmployeeApiData ───────────────────────────────────────────────────────────
class EmployeeApiData {
  // udt_users
  final int id;
  final String userId;
  final String name;
  final String email;
  final String? phone;
  final String? additionalPhone;
  final String? address;
  final String? citizenIdAddress;
  final String? residentialAddress;
  final String? postalCode;
  final String? gender;
  final String? jobs;
  final String? placeOfBirth;
  final DateTime? birthDate;
  final String? maritalStatus;
  final String? bloodType;
  final String? religion;
  final String? nik;
  final String? nip;
  final String? npwp;
  final String? bpjsKetenagakerjaan;
  final String? passportNumber;
  final DateTime? passportExpiry;
  final bool active;
  final DateTime? lastLogin;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? profilePhotoBase64;

  // udt_company_info_user
  final String employeeId;
  final String? barcode;
  final String? companyName;
  final String? branch;
  final String? department;
  final String? jobPosition;
  final String? employmentStatus;
  final DateTime? joinDate;
  final DateTime? endContractDate;
  final int? workingPeriodYear;
  final int? workingPeriodMonth;
  final int? workingPeriodDay;
  final String? manager;
  final String? managerUserId;

  // ── BARU: bank ──────────────────────────────────────────────────────────────
  final String? bankName;
  final String? bankAccountNumber;
  final String? bankAccountName;

  // derived
  final String statusDisplay;
  final List<String> skills;

  EmployeeApiData({
    required this.id,
    required this.userId,
    required this.name,
    required this.email,
    this.phone,
    this.additionalPhone,
    this.address,
    this.citizenIdAddress,
    this.residentialAddress,
    this.postalCode,
    this.gender,
    this.jobs,
    this.placeOfBirth,
    this.birthDate,
    this.maritalStatus,
    this.bloodType,
    this.religion,
    this.nik,
    this.nip,
    this.npwp,
    this.bpjsKetenagakerjaan,
    this.passportNumber,
    this.passportExpiry,
    required this.active,
    this.lastLogin,
    required this.createdAt,
    this.updatedAt,
    this.profilePhotoBase64,
    required this.employeeId,
    this.barcode,
    this.companyName,
    this.branch,
    this.department,
    this.jobPosition,
    this.employmentStatus,
    this.joinDate,
    this.endContractDate,
    this.workingPeriodYear,
    this.workingPeriodMonth,
    this.workingPeriodDay,
    this.manager,
    this.managerUserId,
    // ── BARU ──────────────────────────────────────────────────────────────────
    this.bankName,
    this.bankAccountNumber,
    this.bankAccountName,
    required this.statusDisplay,
    required this.skills,
  });

  factory EmployeeApiData.fromJson(Map<String, dynamic> json) {
    dynamic g(String pascal, [String? snake]) {
      return json[pascal] ??
          (snake != null ? json[snake] : null) ??
          json[pascal[0].toLowerCase() + pascal.substring(1)];
    }

    DateTime? parseDate(dynamic v) =>
        v == null ? null : DateTime.tryParse(v.toString());

    return EmployeeApiData(
      id: (g('Id', 'id') as int?) ?? 0,
      userId: g('UserId', 'userid')?.toString() ?? '',
      name: g('Name', 'name')?.toString() ?? '',
      email:
          g('Mail', 'mail')?.toString() ??
          g('Email', 'email')?.toString() ??
          '',

      phone: g('Phone', 'phone')?.toString(),
      additionalPhone: g('AdditionalPhone', 'additional_phone')?.toString(),
      address: g('Address', 'address')?.toString(),
      citizenIdAddress: g('CitizenIdAddress', 'citizen_id_address')?.toString(),
      residentialAddress: g(
        'ResidentialAddress',
        'residential_address',
      )?.toString(),
      postalCode: g('PostalCode', 'postal_code')?.toString(),
      gender: g('Gender', 'gender')?.toString(),
      jobs: g('Jobs', 'jobs')?.toString(),
      placeOfBirth: g('PlaceOfBirth', 'place_of_birth')?.toString(),
      birthDate: parseDate(g('BirthDate', 'birth_date')),
      maritalStatus: g('MaritalStatus', 'marital_status')?.toString(),
      bloodType: g('BloodType', 'blood_type')?.toString(),
      religion: g('Religion', 'religion')?.toString(),
      nik: g('Nik', 'nik')?.toString(),
      nip: g('Nip', 'nip')?.toString(),
      npwp: g('Npwp', 'npwp')?.toString(),
      bpjsKetenagakerjaan: g(
        'BpjsKetenagakerjaan',
        'bpjs_ketenagakerjaan',
      )?.toString(),
      passportNumber: g('PassportNumber', 'passport_number')?.toString(),
      passportExpiry: parseDate(g('PassportExpiry', 'passport_expiry')),
      active: (g('Active', 'active') as bool?) ?? false,
      lastLogin: parseDate(g('LastLogin', 'last_login')),
      createdAt: parseDate(g('CreatedAt', 'created_at')) ?? DateTime.now(),
      updatedAt: parseDate(g('UpdatedAt', 'updated_at')),
      profilePhotoBase64:
          g('ProfilePhoto', 'FotoProfil')?.toString() ??
          g('FotoProfil')?.toString(),

      employeeId: g('EmployeeId', 'employeeID')?.toString() ?? '',
      barcode: g('Barcode', 'barcode')?.toString(),
      companyName: g('CompanyName', 'company_name')?.toString(),
      branch: g('Branch', 'branch')?.toString(),
      department:
          g('Department', 'organization')?.toString() ??
          g('Organization', 'organization')?.toString(),
      jobPosition: g('JobPosition', 'job_position')?.toString(),
      employmentStatus: g('EmploymentStatus', 'employment_status')?.toString(),
      joinDate: parseDate(g('JoinDate', 'join_date')),
      endContractDate: parseDate(g('EndContractDate', 'end_contract_date')),
      workingPeriodYear: g('WorkingPeriodYear', 'working_period_year') as int?,
      workingPeriodMonth:
          g('WorkingPeriodMonth', 'working_period_month') as int?,
      workingPeriodDay: g('WorkingPeriodDay', 'working_period_day') as int?,
      manager: g('Manager', 'manager')?.toString(),
      managerUserId: g('ManagerUserId', 'manager_userid')?.toString(),

      // ── BARU: bank ──────────────────────────────────────────────────────────
      bankName: g('BankName', 'bank_name')?.toString(),
      bankAccountNumber: g(
        'BankAccountNumber',
        'bank_account_number',
      )?.toString(),
      bankAccountName: g('BankAccountName', 'bank_account_name')?.toString(),

      statusDisplay: g('StatusDisplay', 'status_display')?.toString() ?? '',
      skills: (g('Skills', 'skills') as List? ?? [])
          .map((e) => e.toString())
          .toList(),
    );
  }

  EmployeeData toEmployeeData() {
    return EmployeeData(
      id: id,
      userId: userId,
      nama: name,
      email: email,
      telepon: phone ?? '',
      jabatan: jobPosition ?? '',
      departemen: department ?? '',
      status: statusDisplay,
      tanggalBergabung: joinDate?.toIso8601String().split('T')[0] ?? '',
      alamat: address ?? '',
      foto: profilePhotoBase64 ?? '',
      nomorKaryawan: employeeId,
      manager: manager ?? '',
      managerUserId: managerUserId,
      skills: skills,
      // personal
      gender: gender,
      additionalPhone: additionalPhone,
      citizenIdAddress: citizenIdAddress,
      residentialAddress: residentialAddress,
      postalCode: postalCode,
      jobs: jobs,
      placeOfBirth: placeOfBirth,
      birthDate: birthDate?.toIso8601String().split('T')[0],
      maritalStatus: maritalStatus,
      bloodType: bloodType,
      religion: religion,
      nik: nik,
      nip: nip,
      npwp: npwp,
      bpjsKetenagakerjaan: bpjsKetenagakerjaan,
      passportNumber: passportNumber,
      passportExpiry: passportExpiry?.toIso8601String().split('T')[0],
      // company
      barcode: barcode,
      branch: branch,
      companyName: companyName,
      employmentStatus: employmentStatus,
      endContractDate: endContractDate?.toIso8601String().split('T')[0],
      workingPeriodYear: workingPeriodYear,
      workingPeriodMonth: workingPeriodMonth,
      workingPeriodDay: workingPeriodDay,
      // ── BARU: bank ──────────────────────────────────────────────────────────
      bankName: bankName,
      bankAccountNumber: bankAccountNumber,
      bankAccountName: bankAccountName,
    );
  }
}

// ── EmployeeStats ─────────────────────────────────────────────────────────────
class EmployeeStats {
  final int totalEmployees;
  final int activeEmployees;
  final int onLeaveEmployees;
  final int inactiveEmployees;
  final List<DepartmentStats> departmentStats;

  EmployeeStats({
    required this.totalEmployees,
    required this.activeEmployees,
    required this.onLeaveEmployees,
    required this.inactiveEmployees,
    this.departmentStats = const [],
  });

  factory EmployeeStats.fromJson(Map<String, dynamic> json) {
    dynamic g(String k) => json[k] ?? json[k[0].toLowerCase() + k.substring(1)];
    return EmployeeStats(
      totalEmployees: (g('TotalEmployees') as int?) ?? 0,
      activeEmployees: (g('ActiveEmployees') as int?) ?? 0,
      onLeaveEmployees: (g('OnLeaveEmployees') as int?) ?? 0,
      inactiveEmployees: (g('InactiveEmployees') as int?) ?? 0,
      departmentStats: ((g('DepartmentStats') as List?) ?? [])
          .map((i) => DepartmentStats.fromJson(i as Map<String, dynamic>))
          .toList(),
    );
  }
}

// ── DepartmentStats ───────────────────────────────────────────────────────────
class DepartmentStats {
  final String department;
  final int totalEmployees;
  final int activeEmployees;
  final int onLeaveEmployees;
  final int inactiveEmployees;

  DepartmentStats({
    required this.department,
    required this.totalEmployees,
    this.activeEmployees = 0,
    this.onLeaveEmployees = 0,
    this.inactiveEmployees = 0,
  });

  factory DepartmentStats.fromJson(Map<String, dynamic> json) {
    dynamic g(String k) => json[k] ?? json[k[0].toLowerCase() + k.substring(1)];
    return DepartmentStats(
      department: g('Department')?.toString() ?? '',
      totalEmployees: (g('TotalEmployees') as int?) ?? 0,
      activeEmployees: (g('ActiveEmployees') as int?) ?? 0,
      onLeaveEmployees: (g('OnLeaveEmployees') as int?) ?? 0,
      inactiveEmployees: (g('InactiveEmployees') as int?) ?? 0,
    );
  }
}

// ── Request models ────────────────────────────────────────────────────────────
class EmployeeListRequest {
  final String? searchQuery;
  final String? department;
  final String? status;
  final String? sortBy;
  final int? page;
  final int? pageSize;
  final String? userId;

  EmployeeListRequest({
    this.searchQuery,
    this.department,
    this.status,
    this.sortBy,
    this.page,
    this.pageSize,
    this.userId,
  });

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    if (searchQuery?.isNotEmpty == true) data['SearchQuery'] = searchQuery;
    if (department?.isNotEmpty == true) data['Department'] = department;
    if (status?.isNotEmpty == true) data['Status'] = status;
    if (sortBy?.isNotEmpty == true) data['SortBy'] = sortBy;
    if (page != null) data['Page'] = page;
    if (pageSize != null) data['PageSize'] = pageSize;
    if (userId?.isNotEmpty == true) data['UserId'] = userId;
    return data;
  }
}

class EmployeeDetailRequest {
  final int? id;
  final String? userId;
  final String? employeeId;

  EmployeeDetailRequest({this.id, this.userId, this.employeeId});

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    if (id != null) data['Id'] = id;
    if (userId?.isNotEmpty == true) data['UserId'] = userId;
    if (employeeId?.isNotEmpty == true) data['EmployeeId'] = employeeId;
    return data;
  }
}
