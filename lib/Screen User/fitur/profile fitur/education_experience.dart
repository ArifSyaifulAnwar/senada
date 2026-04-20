// lib/models/education_experience.dart

class Education {
  final String institution;
  final String degree;
  final String field;
  final String period;
  final String? grade;
  final String type;

  Education({
    required this.institution,
    required this.degree,
    required this.field,
    required this.period,
    this.grade,
    required this.type,
  });
}

class Experience {
  final String company;
  final String position;
  final String period;
  final String? description;
  final String type;

  Experience({
    required this.company,
    required this.position,
    required this.period,
    this.description,
    required this.type,
  });
}
