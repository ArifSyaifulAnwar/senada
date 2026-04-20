import 'dart:convert';
import 'package:absensikaryawan/models/attendance_model.dart';
import 'package:http/http.dart' as http;
import 'package:absensikaryawan/Services/config.dart';

class ApiService {
  Future<FaceVerificationResult> submitAttendance(
    AttendanceRequest request,
    bool isCheckOut,
  ) async {
    try {
      final uri = Uri.parse(
        '$baseURL/asn/attendance/${isCheckOut ? 'checkout' : 'checkin'}',
      );

      var requestHttp = http.MultipartRequest('POST', uri)
        ..fields.addAll({
          'email': request.userEmail,
          'latitude': request.latitude.toString(),
          'longitude': request.longitude.toString(),
          'officeName': request.officeName,
        });

      if (request.faceImagePath != null) {
        requestHttp.files.add(
          await http.MultipartFile.fromPath(
            'faceImage',
            request.faceImagePath!,
          ),
        );
      }

      final response = await requestHttp.send();
      final responseData = await response.stream.bytesToString();
      final jsonResponse = jsonDecode(responseData);

      if (response.statusCode == 200) {
        return FaceVerificationResult(
          isSuccess: true,
          message: jsonResponse['message'],
          faceVerified: jsonResponse['faceVerified'],
          recognizedName: jsonResponse['recognizedName'],
        );
      } else {
        return FaceVerificationResult(
          isSuccess: false,
          message: jsonResponse['message'] ?? 'Verifikasi gagal',
        );
      }
    } catch (e) {
      return FaceVerificationResult(isSuccess: false, message: 'Error: $e');
    }
  }
}
