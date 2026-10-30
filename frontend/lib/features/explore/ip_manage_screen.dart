import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_state.dart';
import '../../components/buttons/app_button.dart';
import '../../components/goods_thumb/goods_thumb.dart';
import '../../components/ip_tile/ip_request_box.dart';
import '../../components/ip_tile/ip_tile.dart';
import '../../components/skeleton/skeleton.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/catalog.dart';
import '../auth/auth_view_model.dart';

/// 12. IP 목록 조정 — 홈의 [+ 추가], 굿즈 탐색의 [IP 목록 조정], 마이의 내 IP 에서 들어오는 화면
class IpManageScreen extends StatefulWidget {
  const IpManageScreen({super.key});

  @override
  State<IpManageScreen> createState() => _IpManageScreenState();
}

class _IpManageScreenState extends State<IpManageScreen> {
  late final vm = IpPickViewModel(AppScope.read(context).api, initial: AppScope.read(context).myIps);

  @override
  void dispose() {
    vm.dispose();
    super.dispose();
  }

  void _save() {
    AppScope.read(context).setMyIps(vm.selected);
    context.pop();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('내 IP ${vm.selected.length}개를 저장했어요')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('IP 목록 조정')),
      body: ListenableBuilder(
        listenable: vm,
        builder: (context, _) => Column(
          children: [
            Expanded(
              child: LoadView<List<Ip>>(
                load: vm.ips,
                onRetry: vm.reload,
                skeleton: const SkeletonRows(count: 6, thumb: 44),
                builder: (all) {
                  final byId = {for (final ip in all) ip.id: ip};
                  final others = vm.visible(all).where((ip) => !vm.selected.contains(ip.id)).toList();
                  return CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('홈과 굿즈 탐색에 보일 IP를 고르세요', style: AppText.body.copyWith(color: AppColors.sub)),
                              const SizedBox(height: 12),
                              TextField(
                                onChanged: vm.setQuery,
                                decoration: const InputDecoration(hintText: 'IP · 캐릭터 이름 검색', prefixIcon: Icon(Icons.search_rounded)),
                              ),
                              const SizedBox(height: 18),
                              Row(
                                children: [
                                  Text('내 IP ${vm.selected.length}', style: AppText.section),
                                  const Spacer(),
                                  Text('꾹 눌러 끌면 순서가 바뀌어요', style: AppText.caption),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      SliverReorderableList(
                        itemCount: vm.selected.length,
                        onReorderItem: vm.reorder,
                        itemBuilder: (context, i) {
                          final ip = byId[vm.selected[i]]!;
                          return ReorderableDelayedDragStartListener(
                            key: ValueKey(ip.id),
                            index: i,
                            child: Material(
                              color: AppColors.white,
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                                leading: GoodsThumb(emoji: ip.emoji, bg: ip.bg, size: 44, radius: 12),
                                title: Text(ip.name, style: AppText.bodyStrong),
                                subtitle: Text('${i + 1}번째로 보여요', style: AppText.tiny),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: '빼기',
                                      onPressed: () => vm.toggle(ip.id),
                                      icon: const CircleAvatar(
                                        radius: 11,
                                        backgroundColor: AppColors.orange,
                                        child: Icon(Icons.check_rounded, size: 15, color: AppColors.white),
                                      ),
                                    ),
                                    ReorderableDragStartListener(
                                      index: i,
                                      child: const Icon(Icons.drag_handle_rounded, color: AppColors.sub),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
                          child: Text('다른 IP', style: AppText.section),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverGrid.count(
                          crossAxisCount: 3,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.98,
                          children: [for (final ip in others) IpTileGrid(ip: ip, onTap: () => vm.toggle(ip.id))],
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: IpRequestBox(requested: vm.requested, onRequest: vm.request),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: AppButton('저장', onPressed: vm.selected.isEmpty ? null : _save),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
