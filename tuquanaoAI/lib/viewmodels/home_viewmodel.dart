import 'package:flutter/foundation.dart';
import '../models/clothing_item.dart';
import '../service/Session_service.dart';
import '../service/Weather_service.dart';
import '../service/rag_service.dart';
import '../service/ai_history_service.dart';
import '../viewmodels/Ai_History_viewmodel.dart';

enum SuggestState { idle, loading, success, error }

abstract class AIRepository {
  Future<String> suggestOutfit({
    required List<ClothingItem> wardrobe,
    required String destination,
    required String health,
    required String weather,
  });

  Future<String> evaluateOutfit({
    required ClothingItem top,
    required ClothingItem bottom,
    required String destination,
    required String health,
    required String weather,
  });
}

class HomeViewModel extends ChangeNotifier {
  final SessionService _session;
  final WeatherService _weather;
  final AiHistoryViewModel _history;

  String _destination = '';
  String _health = '';
  SuggestState _state = SuggestState.idle;
  String? _suggestion;
  String? _lastSavedSuggestionId;

  HomeViewModel({
    required SessionService session,
    required WeatherService weather,
    required AiHistoryViewModel history,
  })  : _session = session,
        _weather = weather,
        _history = history;

  String get destination => _destination;
  String get health => _health;
  SuggestState get state => _state;
  String? get suggestion => _suggestion;
  String? get lastSavedSuggestionId => _lastSavedSuggestionId;

  void setDestination(String v) {
    _destination = _destination == v ? '' : v;
    notifyListeners();
  }

  void setHealth(String v) {
    _health = _health == v ? '' : v;
    notifyListeners();
  }

  Future<void> suggestOutfit(Wardrobe wardrobe) async {
    final userId = _session.userId ?? '';
    if (userId.isEmpty) return;

    _state = SuggestState.loading;
    _suggestion = null;
    _lastSavedSuggestionId = null;
    notifyListeners();

    try {
      final w = _weather.weather;
      double? temp;
      String? condition;
      if (w != null) {
        temp = w.tempC;
        condition = w.description;
      }

      final occasion = _mapOccasion(_destination);

      // Gọi RAG server
      final result = await RagService.suggestOutfit(
        userId: userId,
        temperature: temp,
        weatherCondition: condition,
        occasion: occasion,
        destination: _destination.isEmpty ? null : _destination,
        additionalNote: _health.isEmpty ? null : 'Tình trạng sức khoẻ: $_health',
      );

      if (result != null && result.isNotEmpty) {
        _suggestion = result;
        _state = SuggestState.success;

        // ── Lưu kết quả lên API ngay sau khi nhận được ─────────────────
        final weatherSnapshot = w != null
            ? '${w.description}, ${w.tempDisplay}, ${w.humidityDisplay}'
            : null;

        final saved = await AiHistoryService.saveSuggestion(
          userId: userId,
          suggestionText: result,
          destination: _destination.isEmpty ? null : _destination,
          healthTag: _health.isEmpty ? null : _health,
          weatherSnapshot: weatherSnapshot,
          source: 'rag',
        );

        if (saved != null) {
          _lastSavedSuggestionId = saved.id;
          // Đẩy lên HistoryViewModel để hiển thị ngay, không cần reload
          _history.prependSuggestion(saved);
        }
      } else {
        _state = SuggestState.error;
      }
    } catch (e) {
      print('[HomeVM] suggestOutfit lỗi: $e');
      _state = SuggestState.error;
    }

    notifyListeners();
  }

  /// Gửi feedback 👍/👎 sau khi user bấm
  Future<void> sendFeedback(bool isHelpful) async {
    if (_lastSavedSuggestionId == null) return;
    await _history.sendFeedback(
      suggestionId: _lastSavedSuggestionId!,
      isHelpful: isHelpful,
    );
  }

  String? _mapOccasion(String destination) {
    if (destination.isEmpty) return null;
    final d = destination.toLowerCase();
    if (d.contains('làm') || d.contains('công sở') || d.contains('văn phòng')) return 'work';
    if (d.contains('học') || d.contains('trường')) return 'school';
    if (d.contains('gym') || d.contains('tập') || d.contains('thể thao')) return 'sport';
    if (d.contains('nhà')) return 'home';
    return 'outing';
  }

  void reset() {
    _destination = '';
    _health = '';
    _state = SuggestState.idle;
    _suggestion = null;
    _lastSavedSuggestionId = null;
    notifyListeners();
  }
}