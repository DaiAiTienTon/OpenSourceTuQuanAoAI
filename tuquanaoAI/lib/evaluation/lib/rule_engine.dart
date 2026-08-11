// evaluation/lib/rule_engine.dart
//
// Phần 4.5 — So sánh Rule-Based vs LLM-Based
//
// RuleEngine: implement thuần túy logic từ prompt của GemmaThemeService,
// không dùng AI. Đây là "baseline" để so sánh.
//
// Phân tích:
//   - Agreement rate: % các case mà Rule và LLM cho cùng palette
//   - Edge case: các case Rule và LLM bất đồng → phân tích thủ công
//   - Latency so sánh: Rule <1ms vs LLM vài trăm ms
//   - Accuracy so sánh: trên EvalDataset

import 'package:flutter/foundation.dart';
import 'package:tuquanapai/service/gemma_theme_service.dart';
import 'test_dataset.dart';

// ── Priority Hint (CHỈ DÙNG ĐỂ ĐO ĐẠC / PHÂN TÍCH) ──────────────────────────
//
// QUAN TRỌNG: heuristic này KHÔNG được đưa vào prompt của LLM (xem
// GemmaThemeService._buildPrompt — prompt chỉ chứa context thô, không có
// bất kỳ gợi ý palette nào). Nó chỉ tồn tại ở tầng evaluation, tính toán
// SAU KHI đã có kết quả từ model, để phục vụ phân tích định lượng:
//   - hint_palette: palette mà 1 rule ưu tiên đơn giản (dựa theo giờ/thời
//     tiết/nhịp tim) sẽ chọn, dùng làm 1 "baseline ngây thơ" khác để so
//     sánh bên cạnh RuleEngine.decide() đầy đủ hơn.
//   - hint_mismatch: baseline ngây thơ đó có khớp với rule đầy đủ không —
//     giúp thấy rule đơn giản "sai" ở đâu, từ đó suy ra model có đang học
//     đúng ngữ cảnh phức tạp hay chỉ bắt được tín hiệu bề mặt.
class PromptPriorityHint {
  final String tag; // vd: "MORN_H9"
  final String palette; // vd: "mint"
  const PromptPriorityHint(this.tag, this.palette);

  String get formatted => '$tag→$palette';
}

PromptPriorityHint computePromptPriorityHint(ThemeContext ctx) {
  final hour = ctx.hourOfDay;

  if (ctx.weatherCondition?.contains('rain') == true ||
      ctx.weatherCondition?.contains('storm') == true) {
    return const PromptPriorityHint('RAIN', 'rainy_evening');
  }
  if ((ctx.tempC ?? 0) >= 34) {
    return PromptPriorityHint('HOT${ctx.tempC!.round()}C', 'warm_orange');
  }
  if (hour >= 5 && hour < 7) {
    return PromptPriorityHint('DAWN_H$hour', 'golden_morning');
  }
  if (hour >= 7 && hour < 12) {
    return PromptPriorityHint('MORN_H$hour', 'mint');
  }
  if (hour >= 12 && hour < 17) {
    return PromptPriorityHint('AFTN_H$hour', 'ocean');
  }
  if (hour >= 17 && hour < 20) {
    return PromptPriorityHint('EVNG_H$hour', 'sunset');
  }
  final hr = ctx.heartRateBpm ?? 70;
  final sleep = ctx.sleepHours ?? 0;
  if (hr < 65 && sleep >= 7) {
    return PromptPriorityHint('NIGHT_H${hour}_RELAX', 'lavender');
  }
  return PromptPriorityHint('NIGHT_H$hour', 'dark_blue');
}

// ── Rule Engine ──────────────────────────────────────────────────────────────

/// Hệ thống rule thuần túy — đối chiếu với LLM
/// Logic phản ánh prompt trong GemmaThemeService._buildPrompt()
/// + thêm các rule bổ sung từ ThemeContext
class RuleEngine {
  static String decide(ThemeContext ctx) {
    final hour = ctx.hourOfDay;
    final temp = ctx.tempC;
    final weather = ctx.weatherCondition?.toLowerCase() ?? '';
    final hr = ctx.heartRateBpm;
    final sleep = ctx.sleepHours;

    // ── Rule 1: Weather override (ưu tiên cao nhất) ──────────────────
    if (weather.contains('rain') || weather.contains('drizzle') ||
        weather.contains('storm')) {
      return 'rainy_evening';
    }

    // ── Rule 2: Nhiệt độ cực đoan ────────────────────────────────────
    if (temp != null && temp >= 34) return 'warm_orange';

    // ── Rule 3: Sức khỏe override ────────────────────────────────────
    // Thư giãn tối (hr thấp + ngủ đủ + đêm/tối)
    if (hr != null && hr < 65 && sleep != null && sleep >= 7 && hour >= 18) {
      return 'lavender';
    }

    // ── Rule 4: Time-based (rule chính) ──────────────────────────────
    if (hour >= 5 && hour < 7) return 'golden_morning';
    if (hour >= 7 && hour < 12) {
      // Sáng: mint hoặc forest
      if (temp != null && temp < 20) return 'forest';
      return 'mint';
    }
    if (hour >= 12 && hour < 17) {
      // Chiều: ocean hoặc mint
      if (hr != null && hr >= 85) return 'warm_orange';
      return 'ocean';
    }
    if (hour >= 17 && hour < 20) {
      return 'sunset';
    }
    // Đêm (20h+, 0-5h)
    if (hr != null && hr < 65 && sleep != null && sleep >= 7) return 'lavender';
    return 'dark_blue';
  }

  /// Giải thích lý do chọn (cho phân tích định tính)
  static String explain(ThemeContext ctx) {
    final hour = ctx.hourOfDay;
    final temp = ctx.tempC;
    final weather = ctx.weatherCondition?.toLowerCase() ?? '';
    final hr = ctx.heartRateBpm;
    final sleep = ctx.sleepHours;

    final reasons = <String>[];

    if (weather.contains('rain')) reasons.add('thời tiết mưa → rainy_evening');
    if (temp != null && temp >= 34) reasons.add('nhiệt độ ${temp}°C ≥34 → warm_orange');
    if (hr != null && hr < 65 && sleep != null && sleep >= 7 && hour >= 18) {
      reasons.add('hr=${hr}bpm + sleep=${sleep}h + giờ=${hour}h → lavender');
    }
    if (hour >= 5 && hour < 7) reasons.add('bình minh → golden_morning');
    else if (hour >= 7 && hour < 12) reasons.add('buổi sáng → mint/forest');
    else if (hour >= 12 && hour < 17) reasons.add('buổi chiều → ocean');
    else if (hour >= 17 && hour < 20) reasons.add('buổi tối → sunset');
    else reasons.add('đêm khuya → dark_blue/lavender');

    return reasons.join('; ');
  }
}

// ── RuleVsLlmService ─────────────────────────────────────────────────────────

class RuleVsLlmService {
  Future<Map<String, dynamic>> run({
    void Function(int current, int total)? onProgress,
  }) async {
    final gemma = GemmaThemeService.instance;
    if (!gemma.isReady) await gemma.initialize();

    final results = <Map<String, dynamic>>[];
    int processed = 0;
    final total = EvalDataset.cases.length;

    for (final evalCase in EvalDataset.cases) {
      onProgress?.call(++processed, total);

      // ── Rule decision (sync, <1ms) ──────────────────────────────────
      final ruleStart = DateTime.now();
      final rulePalette = RuleEngine.decide(evalCase.context);
      final ruleMs = DateTime.now().difference(ruleStart).inMicroseconds / 1000;
      final ruleExplanation = RuleEngine.explain(evalCase.context);

      // ── LLM decision ───────────────────────────────────────────────
      // Lưu ý: evalCase.context được truyền thẳng vào generateTheme(),
      // KHÔNG đi qua computePromptPriorityHint ở trên — hint chỉ được
      // tính riêng bên dưới để SO SÁNH SAU KHI model đã tự suy luận
      // xong, không hề chạm vào prompt gửi cho model.
      await gemma.generateTheme(evalCase.context);
      final b = gemma.lastBenchmark;
      final llmPalette = b?.paletteName ?? 'error';
      final llmMs = b?.totalInferenceMs ?? -1;

      // ── Priority hint (baseline ngây thơ, chỉ để đo đạc) ─────────────
      // So sánh với rulePalette (ground truth đầy đủ hơn) để biết baseline
      // đơn giản "nói sai" ở đâu so với nhãn đúng — không liên quan gì
      // đến việc model đã suy luận ra llmPalette bằng cách nào.
      final hint = computePromptPriorityHint(evalCase.context);
      final hintMismatch = hint.palette != rulePalette;

      final agree = rulePalette == llmPalette;
      final ruleCorrect = evalCase.expectedPalettes.contains(rulePalette);
      final llmCorrect = evalCase.expectedPalettes.contains(llmPalette);

      // Phân loại edge case
      String edgeType = 'normal';
      if (!agree && ruleCorrect && !llmCorrect) edgeType = 'rule_wins';
      if (!agree && !ruleCorrect && llmCorrect) edgeType = 'llm_wins';
      if (!agree && !ruleCorrect && !llmCorrect) edgeType = 'both_wrong';
      if (!agree && ruleCorrect && llmCorrect) edgeType = 'both_correct_differ';

      results.add({
        'case_id': evalCase.id,
        'category': evalCase.category,
        'description': evalCase.description,
        'expected_palettes': evalCase.expectedPalettes,

        // Rule
        'rule_palette': rulePalette,
        'rule_correct': ruleCorrect,
        'rule_latency_ms': ruleMs,
        'rule_explanation': ruleExplanation,

        // Priority hint (baseline ngây thơ, chỉ dùng để đo đạc offline)
        'hint_palette': hint.palette,
        'hint_mismatch': hintMismatch,

        // LLM
        'llm_palette': llmPalette,
        'llm_correct': llmCorrect,
        'llm_latency_ms': llmMs,
        'llm_output_tokens': b?.outputTokens ?? -1,

        // Comparison
        'agree': agree,
        'edge_type': edgeType,
        'is_edge_case': !agree,
      });

      debugPrint(
        '[RuleVsLLM] ${evalCase.id}: '
            'Rule=$rulePalette(${ruleCorrect ? "✅" : "❌"}) '
            'LLM=$llmPalette(${llmCorrect ? "✅" : "❌"}) '
            '${agree ? "AGREE" : "DIFFER[$edgeType]"}',
      );

      await Future.delayed(const Duration(milliseconds: 200));
    }

    return _computeStats(results);
  }

  Map<String, dynamic> _computeStats(List<Map<String, dynamic>> results) {
    final agreeCount = results.where((r) => r['agree'] == true).length;
    final edgeCases = results.where((r) => r['is_edge_case'] == true).toList();

    final ruleCorrect = results.where((r) => r['rule_correct'] == true).length;
    final llmCorrect = results.where((r) => r['llm_correct'] == true).length;

    // Phân loại edge cases
    final ruleWins = edgeCases.where((r) => r['edge_type'] == 'rule_wins').toList();
    final llmWins = edgeCases.where((r) => r['edge_type'] == 'llm_wins').toList();
    final bothWrong = edgeCases.where((r) => r['edge_type'] == 'both_wrong').toList();
    final bothCorrectDiffer = edgeCases
        .where((r) => r['edge_type'] == 'both_correct_differ')
        .toList();

    // Latency so sánh
    final ruleLats = results
        .map((r) => r['rule_latency_ms'] as double)
        .toList();
    final llmLats = results
        .where((r) => (r['llm_latency_ms'] as int) > 0)
        .map((r) => (r['llm_latency_ms'] as int).toDouble())
        .toList();

    double mean(List<double> v) =>
        v.isEmpty ? 0 : v.reduce((a, b) => a + b) / v.length;

    return {
      'total_cases': results.length,

      // Agreement
      'agreement_rate_pct': double.parse(
        (agreeCount / results.length * 100).toStringAsFixed(1),
      ),
      'agree_count': agreeCount,

      // Accuracy
      'rule_accuracy_pct': double.parse(
        (ruleCorrect / results.length * 100).toStringAsFixed(1),
      ),
      'llm_accuracy_pct': double.parse(
        (llmCorrect / results.length * 100).toStringAsFixed(1),
      ),

      // ── Breakdown theo tầng phức tạp L1-L4 (xem co "rot" o tang nao) ──
      'accuracy_by_category': _breakdownBy(results, (r) => r['category'] as String),

      // ── Breakdown theo hint_mismatch (baseline ngây thơ có "đoán sai"
      // so với rule đầy đủ không). Đây thuần túy là 1 lát cắt phân tích
      // offline — không phản ánh việc model có "đọc" hint hay không, vì
      // model chưa bao giờ nhìn thấy hint này trong prompt của nó.
      'accuracy_by_hint_mismatch': _breakdownBy(
        results,
            (r) => (r['hint_mismatch'] as bool) ? 'hint_sai' : 'hint_dung',
      ),

      // ── QUAN TRỌNG: phân bố palette model thực sự dự đoán ──
      // Neu 1 palette (vd "ocean") chiem ty le bat thuong cao so voi ty le
      // xuat hien cua no trong expected_palettes, day la dau hieu MODE
      // COLLAPSE: model hoc lech ve 1 class thay vi phan biet theo context.
      'llm_prediction_distribution': _distribution(results, 'llm_palette'),
      'expected_palette_distribution_hint': _expectedDistribution(results),

      // Edge cases
      'edge_case_count': edgeCases.length,
      'rule_wins_count': ruleWins.length,
      'llm_wins_count': llmWins.length,
      'both_wrong_count': bothWrong.length,
      'both_correct_differ_count': bothCorrectDiffer.length,

      // Latency
      'rule_latency_mean_ms': double.parse(mean(ruleLats).toStringAsFixed(3)),
      'llm_latency_mean_ms': double.parse(mean(llmLats).toStringAsFixed(1)),
      'latency_speedup_x': llmLats.isEmpty || mean(ruleLats) == 0
          ? 0
          : double.parse(
          (mean(llmLats) / mean(ruleLats)).toStringAsFixed(0)),

      // Edge case detail (cho phân tích định tính trong báo cáo)
      'edge_cases_detail': edgeCases
          .map((r) => {
        'id': r['case_id'],
        'desc': r['description'],
        'expected': r['expected_palettes'],
        'rule': r['rule_palette'],
        'llm': r['llm_palette'],
        'type': r['edge_type'],
        'rule_explain': r['rule_explanation'],
      })
          .toList(),

      'raw': results,
    };
  }

  // ── Helper: gom nhom va tinh accuracy/agreement theo 1 key bat ky ────────
  // Dung cho ca 'category' (L1-L4) va 'hint_mismatch' (hint_dung/hint_sai).
  Map<String, dynamic> _breakdownBy(
      List<Map<String, dynamic>> results,
      String Function(Map<String, dynamic>) keyOf,
      ) {
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final r in results) {
      groups.putIfAbsent(keyOf(r), () => []).add(r);
    }
    final sortedKeys = groups.keys.toList()..sort();
    final out = <String, dynamic>{};
    for (final k in sortedKeys) {
      final g = groups[k]!;
      final ruleOk = g.where((r) => r['rule_correct'] == true).length;
      final llmOk = g.where((r) => r['llm_correct'] == true).length;
      final agreeOk = g.where((r) => r['agree'] == true).length;
      out[k] = {
        'count': g.length,
        'rule_accuracy_pct': double.parse((ruleOk / g.length * 100).toStringAsFixed(1)),
        'llm_accuracy_pct': double.parse((llmOk / g.length * 100).toStringAsFixed(1)),
        'agreement_rate_pct': double.parse((agreeOk / g.length * 100).toStringAsFixed(1)),
      };
    }
    return out;
  }

  // ── Helper: dem so lan xuat hien tung gia tri cua 1 field, sap xep giam dan ──
  // Dung de phat hien "mode collapse": neu 1 gia tri chiem ty le bat thuong
  // cao bat ke context dau vao la gi, do la dau hieu model khong hoc duoc
  // phan biet theo ngu canh ma chi lap lai 1 cau tra loi quen thuoc.
  Map<String, dynamic> _distribution(List<Map<String, dynamic>> results, String field) {
    final counter = <String, int>{};
    for (final r in results) {
      final v = r[field] as String;
      counter[v] = (counter[v] ?? 0) + 1;
    }
    final sortedEntries = counter.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final out = <String, dynamic>{};
    for (final e in sortedEntries) {
      out[e.key] = {
        'count': e.value,
        'pct': double.parse((e.value / results.length * 100).toStringAsFixed(1)),
      };
    }
    return out;
  }

  // ── Phan bo ground truth (rule_palette) de lam doi chung ─────────────────
  // So sanh voi llm_prediction_distribution: neu ground truth trai deu tren
  // nhieu palette nhung LLM chi tap trung vao 1-2 palette, do la bang chung
  // ro rang cho mode collapse (khong phai do du lieu von di mat can bang).
  Map<String, dynamic> _expectedDistribution(List<Map<String, dynamic>> results) {
    return _distribution(results, 'rule_palette');
  }
}