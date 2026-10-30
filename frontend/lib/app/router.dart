import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/login_screen.dart';
import '../features/auth/signup_account_screen.dart';
import '../features/auth/auth_view_model.dart';
import '../features/auth/signup_ip_screen.dart';
import '../features/explore/character_screen.dart';
import '../features/explore/explore_screen.dart';
import '../features/explore/ip_manage_screen.dart';
import '../features/explore/ip_screen.dart';
import '../features/home/home_screen.dart';
import '../features/my/my_list_screen.dart';
import '../features/my/my_screen.dart';
import '../features/my/visit_history_screen.dart';
import '../features/notification/notification_screen.dart';
import '../features/product/product_screen.dart';
import '../features/search/photo_search_screen.dart';
import '../features/search/search_screen.dart';
import '../features/seller/seller_screen.dart';
import '../features/store/store_detail_screen.dart';
import '../features/store/store_finder_screen.dart';
import '../models/catalog.dart';
import '../models/search.dart';
import 'app_state.dart';
import 'shell_screen.dart';

/// 화면 이동 (docs/01-screen-flow.md 화면 흐름 그래프).
/// 하단 탭 4개는 StatefulShellRoute(IndexedStack)로 살려 두고, 상품 상세처럼 여러 곳에서 들어오는 화면은 탭 위에 띄운다.
GoRouter buildRouter(AppState state) {
  final rootKey = GlobalKey<NavigatorState>();

  Widget search(GoRouterState s) => SearchScreen(
    initialQuery: s.uri.queryParameters['q'] ?? '',
    category: GoodsCategory.values.where((c) => c.name == s.uri.queryParameters['cat']).firstOrNull,
    sort: SearchSort.values.where((v) => v.name == s.uri.queryParameters['sort']).firstOrNull ?? SearchSort.lowest,
  );

  return GoRouter(
    navigatorKey: rootKey,
    initialLocation: '/login',
    refreshListenable: state,
    redirect: (context, s) {
      final loc = s.matchedLocation;
      final inAuth = loc.startsWith('/login') || loc.startsWith('/signup');
      if (!state.started && !inAuth) return '/login';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: '/signup',
        builder: (_, _) => const SignupAccountScreen(),
        routes: [
          GoRoute(
            path: 'ip',
            builder: (_, s) => SignupIpScreen(draft: s.extra as SignupDraft?),
          ),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, s, shell) => ShellScreen(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (_, _) => const HomeScreen(),
                routes: [GoRoute(path: 'search', builder: (_, s) => search(s))],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/explore',
                builder: (_, _) => const ExploreScreen(),
                routes: [
                  GoRoute(path: 'search', builder: (_, s) => search(s)),
                  GoRoute(
                    path: 'ip/:ipId',
                    builder: (_, s) => IpScreen(ipId: s.pathParameters['ipId']!),
                    routes: [
                      GoRoute(
                        path: 'character/:charId',
                        builder: (_, s) => CharacterScreen(characterId: s.pathParameters['charId']!),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/stores',
                builder: (_, s) => StoreFinderScreen(initialMap: s.uri.queryParameters['view'] == 'map'),
                routes: [
                  GoRoute(
                    path: ':storeId',
                    builder: (_, s) => StoreDetailScreen(storeId: s.pathParameters['storeId']!),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/my',
                builder: (_, _) => const MyScreen(),
                routes: [
                  GoRoute(path: 'history', builder: (_, _) => const VisitHistoryScreen()),
                  GoRoute(
                    path: 'list/:kind',
                    builder: (_, s) => MyListScreen(kind: MyListKind.values.byName(s.pathParameters['kind']!)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(parentNavigatorKey: rootKey, path: '/notifications', builder: (_, _) => const NotificationScreen()),
      GoRoute(
        parentNavigatorKey: rootKey,
        path: '/photo-search/:photoId',
        builder: (_, s) => PhotoSearchScreen(photoId: s.pathParameters['photoId']!),
      ),
      GoRoute(
        parentNavigatorKey: rootKey,
        path: '/product/:id',
        builder: (_, s) => ProductScreen(
          productId: s.pathParameters['id']!,
          variantId: s.uri.queryParameters['v'],
          initialTab: ProductTab.values.where((t) => t.name == s.uri.queryParameters['tab']).firstOrNull ?? ProductTab.online,
        ),
      ),
      GoRoute(parentNavigatorKey: rootKey, path: '/ip-manage', builder: (_, _) => const IpManageScreen()),
      GoRoute(parentNavigatorKey: rootKey, path: '/seller', builder: (_, _) => const SellerScreen()),
    ],
  );
}
