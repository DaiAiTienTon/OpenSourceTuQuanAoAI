import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tuquanapai/core/app_dynamic_theme.dart';
import 'package:tuquanapai/service/gemma_theme_service.dart';

/// Quản lý vòng đời của dynamic theme:
/// - Lưu/đọc theme đã cache vào SharedPreferences
/// - Quyết định khi nào cần gọi Gemma (throttle 30 phút)
/// - Cung cấp theme hiện tại cho toàn bộ widget tree qua Provider
class ThemeService extends ChangeNotifier {
  static const _cacheKey = 'dynamic_theme_v1';
  static const _cacheTimeKey = 'dynamic_theme_time_v1';
  static const _throttleMinutes = 1; // Không gọi Gemma quá 1 lần / 30 phút

  AppDynamicTheme _current = AppDynamicTheme.defaultTheme;
  bool _isGenerating = false;
  DateTime? _lastGenerated;

  AppDynamicTheme get current => _current;
  bool get isGenerating => _isGenerating;
  DateTime? get lastGenerated => _lastGenerated;

  // ── Khởi tạo: đọc cache ──────────────────────────────────────────────
  Future<void> init() async {
    await _loadFromCache();
  }

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_cacheKey);
      final timeStr = prefs.getString(_cacheTimeKey);

      if (json != null && json.isNotEmpty) {
        _current = AppDynamicTheme.fromJson(
          jsonDecode(json) as Map<String, dynamic>,
        );
        debugPrint('[ThemeService] Đọc cache: ${_current.name}');
      }
      if (timeStr != null) {
        _lastGenerated = DateTime.tryParse(timeStr);
      }
    } catch (e) {
      debugPrint('[ThemeService] Lỗi đọc cache: $e');
    }
    notifyListeners();
  }

  Future<void> _saveToCache(AppDynamicTheme theme) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(theme.toJson()));
      await prefs.setString(_cacheTimeKey, DateTime.now().toIso8601String());
    } catch (e) {
      debugPrint('[ThemeService] Lỗi lưu cache: $e');
    }
  }

  // ── Sinh theme mới ────────────────────────────────────────────────────
  /// Gọi hàm này mỗi khi dữ liệu context thay đổi đáng kể
  /// (weather update, health save, chuyển giờ trong ngày).
  ///
  /// [force] = true → bỏ qua throttle (ví dụ: user nhấn nút refresh thủ công)
  Future<void> generateTheme(
      ThemeContext ctx, {
        bool force = false,
      }) async {
    // Throttle: không gọi Gemma nếu vừa gọi trong [_throttleMinutes] phút
    if (!force && _lastGenerated != null) {
      final diff = DateTime.now().difference(_lastGenerated!);
      if (diff.inMinutes < _throttleMinutes) {
        debugPrint(
          '[ThemeService] Throttled: ${_throttleMinutes - diff.inMinutes} phút còn lại',
        );
        return;
      }
    }

    if (_isGenerating) return;
    _isGenerating = true;
    notifyListeners();

    try {
      final gemma = GemmaThemeService.instance;

      // Khởi tạo Gemma nếu chưa sẵn sàng
      if (!gemma.isReady) {
        await gemma.initialize();
      }

      final newTheme = await gemma.generateTheme(ctx);
      if (newTheme != null) {
        _current = newTheme;
        _lastGenerated = DateTime.now();
        await _saveToCache(newTheme);
        debugPrint('[ThemeService] ✅ Theme mới: ${newTheme.name}');
      } else {
        debugPrint('[ThemeService] Gemma trả về null → giữ theme hiện tại');
      }
    } catch (e) {
      debugPrint('[ThemeService] ❌ generateTheme lỗi: $e');
    } finally {
      _isGenerating = false;
      notifyListeners();
    }
  }

  // ── Reset về mặc định ─────────────────────────────────────────────────
  Future<void> resetToDefault() async {
    _current = AppDynamicTheme.defaultTheme;
    _lastGenerated = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
    await prefs.remove(_cacheTimeKey);
    notifyListeners();
  }
}