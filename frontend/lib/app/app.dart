import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/cache/cached_api.dart';
import '../core/network/goodmorning_api.dart';
import '../core/network/mock_api.dart';
import '../core/theme/app_theme.dart';
import 'app_state.dart';
import 'phone_frame.dart';
import 'router.dart';

/// 앱 시작점: API(목업 + 캐시), 사용자 상태, 화면 이동, 테마를 묶는다.
class GoodmorningApp extends StatefulWidget {
  const GoodmorningApp({super.key, this.api});

  final GoodmorningApi? api; // 테스트에서는 지연 없는 목업을 넣는다

  @override
  State<GoodmorningApp> createState() => _GoodmorningAppState();
}

class _GoodmorningAppState extends State<GoodmorningApp> {
  late final AppState _state = AppState(api: CachedApi(widget.api ?? MockGoodmorningApi()))..startFrom(Uri.base);
  late final GoRouter _router = buildRouter(_state);

  @override
  void dispose() {
    _router.dispose();
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppScope(
    state: _state,
    child: MaterialApp.router(
      title: '굿모닝',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routerConfig: _router,
      builder: (context, child) => PhoneFrame(child: child ?? const SizedBox.shrink()),
    ),
  );
}
