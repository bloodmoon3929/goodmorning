import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../emoji/emoji_image.dart';

enum AppButtonKind { primary, secondary, dark, soft }

/// 버튼: 주요 행동(주황) · 보조 행동(테두리) · 누를 수 없음(회색, onPressed 없음).
class AppButton extends StatelessWidget {
  const AppButton(
    this.label, {
    super.key,
    this.onPressed,
    this.kind = AppButtonKind.primary,
    this.icon,
    this.height = 52,
    this.fontSize = 15,
    this.expand = true,
    this.radius,
    this.busy = false,
    this.color,
    this.textColor,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonKind kind;
  final String? icon; // 이모지 키
  final double height;
  final double fontSize;
  final bool expand;
  final double? radius;
  final bool busy;
  final Color? color;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    final (bg, fg, border) = switch (kind) {
      AppButtonKind.primary => (AppColors.orange, AppColors.white, null),
      AppButtonKind.secondary => (AppColors.white, AppColors.ink, AppColors.line),
      AppButtonKind.dark => (AppColors.ink, AppColors.white, null),
      AppButtonKind.soft => (AppColors.orangeBg, AppColors.orange, null),
    };
    final background = !enabled && !busy ? AppColors.bg : (color ?? bg);
    final foreground = !enabled && !busy ? const Color(0xFFB0B5BD) : (textColor ?? fg);
    final child = busy
        ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: foreground))
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[EmojiImage(icon!, size: fontSize + 4), const SizedBox(width: 6)],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600, color: foreground),
                ),
              ),
            ],
          );
    return SizedBox(
      width: expand ? double.infinity : null,
      height: height,
      child: Material(
        color: background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius ?? height / 2),
          side: border != null && enabled ? BorderSide(color: border) : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: height < 40 ? 12 : 18),
            child: Center(widthFactor: 1, child: child),
          ),
        ),
      ),
    );
  }
}
