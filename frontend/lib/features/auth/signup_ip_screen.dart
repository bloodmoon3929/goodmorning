import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_state.dart';
import '../../components/buttons/app_button.dart';
import '../../components/chips/app_chip.dart';
import '../../components/ip_tile/ip_tile.dart';
import '../../components/skeleton/skeleton.dart';
import '../../core/theme/app_theme.dart';
import '../../models/catalog.dart';
import 'auth_view_model.dart';
import '../../components/ip_tile/ip_request_box.dart';
import 'widgets/signup_steps.dart';

/// 6. 회원가입 · IP 고르기 — 고른 IP만 홈과 굿즈 탐색에 보인다
class SignupIpScreen extends StatefulWidget {
  const SignupIpScreen({super.key, this.draft});

  final SignupDraft? draft;

  @override
  State<SignupIpScreen> createState() => _SignupIpScreenState();
}

class _SignupIpScreenState extends State<SignupIpScreen> {
  late final vm = IpPickViewModel(AppScope.read(context).api);

  @override
  void dispose() {
    vm.dispose();
    super.dispose();
  }

  void _start() {
    final d = widget.draft ?? const SignupDraft();
    AppScope.read(context).signUp(email: d.email.isEmpty ? 'goods@example.com' : d.email, nickname: d.nickname, region: d.region, ips: vm.selected);
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final sns = widget.draft?.sns;
    return Scaffold(
      appBar: AppBar(title: Text(sns == null ? '회원가입' : '$sns로 시작하기')),
      body: ListenableBuilder(
        listenable: vm,
        builder: (context, _) => Column(
          children: [
            const SignupSteps(active: 2),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  const Text('좋아하는 IP를 골라 주세요', style: AppText.display),
                  const SizedBox(height: 4),
                  const Text('고른 IP의 굿즈만 보여요 · 나중에 바꿀 수 있어요', style: AppText.caption),
                  const SizedBox(height: 14),
                  TextField(
                    onChanged: vm.setQuery,
                    decoration: const InputDecoration(hintText: 'IP · 캐릭터 이름 검색 (먼작귀도 돼요)', prefixIcon: Icon(Icons.search_rounded)),
                  ),
                  const SizedBox(height: 12),
                  ChipRow(
                    padding: EdgeInsets.zero,
                    children: [
                      AppChip('전체', selected: vm.kind == null, onTap: () => vm.setKind(null)),
                      for (final k in IpKind.values) AppChip(k.label, selected: vm.kind == k, onTap: () => vm.setKind(k)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  LoadView<List<Ip>>(
                    load: vm.ips,
                    onRetry: vm.reload,
                    skeleton: const SkeletonCards(count: 3, height: 104),
                    builder: (all) {
                      final list = vm.visible(all);
                      if (list.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(24),
                          child: Center(child: Text('찾는 IP가 없어요', style: AppText.caption)),
                        );
                      }
                      return GridView.count(
                        crossAxisCount: 3,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.98,
                        children: [for (final ip in list) IpTileGrid(ip: ip, selected: vm.selected.contains(ip.id), onTap: () => vm.toggle(ip.id))],
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  IpRequestBox(requested: vm.requested, onRequest: vm.request),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: AppButton(
                  vm.selected.isEmpty ? 'IP를 1개 이상 골라 주세요' : '${vm.selected.length}개 선택 · 굿모닝 시작하기',
                  onPressed: vm.selected.isEmpty ? null : _start,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
