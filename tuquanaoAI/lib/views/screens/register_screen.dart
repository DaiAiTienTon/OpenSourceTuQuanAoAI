import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../repositories/app_repository.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../widgets/common_widgets.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  int _step = 1;
  String _name = '', _email = '', _password = '', _confirmPassword = '', _dob = '';
  DateTime? _selectedDate;
  List<String> _hobbies = [];
  bool _done = false;

  void _toggleHobby(String h) {
    setState(() {
      if (_hobbies.contains(h)) {
        _hobbies.remove(h);
      } else {
        _hobbies.add(h);
      }
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime(now.year - 20),
      firstDate: DateTime(1920),
      lastDate: DateTime(now.year - 5),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dob =
        '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _doRegister() async {
    final success = await context.read<AuthViewModel>().register(
      name: _name,
      email: _email,
      password: _password,
      dob: _dob,
      hobbies: _hobbies,
    );
    if (success && mounted) setState(() => _done = true);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AuthViewModel>();
    final t = AppTheme.of(context);
    if (_done) return _buildSuccessScreen(t);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: t.appGradient),
        child: SafeArea(
          bottom: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height
                  - MediaQuery.of(context).padding.top,
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + MediaQuery.of(context).padding.bottom),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  Text(
                    'StyleAI',
                    style: TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w800,
                      color: t.primaryDark,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.92),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: t.borderColor.withOpacity(0.5)),
                      boxShadow: [
                        BoxShadow(
                          color: t.primary.withOpacity(0.08),
                          blurRadius: 32,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildProgressBar(t),
                        const SizedBox(height: 22),
                        if (_step == 1) _buildStep1(t),
                        if (_step == 2) _buildStep2(t),
                        if (_step == 3) _buildStep3(vm, t),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Đã có tài khoản? ',
                        style: TextStyle(fontSize: 13, color: t.textMuted),
                      ),
                      GestureDetector(
                        onTap: () => context.read<AuthViewModel>().goToLogin(),
                        child: Text(
                          'Đăng nhập',
                          style: TextStyle(
                            color: t.primary,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar(AppTheme t) {
    return Row(
      children: List.generate(
        3,
        (i) => Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
            height: 5,
            decoration: BoxDecoration(
              gradient: _step > i ? t.primaryGradient : null,
              color: _step <= i ? t.borderColor.withOpacity(0.4) : null,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep1(AppTheme t) {
    // Tính real-time match để hiện icon ✓/✗ ở field xác nhận
    final passwordsMatch =
        _confirmPassword.isNotEmpty && _confirmPassword == _password;
    final passwordsMismatch =
        _confirmPassword.isNotEmpty && _confirmPassword != _password;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tạo tài khoản mới ✨',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: t.primaryDark,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Bước 1/3 · Nhập thông tin đăng nhập',
          style: TextStyle(
            fontSize: 12,
            color: t.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        const FeatureHint(
            'ℹ️ Tài khoản giúp StyleAI lưu trữ tủ đồ và lịch sử gợi ý trên mọi thiết bị.'),
        const SizedBox(height: 8),

        // ── Họ và tên ──────────────────────────────────────────────────────
        Text(
          '👤 Họ và tên',
          style: TextStyle(
            fontSize: 12,
            color: t.textSecondary,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 6),
        AppTextField(
          placeholder: 'Nguyễn Văn A',
          value: _name,
          onChanged: (v) => setState(() => _name = v),
        ),
        const SizedBox(height: 14),

        // ── Email ──────────────────────────────────────────────────────────
        Text(
          '📧 Email',
          style: TextStyle(
            fontSize: 12,
            color: t.textSecondary,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 6),
        AppTextField(
          placeholder: 'your@email.com',
          value: _email,
          onChanged: (v) => setState(() => _email = v),
        ),
        const SizedBox(height: 14),

        // ── Mật khẩu ──────────────────────────────────────────────────────
        Text(
          '🔒 Mật khẩu',
          style: TextStyle(
            fontSize: 12,
            color: t.textSecondary,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 6),
        AppTextField(
          placeholder: 'Tối thiểu 6 ký tự',
          value: _password,
          onChanged: (v) => setState(() => _password = v),
          obscureText: true,
        ),
        const SizedBox(height: 14),

        // ── Xác nhận mật khẩu ─────────────────────────────────────────────
        Text(
          '🔒 Xác nhận mật khẩu',
          style: TextStyle(
            fontSize: 12,
            color: t.textSecondary,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 6),
        AppTextField(
          placeholder: 'Nhập lại mật khẩu',
          value: _confirmPassword,
          onChanged: (v) => setState(() => _confirmPassword = v),
          obscureText: true,
          suffixIcon: _confirmPassword.isEmpty
              ? null
              : Icon(
                  passwordsMatch
                      ? Icons.check_circle_rounded
                      : Icons.cancel_rounded,
                  color: passwordsMatch
                      ? const Color(0xFF4CAF50)
                      : const Color(0xFFE53935),
                  size: 20,
                ),
        ),

        // ── Inline error khi mật khẩu không khớp ─────────────────────────
        if (passwordsMismatch) ...[
          const SizedBox(height: 6),
          const Row(
            children: [
              Text('⚠️ ', style: TextStyle(fontSize: 12)),
              Text(
                'Mật khẩu không khớp',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFFD32F2F),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],

        const SizedBox(height: 22),
        PrimaryButton(
          label: 'Tiếp theo →',
          onTap: () async {
            final nameError     = _validateName(_name);
            final emailError    = _validateEmail(_email);
            final passError     = _validatePassword(_password);
            final confirmError  = _validateConfirmPassword(_password, _confirmPassword);

            if (nameError != null || emailError != null ||
                passError != null || confirmError != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(
                    nameError ?? emailError ?? passError ?? confirmError!)),
              );
              return;
            }

            print('>>> Calling checkEmailExists with: ${_email.trim()}');
            bool emailExists = false;
            try {
              emailExists = await context
                  .read<AuthViewModel>()
                  .checkEmailExists(_email.trim());
              print('>>> Result: $emailExists');
            } catch (e, stack) {
              print('>>> ERROR: ${e.runtimeType}: $e');
              print('>>> Stack: $stack');
            }
            if (!mounted) return;
            if (emailExists) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Email đã được sử dụng')),
              );
              return;
            }

            setState(() => _step = 2);
          },
        ),
      ],
    );
  }

  Widget _buildStep2(AppTheme t) {
    final hasDate = _selectedDate != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Thông tin cá nhân 🌸',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: t.primaryDark,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Bước 2/3 · Giúp AI hiểu bạn hơn',
          style: TextStyle(
            fontSize: 12,
            color: t.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        const FeatureHint(
            'ℹ️ Ngày sinh giúp AI tính tuổi và điều chỉnh phong cách gợi ý phù hợp.'),
        const SizedBox(height: 8),
        Text(
          '🎂 Ngày sinh',
          style: TextStyle(
            fontSize: 12,
            color: t.textSecondary,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickDate,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: hasDate ? t.primary : t.borderColor.withOpacity(0.6),
                width: 1.2,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_month_rounded,
                  size: 18,
                  color: hasDate ? t.primary : t.textMuted.withOpacity(0.7),
                ),
                const SizedBox(width: 10),
                Text(
                  hasDate
                      ? '${_selectedDate!.day.toString().padLeft(2, '0')}/'
                        '${_selectedDate!.month.toString().padLeft(2, '0')}/'
                        '${_selectedDate!.year}'
                      : 'Chọn ngày sinh',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: hasDate ? t.primaryDark : t.textMuted.withOpacity(0.5),
                    fontWeight: hasDate ? FontWeight.w700 : FontWeight.normal,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: t.textMuted.withOpacity(0.5),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: SecondaryButton(
                label: '← Quay lại',
                onTap: () => setState(() => _step = 1),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: PrimaryButton(
                label: 'Tiếp theo →',
                onTap: () {
                  final dobError = _validateDob();
                  if (dobError != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(dobError)),
                    );
                    return;
                  }
                  setState(() => _step = 3);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStep3(AuthViewModel vm, AppTheme t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sở thích của bạn 💖',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: t.primaryDark,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Bước 3/3 · Chọn những gì bạn yêu thích',
          style: TextStyle(
            fontSize: 12,
            color: t.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        const FeatureHint(
            'ℹ️ Sở thích được dùng để cá nhân hoá gợi ý trang phục phù hợp với lối sống của bạn.'),
        const SizedBox(height: 8),
        Wrap(
          children: AppRepository.hobbySuggestions
              .map((h) => TagButton(
                  label: h,
                  active: _hobbies.contains(h),
                  onTap: () => _toggleHobby(h)))
              .toList(),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: SecondaryButton(
                label: '← Quay lại',
                onTap: () => setState(() => _step = 2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: PrimaryButton(
                label: vm.loading ? 'Đang tạo...' : '🎉 Hoàn tất',
                onTap: vm.loading ? null : _doRegister,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSuccessScreen(AppTheme t) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: t.appGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.92),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: t.borderColor.withOpacity(0.5)),
                  boxShadow: [
                    BoxShadow(
                      color: t.primary.withOpacity(0.08),
                      blurRadius: 32,
                      offset: const Offset(0, 10),
                    )
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🎉', style: TextStyle(fontSize: 54)),
                    const SizedBox(height: 14),
                    Text(
                      'Đăng ký thành công!',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: t.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Chào mừng ${_name.isNotEmpty ? _name : 'bạn'} đến với StyleAI 🌸\nHãy thêm tủ đồ để AI gợi ý chính xác hơn!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: t.textMuted,
                        height: 1.6,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 22),
                    PrimaryButton(
                      label: 'Đăng nhập ngay →',
                      onTap: () => context.read<AuthViewModel>().goToLogin(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Validators ─────────────────────────────────────────────────────────────

  String? _validateName(String name) {
    if (name.trim().isEmpty) return 'Vui lòng nhập họ tên';
    if (name.trim().length < 2) return 'Họ tên quá ngắn';
    return null;
  }

  String? _validateEmail(String email) {
    final regex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (email.isEmpty) return 'Email không được để trống';
    if (!regex.hasMatch(email)) return 'Email không hợp lệ';
    return null;
  }

  String? _validatePassword(String password) {
    if (password.isEmpty) return 'Mật khẩu không được để trống';
    if (password.length < 6) return 'Mật khẩu phải có ít nhất 6 ký tự';
    return null;
  }

  /// Kiểm tra mật khẩu xác nhận có khớp không
  String? _validateConfirmPassword(String password, String confirm) {
    if (confirm.isEmpty) return 'Vui lòng xác nhận mật khẩu';
    if (confirm != password) return 'Mật khẩu xác nhận không khớp';
    return null;
  }

  String? _validateDob() {
    if (_selectedDate == null) return 'Vui lòng chọn ngày sinh';

    final now = DateTime.now();
    if (_selectedDate!.isAfter(now)) return 'Ngày sinh không hợp lệ';

    final age = now.year -
        _selectedDate!.year -
        (now.isBefore(DateTime(
            now.year, _selectedDate!.month, _selectedDate!.day))
            ? 1
            : 0);

    if (age < 5) return 'Ngày sinh không hợp lệ';
    if (age > 100) return 'Ngày sinh không hợp lệ';

    return null;
  }
}