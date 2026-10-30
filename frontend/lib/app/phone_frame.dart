import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// 넓은 화면(웹 · 태블릿)에서는 휴대폰 크기 틀 안에 앱을 보여 준다. 휴대폰에서는 그대로.
class PhoneFrame extends StatelessWidget {
  const PhoneFrame({super.key, required this.child});

  final Widget child;

  static const phone = Size(390, 844);

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final size = mq.size;
    if (size.width < 600) return child;
    final scale = ((size.height - 48) / (phone.height + 24)).clamp(0.55, 1.0);
    return ColoredBox(
      color: const Color(0xFFEEF0F3),
      child: Center(
        child: Transform.scale(
          scale: scale,
          child: Container(
            width: phone.width + 24,
            height: phone.height + 24,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.ink,
              borderRadius: BorderRadius.circular(52),
              boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 40, offset: Offset(0, 16))],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(40),
              child: MediaQuery(
                data: mq.copyWith(size: phone, padding: EdgeInsets.zero, viewPadding: EdgeInsets.zero),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
