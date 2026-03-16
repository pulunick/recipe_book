import 'recipe.dart';

class CollectionTag {
  final int id;
  final String name;
  final String color;

  const CollectionTag({required this.id, required this.name, required this.color});

  factory CollectionTag.fromJson(Map<String, dynamic> j) => CollectionTag(
        id: j['id'] as int,
        name: j['name'] as String,
        color: j['color'] as String? ?? '#8B6F5E',
      );
}

class CollectionItem {
  final int id;
  final Recipe recipe;
  final String? customTip;
  final Map<String, dynamic>? recipeOverride;
  final String createdAt;
  final bool isFavorite;
  final int? myRating;
  final int cookedCount;
  final String? lastCookedAt;
  final String? categoryOverride;
  final List<CollectionTag> tags;

  const CollectionItem({
    required this.id,
    required this.recipe,
    this.customTip,
    this.recipeOverride,
    required this.createdAt,
    required this.isFavorite,
    this.myRating,
    required this.cookedCount,
    this.lastCookedAt,
    this.categoryOverride,
    required this.tags,
  });

  factory CollectionItem.fromJson(Map<String, dynamic> j) => CollectionItem(
        id: j['id'] as int,
        recipe: Recipe.fromJson(j['recipe'] as Map<String, dynamic>),
        customTip: j['custom_tip'] as String?,
        recipeOverride: j['recipe_override'] as Map<String, dynamic>?,
        createdAt: j['created_at'] as String,
        isFavorite: j['is_favorite'] as bool? ?? false,
        myRating: j['my_rating'] as int?,
        cookedCount: j['cooked_count'] as int? ?? 0,
        lastCookedAt: j['last_cooked_at'] as String?,
        categoryOverride: j['category_override'] as String?,
        tags: (j['tags'] as List? ?? [])
            .map((e) => CollectionTag.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  String get displayCategory => categoryOverride ?? recipe.category ?? '';
}

// 내 레시피 목록용 경량 모델
class CollectionListItem {
  final int id;
  final int recipeId;
  final String title;
  final String? videoId;
  final String? category;
  final String? categoryOverride;
  final String? source;
  final bool isFavorite;
  final int? myRating;
  final int cookedCount;
  final int? calories;
  final int? cookingTimeMinutes;
  final String? channelName;

  const CollectionListItem({
    required this.id,
    required this.recipeId,
    required this.title,
    this.videoId,
    this.category,
    this.categoryOverride,
    this.source,
    required this.isFavorite,
    this.myRating,
    required this.cookedCount,
    this.calories,
    this.cookingTimeMinutes,
    this.channelName,
  });

  factory CollectionListItem.fromJson(Map<String, dynamic> j) {
    final recipe = j['recipe'] as Map<String, dynamic>? ?? j;
    return CollectionListItem(
      id: j['id'] as int,
      recipeId: (recipe['id'] ?? j['recipe_id']) as int,
      title: recipe['title'] as String? ?? j['title'] as String,
      videoId: recipe['video_id'] as String?,
      category: recipe['category'] as String?,
      categoryOverride: j['category_override'] as String?,
      source: recipe['source'] as String?,
      isFavorite: j['is_favorite'] as bool? ?? false,
      myRating: j['my_rating'] as int?,
      cookedCount: j['cooked_count'] as int? ?? 0,
      calories: recipe['calories'] as int?,
      cookingTimeMinutes: recipe['cooking_time_minutes'] as int?,
      channelName: recipe['channel_name'] as String?,
    );
  }

  String? get thumbnailUrl =>
      videoId != null ? 'https://img.youtube.com/vi/$videoId/mqdefault.jpg' : null;

  String get displayCategory => categoryOverride ?? category ?? '';
  bool get isYoutube => source == 'youtube';
}
