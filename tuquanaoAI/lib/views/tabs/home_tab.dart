import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tuquanapai/evaluation/lib/evaluation_dashboard.dart';
import 'package:tuquanapai/service/gemma_theme_service.dart';
import '../../core/theme.dart';
import '../../repositories/app_repository.dart';
import '../../service/Session_service.dart';
import '../../service/Weather_service.dart';
import '../../service/theme_service.dart';
import '../../viewmodels/home_viewmodel.dart';
import '../../viewmodels/wardrobe_viewmodel.dart';
import '../widgets/common_widgets.dart';

class HomeTab extends StatelessWidget {
  final VoidCallback onGoEval;
  const HomeTab({super.key, required this.onGoEval});

  @override
  Widget build(BuildContext context) {
    final vm       = context.watch<HomeViewModel>();
    final wardrobe = context.watch<WardrobeViewModel>().wardrobe;
    final session  = context.watch<SessionService>();
    final weather  = context.watch<WeatherService>();
    final t        = AppTheme.of(context);

    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Chào buổi sáng'
        : hour < 18
        ? 'Chào buổi chiều'
        : 'Chào buổi tối';
    final greetingEmoji = hour < 12 ? '🌸' : hour < 18 ? '☀️' : '🌙';

    final fullName  = session.currentUser?.name ?? '';
    final firstName = fullName.trim().split(' ').last.isNotEmpty
        ? fullName.trim().split(' ').last
        : 'bạn';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${greeting.toUpperCase()} · $firstName $greetingEmoji',
          style: TextStyle(
            fontSize: 11.5,
            color: t.textSecondary,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.0,
          ),
        ),
        const SizedBox(height: 14),

        // ── Weather Card ──────────────────────────────────────────────────
        _WeatherCard(weather: weather),

        // ── Suggest Outfit Card ───────────────────────────────────────────
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('✨ Gợi ý trang phục hôm nay',
                  style: TextStyle(fontWeight: FontWeight.w800, color: t.primaryDark, fontSize: 14.5)),
              const SizedBox(height: 3),
              Text(
                'AI sẽ kết hợp tủ đồ với thời tiết, địa điểm và sức khoẻ để đề xuất bộ phù hợp nhất.',
                style: TextStyle(fontSize: 11.5, color: t.textSecondary, fontWeight: FontWeight.w600, height: 1.45),
              ),
              const SizedBox(height: 12),
              Text('📍 Hôm nay bạn đi đâu:',
                  style: TextStyle(fontSize: 12.5, color: t.textMuted, fontWeight: FontWeight.w700)),
              const SizedBox(height: 7),
              Wrap(
                children: AppRepository.destinationTags.map((tag) => TagButton(
                  label: tag,
                  active: vm.destination == tag,
                  onTap: () => context.read<HomeViewModel>().setDestination(tag),
                )).toList(),
              ),
              const SizedBox(height: 12),
              Text('💗 Tình trạng sức khoẻ hôm nay:',
                  style: TextStyle(fontSize: 12.5, color: t.textMuted, fontWeight: FontWeight.w700)),
              const SizedBox(height: 7),
              Wrap(
                children: AppRepository.healthTags.map((tag) => TagButton(
                  label: tag,
                  active: vm.health == tag,
                  onTap: () => context.read<HomeViewModel>().setHealth(tag),
                )).toList(),
              ),
              const SizedBox(height: 14),
              PrimaryButton(
                label: vm.state == SuggestState.loading
                    ? '✨ Đang phân tích...'
                    : '✨ Gợi ý trang phục cho tôi!',
                onTap: vm.state == SuggestState.loading
                    ? null
                    : () => context.read<HomeViewModel>().suggestOutfit(wardrobe),
              ),
            ],
          ),
        ),



        // ── Quick Eval Shortcut ───────────────────────────────────────────
        _QuickEvalButton(onTap: onGoEval),
        _buildPlayButton(context),
        // ── AI States ─────────────────────────────────────────────────────
        if (vm.state == SuggestState.loading) const SpinnerWidget(),
        if (vm.state == SuggestState.error)
          _buildErrorBanner(context, vm.health, weather.weather?.tempDisplay ?? ''),
        if (vm.state == SuggestState.success && vm.suggestion != null)
          AIResultCard(text: vm.suggestion!),

        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildErrorBanner(BuildContext context, String health, String temp) {
    final t = AppTheme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFfce4ec), Color(0xFFf8bbd0)]),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFf48fb1), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('⚠️ Máy chủ AI tạm thời không phản hồi',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFFC62828))),
          const SizedBox(height: 4),
          Text(
            'Gợi ý nhanh: Thời tiết ${temp.isNotEmpty ? temp : "hôm nay"} và tình trạng $health — ưu tiên áo vải nhẹ, quần rộng thoáng khí.',
            style: const TextStyle(fontSize: 12, color: Color(0xFFD32F2F), height: 1.5),
          ),
          const Text('💡 Gợi ý dự phòng (Heuristic) · AI sẽ phục hồi sớm',
              style: TextStyle(fontSize: 11, color: Color(0xFFE57373))),
        ],
      ),
    );
  }

  // Thêm nút Play nổi bật, đồng bộ với AppTheme
  Widget _buildPlayButton(BuildContext context) {
    final t = AppTheme.of(context);
    return const _PlayDashboardButton();
  }
}

// ── _WeatherCard ──────────────────────────────────────────────────────────────

class _WeatherCard extends StatelessWidget {
  final WeatherService weather;
  const _WeatherCard({required this.weather});

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);

    final cardGradient = LinearGradient(
      colors: [
        t.gradientStart,
        t.gradientEnd,
      ],
    );
    final cardBorder = Border.fromBorderSide(
      BorderSide(color: t.borderColor.withOpacity(0.3)),
    );

    if (weather.status == WeatherStatus.loading ||
        weather.status == WeatherStatus.idle) {
      return AppCard(
        gradient: cardGradient,
        border: cardBorder,
        child: SizedBox(
          height: 80,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: t.primary),
                ),
                const SizedBox(width: 10),
                Text('Đang lấy dữ liệu thời tiết...',
                    style: TextStyle(
                        fontSize: 13,
                        color: t.textSecondary,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      );
    }

    if (weather.status == WeatherStatus.error || !weather.isReady) {
      return AppCard(
        gradient: cardGradient,
        border: cardBorder,
        child: Row(children: [
          const Text('🌐', style: TextStyle(fontSize: 28)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Không lấy được thời tiết',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: t.textSecondary)),
              Text(
                weather.errorMessage ?? 'Kiểm tra GPS và kết nối mạng',
                style: TextStyle(fontSize: 11, color: t.textMuted),
                maxLines: 2,
              ),
            ]),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              context.read<WeatherService>().fetchWeather().then((_) {
                // Trigger theme update khi retry thời tiết thành công
                if (context.mounted) _triggerThemeOnWeather(context);
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: t.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('Thử lại',
                  style: TextStyle(
                      fontSize: 11.5,
                      color: t.primary,
                      fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      );
    }

    // ── Success ───────────────────────────────────────────────────────────
    final w = weather.weather!;

    // Trigger theme khi weather đã load xong lần đầu
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _triggerThemeOnWeather(context);
    });

    return AppCard(
      gradient: cardGradient,
      border: cardBorder,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '📍 ${w.city.toUpperCase()} · HÔM NAY',
                style: TextStyle(
                    fontSize: 10,
                    color: t.textSecondary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5),
              ),
              const SizedBox(height: 6),
              Text(
                w.tempDisplay,
                style: TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.w900,
                    color: t.primaryDark,
                    letterSpacing: -1,
                    height: 1.1),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    w.icon,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    w.description,
                    style: TextStyle(
                        fontSize: 13,
                        color: t.primaryDark,
                        fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '${w.humidityDisplay} · ${w.windDisplay}',
                style: TextStyle(
                  fontSize: 11,
                  color: t.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Column(
            children: [
              Text(w.icon, style: const TextStyle(fontSize: 56)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: t.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  w.dayOfWeek.toUpperCase(),
                  style: TextStyle(
                      fontSize: 9.5,
                      color: t.primary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Trigger ThemeService.generateTheme() với dữ liệu thời tiết hiện tại
  void _triggerThemeOnWeather(BuildContext context) {
    final weather = context.read<WeatherService>();
    if (!weather.isReady) return;
    final w = weather.weather!;
    final themeCtx = ThemeContext(
      tempC:            w.tempC,
      weatherCondition: w.description,
      hourOfDay:        DateTime.now().hour,
    );
    context.read<ThemeService>().generateTheme(themeCtx);
  }
}

class _QuickEvalButton extends StatefulWidget {
  final VoidCallback onTap;
  const _QuickEvalButton({required this.onTap});

  @override
  State<_QuickEvalButton> createState() => _QuickEvalButtonState();
}

class _QuickEvalButtonState extends State<_QuickEvalButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.97),
      onTapUp: (_) => setState(() => _scale = 1.0),
      onTapCancel: () => setState(() => _scale = 1.0),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
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
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: t.primary.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Text('👗', style: TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Đánh giá trang phục',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: t.primaryDark),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Chọn bộ đồ có sẵn và nhận nhận xét từ AI',
                    style: TextStyle(fontSize: 11.5, color: t.textSecondary, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const Spacer(),
              Text('→', style: TextStyle(fontSize: 18, color: t.primary, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayDashboardButton extends StatefulWidget {
  const _PlayDashboardButton();

  @override
  State<_PlayDashboardButton> createState() => _PlayDashboardButtonState();
}

class _PlayDashboardButtonState extends State<_PlayDashboardButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      width: double.infinity,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _scale = 0.96),
        onTapUp: (_) => setState(() => _scale = 1.0),
        onTapCancel: () => setState(() => _scale = 1.0),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const EvaluationDashboard()),
          );
        },
        child: AnimatedScale(
          scale: _scale,
          duration: const Duration(milliseconds: 100),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 15),
            decoration: BoxDecoration(
              gradient: t.primaryGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: t.primary.withOpacity(0.24),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                )
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.play_circle_fill, size: 20, color: Colors.white),
                const SizedBox(width: 8),
                const Text(
                  'Chạy Thực Nghiệm Đánh Giá',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}