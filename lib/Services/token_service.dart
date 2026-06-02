import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config.dart';

class TokenService {
  static String? _cachedToken;
  static DateTime? _tokenExpiry;
  static bool _isFetching = false;
  static Future<String?>? _pendingFetch;

  /// Ambil token — pakai cache kalau masih valid (< 50 menit)
  static Future<String?> getToken() async {
    // Kalau sedang fetch, tunggu yang sedang berjalan
    if (_isFetching && _pendingFetch != null) {
      return _pendingFetch;
    }

    // Kalau cache masih valid, langsung return
    if (_cachedToken != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!)) {
      return _cachedToken;
    }

    // Fetch baru
    _isFetching = true;
    _pendingFetch = _fetchToken();
    final token = await _pendingFetch;
    _isFetching = false;
    _pendingFetch = null;
    return token;
  }

  static Future<String?> _fetchToken() async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseURL/api/auth/token'),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: {'grant_type': 'password', 'password': 'ASN_DBS'},
          )
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final d = json.decode(res.body);
        if (d['access_token'] != null) {
          _cachedToken = d['access_token'] as String;
          // Cache 50 menit (asumsi token expire 1 jam)
          _tokenExpiry = DateTime.now().add(const Duration(minutes: 50));
          return _cachedToken;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Panggil ini untuk request yang butuh auto-retry saat 401
  static Future<http.Response> authorizedPost(
    Uri url, {
    required Object body,
  }) async {
    var headers = await jsonHeaders();
    var res = await http
        .post(url, headers: headers, body: body)
        .timeout(const Duration(seconds: 30));

    if (res.statusCode == 401) {
      // Token expired — invalidate dan retry sekali
      invalidate();
      headers = await jsonHeaders(); // fetch token baru
      res = await http
          .post(url, headers: headers, body: body)
          .timeout(const Duration(seconds: 30));
    }

    return res;
  }

  /// Force refresh token (panggil kalau dapat 401)
  static void invalidate() {
    _cachedToken = null;
    _tokenExpiry = null;
  }

  static Future<Map<String, String>> jsonHeaders() async {
    final tok = await getToken();
    return {'Content-Type': 'application/json', 'Authorization': 'bearer $tok'};
  }

  static Future<Map<String, String>> multipartHeaders() async {
    final tok = await getToken();
    return {'Authorization': 'bearer $tok'};
  }
}
