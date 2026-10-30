import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_state.dart';
import '../../components/channel_badge/channel_badge.dart';
import '../../components/emoji/emoji_image.dart';
import '../../components/goods_thumb/goods_thumb.dart';
import '../../components/ip_tile/ip_tile.dart';
import '../../components/photo_pick/photo_pick_sheet.dart';
import '../../components/product_card/product_card.dart';
import '../../components/skeleton/skeleton.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/account.dart';
import 'photo_search_view_model.dart';

/// 11. 사진 검색 결과 — 홈의 📷 으로 사진을 올린 뒤 보이는 화면
class PhotoSearchScreen extends StatefulWidget {
  const PhotoSearchScreen({super.key, required this.photoId});

  final String photoId;

  @override
  State<PhotoSearchScreen> createState() => _PhotoSearchScreenState();
}

class _PhotoSearchScreenState extends State<PhotoSearchScreen> {
  late final vm = PhotoSearchViewModel(AppScope.read(context).api, widget.photoId);
  final _cond = TextEditingController();

  @override
  void dispose() {
    vm.dispose();
    _cond.dispose();
    super.dispose();
  }

  Future<void> _retake() async {
    final id = await showPhotoPickSheet(context);
    if (id != null) {
      _cond.clear();
      vm.retake(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('사진 검색')),
      body: ListenableBuilder(
        listenable: vm,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            _photoBox(vm.result.valueOrNull?.photo),
            if (vm.result.valueOrNull?.versionWarning case final w?) _warning(w),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                controller: _cond,
                textInputAction: TextInputAction.search,
                onSubmitted: vm.addCondition,
                decoration: InputDecoration(
                  hintText: '+ 조건 추가 (예: 미니, 박스 ver.)',
                  suffixIcon: IconButton(tooltip: '조건으로 다시 찾기', icon: const Icon(Icons.search_rounded), onPressed: () => vm.addCondition(_cond.text)),
                ),
              ),
            ),
            if (vm.condition.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 6, 16, 0),
                child: Text('‘${vm.condition}’ 조건을 더해 다시 찾았어요', style: AppText.caption.copyWith(color: AppColors.orange)),
              ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 18, 16, 4),
              child: Text('비슷한 굿즈', style: AppText.section),
            ),
            LoadView<PhotoSearchResult>(
              load: vm.result,
              onRetry: vm.run,
              skeleton: const SkeletonRows(count: 3),
              builder: (r) => Column(
                children: [
                  for (final g in PhotoSearchViewModel.group(r.matches)) g.length > 1 ? _group(g) : _row(g.first, dim: g.first.similarity < 50),
                  if (r.matches.length > 1 && PhotoSearchViewModel.group(r.matches).any((g) => g.length > 1))
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '점선 안 = 같은 굿즈의 다른 버전',
                        style: AppText.caption.copyWith(color: AppColors.orange, fontWeight: FontWeight.w500),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _photoBox(SamplePhoto? p) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
    child: Stack(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: p == null
              ? const Shimmer(child: SkeletonBox(height: 140, radius: 14))
              : GoodsThumb(key: ValueKey(p.id), emoji: p.emoji, bg: p.bg, width: double.infinity, height: 140, radius: 14, emojiScale: 0.55),
        ),
        const Positioned(
          left: 10,
          top: 10,
          child: Pill('올린 사진', fg: AppColors.white, bg: AppColors.ink),
        ),
        Positioned(
          right: 10,
          bottom: 10,
          child: Material(
            color: AppColors.white,
            shape: const StadiumBorder(),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: _retake,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Text('다시 찍기', style: AppText.label),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _warning(String w) => Container(
    margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.amberBg,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFF2D58A)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const EmojiImage('warning', size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('비슷한 버전이 있어요', style: AppText.bodyStrong.copyWith(color: AppColors.amber)),
              const SizedBox(height: 2),
              Text(w, style: AppText.caption.copyWith(color: AppColors.amber)),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _group(List<PhotoMatch> g) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    child: CustomPaint(
      painter: DashedRRectPainter(radius: 14, color: AppColors.orange, dash: 6, gap: 4, strokeWidth: 1.6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(children: [for (final m in g) _row(m, inset: true)]),
      ),
    ),
  );

  Widget _row(PhotoMatch m, {bool dim = false, bool inset = false}) => ProductRow(
    item: m.summary,
    dim: dim,
    chip: Pill(m.variant.label, fg: AppColors.orange, bg: AppColors.orangeBg),
    trailing: Text('유사도 ${m.similarity}%', style: AppText.caption),
    onTap: () => context.push('/product/${m.summary.product.id}?v=${m.variant.id}'),
  );
}
