import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../features/add_recipe/add_recipe_sheet.dart';

class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.child});

  final Widget child;

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/my-recipes')) return 1;
    if (location.startsWith('/cart')) return 3;
    if (location.startsWith('/my')) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _currentIndex(context);
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        height: 60 + bottomPadding,
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(top: BorderSide(color: lightLineColor, width: 1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(15),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomPadding),
          child: Row(
            children: [
              // 탐색
              _NavItem(
                icon: Icons.explore_outlined,
                activeIcon: Icons.explore,
                label: '탐색',
                isActive: currentIndex == 0,
                onTap: () => context.go('/'),
              ),
              // 내 레시피
              _NavItem(
                icon: Icons.menu_book_outlined,
                activeIcon: Icons.menu_book,
                label: '내 레시피',
                isActive: currentIndex == 1,
                onTap: () => context.go('/my-recipes'),
              ),
              // 중앙 [+] 버튼
              Expanded(
                child: GestureDetector(
                  onTap: () => _showAddSheet(context),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Transform.translate(
                        offset: const Offset(0, -16),
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: primaryColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: primaryColor.withAlpha(102),
                                blurRadius: 14,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.add, color: Colors.white, size: 22),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // 장바구니
              _NavItem(
                icon: Icons.shopping_cart_outlined,
                activeIcon: Icons.shopping_cart,
                label: '장바구니',
                isActive: currentIndex == 3,
                onTap: () => context.go('/cart'),
              ),
              // 마이
              _NavItem(
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                label: '마이',
                isActive: currentIndex == 4,
                onTap: () => context.go('/my'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddRecipeSheet(
        onSaved: (collectionId) => context.push('/my-recipes/$collectionId'),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: 60,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isActive ? activeIcon : icon,
                size: 22,
                color: isActive ? primaryColor : softBrownColor,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: isActive ? primaryColor : softBrownColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
