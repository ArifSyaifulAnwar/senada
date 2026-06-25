import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'config.dart';

class TokenUnavailableException implements Exception {
  final String message;

  TokenUnavailableException(this.message);

  @override
  String toString() => message;
}

class TokenService {
  static String? _cachedToken;
  static DateTime? _tokenExpiry;

  // Supaya saat banyak request bersamaan, token hanya diambil sekali.
  static Future<String?>? _pendingFetch;

  static bool get _isTokenStillValid {
    return _cachedToken != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!);
  }

  /// Ambil token dari cache jika masih valid.
  static Future<String?> getToken({bool forceRefresh = false}) async {
    if (!forceRefresh && _isTokenStillValid) {
      return _cachedToken;
    }

    // Kalau sudah ada proses ambil token, request lain cukup menunggu.
    if (_pendingFetch != null) {
      return _pendingFetch;
    }

    _pendingFetch = _fetchToken();

    try {
      return await _pendingFetch;
    } finally {
      _pendingFetch = null;
    }
  }

  static Future<String?> _fetchToken() async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseURL/api/auth/token'),
            headers: const {
              'Content-Type': 'application/x-www-form-urlencoded',
              'Accept': 'application/json',
            },
            body: {'grant_type': 'password', 'password': 'ASN_DBS'},
          )
          .timeout(const Duration(seconds: 15));

      if (res.statusCode != 200) {
        return null;
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final token = data['access_token']?.toString();

      if (token == null || token.isEmpty) {
        return null;
      }

      // Gunakan expires_in dari API bila tersedia.
      // Fallback 1 jam bila API tidak mengirim expires_in.
      final expiresIn = int.tryParse('${data['expires_in'] ?? 3600}') ?? 3600;

      // Refresh token 60 detik sebelum benar-benar expired.
      final cacheSeconds = math.max(30, expiresIn - 60);

      _cachedToken = token;
      _tokenExpiry = DateTime.now().add(Duration(seconds: cacheSeconds));

      return _cachedToken;
    } catch (_) {
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

  static Future<String?> _refreshAfter401(String failedToken) async {
    // Jika request lain sudah lebih dulu refresh token,
    // pakai token baru tersebut tanpa request token lagi.
    if (_isTokenStillValid &&
        _cachedToken != null &&
        _cachedToken != failedToken) {
      return _cachedToken;
    }

    invalidate();

    return getToken(forceRefresh: true);
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
    _cachedToken = null;
    _tokenExpiry = null;
  }
}
