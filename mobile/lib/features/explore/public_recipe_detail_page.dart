import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/api_service.dart';
import '../../core/theme.dart';
import '../../shared/models/recipe.dart';

final _publicRecipeProvider = FutureProvider.family<Recipe, int>((ref, id) {
  return ref.watch(apiServiceProvider).getPublicRecipe(id);
});

class PublicRecipeDetailPage extends ConsumerWidget {
  const PublicRecipeDetailPage({
    super.key,
    required this.recipeId,
    this.initialCollectionId,
  });

  final int recipeId;
  // 탐색 탭에서 이미 수집 여부를 알고 있는 경우 전달
  final int? initialCollectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipeAsync = ref.watch(_publicRecipeProvider(recipeId));

    return recipeAsync.when(
      loading: () => const Scaffold(
        backgroundColor: paperColor,
        body: Center(child: CircularProgressIndicator(color: primaryColor)),
      ),
      error: (e, st) => Scaffold(
        backgroundColor: paperColor,
        appBar: AppBar(backgroundColor: paperColor, foregroundColor: darkColor),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: softBrownColor),
              const SizedBox(height: 12),
              const Text('불러올 수 없어요', style: TextStyle(color: softBrownColor)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(_publicRecipeProvider(recipeId)),
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      ),
      data: (recipe) => _DetailView(
        recipe: recipe,
        recipeId: recipeId,
        initialCollectionId: initialCollectionId,
      ),
    );
  }
}

class _DetailView extends ConsumerStatefulWidget {
  const _DetailView({
    required this.recipe,
    required this.recipeId,
    this.initialCollectionId,
  });

  final Recipe recipe;
  final int recipeId;
  final int? initialCollectionId;

  @override
  ConsumerState<_DetailView> createState() => _DetailViewState();
}

class _DetailViewState extends ConsumerState<_DetailView> {
  bool _isSaving = false;
  int? _collectionId;

  @override
  void initState() {
    super.initState();
    _collectionId = widget.initialCollectionId;
  }

  Future<void> _collect() async {
    // 이미 보관 → 상세로 이동
    if (_collectionId != null) {
      context.push('/my-recipes/$_collectionId');
      return;
    }
    // 로그인 확인
    final isLoggedIn = Supabase.instance.client.auth.currentUser != null;
    if (!isLoggedIn) {
      context.push('/login');
      return;
    }
    setState(() => _isSaving = true);
    try {
      final collectionId =
          await ref.read(apiServiceProvider).saveToCollection(widget.recipeId);
      if (mounted) {
        setState(() {
          _isSaving = false;
          _collectionId = collectionId;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('저장 중 오류가 발생했어요.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final recipe = widget.recipe;
    final isSaved = _collectionId != null;

    return Scaffold(
      backgroundColor: paperColor,
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _collect,
              style: ElevatedButton.styleFrom(
                backgroundColor: isSaved ? const Color(0xFF4CAF50) : primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5),
                    )
                  : Text(
                      isSaved ? '내 레시피 보러가기 →' : '내 레시피에 담기',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
                    ),
            ),
          ),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          // 헤더 (썸네일 + 뒤로가기)
          SliverAppBar(
            expandedHeight: recipe.thumbnailUrl != null ? 220 : 0,
            pinned: true,
            backgroundColor: paperColor,
            foregroundColor: darkColor,
            flexibleSpace: recipe.thumbnailUrl != null
                ? FlexibleSpaceBar(
                    background: CachedNetworkImage(
                      imageUrl: recipe.thumbnailUrl!,
                      fit: BoxFit.cover,
                      placeholder: (ctx, url) => Container(color: creamColor),
                      errorWidget: (ctx, url, err) =>
                          Container(color: creamColor),
                    ),
                  )
                : null,
          ),

          // 본문
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 카테고리 배지
                  if (recipe.category != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: primaryColor.withAlpha(20),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        recipe.category!,
                        style: const TextStyle(
                            fontSize: 11,
                            color: primaryColor,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

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

                  // 채널명 / 직접 작성
                  if (recipe.channelName != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      recipe.channelName!,
                      style: TextStyle(
                          fontSize: 13,
                          color: softBrownColor.withAlpha(204)),
                    ),
                  ] else if (recipe.source == 'text') ...[
                    const SizedBox(height: 6),
                    const Text(
                      '✏ 직접 작성',
                      style: TextStyle(fontSize: 13, color: softBrownColor),
                    ),
                  ],

                  // 메타 칩
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (recipe.cookingTimeMinutes != null)
                        _MetaChip(Icons.timer_outlined,
                            '${recipe.cookingTimeMinutes}분')
                      else if (recipe.cookingTime != null)
                        _MetaChip(Icons.timer_outlined, recipe.cookingTime!),
                      if (recipe.calories != null)
                        _MetaChip(Icons.local_fire_department_outlined,
                            '${recipe.calories}kcal'),
                      if (recipe.servings != null)
                        _MetaChip(Icons.people_outline, recipe.servings!),
                      if (recipe.difficulty != null)
                        _MetaChip(Icons.bar_chart, recipe.difficulty!),
                    ],
                  ),

                  const Divider(height: 32),

                  // 요약
                  if (recipe.summary != null && recipe.summary!.isNotEmpty) ...[
                    MarkdownBody(
                      data: recipe.summary!,
                      styleSheet: MarkdownStyleSheet(
                        p: const TextStyle(
                            fontSize: 14, color: softBrownColor, height: 1.6),
                        strong: const TextStyle(
                            fontSize: 14,
                            color: warmBrownColor,
                            fontWeight: FontWeight.w600),
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
                    ..._groupIngredients(recipe.ingredients)
                        .entries
                        .map((e) => Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (e.key.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        bottom: 6, top: 4),
                                    child: Text(e.key,
                                        style: const TextStyle(
                                            fontSize: 13,
                                            color: softBrownColor,
                                            fontWeight: FontWeight.w600)),
                                  ),
                                ...e.value.map((ing) => Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 5),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(ing.name,
                                                style: const TextStyle(
                                                    fontSize: 14,
                                                    color: warmBrownColor)),
                                          ),
                                          Text(
                                            [ing.amount, ing.unit]
                                                .whereType<String>()
                                                .join(' '),
                                            style: const TextStyle(
                                                fontSize: 14,
                                                color: softBrownColor),
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
                  if (recipe.tip != null && recipe.tip!.isNotEmpty) ...[
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
                        data: recipe.tip!,
                        styleSheet: MarkdownStyleSheet(
                          p: const TextStyle(
                              fontSize: 14,
                              height: 1.6,
                              color: warmBrownColor),
                          strong: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: warmBrownColor),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // YouTube 원본 링크
                  if (recipe.isYoutube && recipe.videoId != null)
                    _VideoCard(recipe: recipe),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, List<Ingredient>> _groupIngredients(
      List<Ingredient> ingredients) {
    final groups = <String, List<Ingredient>>{};
    for (final ing in ingredients) {
      groups.putIfAbsent(ing.category, () => []).add(ing);
    }
    return groups;
  }
}

// ── 섹션 제목 ──────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
          fontSize: 17, fontWeight: FontWeight.bold, color: warmBrownColor),
    );
  }
}

// ── 메타 칩 ───────────────────────────────────────────────
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
          Text(label,
              style: const TextStyle(fontSize: 12, color: softBrownColor)),
        ],
      ),
    );
  }
}

// ── 조리 단계 ─────────────────────────────────────────────
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
            decoration:
                const BoxDecoration(color: primaryColor, shape: BoxShape.circle),
            child: Center(
              child: Text(
                '${step.stepNumber}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
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
                    p: const TextStyle(
                        fontSize: 14, height: 1.6, color: warmBrownColor),
                    strong: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: warmBrownColor),
                  ),
                ),
                if (step.timer != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.timer_outlined,
                            size: 13, color: primaryColor),
                        const SizedBox(width: 4),
                        Text(step.timer!,
                            style: const TextStyle(
                                fontSize: 12, color: primaryColor)),
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

// ── 맛 프로필 ─────────────────────────────────────────────
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
                    style: const TextStyle(
                        fontSize: 12.5, color: softBrownColor),
                  ),
                ),
                const SizedBox(width: 12),
                Row(
                  children: List.generate(
                    5,
                    (j) => Container(
                      width: 14,
                      height: 14,
                      margin: const EdgeInsets.only(right: 5),
                      decoration: BoxDecoration(
                        color: j < filled ? _axes[i].$2 : lightLineColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  values[i].toStringAsFixed(1),
                  style:
                      const TextStyle(fontSize: 12, color: softBrownColor),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

// ── YouTube 원본 영상 카드 ────────────────────────────────
class _VideoCard extends StatelessWidget {
  const _VideoCard({required this.recipe});
  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: lightLineColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          if (recipe.thumbnailUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: recipe.thumbnailUrl!,
                width: 80,
                height: 56,
                fit: BoxFit.cover,
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (recipe.videoTitle != null)
                  Text(
                    recipe.videoTitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: warmBrownColor),
                  ),
                if (recipe.channelName != null)
                  Text(
                    recipe.channelName!,
                    style: const TextStyle(
                        fontSize: 11, color: softBrownColor),
                  ),
              ],
            ),
          ),
          const Icon(Icons.play_circle_outline,
              color: primaryColor, size: 28),
        ],
      ),
    );
  }
}
