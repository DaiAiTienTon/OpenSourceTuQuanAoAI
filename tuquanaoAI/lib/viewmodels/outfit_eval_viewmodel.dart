import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/clothing_item.dart';
import '../service/Weather_service.dart';
import '../service/Session_service.dart';
import '../service/ai_history_service.dart';
import '../viewmodels/health_viewmodel.dart';
import '../viewmodels/Ai_History_viewmodel.dart';

import '../core/app_config.dart';

enum EvalState { idle, loading, success, error }

class OutfitEvalViewModel extends ChangeNotifier {
  static const _workerUrl = AppConfig.outfitEvalWorkerUrl;

  final WeatherService _weatherService;
  final HealthViewModel _healthViewModel;
  final AiHistoryViewModel _history;
  final SessionService _session;

  OutfitEvalViewModel({
    required WeatherService weatherService,
    required HealthViewModel healthViewModel,
    required AiHistoryViewModel history,
    required SessionService session,
  })  : _weatherService = weatherService,
        _healthViewModel = healthViewModel,
        _history = history,
        _session = session;

  ClothingItem? _selectedTop;
  ClothingItem? _selectedBottom;
  String _destination = '';
  String _health = '';
  EvalState _state = EvalState.idle;
  String? _result;
  String? _lastSavedEvaluationId;

  ClothingItem? get selectedTop    => _selectedTop;
  ClothingItem? get selectedBottom => _selectedBottom;
  String        get destination    => _destination;
  String        get health         => _health;
  EvalState     get state          => _state;
  String?       get result         => _result;
  String?       get lastSavedEvaluationId => _lastSavedEvaluationId;
  bool get isReady => _selectedTop != null && _selectedBottom != null;

  void selectTop(ClothingItem item) {
    _selectedTop = _selectedTop?.id == item.id ? null : item;
    _result = null;
    _state = EvalState.idle;
    _lastSavedEvaluationId = null;
    notifyListeners();
  }

  void selectBottom(ClothingItem item) {
    _selectedBottom = _selectedBottom?.id == item.id ? null : item;
    _result = null;
    _state = EvalState.idle;
    _lastSavedEvaluationId = null;
    notifyListeners();
  }

  void setDestination(String d) {
    _destination = _destination == d ? '' : d;
    notifyListeners();
  }

  void setHealth(String h) {
    _health = _health == h ? '' : h;
    notifyListeners();
  }

  Future<void> evaluate() async {
    if (!isReady) return;

    _state = EvalState.loading;
    _result = null;
    _lastSavedEvaluationId = null;
    notifyListeners();

    // ── Lấy thông tin thời tiết ──────────────────────────────────────────
    final weatherStr = _weatherService.isReady
        ? '${_weatherService.weather!.description}, '
        '${_weatherService.weather!.tempDisplay}, '
        '${_weatherService.weather!.humidityDisplay}'
        : '';

    final locationStr = _destination.isNotEmpty
        ? _destination
        : (_weatherService.isReady ? _weatherService.weather!.city : '');

    final h = _healthViewModel.data;
    final healthFromData = [
      if (h.heartRate.isNotEmpty)     'Nhịp tim: ${h.heartRate} bpm',
      if (h.bloodPressure.isNotEmpty) 'Huyết áp: ${h.bloodPressure}',
      if (h.weight.isNotEmpty)        'Cân nặng: ${h.weight} kg',
      if (h.sleep.isNotEmpty)         'Ngủ: ${h.sleep} giờ',
      if (h.notes.isNotEmpty)         h.notes,
    ].join(', ');
    final healthStr = _health.isNotEmpty ? _health : healthFromData;

    print('=== [OutfitEval] 🚀 Bắt đầu đánh giá');
    print('=== [OutfitEval] 👕 top: ${_selectedTop!.name}');
    print('=== [OutfitEval] 👖 bottom: ${_selectedBottom!.name}');
    print('=== [OutfitEval] 📍 destination: $locationStr');

    try {
      final res = await http.post(
        Uri.parse(_workerUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'top':         {'name': _selectedTop!.name, 'desc': _selectedTop!.desc},
          'bottom':      {'name': _selectedBottom!.name, 'desc': _selectedBottom!.desc},
          'destination': locationStr,
          'weather':     weatherStr,
          'health':      healthStr,
        }),
      );

      final json = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200) {
        final evalText = json['result'] as String? ?? 'Không có phản hồi.';
        _result = evalText;
        _state  = EvalState.success;
        print('=== [OutfitEval] ✅ Kết quả: $evalText');

        // ── Lưu evaluation lên API ngay sau khi nhận kết quả ────────────
        final userId = _session.userId ?? '';
        if (userId.isNotEmpty) {
          final saved = await AiHistoryService.saveEvaluation(
            userId: userId,
            topItemId: _selectedTop!.id,
            topItemName: _selectedTop!.name,
            bottomItemId: _selectedBottom!.id,
            bottomItemName: _selectedBottom!.name,
            evaluationText: evalText,
            destination: locationStr.isEmpty ? null : locationStr,
            healthTag: healthStr.isEmpty ? null : healthStr,
            weatherSnapshot: weatherStr.isEmpty ? null : weatherStr,
          );

          if (saved != null) {
            _lastSavedEvaluationId = saved.id;
            // Đẩy lên HistoryViewModel để hiển thị ngay
            _history.prependEvaluation(saved);
          }
        }
      } else {
        _result = json['error'] as String? ?? 'Lỗi: ${res.statusCode}';
        _state  = EvalState.error;
        print('=== [OutfitEval] ❌ Lỗi từ Worker: $_result');
      }
    } catch (e) {
      _result = 'Không thể kết nối tới AI.';
      _state  = EvalState.error;
      print('=== [OutfitEval] ❌ Exception: $e');
    }

    notifyListeners();
  }

  /// Gửi đánh giá sao sau khi user chấm
  Future<void> rateResult(int rating) async {
    if (_lastSavedEvaluationId == null) return;
    await _history.rateEvaluation(
      evaluationId: _lastSavedEvaluationId!,
      rating: rating,
    );
  }
}