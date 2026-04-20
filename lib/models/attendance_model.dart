class AttendanceRequest {
  final String userEmail;
  final double latitude;
  final double longitude;
  final String officeName;
  final String? faceImagePath;

  AttendanceRequest({
    required this.userEmail,
    required this.latitude,
    required this.longitude,
    required this.officeName,
    this.faceImagePath,
  });

  Map<String, dynamic> toJson() => {
    'email': userEmail,
    'latitude': latitude,
    'longitude': longitude,
    'officeName': officeName,
    if (faceImagePath != null) 'faceImage': faceImagePath,
  };
}

class FaceVerificationResult {
  final bool isSuccess;
  final String message;
  final bool? faceVerified;
  final String? recognizedName;

  FaceVerificationResult({
    required this.isSuccess,
    required this.message,
    this.faceVerified,
    this.recognizedName,
  });
}
