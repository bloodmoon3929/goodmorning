import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_state.dart';
import '../../components/buttons/app_button.dart';
import '../../components/emoji/emoji_image.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import 'auth_view_model.dart';
import 'widgets/signup_steps.dart';

/// 5. 회원가입 · 계정 정보
class SignupAccountScreen extends StatefulWidget {
  const SignupAccountScreen({super.key});

  @override
  State<SignupAccountScreen> createState() => _SignupAccountScreenState();
}

class _SignupAccountScreenState extends State<SignupAccountScreen> {
  late final vm = SignupAccountViewModel(AppScope.read(context).api);

  @override
  void dispose() {
    vm.dispose();
    super.dispose();
  }

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(top: 14, bottom: 6),
    child: Text(t, style: AppText.bodyStrong.copyWith(fontSize: 13)),
  );

  Widget _check(String label, bool on, VoidCallback onTap, {bool bold = false}) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: on ? AppColors.orange : AppColors.white,
              border: Border.all(color: on ? AppColors.orange : AppColors.line, width: 1.5),
            ),
            child: Icon(Icons.check_rounded, size: 15, color: on ? AppColors.white : AppColors.line),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: bold ? AppText.bodyStrong.copyWith(fontSize: 15) : AppText.body.copyWith(fontSize: 13.5))),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('회원가입')),
      body: ListenableBuilder(
        listenable: vm,
        builder: (context, _) {
          final emailMsg = switch (vm.emailCheck) {
            EmailCheck.ok => ('사용할 수 있는 이메일이에요', AppColors.green),
            EmailCheck.taken => ('이미 가입한 이메일이에요. 로그인으로 가 주세요', AppColors.red),
            _ => null,
          };
          return Column(
            children: [
              const SignupSteps(active: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _label('이메일'),
                    TextField(
                      keyboardType: TextInputType.emailAddress,
                      onChanged: vm.setEmail,
                      decoration: InputDecoration(
                        hintText: 'goods@example.com',
                        suffixIcon: Padding(
                          padding: const EdgeInsets.all(6),
                          child: AppButton(
                            '중복 확인',
                            kind: AppButtonKind.secondary,
                            expand: false,
                            height: 34,
                            fontSize: 12,
                            busy: vm.emailCheck == EmailCheck.checking,
                            onPressed: vm.email.contains('@') ? vm.checkEmail : null,
                          ),
                        ),
                      ),
                    ),
                    if (emailMsg != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6, left: 2),
                        child: Text(emailMsg.$1, style: AppText.caption.copyWith(color: emailMsg.$2)),
                      ),
                    if (emailMsg?.$2 == AppColors.red)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(onPressed: () => context.go('/login'), child: const Text('로그인으로')),
                      ),
                    _label('비밀번호'),
                    TextField(
                      obscureText: true,
                      onChanged: vm.setPassword,
                      decoration: const InputDecoration(hintText: '영문 · 숫자 포함 8자 이상'),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 6, left: 2),
                      child: Text(
                        '${vm.passwordOk ? '✓ ' : ''}영문 · 숫자 포함 8자 이상',
                        style: AppText.caption.copyWith(color: vm.passwordOk ? AppColors.green : AppColors.sub, fontWeight: FontWeight.w500),
                      ),
                    ),
                    _label('비밀번호 확인'),
                    TextField(
                      obscureText: true,
                      onChanged: vm.setConfirm,
                      decoration: const InputDecoration(hintText: '한 번 더 입력'),
                    ),
                    if (vm.confirm.isNotEmpty && !vm.confirmOk)
                      Padding(
                        padding: const EdgeInsets.only(top: 6, left: 2),
                        child: Text('비밀번호가 같지 않아요', style: AppText.caption.copyWith(color: AppColors.red)),
                      ),
                    _label('닉네임'),
                    TextField(
                      onChanged: vm.setNickname,
                      decoration: const InputDecoration(hintText: '문의 · 제보에 보이는 이름'),
                    ),
                    _label('동네 (선택)'),
                    OutlinedButton(
                      onPressed: vm.useCurrentLocation,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        alignment: Alignment.centerLeft,
                        side: const BorderSide(color: AppColors.line),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Row(
                        children: [
                          const EmojiImage('pin', size: 18),
                          const SizedBox(width: 8),
                          Text(vm.region == null ? '현재 위치로 설정' : '현재 위치로 설정 · ${vm.region}', style: AppText.label),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4, left: 2),
                      child: Text('내 주변 재고의 기준 위치예요. 나중에 바꿀 수 있어요', style: AppText.tiny),
                    ),
                    const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Divider()),
                    _check('전체 동의', vm.allAgreed, vm.toggleAll, bold: true),
                    _check('이용약관 (필수)', vm.terms, () => vm.toggle('terms')),
                    _check('개인정보 처리방침 (필수)', vm.privacy, () => vm.toggle('privacy')),
                    _check('위치 정보 이용 (선택) · 내 주변 재고', vm.location, () => vm.toggle('location')),
                    _check('알림 받기 (선택) · 가격 하락 · 재입고', vm.alerts, () => vm.toggle('alerts')),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: AppButton('다음 · IP 고르기', onPressed: vm.canNext ? () => context.push('/signup/ip', extra: vm.draft) : null),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
