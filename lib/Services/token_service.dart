import 'dart:convert';

import 'package:absensikaryawan/Services/config.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class TokenUnavailableException implements Exception {
  final String message;

  TokenUnavailableException(this.message);

  @override
  String toString() => message;
}

class TokenService {
  static String? _sessionToken;
  static DateTime? _sessionExpiry;
  static String? _refreshToken;
  static bool _sessionLoaded = false;
  static Future<String?>? _refreshInFlight;

  static bool get _isSessionStillValid =>
      _sessionToken != null &&
      _sessionExpiry != null &&
      DateTime.now().isBefore(_sessionExpiry!.subtract(const Duration(minutes: 2)));

  static Future<void> _loadSessionToken() async {
    if (_sessionLoaded) return;
    _sessionLoaded = true;
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('SessionAccessToken');
    final expiryMs = prefs.getInt('SessionAccessTokenExpiry');
    _refreshToken = prefs.getString('SessionRefreshToken');
    if (token != null && expiryMs != null) {
      final expiry = DateTime.fromMillisecondsSinceEpoch(expiryMs);
      _sessionToken = token;
      _sessionExpiry = expiry;
    }
  }

  static Future<void> setSessionToken(
    String token,
    int expiresInSeconds, {
    String? refreshToken,
  }) async {
    final expiry = DateTime.now().add(Duration(seconds: expiresInSeconds));
    _sessionToken = token;
    _sessionExpiry = expiry;
    if (refreshToken != null && refreshToken.isNotEmpty) {
      _refreshToken = refreshToken;
    }
    _sessionLoaded = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('SessionAccessToken', token);
    await prefs.setInt('SessionAccessTokenExpiry', expiry.millisecondsSinceEpoch);
    if (_refreshToken != null && _refreshToken!.isNotEmpty) {
      await prefs.setString('SessionRefreshToken', _refreshToken!);
    }
  }

  /// Token untuk seluruh request yang membutuhkan user login.
  /// Tidak boleh fallback ke token aplikasi bersama, karena token tersebut
  /// tidak membawa identitas user dan dapat membuka data perusahaan lain.
  static Future<String?> getToken({bool forceRefresh = false}) async {
    await _loadSessionToken();
    if (!forceRefresh && _isSessionStillValid) return _sessionToken;
    return _refreshSession();
  }

  static Future<String?> _refreshSession() {
    final active = _refreshInFlight;
    if (active != null) return active;
    final task = _performRefresh();
    _refreshInFlight = task;
    return task.whenComplete(() => _refreshInFlight = null);
  }

  static Future<String?> _performRefresh() async {
    final refreshToken = _refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) return null;
    try {
      final response = await http
          .post(
            Uri.parse('$baseURL/api/asn/session/refresh'),
            headers: const {'Content-Type': 'application/json', 'Accept': 'application/json'},
            body: jsonEncode({'RefreshToken': refreshToken}),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) return null;
      final token = data['accessToken']?.toString();
      final nextRefresh = data['refreshToken']?.toString();
      final expiresIn = data['expiresIn'];
      if (token == null || token.isEmpty || nextRefresh == null || nextRefresh.isEmpty) {
        return null;
      }
      await setSessionToken(
        token,
        expiresIn is int ? expiresIn : int.tryParse('$expiresIn') ?? 28800,
        refreshToken: nextRefresh,
      );
      return token;
    } catch (_) {
      // Kegagalan jaringan bukan logout. Sesi dicoba lagi saat request berikutnya.
      return null;
    }
  }

  static Future<String> _requireToken() async {
    final token = await getToken();

    if (token == null || token.isEmpty) {
      throw TokenUnavailableException(
        'Tidak dapat mengambil token autentikasi.',
      );
    }

    return token;
  }

  static Map<String, String> _jsonHeaders(String token) {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// Pesan aman untuk ditampilkan di UI. Detail exception server tidak pernah
  /// diteruskan mentah ke pengguna.
  static String responseMessage(
    http.Response response, {
    required String fallback,
  }) {
    if (response.statusCode == 401) {
      return 'Sesi tidak dapat diverifikasi. Periksa koneksi lalu coba lagi.';
    }
    if (response.statusCode == 403) {
      return 'Anda tidak memiliki akses ke data ini.';
    }
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final message = decoded['message']?.toString().trim();
        if (message != null && message.isNotEmpty) return message;
      }
    } catch (_) {}
    return fallback;
  }

  static Future<String?> _refreshAfter401(String failedToken) async {
    if (failedToken != _sessionToken) return _sessionToken;
    return _refreshSession();
  }

  /// Semua POST JSON wajib lewat method ini.
  static Future<http.Response> authorizedPost(
    Uri url, {
    Object? body,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final oldToken = await _requireToken();

    var res = await http
        .post(url, headers: _jsonHeaders(oldToken), body: body)
        .timeout(timeout);

    // Token tidak valid/expired → ambil token baru → retry satu kali.
    if (res.statusCode != 401) {
      return res;
    }

    final newToken = await _refreshAfter401(oldToken);

    // Kalau token baru gagal didapat, return 401 awal.
    if (newToken == null || newToken.isEmpty) {
      return res;
    }

    res = await http
        .post(url, headers: _jsonHeaders(newToken), body: body)
        .timeout(timeout);

    return res;
  }

  /// Untuk endpoint GET bila nanti diperlukan.
  static Future<http.Response> authorizedGet(
    Uri url, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final oldToken = await _requireToken();

    var res = await http
        .get(url, headers: _jsonHeaders(oldToken))
        .timeout(timeout);

    if (res.statusCode != 401) {
      return res;
    }

    final newToken = await _refreshAfter401(oldToken);

    if (newToken == null || newToken.isEmpty) {
      return res;
    }

    return http.get(url, headers: _jsonHeaders(newToken)).timeout(timeout);
  }

  /// Untuk request multipart seperti upload gambar.
  static Future<http.Response> authorizedMultipartPost({
    required Uri url,
    required Map<String, String> fields,
    required List<http.MultipartFile> Function() buildFiles,
    Duration timeout = const Duration(seconds: 45),
  }) async {
    final oldToken = await _requireToken();

    var res = await _sendMultipart(
      url: url,
      token: oldToken,
      fields: fields,
      buildFiles: buildFiles,
      timeout: timeout,
    );

    if (res.statusCode != 401) {
      return res;
    }

    final newToken = await _refreshAfter401(oldToken);

    if (newToken == null || newToken.isEmpty) {
      return res;
    }

    return _sendMultipart(
      url: url,
      token: newToken,
      fields: fields,
      buildFiles: buildFiles,
      timeout: timeout,
    );
  }

  static Future<http.Response> _sendMultipart({
    required Uri url,
    required String token,
    required Map<String, String> fields,
    required List<http.MultipartFile> Function() buildFiles,
    required Duration timeout,
  }) async {
    final request = http.MultipartRequest('POST', url);

    request.headers.addAll({
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    });

    request.fields.addAll(fields);
    request.files.addAll(buildFiles());

    final streamedResponse = await request.send();
    return http.Response.fromStream(streamedResponse).timeout(timeout);
  }

  static Future<Map<String, String>> jsonHeaders() async {
    final token = await _requireToken();
    return _jsonHeaders(token);
  }

  static Future<Map<String, String>> multipartHeaders() async {
    final token = await _requireToken();
    return {'Authorization': 'Bearer $token', 'Accept': 'application/json'};
  }

  /// Logout eksplisit: cabut refresh token di server lalu bersihkan perangkat.
  static Future<void> logout() async {
    await _loadSessionToken();
    final refreshToken = _refreshToken;
    if (refreshToken != null && refreshToken.isNotEmpty) {
      try {
        await http
            .post(
              Uri.parse('$baseURL/api/asn/session/logout'),
              headers: const {'Content-Type': 'application/json'},
              body: jsonEncode({'RefreshToken': refreshToken}),
            )
            .timeout(const Duration(seconds: 10));
      } catch (_) {}
    }
    invalidate();
  }

  /// Bersihkan hanya pada logout eksplisit atau login baru yang tidak valid.
  static void invalidate() {
    _sessionToken = null;
    _sessionExpiry = null;
    _refreshToken = null;
    _sessionLoaded = true;
    // Hapus sesi persisten tanpa menunggu UI; sesi yang sudah ditolak server
    // tidak boleh hidup kembali setelah aplikasi dibuka ulang.
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove('SessionAccessToken');
      prefs.remove('SessionAccessTokenExpiry');
      prefs.remove('SessionRefreshToken');
    });
  }
}
