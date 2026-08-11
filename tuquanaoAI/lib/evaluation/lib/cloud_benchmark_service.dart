// evaluation/lib/cloud_benchmark_service.dart
//
// Phần 4.3 — Đo hiệu năng Cloud API (Cloudflare Worker → Llama 3.1 8B)
//
// So sánh với on-device về:
//   - Latency (end-to-end HTTP round-trip)
//   - Availability (timeout rate)
//   - Output quality (palette hợp lệ hay không)
//   - Chi phí (ước tính theo token, nếu có)
//
// Dùng cùng EvalDataset để so sánh táo với táo.

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:tuquanapai/core/app_dynamic_theme.dart';
import 'test_dataset.dart';

import 'package:tuquanapai/core/app_config.dart';

class CloudBenchmarkService {
  // Thay bằng URL worker thực của bạn
  static const String _workerUrl = AppConfig.cloudBenchmarkWorkerUrl;

  static const Duration _timeout = Duration(seconds: 30);
  static const int _totalRuns = 1; // Cloud đắt hơn → chỉ 1 run mỗi case

  Future<Map<String, dynamic>> run({
    void Function(int current, int total)? onProgress,
  }) async {
    final allResults = <Map<String, dynamic>>[];
    int processed = 0;
    final total = EvalDataset.cases.length * _totalRuns;

    for (final evalCase in EvalDataset.cases) {
      for (int run = 0; run < _totalRuns; run++) {
        onProgress?.call(++processed, total);

        final result = await _runSingleCase(evalCase, run);
        allResults.add(result);

        debugPrint(
          '[CloudBenchmark] ${evalCase.id} → '
              '${result['palette']} | ${result['latency_ms']}ms | '
              '${result['is_correct'] ? "✅" : "❌"}',
        );

        // Rate limit: không spam worker
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }

    return _computeStats(allResults);
  }

  Future<Map<String, dynamic>> _runSingleCase(
      EvalCase evalCase,
      int run,
      ) async {
    final requestStart = DateTime.now();
    bool timedOut = false;
    bool httpError = false;
    String palette = 'unknown';
    String rawOutput = '';
    int statusCode = 0;

    try {
      final response = await http.post(
        Uri.parse(_workerUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contextString': evalCase.context.toPromptContext(),
        }),
      ).timeout(_timeout);

      statusCode = response.statusCode;
      final latencyMs =
          DateTime.now().difference(requestStart).inMilliseconds;

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        rawOutput = body['result'] as String? ?? '';

        // Parse palette từ JSON response của worker
        if (rawOutput.isNotEmpty) {
          try {
            final start = rawOutput.indexOf('{');
            final end = rawOutput.lastIndexOf('}');
            if (start != -1 && end > start) {
              final parsed = jsonDecode(rawOutput.substring(start, end + 1))
              as Map<String, dynamic>;
              // Worker trả về AppDynamicTheme JSON → lấy name
              final theme = AppDynamicTheme.fromJson(parsed);
              palette = theme.name;
            }
          } catch (e) {
            // Thử parse trực tiếp như on-device (tên palette)
            final directPalette =
            ThemePaletteExt.fromModelOutput(rawOutput.trim());
            palette = directPalette?.name ?? 'parse_error';
          }
        }

        return {
          'case_id': evalCase.id,
          'category': evalCase.category,
          'run': run,
          'latency_ms': latencyMs,
          'palette': palette,
          'expected_palettes': evalCase.expectedPalettes,
          'is_correct': evalCase.expectedPalettes.contains(palette),
          'timed_out': false,
          'http_error': false,
          'status_code': statusCode,
          'raw_output_length': rawOutput.length,
          'timestamp': DateTime.now().toIso8601String(),
        };
      } else {
        httpError = true;
        return _errorResult(evalCase, run, latencyMs, statusCode,
            'HTTP $statusCode');
      }
    } on TimeoutException {
      timedOut = true;
      final latencyMs =
          DateTime.now().difference(requestStart).inMilliseconds;
      return _errorResult(evalCase, run, latencyMs, 0, 'TIMEOUT');
    } catch (e) {
      final latencyMs =
          DateTime.now().difference(requestStart).inMilliseconds;
      return _errorResult(evalCase, run, latencyMs, statusCode, e.toString());
    }
  }

  Map<String, dynamic> _errorResult(
      EvalCase evalCase,
      int run,
      int latencyMs,
      int statusCode,
      String error,
      ) =>
      {
        'case_id': evalCase.id,
        'category': evalCase.category,
        'run': run,
        'latency_ms': latencyMs,
        'palette': 'error',
        'expected_palettes': evalCase.expectedPalettes,
        'is_correct': false,
        'timed_out': error == 'TIMEOUT',
        'http_error': true,
        'status_code': statusCode,
        'error': error,
        'raw_output_length': 0,
        'timestamp': DateTime.now().toIso8601String(),
      };

  Map<String, dynamic> _computeStats(List<Map<String, dynamic>> results) {
    final successful =
    results.where((r) => r['http_error'] == false).toList();
    final timeouts =
    results.where((r) => r['timed_out'] == true).toList();
    final httpErrors =
    results.where((r) => r['http_error'] == true && r['timed_out'] == false).toList();

    List<double> latencies = successful
        .map((r) => (r['latency_ms'] as int).toDouble())
        .toList()
      ..sort();

    double mean(List<double> vals) => vals.isEmpty
        ? 0
        : vals.reduce((a, b) => a + b) / vals.length;

    double percentile(List<double> sorted, double p) {
      if (sorted.isEmpty) return 0;
      return sorted[(sorted.length * p).floor().clamp(0, sorted.length - 1)];
    }

    final correctCount =
        successful.where((r) => r['is_correct'] == true).length;
    final accuracy = successful.isEmpty
        ? 0.0
        : correctCount / successful.length * 100;

    // Ước tính chi phí (Cloudflare Workers AI: ~$0.01 / 1M input tokens)
    // Llama 3.1 8B: prompt ~100 tokens, output ~20 tokens
    const estimatedTokensPerRequest = 120;
    const cfPricePerMTokenUsd = 0.01;
    final totalRequests = results.length;
    final estimatedCostUsd =
        (totalRequests * estimatedTokensPerRequest / 1_000_000) *
            cfPricePerMTokenUsd;

    return {
      // Meta
      'model': 'Llama 3.1 8B Instruct FP8 (Cloudflare Workers AI)',
      'total_cases': results.length,
      'successful_count': successful.length,
      'timeout_count': timeouts.length,
      'http_error_count': httpErrors.length,
      'availability_pct': double.parse(
        (successful.length / results.length * 100).toStringAsFixed(1),
      ),

      // Latency
      'latency_mean_ms': double.parse(mean(latencies).toStringAsFixed(1)),
      'latency_p50_ms': percentile(latencies, 0.5),
      'latency_p95_ms': percentile(latencies, 0.95),
      'latency_min_ms': latencies.isEmpty ? 0 : latencies.first,
      'latency_max_ms': latencies.isEmpty ? 0 : latencies.last,

      // Accuracy
      'accuracy_pct': double.parse(accuracy.toStringAsFixed(1)),
      'correct_count': correctCount,

      // Cost estimate
      'estimated_cost_per_request_usd': double.parse(
        (estimatedCostUsd / totalRequests).toStringAsFixed(6),
      ),
      'estimated_total_cost_usd':
      double.parse(estimatedCostUsd.toStringAsFixed(4)),
      'cost_note':
      'Ước tính dựa trên Cloudflare Workers AI pricing (~\$0.01/1M tokens)',

      // Privacy note (cho báo cáo)
      'privacy_note':
      'Cloud: context data gửi qua mạng. On-device: data không rời thiết bị.',

      // Raw
      'raw': results,
    };
  }
}