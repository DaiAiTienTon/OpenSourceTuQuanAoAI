import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../models/clothing_item.dart';
import '../../viewmodels/wardrobe_viewmodel.dart';
import '../widgets/common_widgets.dart';

class WardrobeTab extends StatefulWidget {
  const WardrobeTab({super.key});

  @override
  State<WardrobeTab> createState() => _WardrobeTabState();
}

class _WardrobeTabState extends State<WardrobeTab> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final vm      = context.read<WardrobeViewModel>();
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

    if (error != null && !vm.isAdding && vm.editingItem == null) {
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

  static const _closets = {
    'tops':    {'label': 'Tủ áo',   'icon': '🧥'},
    'bottoms': {'label': 'Tủ quần', 'icon': '👖'},
  };

  static const _closetDescs = {
    'tops':    'Lưu trữ áo, blazer, áo khoác. AI dùng thông tin này để phối đồ.',
    'bottoms': 'Lưu trữ quần jeans, váy, quần tây... AI sẽ kết hợp với áo.',
  };

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<WardrobeViewModel>();
    final t  = AppTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: '👗 Tủ đồ cá nhân',
          subtitle: 'Quản lý trang phục bạn đang có. Tủ đồ càng đầy đủ, AI gợi ý càng chính xác.',
        ),

        // ── Closet Selector ───────────────────────────────────────────────
        Row(
          children: _closets.entries.map((e) {
            final isActive = vm.activeCloset == e.key;
            final count = e.key == 'tops' ? vm.topsCount : vm.bottomsCount;
            return Expanded(
              child: GestureDetector(
                onTap: () => context.read<WardrobeViewModel>().setActiveCloset(e.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: EdgeInsets.only(right: e.key == 'tops' ? 10 : 0),
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                  decoration: BoxDecoration(
                    color: isActive
                        ? t.primary.withOpacity(0.08)
                        : Colors.white.withOpacity(0.92),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isActive ? t.primary : t.borderColor.withOpacity(0.4),
                      width: isActive ? 1.5 : 1,
                    ),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: t.primary.withOpacity(0.1),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            )
                          ]
                        : [
                            BoxShadow(
                              color: t.primary.withOpacity(0.02),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            )
                          ],
                  ),
                  child: Column(
                    children: [
                      Text(e.value['icon']!, style: const TextStyle(fontSize: 24)),
                      const SizedBox(height: 4),
                      Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: isActive ? t.primaryDark : t.textMuted,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        e.value['label']!.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9.5,
                          color: isActive ? t.primary : t.textMuted.withOpacity(0.8),
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 14),

        // ── Closet Card ───────────────────────────────────────────────────
        AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(
              '${_closets[vm.activeCloset]!['icon']} ${_closets[vm.activeCloset]!['label']}',
              style: TextStyle(fontWeight: FontWeight.w800, color: t.primaryDark, fontSize: 14.5),
            ),
            if (!vm.isSaving)
              GestureDetector(
                onTap: () {
                  _nameCtrl.clear();
                  _descCtrl.clear();
                  context.read<WardrobeViewModel>().startAdding();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: t.borderColor.withOpacity(0.8), width: 1.2),
                  ),
                  child: Text(
                    '+ Thêm',
                    style: TextStyle(fontSize: 12.5, color: t.primary, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            if (vm.isSaving)
              SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: t.primary),
              ),
          ]),
          const SizedBox(height: 4),
          Text(
            _closetDescs[vm.activeCloset]!,
            style: TextStyle(fontSize: 11.5, color: t.textSecondary, fontWeight: FontWeight.w600, height: 1.45),
          ),
          const SizedBox(height: 10),

          AppTextField(
            placeholder: '🔍 Tìm kiếm...',
            value: vm.searchQuery,
            onChanged: (v) => context.read<WardrobeViewModel>().setSearch(v),
          ),
          const SizedBox(height: 12),

          if (vm.filteredItems.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Column(children: [
                  Text(_closets[vm.activeCloset]!['icon']!, style: const TextStyle(fontSize: 30)),
                  const SizedBox(height: 6),
                  Text(
                    vm.searchQuery.isNotEmpty ? 'Không tìm thấy kết quả' : 'Tủ trống. Hãy thêm trang phục!',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: t.textSecondary),
                  ),
                ]),
              ),
            )
          else
            Wrap(
              children: vm.filteredItems.map((item) {
                final truncDesc = item.desc.isNotEmpty
                    ? '· ${item.desc.substring(0, item.desc.length > 14 ? 14 : item.desc.length)}${item.desc.length > 14 ? '…' : ''}'
                    : null;
                return ItemChip(
                  label: item.name,
                  subLabel: truncDesc != null ? '$truncDesc ✎' : '✎',
                  selected: vm.editingItem?.id == item.id,
                  onTap: () {
                    _nameCtrl.text = item.name;
                    _descCtrl.text = item.desc;
                    context.read<WardrobeViewModel>().startEditing(item);
                  },
                );
              }).toList(),
            ),

          if (vm.isAdding) ...[
            const SizedBox(height: 12),
            _FormSection(
              title: '➕ Thêm vào ${_closets[vm.activeCloset]!['label']}',
              hint: '💡 Mô tả càng chi tiết (màu sắc, chất liệu, dáng), AI sẽ gợi ý chính xác hơn!',
              nameCtrl: _nameCtrl,
              descCtrl: _descCtrl,
              namePlaceholder: 'Tên trang phục *',
              descPlaceholder: 'Mô tả (màu sắc, chất liệu... không bắt buộc)',
              primaryLabel: vm.isSaving ? 'Đang thêm...' : 'Thêm vào tủ',
              errorMessage: vm.errorMessage,
              onPrimary: vm.isSaving
                  ? null
                  : () => context.read<WardrobeViewModel>().addItem(_nameCtrl.text, _descCtrl.text),
              onCancel: vm.isSaving
                  ? null
                  : () => context.read<WardrobeViewModel>().cancelAdding(),
            ),
          ],

          if (vm.editingItem != null) ...[
            const SizedBox(height: 12),
            _EditFormSection(
              nameCtrl: _nameCtrl,
              descCtrl: _descCtrl,
              isSaving: vm.isSaving,
              errorMessage: vm.errorMessage,
              onSave: vm.isSaving
                  ? null
                  : () {
                final updated = vm.editingItem!.copyWith(
                  name: _nameCtrl.text,
                  desc: _descCtrl.text,
                );
                context.read<WardrobeViewModel>().saveEdit(updated);
              },
              onDelete: vm.isSaving
                  ? null
                  : () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    title: const Text('Xác nhận xóa',
                        style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFD4607A))),
                    content: Text(
                      'Xóa "${vm.editingItem!.name}" khỏi tủ đồ?\nThao tác này không thể hoàn tác.',
                      style: const TextStyle(fontSize: 13.5, height: 1.5),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text('Huỷ', style: TextStyle(color: t.textMuted)),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Xóa',
                            style: TextStyle(color: Color(0xFFD4607A), fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                );
                if (confirmed == true && context.mounted) {
                  context.read<WardrobeViewModel>().deleteItem(vm.editingItem!.id);
                }
              },
              onCancel: vm.isSaving
                  ? null
                  : () => context.read<WardrobeViewModel>().cancelEditing(),
            ),
          ],
        ])),

        const SizedBox(height: 20),
      ],
    );
  }
}

// ─── _FormSection ─────────────────────────────────────────────────────────────
class _FormSection extends StatelessWidget {
  final String title;
  final String hint;
  final TextEditingController nameCtrl;
  final TextEditingController descCtrl;
  final String namePlaceholder;
  final String descPlaceholder;
  final String primaryLabel;
  final String? errorMessage;
  final VoidCallback? onPrimary;
  final VoidCallback? onCancel;

  const _FormSection({
    required this.title,
    required this.hint,
    required this.nameCtrl,
    required this.descCtrl,
    required this.errorMessage,
    required this.namePlaceholder,
    required this.descPlaceholder,
    required this.primaryLabel,
    required this.onPrimary,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.gradientStart.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.borderColor),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: TextStyle(fontSize: 12.5, color: t.textMuted, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        FeatureHint(hint),
        TextField(
          controller: nameCtrl,
          decoration: _inputDeco(namePlaceholder, t),
          style: TextStyle(fontSize: 13.5, color: t.primaryDark),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: descCtrl,
          decoration: _inputDeco(descPlaceholder, t),
          style: TextStyle(fontSize: 13.5, color: t.primaryDark),
        ),
        const SizedBox(height: 10),
        if (errorMessage != null) ...[
          const SizedBox(height: 4),
          Row(children: [
            const Text('⚠️ ', style: TextStyle(fontSize: 13)),
            Expanded(
              child: Text(
                errorMessage!,
                style: const TextStyle(
                  fontSize: 12.5, color: Color(0xFFD32F2F), fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 6),
        ],
        Row(children: [
          Expanded(child: PrimaryButton(label: primaryLabel, onTap: onPrimary)),
          const SizedBox(width: 8),
          Expanded(child: SecondaryButton(label: 'Huỷ', onTap: onCancel ?? () {})),
        ]),
      ]),
    );
  }

  InputDecoration _inputDeco(String hint, AppTheme t) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: t.textMuted.withOpacity(0.5), fontSize: 13),
    filled: true,
    fillColor: Colors.white.withOpacity(0.9),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: t.borderColor, width: 1.5)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: t.borderColor, width: 1.5)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: t.primaryLight, width: 1.5)),
  );
}

// ─── _EditFormSection ─────────────────────────────────────────────────────────
class _EditFormSection extends StatelessWidget {
  final TextEditingController nameCtrl;
  final TextEditingController descCtrl;
  final bool isSaving;
  final VoidCallback? onSave;
  final String? errorMessage;
  final VoidCallback? onDelete;
  final VoidCallback? onCancel;

  const _EditFormSection({
    required this.nameCtrl,
    required this.descCtrl,
    required this.isSaving,
    required this.onSave,
    required this.errorMessage,
    required this.onDelete,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.gradientStart.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.borderColor),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('✏️ Chỉnh sửa trang phục',
            style: TextStyle(fontSize: 12.5, color: t.textMuted, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        const FeatureHint('Nhấn Xoá để xoá khỏi tủ đồ. Thao tác này không thể hoàn tác.'),
        TextField(
          controller: nameCtrl,
          decoration: _inputDeco('Tên trang phục', t),
          style: TextStyle(fontSize: 13.5, color: t.primaryDark),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: descCtrl,
          decoration: _inputDeco('Mô tả', t),
          style: TextStyle(fontSize: 13.5, color: t.primaryDark),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: PrimaryButton(label: isSaving ? '⏳ Đang lưu...' : '💾 Lưu', onTap: onSave)),
          const SizedBox(width: 8),
          Expanded(child: DangerButton(label: '🗑️ Xoá', onTap: onDelete ?? () {})),
          const SizedBox(width: 8),
          Expanded(child: SecondaryButton(label: 'Huỷ', onTap: onCancel ?? () {})),
        ]),
      ]),
    );
  }

  InputDecoration _inputDeco(String hint, AppTheme t) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: t.textMuted.withOpacity(0.5), fontSize: 13),
    filled: true,
    fillColor: Colors.white.withOpacity(0.9),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: t.borderColor, width: 1.5)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: t.borderColor, width: 1.5)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: t.primaryLight, width: 1.5)),
  );
}