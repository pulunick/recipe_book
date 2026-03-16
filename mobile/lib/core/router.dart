import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/auth/login_page.dart';
import '../features/cooking_mode/cooking_mode_page.dart';
import '../features/explore/explore_page.dart';
import '../features/my_recipes/my_recipes_page.dart';
import '../features/recipe_detail/recipe_detail_page.dart';
import '../features/cart/cart_page.dart';
import '../features/my/my_page.dart';
import '../shared/widgets/main_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

// auth 상태 변경 시 라우터를 새로고침하기 위한 notifier
class _AuthNotifier extends ChangeNotifier {
  _AuthNotifier() {
    Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      notifyListeners();
    });
  }
}

GoRouter buildRouter() {
  final authNotifier = _AuthNotifier();

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final isLoggedIn =
          Supabase.instance.client.auth.currentUser != null;
      final isLoginPage = state.matchedLocation == '/login';

      final protectedPaths = ['/my-recipes', '/cart', '/my', '/write'];
      final needsLogin =
          protectedPaths.any((p) => state.matchedLocation.startsWith(p));

      if (needsLogin && !isLoggedIn) return '/login';
      if (isLoginPage && isLoggedIn) return '/';
      return null;
    },
    routes: [
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const ExplorePage(),
          ),
          GoRoute(
            path: '/my-recipes',
            builder: (context, state) => const MyRecipesPage(),
          ),
          GoRoute(
            path: '/cart',
            builder: (context, state) => const CartPage(),
          ),
          GoRoute(
            path: '/my',
            builder: (context, state) => const MyPage(),
          ),
        ],
      ),
      // 레시피 상세 (쉘 밖 — 전체 화면)
      GoRoute(
        path: '/my-recipes/:id',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return RecipeDetailPage(collectionId: id);
        },
      ),
      // 쿠킹 모드 (전체 화면, 쉘 밖)
      GoRoute(
        path: '/my-recipes/:id/cook',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return CookingModePage(collectionId: id);
        },
      ),
      // 로그인
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
    ],
  );
}
