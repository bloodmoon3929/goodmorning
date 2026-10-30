import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_state.dart';
import '../../components/channel_filter/channel_filter.dart';
import '../../components/emoji/emoji_image.dart';
import '../../components/ip_tile/ip_tile.dart';
import '../../components/section_header/section_header.dart';
import '../../components/skeleton/skeleton.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/catalog.dart';
import '../../models/search.dart';
import 'explore_view_model.dart';

/// 8. 굿즈 탐색 — 품목이나 IP로 굿즈를 찾아 들어가는 화면
class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  late final vm = ExploreViewModel(AppScope.read(context));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    AppScope.of(context);
    vm.loadIfNeeded();
  }

  @override
  void dispose() {
    vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: vm,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Text('굿즈 탐색', style: AppText.display),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Material(
                  color: AppColors.bg,
                  shape: const StadiumBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => context.push('/explore/search'),
                    child: const Padding(
                      padding: EdgeInsets.fromLTRB(18, 13, 16, 13),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text('캐릭터 · IP 이름 검색 (예: 먼작귀)', style: TextStyle(fontSize: 14, color: AppColors.sub)),
                          ),
                          Icon(Icons.search_rounded, color: AppColors.sub),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const Padding(padding: EdgeInsets.fromLTRB(16, 12, 16, 0), child: ChannelFilter()),
              const SectionHeader('품목으로 보기'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    for (final c in GoodsCategory.values)
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => context.push('/explore/search?cat=${c.name}&sort=${SearchSort.popular.name}'),
                          child: Column(
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(14)),
                                alignment: Alignment.center,
                                child: EmojiImage(c.emoji, size: 32),
                              ),
                              const SizedBox(height: 6),
                              Text(c.label, style: AppText.label.copyWith(fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SectionHeader('내 IP', sub: '회원가입 때 고른 IP'),
              LoadView<List<IpStat>>(
                load: vm.stats,
                onRetry: vm.reload,
                skeleton: const SkeletonCards(count: 3, height: 124),
                builder: (stats) => GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.86,
                  children: [
                    for (final s in stats)
                      IpTileGrid(ip: s.ip, sub: '캐릭터 ${s.characterCount} · 굿즈 ${s.goodsCount}', onTap: () => context.push('/explore/ip/${s.ip.id}')),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/ip-manage'),
                  icon: const EmojiImage('gear', size: 20),
                  label: const Text('IP 목록 조정', style: AppText.bodyStrong),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                    side: const BorderSide(color: AppColors.line),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
