import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_service.dart';
import '../../core/theme.dart';
import '../../shared/models/cart_item.dart';
import '../../shared/providers/auth_provider.dart';

final cartProvider = FutureProvider<List<CartGroup>>((ref) {
  return ref.watch(apiServiceProvider).getCart();
});

class CartPage extends ConsumerStatefulWidget {
  const CartPage({super.key});

  @override
  ConsumerState<CartPage> createState() => _CartPageState();
}

class _CartPageState extends ConsumerState<CartPage> {
  // 접힌 그룹 추적
  final Set<String> _collapsedGroups = {};

  String _groupKey(CartGroup group) =>
      '${group.collectionId ?? group.recipeTitle ?? "기타"}';

  void _toggleCollapse(CartGroup group) {
    setState(() {
      final key = _groupKey(group);
      if (_collapsedGroups.contains(key)) {
        _collapsedGroups.remove(key);
      } else {
        _collapsedGroups.add(key);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).valueOrNull;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('장바구니')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🛒', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              const Text('로그인이 필요해요',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: warmBrownColor)),
              const SizedBox(height: 8),
              const Text('장바구니를 사용하려면 로그인해주세요.',
                  style: TextStyle(fontSize: 14, color: softBrownColor)),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => context.go('/login'),
                child: const Text('로그인'),
              ),
            ],
          ),
        ),
      );
    }

    final cartAsync = ref.watch(cartProvider);
    final api = ref.read(apiServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: Image.asset('assets/images/logo.png', height: 28),
        actions: [
          cartAsync.maybeWhen(
            data: (groups) {
              if (groups.isEmpty) return const SizedBox.shrink();
              final checkedCount = groups.fold<int>(
                  0, (sum, g) => sum + g.items.where((i) => i.isChecked).length);
              return Row(
                children: [
                  if (checkedCount > 0)
                    TextButton(
                      onPressed: () async {
                        await api.clearCheckedCart();
                        ref.invalidate(cartProvider);
                      },
                      child: Text('선택 삭제 ($checkedCount)',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600, color: primaryColor)),
                    ),
                  TextButton(
                    onPressed: () async {
                      await api.clearCart();
                      ref.invalidate(cartProvider);
                    },
                    child: const Text('전체 비우기',
                        style: TextStyle(fontSize: 13, color: softBrownColor)),
                  ),
                ],
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            color: primaryColor,
            onRefresh: () async => ref.invalidate(cartProvider),
            child: cartAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: primaryColor),
              ),
              error: (e, st) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.wifi_off, size: 48, color: softBrownColor),
                    const SizedBox(height: 12),
                    const Text('오류가 발생했어요', style: TextStyle(color: softBrownColor)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(cartProvider),
                      child: const Text('다시 시도'),
                    ),
                  ],
                ),
              ),
              data: (groups) {
                if (groups.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('🛒', style: TextStyle(fontSize: 48)),
                        const SizedBox(height: 12),
                        const Text('장바구니가 비어있어요',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: warmBrownColor)),
                        const SizedBox(height: 8),
                        const Text('레시피 상세 페이지에서 재료를 담아보세요.',
                            style: TextStyle(fontSize: 14, color: softBrownColor)),
                        const SizedBox(height: 20),
                        TextButton(
                          onPressed: () => context.go('/my-recipes'),
                          child: const Text('내 레시피 보러가기'),
                        ),
                      ],
                    ),
                  );
                }

                final totalCount = groups.fold<int>(0, (sum, g) => sum + g.items.length);
                final checkedCount = groups.fold<int>(
                    0, (sum, g) => sum + g.items.where((i) => i.isChecked).length);

                return ListView(
                  padding: const EdgeInsets.fromLTRB(0, 0, 0, 160),
                  children: [
                    // 요약
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
                      child: Row(
                        children: [
                          Text.rich(TextSpan(
                            style: const TextStyle(fontSize: 14, color: warmBrownColor),
                            children: [
                              const TextSpan(text: '총 '),
                              TextSpan(
                                  text: '$totalCount개',
                                  style: const TextStyle(fontWeight: FontWeight.w700)),
                              const TextSpan(text: ' 재료'),
                            ],
                          )),
                          if (checkedCount > 0) ...[
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: creamColor,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text('$checkedCount개 체크됨',
                                  style: const TextStyle(fontSize: 12.5, color: softBrownColor)),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // 그룹 목록
                    ...groups.map((group) => _CartGroupWidget(
                      group: group,
                      isCollapsed: _collapsedGroups.contains(_groupKey(group)),
                      onToggleCollapse: () => _toggleCollapse(group),
                      onToggleItem: (item) async {
                        await api.toggleCartItem(item.id, !item.isChecked);
                        ref.invalidate(cartProvider);
                      },
                      onDeleteItem: (item) async {
                        await api.deleteCartItem(item.id);
                        ref.invalidate(cartProvider);
                      },
                    )),
                  ],
                );
              },
            ),
          ),

          // 하단 구매 바
          cartAsync.maybeWhen(
            data: (groups) {
              if (groups.isEmpty) return const SizedBox.shrink();
              final totalCount = groups.fold<int>(0, (sum, g) => sum + g.items.length);
              final checkedCount = groups.fold<int>(
                  0, (sum, g) => sum + g.items.where((i) => i.isChecked).length);
              return _ShopBar(totalCount: totalCount, checkedCount: checkedCount);
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ── 그룹 위젯 (접기/펼치기 지원) ───────────────────────────
class _CartGroupWidget extends StatelessWidget {
  const _CartGroupWidget({
    required this.group,
    required this.isCollapsed,
    required this.onToggleCollapse,
    required this.onToggleItem,
    required this.onDeleteItem,
  });

  final CartGroup group;
  final bool isCollapsed;
  final VoidCallback onToggleCollapse;
  final void Function(CartItem) onToggleItem;
  final void Function(CartItem) onDeleteItem;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: [
          // 그룹 헤더 (탭하여 접기/펼치기)
          GestureDetector(
            onTap: onToggleCollapse,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: BoxDecoration(
                border: isCollapsed
                    ? null
                    : const Border(bottom: BorderSide(color: lightLineColor)),
              ),
              child: Row(
                children: [
                  Text(
                    isCollapsed ? '▶' : '▼',
                    style: const TextStyle(fontSize: 10, color: softBrownColor),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      group.recipeTitle ?? '기타',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14.5, fontWeight: FontWeight.w700, color: warmBrownColor),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: creamColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('${group.items.length}개',
                        style: const TextStyle(fontSize: 12, color: softBrownColor)),
                  ),
                  if (group.collectionId != null) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => context.push('/my-recipes/${group.collectionId}'),
                      child: const Text('레시피 →',
                          style: TextStyle(fontSize: 12, color: primaryColor)),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // 재료 목록
          if (!isCollapsed)
            ...group.items.map((item) => _CartItemTile(
              item: item,
              onToggle: () => onToggleItem(item),
              onDelete: () => onDeleteItem(item),
            )),
        ],
      ),
    );
  }
}

// ── 재료 타일 ────────────────────────────────────────────────
class _CartItemTile extends StatelessWidget {
  const _CartItemTile({
    required this.item,
    required this.onToggle,
    required this.onDelete,
  });

  final CartItem item;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        color: item.isChecked ? paperColor : Colors.white,
        border: const Border(bottom: BorderSide(color: lightLineColor, width: 0.5)),
      ),
      child: Row(
        children: [
          // 체크 버튼
          GestureDetector(
            onTap: onToggle,
            child: Icon(
              item.isChecked ? Icons.check_box : Icons.check_box_outline_blank,
              size: 22,
              color: primaryColor,
            ),
          ),
          const SizedBox(width: 10),

          // 재료명 + 수량
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    item.ingredientName,
                    style: TextStyle(
                      fontSize: 14,
                      color: item.isChecked ? softBrownColor : darkColor,
                      fontWeight: FontWeight.w500,
                      decoration: item.isChecked ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
                if (item.displayAmount.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Text(
                    item.displayAmount,
                    style: TextStyle(
                      fontSize: 13,
                      color: item.isChecked
                          ? softBrownColor.withAlpha(100)
                          : softBrownColor,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // 카테고리 배지
          if (item.category.isNotEmpty) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: creamColor,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(item.category,
                  style: const TextStyle(fontSize: 11, color: softBrownColor)),
            ),
          ],

          // 삭제 버튼
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onDelete,
            child: Icon(Icons.close, size: 18, color: lightLineColor),
          ),
        ],
      ),
    );
  }
}

// ── 하단 구매 바 ──────────────────────────────────────────────
class _ShopBar extends StatelessWidget {
  const _ShopBar({required this.totalCount, required this.checkedCount});
  final int totalCount;
  final int checkedCount;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 16,
      right: 16,
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(30),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: checkedCount > 0
                    ? Text.rich(TextSpan(
                        style: const TextStyle(fontSize: 14, color: softBrownColor),
                        children: [
                          const TextSpan(text: '선택 '),
                          TextSpan(
                              text: '$checkedCount',
                              style: const TextStyle(fontWeight: FontWeight.w700, color: darkColor)),
                          const TextSpan(text: ' / 전체 '),
                          TextSpan(
                              text: '${totalCount}개',
                              style: const TextStyle(fontWeight: FontWeight.w700, color: darkColor)),
                        ],
                      ))
                    : Text.rich(TextSpan(
                        style: const TextStyle(fontSize: 14, color: softBrownColor),
                        children: [
                          const TextSpan(text: '전체 '),
                          TextSpan(
                              text: '${totalCount}개',
                              style: const TextStyle(fontWeight: FontWeight.w700, color: darkColor)),
                          const TextSpan(text: ' 재료'),
                        ],
                      )),
              ),
              if (checkedCount > 0) ...[
                OutlinedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${checkedCount}개 재료 구매 기능은 곧 출시 예정이에요!')),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: primaryColor, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  child: const Text('선택만 구매',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: primaryColor)),
                ),
                const SizedBox(width: 8),
              ],
              ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$totalCount개 재료 구매 기능은 곧 출시 예정이에요!')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('🛍 전체 구매',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
