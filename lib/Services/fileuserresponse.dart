class FileUserResponse {
  final int id;
  final String userId;
  final String name;
  final String mail;
  final String fileCategory;
  final String description;
  final String fileType;
  final DateTime uploadedAt;

  FileUserResponse({
    required this.id,
    required this.userId,
    required this.name,
    required this.mail,
    required this.fileCategory,
    required this.description,
    required this.fileType,
    required this.uploadedAt,
  });

  factory FileUserResponse.fromJson(Map<String, dynamic> json) {
    return FileUserResponse(
      id: json['Id'] ?? 0, // pastikan 'id' dari JSON
      userId: json['UserId'] ?? '',
      name: json['Name'] ?? '',
      mail: json['Mail'] ?? '',
      fileCategory: json['FileCategory'] ?? '',
      description: json['Description'] ?? '',
      fileType: json['FileType'] ?? '',
      uploadedAt: DateTime.parse(json['UploadedAt']),
    );
  }
}

class FileUserAdminResponse {
  final int id;
  final String userId;
  final String employeeName;
  final String jobPosition;
  final String organization;
  final String name;
  final String fileCategory;
  final String description;
  final String fileType;
  final DateTime uploadedAt;

  FileUserAdminResponse({
    required this.id,
    required this.userId,
    required this.employeeName,
    required this.jobPosition,
    required this.organization,
    required this.name,
    required this.fileCategory,
    required this.description,
    required this.fileType,
    required this.uploadedAt,
  });

  factory FileUserAdminResponse.fromJson(Map<String, dynamic> json) {
    return FileUserAdminResponse(
      id: json['Id'] ?? 0,
      userId: json['UserId']?.toString() ?? '',
      employeeName: json['EmployeeName'] ?? '-',
      jobPosition: json['JobPosition'] ?? '-',
      organization: json['Organization'] ?? '-',
      name: json['Name'] ?? '',
      fileCategory: json['FileCategory'] ?? '',
      description: json['Description'] ?? '',
      fileType: json['FileType'] ?? '',
      uploadedAt:
          DateTime.tryParse(json['UploadedAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}
