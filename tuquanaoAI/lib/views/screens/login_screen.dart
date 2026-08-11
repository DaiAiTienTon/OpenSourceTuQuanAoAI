import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../widgets/common_widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String _email = '';
  String _pw = '';
  // Lưu lỗi client-side riêng để không lẫn với lỗi server từ vm.error
  String _clientError = '';

  @override
  void initState() {
    super.initState();
    _loadSavedEmail();
  }

  Future<void> _loadSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('last_email') ?? '';
    if (saved.isNotEmpty && mounted) {
      setState(() => _email = saved);
    }
  }

  // BUG FIX TC02-04, TC02-05, TC02-06: validate trước khi gọi API
  String? _validate() {
    if (_email.trim().isEmpty) return 'Vui lòng nhập email';

    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(_email.trim())) return 'Email không hợp lệ';

    if (_pw.isEmpty) return 'Vui lòng nhập mật khẩu';

    return null;
  }

  void _onLoginTap() {
    // Xóa lỗi server cũ khi user thử lại
    setState(() => _clientError = '');

    final error = _validate();
    if (error != null) {
      setState(() => _clientError = error);
      return; // Không gọi API nếu validate thất bại
    }

    context.read<AuthViewModel>().login(_email.trim(), _pw);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AuthViewModel>();
    final t = AppTheme.of(context);

    // Hiển thị lỗi client trước, nếu không có thì hiển thị lỗi server
    final displayError = _clientError.isNotEmpty ? _clientError : vm.error;

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
                  const SizedBox(height: 50),
                  Text(
                    'StyleAI',
                    style: TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.w800,
                      color: t.primaryDark,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'PHONG CÁCH · SỨC KHOẺ · PHONG CÁCH SỐNG',
                    style: TextStyle(
                      fontSize: 10,
                      color: t.textSecondary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.5,
                    ),
                  ),
                  const SizedBox(height: 40),
                  Container(
                    padding: const EdgeInsets.all(24),
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
                        Text(
                          'Chào mừng trở lại 🌸',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: t.primaryDark,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Đăng nhập để tiếp tục hành trình phong cách của bạn',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: t.textSecondary,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 24),
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
                          onChanged: (v) => setState(() {
                            _email = v;
                            _clientError = ''; // xóa lỗi khi user đang nhập
                          }),
                        ),
                        const SizedBox(height: 16),
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
                          placeholder: '••••••••',
                          value: _pw,
                          onChanged: (v) => setState(() {
                            _pw = v;
                            _clientError = ''; // xóa lỗi khi user đang nhập
                          }),
                          obscureText: true,
                        ),
                        // Hiển thị lỗi (client hoặc server)
                        if (displayError.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFEEF2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFFCD0D6)),
                            ),
                            child: Row(
                              children: [
                                const Text('⚠️ ', style: TextStyle(fontSize: 13)),
                                Expanded(
                                  child: Text(
                                    displayError,
                                    style: const TextStyle(
                                      color: Color(0xFFD32F2F),
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 22),
                        PrimaryButton(
                          label: vm.loading ? 'Đang đăng nhập...' : '✨ Đăng nhập',
                          // BUG FIX: thay vì gọi API trực tiếp, đi qua _onLoginTap để validate trước
                          onTap: vm.loading ? null : _onLoginTap,
                        ),
                        const SizedBox(height: 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Chưa có tài khoản? ',
                              style: TextStyle(
                                  fontSize: 13, color: t.textMuted),
                            ),
                            GestureDetector(
                              onTap: () =>
                                  context.read<AuthViewModel>().goToRegister(),
                              child: Text(
                                'Đăng ký ngay',
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}