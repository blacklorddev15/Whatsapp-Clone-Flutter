import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Raised for any non-success response, carrying the server's own wording so screens can show it
/// verbatim rather than inventing their own copy.
class ApiException implements Exception {
  ApiException(this.message, [this.statusCode]);

  final String message;
  final int statusCode;

  @override
  String toString() => message;
}

/// Client for the Varnox API (https://varnox-api.vercel.app/api).
///
/// The flow is the React client's flow on the same endpoints:
///
///   POST /auth/register      emails a 6-digit code through Resend
///   POST /auth/verify-email  -> { token, user }
///   POST /auth/login/email   -> { token, user }
///   GET  /auth/check-auth    -> { user }   (requires the token)
///
/// The API also sets an httpOnly cookie, which is what the browser app uses. This client keeps the
/// JWT from the response body and sends it as `Authorization: Bearer <token>` instead. The reason
/// is that the app and the API live on different *.vercel.app hosts, which makes that cookie
/// third-party — dropped by Safari and by Chrome with third-party cookies blocked. authMiddleware
/// accepts either, and the socket layer already reads handshake.auth.token.
class Api {
  Api._();

  static const String baseUrl = "https://varnox-api.vercel.app/api";
  static const String _tokenKey = "varnox_auth_token";

  static String _token;

  static String get token => _token;

  static bool get hasToken => _token != null && _token.isNotEmpty;

  static Map<String, String> _headers() {
    final headers = <String, String>{"Content-Type": "application/json"};
    if (hasToken) headers["Authorization"] = "Bearer $_token";
    return headers;
  }

  /// Restores a previously stored token. Safe to call before the first request.
  static Future<void> loadToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString(_tokenKey);
    } catch (_) {
      // Storage unavailable (or blocked): the session simply will not survive a reload.
      _token = null;
    }
  }

  static Future<void> _storeToken(String token) async {
    _token = token;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
    } catch (_) {}
  }

  static Future<void> _clearToken() async {
    _token = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
    } catch (_) {}
  }

  static dynamic _unwrap(http.Response response) {
    dynamic body;
    if (response.body.isNotEmpty) {
      try {
        body = jsonDecode(response.body);
      } catch (_) {
        body = null;
      }
    }
    final status = response.statusCode;
    if (status >= 200 && status < 300) {
      if (body is Map && body["data"] != null) return body["data"];
      return body;
    }
    final message = (body is Map && body["message"] is String)
        ? body["message"]
        : "Request failed (HTTP $status)";
    throw ApiException(message, status);
  }

  static Future<dynamic> _post(String path, Map payload) async {
    final response = await http.post(
      Uri.parse("$baseUrl$path"),
      headers: _headers(),
      body: jsonEncode(payload),
    );
    return _unwrap(response);
  }

  static Future<dynamic> _get(String path, [Map<String, String> query]) async {
    var uri = Uri.parse("$baseUrl$path");
    if (query != null) uri = uri.replace(queryParameters: query);
    final response = await http.get(uri, headers: _headers());
    return _unwrap(response);
  }

  /// Creates the account, or refreshes the code for one that is not verified yet, and emails a
  /// fresh 6-digit code either way. That is what makes "Resend code" the same call — the API
  /// regenerates the code, resets the 5-minute expiry and sends it again.
  static Future<Map> startEmailVerification(String email, String password) async {
    final data = await _post("/auth/register", {"email": email, "password": password});
    return data is Map ? data : <String, dynamic>{};
  }

  static Future<Map> verifyEmail(String email, String otp) async {
    final data = await _post("/auth/verify-email", {"email": email, "otp": otp});
    final map = data is Map ? data : <String, dynamic>{};
    if (map["token"] is String) await _storeToken(map["token"]);
    return map;
  }

  static Future<Map> login(String email, String password) async {
    final data = await _post("/auth/login/email", {"email": email, "password": password});
    final map = data is Map ? data : <String, dynamic>{};
    if (map["token"] is String) await _storeToken(map["token"]);
    return map;
  }

  /// Returns the signed-in user's document, or throws ApiException(401) when the stored token is
  /// no longer valid. Used on launch to choose between the auth screen and the chat list.
  static Future<Map> checkAuth() async {
    final data = await _get("/auth/check-auth");
    return data is Map ? data : <String, dynamic>{};
  }

  static Future<void> logout() async {
    try {
      await _post("/auth/logout", <String, dynamic>{});
    } catch (_) {
      // Signing out locally matters more than the server round trip succeeding.
    }
    await _clearToken();
  }

  static Future<List> conversations() async {
    final data = await _get("/conversations");
    if (data is Map && data["conversations"] is List) return data["conversations"];
    if (data is List) return data;
    return <dynamic>[];
  }

  static Future<List> messages(String conversationId) async {
    final data = await _get("/messages", {"conversationId": conversationId});
    if (data is Map && data["messages"] is List) return data["messages"];
    if (data is List) return data;
    return <dynamic>[];
  }

  static Future<Map> sendMessage(String conversationId, String text) async {
    final data = await _post("/messages", {"conversationId": conversationId, "text": text});
    return data is Map ? data : <String, dynamic>{};
  }
}
