import 'package:absensikaryawan/Screen%20User/fitur/profile%20fitur/listkaryawan.dart';

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
      success: json['Success'] ?? false,
      message: json['Message'] ?? '',
      data: json['Data'] != null && fromJsonT != null
          ? fromJsonT(json['Data'])
          : null,
      errorCode: json['ErrorCode'],
    );
  }
}

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
    return EmployeeListResponse(
      data: (json['Data'] as List? ?? [])
          .map((item) => EmployeeApiData.fromJson(item))
          .toList(),
      totalCount: json['TotalCount'] ?? 0,
      totalPages: json['TotalPages'] ?? 0,
      currentPage: json['CurrentPage'] ?? 1,
      pageSize: json['PageSize'] ?? 10,
      stats: EmployeeStats.fromJson(json['Stats'] ?? {}),
    );
  }
}

class EmployeeApiData {
  final int id;
  final String userId;
  final String name;
  final String email;
  final String? phone;
  final String? address;
  final String? gender;
  final DateTime? birthDate;
  final String? nik;
  final String? nip;
  final String? npwp;
  final bool active;
  final DateTime? lastLogin;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String employeeId;
  final String? barcode;
  final String? companyName;
  final String? branch;
  final String? department;
  final String? jobPosition;
  final String? jobLevel;
  final String? employmentStatus;
  final DateTime? joinDate;
  final DateTime? endContractDate;
  final String? manager;
  final String? approvalLine;
  final String? grade;
  final String? class_;
  final String statusDisplay;
  final List<String> skills;
  final String? profilePhotoBase64;

  // Additional fields dari detail endpoint
  final String? additionalPhone;
  final String? citizenIdAddress;
  final String? residentialAddress;
  final String? postalCode;
  final String? jobs;
  final String? placeOfBirth;
  final String? maritalStatus;
  final String? bloodType;
  final String? religion;
  final String? passportNumber;
  final DateTime? passportExpiry;
  final int? workingPeriodYear;
  final int? workingPeriodMonth;
  final int? workingPeriodDay;

  EmployeeApiData({
    required this.id,
    required this.userId,
    required this.name,
    required this.email,
    this.phone,
    this.address,
    this.gender,
    this.birthDate,
    this.nik,
    this.nip,
    this.npwp,
    required this.active,
    this.lastLogin,
    required this.createdAt,
    this.updatedAt,
    required this.employeeId,
    this.barcode,
    this.companyName,
    this.branch,
    this.department,
    this.jobPosition,
    this.jobLevel,
    this.employmentStatus,
    this.joinDate,
    this.endContractDate,
    this.manager,
    this.approvalLine,
    this.grade,
    this.class_,
    required this.statusDisplay,
    required this.skills,
    this.profilePhotoBase64,
    this.additionalPhone,
    this.citizenIdAddress,
    this.residentialAddress,
    this.postalCode,
    this.jobs,
    this.placeOfBirth,
    this.maritalStatus,
    this.bloodType,
    this.religion,
    this.passportNumber,
    this.passportExpiry,
    this.workingPeriodYear,
    this.workingPeriodMonth,
    this.workingPeriodDay,
  });

  factory EmployeeApiData.fromJson(Map<String, dynamic> json) {
    return EmployeeApiData(
      id: json['Id'] ?? 0,
      userId: json['UserId'] ?? '',
      name: json['Name'] ?? '',
      email: json['Email'] ?? '',
      phone: json['Phone'],
      address: json['Address'],
      gender: json['Gender'],
      birthDate: json['BirthDate'] != null
          ? DateTime.tryParse(json['BirthDate'].toString())
          : null,
      nik: json['Nik'],
      nip: json['Nip'],
      npwp: json['Npwp'],
      active: json['Active'] ?? false,
      lastLogin: json['LastLogin'] != null
          ? DateTime.tryParse(json['LastLogin'].toString())
          : null,
      createdAt:
          DateTime.tryParse(json['CreatedAt']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt: json['UpdatedAt'] != null
          ? DateTime.tryParse(json['UpdatedAt'].toString())
          : null,
      employeeId: json['EmployeeId'] ?? '',
      barcode: json['Barcode'],
      companyName: json['CompanyName'],
      branch: json['Branch'],
      department: json['Department'],
      jobPosition: json['JobPosition'],
      jobLevel: json['JobLevel'],
      employmentStatus: json['EmploymentStatus'],
      joinDate: json['JoinDate'] != null
          ? DateTime.tryParse(json['JoinDate'].toString())
          : null,
      endContractDate: json['EndContractDate'] != null
          ? DateTime.tryParse(json['EndContractDate'].toString())
          : null,
      manager: json['Manager'],
      approvalLine: json['ApprovalLine'],
      grade: json['Grade'],
      class_: json['Class'],
      statusDisplay: json['StatusDisplay'] ?? '',
      skills: (json['Skills'] as List? ?? []).map((e) => e.toString()).toList(),
      profilePhotoBase64: json['ProfilePhoto'],
      additionalPhone: json['AdditionalPhone'],
      citizenIdAddress: json['CitizenIdAddress'],
      residentialAddress: json['ResidentialAddress'],
      postalCode: json['PostalCode'],
      jobs: json['Jobs'],
      placeOfBirth: json['PlaceOfBirth'],
      maritalStatus: json['MaritalStatus'],
      bloodType: json['BloodType'],
      religion: json['Religion'],
      passportNumber: json['PassportNumber'],
      passportExpiry: json['PassportExpiry'] != null
          ? DateTime.tryParse(json['PassportExpiry'].toString())
          : null,
      workingPeriodYear: json['WorkingPeriodYear'],
      workingPeriodMonth: json['WorkingPeriodMonth'],
      workingPeriodDay: json['WorkingPeriodDay'],
    );
  }

  // Convert to EmployeeData for UI
  EmployeeData toEmployeeData() {
    return EmployeeData(
      id: id,
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
      skills: skills,
      // Additional fields
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
      passportNumber: passportNumber,
      passportExpiry: passportExpiry?.toIso8601String().split('T')[0],
      barcode: barcode,
      branch: branch,
      companyName: companyName,
      jobLevel: jobLevel,
      employmentStatus: employmentStatus,
      endContractDate: endContractDate?.toIso8601String().split('T')[0],
      grade: grade,
      class_: class_,
      approvalLine: approvalLine,
      workingPeriodYear: workingPeriodYear,
      workingPeriodMonth: workingPeriodMonth,
      workingPeriodDay: workingPeriodDay,
    );
  }
}

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
    var deptList = (json['DepartmentStats'] as List? ?? [])
        .map((item) => DepartmentStats.fromJson(item))
        .toList();

    return EmployeeStats(
      totalEmployees: json['TotalEmployees'] ?? 0,
      activeEmployees: json['ActiveEmployees'] ?? 0,
      onLeaveEmployees: json['OnLeaveEmployees'] ?? 0,
      inactiveEmployees: json['InactiveEmployees'] ?? 0,
      departmentStats: deptList,
    );
  }
}

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
    return DepartmentStats(
      department: json['Department'] ?? '',
      totalEmployees: json['TotalEmployees'] ?? 0,
      activeEmployees: json['ActiveEmployees'] ?? 0,
      onLeaveEmployees: json['OnLeaveEmployees'] ?? 0,
      inactiveEmployees: json['InactiveEmployees'] ?? 0,
    );
  }
}

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
    final Map<String, dynamic> data = {};
    if (searchQuery != null && searchQuery!.isNotEmpty) {
      data['SearchQuery'] = searchQuery;
    }
    if (department != null && department!.isNotEmpty) {
      data['Department'] = department;
    }
    if (status != null && status!.isNotEmpty) {
      data['Status'] = status;
    }
    if (sortBy != null && sortBy!.isNotEmpty) {
      data['SortBy'] = sortBy;
    }
    if (page != null) data['Page'] = page;
    if (pageSize != null) data['PageSize'] = pageSize;
    if (userId != null && userId!.isNotEmpty) {
      data['UserId'] = userId;
    }
    return data;
  }
}

class EmployeeDetailRequest {
  final int? id;
  final String? userId;
  final String? employeeId;

  EmployeeDetailRequest({this.id, this.userId, this.employeeId});

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    if (id != null) data['Id'] = id;
    if (userId != null && userId!.isNotEmpty) data['UserId'] = userId;
    if (employeeId != null && employeeId!.isNotEmpty) {
      data['EmployeeId'] = employeeId;
    }
    return data;
  }
}
