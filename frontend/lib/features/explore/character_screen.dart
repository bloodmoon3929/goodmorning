import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_state.dart';
import '../../components/channel_badge/channel_badge.dart';
import '../../components/channel_filter/channel_filter.dart';
import '../../components/goods_thumb/goods_thumb.dart';
import '../../components/section_header/section_header.dart';
import '../../components/skeleton/skeleton.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/catalog.dart';
import '../../models/sales.dart';
import '../../models/search.dart';
import 'explore_view_model.dart';

/// 14. 캐릭터 화면 — IP 화면에서 캐릭터를 고르면 보이는 화면 (예: 쿠로미)
class CharacterScreen extends StatefulWidget {
  const CharacterScreen({super.key, required this.characterId});

  final String characterId;

  @override
  State<CharacterScreen> createState() => _CharacterScreenState();
}

class _CharacterScreenState extends State<CharacterScreen> {
  late final vm = CharacterViewModel(AppScope.read(context), widget.characterId);

  @override
  void dispose() {
    vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final channel = AppScope.of(context).channel;
    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: Text(vm.detail.valueOrNull?.character.name ?? '')),
        body: LoadView<CharacterDetail>(
          load: vm.detail,
          onRetry: vm.reload,
          skeleton: const Column(children: [SizedBox(height: 16), SkeletonRows(count: 1, thumb: 64), SkeletonProductGrid(rows: 2)]),
          builder: (d) {
            final c = d.character;
            return ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: Row(
                    children: [
                      GoodsThumb(emoji: c.emoji, bg: c.bg, size: 64, circle: true, emojiScale: 0.62),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(c.name, style: AppText.display.copyWith(fontSize: 20)),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () => context.pop(),
                                  child: Text(d.ip.name, style: AppText.label.copyWith(color: AppColors.blue)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text('굿즈 ${d.goodsCount}개 · 온라인 ${d.onlineCount} · 근처 매장 ${d.nearbyCount}', style: AppText.caption.copyWith(fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Padding(padding: EdgeInsets.fromLTRB(16, 16, 16, 0), child: ChannelFilter()),
                for (final entry in d.groups.entries)
                  ..._group(
                    entry.key,
                    entry.value
                        .where(
                          (p) => switch (channel) {
                            Channel.all => true,
                            Channel.online => p.channels.hasOnline,
                            Channel.offline => p.channels.hasOffline,
                          },
                        )
                        .toList(),
                    c.name,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _group(GoodsCategory cat, List<ProductSummary> items, String name) {
    if (items.isEmpty) return const [];
    return [
      SectionHeader(
        '${cat.label} ${items.length}',
        more: '전체',
        onMore: () => context.push('/explore/search?q=$name&cat=${cat.name}&sort=${SearchSort.popular.name}'),
      ),
      SizedBox(
        height: 168,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(width: 10),
          itemBuilder: (_, i) {
            final p = items[i];
            return SizedBox(
              width: 112,
              child: InkWell(
                onTap: () => context.push('/product/${p.product.id}'),
                borderRadius: BorderRadius.circular(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GoodsThumb(emoji: p.product.emoji, bg: p.product.bg, width: 112, height: 84, radius: 12),
                    const SizedBox(height: 6),
                    Text(
                      p.product.name.replaceFirst('$name ', ''),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.bodyStrong.copyWith(fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    ChannelBadges(p.channels, compact: true, size: 10),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ];
  }
}
