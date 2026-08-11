import 'package:flutter/foundation.dart';
import 'package:tuquanapai/models/ai_evaluation.dart';
import 'package:tuquanapai/models/ai_suggestion.dart';
import '../service/Ai_history_service.dart';
import '../service/Session_service.dart';

enum HistoryLoadState { idle, loading, loaded, error }

class AiHistoryViewModel extends ChangeNotifier {
  final SessionService _session;

  AiHistoryViewModel({required SessionService session}) : _session = session;

  // ── Suggestions state ──────────────────────────────────────────────────
  List<AiSuggestion> _suggestions = [];
  HistoryLoadState _suggestState = HistoryLoadState.idle;
  int _suggestPage = 1;
  bool _suggestHasMore = true;

  List<AiSuggestion> get suggestions => _suggestions;
  HistoryLoadState get suggestState => _suggestState;
  bool get suggestHasMore => _suggestHasMore;

  // ── Evaluations state ──────────────────────────────────────────────────
  List<AiEvaluation> _evaluations = [];
  HistoryLoadState _evalState = HistoryLoadState.idle;
  int _evalPage = 1;
  bool _evalHasMore = true;

  List<AiEvaluation> get evaluations => _evaluations;
  HistoryLoadState get evalState => _evalState;
  bool get evalHasMore => _evalHasMore;

  // ── Load / refresh ─────────────────────────────────────────────────────

  Future<void> loadAll({bool refresh = false}) async {
    await Future.wait([
      loadSuggestions(refresh: refresh),
      loadEvaluations(refresh: refresh),
    ]);
  }

  Future<void> loadSuggestions({bool refresh = false}) async {
    final userId = _session.userId ?? '';
    if (userId.isEmpty) return;

    if (refresh) {
      _suggestPage = 1;
      _suggestHasMore = true;
      _suggestions = [];
    }
    if (!_suggestHasMore) return;

    _suggestState = HistoryLoadState.loading;
    notifyListeners();

    try {
      final items = await AiHistoryService.fetchSuggestions(
        userId: userId,
        page: _suggestPage,
      );

      if (refresh) {
        _suggestions = items;
      } else {
        _suggestions = [..._suggestions, ...items];
      }

      if (items.length < 20) _suggestHasMore = false;
      _suggestPage++;
      _suggestState = HistoryLoadState.loaded;
    } catch (e) {
      _suggestState = HistoryLoadState.error;
      print('[AiHistoryVM] loadSuggestions exception: $e');
    }

    notifyListeners();
  }

  Future<void> loadEvaluations({bool refresh = false}) async {
    final userId = _session.userId ?? '';
    if (userId.isEmpty) return;

    if (refresh) {
      _evalPage = 1;
      _evalHasMore = true;
      _evaluations = [];
    }
    if (!_evalHasMore) return;

    _evalState = HistoryLoadState.loading;
    notifyListeners();

    try {
      final items = await AiHistoryService.fetchEvaluations(
        userId: userId,
        page: _evalPage,
      );

      if (refresh) {
        _evaluations = items;
      } else {
        _evaluations = [..._evaluations, ...items];
      }

      if (items.length < 20) _evalHasMore = false;
      _evalPage++;
      _evalState = HistoryLoadState.loaded;
    } catch (e) {
      _evalState = HistoryLoadState.error;
      print('[AiHistoryVM] loadEvaluations exception: $e');
    }

    notifyListeners();
  }

  // ── Optimistic updates từ các VM khác push vào ─────────────────────────

  /// Gọi sau khi HomeViewModel lưu thành công → đẩy lên đầu list
  void prependSuggestion(AiSuggestion s) {
    _suggestions = [s, ..._suggestions];
    notifyListeners();
  }

  /// Gọi sau khi OutfitEvalViewModel lưu thành công → đẩy lên đầu list
  void prependEvaluation(AiEvaluation e) {
    _evaluations = [e, ..._evaluations];
    notifyListeners();
  }

  // ── Feedback / rating ──────────────────────────────────────────────────

  Future<void> sendFeedback({
    required String suggestionId,
    required bool isHelpful,
    String? savedOutfitId,
  }) async {
    final ok = await AiHistoryService.sendSuggestionFeedback(
      suggestionId: suggestionId,
      isHelpful: isHelpful,
      savedOutfitId: savedOutfitId,
    );
    if (ok) {
      _suggestions = _suggestions.map((s) {
        if (s.id == suggestionId) {
          return s.copyWith(isHelpful: isHelpful, savedOutfitId: savedOutfitId);
        }
        return s;
      }).toList();
      notifyListeners();
    }
  }

  Future<void> rateEvaluation({
    required String evaluationId,
    required int rating,
  }) async {
    final ok = await AiHistoryService.rateEvaluation(
      evaluationId: evaluationId,
      rating: rating,
    );
    if (ok) {
      _evaluations = _evaluations.map((e) {
        if (e.id == evaluationId) return e.copyWith(userRating: rating);
        return e;
      }).toList();
      notifyListeners();
    }
  }
}