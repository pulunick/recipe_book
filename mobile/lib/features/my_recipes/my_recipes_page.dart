import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_service.dart';
import '../../core/theme.dart';
import '../../shared/models/collection_item.dart';
import '../../shared/providers/auth_provider.dart';
import 'my_recipes_provider.dart';

class MyRecipesPage extends ConsumerStatefulWidget {
  const MyRecipesPage({super.key});

  @override
  ConsumerState<MyRecipesPage> createState() => _MyRecipesPageState();
}

class _MyRecipesPageState extends ConsumerState<MyRecipesPage> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).valueOrNull;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('내 레시피')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 64, color: softBrownColor),
              const SizedBox(height: 16),
              const Text('로그인이 필요해요', style: TextStyle(color: softBrownColor)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go('/login'),
                child: const Text('로그인'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Image.asset('assets/images/logo.png', height: 28),
      ),
      body: RefreshIndicator(
        color: primaryColor,
        onRefresh: () async {
          ref.invalidate(myRecipesProvider);
          ref.invalidate(myTagsProvider);
        },
        child: CustomScrollView(
          slivers: [
            // 검색바
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => ref.read(myRecipesQueryProvider.notifier).state =
                      v.trim().isEmpty ? null : v.trim(),
                  decoration: const InputDecoration(
                    hintText: '내 레시피 검색',
                    prefixIcon: Icon(Icons.search, color: softBrownColor, size: 20),
                  ),
                ),
              ),
            ),

            // 소스 + 즐겨찾기 필터 칩
            SliverToBoxAdapter(child: _FilterChips()),

            // 카테고리 + 태그 필터 탭
            SliverToBoxAdapter(child: _FilterTabs()),

            // 레시피 그리드
            _MyRecipesGrid(),
          ],
        ),
      ),
    );
  }
}

class _FilterChips extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final source = ref.watch(myRecipesSourceProvider);
    final favoriteOnly = ref.watch(myRecipesFavoriteOnlyProvider);

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: [
          // 소스 필터
          for (final (value, label) in [
            (null, '전체'),
            ('youtube', 'YouTube'),
            ('text', '직접 작성'),
          ])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(label, style: const TextStyle(fontSize: 13)),
                selected: source == value,
                onSelected: (_) =>
                    ref.read(myRecipesSourceProvider.notifier).state = value,
                selectedColor: primaryColor,
                labelStyle: TextStyle(
                  color: source == value ? Colors.white : darkColor,
                  fontWeight: source == value ? FontWeight.w600 : FontWeight.normal,
                ),
                backgroundColor: creamColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: source == value ? primaryColor : lightLineColor),
                ),
                showCheckmark: false,
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
            ),

          // 즐겨찾기 필터
          FilterChip(
            label: const Text('즐겨찾기', style: TextStyle(fontSize: 13)),
            selected: favoriteOnly,
            onSelected: (v) =>
                ref.read(myRecipesFavoriteOnlyProvider.notifier).state = v,
            selectedColor: const Color(0xFFFFD700),
            labelStyle: TextStyle(
              color: favoriteOnly ? darkColor : darkColor,
              fontWeight: favoriteOnly ? FontWeight.w600 : FontWeight.normal,
            ),
            backgroundColor: creamColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: favoriteOnly ? const Color(0xFFFFD700) : lightLineColor),
            ),
            showCheckmark: false,
            avatar: favoriteOnly
                ? const Icon(Icons.star, size: 14, color: darkColor)
                : const Icon(Icons.star_border, size: 14, color: softBrownColor),
            padding: const EdgeInsets.symmetric(horizontal: 4),
          ),
        ],
      ),
    );
  }
}

// ── 카테고리 + 태그 필터 탭 ──────────────────────────────────
class _FilterTabs extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipesAsync = ref.watch(myRecipesProvider);
    final tagsAsync = ref.watch(myTagsProvider);
    final selectedCategory = ref.watch(myRecipesCategoryProvider);
    final selectedTagId = ref.watch(myRecipesTagIdProvider);
    final favoriteOnly = ref.watch(myRecipesFavoriteOnlyProvider);

    // 레시피 목록에서 유니크 카테고리 추출
    final categories = recipesAsync.valueOrNull
            ?.map((r) => r.displayCategory)
            .where((c) => c.isNotEmpty)
            .toSet()
            .toList() ??
        [];

    final tags = tagsAsync.valueOrNull ?? [];

    final totalCount = recipesAsync.valueOrNull?.length ?? 0;

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          // 전체(N) 탭
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _TabChip(
              label: '전체',
              count: totalCount,
              isSelected: selectedCategory == null && selectedTagId == null && !favoriteOnly,
              onTap: () {
                ref.read(myRecipesCategoryProvider.notifier).state = null;
                ref.read(myRecipesTagIdProvider.notifier).state = null;
                ref.read(myRecipesFavoriteOnlyProvider.notifier).state = false;
              },
            ),
          ),

          // 즐겨찾기 탭
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _TabChip(
              label: '⭐ 즐겨찾기',
              isSelected: favoriteOnly,
              onTap: () {
                final next = !favoriteOnly;
                ref.read(myRecipesFavoriteOnlyProvider.notifier).state = next;
                if (next) {
                  ref.read(myRecipesCategoryProvider.notifier).state = null;
                  ref.read(myRecipesTagIdProvider.notifier).state = null;
                }
              },
            ),
          ),

          // 카테고리 탭
          ...categories.map((cat) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _TabChip(
                  label: cat,
                  isSelected: selectedCategory == cat && selectedTagId == null,
                  onTap: () {
                    ref.read(myRecipesCategoryProvider.notifier).state =
                        selectedCategory == cat ? null : cat;
                    ref.read(myRecipesTagIdProvider.notifier).state = null;
                    ref.read(myRecipesFavoriteOnlyProvider.notifier).state = false;
                  },
                ),
              )),

          // 태그 탭
          ...tags.map((tag) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _TagTabChip(
                  tag: tag,
                  isSelected: selectedTagId == tag.id,
                  onTap: () {
                    ref.read(myRecipesTagIdProvider.notifier).state =
                        selectedTagId == tag.id ? null : tag.id;
                    ref.read(myRecipesCategoryProvider.notifier).state = null;
                    ref.read(myRecipesFavoriteOnlyProvider.notifier).state = false;
                  },
                ),
              )),
        ],
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.count,
  });
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? primaryColor : lightLineColor,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.white : softBrownColor,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withAlpha(60)
                      : lightLineColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : softBrownColor,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TagTabChip extends StatelessWidget {
  const _TagTabChip({
    required this.tag,
    required this.isSelected,
    required this.onTap,
  });
  final CollectionTag tag;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // hex 색상 파싱
    Color tagColor = softBrownColor;
    try {
      final hex = tag.color.replaceFirst('#', '');
      tagColor = Color(int.parse('FF$hex', radix: 16));
    } catch (_) {}

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? tagColor.withAlpha(204) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? tagColor : lightLineColor,
            width: 1.5,
          ),
        ),
        child: Text(
          tag.name,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? Colors.white : softBrownColor,
          ),
        ),
      ),
    );
  }
}

class _MyRecipesGrid extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipesAsync = ref.watch(myRecipesProvider);

    return recipesAsync.when(
      loading: () => const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.only(top: 80),
          child: Center(child: CircularProgressIndicator(color: primaryColor)),
        ),
      ),
      error: (e, st) => SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              children: [
                const Icon(Icons.wifi_off, size: 48, color: softBrownColor),
                const SizedBox(height: 12),
                const Text('오류가 발생했어요', style: TextStyle(color: softBrownColor)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(myRecipesProvider),
                  child: const Text('다시 시도'),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (recipes) {
        if (recipes.isEmpty) {
          return SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(32, 60, 32, 60),
                child: Column(
                  children: [
                    const Text('📖', style: TextStyle(fontSize: 52)),
                    const SizedBox(height: 16),
                    const Text(
                      '아직 레시피북이 비어있어요',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: darkColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '유튜브 요리 영상 링크를 붙여넣으면\n첫 레시피가 생겨요',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: softBrownColor,
                        height: 1.7,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => context.go('/'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text(
                        '첫 레시피 정리하러 가기',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (context, i) => _CollectionCard(item: recipes[i]),
              childCount: recipes.length,
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.72,
            ),
          ),
        );
      },
    );
  }
}

class _CollectionCard extends ConsumerWidget {
  const _CollectionCard({required this.item});
  final CollectionListItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRegular = item.cookedCount >= 3;

    return GestureDetector(
      onTap: () => context.push('/my-recipes/${item.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 썸네일
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  item.thumbnailUrl != null
                      ? Image.network(
                          item.thumbnailUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, e, st) => _thumbPlaceholder(),
                        )
                      : _thumbPlaceholder(),

                  // 좌상단: 요리시간 / 직접작성 배지
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Row(
                      children: [
                        if (item.cookingTimeMinutes != null) ...[
                          _ThumbBadge('⏱ ${item.cookingTimeMinutes}분'),
                          const SizedBox(width: 3),
                        ],
                        if (!item.isYoutube)
                          const _ThumbBadge('✏ 직접 작성'),
                      ],
                    ),
                  ),

                  // 우상단: 즐겨찾기 버튼
                  Positioned(
                    top: 6,
                    right: 6,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () async {
                        await ref.read(apiServiceProvider).toggleFavorite(item.id);
                        ref.invalidate(myRecipesProvider);
                      },
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(217),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(26),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            item.isFavorite
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            size: 17,
                            color: item.isFavorite
                                ? const Color(0xFFFFD700)
                                : softBrownColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 카드 본문
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 제목
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: warmBrownColor,
                      height: 1.4,
                    ),
                  ),

                  // 채널명
                  if (item.channelName != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      item.channelName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: softBrownColor.withAlpha(204),
                      ),
                    ),
                  ],

                  const SizedBox(height: 6),

                  // 카테고리 + 단골 배지
                  Wrap(
                    spacing: 4,
                    runSpacing: 3,
                    children: [
                      if (item.displayCategory.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: primaryColor.withAlpha(30),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            item.displayCategory,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: primaryColor,
                            ),
                          ),
                        ),
                      if (isRegular)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3CD),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            '🏆 단골',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF8B6914),
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  // 별점
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                      5,
                      (i) => Icon(
                        (item.myRating ?? 0) > i
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        size: 14,
                        color: (item.myRating ?? 0) > i
                            ? const Color(0xFFFFD700)
                            : lightLineColor,
                      ),
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

  Widget _thumbPlaceholder() => Container(
        color: creamColor,
        child: Center(
          child: Icon(
            Icons.play_circle_outline,
            size: 40,
            color: softBrownColor.withAlpha(102),
          ),
        ),
      );
}

class _ThumbBadge extends StatelessWidget {
  const _ThumbBadge(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(133),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
