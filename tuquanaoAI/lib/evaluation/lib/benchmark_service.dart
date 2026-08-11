// evaluation/lib/benchmark_service.dart
//
// Phần 4.2 — Đo hiệu năng on-device (llamadart)
// Tích hợp đầy đủ: RAM + Pin + Error handling + Stats + Thermal Cooldown
// Chạy ngẫu nhiên 200 lượt từ pool 40 cases (sample có hoàn lại)
//
// Model KHÔNG còn cố định — truyền vào qua tham số `model` khi gọi run(),
// vd:
//   await OnDeviceBenchmarkService().run(model: ModelConfig.smollm2_360m);
// Không truyền => dùng model đang active sẵn trong GemmaThemeService
// (hoặc ModelConfig.defaultModel nếu chưa init lần nào).

import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:math' show Random;
import 'package:battery_plus/battery_plus.dart';
import 'package:tuquanapai/service/gemma_theme_service.dart';
import 'test_dataset.dart';

class OnDeviceBenchmarkService {
  static const int totalSamples = 200;
  final Battery _battery = Battery();
  final Random _rng = Random();

  Future<Map<String, dynamic>> run({
    ModelConfig? model,
    void Function(int current, int total)? onProgress,
  }) async {
    final gemma = GemmaThemeService.instance;

    final int batteryLevelStart = await _battery.batteryLevel;
    final startTimestamp = DateTime.now();

    final initStart = DateTime.now();
    // Nếu chỉ định model khác với model đang chạy (hoặc chưa init) thì
    // switchModel/initialize với đúng model đó — không cần sửa code nữa.
    // Không truyền model => initialize() tự ModelConfig.discoverAll() và
    // chọn model đầu tiên tìm thấy trong thư viện hiện có.
    if (model != null &&
        (!gemma.isReady || gemma.currentModel?.id != model.id)) {
      await gemma.switchModel(model);
    } else if (!gemma.isReady) {
      await gemma.initialize();
    }
    final initTimeMs = DateTime.now().difference(initStart).inMilliseconds;
    final activeModel = gemma.currentModel;
    if (activeModel == null) {
      throw StateError(
          'Không có model nào sẵn sàng để benchmark — kiểm tra assets/models/ hoặc imported_models/.');
    }
    debugPrint('[Benchmark] Model: ${activeModel.id} | Init: ${initTimeMs}ms');

    final allResults = <Map<String, dynamic>>[];
    final pool = EvalDataset.cases;
    final appearedCases = <String>{};

    for (int i = 0; i < totalSamples; i++) {
      onProgress?.call(i + 1, totalSamples);

      if (i > 0 && i % 20 == 0) {
        debugPrint('[Benchmark] ❄️ Nghỉ 5s để xả nhiệt và dọn rác bộ nhớ...');
        await Future.delayed(const Duration(seconds: 5));
      }

      final evalCase = pool[_rng.nextInt(pool.length)];
      final isCold = !appearedCases.contains(evalCase.id);
      appearedCases.add(evalCase.id);

      debugPrint('[Benchmark] Sample ${i + 1}/$totalSamples → ${evalCase.id} (${isCold ? "cold" : "warm"})');

      try {
        await gemma.generateTheme(evalCase.context);
      } catch (e) {
        debugPrint('⚠️ [Benchmark] Lỗi ở case ${evalCase.id}. Bỏ qua lượt này. ($e)');
        continue;
      }

      final b = gemma.lastBenchmark;
      if (b == null) continue;

      final int ramBytes = ProcessInfo.currentRss;
      final double ramMb = double.parse((ramBytes / (1024 * 1024)).toStringAsFixed(2));

      allResults.add({
        'case_id':            evalCase.id,
        'category':           evalCase.category,
        'sample_index':       i,
        'is_cold_run':        isCold,
        'ttft_ms':            b.timeToFirstTokenMs,
        'total_inference_ms': b.totalInferenceMs,
        'tokens_per_sec':     double.parse(b.tokensPerSecond.toStringAsFixed(2)),
        'output_tokens':      b.outputTokens,
        'palette':            b.paletteName,
        'expected_palettes':  evalCase.expectedPalettes,
        'is_correct':         evalCase.expectedPalettes.contains(b.paletteName),
        'prompt_chars':       b.promptChars,
        'prompt_tokens_est':  b.promptTokensEst,
        'timestamp':          DateTime.now().toIso8601String(),
        'ram_usage_mb':       ramMb,
      });

      await Future.delayed(const Duration(milliseconds: 800));
    }

    final int batteryLevelEnd = await _battery.batteryLevel;
    final int totalBatteryDropped = batteryLevelStart - batteryLevelEnd;
    final int totalDurationSec = DateTime.now().difference(startTimestamp).inSeconds;

    final summary = _computeStats(
      allResults,
      initTimeMs,
      totalBatteryDropped,
      totalDurationSec,
      activeModel,
    );

    return {
      'summary': summary,
      'raw_results': allResults,
    };
  }

  List<double> _vals(List<Map<String, dynamic>> rows, String key) =>
      rows.map((r) => (r[key] as num).toDouble()).toList();

  _Stats _stats(List<Map<String, dynamic>> rows, String key) {
    final vals = _vals(rows, key);
    if (vals.isEmpty) return _Stats.zero();
    final mean = vals.reduce((a, b) => a + b) / vals.length;
    final variance = vals
        .map((v) => (v - mean) * (v - mean))
        .reduce((a, b) => a + b) /
        vals.length;
    final sorted = List<double>.from(vals)..sort();
    return _Stats(
      mean: _r(mean),
      std:  _r(_sqrt(variance)),
      min:  sorted.first,
      max:  sorted.last,
      p50:  sorted[_p(sorted, 0.50)],
      p95:  sorted[_p(sorted, 0.95)],
    );
  }

  int    _p(List<double> sorted, double pct) =>
      (sorted.length * pct).floor().clamp(0, sorted.length - 1);
  double _r(double v) => double.parse(v.toStringAsFixed(2));
  double _sqrt(double x) {
    if (x <= 0) return 0;
    double r = x;
    for (int i = 0; i < 20; i++) r = (r + x / r) / 2;
    return r;
  }

  Map<String, dynamic> _computeStats(
      List<Map<String, dynamic>> results,
      int initTimeMs,
      int batteryDropped,
      int durationSec,
      ModelConfig activeModel,
      ) {
    final ttftAll  = _stats(results, 'ttft_ms');
    final tpsAll   = _stats(results, 'tokens_per_sec');
    final infAll   = _stats(results, 'total_inference_ms');
    final tokAll   = _stats(results, 'output_tokens');
    final ramStats = _stats(results, 'ram_usage_mb');

    final correctCount = results.where((r) => r['is_correct'] == true).length;
    final accuracy = results.isEmpty
        ? 0.0
        : _r(correctCount / results.length * 100);

    return {
      // Trước đây field 'model' bị hard-code chuỗi "Gemma-3-270M-IT (INT4
      // QAT - llamadart)". Giờ lấy động từ ModelConfig đang chạy thực tế.
      'model': activeModel.displayName,
      'model_id': activeModel.id,
      'total_cases': results.length,
      'init_time_ms': initTimeMs,
      'ttft': {
        'mean': ttftAll.mean, 'std': ttftAll.std,
        'min': ttftAll.min,   'max': ttftAll.max,
        'p50': ttftAll.p50,   'p95': ttftAll.p95,
      },
      'total_inference': {
        'mean': infAll.mean, 'std': infAll.std,
        'min': infAll.min,   'max': infAll.max,
        'p50': infAll.p50,   'p95': infAll.p95,
      },
      'tokens_per_sec': {
        'mean': tpsAll.mean, 'std': tpsAll.std,
        'min': tpsAll.min,   'max': tpsAll.max,
        'p50': tpsAll.p50,   'p95': tpsAll.p95,
      },
      'output_tokens': {
        'mean': tokAll.mean, 'std': tokAll.std,
        'min': tokAll.min,   'max': tokAll.max,
        'p50': tokAll.p50,   'p95': tokAll.p95,
      },
      'ram_usage_mb': {
        'mean': ramStats.mean, 'std': ramStats.std,
        'min': ramStats.min,   'max': ramStats.max,
        'p50': ramStats.p50,   'p95': ramStats.p95,
      },
      'battery_dropped_pct': batteryDropped,
      'benchmark_duration_sec': durationSec,
      'battery_consumption_rate': durationSec > 0
          ? _r((batteryDropped / durationSec) * 3600)
          : 0.0,
      'accuracy_pct': accuracy,
      'correct_count': correctCount,
      'accuracy_by_category': _accuracyByCategory(results),
      'palette_prediction_distribution': _paletteDistribution(results),
    };
  }

  Map<String, dynamic> _accuracyByCategory(List<Map<String, dynamic>> results) {
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final r in results) {
      final cat = (r['category'] as String?) ?? 'unknown';
      groups.putIfAbsent(cat, () => []).add(r);
    }
    final sortedKeys = groups.keys.toList()..sort();
    final out = <String, dynamic>{};
    for (final k in sortedKeys) {
      final g = groups[k]!;
      final ok = g.where((r) => r['is_correct'] == true).length;
      out[k] = {
        'count': g.length,
        'correct_count': ok,
        'accuracy_pct': _r(ok / g.length * 100),
      };
    }
    return out;
  }

  Map<String, dynamic> _paletteDistribution(List<Map<String, dynamic>> results) {
    final counter = <String, int>{};
    for (final r in results) {
      final p = r['palette'] as String;
      counter[p] = (counter[p] ?? 0) + 1;
    }
    final sortedEntries = counter.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final out = <String, dynamic>{};
    for (final e in sortedEntries) {
      out[e.key] = {
        'count': e.value,
        'pct': _r(e.value / results.length * 100),
      };
    }
    return out;
  }
}

class _Stats {
  final double mean, std, min, max, p50, p95;
  const _Stats({
    required this.mean, required this.std,
    required this.min,  required this.max,
    required this.p50,  required this.p95,
  });
  factory _Stats.zero() =>
      const _Stats(mean: 0, std: 0, min: 0, max: 0, p50: 0, p95: 0);
}