// evaluation/lib/user_study_screen.dart
//
// Phần 4.6 — Đánh giá người dùng (User Study)
//
// Giao diện cho người dùng thực đánh giá kết quả theme AI.
// Không cần ground truth — người dùng LÀ ground truth.
//
// Flow:
//   1. Hiển thị context thực của người dùng (giờ, thời tiết, nhịp tim...)
//   2. Hiển thị theme được AI chọn (màu sắc trực quan)
//   3. Hỏi 4 câu Likert 5 điểm
//   4. Lưu kết quả vào SharedPreferences
//
// Trong báo cáo: tổng hợp điểm trung bình từ N người dùng thực.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tuquanapai/core/app_dynamic_theme.dart';
import 'package:tuquanapai/service/gemma_theme_service.dart';

// ── Model câu hỏi ────────────────────────────────────────────────────────────

class LikertQuestion {
  final String id;
  final String question;
  final String lowLabel;  // Nhãn cho điểm 1
  final String highLabel; // Nhãn cho điểm 5

  const LikertQuestion({
    required this.id,
    required this.question,
    required this.lowLabel,
    required this.highLabel,
  });
}

const List<LikertQuestion> kUserStudyQuestions = [
  LikertQuestion(
    id: 'Q1_relevance',
    question: 'Theme màu sắc này phù hợp với thời điểm và trạng thái hiện tại của bạn?',
    lowLabel: 'Hoàn toàn\nkhông phù hợp',
    highLabel: 'Rất\nphù hợp',
  ),
  LikertQuestion(
    id: 'Q2_comfort',
    question: 'Nhìn vào theme này, bạn cảm thấy thoải mái và dễ nhìn?',
    lowLabel: 'Khó chịu,\nkhó nhìn',
    highLabel: 'Rất thoải mái,\ndễ nhìn',
  ),
  LikertQuestion(
    id: 'Q3_intelligence',
    question: 'AI hiểu đúng trạng thái của bạn và phản ánh qua màu sắc?',
    lowLabel: 'Không hiểu\ngì cả',
    highLabel: 'Hiểu rất\nchính xác',
  ),
  LikertQuestion(
    id: 'Q4_preference',
    question: 'So với theme cố định (màu hồng mặc định), bạn thích theme AI hơn?',
    lowLabel: 'Thích theme\ncố định hơn',
    highLabel: 'Thích theme\nAI hơn nhiều',
  ),
];

// ── User Study Response ───────────────────────────────────────────────────────

class UserStudyResponse {
  final String sessionId;
  final DateTime timestamp;
  final String paletteName;
  final ThemeContext context;
  final Map<String, int> scores; // questionId → 1-5
  final String? openFeedback;

  const UserStudyResponse({
    required this.sessionId,
    required this.timestamp,
    required this.paletteName,
    required this.context,
    required this.scores,
    this.openFeedback,
  });

  Map<String, dynamic> toJson() => {
    'session_id': sessionId,
    'timestamp': timestamp.toIso8601String(),
    'palette_name': paletteName,
    'context': {
      'hour': context.hourOfDay,
      'temp_c': context.tempC,
      'weather': context.weatherCondition,
      'heart_rate': context.heartRateBpm,
      'sleep_hours': context.sleepHours,
    },
    'scores': scores,
    'mean_score': double.parse(
      (scores.values.reduce((a, b) => a + b) / scores.length)
          .toStringAsFixed(2),
    ),
    'open_feedback': openFeedback,
  };
}

// ── User Study Screen ─────────────────────────────────────────────────────────

class UserStudyScreen extends StatefulWidget {
  final ThemeContext context;
  final AppDynamicTheme theme;

  const UserStudyScreen({
    super.key,
    required this.context,
    required this.theme,
  });

  @override
  State<UserStudyScreen> createState() => _UserStudyScreenState();
}

class _UserStudyScreenState extends State<UserStudyScreen> {
  final Map<String, int> _scores = {};
  final TextEditingController _feedbackCtrl = TextEditingController();
  bool _submitted = false;

  bool get _canSubmit =>
      _scores.length == kUserStudyQuestions.length;

  String _timeLabel(int h) => switch (h) {
    < 6 => 'Đêm khuya (${h}h)',
    < 12 => 'Buổi sáng (${h}h)',
    < 17 => 'Buổi chiều (${h}h)',
    < 20 => 'Buổi tối (${h}h)',
    _ => 'Đêm (${h}h)',
  };

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Đánh giá Theme AI'),
        backgroundColor: t.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _submitted ? _buildSuccessView() : _buildForm(t),
    );
  }

  Widget _buildForm(AppDynamicTheme t) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Context display ───────────────────────────────────────
          _SectionCard(
            title: 'Thông tin của bạn lúc này',
            child: Wrap(
              spacing: 8, runSpacing: 8,
              children: [
                _Chip(_timeLabel(widget.context.hourOfDay)),
                if (widget.context.tempC != null)
                  _Chip('${widget.context.tempC!.round()}°C'),
                if (widget.context.weatherCondition != null)
                  _Chip(widget.context.weatherCondition!),
                if (widget.context.heartRateBpm != null)
                  _Chip('Tim ${widget.context.heartRateBpm!.round()} bpm'),
                if (widget.context.sleepHours != null)
                  _Chip('Ngủ ${widget.context.sleepHours!.toStringAsFixed(1)}h'),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Theme preview ─────────────────────────────────────────
          _SectionCard(
            title: 'Theme AI đã chọn: "${t.name}"',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: t.appGradient,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: t.borderColor),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _ColorDot(t.primary, 'Primary'),
                    const SizedBox(width: 8),
                    _ColorDot(t.primaryLight, 'Light'),
                    const SizedBox(width: 8),
                    _ColorDot(t.primaryDark, 'Dark'),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  t.reason,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Likert questions ──────────────────────────────────────
          const Text(
            'Câu hỏi đánh giá',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),

          ...kUserStudyQuestions.map((q) => _LikertCard(
            question: q,
            value: _scores[q.id],
            accentColor: t.primary,
            onChanged: (v) => setState(() => _scores[q.id] = v),
          )),

          // ── Open feedback ─────────────────────────────────────────
          _SectionCard(
            title: 'Nhận xét thêm (không bắt buộc)',
            child: TextField(
              controller: _feedbackCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Bạn thấy theme này như thế nào? Có muốn thay đổi gì không?',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(10),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Submit ────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _canSubmit ? _submit : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: t.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _canSubmit
                    ? 'Gửi đánh giá'
                    : 'Hãy trả lời ${kUserStudyQuestions.length - _scores.length} câu hỏi còn lại',
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSuccessView() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.check_circle, color: Colors.green, size: 64),
        const SizedBox(height: 16),
        const Text(
          'Cảm ơn bạn đã đánh giá!',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          'Điểm trung bình: ${(_scores.values.reduce((a, b) => a + b) / _scores.length).toStringAsFixed(2)} / 5',
          style: TextStyle(fontSize: 15, color: Colors.grey[600]),
        ),
      ],
    ),
  );

  Future<void> _submit() async {
    final response = UserStudyResponse(
      sessionId: DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      paletteName: widget.theme.name,
      context: widget.context,
      scores: Map.from(_scores),
      openFeedback: _feedbackCtrl.text.trim().isEmpty
          ? null
          : _feedbackCtrl.text.trim(),
    );

    // Lưu vào SharedPreferences (tích lũy nhiều response)
    await _saveResponse(response);

    setState(() => _submitted = true);
  }

  Future<void> _saveResponse(UserStudyResponse response) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getStringList('user_study_responses') ?? [];
      existing.add(jsonEncode(response.toJson()));
      await prefs.setStringList('user_study_responses', existing);
      debugPrint('[UserStudy] Đã lưu response #${existing.length}');
    } catch (e) {
      debugPrint('[UserStudy] Lỗi lưu: $e');
    }
  }
}

// ── Utility Widgets ───────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.grey[50],
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.grey[200]!),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        child,
      ],
    ),
  );
}

class _Chip extends StatelessWidget {
  final String label;
  const _Chip(this.label);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.blue[50],
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.blue[100]!),
    ),
    child: Text(label,
        style: TextStyle(fontSize: 12, color: Colors.blue[700])),
  );
}

class _ColorDot extends StatelessWidget {
  final Color color;
  final String label;
  const _ColorDot(this.color, this.label);

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey[300]!),
        ),
      ),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
    ],
  );
}

class _LikertCard extends StatelessWidget {
  final LikertQuestion question;
  final int? value;
  final Color accentColor;
  final void Function(int) onChanged;

  const _LikertCard({
    required this.question,
    required this.value,
    required this.accentColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: value != null ? accentColor.withOpacity(0.4) : Colors.grey[200]!,
        width: value != null ? 1.5 : 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          question.question,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(5, (i) {
            final score = i + 1;
            final selected = value == score;
            return GestureDetector(
              onTap: () => onChanged(score),
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: selected ? accentColor : Colors.grey[100],
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? accentColor : Colors.grey[300]!,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '$score',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: selected ? Colors.white : Colors.grey[600],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              question.lowLabel,
              style: TextStyle(fontSize: 10, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
            Text(
              question.highLabel,
              style: TextStyle(fontSize: 10, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ],
    ),
  );
}

// ── User Study Results Reader (cho báo cáo) ───────────────────────────────────

class UserStudyResultsReader {
  static Future<Map<String, dynamic>> loadAndAggregate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList('user_study_responses') ?? [];

      if (raw.isEmpty) return {'error': 'Chưa có response nào'};

      final responses = raw
          .map((s) => jsonDecode(s) as Map<String, dynamic>)
          .toList();

      // Tính mean từng câu hỏi
      final questionIds =
      kUserStudyQuestions.map((q) => q.id).toList();
      final questionStats = <String, Map<String, double>>{};

      for (final qId in questionIds) {
        final scores = responses
            .where((r) => (r['scores'] as Map).containsKey(qId))
            .map((r) => ((r['scores'] as Map)[qId] as int).toDouble())
            .toList();

        if (scores.isEmpty) continue;
        final mean = scores.reduce((a, b) => a + b) / scores.length;
        scores.sort();
        questionStats[qId] = {
          'mean': double.parse(mean.toStringAsFixed(2)),
          'n': scores.length.toDouble(),
          'min': scores.first,
          'max': scores.last,
        };
      }

      // Overall mean score
      final allMeans = responses
          .map((r) => r['mean_score'] as double)
          .toList();
      final overallMean = allMeans.reduce((a, b) => a + b) / allMeans.length;

      // Phân bố palette được đánh giá
      final paletteFreq = <String, int>{};
      for (final r in responses) {
        final p = r['palette_name'] as String;
        paletteFreq[p] = (paletteFreq[p] ?? 0) + 1;
      }

      // Open feedback
      final feedbacks = responses
          .where((r) => r['open_feedback'] != null)
          .map((r) => r['open_feedback'] as String)
          .toList();

      return {
        'n_responses': responses.length,
        'overall_mean_score': double.parse(overallMean.toStringAsFixed(2)),
        'question_stats': questionStats,
        'palette_distribution': paletteFreq,
        'open_feedbacks': feedbacks,
        'raw': responses,
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Export toàn bộ responses ra JSON string (để copy ra Excel/SPSS)
  static Future<String> exportJson() async {
    final data = await loadAndAggregate();
    return const JsonEncoder.withIndent('  ').convert(data);
  }
}