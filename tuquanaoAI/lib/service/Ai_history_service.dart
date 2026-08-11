import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:tuquanapai/models/ai_evaluation.dart';
import 'package:tuquanapai/models/ai_suggestion.dart';
import '../api/api_client.dart';

/// Service gọi API lưu và lấy lịch sử gợi ý / đánh giá từ AI
class AiHistoryService {
  // ── Suggestions ────────────────────────────────────────────────────────

  /// Lưu kết quả gợi ý vừa nhận được từ RAG server
  static Future<AiSuggestion?> saveSuggestion({
    required String userId,
    required String suggestionText,
    String? destination,
    String? healthTag,
    String? weatherSnapshot,
    String source = 'rag',
  }) async {
    try {
      final body = {
        'userId': userId,
        'suggestionText': suggestionText,
        if (destination != null && destination.isNotEmpty) 'destination': destination,
        if (healthTag != null && healthTag.isNotEmpty) 'healthTag': healthTag,
        if (weatherSnapshot != null && weatherSnapshot.isNotEmpty)
          'weatherSnapshot': weatherSnapshot,
        'source': source,
      };

      final res = await ApiClient.post('/AiSuggestions', body);
      if (res.statusCode == 201) {
        return AiSuggestion.fromJson(ApiClient.parseJson(res));
      }
      print('[AiHistoryService] saveSuggestion lỗi ${res.statusCode}: ${res.body}');
    } catch (e) {
      print('[AiHistoryService] saveSuggestion exception: $e');
    }
    return null;
  }

  /// Lấy danh sách lịch sử gợi ý của user (mới nhất trước)
  static Future<List<AiSuggestion>> fetchSuggestions({
    required String userId,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final res = await ApiClient.get(
        '/AiSuggestions/user/$userId?page=$page&pageSize=$pageSize',
      );
      if (res.statusCode == 200) {
        final list = ApiClient.parseJsonList(res);
        return list
            .map((e) => AiSuggestion.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      print('[AiHistoryService] fetchSuggestions exception: $e');
    }
    return [];
  }

  /// Gửi feedback 👍/👎 sau khi user tương tác
  static Future<bool> sendSuggestionFeedback({
    required String suggestionId,
    required bool isHelpful,
    String? savedOutfitId,
  }) async {
    try {
      final body = {
        'isHelpful': isHelpful,
        if (savedOutfitId != null) 'savedOutfitId': savedOutfitId,
      };
      final res = await ApiClient.patch(
        '/AiSuggestions/$suggestionId/feedback',
        body,
      );
      return res.statusCode == 204;
    } catch (e) {
      print('[AiHistoryService] sendSuggestionFeedback exception: $e');
      return false;
    }
  }

  // ── Evaluations ────────────────────────────────────────────────────────

  /// Lưu kết quả đánh giá vừa nhận được từ AI Worker
  static Future<AiEvaluation?> saveEvaluation({
    required String userId,
    required String topItemId,
    required String topItemName,
    required String bottomItemId,
    required String bottomItemName,
    required String evaluationText,
    String? destination,
    String? healthTag,
    String? weatherSnapshot,
  }) async {
    try {
      final body = {
        'userId': userId,
        'topItemId': topItemId,
        'topItemName': topItemName,
        'bottomItemId': bottomItemId,
        'bottomItemName': bottomItemName,
        'evaluationText': evaluationText,
        if (destination != null && destination.isNotEmpty) 'destination': destination,
        if (healthTag != null && healthTag.isNotEmpty) 'healthTag': healthTag,
        if (weatherSnapshot != null && weatherSnapshot.isNotEmpty)
          'weatherSnapshot': weatherSnapshot,
      };

      final res = await ApiClient.post('/AiEvaluations', body);
      if (res.statusCode == 201) {
        return AiEvaluation.fromJson(ApiClient.parseJson(res));
      }
      print('[AiHistoryService] saveEvaluation lỗi ${res.statusCode}: ${res.body}');
    } catch (e) {
      print('[AiHistoryService] saveEvaluation exception: $e');
    }
    return null;
  }

  /// Lấy danh sách lịch sử đánh giá của user
  static Future<List<AiEvaluation>> fetchEvaluations({
    required String userId,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final res = await ApiClient.get(
        '/AiEvaluations/user/$userId?page=$page&pageSize=$pageSize',
      );
      if (res.statusCode == 200) {
        final list = ApiClient.parseJsonList(res);
        return list
            .map((e) => AiEvaluation.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      print('[AiHistoryService] fetchEvaluations exception: $e');
    }
    return [];
  }

  /// Gửi đánh giá sao (1–5) sau khi user xem kết quả
  static Future<bool> rateEvaluation({
    required String evaluationId,
    required int rating,
  }) async {
    try {
      final res = await ApiClient.patch(
        '/AiEvaluations/$evaluationId/rate',
        {'userRating': rating},
      );
      return res.statusCode == 204;
    } catch (e) {
      print('[AiHistoryService] rateEvaluation exception: $e');
      return false;
    }
  }
}