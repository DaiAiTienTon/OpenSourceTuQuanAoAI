// evaluation/lib/consistency_test.dart
//
// Phần 4.4 — Độ ổn định đầu ra (Consistency Test)
//
// Cùng 1 ThemeContext → chạy N lần → đếm xem kết quả có nhất quán không.
//
// Chọn 8 context đại diện (2 easy + 2 medium + 2 hard + 2 edge).
// Mỗi context chạy REPEAT_COUNT lần.
// Consistency rate = tỉ lệ lần chạy cho ra cùng palette với majority vote.

import 'package:flutter/foundation.dart';
import 'package:tuquanapai/service/gemma_theme_service.dart';
import 'test_dataset.dart';

class ConsistencyTestService {
  static const int repeatCount = 10; // Số lần lặp mỗi context

  // Chọn các case đại diện (id từ EvalDataset)
  static const List<String> targetCaseIds = [
    'T01', // Sáng, dễ (rõ ràng = mint/forest)
    'T07', // Đêm khuya, dễ (= dark_blue)
    'W01', // Mưa chiều, medium
    'H02', // Thư giãn tối, medium
    'C01', // Combined đầy đủ, medium
    'C04', // Trưa nóng stress, hard
    'E02', // Edge: mâu thuẫn nóng + mưa
    'E03', // Edge: sáng nhưng rất mệt
  ];

  Future<Map<String, dynamic>> run({
    void Function(int current, int total)? onProgress,
  }) async {
    final gemma = GemmaThemeService.instance;
    if (!gemma.isReady) await gemma.initialize();

    final caseResults = <Map<String, dynamic>>[];
    int processed = 0;
    final total = targetCaseIds.length * repeatCount;

    for (final caseId in targetCaseIds) {
      final evalCase = EvalDataset.byId(caseId);
      if (evalCase == null) continue;

      final palettes = <String>[];

      for (int i = 0; i < repeatCount; i++) {
        onProgress?.call(++processed, total);

        await gemma.generateTheme(evalCase.context);
        final b = gemma.lastBenchmark;
        if (b != null) palettes.add(b.paletteName);

        await Future.delayed(const Duration(milliseconds: 300));
      }

      // Majority vote
      final freq = <String, int>{};
      for (final p in palettes) freq[p] = (freq[p] ?? 0) + 1;
      final sorted = freq.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final majority = sorted.first.key;
      final consistencyRate = (sorted.first.value / palettes.length * 100);

      caseResults.add({
        'case_id': caseId,
        'category': evalCase.category,
        'description': evalCase.description,
        'repeat_count': repeatCount,
        'palettes_observed': palettes,
        'frequency': freq,
        'majority_palette': majority,
        'consistency_rate_pct':
        double.parse(consistencyRate.toStringAsFixed(1)),
        'unique_palettes': freq.keys.length,
        'is_consistent': consistencyRate >= 70.0, // Ngưỡng: ≥70% = ổn định
      });

      debugPrint(
        '[Consistency] $caseId → $majority '
            '(${consistencyRate.toStringAsFixed(0)}% / $repeatCount runs) '
            '${consistencyRate >= 70 ? "✅" : "⚠️"}',
      );
    }

    // Overall stats
    final avgRate = caseResults.isEmpty
        ? 0.0
        : caseResults
        .map((r) => r['consistency_rate_pct'] as double)
        .reduce((a, b) => a + b) /
        caseResults.length;

    final consistentCount =
        caseResults.where((r) => r['is_consistent'] == true).length;

    return {
      'repeat_count_per_case': repeatCount,
      'cases_tested': caseResults.length,
      'consistency_rate_pct': double.parse(avgRate.toStringAsFixed(1)),
      'consistent_cases': consistentCount,
      'inconsistent_cases': caseResults.length - consistentCount,
      'consistency_threshold_pct': 70,
      'note':
      'Consistent = cùng palette ≥70% số lần chạy. '
          'LLM nhỏ (270M) kỳ vọng 60-80%.',
      'cases': caseResults,
    };
  }
}