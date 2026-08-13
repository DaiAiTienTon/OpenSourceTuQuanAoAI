import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tuquanapai/viewmodels/Ai_History_viewmodel.dart';
import '../../core/theme.dart';
import '../widgets/common_widgets.dart';

class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  String? _expandedSuggestId;
  String? _expandedEvalId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final hvm = context.read<AiHistoryViewModel>();
      if (hvm.suggestState == HistoryLoadState.idle) {
        hvm.loadAll();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Tab selector ───────────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.92),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: t.borderColor.withOpacity(0.4), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: t.primary.withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TabBar(
              controller: _tabController,
              labelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, letterSpacing: 0.2),
              unselectedLabelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              labelColor: t.primaryDark,
              unselectedLabelColor: t.textMuted,
              indicator: BoxDecoration(
                color: t.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: t.primary.withOpacity(0.15), width: 1),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              padding: const EdgeInsets.all(4),
              tabs: const [
                Tab(text: '✨ Gợi ý AI'),
                Tab(text: '🌸 Đánh giá AI'),
              ],
            ),
          ),

          // ── Tab content ────────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _SuggestionHistoryList(
                  expandedId: _expandedSuggestId,
                  onExpand: (id) => setState(() => _expandedSuggestId = id),
                ),
                _EvaluationHistoryList(
                  expandedId: _expandedEvalId,
                  onExpand: (id) => setState(() => _expandedEvalId = id),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab 1: Lịch sử gợi ý AI ──────────────────────────────────────────────────

class _SuggestionHistoryList extends StatelessWidget {
  final String? expandedId;
  final ValueChanged<String?> onExpand;
  const _SuggestionHistoryList({required this.expandedId, required this.onExpand});

  @override
  Widget build(BuildContext context) {
    final hvm = context.watch<AiHistoryViewModel>();
    final t   = AppTheme.of(context);

    if (hvm.suggestState == HistoryLoadState.loading && hvm.suggestions.isEmpty) {
      return const Center(child: SpinnerWidget(text: 'Đang tải gợi ý AI...'));
    }

    if (hvm.suggestions.isEmpty) {
      return _EmptyState(
        icon: '✨',
        title: 'Chưa có gợi ý nào',
        subtitle: 'Về trang chính và nhấn "Gợi ý trang phục" để bắt đầu!',
      );
    }

    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: hvm.suggestions.length + (hvm.suggestHasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == hvm.suggestions.length) {
          if (hvm.suggestState != HistoryLoadState.loading) hvm.loadSuggestions();
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: t.primary)),
          );
        }

        final s = hvm.suggestions[index];
        final isExpanded = expandedId == s.id;

        return GestureDetector(
          onTap: () => onExpand(isExpanded ? null : s.id),
          child: _HistoryCard(
            isExpanded: isExpanded,
            headerSlot: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('🕐 ${_formatDate(s.createdAt)}',
                  style: TextStyle(fontSize: 11.5, color: t.textSecondary, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                s.suggestionText.length > 80
                    ? '${s.suggestionText.substring(0, 80)}...'
                    : s.suggestionText,
                style: TextStyle(fontSize: 13, color: t.primaryDark, fontWeight: FontWeight.w700, height: 1.4),
              ),
            ]),
            tagsSlot: Wrap(children: [
              if (s.destination != null) _tag(context, '📍 ${s.destination}'),
              if (s.healthTag != null) _tag(context, '💗 ${s.healthTag}'),
              _tag(context, _sourceLabel(s.source)),
              if (s.isHelpful == true) _tag(context, '👍 Hữu ích'),
              if (s.isHelpful == false) _tag(context, '👎 Chưa phù hợp'),
            ]),
            expandedSlot: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.suggestionText,
                  style: TextStyle(fontSize: 12.5, color: t.primaryDark, height: 1.65, fontWeight: FontWeight.w600)),
              if (s.weatherSnapshot != null) ...[
                const SizedBox(height: 8),
                Text('🌤 ${s.weatherSnapshot}',
                    style: TextStyle(fontSize: 11.5, color: t.textSecondary)),
              ],
              const SizedBox(height: 12),
              if (s.isHelpful == null)
                Row(children: [
                  _FeedbackButton(
                    label: '👍 Hữu ích',
                    color: const Color(0xFF4CAF50),
                    onTap: () => context.read<AiHistoryViewModel>().sendFeedback(suggestionId: s.id, isHelpful: true),
                  ),
                  const SizedBox(width: 8),
                  _FeedbackButton(
                    label: '👎 Chưa phù hợp',
                    color: const Color(0xFFE57373),
                    onTap: () => context.read<AiHistoryViewModel>().sendFeedback(suggestionId: s.id, isHelpful: false),
                  ),
                ])
              else
                Text(
                  s.isHelpful! ? '👍 Bạn đã đánh giá hữu ích' : '👎 Bạn đã đánh giá chưa phù hợp',
                  style: TextStyle(fontSize: 12, color: t.textSecondary, fontStyle: FontStyle.italic),
                ),
            ]),
          ),
        );
      },
    );
  }

  String _sourceLabel(String source) {
    switch (source) {
      case 'rag':    return '🤖 RAG';
      case 'worker': return '⚡ Worker';
      default:       return '💡 Heuristic';
    }
  }
}

// ── Tab 2: Lịch sử đánh giá AI ───────────────────────────────────────────────

class _EvaluationHistoryList extends StatelessWidget {
  final String? expandedId;
  final ValueChanged<String?> onExpand;
  const _EvaluationHistoryList({required this.expandedId, required this.onExpand});

  @override
  Widget build(BuildContext context) {
    final hvm = context.watch<AiHistoryViewModel>();
    final t   = AppTheme.of(context);

    if (hvm.evalState == HistoryLoadState.loading && hvm.evaluations.isEmpty) {
      return const Center(child: SpinnerWidget(text: 'Đang tải lịch sử đánh giá...'));
    }

    if (hvm.evaluations.isEmpty) {
      return _EmptyState(
        icon: '🌸',
        title: 'Chưa có đánh giá nào',
        subtitle: 'Chọn trang phục và nhấn "Đánh giá outfit" để bắt đầu!',
      );
    }

    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: hvm.evaluations.length + (hvm.evalHasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == hvm.evaluations.length) {
          if (hvm.evalState != HistoryLoadState.loading) hvm.loadEvaluations();
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: t.primary)),
          );
        }

        final e = hvm.evaluations[index];
        final isExpanded = expandedId == e.id;

        return GestureDetector(
          onTap: () => onExpand(isExpanded ? null : e.id),
          child: _HistoryCard(
            isExpanded: isExpanded,
            headerSlot: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('🕐 ${_formatDate(e.createdAt)}',
                  style: TextStyle(fontSize: 11.5, color: t.textSecondary, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('👕 ${e.topItemName}  ·  👖 ${e.bottomItemName}',
                  style: TextStyle(fontSize: 13, color: t.primaryDark, fontWeight: FontWeight.w800)),
            ]),
            tagsSlot: Wrap(children: [
              if (e.destination != null) _tag(context, '📍 ${e.destination}'),
              if (e.userRating != null) _tag(context, '⭐ ${e.userRating}/5'),
            ]),
            expandedSlot: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(e.evaluationText,
                  style: TextStyle(fontSize: 12.5, color: t.primaryDark, height: 1.65, fontWeight: FontWeight.w600)),
              if (e.weatherSnapshot != null) ...[
                const SizedBox(height: 8),
                Text('🌤 ${e.weatherSnapshot}',
                    style: TextStyle(fontSize: 11.5, color: t.textSecondary)),
              ],
              const SizedBox(height: 12),
              if (e.userRating == null) ...[
                Text('Chấm điểm gợi ý này:',
                    style: TextStyle(fontSize: 12, color: t.textSecondary)),
                const SizedBox(height: 6),
                Row(
                  children: List.generate(5, (i) => GestureDetector(
                    onTap: () => context.read<AiHistoryViewModel>().rateEvaluation(evaluationId: e.id, rating: i + 1),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Text('⭐', style: TextStyle(fontSize: 22, color: Colors.amber.shade300)),
                    ),
                  )),
                ),
              ] else
                Text('⭐ Bạn đã chấm ${e.userRating}/5 sao',
                    style: TextStyle(fontSize: 12, color: t.textSecondary, fontStyle: FontStyle.italic)),
            ]),
          ),
        );
      },
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _HistoryCard extends StatelessWidget {
  final bool isExpanded;
  final Widget headerSlot;
  final Widget tagsSlot;
  final Widget expandedSlot;

  const _HistoryCard({
    required this.isExpanded,
    required this.headerSlot,
    required this.tagsSlot,
    required this.expandedSlot,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: t.borderColor.withOpacity(0.4), width: 1),
        boxShadow: [
          BoxShadow(
            color: t.primary.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: headerSlot),
              const SizedBox(width: 8),
              AnimatedRotation(
                turns: isExpanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                child: Icon(
                  Icons.expand_more_rounded,
                  size: 20,
                  color: t.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          tagsSlot,
          if (isExpanded) ...[
            Divider(color: t.borderColor.withOpacity(0.4), height: 24, thickness: 1),
            expandedSlot,
          ],
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String icon;
  final String title;
  final String subtitle;
  const _EmptyState({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(children: [
          Text(icon, style: const TextStyle(fontSize: 42)),
          const SizedBox(height: 10),
          Text(title,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: t.textSecondary)),
          const SizedBox(height: 4),
          Text(subtitle, textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: t.textSecondary)),
        ]),
      ),
    );
  }
}

class _FeedbackButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _FeedbackButton({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

Widget _tag(BuildContext context, String text) {
  final t = AppTheme.of(context);
  return Container(
    margin: const EdgeInsets.only(right: 4, bottom: 4),
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
    decoration: BoxDecoration(
      color: t.gradientStart,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: t.borderColor),
    ),
    child: Text(text,
        style: TextStyle(fontSize: 11, color: t.textMuted, fontWeight: FontWeight.w700)),
  );
}

String _formatDate(DateTime dt) {
  final d   = dt.toLocal();
  final pad = (int n) => n.toString().padLeft(2, '0');
  return '${pad(d.day)}/${pad(d.month)}/${d.year} · ${pad(d.hour)}:${pad(d.minute)}';
}