import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../service/Session_service.dart';
import '../tabs/health_tab.dart';
import '../tabs/history_tab.dart';
import '../tabs/home_tab.dart';
import '../tabs/outfit_eval_tab.dart';
import '../tabs/profile_tab.dart';
import '../tabs/wardrobe_tab.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tabIndex = 0;
  bool _showOutfitEval = false;

  static const _tabs = [
    {'icon': Icons.auto_awesome,  'label': 'Trang chủ'},
    {'icon': Icons.checkroom,     'label': 'Tủ đồ'},
    {'icon': Icons.menu_book,     'label': 'Lịch sử'},
    {'icon': Icons.favorite,      'label': 'Sức khoẻ'},
    {'icon': Icons.local_florist, 'label': 'Cá nhân'},
  ];

  void _setTab(int i) => setState(() {
    _tabIndex = i;
    _showOutfitEval = false;
  });

  /// Xử lý khi user vuốt back hoặc nhấn nút back hệ thống.
  /// - Nếu đang ở sub-screen (OutfitEval) → quay về tab chính, không thoát.
  /// - Nếu không ở tab 0 → về tab Trang chủ, không thoát.
  /// - Nếu đang ở tab 0 → hiện dialog xác nhận thoát app.
  Future<bool> _onWillPop() async {
    // Nếu đang xem OutfitEval → back về tab hiện tại
    if (_showOutfitEval) {
      setState(() => _showOutfitEval = false);
      return false;
    }

    // Nếu không ở tab đầu → về tab Trang chủ
    if (_tabIndex != 0) {
      setState(() => _tabIndex = 0);
      return false;
    }

    // Ở tab Trang chủ → hỏi xác nhận thoát
    return await _showExitDialog();
  }

  Future<bool> _showExitDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: const Color(0xFFFFF5F8),
        title: const Row(
          children: [
            Text('🌸', style: TextStyle(fontSize: 22)),
            SizedBox(width: 8),
            Text(
              'Thoát ứng dụng?',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryDark,
              ),
            ),
          ],
        ),
        content: const Text(
          'Bạn có chắc muốn thoát StyleAI không?',
          style: TextStyle(
            fontSize: 13.5,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
            height: 1.5,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          // Huỷ – ở lại app
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFF0D0DC), width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text(
                'Ở lại',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Xác nhận thoát
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                elevation: 0,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text(
                'Thoát',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    // Nếu user xác nhận → đóng app hoàn toàn
    if (confirmed == true) {
      SystemNavigator.pop();
    }
    return false; // Không để Flutter tự pop (đã xử lý thủ công)
  }

  @override
  Widget build(BuildContext context) {
    // PopScope thay thế WillPopScope (Flutter 3.12+)
    // canPop: false → luôn chặn back mặc định, xử lý thủ công qua onPopInvoked
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        await _onWillPop();
      },
      child: Builder(
        builder: (context) {
          final t = AppTheme.of(context); // watch → rebuild khi theme đổi
          return Scaffold(
            backgroundColor: Colors.transparent,
            body: Container(
              decoration: BoxDecoration(gradient: t.appGradient),
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    const _AppHeader(),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                        child: _buildContent(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            bottomNavigationBar: _BottomNav(
              currentIndex: _tabIndex,
              showSubScreen: _showOutfitEval,
              onTap: _setTab,
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent() {
    if (_showOutfitEval) {
      return OutfitEvalTab(onBack: () => setState(() => _showOutfitEval = false));
    }
    switch (_tabIndex) {
      case 0: return HomeTab(onGoEval: () => setState(() { _showOutfitEval = true; }));
      case 1: return const WardrobeTab();
      case 2: return const HistoryTab();
      case 3: return const HealthTab();
      case 4: return const ProfileTab();
      default: return const SizedBox();
    }
  }
}

// ─── _AppHeader ───────────────────────────────────────────────────────────────
class _AppHeader extends StatelessWidget {
  const _AppHeader();

  @override
  Widget build(BuildContext context) {
    final t       = AppTheme.of(context); // watch → rebuild khi theme đổi
    final session = context.watch<SessionService>();

    final name = session.currentUser?.name ?? '';
    final initial = name.trim().isNotEmpty
        ? name.trim()[0].toUpperCase()
        : '?';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
      decoration: BoxDecoration(
        color: t.gradientStart.withOpacity(0.95),
        border: Border(bottom: BorderSide(color: t.borderColor.withOpacity(0.3))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'StyleAI',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: t.primaryDark,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'PHONG CÁCH · SỨC KHOẺ · PHONG CÁCH SỐNG',
                style: TextStyle(
                  fontSize: 9,
                  color: t.textSecondary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.8,
                ),
              ),
            ],
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: t.primaryGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: t.primary.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: Center(
              child: Text(
                initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── _BottomNav ───────────────────────────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final bool showSubScreen;
  final ValueChanged<int> onTap;

  const _BottomNav({
    required this.currentIndex,
    required this.showSubScreen,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context); // watch → rebuild khi theme đổi
    return Container(
      decoration: BoxDecoration(
        color: t.gradientStart.withOpacity(0.97),
        border: Border(top: BorderSide(color: t.borderColor.withOpacity(0.4))),
        boxShadow: [
          BoxShadow(
            color: t.primary.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          child: Row(
            children: List.generate(_MainShellState._tabs.length, (i) {
              final isActive = currentIndex == i && !showSubScreen;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: isActive ? t.primary.withOpacity(0.08) : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          _MainShellState._tabs[i]['icon'] as IconData,
                          size: 20,
                          color: isActive
                              ? t.primary
                              : t.textMuted.withOpacity(0.6),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _MainShellState._tabs[i]['label'] as String,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: isActive
                              ? t.primary
                              : t.textMuted.withOpacity(0.7),
                          letterSpacing: 0.1,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}