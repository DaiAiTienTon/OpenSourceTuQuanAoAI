import 'dart:convert';
import 'package:http/http.dart' as http;

import '../core/app_config.dart';

/// Service gọi RAG Fashion Assistant Server
class RagService {
  static const _baseUrl = AppConfig.ragServerBaseUrl;
  static const _apiKey = AppConfig.ragApiKey;

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'X-Rag-Key': _apiKey,
  };

  /// Gợi ý outfit từ RAG server
  /// Trả về chuỗi gợi ý, hoặc null nếu lỗi
  static Future<String?> suggestOutfit({
    required String userId,
    double? temperature,
    String? weatherCondition,
    String? occasion,
    String? destination,
    String? additionalNote,
  }) async {
    try {
      final body = {
        'user_id': userId,
        if (temperature != null || weatherCondition != null)
          'weather': {
            if (temperature != null) 'temperature': temperature,
            if (weatherCondition != null) 'condition': weatherCondition,
          },
        if (occasion != null) 'occasion': occasion,
        if (destination != null) 'destination': destination,
        if (additionalNote != null) 'additional_note': additionalNote,
      };

      final res = await http
          .post(
        Uri.parse('$_baseUrl/api/suggest'),
        headers: _headers,
        body: jsonEncode(body),
      )
          .timeout(const Duration(seconds: 60));

      if (res.statusCode == 200) {
        final json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        return json['suggestion'] as String?;
      } else if (res.statusCode == 404) {
        // Chưa có index → sync trước rồi retry
        await syncUser(userId: userId, dataType: 'all');
        return await _suggestRetry(body);
      } else {
        print('[RAG] suggest lỗi ${res.statusCode}: ${res.body}');
        return null;
      }
    } catch (e) {
      print('[RAG] suggest exception: $e');
      return null;
    }
  }

  /// Retry sau khi sync
  static Future<String?> _suggestRetry(Map<String, dynamic> body) async {
    try {
      final res = await http
          .post(
        Uri.parse('$_baseUrl/api/suggest'),
        headers: _headers,
        body: jsonEncode(body),
      )
          .timeout(const Duration(seconds: 60));

      if (res.statusCode == 200) {
        final json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        return json['suggestion'] as String?;
      }
    } catch (_) {}
    return null;
  }

  /// Sync dữ liệu user lên RAG server
  static Future<bool> syncUser({
    required String userId,
    String dataType = 'all',
  }) async {
    try {
      final res = await http
          .post(
        Uri.parse('$_baseUrl/api/sync'),
        headers: _headers,
        body: jsonEncode({
          'user_id': userId,
          'data_type': dataType,
        }),
      )
          .timeout(const Duration(seconds: 30));

      return res.statusCode == 200;
    } catch (e) {
      print('[RAG] sync exception: $e');
      return false;
    }
  }

  /// Health check
  static Future<bool> isReady() async {
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/health'))
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}