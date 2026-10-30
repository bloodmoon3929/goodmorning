import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../components/bottom_tab_bar/bottom_tab_bar.dart';

/// 하단 탭 화면. 탭을 오가도 화면을 처음부터 다시 만들지 않는다 (IndexedStack).
class ShellScreen extends StatelessWidget {
  const ShellScreen({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: shell,
    bottomNavigationBar: BottomTabBar(
      currentIndex: shell.currentIndex,
      // 지금 탭을 한 번 더 누르면 그 탭의 첫 화면으로
      onTap: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
    ),
  );
}
