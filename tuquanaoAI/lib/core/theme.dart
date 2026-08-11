import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tuquanapai/service/gemma_theme_service.dart';
import 'package:tuquanapai/service/theme_service.dart';

class AppColors {
  static const primary       = Color(0xFFD48FB0);
  static const primaryLight  = Color(0xFFF7A8C4);
  static const primaryDark   = Color(0xFF8A3060);
  static const textSecondary = Color(0xFFC4849A);
  static const textMuted     = Color(0xFFB07A92);
  static const borderColor   = Color(0xFFF0C4D4);
  static const error         = Color(0xFFE07070);

  // Đưa gradients vào trong AppColors để gom nhóm gọn gàng
  static const appGradient = LinearGradient(
    colors: [Color(0xFFFFF5F8), Color(0xFFFDE8F0), Color(0xFFF5EEFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const primaryGradient = LinearGradient(
    colors: [Color(0xFFF7A8C4), Color(0xFFD48FB0)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppTheme {
  final Color primary;
  final Color primaryLight;
  final Color primaryDark;
  final Color textSecondary;
  final Color textMuted;
  final Color borderColor;

  final Color gradientStart;
  final Color gradientMid;
  final Color gradientEnd;

  final LinearGradient appGradient;
  final LinearGradient primaryGradient;

  AppTheme._({
    required this.primary,
    required this.primaryLight,
    required this.primaryDark,
    required this.textSecondary,
    required this.textMuted,
    required this.borderColor,
    required this.gradientStart,
    required this.gradientMid,
    required this.gradientEnd,
    required this.appGradient,
    required this.primaryGradient,
  });

  factory AppTheme.of(BuildContext context) {
    try {
      final svc = context.watch<ThemeService>();
      final t = svc.current;
      return AppTheme._(
        primary: t.primary,
        primaryLight: t.primaryLight,
        primaryDark: t.primaryDark,
        textSecondary: t.textSecondary,
        textMuted: t.textMuted,
        borderColor: t.borderColor,

        gradientStart: t.gradientStart,
        gradientMid: t.gradientMid,
        gradientEnd: t.gradientEnd,

        appGradient: t.appGradient,
        primaryGradient: t.primaryGradient,
      );
    } catch (_) {
      return AppTheme._fallback();
    }
  }

  factory AppTheme.read(BuildContext context) {
    try {
      final svc = context.read<ThemeService>();
      final t = svc.current;
      return AppTheme._(
        primary: t.primary,
        primaryLight: t.primaryLight,
        primaryDark: t.primaryDark,
        textSecondary: t.textSecondary,
        textMuted: t.textMuted,
        borderColor: t.borderColor,

        gradientStart: t.gradientStart,
        gradientMid: t.gradientMid,
        gradientEnd: t.gradientEnd,

        appGradient: t.appGradient,
        primaryGradient: t.primaryGradient,
      );
    } catch (_) {
      return AppTheme._fallback();
    }
  }

  /// Gọi qua AppColors để phân biệt rõ ràng với instance variable
  factory AppTheme._fallback() => AppTheme._(
    primary:         AppColors.primary,
    primaryLight:    AppColors.primaryLight,
    primaryDark:     AppColors.primaryDark,
    textSecondary:   AppColors.textSecondary,
    textMuted:       AppColors.textMuted,
    borderColor:     AppColors.borderColor,
    gradientStart:   AppColors.primary,
    gradientMid:     AppColors.primaryLight,
    gradientEnd:     AppColors.primaryDark,
    appGradient:     AppColors.appGradient,     // Sửa ở đây
    primaryGradient: AppColors.primaryGradient, // Sửa ở đây
  );
}

const kNotesMaxLength = 500;