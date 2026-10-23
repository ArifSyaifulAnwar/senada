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
  static bool _sessionLoaded = false;

  static bool get _isSessionStillValid =>
      _sessionToken != null &&
      _sessionExpiry != null &&
      DateTime.now().isBefore(_sessionExpiry!);

  static Future<void> _loadSessionToken() async {
    if (_sessionLoaded) return;
    _sessionLoaded = true;
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('SessionAccessToken');
    final expiryMs = prefs.getInt('SessionAccessTokenExpiry');
    if (token != null && expiryMs != null) {
      final expiry = DateTime.fromMillisecondsSinceEpoch(expiryMs);
      if (DateTime.now().isBefore(expiry)) {
        _sessionToken = token;
        _sessionExpiry = expiry;
      }
    }
  }

  static Future<void> setSessionToken(String token, int expiresInSeconds) async {
    final expiry = DateTime.now().add(Duration(seconds: expiresInSeconds));
    _sessionToken = token;
    _sessionExpiry = expiry;
    _sessionLoaded = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('SessionAccessToken', token);
    await prefs.setInt('SessionAccessTokenExpiry', expiry.millisecondsSinceEpoch);
  }

  /// Token untuk seluruh request yang membutuhkan user login.
  /// Tidak boleh fallback ke token aplikasi bersama, karena token tersebut
  /// tidak membawa identitas user dan dapat membuka data perusahaan lain.
  static Future<String?> getToken({bool forceRefresh = false}) async {
    await _loadSessionToken();
    if (!forceRefresh && _isSessionStillValid) return _sessionToken;
    if (forceRefresh && _isSessionStillValid) return _sessionToken;
    return null;
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

  static Future<String?> _refreshAfter401(String failedToken) async {
    invalidate();
    return null;
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

  static void invalidate() {
    _sessionToken = null;
    _sessionExpiry = null;
    _sessionLoaded = true;
    // Hapus sesi persisten tanpa menunggu UI; sesi yang sudah ditolak server
    // tidak boleh hidup kembali setelah aplikasi dibuka ulang.
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove('SessionAccessToken');
      prefs.remove('SessionAccessTokenExpiry');
    });
  }
}
