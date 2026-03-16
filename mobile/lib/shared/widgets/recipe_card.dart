import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/theme.dart';
import '../models/recipe_public_item.dart';

class RecipeCard extends StatelessWidget {
  const RecipeCard({
    super.key,
    required this.recipe,
    this.onTap,
    this.onCollect,
    this.isCollecting = false,
  });

  final RecipePublicItem recipe;
  final VoidCallback? onTap;
  final VoidCallback? onCollect;
  final bool isCollecting;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: lightLineColor),
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
                  if (recipe.thumbnailUrl != null)
                    CachedNetworkImage(
                      imageUrl: recipe.thumbnailUrl!,
                      fit: BoxFit.cover,
                      placeholder: (ctx, url) => Container(color: creamColor),
                      errorWidget: (ctx, url, err) => _PlaceholderThumbnail(recipe: recipe),
                    )
                  else
                    _PlaceholderThumbnail(recipe: recipe),

                  // 카테고리 배지 (썸네일 하단 왼쪽 오버레이)
                  if (recipe.category != null)
                    Positioned(
                      bottom: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(140),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          recipe.category!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                  // 보관함 버튼 (상단 오른쪽)
                  if (onCollect != null)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: GestureDetector(
                        onTap: isCollecting ? null : onCollect,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: recipe.isCollected
                                ? primaryColor
                                : Colors.white.withAlpha(224),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(38),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: isCollecting
                              ? Padding(
                                  padding: const EdgeInsets.all(7),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: recipe.isCollected ? Colors.white : primaryColor,
                                  ),
                                )
                              : Icon(
                                  recipe.isCollected
                                      ? Icons.bookmark
                                      : Icons.bookmark_border,
                                  size: 16,
                                  color: recipe.isCollected ? Colors.white : softBrownColor,
                                ),
                        ),
                      ),
                    ),

                  // 직접 작성 배지 (상단 왼쪽, 보관함 버튼 없을 때)
                  if (!recipe.isYoutube && onCollect == null)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: primaryColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          '✏ 직접 작성',
                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // 텍스트 영역
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 제목
                  Text(
                    recipe.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: warmBrownColor,
                      height: 1.35,
                    ),
                  ),

                  const SizedBox(height: 6),

                  // 메타 칩 (시간, 난이도, 칼로리)
                  Wrap(
                    spacing: 4,
                    runSpacing: 2,
                    children: [
                      if (recipe.cookingTimeMinutes != null)
                        _MetaChip(
                          icon: Icons.timer_outlined,
                          label: '${recipe.cookingTimeMinutes}분',
                        ),
                      if (recipe.difficulty != null)
                        _MetaChip(
                          label: const {'easy': '쉬움', 'medium': '보통', 'hard': '어려움'}[recipe.difficulty] ?? recipe.difficulty!,
                        ),
                      if (recipe.calories != null)
                        _MetaChip(
                          icon: Icons.local_fire_department_outlined,
                          label: '${recipe.calories}kcal',
                          isCalorie: true,
                        ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  // 채널명 / 직접 작성
                  if (recipe.channelName != null)
                    Row(
                      children: [
                        if (recipe.isYoutube)
                          const Text(
                            '▶ ',
                            style: TextStyle(fontSize: 10, color: Color(0xFFFF0000)),
                          ),
                        Expanded(
                          child: Text(
                            recipe.channelName!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, color: softBrownColor.withAlpha(191)),
                          ),
                        ),
                      ],
                    )
                  else if (!recipe.isYoutube)
                    const Row(
                      children: [
                        Text(
                          '✏ ',
                          style: TextStyle(fontSize: 10, color: primaryColor),
                        ),
                        Text(
                          '직접 작성',
                          style: TextStyle(fontSize: 11, color: softBrownColor),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({this.icon, required this.label, this.isCalorie = false});
  final IconData? icon;
  final String label;
  final bool isCalorie;

  @override
  Widget build(BuildContext context) {
    final color = isCalorie ? const Color(0xFFB84C00) : softBrownColor;
    final bgColor = isCalorie ? const Color(0xFFFFF0E6) : paperColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 2),
          ],
          Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: isCalorie ? FontWeight.w600 : FontWeight.normal)),
        ],
      ),
    );
  }
}

class _PlaceholderThumbnail extends StatelessWidget {
  const _PlaceholderThumbnail({required this.recipe});
  final RecipePublicItem recipe;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: creamColor,
      child: Center(
        child: Icon(
          Icons.play_circle_outline,
          size: 40,
          color: softBrownColor.withAlpha(102), // opacity: 0.4
        ),
      ),
    );
  }
}
