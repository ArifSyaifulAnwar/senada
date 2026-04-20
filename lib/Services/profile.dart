import 'dart:convert';
import 'dart:typed_data';

class ProfileDisplay {
  final int id;
  final String userId;
  final String displayName;
  final String role;
  final String email;
  final String phoneNumber;
  final String? additionalPhone;
  final String? address;
  final String? citizenIdAddress;
  final String? residentialAddress;
  final String? postalCode;
  final String? jobs;
  final String? gender;
  final String? placeOfBirth;
  final String? birthDate;
  final String? maritalStatus;
  final String? bloodType;
  final String? religion;
  final String? nik;
  final String? npwp;
  final String? nip;
  final String? passportNumber;
  final String? passportExpiry;
  final Uint8List? fotoProfil;

  ProfileDisplay({
    required this.id,
    required this.userId,
    required this.displayName,
    required this.role,
    required this.email,
    required this.phoneNumber,
    this.additionalPhone,
    this.address,
    this.citizenIdAddress,
    this.residentialAddress,
    this.postalCode,
    this.jobs,
    this.gender,
    this.placeOfBirth,
    this.birthDate,
    this.maritalStatus,
    this.bloodType,
    this.religion,
    this.nik,
    this.npwp,
    this.nip,
    this.passportNumber,
    this.passportExpiry,
    this.fotoProfil,
  });

  factory ProfileDisplay.fromJson(Map<String, dynamic> json) {
    final data = json['data'] ?? json;

    Uint8List? fotoBytes;
    if (data['fotoProfil'] != null) {
      try {
        fotoBytes = base64Decode(data['fotoProfil']);
      } catch (e) {
        fotoBytes = null;
      }
    }

    return ProfileDisplay(
      id: data['id'] ?? 0,
      userId: data['userId'] ?? '-',
      displayName: data['name'] ?? '-',
      role: data['role'] ?? '-',
      email: data['email'] ?? '-',
      phoneNumber: data['phone'] ?? '-',
      additionalPhone: data['additionalPhone'],
      address: data['address'],
      citizenIdAddress: data['citizenIdAddress'],
      residentialAddress: data['residentialAddress'],
      postalCode: data['postalCode'],
      jobs: data['jobs'],
      gender: data['gender'],
      placeOfBirth: data['placeOfBirth'],
      birthDate: data['birthDate'],
      maritalStatus: data['maritalStatus'],
      bloodType: data['bloodType'],
      religion: data['religion'],
      nik: data['nik'],
      npwp: data['npwp'],
      nip: data['nip'],
      passportNumber: data['passportNumber'],
      passportExpiry: data['passportExpiry'],
      fotoProfil: fotoBytes,
    );
  }

  String safe(String? val) => (val == null || val.trim().isEmpty) ? '-' : val;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': safe(userId),
      'name': safe(displayName),
      'role': safe(role),
      'email': safe(email),
      'phone': safe(phoneNumber),
      'additionalPhone': safe(additionalPhone),
      'address': safe(address),
      'citizenIdAddress': safe(citizenIdAddress),
      'residentialAddress': safe(residentialAddress),
      'postalCode': safe(postalCode),
      'jobs': safe(jobs),
      'gender': safe(gender),
      'placeOfBirth': safe(placeOfBirth),
      'birthDate': safe(birthDate),
      'maritalStatus': safe(maritalStatus),
      'bloodType': safe(bloodType),
      'religion': safe(religion),
      'nik': safe(nik),
      'npwp': safe(npwp),
      'nip': safe(nip),
      'passportNumber': safe(passportNumber),
      'passportExpiry': safe(passportExpiry),
      'fotoProfil': fotoProfil != null ? base64Encode(fotoProfil!) : null,
    };
  }

  String get fullName => safe(displayName);

  String get contactInfo => '${safe(phoneNumber)} / ${safe(additionalPhone)}';

  String get fullAddress {
    return [
      safe(address),
      'KTP: ${safe(citizenIdAddress)}',
      'Domisili: ${safe(residentialAddress)}',
      'Kode Pos: ${safe(postalCode)}',
    ].join(', ');
  }

  String get identityInfo {
    final nikPart = 'NIK: ${safe(nik)}';

    String passportPart = 'Paspor: ${safe(passportNumber)}';
    if (passportNumber != null &&
        passportNumber!.isNotEmpty &&
        passportExpiry != null &&
        passportExpiry!.isNotEmpty) {
      passportPart += ' (exp: ${passportExpiry!})';
    } else if (passportNumber == null || passportNumber!.isEmpty) {
      passportPart = 'Paspor: -';
    }

    return '$nikPart, $passportPart';
  }

  String get personalInfo {
    List<String> parts = [];

    if ((placeOfBirth?.isNotEmpty ?? false) ||
        (birthDate?.isNotEmpty ?? false)) {
      final tempat = safe(placeOfBirth);
      final tanggal = safe(birthDate);
      parts.add('Tempat Lahir: $tempat, Tanggal Lahir: $tanggal');
    } else {
      parts.add('Tempat Lahir: -, Tanggal Lahir: -');
    }

    parts.add('Jenis Kelamin: ${safe(gender)}');
    parts.add('Status: ${safe(maritalStatus)}');
    parts.add('Golongan Darah: ${safe(bloodType)}');
    parts.add('Agama: ${safe(religion)}');

    return parts.join(', ');
  }

  ProfileDisplay copyWith({
    int? id,
    String? userId,
    String? displayName,
    String? role,
    String? email,
    String? phoneNumber,
    String? additionalPhone,
    String? address,
    String? citizenIdAddress,
    String? residentialAddress,
    String? postalCode,
    String? jobs,
    String? gender,
    String? placeOfBirth,
    String? birthDate,
    String? maritalStatus,
    String? bloodType,
    String? religion,
    String? nik,
    String? npwp,
    String? nip,
    String? passportNumber,
    String? passportExpiry,
    Uint8List? fotoProfil,
  }) {
    return ProfileDisplay(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      additionalPhone: additionalPhone ?? this.additionalPhone,
      address: address ?? this.address,
      citizenIdAddress: citizenIdAddress ?? this.citizenIdAddress,
      residentialAddress: residentialAddress ?? this.residentialAddress,
      postalCode: postalCode ?? this.postalCode,
      jobs: jobs ?? this.jobs,
      gender: gender ?? this.gender,
      placeOfBirth: placeOfBirth ?? this.placeOfBirth,
      birthDate: birthDate ?? this.birthDate,
      maritalStatus: maritalStatus ?? this.maritalStatus,
      bloodType: bloodType ?? this.bloodType,
      religion: religion ?? this.religion,
      nik: nik ?? this.nik,
      npwp: npwp ?? this.npwp,
      nip: nip ?? this.nip,
      passportNumber: passportNumber ?? this.passportNumber,
      passportExpiry: passportExpiry ?? this.passportExpiry,
      fotoProfil: fotoProfil ?? this.fotoProfil,
    );
  }

  @override
  String toString() {
    return '''
ProfileDisplay(
  id: $id,
  userId: ${safe(userId)},
  displayName: ${safe(displayName)},
  role: ${safe(role)},
  email: ${safe(email)},
  phone: ${safe(phoneNumber)},
  additionalPhone: ${safe(additionalPhone)},
  address: ${safe(address)},
  citizenIdAddress: ${safe(citizenIdAddress)},
  residentialAddress: ${safe(residentialAddress)},
  postalCode: ${safe(postalCode)},
  jobs: ${safe(jobs)},
  gender: ${safe(gender)},
  placeOfBirth: ${safe(placeOfBirth)},
  birthDate: ${safe(birthDate)},
  maritalStatus: ${safe(maritalStatus)},
  bloodType: ${safe(bloodType)},
  religion: ${safe(religion)},
  nik: ${safe(nik)},
  npwp: ${safe(npwp)},
  nip: ${safe(nip)},
  passportNumber: ${safe(passportNumber)},
  passportExpiry: ${safe(passportExpiry)}
)
''';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProfileDisplay &&
        other.id == id &&
        other.userId == userId &&
        other.displayName == displayName &&
        other.role == role &&
        other.email == email;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        userId.hashCode ^
        displayName.hashCode ^
        role.hashCode ^
        email.hashCode;
  }
}
