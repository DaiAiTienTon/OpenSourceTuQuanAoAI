// evaluation/lib/test_dataset_v2.dart
//
// ═══════════════════════════════════════════════════════════════════
// BENCHMARK DATASET v2 — Thiết kế Bottom-Up (4 tầng)
// ═══════════════════════════════════════════════════════════════════
//
// Mục tiêu: Cô lập từng biến, sau đó kết hợp dần để xác định
//           chính xác điểm thất bại của model.
//
// Cấu trúc 4 tầng:
//   L1 — Đơn biến    : Chỉ 1 biến active, còn lại null/default
//   L2 — Hai biến    : 2 biến tương tác, tín hiệu không mâu thuẫn
//   L3 — Ba biến     : 3 biến kết hợp, tín hiệu hợp lý
//   L4 — Edge/Phức   : Mâu thuẫn tín hiệu, ưu tiên, profile đầy đủ
//
// Ground truth logic (từ _buildPrompt()):
//   Priority 1: rain/storm                → rainy_evening
//   Priority 2: tempC >= 34               → warm_orange
//   Priority 3: hour 5-6                  → golden_morning
//   Priority 4: hour 7-11                 → mint
//   Priority 5: hour 12-16               → ocean
//   Priority 6: hour 17-19               → sunset
//   Priority 7: night + hr<65 + sleep>=7  → lavender
//   Priority 8: night (default)            → dark_blue
//
// Số lượng: 20 (L1) + 18 (L2) + 16 (L3) + 14 (L4) = 68 cases
// ═══════════════════════════════════════════════════════════════════

import 'package:tuquanapai/service/gemma_theme_service.dart';

class EvalCase {
  final String id;
  final ThemeContext context;
  final List<String> expectedPalettes;
  final String category;       // L1 / L2 / L3 / L4
  final String subCategory;    // biến đang được test
  final String description;
  final String primarySignal;  // biến quyết định palette (để phân tích lỗi)

  const EvalCase({
    required this.id,
    required this.context,
    required this.expectedPalettes,
    required this.category,
    required this.subCategory,
    required this.description,
    required this.primarySignal,
  });
}

class EvalDataset {
  static const List<EvalCase> cases = [

    // ════════════════════════════════════════════════════════════════
    // L1 — ĐƠN BIẾN (20 cases)
    // Mỗi case chỉ kích hoạt ĐÚNG 1 yếu tố quyết định
    // hourOfDay luôn phải có (required field) — chọn giờ trung tính
    // khi muốn test biến khác (vd: giờ buổi chiều cho test weather)
    // ════════════════════════════════════════════════════════════════

    // ── L1.TIME — Chỉ có giờ (5 mốc giờ chính) ─────────────────────

    EvalCase(
      id: 'L1_T01',
      context: ThemeContext(hourOfDay: 6), // Dawn boundary
      expectedPalettes: ['golden_morning'],
      category: 'L1',
      subCategory: 'time_dawn',
      description: '[L1] Chỉ giờ: bình minh (6h)',
      primarySignal: 'hour=6 → golden_morning',
    ),
    EvalCase(
      id: 'L1_T02',
      context: ThemeContext(hourOfDay: 9), // Morning
      expectedPalettes: ['mint'],
      category: 'L1',
      subCategory: 'time_morning',
      description: '[L1] Chỉ giờ: sáng (9h)',
      primarySignal: 'hour=9 → mint',
    ),
    EvalCase(
      id: 'L1_T03',
      context: ThemeContext(hourOfDay: 14), // Afternoon
      expectedPalettes: ['ocean'],
      category: 'L1',
      subCategory: 'time_afternoon',
      description: '[L1] Chỉ giờ: chiều (14h)',
      primarySignal: 'hour=14 → ocean',
    ),
    EvalCase(
      id: 'L1_T04',
      context: ThemeContext(hourOfDay: 18), // Evening
      expectedPalettes: ['sunset'],
      category: 'L1',
      subCategory: 'time_evening',
      description: '[L1] Chỉ giờ: tối sớm (18h)',
      primarySignal: 'hour=18 → sunset',
    ),
    EvalCase(
      id: 'L1_T05',
      context: ThemeContext(hourOfDay: 23), // Night default
      expectedPalettes: ['dark_blue'],
      category: 'L1',
      subCategory: 'time_night',
      description: '[L1] Chỉ giờ: đêm khuya (23h) — không có hr/sleep → dark_blue',
      primarySignal: 'hour=23, no hr/sleep → dark_blue',
    ),

    // ── L1.TIME — Boundary kiểm tra ranh giới giờ ───────────────────

    EvalCase(
      id: 'L1_T06',
      context: ThemeContext(hourOfDay: 5), // Dawn start
      expectedPalettes: ['golden_morning'],
      category: 'L1',
      subCategory: 'time_boundary',
      description: '[L1] Boundary: 5h — rìa golden_morning',
      primarySignal: 'hour=5 → golden_morning (boundary)',
    ),
    EvalCase(
      id: 'L1_T07',
      context: ThemeContext(hourOfDay: 7), // Morning start
      expectedPalettes: ['mint'],
      category: 'L1',
      subCategory: 'time_boundary',
      description: '[L1] Boundary: 7h — rìa mint',
      primarySignal: 'hour=7 → mint (boundary start)',
    ),
    EvalCase(
      id: 'L1_T08',
      context: ThemeContext(hourOfDay: 11), // Morning end
      expectedPalettes: ['mint'],
      category: 'L1',
      subCategory: 'time_boundary',
      description: '[L1] Boundary: 11h — rìa cuối mint',
      primarySignal: 'hour=11 → mint (boundary end)',
    ),
    EvalCase(
      id: 'L1_T09',
      context: ThemeContext(hourOfDay: 12), // Afternoon start
      expectedPalettes: ['ocean'],
      category: 'L1',
      subCategory: 'time_boundary',
      description: '[L1] Boundary: 12h — rìa ocean',
      primarySignal: 'hour=12 → ocean (boundary start)',
    ),
    EvalCase(
      id: 'L1_T10',
      context: ThemeContext(hourOfDay: 17), // Evening start
      expectedPalettes: ['sunset'],
      category: 'L1',
      subCategory: 'time_boundary',
      description: '[L1] Boundary: 17h — rìa sunset',
      primarySignal: 'hour=17 → sunset (boundary start)',
    ),

    // ── L1.WEATHER — Chỉ có thời tiết (giờ trung tính: 10h) ─────────

    EvalCase(
      id: 'L1_W01',
      context: ThemeContext(hourOfDay: 10, weatherCondition: 'rainy'),
      expectedPalettes: ['rainy_evening'],
      category: 'L1',
      subCategory: 'weather_rain',
      description: '[L1] Chỉ thời tiết: mưa (10h — giờ trung tính)',
      primarySignal: 'weather=rainy → rainy_evening (overrides morning)',
    ),
    EvalCase(
      id: 'L1_W02',
      context: ThemeContext(hourOfDay: 10, weatherCondition: 'stormy'),
      expectedPalettes: ['rainy_evening'],
      category: 'L1',
      subCategory: 'weather_storm',
      description: '[L1] Chỉ thời tiết: bão (10h)',
      primarySignal: 'weather=stormy → rainy_evening',
    ),
    EvalCase(
      id: 'L1_W03',
      context: ThemeContext(hourOfDay: 10, weatherCondition: 'cloudy'),
      expectedPalettes: ['mint', 'forest'],  // cloudy KHÔNG override → vẫn theo giờ
      category: 'L1',
      subCategory: 'weather_cloudy',
      description: '[L1] Chỉ thời tiết: âm u (10h) — KHÔNG override, theo giờ',
      primarySignal: 'weather=cloudy → không override → hour=10 → mint',
    ),
    EvalCase(
      id: 'L1_W04',
      context: ThemeContext(hourOfDay: 10, weatherCondition: 'sunny'),
      expectedPalettes: ['mint', 'ocean'],  // sunny KHÔNG override
      category: 'L1',
      subCategory: 'weather_sunny',
      description: '[L1] Chỉ thời tiết: nắng (10h) — KHÔNG override, theo giờ',
      primarySignal: 'weather=sunny → không override → hour=10 → mint',
    ),

    // ── L1.TEMP — Chỉ có nhiệt độ cao (giờ trung tính: 10h) ─────────

    EvalCase(
      id: 'L1_H01',
      context: ThemeContext(hourOfDay: 10, tempC: 34),
      expectedPalettes: ['warm_orange'],
      category: 'L1',
      subCategory: 'temp_hot_boundary',
      description: '[L1] Chỉ nhiệt độ: 34°C boundary (10h)',
      primarySignal: 'tempC=34 → warm_orange (boundary)',
    ),
    EvalCase(
      id: 'L1_H02',
      context: ThemeContext(hourOfDay: 10, tempC: 38),
      expectedPalettes: ['warm_orange'],
      category: 'L1',
      subCategory: 'temp_very_hot',
      description: '[L1] Chỉ nhiệt độ: 38°C rất nóng (10h)',
      primarySignal: 'tempC=38 → warm_orange',
    ),
    EvalCase(
      id: 'L1_H03',
      context: ThemeContext(hourOfDay: 10, tempC: 33),
      expectedPalettes: ['mint', 'ocean'],  // 33°C chưa trigger hot
      category: 'L1',
      subCategory: 'temp_below_hot',
      description: '[L1] Chỉ nhiệt độ: 33°C — DƯỚI ngưỡng, theo giờ',
      primarySignal: 'tempC=33 → không override → hour=10 → mint',
    ),

    // ── L1.HEALTH — Night + health signal đơn lẻ ────────────────────

    EvalCase(
      id: 'L1_N01',
      context: ThemeContext(hourOfDay: 22, heartRateBpm: 60, sleepHours: 8),
      expectedPalettes: ['lavender'],
      category: 'L1',
      subCategory: 'night_relax',
      description: '[L1] Đêm + hr<65 + sleep>=7 → lavender',
      primarySignal: 'night + hr=60 + sleep=8 → lavender',
    ),
    EvalCase(
      id: 'L1_N02',
      context: ThemeContext(hourOfDay: 22, heartRateBpm: 80),
      expectedPalettes: ['dark_blue'],
      category: 'L1',
      subCategory: 'night_default',
      description: '[L1] Đêm + hr cao → dark_blue (không thỏa relax)',
      primarySignal: 'night + hr=80 → dark_blue',
    ),
    EvalCase(
      id: 'L1_N03',
      context: ThemeContext(hourOfDay: 22, sleepHours: 5),
      expectedPalettes: ['dark_blue'],
      category: 'L1',
      subCategory: 'night_low_sleep',
      description: '[L1] Đêm + sleep<7 → dark_blue (không thỏa relax)',
      primarySignal: 'night + sleep=5 → dark_blue',
    ),

    // ════════════════════════════════════════════════════════════════
    // L2 — HAI BIẾN (18 cases)
    // 2 biến kết hợp, không mâu thuẫn với nhau
    // Test xem model có xử lý đúng ưu tiên khi có thêm context không
    // ════════════════════════════════════════════════════════════════

    // ── L2.TIME + TEMP (reinforcing) ─────────────────────────────────

    EvalCase(
      id: 'L2_TT01',
      context: ThemeContext(hourOfDay: 9, tempC: 22),  // Sáng + mát → mint
      expectedPalettes: ['mint', 'forest'],
      category: 'L2',
      subCategory: 'time+temp_reinforce',
      description: '[L2] Sáng (9h) + mát (22°C) — cùng hướng mint',
      primarySignal: 'hour=9 → mint | tempC=22 không override',
    ),
    EvalCase(
      id: 'L2_TT02',
      context: ThemeContext(hourOfDay: 13, tempC: 36), // Trưa + nóng → warm_orange override ocean
      expectedPalettes: ['warm_orange'],
      category: 'L2',
      subCategory: 'time+temp_override',
      description: '[L2] Trưa (13h) + nóng (36°C) — temp override time',
      primarySignal: 'tempC=36 → warm_orange (overrides ocean)',
    ),
    EvalCase(
      id: 'L2_TT03',
      context: ThemeContext(hourOfDay: 18, tempC: 24), // Tối + mát → sunset
      expectedPalettes: ['sunset', 'warm_orange'],
      category: 'L2',
      subCategory: 'time+temp_evening',
      description: '[L2] Tối (18h) + mát vừa (24°C) — không override',
      primarySignal: 'hour=18 → sunset | tempC=24 không override',
    ),
    EvalCase(
      id: 'L2_TT04',
      context: ThemeContext(hourOfDay: 8, tempC: 35),  // Sáng + cực nóng → warm_orange override mint
      expectedPalettes: ['warm_orange'],
      category: 'L2',
      subCategory: 'time+temp_hot_override',
      description: '[L2] Sáng (8h) + cực nóng (35°C) — temp override time',
      primarySignal: 'tempC=35 → warm_orange (overrides mint)',
    ),

    // ── L2.TIME + WEATHER ─────────────────────────────────────────────

    EvalCase(
      id: 'L2_TW01',
      context: ThemeContext(hourOfDay: 9, weatherCondition: 'rainy'), // Sáng + mưa → rainy override
      expectedPalettes: ['rainy_evening'],
      category: 'L2',
      subCategory: 'time+weather_rain_override',
      description: '[L2] Sáng (9h) + mưa — rain override morning',
      primarySignal: 'weather=rainy → rainy_evening (overrides mint)',
    ),
    EvalCase(
      id: 'L2_TW02',
      context: ThemeContext(hourOfDay: 18, weatherCondition: 'rainy'), // Tối + mưa → rainy override sunset
      expectedPalettes: ['rainy_evening'],
      category: 'L2',
      subCategory: 'time+weather_rain_override_evening',
      description: '[L2] Tối (18h) + mưa — rain override sunset',
      primarySignal: 'weather=rainy → rainy_evening (overrides sunset)',
    ),
    EvalCase(
      id: 'L2_TW03',
      context: ThemeContext(hourOfDay: 14, weatherCondition: 'sunny'), // Chiều + nắng → theo giờ
      expectedPalettes: ['ocean', 'mint'],
      category: 'L2',
      subCategory: 'time+weather_sunny',
      description: '[L2] Chiều (14h) + nắng — sunny không override',
      primarySignal: 'hour=14 → ocean | weather=sunny không override',
    ),
    EvalCase(
      id: 'L2_TW04',
      context: ThemeContext(hourOfDay: 7, weatherCondition: 'foggy'), // Sáng + sương mù → theo giờ
      expectedPalettes: ['mint', 'forest'],
      category: 'L2',
      subCategory: 'time+weather_foggy',
      description: '[L2] Sáng (7h) + sương mù — foggy không override',
      primarySignal: 'hour=7 → mint | weather=foggy không override',
    ),

    // ── L2.TIME + HEALTH (daytime) ────────────────────────────────────

    EvalCase(
      id: 'L2_TH01',
      context: ThemeContext(hourOfDay: 9, heartRateBpm: 90), // Sáng + tim cao → mint (hr chỉ ảnh hưởng đêm)
      expectedPalettes: ['mint', 'warm_orange'],
      category: 'L2',
      subCategory: 'time+hr_daytime',
      description: '[L2] Sáng (9h) + hr cao (90) — hr chỉ ảnh hưởng khi đêm',
      primarySignal: 'hour=9 → mint | hr=90 chỉ ảnh hưởng ban đêm',
    ),
    EvalCase(
      id: 'L2_TH02',
      context: ThemeContext(hourOfDay: 14, sleepHours: 3), // Chiều + thiếu ngủ → ocean (sleep chỉ ảnh hưởng đêm)
      expectedPalettes: ['ocean', 'dark_blue'],
      category: 'L2',
      subCategory: 'time+sleep_daytime',
      description: '[L2] Chiều (14h) + thiếu ngủ (3h) — sleep chỉ ảnh hưởng khi đêm',
      primarySignal: 'hour=14 → ocean | sleep=3 chỉ ảnh hưởng ban đêm',
    ),

    // ── L2.NIGHT + HEALTH (2 điều kiện lavender) ─────────────────────

    EvalCase(
      id: 'L2_NH01',
      context: ThemeContext(hourOfDay: 21, heartRateBpm: 62, sleepHours: 7), // Đúng boundary
      expectedPalettes: ['lavender'],
      category: 'L2',
      subCategory: 'night+health_lavender_boundary',
      description: '[L2] Đêm + hr=62 (boundary <65) + sleep=7 (boundary >=7)',
      primarySignal: 'night + hr=62 + sleep=7 → lavender (exact boundary)',
    ),
    EvalCase(
      id: 'L2_NH02',
      context: ThemeContext(hourOfDay: 21, heartRateBpm: 64, sleepHours: 7), // hr=64 còn thỏa
      expectedPalettes: ['lavender'],
      category: 'L2',
      subCategory: 'night+health_lavender',
      description: '[L2] Đêm + hr=64 (<65) + sleep=7 → lavender',
      primarySignal: 'night + hr=64 + sleep=7 → lavender',
    ),
    EvalCase(
      id: 'L2_NH03',
      context: ThemeContext(hourOfDay: 21, heartRateBpm: 65, sleepHours: 8), // hr=65 KHÔNG thỏa (cần < 65)
      expectedPalettes: ['dark_blue'],
      category: 'L2',
      subCategory: 'night+health_dark_blue_hr',
      description: '[L2] Đêm + hr=65 (KHÔNG <65) → dark_blue',
      primarySignal: 'night + hr=65 (not <65) → dark_blue',
    ),
    EvalCase(
      id: 'L2_NH04',
      context: ThemeContext(hourOfDay: 21, heartRateBpm: 60, sleepHours: 6), // sleep=6 KHÔNG thỏa (cần >=7)
      expectedPalettes: ['dark_blue'],
      category: 'L2',
      subCategory: 'night+health_dark_blue_sleep',
      description: '[L2] Đêm + sleep=6 (KHÔNG >=7) → dark_blue',
      primarySignal: 'night + sleep=6 (not >=7) → dark_blue',
    ),

    // ── L2.TEMP + WEATHER ─────────────────────────────────────────────

    EvalCase(
      id: 'L2_TpW01',
      context: ThemeContext(hourOfDay: 10, tempC: 36, weatherCondition: 'sunny'), // Nóng + nắng
      expectedPalettes: ['warm_orange'],
      category: 'L2',
      subCategory: 'temp+weather_hot_sunny',
      description: '[L2] Nóng (36°C) + nắng — cùng hướng warm_orange',
      primarySignal: 'tempC=36 → warm_orange | sunny reinforces',
    ),
    EvalCase(
      id: 'L2_TpW02',
      context: ThemeContext(hourOfDay: 10, tempC: 36, weatherCondition: 'rainy'), // Mâu thuẫn nhẹ: nóng + mưa
      expectedPalettes: ['rainy_evening'],                                          // rain priority > temp
      category: 'L2',
      subCategory: 'temp+weather_conflict_mild',
      description: '[L2] Nóng (36°C) + mưa — rain priority cao hơn temp',
      primarySignal: 'weather=rainy → rainy_evening (priority > tempC=36)',
    ),
    EvalCase(
      id: 'L2_TpW03',
      context: ThemeContext(hourOfDay: 10, tempC: 18, weatherCondition: 'rainy'), // Lạnh + mưa → rainy
      expectedPalettes: ['rainy_evening'],
      category: 'L2',
      subCategory: 'temp+weather_cold_rain',
      description: '[L2] Lạnh (18°C) + mưa — cùng hướng rainy_evening',
      primarySignal: 'weather=rainy → rainy_evening | tempC=18 reinforces',
    ),

    // ════════════════════════════════════════════════════════════════
    // L3 — BA BIẾN (16 cases)
    // 3 biến kết hợp — kiểm tra model có giữ ưu tiên đúng không
    // ════════════════════════════════════════════════════════════════

    // ── L3 — Rain dominates everything ───────────────────────────────

    EvalCase(
      id: 'L3_R01',
      context: ThemeContext(hourOfDay: 6, tempC: 22, weatherCondition: 'rainy'),
      expectedPalettes: ['rainy_evening'],
      category: 'L3',
      subCategory: 'rain_vs_dawn_temp',
      description: '[L3] Mưa + bình minh (6h) + mát — rain override dawn',
      primarySignal: 'weather=rainy → rainy_evening (overrides golden_morning)',
    ),
    EvalCase(
      id: 'L3_R02',
      context: ThemeContext(hourOfDay: 9, tempC: 20, weatherCondition: 'rainy'),
      expectedPalettes: ['rainy_evening'],
      category: 'L3',
      subCategory: 'rain_vs_morning_temp',
      description: '[L3] Mưa + sáng (9h) + lạnh — rain override morning',
      primarySignal: 'weather=rainy → rainy_evening (overrides mint)',
    ),
    EvalCase(
      id: 'L3_R03',
      context: ThemeContext(hourOfDay: 18, tempC: 23, weatherCondition: 'rainy'),
      expectedPalettes: ['rainy_evening'],
      category: 'L3',
      subCategory: 'rain_vs_evening_temp',
      description: '[L3] Mưa + hoàng hôn (18h) + mát — rain override sunset',
      primarySignal: 'weather=rainy → rainy_evening (overrides sunset)',
    ),

    // ── L3 — Hot temp dominates (trừ rain) ───────────────────────────

    EvalCase(
      id: 'L3_H01',
      context: ThemeContext(hourOfDay: 7, tempC: 36, weatherCondition: 'sunny'),
      expectedPalettes: ['warm_orange'],
      category: 'L3',
      subCategory: 'hot_vs_dawn_sunny',
      description: '[L3] Nóng (36°C) + bình minh (7h) + nắng — hot override dawn',
      primarySignal: 'tempC=36 → warm_orange (overrides mint, sunny reinforces)',
    ),
    EvalCase(
      id: 'L3_H02',
      context: ThemeContext(hourOfDay: 23, tempC: 35, heartRateBpm: 80),
      expectedPalettes: ['warm_orange', 'dark_blue'],
      category: 'L3',
      subCategory: 'hot_vs_night_hr',
      description: '[L3] Nóng (35°C) + đêm (23h) + hr cao — hot override night',
      primarySignal: 'tempC=35 → warm_orange (overrides dark_blue)',
    ),

    // ── L3 — Time + Health + Temp (no override) ───────────────────────

    EvalCase(
      id: 'L3_C01',
      context: ThemeContext(hourOfDay: 8, tempC: 22, heartRateBpm: 65),
      expectedPalettes: ['mint', 'forest'],
      category: 'L3',
      subCategory: 'morning+temp+hr',
      description: '[L3] Sáng (8h) + mát (22°C) + hr bình thường — mint',
      primarySignal: 'hour=8 → mint | tempC=22 & hr=65 không override',
    ),
    EvalCase(
      id: 'L3_C02',
      context: ThemeContext(hourOfDay: 14, tempC: 26, sleepHours: 6),
      expectedPalettes: ['ocean', 'mint'],
      category: 'L3',
      subCategory: 'afternoon+temp+sleep',
      description: '[L3] Chiều (14h) + dễ chịu (26°C) + ngủ ít — ocean',
      primarySignal: 'hour=14 → ocean | tempC=26 & sleep=6 không override',
    ),
    EvalCase(
      id: 'L3_C03',
      context: ThemeContext(hourOfDay: 18, tempC: 24, heartRateBpm: 68),
      expectedPalettes: ['sunset', 'warm_orange'],
      category: 'L3',
      subCategory: 'evening+temp+hr',
      description: '[L3] Tối (18h) + ấm (24°C) + hr bình thường — sunset',
      primarySignal: 'hour=18 → sunset | tempC=24 & hr=68 không override',
    ),

    // ── L3 — Night lavender với đủ 2 điều kiện + temp ─────────────────

    EvalCase(
      id: 'L3_N01',
      context: ThemeContext(hourOfDay: 22, tempC: 21, heartRateBpm: 60, sleepHours: 8),
      expectedPalettes: ['lavender', 'dark_blue'],
      category: 'L3',
      subCategory: 'night+relax+cool_temp',
      description: '[L3] Đêm + thư giãn + mát — lavender',
      primarySignal: 'night + hr=60 + sleep=8 → lavender | tempC=21 không override',
    ),
    EvalCase(
      id: 'L3_N02',
      context: ThemeContext(hourOfDay: 22, tempC: 34, heartRateBpm: 60, sleepHours: 8),
      expectedPalettes: ['warm_orange'],
      category: 'L3',
      subCategory: 'night+relax+hot_temp',
      description: '[L3] Đêm + thư giãn + NÓNG (34°C) — hot override lavender',
      primarySignal: 'tempC=34 → warm_orange (overrides lavender)',
    ),

    // ── L3 — Hobbies/Age/Color (user profile signal) ──────────────────

    EvalCase(
      id: 'L3_P01',
      context: ThemeContext(
        hourOfDay: 21, tempC: 22,
        heartRateBpm: 58, sleepHours: 8,
        userHobbies: ['yoga'],
      ),
      expectedPalettes: ['lavender', 'dark_blue'],
      category: 'L3',
      subCategory: 'night+relax+yoga',
      description: '[L3] Đêm + thư giãn + yoga — lavender reinforced by yoga',
      primarySignal: 'night relax → lavender | yoga reinforces',
    ),
    EvalCase(
      id: 'L3_P02',
      context: ThemeContext(
        hourOfDay: 6, tempC: 20,
        heartRateBpm: 70,
        userHobbies: ['sport'],
      ),
      expectedPalettes: ['golden_morning', 'mint', 'warm_orange'],
      category: 'L3',
      subCategory: 'dawn+sport_hobby',
      description: '[L3] Bình minh + thể thao — golden_morning reinforced',
      primarySignal: 'hour=6 → golden_morning | sport reinforces energy',
    ),
    EvalCase(
      id: 'L3_P03',
      context: ThemeContext(
        hourOfDay: 14, tempC: 24,
        heartRateBpm: 65,
        favoriteColor: 'purple',
      ),
      expectedPalettes: ['lavender', 'ocean'],
      category: 'L3',
      subCategory: 'afternoon+purple_pref',
      description: '[L3] Chiều + thích màu tím — lavender vs ocean conflict',
      primarySignal: 'hour=14 → ocean | favoriteColor=purple → lavender',
    ),
    EvalCase(
      id: 'L3_P04',
      context: ThemeContext(
        hourOfDay: 14, tempC: 24,
        favoriteColor: 'blue',
        userAge: 25,
      ),
      expectedPalettes: ['ocean', 'dark_blue', 'mint'],
      category: 'L3',
      subCategory: 'afternoon+blue_pref+age',
      description: '[L3] Chiều + thích màu xanh + 25 tuổi — ocean reinforced',
      primarySignal: 'hour=14 → ocean | favoriteColor=blue reinforces',
    ),

    // ════════════════════════════════════════════════════════════════
    // L4 — EDGE / CONFLICT / PHỨC TẠP (14 cases)
    // Tín hiệu mâu thuẫn, nhiều biến cùng lúc, case đặc biệt
    // ════════════════════════════════════════════════════════════════

    // ── L4 — Tín hiệu mâu thuẫn rõ ràng ─────────────────────────────

    EvalCase(
      id: 'L4_X01',
      context: ThemeContext(
        hourOfDay: 10, tempC: 40, weatherCondition: 'rainy',
      ),
      expectedPalettes: ['rainy_evening'], // rain > hot theo priority
      category: 'L4',
      subCategory: 'conflict_rain_vs_extreme_heat',
      description: '[L4] Mâu thuẫn cực đoan: 40°C + mưa — rain priority',
      primarySignal: 'weather=rainy → rainy_evening (P1 > P2: tempC=40)',
    ),
    EvalCase(
      id: 'L4_X02',
      context: ThemeContext(
        hourOfDay: 6, tempC: 36, weatherCondition: 'sunny',
      ),
      expectedPalettes: ['warm_orange'], // hot (P2) > dawn (P3)
      category: 'L4',
      subCategory: 'conflict_heat_vs_dawn',
      description: '[L4] Mâu thuẫn: 36°C + bình minh — hot override dawn',
      primarySignal: 'tempC=36 → warm_orange (P2 > P3: hour=6)',
    ),
    EvalCase(
      id: 'L4_X03',
      context: ThemeContext(
        hourOfDay: 6, weatherCondition: 'rainy', tempC: 18,
      ),
      expectedPalettes: ['rainy_evening'], // rain (P1) > dawn (P3)
      category: 'L4',
      subCategory: 'conflict_rain_vs_dawn',
      description: '[L4] Mâu thuẫn: mưa + bình minh (6h) — rain override',
      primarySignal: 'weather=rainy → rainy_evening (P1 > P3: hour=6)',
    ),
    EvalCase(
      id: 'L4_X04',
      context: ThemeContext(
        hourOfDay: 20, tempC: 34, heartRateBpm: 60, sleepHours: 8,
      ),
      expectedPalettes: ['warm_orange'], // hot (P2) > night_relax (P7)
      category: 'L4',
      subCategory: 'conflict_heat_vs_relax_night',
      description: '[L4] Đêm thư giãn nhưng 34°C — hot override lavender',
      primarySignal: 'tempC=34 → warm_orange (P2 > P7: night relax)',
    ),

    // ── L4 — Profile đầy đủ ───────────────────────────────────────────

    EvalCase(
      id: 'L4_F01',
      context: ThemeContext(
        hourOfDay: 8, tempC: 22, weatherCondition: 'sunny',
        heartRateBpm: 65, sleepHours: 7,
        userHobbies: ['sport'], userAge: 22,
      ),
      expectedPalettes: ['mint', 'golden_morning', 'forest'],
      category: 'L4',
      subCategory: 'full_profile_morning_healthy',
      description: '[L4] Profile đầy đủ: sáng đẹp, khỏe mạnh, thể thao',
      primarySignal: 'hour=8 → mint | tất cả tín hiệu cùng hướng positive',
    ),
    EvalCase(
      id: 'L4_F02',
      context: ThemeContext(
        hourOfDay: 23, tempC: 21, weatherCondition: 'clear',
        heartRateBpm: 58, sleepHours: 9,
        userHobbies: ['yoga'], userAge: 28,
        favoriteColor: 'purple',
      ),
      expectedPalettes: ['lavender', 'dark_blue'],
      category: 'L4',
      subCategory: 'full_profile_night_relax',
      description: '[L4] Profile đầy đủ: đêm thư giãn, yoga, thích tím',
      primarySignal: 'night relax → lavender | yoga+purple reinforces',
    ),
    EvalCase(
      id: 'L4_F03',
      context: ThemeContext(
        hourOfDay: 14, tempC: 30, weatherCondition: 'sunny',
        heartRateBpm: 88, sleepHours: 5,
        userHobbies: ['travel', 'photo'], userAge: 25,
      ),
      expectedPalettes: ['ocean', 'warm_orange'],
      category: 'L4',
      subCategory: 'full_profile_afternoon_stressed',
      description: '[L4] Profile đầy đủ: chiều nắng, mệt, nhịp tim cao',
      primarySignal: 'hour=14 → ocean | hr cao nhưng daytime không override',
    ),

    // ── L4 — Context tối thiểu / Null nhiều trường ───────────────────

    EvalCase(
      id: 'L4_M01',
      context: ThemeContext(hourOfDay: 12), // Minimal: chỉ giờ
      expectedPalettes: ['ocean', 'mint', 'forest'],
      category: 'L4',
      subCategory: 'minimal_context',
      description: '[L4] Context tối thiểu: chỉ có giờ (12h)',
      primarySignal: 'hour=12 → ocean | mọi field khác null',
    ),
    EvalCase(
      id: 'L4_M02',
      context: ThemeContext(hourOfDay: 3), // Midnight
      expectedPalettes: ['dark_blue'],
      category: 'L4',
      subCategory: 'minimal_midnight',
      description: '[L4] Context tối thiểu: nửa đêm (3h)',
      primarySignal: 'hour=3 → dark_blue | không có hr/sleep',
    ),

    // ── L4 — Night ambiguity (hr hoặc sleep thiếu một trong hai) ────

    EvalCase(
      id: 'L4_N01',
      context: ThemeContext(hourOfDay: 22, heartRateBpm: 60), // Chỉ có hr, không có sleep
      expectedPalettes: ['dark_blue', 'lavender'],
      category: 'L4',
      subCategory: 'night_only_hr',
      description: '[L4] Đêm + chỉ hr=60 (thiếu sleep) — ambiguous',
      primarySignal: 'night + hr=60 nhưng sleep=null → ambiguous',
    ),
    EvalCase(
      id: 'L4_N02',
      context: ThemeContext(hourOfDay: 22, sleepHours: 8), // Chỉ có sleep, không có hr
      expectedPalettes: ['lavender', 'dark_blue'],
      category: 'L4',
      subCategory: 'night_only_sleep',
      description: '[L4] Đêm + chỉ sleep=8 (thiếu hr) — ambiguous',
      primarySignal: 'night + sleep=8 nhưng hr=null → ambiguous',
    ),

    // ── L4 — Extreme stress ban ngày ─────────────────────────────────

    EvalCase(
      id: 'L4_S01',
      context: ThemeContext(
        hourOfDay: 9, tempC: 25,
        heartRateBpm: 110, sleepHours: 3,
      ),
      expectedPalettes: ['mint', 'warm_orange', 'ocean'],
      category: 'L4',
      subCategory: 'morning_extreme_stress',
      description: '[L4] Sáng nhưng cực kỳ mệt: hr=110, sleep=3h',
      primarySignal: 'hour=9 → mint | stress ban ngày không override',
    ),
    EvalCase(
      id: 'L4_S02',
      context: ThemeContext(
        hourOfDay: 22, tempC: 30,
        heartRateBpm: 95, sleepHours: 3,
        weatherCondition: 'clear',
      ),
      expectedPalettes: ['dark_blue', 'warm_orange'],
      category: 'L4',
      subCategory: 'night_extreme_stress_hot',
      description: '[L4] Đêm khuya, nóng (30°C), stress, mất ngủ',
      primarySignal: 'night + hr=95 + sleep=3 → dark_blue | tempC=30 không override',
    ),
  ];

  // ── Utilities ─────────────────────────────────────────────────────────────

  static List<EvalCase> byCategory(String cat) =>
      cases.where((c) => c.category == cat).toList();

  static List<EvalCase> bySubCategory(String sub) =>
      cases.where((c) => c.subCategory == sub).toList();

  static EvalCase? byId(String id) =>
      cases.where((c) => c.id == id).firstOrNull;

  /// Trả về stats số lượng theo tầng
  static Map<String, int> get layerStats => {
    'L1': byCategory('L1').length,
    'L2': byCategory('L2').length,
    'L3': byCategory('L3').length,
    'L4': byCategory('L4').length,
    'total': cases.length,
  };

  /// Lấy theo nhóm tín hiệu để chạy benchmark từng phần
  static List<EvalCase> get timeOnlyCases =>
      cases.where((c) => c.subCategory.startsWith('time')).toList();

  static List<EvalCase> get rainCases =>
      cases.where((c) => c.subCategory.contains('rain')).toList();

  static List<EvalCase> get hotCases =>
      cases.where((c) => c.subCategory.contains('hot') || c.subCategory.contains('temp')).toList();

  static List<EvalCase> get nightCases =>
      cases.where((c) => c.subCategory.startsWith('night')).toList();

  static List<EvalCase> get conflictCases =>
      cases.where((c) => c.subCategory.startsWith('conflict')).toList();
}