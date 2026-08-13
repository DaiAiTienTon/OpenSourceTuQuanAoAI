import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tuquanapai/service/gemma_theme_service.dart';
import 'package:tuquanapai/viewmodels/health_viewmodel.dart';
import '../../core/theme.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/profile_viewmodel.dart';
import '../../viewmodels/wardrobe_viewmodel.dart';
import '../../service/Session_service.dart';
import '../widgets/common_widgets.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  late TextEditingController _nameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _birthCtrl;
  final _hobbyCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nameCtrl  = TextEditingController();
    _emailCtrl = TextEditingController();
    _birthCtrl = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final vm = context.read<ProfileViewModel>();
    if (!vm.isEditing) {
      final user = vm.user;
      _nameCtrl.text  = user.name;
      _emailCtrl.text = user.email;
      _birthCtrl.text = user.birthYear > 0 ? user.birthYear.toString() : '';
    }

    final success = vm.successMessage;
    final error   = vm.errorMessage;

    if (success != null) {
      vm.clearMessages();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(success),
          backgroundColor: const Color(0xFF4CAF50),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ));
      });
    }

    if (error != null && !vm.isEditing) {
      vm.clearMessages();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error),
          backgroundColor: const Color(0xFFE53935),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 3),
        ));
      });
    }
  }

  void _showEditHobbyDialog(BuildContext context, String hobby) {
    final t    = AppTheme.read(context);
    final ctrl = TextEditingController(text: hobby);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.fromLTRB(
          20, 24, 20,
          MediaQuery.of(sheetCtx).viewInsets.bottom + 28,
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            '✏️ Sửa sở thích',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: t.primaryDark),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: ctrl,
            autofocus: true,
            style: TextStyle(fontSize: 14, color: t.primaryDark),
            decoration: InputDecoration(
              hintText: 'Nhập sở thích mới...',
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: t.borderColor, width: 1.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: t.borderColor, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: t.primaryLight, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: SecondaryButton(label: 'Huỷ', onTap: () => Navigator.of(sheetCtx).pop())),
            const SizedBox(width: 10),
            Expanded(
              child: PrimaryButton(
                label: '💾 Lưu',
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  context.read<ProfileViewModel>().editHobby(hobby, ctrl.text);
                },
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _birthCtrl.dispose();
    _hobbyCtrl.dispose();
    super.dispose();
  }

  void _showLogoutSheet(BuildContext context, AuthViewModel authVM) {
    final t       = AppTheme.read(context);
    final rootNav = Navigator.of(context, rootNavigator: true);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetCtx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Đăng xuất? 👋',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: t.primaryDark)),
          const SizedBox(height: 6),
          Text(
            'Tủ đồ, sở thích và lịch sử vẫn được lưu lại. '
                'Bạn có thể đăng nhập lại bất cứ lúc nào.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: t.textMuted, height: 1.55),
          ),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: SecondaryButton(
              label: 'Ở lại',
              onTap: () => Navigator.of(sheetCtx).pop(),
            )),
            const SizedBox(width: 10),
            Expanded(child: DangerButton(
              label: '🚪 Xác nhận',
              onTap: () async {
                rootNav.pop();
                context.read<HealthViewModel>().reset();
                await authVM.logout();
              },
            )),
          ]),
        ]),
      ),
    );
  }

  // Giả sử đây là hàm được gọi khi bấm nút "Đổi Theme AI"
  void _onGenerateAiThemePressed(BuildContext context) async {
    // 1. Lấy ra các ViewModel y hệt như cách bạn gọi trong ProfileTab
    final profileVM = context.read<ProfileViewModel>();
    final session   = context.read<SessionService>();
    // final wardVM = context.read<WardrobeViewModel>(); // Nếu bạn cần số lượng quần áo

    // 2. Lấy dữ liệu từ ViewModel của bạn
    final user = profileVM.user;
    final hobbies = session.userPreference?.hobbies ?? [];
    // final totalClothes = wardVM.wardrobe.totalItems;

    // 3. Khởi tạo ThemeContext và truyền data vào
    final themeCtx = ThemeContext(
      hourOfDay: DateTime.now().hour,

      // ĐÂY LÀ CHỖ DATA TỪ PROFILE CỦA BẠN ĐƯỢC ĐƯA VÀO:
      userName: user.name,                  // Lấy từ UserModel
      userAge: user.age,                    // Lấy từ UserModel
      userHobbies: hobbies,                 // Lấy từ mảng hobbies trong Session
      // wardrobeItemCount: totalClothes,
    );

    // 4. Gửi lên Cloudflare Worker
    final newTheme = await GemmaThemeService.instance.generateTheme(themeCtx);

    if (newTheme != null) {
      // Áp dụng theme mới vào app của bạn
      // context.read<DynamicThemeProvider>().setTheme(newTheme);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm     = context.watch<ProfileViewModel>();
    final wardVM = context.watch<WardrobeViewModel>();
    final user   = vm.user;
    final authVM = context.read<AuthViewModel>();
    final session = context.watch<SessionService>();
    final hobbies = session.userPreference?.hobbies ?? [];
    final t      = AppTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: '🌸 Thông tin cá nhân',
          subtitle: 'Hồ sơ cá nhân giúp AI hiểu phong cách sống và đưa ra gợi ý phù hợp hơn.',
        ),

        // ── Avatar Card ───────────────────────────────────────────────────
        AppCard(
          gradient: LinearGradient(
              colors: [t.primaryLight.withOpacity(0.18), t.primary.withOpacity(0.09)]),
          child: Column(children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(gradient: t.primaryGradient, shape: BoxShape.circle),
              child: Center(
                child: Text(user.initial,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w900, fontSize: 28)),
              ),
            ),
            const SizedBox(height: 12),
            Text(user.name,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: t.primaryDark)),
            const SizedBox(height: 2),
            Text(user.email,
                style: TextStyle(fontSize: 12, color: t.textSecondary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 3),
            Text('✨ Thành viên StyleAI',
                style: TextStyle(fontSize: 11.5, color: t.textMuted)),
            const SizedBox(height: 14),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _statMini(context, '${wardVM.wardrobe.totalItems}', '👗 Trang phục'),
              const SizedBox(width: 40),
              _statMini(context, '${hobbies.length}', '💖 Sở thích'),
            ]),
          ]),
        ),

        // ── Basic Info Card ───────────────────────────────────────────────
        AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Thông tin cơ bản',
                    style: TextStyle(fontWeight: FontWeight.w800, color: t.primaryDark, fontSize: 14.5)),
                Text('Tên và ngày sinh dùng để cá nhân hoá trải nghiệm',
                    style: TextStyle(fontSize: 11.5, color: t.textSecondary)),
              ]),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                if (vm.isEditing) {
                  context.read<ProfileViewModel>().cancelEditing();
                } else {
                  _nameCtrl.text  = user.name;
                  _emailCtrl.text = user.email;
                  _birthCtrl.text = user.birthYear > 0 ? user.birthYear.toString() : '';
                  context.read<ProfileViewModel>().startEditing();
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: t.borderColor, width: 2),
                ),
                child: Text(
                  vm.isEditing ? 'Huỷ' : '✏️ Sửa',
                  style: TextStyle(fontSize: 12.5, color: t.primary, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 10),

          if (vm.isEditing) ...[
            _editField(context, '👤 Họ và tên', _nameCtrl),
            _editField(context, '📧 Email', _emailCtrl),
            _editField(context, '🎂 Năm sinh', _birthCtrl, keyboardType: TextInputType.number),
            const SizedBox(height: 4),
            if (vm.errorMessage != null) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  const Text('⚠️ ', style: TextStyle(fontSize: 13)),
                  Expanded(
                    child: Text(
                      vm.errorMessage!,
                      style: const TextStyle(
                        fontSize: 12.5, color: Color(0xFFD32F2F), fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ]),
              ),
            ],
            PrimaryButton(
              label: vm.saving ? '💾 Đang lưu...' : '💾 Lưu thay đổi',
              onTap: vm.saving
                  ? null
                  : () => context.read<ProfileViewModel>().saveProfile(
                name: _nameCtrl.text,
                email: _emailCtrl.text,
                birthYear: int.tryParse(_birthCtrl.text) ?? user.birthYear,
              ),
            ),
          ] else ...[
            for (final row in [
              ['Họ và tên', user.name],
              ['Email', user.email],
              ['Tuổi', '${user.age} tuổi'],
              ['Năm sinh', user.birthYear > 0 ? user.birthYear.toString() : '—'],
            ])
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: t.borderColor.withOpacity(0.4))),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(row[0],
                      style: TextStyle(fontSize: 12.5, color: t.textSecondary, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      row[1],
                      textAlign: TextAlign.end,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13.5, color: t.primaryDark, fontWeight: FontWeight.w800),
                    ),
                  ),
                ]),
              ),
          ],
        ])),

        // ── Hobbies Card ──────────────────────────────────────────────────
        AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('💖 Sở thích cá nhân',
                    style: TextStyle(fontWeight: FontWeight.w800, color: t.primaryDark, fontSize: 14.5)),
                Text('AI dùng sở thích để điều chỉnh phong cách gợi ý',
                    style: TextStyle(fontSize: 11.5, color: t.textSecondary)),
              ]),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => context.read<ProfileViewModel>().setAddingHobby(true),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: t.borderColor, width: 2),
                ),
                child: Text('+ Thêm',
                    style: TextStyle(fontSize: 12.5, color: t.primary, fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
          const SizedBox(height: 10),

          if (hobbies.isEmpty)
            Text('Chưa có sở thích nào. Hãy thêm!',
                style: TextStyle(fontSize: 12.5, color: t.textSecondary))
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: hobbies.map((h) => _HobbyChip(
                label: h,
                onEdit: () => _showEditHobbyDialog(context, h),
                onRemove: () => context.read<ProfileViewModel>().removeHobby(h),
              )).toList(),
            ),

          if (vm.isAddingHobby) ...[
            const SizedBox(height: 10),
            const FeatureHint('ℹ️ Nhấn ✏️ để sửa, nhấn ✕ để xoá sở thích.'),
            TextField(
              controller: _hobbyCtrl,
              decoration: InputDecoration(
                hintText: 'Nhập sở thích...',
                hintStyle: TextStyle(color: t.textMuted.withOpacity(0.5)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.9),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: t.borderColor, width: 1.5)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: t.borderColor, width: 1.5)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: t.primaryLight, width: 1.5)),
              ),
              style: TextStyle(fontSize: 13.5, color: t.primaryDark),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: PrimaryButton(
                label: 'Thêm',
                onTap: () {
                  context.read<ProfileViewModel>().addHobby(_hobbyCtrl.text);
                  _hobbyCtrl.clear();
                },
              )),
              const SizedBox(width: 8),
              Expanded(child: SecondaryButton(
                label: 'Huỷ',
                onTap: () {
                  context.read<ProfileViewModel>().setAddingHobby(false);
                  _hobbyCtrl.clear();
                },
              )),
            ]),
          ],
        ])),

        // ── Logout ────────────────────────────────────────────────────────
        GestureDetector(
          onTap: () => _showLogoutSheet(context, authVM),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.85),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF5A0B0), width: 2),
            ),
            child: const Center(
              child: Text('🚪 Đăng xuất',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Color(0xFFD4607A))),
            ),
          ),
        ),
        Text('Dữ liệu tủ đồ sẽ được lưu lại khi đăng xuất',
            style: TextStyle(fontSize: 11.5, color: t.textSecondary)),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _editField(BuildContext context, String label, TextEditingController ctrl,
      {TextInputType? keyboardType}) {
    final t = AppTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: TextStyle(fontSize: 12.5, color: t.textMuted, fontWeight: FontWeight.w700)),
        const SizedBox(height: 5),
        TextField(
          controller: ctrl,
          keyboardType: keyboardType,
          style: TextStyle(fontSize: 13.5, color: t.primaryDark),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withOpacity(0.9),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: t.borderColor, width: 1.5)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: t.borderColor, width: 1.5)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: t.primaryLight, width: 1.5)),
          ),
        ),
      ]),
    );
  }

  Widget _statMini(BuildContext context, String value, String label) {
    final t = AppTheme.of(context);
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: t.primaryDark, letterSpacing: -0.5),
        ),
        const SizedBox(height: 2),
        Text(
          label.toUpperCase(),
          style: TextStyle(fontSize: 10, color: t.textSecondary, fontWeight: FontWeight.w800, letterSpacing: 0.8),
        ),
      ],
    );
  }
}

// ── Hobby chip với nút sửa và xoá ────────────────────────────────────────────
class _HobbyChip extends StatelessWidget {
  final String label;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  const _HobbyChip({required this.label, required this.onEdit, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: t.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: t.borderColor.withOpacity(0.6), width: 1.2),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, color: t.primaryDark, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onEdit,
            child: Icon(
              Icons.edit_rounded,
              size: 13,
              color: t.textSecondary,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(
              Icons.close_rounded,
              size: 14,
              color: Color(0xFFD4607A),
            ),
          ),
        ],
      ),
    );
  }
}