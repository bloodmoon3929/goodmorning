import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_state.dart';
import '../../components/buttons/app_button.dart';
import '../../components/emoji/emoji_image.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import 'auth_view_model.dart';

/// 4. 로그인 — 앱을 처음 열거나 로그아웃 상태일 때
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final vm = LoginViewModel();
  late final _email = TextEditingController(text: vm.email);
  late final _password = TextEditingController(text: vm.password);

  @override
  void dispose() {
    vm.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    await vm.submit();
    if (!mounted) return;
    AppScope.read(context).login(email: vm.email);
    context.go('/home');
  }

  void _sns(String name) {
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
        child: ListenableBuilder(
          listenable: vm,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            children: [
              const SizedBox(height: 48),
              const Center(child: EmojiImage('sunrise', size: 80)),
              const SizedBox(height: 10),
              Center(
                child: Text('굿모닝', style: AppText.display.copyWith(fontSize: 34, color: AppColors.orange)),
              ),
              Center(
                child: Text('굿즈 모으는 닝겐', style: AppText.body.copyWith(color: AppColors.sub)),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(hintText: '이메일'),
                onChanged: (v) {
                  vm.email = v;
                  vm.notify();
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(hintText: '비밀번호'),
                onChanged: (v) {
                  vm.password = v;
                  vm.notify();
                },
                onSubmitted: (_) => vm.canSubmit ? _login() : null,
              ),
              const SizedBox(height: 16),
              AppButton('로그인', busy: vm.busy, onPressed: vm.canSubmit ? _login : null),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('가입한 이메일로 비밀번호 재설정 링크를 보냈어요 (프로토타입)'))),
                    child: Text('비밀번호 찾기', style: AppText.label.copyWith(color: AppColors.sub)),
                  ),
                  Text('·', style: AppText.caption),
                  TextButton(
                    onPressed: () => context.push('/signup'),
                    child: Text(
                      '회원가입',
                      style: AppText.label.copyWith(color: AppColors.ink, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text('SNS로 시작하기', style: AppText.caption),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 14),
              AppButton('카카오로 시작하기', height: 48, radius: 12, color: const Color(0xFFFEE500), textColor: const Color(0xFF191919), onPressed: () => _sns('카카오')),
              const SizedBox(height: 8),
              AppButton('네이버로 시작하기', height: 48, radius: 12, color: const Color(0xFF03C75A), onPressed: () => _sns('네이버')),
              const SizedBox(height: 8),
              AppButton('Apple로 시작하기', height: 48, radius: 12, color: Colors.black, onPressed: () => _sns('Apple')),
              const SizedBox(height: 18),
              Center(
                child: TextButton(
                  onPressed: () {
                    AppScope.read(context).browseAsGuest();
                    context.go('/home');
                  },
                  child: Text('로그인 없이 둘러보기 ›', style: AppText.label.copyWith(color: AppColors.sub)),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
