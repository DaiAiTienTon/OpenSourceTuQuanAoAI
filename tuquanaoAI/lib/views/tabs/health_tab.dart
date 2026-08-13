import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:tuquanapai/service/gemma_theme_service.dart';
import '../../core/theme.dart';
import '../../service/theme_service.dart';
import '../../viewmodels/health_viewmodel.dart';
import '../../service/Weather_service.dart';
import '../widgets/common_widgets.dart';

class HealthTab extends StatefulWidget {
  const HealthTab({super.key});

  @override
  State<HealthTab> createState() => _HealthTabState();
}

class _HealthTabState extends State<HealthTab> {
  static const _fields = [
    {'label': 'Nhịp tim',  'unit': 'bpm',  'icon': '💓', 'color': 0xFFFFC4D4, 'normal': '60–100',        'key': 'heartRate',     'numeric': true},
    {'label': 'Huyết áp',  'unit': 'mmHg', 'icon': '🩺', 'color': 0xFFC4D4FF, 'normal': '<120/80',       'key': 'bloodPressure', 'numeric': false},
    {'label': 'Cân nặng',  'unit': 'kg',   'icon': '⚖️', 'color': 0xFFC4FFD4, 'normal': 'BMI 18.5–24.9', 'key': 'weight',        'numeric': true},
    {'label': 'Giờ ngủ',   'unit': 'giờ',  'icon': '😴', 'color': 0xFFFFD6A8, 'normal': '7–9 giờ',       'key': 'sleep',         'numeric': true},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<HealthViewModel>().load();
    });
  }

  String _getValue(HealthViewModel vm, String key) {
    switch (key) {
      case 'heartRate':     return vm.data.heartRate;
      case 'bloodPressure': return vm.data.bloodPressure;
      case 'weight':        return vm.data.weight;
      case 'sleep':         return vm.data.sleep;
      default:              return '';
    }
  }

  void _onChanged(String key, String value) {
    final vm = context.read<HealthViewModel>();
    switch (key) {
      case 'heartRate':     vm.update(heartRate: value);     break;
      case 'bloodPressure': vm.update(bloodPressure: value); break;
      case 'weight':        vm.update(weight: value);        break;
      case 'sleep':         vm.update(sleep: value);         break;
    }
  }

  Future<void> _handleSave() async {
    final vm = context.read<HealthViewModel>();
    final needConfirm = await vm.requestSave();

    if (!needConfirm || !mounted) return;

    final warnings = vm.pendingWarnings.values.join('\n\n');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          '⚠️ Dữ liệu bất thường',
          style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFD4607A)),
        ),
        content: Text(warnings,
            style: const TextStyle(fontSize: 13.5, height: 1.55)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Huỷ', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Vẫn lưu',
              style: TextStyle(
                  color: Color(0xFFD4607A), fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (confirmed == true) {
      vm.confirmSaveWithWarnings();
      // ── Trigger cập nhật theme sau khi lưu sức khoẻ ─────────────────
      _triggerThemeUpdate();
    } else {
      vm.cancelPendingWarnings();
    }
  }

  /// Gọi ThemeService.generateTheme() với dữ liệu sức khoẻ mới nhất
  void _triggerThemeUpdate() {
    final vm      = context.read<HealthViewModel>();
    final weather = context.read<WeatherService>();
    final themeCtx = ThemeContext(
      tempC:            weather.weather?.tempC,
      weatherCondition: weather.weather?.description,
      hourOfDay:        DateTime.now().hour,
      heartRateBpm:     double.tryParse(vm.data.heartRate),
      sleepHours:       double.tryParse(vm.data.sleep),
    );
    context.read<ThemeService>().generateTheme(themeCtx);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<HealthViewModel>();
    final t  = AppTheme.of(context);

    if (vm.loading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: CircularProgressIndicator(color: t.primary),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: '💗 Tình trạng sức khoẻ',
          subtitle:
          'Cập nhật sức khoẻ hàng ngày để AI điều chỉnh gợi ý trang phục phù hợp hơn.',
        ),

        // ── Stats Grid ────────────────────────────────────────────────────
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.3,
          children: _fields.map((f) {
            final value = _getValue(vm, f['key'] as String);
            final fieldColor = Color(f['color'] as int);
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.92),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: fieldColor.withOpacity(0.5),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: fieldColor.withOpacity(0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(f['icon'] as String, style: const TextStyle(fontSize: 22)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: fieldColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          f['unit'] as String,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: t.primaryDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value.isEmpty ? '--' : value,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: t.primaryDark,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    f['label'] as String,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: t.textSecondary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.1,
                    ),
                  ),
                  Text(
                    'Bình thường: ${f['normal']}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9.5,
                      color: t.textMuted.withOpacity(0.75),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 14),

        // ── Manual Input Card ─────────────────────────────────────────────
        AppCard(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('✏️ Nhập thủ công',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: t.primaryDark,
                          fontSize: 14.5)),
                  const SizedBox(height: 4),
                  Text('Tự điền các chỉ số sức khoẻ hàng ngày.',
                      style: TextStyle(
                          fontSize: 11.5,
                          color: t.textSecondary,
                          fontWeight: FontWeight.w600,
                          height: 1.45)),
                  const SizedBox(height: 12),

                  ...(_fields.map((f) {
                    final key       = f['key'] as String;
                    final isNumeric = f['numeric'] as bool;
                    final error     = vm.fieldErrors[key];

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 11),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${f['icon']} ${f['label']} (${f['unit']})',
                                style: TextStyle(
                                    fontSize: 12.5,
                                    color: t.textMuted,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 5),
                            AppTextField(
                              placeholder: isNumeric ? '0' : 'vd: 120/80',
                              value: _getValue(vm, key),
                              onChanged: (v) => _onChanged(key, v),
                              keyboardType: isNumeric
                                  ? const TextInputType.numberWithOptions(decimal: true)
                                  : TextInputType.text,
                              inputFormatters: isNumeric
                                  ? [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))]
                                  : null,
                            ),
                            if (error != null) ...[
                              const SizedBox(height: 4),
                              Row(children: [
                                const Text('⚠️ ', style: TextStyle(fontSize: 12)),
                                Expanded(
                                  child: Text(
                                    error,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFFD32F2F),
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ]),
                            ],
                          ]),
                    );
                  })),

                  Text('📝 Ghi chú thêm',
                      style: TextStyle(
                          fontSize: 12.5,
                          color: t.textMuted,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(
                      'Ghi chú triệu chứng hoặc cảm nhận cơ thể để AI hiểu rõ hơn',
                      style: TextStyle(
                          fontSize: 11.5,
                          color: t.textSecondary,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 5),

                  AppTextField(
                    placeholder:
                    'vd: Đau đầu nhẹ từ sáng, mệt sau khi tập yoga...',
                    value: vm.data.notes,
                    onChanged: (v) =>
                        context.read<HealthViewModel>().update(notes: v),
                    maxLines: 3,
                    maxLength: 500,
                  ),

                  if (vm.fieldErrors['notes'] != null) ...[
                    const SizedBox(height: 4),
                    Row(children: [
                      const Text('⚠️ ', style: TextStyle(fontSize: 12)),
                      Expanded(
                        child: Text(
                          vm.fieldErrors['notes']!,
                          style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFFD32F2F),
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ]),
                  ],

                  const SizedBox(height: 13),

                  PrimaryButton(
                    label: vm.saving
                        ? '⏳ Đang lưu...'
                        : vm.saved
                        ? '✅ Đã lưu thành công!'
                        : '💾 Lưu thông tin sức khoẻ',
                    onTap: vm.saving ? null : _handleSave,
                    overrideColor: vm.saved ? const Color(0xFF66BB6A) : null,
                  ),
                ])),

        const SizedBox(height: 20),
      ],
    );
  }
}