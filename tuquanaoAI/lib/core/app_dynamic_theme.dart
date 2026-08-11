import 'dart:ui';
import 'package:flutter/material.dart';

// ── Danh sách palette ────────────────────────────────────────────────────────
enum ThemePalette {
  ocean,
  forest,
  sunset,
  warmOrange,
  darkBlue,
  lavender,
  mint,
  rose,
  goldenMorning,
  rainyEvening,
}

extension ThemePaletteExt on ThemePalette {
  AppDynamicTheme get theme => switch (this) {
    ThemePalette.ocean => const AppDynamicTheme(
      name: 'ocean',
      reason: 'Cool blue tones suited for daytime or cool weather',
      primary: Color(0xFF1A7FA8),
      primaryLight: Color(0xFF5BB3D0),
      primaryDark: Color(0xFF0D5273),
      textSecondary: Color(0xFF4A9BB5),
      textMuted: Color(0xFF7ABDD0),
      borderColor: Color(0xFFB8DDE8),
      gradientStart: Color(0xFFF0F9FC),
      gradientMid: Color(0xFFD6EEF5),
      gradientEnd: Color(0xFFEAF4FF),
    ),
    ThemePalette.forest => const AppDynamicTheme(
      name: 'forest',
      reason: 'Earthy green for morning freshness or cool weather',
      primary: Color(0xFF2E7D5E),
      primaryLight: Color(0xFF5AAF8A),
      primaryDark: Color(0xFF1A5440),
      textSecondary: Color(0xFF4A9476),
      textMuted: Color(0xFF7AB89F),
      borderColor: Color(0xFFB8DDD0),
      gradientStart: Color(0xFFF0FAF5),
      gradientMid: Color(0xFFD6EFE5),
      gradientEnd: Color(0xFFEAF5EE),
    ),
    ThemePalette.sunset => const AppDynamicTheme(
      name: 'sunset',
      reason: 'Warm orange-red tones for the evening',
      primary: Color(0xFFE8724A),
      primaryLight: Color(0xFFF4A07A),
      primaryDark: Color(0xFFA84B2A),
      textSecondary: Color(0xFFD4826A),
      textMuted: Color(0xFFE0A090),
      borderColor: Color(0xFFF5D0C0),
      gradientStart: Color(0xFFFFF8F5),
      gradientMid: Color(0xFFFDE8DC),
      gradientEnd: Color(0xFFFFF0E8),
    ),
    ThemePalette.warmOrange => const AppDynamicTheme(
      name: 'warm_orange',
      reason: 'Energetic orange for active states or high heart rate',
      primary: Color(0xFFE8920A),
      primaryLight: Color(0xFFF4B84A),
      primaryDark: Color(0xFFA86200),
      textSecondary: Color(0xFFD4A030),
      textMuted: Color(0xFFE0BC70),
      borderColor: Color(0xFFF5DFB0),
      gradientStart: Color(0xFFFFFAF0),
      gradientMid: Color(0xFFFDF0D0),
      gradientEnd: Color(0xFFFFF5E0),
    ),
    ThemePalette.darkBlue => const AppDynamicTheme(
      name: 'dark_blue',
      reason: 'Deep blue for nighttime or low-light conditions',
      primary: Color(0xFF3A5FA8),
      primaryLight: Color(0xFF6A8FD0),
      primaryDark: Color(0xFF1A3D73),
      textSecondary: Color(0xFF5A7AB5),
      textMuted: Color(0xFF8AAAD0),
      borderColor: Color(0xFFC0D0E8),
      gradientStart: Color(0xFFF0F4FC),
      gradientMid: Color(0xFFD8E4F5),
      gradientEnd: Color(0xFFEAEEFF),
    ),
    ThemePalette.lavender => const AppDynamicTheme(
      name: 'lavender',
      reason: 'Soft purple for relaxed or low-activity states',
      primary: Color(0xFF8A5FD0),
      primaryLight: Color(0xFFB48FE8),
      primaryDark: Color(0xFF5A3A98),
      textSecondary: Color(0xFFA070C8),
      textMuted: Color(0xFFC0A0E0),
      borderColor: Color(0xFFE0D0F5),
      gradientStart: Color(0xFFF8F5FF),
      gradientMid: Color(0xFFEEE0FF),
      gradientEnd: Color(0xFFF5F0FF),
    ),
    ThemePalette.mint => const AppDynamicTheme(
      name: 'mint',
      reason: 'Fresh mint for morning energy or cool temperature',
      primary: Color(0xFF2ABFA0),
      primaryLight: Color(0xFF60D8C0),
      primaryDark: Color(0xFF1A8070),
      textSecondary: Color(0xFF40C0A8),
      textMuted: Color(0xFF80D8C8),
      borderColor: Color(0xFFB8EDE5),
      gradientStart: Color(0xFFF0FEFA),
      gradientMid: Color(0xFFD5F5EE),
      gradientEnd: Color(0xFFEAFAF6),
    ),
    ThemePalette.rose => AppDynamicTheme.defaultTheme,
    ThemePalette.goldenMorning => const AppDynamicTheme(
      name: 'golden_morning',
      reason: 'Golden yellow tones for early morning hours',
      primary: Color(0xFFD4A820),
      primaryLight: Color(0xFFE8CC60),
      primaryDark: Color(0xFF987800),
      textSecondary: Color(0xFFC0A040),
      textMuted: Color(0xFFD8C080),
      borderColor: Color(0xFFF0E0A0),
      gradientStart: Color(0xFFFFFDF0),
      gradientMid: Color(0xFFFDF5D0),
      gradientEnd: Color(0xFFFFF8E0),
    ),
    ThemePalette.rainyEvening => const AppDynamicTheme(
      name: 'rainy_evening',
      reason: 'Muted grey-blue for rainy or overcast weather',
      primary: Color(0xFF607890),
      primaryLight: Color(0xFF90A8B8),
      primaryDark: Color(0xFF405870),
      textSecondary: Color(0xFF7890A0),
      textMuted: Color(0xFFA0B8C8),
      borderColor: Color(0xFFD0DDE5),
      gradientStart: Color(0xFFF5F8FA),
      gradientMid: Color(0xFFE5ECF0),
      gradientEnd: Color(0xFFEEF2F5),
    ),
  };

  /// Parse tên từ model output → enum
  /// Hỗ trợ: "mint", "warm_orange", "warmorange", "Warm Orange", v.v.
  static ThemePalette? fromModelOutput(String raw) {
    final normalized = raw
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[\s\-]+'), '_')
        .replaceAll(RegExp(r'[^a-z_]'), '');

    // So khớp tên enum (camelCase → snake)
    final enumMap = {
      'ocean': ThemePalette.ocean,
      'forest': ThemePalette.forest,
      'sunset': ThemePalette.sunset,
      'warm_orange': ThemePalette.warmOrange,
      'warmorange': ThemePalette.warmOrange,
      'dark_blue': ThemePalette.darkBlue,
      'darkblue': ThemePalette.darkBlue,
      'lavender': ThemePalette.lavender,
      'mint': ThemePalette.mint,
      'rose': ThemePalette.rose,
      'golden_morning': ThemePalette.goldenMorning,
      'goldenmorning': ThemePalette.goldenMorning,
      'rainy_evening': ThemePalette.rainyEvening,
      'rainyevening': ThemePalette.rainyEvening,
    };

    return enumMap[normalized];
  }
}

// ── Model bộ màu động ────────────────────────────────────────────────────────

/// Một bộ màu động được chọn bởi Gemma on-device.
class AppDynamicTheme {
  final Color primary;
  final Color primaryLight;
  final Color primaryDark;
  final Color textSecondary;
  final Color textMuted;
  final Color borderColor;
  final Color gradientStart;
  final Color gradientMid;
  final Color gradientEnd;

  /// Tên palette (vd: "ocean", "sunset", "golden_morning")
  final String name;

  /// Lý do model chọn bộ màu này (dùng cho debug / thesis)
  final String reason;

  const AppDynamicTheme({
    required this.primary,
    required this.primaryLight,
    required this.primaryDark,
    required this.textSecondary,
    required this.textMuted,
    required this.borderColor,
    required this.gradientStart,
    required this.gradientMid,
    required this.gradientEnd,
    required this.name,
    required this.reason,
  });

  // ── Gradient helpers ─────────────────────────────────────────────────────
  LinearGradient get appGradient => LinearGradient(
    colors: [gradientStart, gradientMid, gradientEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  LinearGradient get primaryGradient => LinearGradient(
    colors: [primaryLight, primary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Fallback: bộ màu mặc định (rose/pink) ───────────────────────────────
  static const AppDynamicTheme defaultTheme = AppDynamicTheme(
    primary: Color(0xFFD48FB0),
    primaryLight: Color(0xFFF7A8C4),
    primaryDark: Color(0xFF8A3060),
    textSecondary: Color(0xFFC4849A),
    textMuted: Color(0xFFB07A92),
    borderColor: Color(0xFFF0C4D4),
    gradientStart: Color(0xFFFFF5F8),
    gradientMid: Color(0xFFFDE8F0),
    gradientEnd: Color(0xFFF5EEFF),
    name: 'rose',
    reason: 'Bộ màu mặc định của ứng dụng',
  );

  // ── Serialization (dùng để cache vào SharedPreferences) ─────────────────
  factory AppDynamicTheme.fromJson(Map<String, dynamic> json) {
    // Nếu có trường 'palette_name' → lookup từ ThemePaletteExt
    final paletteName = json['palette_name'] as String?;
    if (paletteName != null && paletteName.isNotEmpty) {
      final palette = ThemePaletteExt.fromModelOutput(paletteName);
      if (palette != null) return palette.theme;
    }

    // Fallback: đọc từng trường màu hex (tương thích cache cũ)
    Color hex(String key, Color fallback) {
      try {
        final raw = (json[key] as String?)?.replaceAll('#', '') ?? '';
        if (raw.length == 6) {
          return Color(int.parse('FF$raw', radix: 16));
        }
      } catch (_) {}
      return fallback;
    }

    return AppDynamicTheme(
      primary: hex('primary', defaultTheme.primary),
      primaryLight: hex('primary_light', defaultTheme.primaryLight),
      primaryDark: hex('primary_dark', defaultTheme.primaryDark),
      textSecondary: hex('text_secondary', defaultTheme.textSecondary),
      textMuted: hex('text_muted', defaultTheme.textMuted),
      borderColor: hex('border_color', defaultTheme.borderColor),
      gradientStart: hex('gradient_start', defaultTheme.gradientStart),
      gradientMid: hex('gradient_mid', defaultTheme.gradientMid),
      gradientEnd: hex('gradient_end', defaultTheme.gradientEnd),
      name: (json['name'] as String?) ?? 'rose',
      reason: (json['reason'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'palette_name': name, // dùng để restore nhanh qua ThemePaletteExt
    'name': name,
    'reason': reason,
    'primary': _colorToHex(primary),
    'primary_light': _colorToHex(primaryLight),
    'primary_dark': _colorToHex(primaryDark),
    'text_secondary': _colorToHex(textSecondary),
    'text_muted': _colorToHex(textMuted),
    'border_color': _colorToHex(borderColor),
    'gradient_start': _colorToHex(gradientStart),
    'gradient_mid': _colorToHex(gradientMid),
    'gradient_end': _colorToHex(gradientEnd),
  };

  static String _colorToHex(Color c) =>
      '#${c.value.toRadixString(16).substring(2).toUpperCase()}';

  @override
  String toString() => 'AppDynamicTheme($name)';
}