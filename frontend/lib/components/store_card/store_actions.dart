import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../models/sales.dart';
import '../buttons/app_button.dart';
import '../external_move/external_move.dart';

/// 길찾기 · 전화 · 저장: 상품 상세의 오프라인 매장, 매장 찾기 리스트 · 지도에서 함께 쓴다.
class StoreActions extends StatelessWidget {
  const StoreActions({super.key, required this.store, this.showSave = true, this.height = 32});

  final Store store;
  final bool showSave;
  final double height;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final saved = state.savedStores.contains(store.id);
    return Row(
      children: [
        AppButton(
          '길찾기',
          kind: AppButtonKind.secondary,
          expand: false,
          height: height,
          fontSize: 12,
          onPressed: () => showExternalMove(context, kind: ExternalKind.map, target: store.name),
        ),
        const SizedBox(width: 6),
        AppButton(
          '전화',
          kind: AppButtonKind.secondary,
          expand: false,
          height: height,
          fontSize: 12,
          onPressed: () => showExternalMove(context, kind: ExternalKind.phone, target: store.name, detail: store.phone),
        ),
        if (showSave) ...[
          const SizedBox(width: 6),
          AppButton(
            saved ? '저장됨' : '저장',
            kind: saved ? AppButtonKind.soft : AppButtonKind.secondary,
            icon: saved ? 'star' : null,
            expand: false,
            height: height,
            fontSize: 12,
            onPressed: () => state.toggleSavedStore(store.id),
          ),
        ],
      ],
    );
  }
}
