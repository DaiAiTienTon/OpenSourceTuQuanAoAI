import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  static const _base =
      'https://quanlytudoapi20260505151646-gmd8hgcag6hkdkfr.japaneast-01.azurewebsites.net/api';

  // ── Token storage ────────────────────────────────────────────────────
  static Future<String?> getToken() async =>
      (await SharedPreferences.getInstance()).getString('jwt');

  static Future<void> saveToken(String t) async =>
      (await SharedPreferences.getInstance()).setString('jwt', t);

  static Future<void> clearToken() async =>
      (await SharedPreferences.getInstance()).remove('jwt');

  // ── Headers ──────────────────────────────────────────────────────────
  static Future<Map<String, String>> _headers({bool auth = true}) async {
    final h = <String, String>{'Content-Type': 'application/json'};
    if (auth) {
      final token = await getToken();
      if (token != null) h['Authorization'] = 'Bearer $token';
    }
    return h;
  }

  // ── HTTP Methods ─────────────────────────────────────────────────────
  static Future<http.Response> get(String path) async =>
      http.get(Uri.parse('$_base$path'), headers: await _headers());

  static Future<http.Response> post(
      String path,
      Map<String, dynamic> body, {
        bool auth = true,
      }) async =>
      http.post(
        Uri.parse('$_base$path'),
        headers: await _headers(auth: auth),
        body: jsonEncode(body),
      );

  static Future<http.Response> put(
      String path,
      Map<String, dynamic> body,
      ) async =>
      http.put(
        Uri.parse('$_base$path'),
        headers: await _headers(),
        body: jsonEncode(body),
      );

  static Future<http.Response> patch(
      String path,
      Map<String, dynamic> body,
      ) async =>
      http.patch(
        Uri.parse('$_base$path'),
        headers: await _headers(),
        body: jsonEncode(body),
      );

  static Future<http.Response> delete(String path) async =>
      http.delete(Uri.parse('$_base$path'), headers: await _headers());

  // ── Helper: parse & throw nếu lỗi ───────────────────────────────────
  static Map<String, dynamic> parseJson(http.Response res) {
    if (res.statusCode >= 400) {
      throw ApiException(res.statusCode, res.body);
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static List<dynamic> parseJsonList(http.Response res) {
    if (res.statusCode >= 400) {
      throw ApiException(res.statusCode, res.body);
    }
    return jsonDecode(res.body) as List<dynamic>;
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;
  const ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';
}