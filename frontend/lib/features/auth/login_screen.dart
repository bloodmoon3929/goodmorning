import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_state.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import 'auth_view_model.dart';

/// 4. 로그인 — 앱을 처음 열거나 로그아웃 상태일 때. UI 시안 표지와 같은 구성:
/// 굿즈 스티커 · 로고 · "촬영 → 키링" 그림 · SNS 4개 · 로그인 없이 모아보기
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  static const sns = [
    _Sns('카카오', Color(0xFFFEE500), null),
    _Sns('네이버', Color(0xFF03C75A), null),
    _Sns('구글', AppColors.white, Color(0xFFDADCE0)),
    _Sns('Apple', Color(0xFF222222), null),
  ];

  void _sns(BuildContext context, String name) {
    // SNS 첫 로그인이면 IP 고르기 단계로 바로
    context.go(
      '/signup/ip',
      extra: SignupDraft(sns: name, email: 'goods@example.com'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.cardLine, width: 1.2),
              ),
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
              child: Column(
                children: [
                  const _StickerRow(),
                  const SizedBox(height: 18),
                  Semantics(
                    label: '굿즈 모으는 닝겐들',
                    image: true,
                    child: ExcludeSemantics(child: Image.asset('assets/brand/logo.png', width: 282)),
                  ),
                  const SizedBox(height: 10),
                  ExcludeSemantics(child: Image.asset('assets/brand/hero.png', width: 196)),
                  const SizedBox(height: 18),
                  Text('SNS로 모으러 가기', style: AppText.section.copyWith(fontSize: 15)),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [for (final s in sns) _SnsButton(s, onTap: () => _sns(context, s.name))],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 72,
                    child: Stack(
                      children: [
                        Positioned(left: 0, bottom: 0, child: ExcludeSemantics(child: Image.asset('assets/brand/bear.png', height: 64))),
                        Positioned(right: 0, bottom: 4, child: ExcludeSemantics(child: Image.asset('assets/brand/photocard.png', height: 56))),
                        Align(
                          alignment: const Alignment(0, 0.55),
                          child: TextButton(
                            onPressed: () {
                              AppScope.read(context).browseAsGuest();
                              context.go('/home');
                            },
                            child: Text(
                              '로그인 없이 모아보기',
                              style: AppText.body.copyWith(decoration: TextDecoration.underline, decorationColor: AppColors.ink),
                            ),
                          ),
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

class _StickerRow extends StatelessWidget {
  const _StickerRow();

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Image.asset('assets/brand/gacha.png', width: 90),
        const SizedBox(width: 2),
        Expanded(child: Image.asset('assets/brand/kuji.png', height: 68)),
        const SizedBox(width: 6),
        Image.asset('assets/brand/itabag.png', width: 100),
      ],
    ),
  );
}

class _Sns {
  const _Sns(this.name, this.color, this.border);
  final String name;
  final Color color;
  final Color? border;
}

class _SnsButton extends StatelessWidget {
  const _SnsButton(this.sns, {required this.onTap});

  final _Sns sns;
  final VoidCallback onTap;

  Widget _mark() => switch (sns.name) {
    '카카오' => const Icon(Icons.chat_bubble_rounded, size: 20, color: Color(0xFF3A1D1D)),
    '네이버' => const Text(
      'N',
      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.white, height: 1),
    ),
    '구글' => const Text(
      'G',
      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF3C6FD8), height: 1),
    ),
    _ => const Icon(Icons.apple, size: 22, color: AppColors.white),
  };

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '${sns.name}로 시작하기',
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: sns.color,
                shape: BoxShape.circle,
                border: sns.border == null ? null : Border.all(color: sns.border!),
              ),
              child: ExcludeSemantics(child: _mark()),
            ),
            const SizedBox(height: 7),
            ExcludeSemantics(child: Text(sns.name, style: AppText.label)),
          ],
        ),
      ),
    ),
  );
}
