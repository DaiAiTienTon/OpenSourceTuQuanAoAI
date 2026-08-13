import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:tuquanapai/core/theme.dart';


// ─── AppCard ───────────────────────────────────────────────────────────────────
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final Gradient? gradient;
  final Border? border;

  const AppCard({super.key, required this.child, this.padding, this.gradient, this.border});

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: padding ?? const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: gradient ?? LinearGradient(
          colors: [
            Colors.white.withOpacity(0.92),
            t.gradientEnd.withOpacity(0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: border ?? Border.all(color: t.borderColor.withOpacity(0.4), width: 1),
        boxShadow: [
          BoxShadow(
            color: t.primary.withOpacity(0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: t.primaryDark.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ─── TagButton ────────────────────────────────────────────────────────────────
class TagButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const TagButton({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.only(right: 6, bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: active ? t.primaryGradient : null,
          color: active ? null : Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: active ? Colors.transparent : t.borderColor.withOpacity(0.6),
            width: 1.2,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: t.primary.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : t.textMuted,
          ),
        ),
      ),
    );
  }
}

// ─── ItemChip ────────────────────────────────────────────────────────────────
class ItemChip extends StatelessWidget {
  final String label;
  final String? subLabel;
  final bool selected;
  final VoidCallback onTap;

  const ItemChip({
    super.key,
    required this.label,
    this.subLabel,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.only(right: 6, bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: selected ? t.primaryGradient : null,
          color: selected ? null : Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? Colors.transparent : t.borderColor.withOpacity(0.6),
            width: 1.2,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: t.primary.withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : t.textMuted,
                ),
              ),
            ),
            if (subLabel != null) ...[
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  subLabel!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? Colors.white70
                        : t.textMuted.withOpacity(0.6),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── PrimaryButton ────────────────────────────────────────────────────────────
class PrimaryButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final Color? overrideColor;

  const PrimaryButton({
    super.key,
    required this.label,
    this.onTap,
    this.overrideColor,
  });

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    final disabled = widget.onTap == null;
    return SizedBox(
      width: double.infinity,
      child: GestureDetector(
        onTapDown: disabled ? null : (_) => setState(() => _scale = 0.96),
        onTapUp: disabled ? null : (_) => setState(() => _scale = 1.0),
        onTapCancel: disabled ? null : () => setState(() => _scale = 1.0),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _scale,
          duration: const Duration(milliseconds: 100),
          child: Opacity(
            opacity: disabled ? 0.6 : 1.0,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                gradient: widget.overrideColor != null ? null : t.primaryGradient,
                color: widget.overrideColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: disabled
                    ? null
                    : [
                        BoxShadow(
                          color: (widget.overrideColor ?? t.primary).withOpacity(0.24),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        )
                      ],
              ),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14.5,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── SecondaryButton ──────────────────────────────────────────────────────────
class SecondaryButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  const SecondaryButton({super.key, required this.label, required this.onTap});

  @override
  State<SecondaryButton> createState() => _SecondaryButtonState();
}

class _SecondaryButtonState extends State<SecondaryButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.96),
      onTapUp: (_) => setState(() => _scale = 1.0),
      onTapCancel: () => setState(() => _scale = 1.0),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: t.borderColor.withOpacity(0.8), width: 1.2),
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: t.primary,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── DangerButton ─────────────────────────────────────────────────────────────
class DangerButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  const DangerButton({super.key, required this.label, required this.onTap});

  @override
  State<DangerButton> createState() => _DangerButtonState();
}

class _DangerButtonState extends State<DangerButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.96),
      onTapUp: (_) => setState(() => _scale = 1.0),
      onTapCancel: () => setState(() => _scale = 1.0),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFE07070).withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE07070).withOpacity(0.3), width: 1.2),
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFE07070),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── AppTextField ─────────────────────────────────────────────────────────────
class AppTextField extends StatefulWidget {
  final String placeholder;
  final String value;
  final ValueChanged<String> onChanged;
  final bool obscureText;
  final int? maxLines;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final Widget? suffixIcon;

  const AppTextField({
    super.key,
    required this.placeholder,
    required this.value,
    required this.onChanged,
    this.obscureText = false,
    this.maxLines = 1,
    this.keyboardType,
    this.inputFormatters,
    this.maxLength,
    this.suffixIcon,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _controller.selection = TextSelection.collapsed(offset: widget.value.length);
  }

  @override
  void didUpdateWidget(AppTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      final selection = _controller.selection;
      _controller.text = widget.value;
      if (selection.start <= widget.value.length) {
        _controller.selection = selection;
      } else {
        _controller.selection = TextSelection.collapsed(offset: widget.value.length);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      obscureText: widget.obscureText,
      maxLines: widget.obscureText ? 1 : widget.maxLines,
      keyboardType: widget.keyboardType,
      inputFormatters: widget.inputFormatters,
      maxLength: widget.maxLength,
      style: TextStyle(fontSize: 13.5, color: t.primaryDark, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: widget.placeholder,
        hintStyle: TextStyle(color: t.textMuted.withOpacity(0.45), fontWeight: FontWeight.normal),
        filled: true,
        fillColor: Colors.white.withOpacity(0.95),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        suffixIcon: widget.suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: t.borderColor.withOpacity(0.6), width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: t.borderColor.withOpacity(0.6), width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: t.primary, width: 1.5),
        ),
      ),
    );
  }
}

// ─── AIResultCard ─────────────────────────────────────────────────────────────
class AIResultCard extends StatelessWidget {
  final String text;
  const AIResultCard({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.9),
            t.gradientEnd.withOpacity(0.12),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: t.primaryLight.withOpacity(0.35), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: t.primary.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13.5,
          color: t.primaryDark,
          height: 1.7,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.15,
        ),
      ),
    );
  }
}

// ─── SpinnerWidget ────────────────────────────────────────────────────────────
class SpinnerWidget extends StatelessWidget {
  final String text;
  const SpinnerWidget({super.key, this.text = 'AI đang phân tích...'});

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: t.primary,
                backgroundColor: t.borderColor.withOpacity(0.3),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              text,
              style: TextStyle(
                color: t.textSecondary,
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── FeatureHint ─────────────────────────────────────────────────────────────
class FeatureHint extends StatelessWidget {
  final String text;
  const FeatureHint(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: t.primaryLight.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(color: t.primaryLight.withOpacity(0.5), width: 3),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11.5,
          color: t.textSecondary,
          fontWeight: FontWeight.w600,
          height: 1.5,
        ),
      ),
    );
  }
}

// ─── SectionHeader ────────────────────────────────────────────────────────────
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;

  const SectionHeader({super.key, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: t.primaryDark,
            letterSpacing: 0.25,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            subtitle!,
            style: TextStyle(
              fontSize: 12.5,
              color: t.textSecondary,
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
          ),
        ],
        const SizedBox(height: 18),
      ],
    );
  }
}