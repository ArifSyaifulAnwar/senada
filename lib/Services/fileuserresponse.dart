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
