import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../repositories/app_repository.dart';
import '../../viewmodels/outfit_eval_viewmodel.dart';
import '../../viewmodels/wardrobe_viewmodel.dart';
import '../widgets/common_widgets.dart';

class OutfitEvalTab extends StatelessWidget {
  final VoidCallback onBack;
  const OutfitEvalTab({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final vm       = context.watch<OutfitEvalViewModel>();
    final wardrobe = context.watch<WardrobeViewModel>().wardrobe;
    final t        = AppTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ───────────────────────────────────────────────────────
        Row(children: [
          GestureDetector(
            onTap: onBack,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: t.borderColor.withOpacity(0.8), width: 1.2),
              ),
              child: Center(
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 14,
                  color: t.primaryDark,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Đánh giá trang phục',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: t.primaryDark),
          ),
        ]),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 46),
          child: Text(
            'Chọn bộ trang phục bạn định mặc, AI sẽ nhận xét mức độ phù hợp với thời tiết và địa điểm.',
            style: TextStyle(fontSize: 12, color: t.textSecondary, fontWeight: FontWeight.w600, height: 1.5),
          ),
        ),
        const SizedBox(height: 12),

        // ── Selected Outfit Preview ───────────────────────────────────────
        if (vm.isReady)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: t.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: t.primary.withOpacity(0.2), width: 1.2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BỘ ĐỒ ĐÃ CHỌN',
                  style: TextStyle(
                    fontSize: 9.5,
                    color: t.primary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Text('👕', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        vm.selectedTop!.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13.5, color: t.primaryDark, fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text('·', style: TextStyle(color: t.textSecondary, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 6),
                    const Text('👖', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        vm.selectedBottom!.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13.5, color: t.primaryDark, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

        // ── Select Top ────────────────────────────────────────────────────
        AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('👕 Chọn áo',
              style: TextStyle(fontWeight: FontWeight.w800, color: t.primaryDark, fontSize: 14.5)),
          Text('Chọn áo bạn muốn mặc từ tủ áo cá nhân',
              style: TextStyle(fontSize: 11.5, color: t.textSecondary)),
          const SizedBox(height: 10),
          Wrap(
            children: wardrobe.tops.map((top) => ItemChip(
              label: top.name,
              selected: vm.selectedTop?.id == top.id,
              onTap: () => context.read<OutfitEvalViewModel>().selectTop(top),
            )).toList(),
          ),
        ])),

        // ── Select Bottom ─────────────────────────────────────────────────
        AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('👖 Chọn quần / váy',
              style: TextStyle(fontWeight: FontWeight.w800, color: t.primaryDark, fontSize: 14.5)),
          Text('Chọn quần hoặc váy từ tủ quần của bạn',
              style: TextStyle(fontSize: 11.5, color: t.textSecondary)),
          const SizedBox(height: 10),
          Wrap(
            children: wardrobe.bottoms.map((bottom) => ItemChip(
              label: bottom.name,
              selected: vm.selectedBottom?.id == bottom.id,
              onTap: () => context.read<OutfitEvalViewModel>().selectBottom(bottom),
            )).toList(),
          ),
        ])),

        // ── Destination ───────────────────────────────────────────────────
        AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('📍 Địa điểm hôm nay',
              style: TextStyle(fontWeight: FontWeight.w800, color: t.primaryDark, fontSize: 14.5)),
          const SizedBox(height: 8),
          Wrap(
            children: AppRepository.destinationTags.map((d) => TagButton(
              label: d,
              active: vm.destination == d,
              onTap: () => context.read<OutfitEvalViewModel>().setDestination(d),
            )).toList(),
          ),
        ])),

        // ── Health ────────────────────────────────────────────────────────
        AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('💗 Tình trạng sức khoẻ',
              style: TextStyle(fontWeight: FontWeight.w800, color: t.primaryDark, fontSize: 14.5)),
          const SizedBox(height: 8),
          Wrap(
            children: AppRepository.healthTags.map((h) => TagButton(
              label: h,
              active: vm.health == h,
              onTap: () => context.read<OutfitEvalViewModel>().setHealth(h),
            )).toList(),
          ),
        ])),

        // ── Validation hint ───────────────────────────────────────────────
        if (!vm.isReady)
          Container(
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: t.gradientStart.withOpacity(0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                'ⓘ Vui lòng chọn áo và quần/váy để tiếp tục',
                style: TextStyle(fontSize: 12.5, color: t.textSecondary, fontWeight: FontWeight.w600),
              ),
            ),
          ),

        // ── CTA ───────────────────────────────────────────────────────────
        PrimaryButton(
          label: vm.state == EvalState.loading
              ? '🌸 Đang đánh giá...'
              : '🌸 Đánh giá trang phục của tôi',
          onTap: (!vm.isReady || vm.state == EvalState.loading)
              ? null
              : () => context.read<OutfitEvalViewModel>().evaluate(),
        ),

        if (vm.state == EvalState.loading)
          const SpinnerWidget(text: 'AI đang đánh giá outfit của bạn...'),
        if (vm.state == EvalState.success && vm.result != null)
          AIResultCard(text: vm.result!),

        const SizedBox(height: 20),
      ],
    );
  }
}