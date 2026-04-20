class FileCategory {
  final int id;
  final String name;

  FileCategory({required this.id, required this.name});

  factory FileCategory.fromJson(Map<String, dynamic> json) {
    return FileCategory(id: json['Id'], name: json['Name']);
  }
}
