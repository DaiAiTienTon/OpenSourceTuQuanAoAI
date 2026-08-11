// evaluation/lib/evaluation_runner.dart
//
// Orchestrator chính cho toàn bộ phần 4.x thực nghiệm.
// Gọi từ một màn hình debug / nút ẩn trong app.
//
// Cách dùng:
//   final runner = EvaluationRunner();
//   await runner.runAll(model: ModelConfig.smollm2_360m);
//   // hoặc model import từ máy: ModelConfig.fromLocalPath(...)
//   // Xem kết quả ở runner.reportJson

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'benchmark_service.dart';       // 4.2 — trả về { 'summary': {...}, 'raw_results': [...] }
import 'package:tuquanapai/service/gemma_theme_service.dart' show ModelConfig;
import 'cloud_benchmark_service.dart'; // 4.3
import 'consistency_test.dart';        // 4.4
import 'rule_engine.dart';             // 4.5
import 'test_dataset.dart';            // Shared dataset

class EvaluationRunner extends ChangeNotifier {
  final List<String> _logs = [];
  bool _running = false;

  bool get isRunning => _running;
  List<String> get logs => List.unmodifiable(_logs);

  // Kết quả từng phần (raw output từ mỗi service)
  Map<String, dynamic>? resultOnDevice;
  Map<String, dynamic>? resultCloud;
  Map<String, dynamic>? resultConsistency;
  Map<String, dynamic>? resultRuleVsLlm;

  void _log(String msg) {
    _logs.add('[${DateTime.now().toIso8601String()}] $msg');
    debugPrint('[EvalRunner] $msg');
    notifyListeners();
  }

  // ── Helper truy cập an toàn ──────────────────────────────────────────────

  /// Lấy giá trị nested an toàn, trả về fallback nếu null hoặc sai kiểu
  T _get<T>(Map<String, dynamic>? map, List<String> path, T fallback) {
    dynamic current = map;
    for (final key in path) {
      if (current is Map<String, dynamic> && current.containsKey(key)) {
        current = current[key];
      } else {
        return fallback;
      }
    }
    if (current is T) return current;
    // Xử lý num → double / int conversion
    if (current is num) {
      if (fallback is double) return current.toDouble() as T;
      if (fallback is int)    return current.toInt() as T;
    }
    return fallback;
  }

  // ── Chạy toàn bộ pipeline ────────────────────────────────────────────────

  /// [model]: model dùng cho phần 4.2 On-device benchmark — lấy từ
  /// ModelConfig.discoverAll() (bao gồm cả model assets/models/ lẫn model
  /// tự import từ máy, vd model fine-tune riêng của bạn). Không truyền =>
  /// service tự chọn model đầu tiên tìm thấy trong thư viện hiện có.
  Future<void> runAll({
    ModelConfig? model,
    bool runOnDevice    = true,
    bool runCloud       = true,
    bool runConsistency = true,
    bool runRuleVsLlm   = true,
  }) async {
    if (_running) return;
    _running = true;
    _logs.clear();
    notifyListeners();

    try {
      _log('=== BẮT ĐẦU ĐÁNH GIÁ THỰC NGHIỆM ===');
      _log('Dataset: ${EvalDataset.cases.length} test cases');

      // ── 4.2 On-device benchmark ─────────────────────────────────────────
      if (runOnDevice) {
        final modelLabel = model?.displayName ?? '(model mặc định)';
        _log('--- 4.2 On-device benchmark (N=200, model: $modelLabel) ---');
        final svc = OnDeviceBenchmarkService();
        final raw = await svc.run(
          model: model,
          onProgress: (i, total) => _log('  On-device [$i/$total]'),
        );

        // run() trả về { 'summary': {...}, 'raw_results': [...] }
        resultOnDevice = raw;
        final s = raw['summary'] as Map<String, dynamic>? ?? {};

        final modelUsed  = _get<String>(s, ['model'], modelLabel);
        final ttftMean   = _get<double>(s, ['ttft', 'mean'], 0.0);
        final ttftP95    = _get<double>(s, ['ttft', 'p95'], 0.0);
        final tpsMean    = _get<double>(s, ['tokens_per_sec', 'mean'], 0.0);
        final infMean    = _get<double>(s, ['total_inference', 'mean'], 0.0);
        final ramMean    = _get<double>(s, ['ram_usage_mb', 'mean'], 0.0);
        final initMs     = _get<int>   (s, ['init_time_ms'], 0);
        final accuracy   = _get<double>(s, ['accuracy_pct'], 0.0);
        final correct    = _get<int>   (s, ['correct_count'], 0);
        final total      = _get<int>   (s, ['total_cases'], 0);
        final batDrop    = _get<int>   (s, ['battery_dropped_pct'], 0);
        final batRate    = _get<double>(s, ['battery_consumption_rate'], 0.0);
        final durSec     = _get<int>   (s, ['benchmark_duration_sec'], 0);

        _log('  Model          : $modelUsed');
        _log('  Init time      : ${initMs}ms');
        _log('  TTFT mean/p95  : ${ttftMean}ms / ${ttftP95}ms');
        _log('  Total inf mean : ${infMean}ms');
        _log('  Tốc độ         : ${tpsMean} tok/s');
        _log('  RAM mean       : ${ramMean} MB');
        _log('  Accuracy       : ${accuracy}% ($correct/$total)');
        _log('  Pin tiêu thụ   : ${batDrop}% (${batRate}%/h)');
        _log('  Thời gian chạy : ${durSec}s');
      }

      // ── 4.3 Cloud API benchmark ─────────────────────────────────────────
      if (runCloud) {
        _log('--- 4.3 Cloud API benchmark ---');
        final svc = CloudBenchmarkService();
        resultCloud = await svc.run(
          onProgress: (i, total) => _log('  Cloud [$i/$total]'),
        );

        // Key thực tế của cloud service — dùng safe access
        final latencyMean = _get<double>(resultCloud, ['latency_mean_ms'], -1.0);
        final timeoutCount = _get<int>  (resultCloud, ['timeout_count'],    -1);
        final cloudAccuracy = _get<double>(resultCloud, ['accuracy_pct'],   -1.0);

        if (latencyMean >= 0)  _log('  Latency mean   : ${latencyMean}ms');
        if (timeoutCount >= 0) _log('  Timeout count  : $timeoutCount');
        if (cloudAccuracy >= 0) _log('  Cloud accuracy : ${cloudAccuracy}%');

        // Fallback: log toàn bộ nếu key không khớp
        if (latencyMean < 0 && timeoutCount < 0) {
          _log('  ⚠️  Cloud result keys: ${resultCloud?.keys.join(', ')}');
          _log('  ⚠️  Kiểm tra lại key trong cloud_benchmark_service.dart');
        }
      }

      // ── 4.4 Consistency test ────────────────────────────────────────────
      if (runConsistency) {
        _log('--- 4.4 Consistency test ---');
        final svc = ConsistencyTestService();
        resultConsistency = await svc.run(
          onProgress: (i, total) => _log('  Consistency [$i/$total]'),
        );

        final consRate = _get<double>(resultConsistency, ['consistency_rate_pct'], -1.0);
        if (consRate >= 0) {
          _log('  Consistency rate: ${consRate}%');
        } else {
          _log('  ⚠️  Consistency keys: ${resultConsistency?.keys.join(', ')}');
        }
      }

      // ── 4.5 Rule-Based vs LLM ───────────────────────────────────────────
      if (runRuleVsLlm) {
        _log('--- 4.5 Rule-Based vs LLM ---');
        final svc = RuleVsLlmService();
        resultRuleVsLlm = await svc.run(
          onProgress: (i, total) => _log('  Rule vs LLM [$i/$total]'),
        );

        final agreeRate   = _get<double>(resultRuleVsLlm, ['agreement_rate_pct'], -1.0);
        final edgeCases   = _get<int>   (resultRuleVsLlm, ['edge_case_count'],    -1);
        final ruleAccuracy = _get<double>(resultRuleVsLlm, ['rule_accuracy_pct'], -1.0);
        final llmAccuracy  = _get<double>(resultRuleVsLlm, ['llm_accuracy_pct'],  -1.0);

        if (agreeRate >= 0)   _log('  Agreement rate  : ${agreeRate}%');
        if (edgeCases >= 0)   _log('  Edge cases      : $edgeCases');
        if (ruleAccuracy >= 0) _log('  Rule accuracy   : ${ruleAccuracy}%');
        if (llmAccuracy >= 0)  _log('  LLM accuracy    : ${llmAccuracy}%');

        if (agreeRate < 0 && edgeCases < 0) {
          _log('  ⚠️  RuleVsLlm keys: ${resultRuleVsLlm?.keys.join(', ')}');
          _log('  ⚠️  Kiểm tra lại key trong rule_engine.dart');
        }
      }

      _log('=== HOÀN TẤT ===');

      // Log report tóm tắt (không log raw_results để tránh spam)
      final report = _buildFinalReport();
      final reportWithoutRaw = Map<String, dynamic>.from(report);
      (reportWithoutRaw['on_device'] as Map?)?.remove('raw_results');
      _log('REPORT:\n${const JsonEncoder.withIndent('  ').convert(reportWithoutRaw)}');

    } catch (e, st) {
      _log('❌ Lỗi không xử lý được: $e');
      _log('StackTrace: $st');
    } finally {
      _running = false;
      notifyListeners();
    }
  }

  // ── Build report cuối ────────────────────────────────────────────────────

  Map<String, dynamic> _buildFinalReport() {
    final s = (resultOnDevice?['summary'] as Map<String, dynamic>?) ?? {};

    return {
      'generated_at': DateTime.now().toIso8601String(),
      'dataset_size': EvalDataset.cases.length,

      // on_device: tách summary ra ngoài cho dễ đọc
      'on_device': {
        'summary': s,
        // raw_results giữ trong resultOnDevice nếu cần
      },

      'cloud':        resultCloud,
      'consistency':  resultConsistency,
      'rule_vs_llm':  resultRuleVsLlm,
    };
  }

  /// Toàn bộ report dạng JSON string (bao gồm raw_results)
  String get reportJson =>
      const JsonEncoder.withIndent('  ').convert({
        'generated_at': DateTime.now().toIso8601String(),
        'dataset_size': EvalDataset.cases.length,
        'on_device':    resultOnDevice,
        'cloud':        resultCloud,
        'consistency':  resultConsistency,
        'rule_vs_llm':  resultRuleVsLlm,
      });

  /// Report tóm tắt không có raw_results (để hiển thị UI)
  String get summaryJson {
    final onDeviceSummaryOnly = resultOnDevice == null ? null : {
      'summary': resultOnDevice!['summary'],
    };
    return const JsonEncoder.withIndent('  ').convert({
      'generated_at': DateTime.now().toIso8601String(),
      'on_device':    onDeviceSummaryOnly,
      'cloud':        resultCloud,
      'consistency':  resultConsistency,
      'rule_vs_llm':  resultRuleVsLlm,
    });
  }
}