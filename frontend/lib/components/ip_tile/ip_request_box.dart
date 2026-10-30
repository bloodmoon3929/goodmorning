import 'package:flutter/material.dart';

import 'ip_tile.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// 찾는 IP가 없을 때 추가 요청 → 관리자 확인 후 추가되고 알림으로 알려 준다.
/// 회원가입 IP 고르기와 IP 목록 조정이 함께 쓴다.
class IpRequestBox extends StatelessWidget {
  const IpRequestBox({super.key, required this.requested, required this.onRequest});

  final Set<String> requested;
  final ValueChanged<String> onRequest;

  Future<void> _ask(BuildContext context) async {
    final c = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('IP 추가 요청', style: AppText.title),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration: const InputDecoration(hintText: '예: 스누피, 원신'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('보내기')),
        ],
      ),
    );
    if (name != null && name.trim().isNotEmpty) {
      onRequest(name);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('‘${name.trim()}’ 추가를 요청했어요. 확인되면 알림으로 알려 드려요')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: DashedRRectPainter(radius: 12),
    child: InkWell(
      onTap: () => _ask(context),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('찾는 IP가 없나요?', style: AppText.bodyStrong),
                  const SizedBox(height: 2),
                  Text(requested.isEmpty ? 'IP 이름을 보내 주시면 확인 후 추가해요' : '요청함: ${requested.join(', ')}', style: AppText.caption),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: AppColors.orangeBg, borderRadius: BorderRadius.circular(99)),
              child: const Text(
                '추가 요청 +',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.orange),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
