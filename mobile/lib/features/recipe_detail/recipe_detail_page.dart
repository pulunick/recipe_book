import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_service.dart';
import '../../core/theme.dart';
import '../../shared/models/collection_item.dart';
import '../../shared/models/recipe.dart';
import 'ai_fab.dart';
import 'edit_recipe_sheet.dart';

final collectionItemProvider =
    FutureProvider.family<CollectionItem, int>((ref, id) {
  return ref.watch(apiServiceProvider).getCollectionItem(id);
});

class RecipeDetailPage extends ConsumerWidget {
  const RecipeDetailPage({super.key, required this.collectionId});
  final int collectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemAsync = ref.watch(collectionItemProvider(collectionId));

    return itemAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator(color: primaryColor)),
      ),
      error: (e, st) => Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: softBrownColor),
              const SizedBox(height: 12),
              const Text('불러올 수 없어요', style: TextStyle(color: softBrownColor)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(collectionItemProvider(collectionId)),
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      ),
      data: (item) => _DetailView(item: item, collectionId: collectionId),
    );
  }
}

class _DetailView extends ConsumerStatefulWidget {
  const _DetailView({required this.item, required this.collectionId});
  final CollectionItem item;
  final int collectionId;

  @override
  ConsumerState<_DetailView> createState() => _DetailViewState();
}

class _DetailViewState extends ConsumerState<_DetailView> {
  bool _cookLoading = false;

  void _invalidate() {
    ref.invalidate(collectionItemProvider(widget.collectionId));
  }

  Future<void> _setRating(int rating) async {
    await ref.read(apiServiceProvider).setRating(widget.item.id, rating);
    _invalidate();
  }

  Future<void> _recordCooked() async {
    if (_cookLoading) return;
    setState(() => _cookLoading = true);
    try {
      await ref.read(apiServiceProvider).recordCooked(widget.item.id);
      _invalidate();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('요리 기록이 추가됐어요!')),
        );
      }
    } finally {
      if (mounted) setState(() => _cookLoading = false);
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('레시피 삭제'),
        content: const Text('이 레시피를 내 레시피에서 삭제할까요?\n삭제하면 되돌릴 수 없어요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(apiServiceProvider).removeFromCollection(widget.item.id);
      if (mounted) context.go('/my-recipes');
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    // recipe_override가 있으면 해당 필드 우선 적용
    final ov = item.recipeOverride;
    final recipe = ov == null ? item.recipe : _applyOverride(item.recipe, ov);

    return Scaffold(
      floatingActionButton: AiFab(collectionId: item.id),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: recipe.steps.isNotEmpty
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () => context.push('/my-recipes/${item.id}/cook'),
                    icon: const Icon(Icons.restaurant_menu, size: 20),
                    label: const Text('요리 시작', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                  ),
                ),
              ),
            )
          : null,
      body: CustomScrollView(
        slivers: [
          // 헤더 (썸네일 + 타이틀)
          SliverAppBar(
            expandedHeight: recipe.thumbnailUrl != null ? 220 : 0,
            pinned: true,
            backgroundColor: paperColor,
            foregroundColor: darkColor,
            actions: [
              // 편집
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => EditRecipeSheet(
                      item: item,
                      onSaved: _invalidate,
                    ),
                  );
                },
              ),
              // 즐겨찾기
              IconButton(
                icon: Icon(
                  item.isFavorite ? Icons.star : Icons.star_border,
                  color: item.isFavorite ? const Color(0xFFFFD700) : softBrownColor,
                ),
                onPressed: () async {
                  await ref.read(apiServiceProvider).toggleFavorite(item.id);
                  _invalidate();
                },
              ),
              // 장바구니 담기
              IconButton(
                icon: const Icon(Icons.shopping_cart_outlined),
                onPressed: () async {
                  await ref.read(apiServiceProvider).addToCart(item.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('장바구니에 담겼어요!')),
                    );
                  }
                },
              ),
              // 더보기 메뉴 (삭제)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) {
                  if (value == 'delete') _confirmDelete();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 20, color: Colors.red),
                        SizedBox(width: 8),
                        Text('삭제', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            flexibleSpace: recipe.thumbnailUrl != null
                ? FlexibleSpaceBar(
                    background: Image.network(
                      recipe.thumbnailUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, e, st) => Container(color: creamColor),
                    ),
                  )
                : null,
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 소스 배지 — 웹 .text-badge 스타일 (초록)
                  if (!recipe.isYoutube)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFC8E6C9)),
                      ),
                      child: const Text(
                        '✏ 직접 작성',
                        style: TextStyle(color: Color(0xFF2E7D32), fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),

                  // 제목
                  Text(
                    recipe.title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: warmBrownColor,
                      height: 1.3,
                    ),
                  ),

                  // 채널명
                  if (recipe.channelName != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      recipe.channelName!,
                      style: TextStyle(fontSize: 13, color: softBrownColor.withAlpha(204)),
                    ),
                  ],

                  // 메타 칩 (시간, 칼로리, 인분)
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    children: [
                      if (recipe.cookingTimeMinutes != null)
                        _MetaChip(Icons.timer_outlined, '${recipe.cookingTimeMinutes}분'),
                      if (recipe.calories != null)
                        _MetaChip(Icons.local_fire_department_outlined, '${recipe.calories}kcal'),
                      if (recipe.servings != null)
                        _MetaChip(Icons.people_outline, recipe.servings!),
                      if (recipe.difficulty != null)
                        _MetaChip(Icons.bar_chart, recipe.difficulty!),
                    ],
                  ),

                  // 활동 블록: 별점 + 요리 기록
                  const SizedBox(height: 16),
                  _ActivityBlock(
                    myRating: item.myRating,
                    cookedCount: item.cookedCount,
                    cookLoading: _cookLoading,
                    onSetRating: _setRating,
                    onRecordCooked: _recordCooked,
                  ),

                  const Divider(height: 32),

                  // 요약 (마크다운 렌더링)
                  if (recipe.summary != null && recipe.summary!.isNotEmpty) ...[
                    MarkdownBody(
                      data: recipe.summary!,
                      styleSheet: MarkdownStyleSheet(
                        p: const TextStyle(fontSize: 14, color: softBrownColor, height: 1.6),
                        strong: const TextStyle(fontSize: 14, color: warmBrownColor, fontWeight: FontWeight.w600),
                        h1: const TextStyle(fontSize: 16, color: warmBrownColor, fontWeight: FontWeight.bold),
                        h2: const TextStyle(fontSize: 15, color: warmBrownColor, fontWeight: FontWeight.bold),
                        h3: const TextStyle(fontSize: 14, color: warmBrownColor, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const Divider(height: 32),
                  ],

                  // 맛 프로필
                  if (recipe.flavor != null) ...[
                    _SectionTitle('맛 한눈에 보기'),
                    const SizedBox(height: 12),
                    _FlavorProfileWidget(flavor: recipe.flavor!),
                    const Divider(height: 32),
                  ],

                  // 재료
                  if (recipe.ingredients.isNotEmpty) ...[
                    _SectionTitle('재료'),
                    const SizedBox(height: 12),
                    ..._groupIngredients(recipe.ingredients).entries.map((e) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (e.key.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6, top: 4),
                            child: Text(e.key,
                                style: const TextStyle(
                                    fontSize: 13, color: softBrownColor, fontWeight: FontWeight.w600)),
                          ),
                        ...e.value.map((ing) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(ing.name,
                                    style: const TextStyle(fontSize: 14, color: darkColor)),
                              ),
                              Text(
                                [ing.amount, ing.unit].whereType<String>().join(' '),
                                style: const TextStyle(fontSize: 14, color: softBrownColor),
                              ),
                            ],
                          ),
                        )),
                        const SizedBox(height: 4),
                      ],
                    )),
                    const Divider(height: 32),
                  ],

                  // 조리 순서
                  if (recipe.steps.isNotEmpty) ...[
                    _SectionTitle('조리 순서'),
                    const SizedBox(height: 12),
                    ...recipe.steps.map((step) => _StepItem(step: step)),
                    const Divider(height: 32),
                  ],

                  // 꿀팁
                  if ((item.customTip ?? recipe.tip) != null &&
                      (item.customTip ?? recipe.tip)!.isNotEmpty) ...[
                    _SectionTitle('꿀팁'),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: creamColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: MarkdownBody(
                        data: item.customTip ?? recipe.tip ?? '',
                        styleSheet: MarkdownStyleSheet(
                          p: const TextStyle(fontSize: 14, height: 1.6, color: warmBrownColor),
                          strong: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: warmBrownColor),
                        ),
                      ),
                    ),
                  ],

                  // 원본 영상
                  if (recipe.isYoutube && recipe.videoId != null) ...[
                    const SizedBox(height: 8),
                    _OriginalVideoCard(recipe: recipe),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Recipe _applyOverride(Recipe base, Map<String, dynamic> ov) {
    final overrideIngredients = ov['ingredients'] as List?;
    final overrideSteps = ov['steps'] as List?;
    return Recipe(
      id: base.id,
      title: ov['title'] as String? ?? base.title,
      summary: ov['summary'] as String? ?? base.summary,
      ingredients: overrideIngredients != null
          ? overrideIngredients
              .map((e) => Ingredient.fromJson(e as Map<String, dynamic>))
              .toList()
          : base.ingredients,
      steps: overrideSteps != null
          ? overrideSteps
              .map((e) => RecipeStep.fromJson(e as Map<String, dynamic>))
              .toList()
          : base.steps,
      tip: ov['tip'] as String? ?? base.tip,
      category: base.category,
      cookingTimeMinutes: base.cookingTimeMinutes,
      calories: base.calories,
      servings: base.servings,
      difficulty: base.difficulty,
      videoId: base.videoId,
      videoTitle: base.videoTitle,
      channelName: base.channelName,
      source: base.source,
      flavor: base.flavor,
      cookingTime: base.cookingTime,
    );
  }

  Map<String, List<Ingredient>> _groupIngredients(List<Ingredient> ingredients) {
    final groups = <String, List<Ingredient>>{};
    for (final ing in ingredients) {
      groups.putIfAbsent(ing.category, () => []).add(ing);
    }
    return groups;
  }
}

/// 활동 블록 — 인터랙티브 별점 + 요리했어요 버튼
class _ActivityBlock extends StatelessWidget {
  const _ActivityBlock({
    required this.myRating,
    required this.cookedCount,
    required this.cookLoading,
    required this.onSetRating,
    required this.onRecordCooked,
  });

  final int? myRating;
  final int cookedCount;
  final bool cookLoading;
  final ValueChanged<int> onSetRating;
  final VoidCallback onRecordCooked;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: creamColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Row 1: 별점 (웹: 중앙 정렬)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ...List.generate(5, (i) {
                final starIndex = i + 1;
                return GestureDetector(
                  onTap: () => onSetRating(starIndex),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Icon(
                      myRating != null && starIndex <= myRating!
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      size: 28,
                      color: const Color(0xFFFFD700),
                    ),
                  ),
                );
              }),
              const SizedBox(width: 8),
              Text(
                myRating == null ? '별점을 매겨보세요' : '$myRating점',
                style: TextStyle(
                  fontSize: 13,
                  color: myRating == null
                      ? softBrownColor.withAlpha(178)
                      : warmBrownColor,
                  fontWeight: myRating == null ? FontWeight.normal : FontWeight.w600,
                ),
              ),
            ],
          ),

          const Divider(height: 20),

          // Row 2: 요리 기록
          Row(
            children: [
              Text(
                '🍳 $cookedCount회 요리함',
                style: const TextStyle(fontSize: 13, color: softBrownColor),
              ),
              const Spacer(),
              SizedBox(
                height: 30,
                child: OutlinedButton.icon(
                  onPressed: cookLoading ? null : onRecordCooked,
                  icon: cookLoading
                      ? SizedBox(
                          width: 13,
                          height: 13,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: softBrownColor),
                        )
                      : const Icon(Icons.restaurant, size: 14),
                  label: const Text('오늘 요리했어요',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: softBrownColor,
                    side: const BorderSide(color: lightLineColor, width: 1.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: warmBrownColor),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip(this.icon, this.label);
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: creamColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: softBrownColor),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: softBrownColor)),
        ],
      ),
    );
  }
}

class _StepItem extends StatelessWidget {
  const _StepItem({required this.step});
  final RecipeStep step;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            margin: const EdgeInsets.only(top: 1, right: 12),
            decoration: const BoxDecoration(color: primaryColor, shape: BoxShape.circle),
            child: Center(
              child: Text(
                '${step.stepNumber}',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MarkdownBody(
                  data: step.description,
                  styleSheet: MarkdownStyleSheet(
                    p: const TextStyle(fontSize: 14, height: 1.6, color: warmBrownColor),
                    strong: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: warmBrownColor),
                  ),
                ),
                if (step.timer != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.timer_outlined, size: 13, color: primaryColor),
                        const SizedBox(width: 4),
                        Text(step.timer!,
                            style: const TextStyle(fontSize: 12, color: primaryColor)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 맛 프로필 (점 차트) ──────────────────────────────────────
class _FlavorProfileWidget extends StatelessWidget {
  const _FlavorProfileWidget({required this.flavor});
  final FlavorProfile flavor;

  static const _axes = [
    ('짠맛', Color(0xFF6B9E6B)),
    ('단맛', Color(0xFFE8623C)),
    ('매운맛', Color(0xFFD94040)),
    ('신맛', Color(0xFFF5C542)),
    ('기름진 맛', Color(0xFFA67C5B)),
  ];

  @override
  Widget build(BuildContext context) {
    final values = [
      flavor.saltiness,
      flavor.sweetness,
      flavor.spiciness,
      flavor.sourness,
      flavor.oiliness,
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: creamColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: List.generate(5, (i) {
          final filled = values[i].round().clamp(0, 5);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                SizedBox(
                  width: 64,
                  child: Text(
                    _axes[i].$1,
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 12.5, color: softBrownColor),
                  ),
                ),
                const SizedBox(width: 12),
                Row(
                  children: List.generate(5, (j) => Container(
                    width: 14,
                    height: 14,
                    margin: const EdgeInsets.only(right: 5),
                    decoration: BoxDecoration(
                      color: j < filled ? _axes[i].$2 : lightLineColor,
                      shape: BoxShape.circle,
                    ),
                  )),
                ),
                const SizedBox(width: 8),
                Text(
                  values[i].toStringAsFixed(1),
                  style: const TextStyle(fontSize: 12, color: softBrownColor),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

// ── 원본 영상 카드 ────────────────────────────────────────────
class _OriginalVideoCard extends StatelessWidget {
  const _OriginalVideoCard({required this.recipe});
  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final thumbnailUrl = recipe.thumbnailUrl;
    final videoUrl = 'https://youtu.be/${recipe.videoId}';

    return GestureDetector(
      onTap: () async {
        final uri = Uri.parse(videoUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('영상 열기: $videoUrl')),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: lightLineColor),
        ),
        child: Row(
          children: [
            if (thumbnailUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  thumbnailUrl,
                  width: 80,
                  height: 52,
                  fit: BoxFit.cover,
                  errorBuilder: (ctx, e, st) => Container(
                    width: 80,
                    height: 52,
                    color: creamColor,
                    child: const Center(
                      child: Icon(Icons.videocam_outlined, color: softBrownColor),
                    ),
                  ),
                ),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '▶ 원본 영상',
                    style: TextStyle(fontSize: 11, color: softBrownColor),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    recipe.videoTitle ?? recipe.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600, color: darkColor),
                  ),
                  if (recipe.channelName != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      recipe.channelName!,
                      style: const TextStyle(fontSize: 12, color: softBrownColor),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: softBrownColor),
          ],
        ),
      ),
    );
  }
}
