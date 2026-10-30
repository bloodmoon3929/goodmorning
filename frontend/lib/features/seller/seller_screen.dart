import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_state.dart';
import '../../components/buttons/app_button.dart';
import '../../components/channel_badge/channel_badge.dart';
import '../../components/emoji/emoji_image.dart';
import '../../components/goods_thumb/goods_thumb.dart';
import '../../components/photo_pick/photo_pick_sheet.dart';
import '../../components/skeleton/skeleton.dart';
import '../../components/stock_badge/stock_badge.dart';
import '../../core/network/load_state.dart';
import '../../core/network/mock_data.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/account.dart';
import '../../models/sales.dart';
import 'seller_view_model.dart';
import 'widgets/stock_segment.dart';

/// 24. 판매자 센터 · 재고 관리 / 25. 상품 등록 — 사장님 계정 · 마이 → 판매자 센터
class SellerScreen extends StatefulWidget {
  const SellerScreen({super.key});

  @override
  State<SellerScreen> createState() => _SellerScreenState();
}

class _SellerScreenState extends State<SellerScreen> with SingleTickerProviderStateMixin {
  late final vm = SellerViewModel(AppScope.read(context));
  late final tabs = TabController(length: 4, vsync: this);

  @override
  void dispose() {
    vm.dispose();
    tabs.dispose();
    super.dispose();
  }

  void _toast(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  void _backToUser() => context.canPop() ? context.pop() : context.go('/my');

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        final storeName = MockData.stores.firstWhere((s) => s.id == vm.storeId).name;
        return Scaffold(
          appBar: AppBar(
            title: const Text('판매자 센터'),
            actions: [
              PopupMenuButton<String>(
                tooltip: '매장 바꾸기',
                initialValue: vm.storeId,
                onSelected: vm.switchStore,
                itemBuilder: (_) => [
                  for (final id in SellerViewModel.myStores) PopupMenuItem(value: id, child: Text(MockData.stores.firstWhere((s) => s.id == id).name)),
                ],
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Text(storeName, style: AppText.bodyStrong),
                      const Icon(Icons.arrow_drop_down_rounded),
                    ],
                  ),
                ),
              ),
            ],
            bottom: TabBar(
              controller: tabs,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: AppColors.ink,
              unselectedLabelColor: AppColors.sub,
              labelStyle: AppText.bodyStrong.copyWith(fontWeight: FontWeight.w700),
              unselectedLabelStyle: AppText.body.copyWith(fontWeight: FontWeight.w500),
              indicatorColor: AppColors.orange,
              indicatorSize: TabBarIndicatorSize.label,
              dividerColor: AppColors.line,
              tabs: [
                const Tab(text: '재고 관리'),
                const Tab(text: '상품 등록'),
                Tab(text: vm.reports.isEmpty ? '제보' : '제보 ${vm.reports.length}'),
                const Tab(text: '매장 정보'),
              ],
            ),
          ),
          body: LoadView<SellerStore>(
            load: vm.store,
            onRetry: vm.reload,
            skeleton: const Padding(padding: EdgeInsets.only(top: 16), child: SkeletonRows(count: 6, thumb: 40)),
            builder: (s) => TabBarView(controller: tabs, children: [_inventory(), _register(), _reports(), _info(s.store)]),
          ),
        );
      },
    );
  }

  // ------------------------------------------------------------ 24. 재고 관리
  Widget _inventory() {
    final n = vm.edits.length;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            children: [
              Material(
                color: AppColors.greenBg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: AppColors.green),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: vm.saving
                      ? null
                      : () async {
                          await vm.confirmAll();
                          _toast('전 품목 확인 시각을 지금으로 바꿨어요');
                        },
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        const EmojiImage('check', size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('오늘 재고 그대로예요', style: AppText.section.copyWith(color: AppColors.green)),
                              const SizedBox(height: 2),
                              Text('상태는 그대로, 전 품목 확인 시각만 지금으로', style: AppText.caption.copyWith(color: AppColors.green)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text('마지막 확인: ${vm.lastConfirmed} · 품목 ${vm.totalItems}개', style: AppText.caption),
              const SizedBox(height: 8),
              for (final it in vm.items) _invRow(it),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Column(
              children: [
                AppButton(
                  n == 0 ? '변경 저장' : '변경 저장 ($n건)',
                  busy: vm.saving,
                  onPressed: n == 0
                      ? null
                      : () async {
                          final saved = await vm.save();
                          _toast('$saved건을 저장했어요. 사용자 화면에 바로 반영돼요');
                        },
                ),
                TextButton(
                  onPressed: _backToUser,
                  child: Text('사용자 화면으로 돌아가기', style: AppText.label.copyWith(color: AppColors.sub)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _invRow(InventoryItem it) {
    final changed = vm.changed(it);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      decoration: BoxDecoration(color: changed ? AppColors.unreadBg : Colors.transparent, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(it.product.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.bodyStrong),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(it.variant.label, style: AppText.caption),
                    if (changed) ...[const SizedBox(width: 6), const Pill('변경', fg: AppColors.orange, bg: AppColors.orangeBg, size: 10)],
                  ],
                ),
              ],
            ),
          ),
          StockSegment(value: vm.statusOf(it), onChanged: (s) => vm.setStatus(it, s)),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ 25. 상품 등록
  Widget _register() {
    final photo = MockData.photos.where((p) => p.id == vm.photoId).firstOrNull;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        const _Step(1, '사진 올리기'),
        if (photo == null)
          _PhotoDrop(onTap: _pickPhoto)
        else
          Stack(
            children: [
              GoodsThumb(emoji: photo.emoji, bg: photo.bg, width: double.infinity, height: 120, radius: 14, emojiScale: 0.6),
              Positioned(
                right: 10,
                bottom: 10,
                child: GestureDetector(
                  onTap: _pickPhoto,
                  child: const Pill('다시 찍기', fg: AppColors.ink, bg: AppColors.white, size: 12, border: AppColors.line),
                ),
              ),
            ],
          ),
        const SizedBox(height: 8),
        Text('박스 앞면이 잘 보이게 찍어 주세요', style: AppText.caption),
        const SizedBox(height: 14),
        const Text('상품명 (선택)', style: AppText.bodyStrong),
        const SizedBox(height: 8),
        TextField(
          onChanged: vm.setName,
          decoration: const InputDecoration(hintText: '예) RG 건담'),
        ),
        const SizedBox(height: 22),
        const _Step(2, '같은 굿즈 고르기'),
        switch (vm.candidates) {
          null => Text('사진을 올리면 AI가 같은 굿즈 후보를 찾아 드려요', style: AppText.caption),
          Loading() => const SkeletonRows(count: 3, thumb: 44),
          LoadFailed() => Text('후보를 찾지 못했어요. 사진을 다시 올려 주세요', style: AppText.caption.copyWith(color: AppColors.red)),
          Loaded(value: final list) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AI가 찾은 후보',
                style: AppText.label.copyWith(color: AppColors.sub, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < list.length; i++) _candidate(list[i], i),
              if (vm.versionWarning case final w?) ...[
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.amberBg, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const EmojiImage('warning', size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          w,
                          style: AppText.caption.copyWith(color: AppColors.amber, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              TextButton(
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                onPressed: () => _toast('새 굿즈 요청을 보냈어요. 등록되면 알려 드려요'),
                child: Text('찾는 굿즈가 없어요 → 새 굿즈 요청 ›', style: AppText.label.copyWith(color: AppColors.blue)),
              ),
            ],
          ),
        },
        const SizedBox(height: 16),
        const _Step(3, '재고 · 판매가'),
        Row(
          children: [
            StockSegment(value: vm.newStatus, onChanged: vm.setNewStatus, width: 200, height: 40),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                onChanged: vm.setPrice,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(hintText: '판매가', suffixText: '원', isDense: true),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        AppButton(
          '내 매장에 추가',
          busy: vm.saving,
          onPressed: vm.canRegister
              ? () async {
                  final added = await vm.register();
                  tabs.animateTo(0);
                  _toast('$added을(를) 재고 관리에 추가했어요');
                }
              : null,
        ),
        TextButton(
          onPressed: _backToUser,
          child: Text('사용자 화면으로 돌아가기', style: AppText.label.copyWith(color: AppColors.sub)),
        ),
      ],
    );
  }

  Future<void> _pickPhoto() async {
    final id = await showPhotoPickSheet(context, title: '상품 사진 올리기', subtitle: '박스 앞면이 잘 보이게 찍어 주세요');
    if (id != null) vm.pickPhoto(id);
  }

  Widget _candidate(RegisterCandidate c, int i) {
    final on = vm.picked == i;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: on ? AppColors.orangeBg : AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: on ? AppColors.orange : AppColors.line, width: on ? 2 : 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => vm.pick(i),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Icon(on ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: on ? AppColors.orange : AppColors.line),
                const SizedBox(width: 8),
                GoodsThumb(emoji: c.product.emoji, bg: c.product.bg, size: 44, radius: 10),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.product.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.bodyStrong),
                      const SizedBox(height: 4),
                      Pill(c.variant.label, fg: AppColors.orange, bg: on ? AppColors.white : AppColors.orangeBg, size: 10),
                    ],
                  ),
                ),
                Text('${c.similarity}%', style: AppText.section.copyWith(color: on ? AppColors.orange : AppColors.sub)),
                const SizedBox(width: 6),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------ 제보 · 매장 정보
  Widget _reports() {
    if (vm.reports.isEmpty) {
      return Center(
        child: Text('확인할 제보가 없어요', style: AppText.body.copyWith(color: AppColors.sub)),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('손님이 보낸 재고 제보예요. 반영하면 재고 관리에서 [변경 저장]으로 확정돼요', style: AppText.caption),
        const SizedBox(height: 12),
        for (final r in vm.reports)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text('${r.item.product.name} · ${r.item.variant.label}', style: AppText.bodyStrong)),
                    StockBadge(r.status),
                  ],
                ),
                const SizedBox(height: 4),
                Text('지금 등록: ${r.item.status.label} · ${r.label}', style: AppText.caption),
                const SizedBox(height: 10),
                Row(
                  children: [
                    AppButton(
                      '반영',
                      expand: false,
                      height: 32,
                      fontSize: 12,
                      onPressed: () {
                        vm.applyReport(r);
                        tabs.animateTo(0);
                      },
                    ),
                    const SizedBox(width: 8),
                    AppButton('넘기기', kind: AppButtonKind.secondary, expand: false, height: 32, fontSize: 12, onPressed: () => vm.dismissReport(r)),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _info(Store s) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      for (final (label, value) in [('매장', s.name), ('종류', s.kind), ('주소', s.address), ('영업', s.hours), ('전화', s.phone)])
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 52,
                child: Text(label, style: AppText.label.copyWith(color: AppColors.sub)),
              ),
              Expanded(child: Text(value, style: AppText.label)),
            ],
          ),
        ),
      Text(s.infoSource, style: AppText.tiny),
      const SizedBox(height: 16),
      AppButton('매장 정보 수정', kind: AppButtonKind.secondary, height: 46, onPressed: () => _toast('매장 정보 수정은 다음 단계에서 열려요')),
    ],
  );
}

class _Step extends StatelessWidget {
  const _Step(this.n, this.title);
  final int n;
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: AppColors.orange, shape: BoxShape.circle),
          child: Text(
            '$n',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.white),
          ),
        ),
        const SizedBox(width: 8),
        Text(title, style: AppText.section),
      ],
    ),
  );
}

class _PhotoDrop extends StatelessWidget {
  const _PhotoDrop({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '사진 올리기',
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 120,
        decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(14)),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            EmojiImage('camera_flash', size: 40),
            SizedBox(height: 8),
            Text('사진 찍기 · 앨범에서 고르기', style: AppText.label),
          ],
        ),
      ),
    ),
  );
}
