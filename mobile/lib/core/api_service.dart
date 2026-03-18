import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import 'dio_client.dart';
import '../shared/models/recipe.dart';
import '../shared/models/recipe_public_item.dart';
import '../shared/models/collection_item.dart';
import '../shared/models/cart_item.dart';

// Dio 인스턴스 provider
final dioProvider = Provider<Dio>((ref) => createDioClient());

// API 서비스 provider
final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService(ref.watch(dioProvider));
});

class ApiService {
  ApiService(this._dio);
  final Dio _dio;

  // ── 공개 레시피 탐색 ──────────────────────────────────────
  Future<PublicRecipesResult> getPublicRecipes({
    String? category,
    String? q,
    String sort = 'latest',
    String? source,
    int page = 1,
    int limit = 20,
    String? difficulty,
    int? maxTime,
    int? minTime,
    int? maxCalories,
    int? minCalories,
    bool hideCollected = false,
    List<String> tags = const [],
  }) async {
    final resp = await _dio.get<Map<String, dynamic>>(
      '/recipes',
      queryParameters: {
        if (category != null && category.isNotEmpty) 'category': category,
        if (q != null && q.isNotEmpty) 'q': q,
        'sort': sort,
        if (source != null && source.isNotEmpty) 'source': source,
        'page': page,
        'limit': limit,
        if (difficulty != null && difficulty.isNotEmpty) 'difficulty': difficulty,
        if (maxTime != null) 'max_time': maxTime,
        if (minTime != null) 'min_time': minTime,
        if (maxCalories != null) 'max_calories': maxCalories,
        if (minCalories != null) 'min_calories': minCalories,
        if (hideCollected) 'hide_collected': true,
        if (tags.isNotEmpty) 'tags': tags,
      },
    );
    final data = resp.data!;
    final items = (data['items'] as List)
        .map((e) => RecipePublicItem.fromJson(e as Map<String, dynamic>))
        .toList();
    return PublicRecipesResult(
      items: items,
      total: data['total'] as int,
      hasMore: data['has_more'] as bool,
    );
  }

  // ── 카테고리 목록 ──────────────────────────────────────────
  Future<List<String>> getCategories() async {
    final resp = await _dio.get<List<dynamic>>('/recipes/categories');
    return resp.data!
        .map((e) => (e as Map<String, dynamic>)['category'] as String)
        .toList();
  }

  // ── 내 레시피 목록 ─────────────────────────────────────────
  Future<List<CollectionListItem>> getMyCollections(
    String userId, {
    String? category,
    String? q,
    String? source,
    bool? isFavorite,
    int? tagId,
    String sort = 'latest',
  }) async {
    final resp = await _dio.get<List<dynamic>>(
      '/collections/$userId',
      queryParameters: {
        'category': category,
        if (q != null && q.isNotEmpty) 'q': q,
        'source': source,
        if (isFavorite == true) 'is_favorite': 'true',
        if (tagId != null) 'tag_id': tagId,
        'sort': sort,
      },
    );
    return resp.data!
        .map((e) => CollectionListItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── 컬렉션 상세 ────────────────────────────────────────────
  Future<CollectionItem> getCollectionItem(int collectionId) async {
    final resp = await _dio.get<Map<String, dynamic>>(
      '/collections/item/$collectionId',
    );
    return CollectionItem.fromJson(resp.data!);
  }

  // ── 즐겨찾기 토글 ──────────────────────────────────────────
  Future<void> toggleFavorite(int collectionId) async {
    await _dio.put('/collections/$collectionId/favorite');
  }

  // ── 장바구니 ───────────────────────────────────────────────
  Future<List<CartGroup>> getCart() async {
    final resp = await _dio.get<List<dynamic>>('/cart');
    return resp.data!
        .map((e) => CartGroup.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> addToCart(int collectionId) async {
    await _dio.post('/cart/from-collection/$collectionId');
  }

  Future<void> toggleCartItem(int itemId, bool checked) async {
    await _dio.put('/cart/items/$itemId/check',
        data: {'is_checked': checked});
  }

  Future<void> deleteCartItem(int itemId) async {
    await _dio.delete('/cart/items/$itemId');
  }

  Future<void> clearCheckedCart() async {
    await _dio.delete('/cart/checked');
  }

  Future<void> clearCart() async {
    await _dio.delete('/cart');
  }

  // ── 컬렉션 수정 ────────────────────────────────────────────
  Future<void> patchCollection(
    int collectionId, {
    String? customTip,
    Map<String, dynamic>? recipeOverride,
    bool clearOverride = false,
  }) async {
    final data = <String, dynamic>{};
    if (customTip != null) data['custom_tip'] = customTip;
    if (clearOverride) {
      data['recipe_override'] = null;
    } else if (recipeOverride != null) {
      data['recipe_override'] = recipeOverride;
    }
    await _dio.patch('/collections/$collectionId', data: data);
  }

  // ── 레시피 추출 ────────────────────────────────────────────
  Future<Map<String, dynamic>> extractFromYoutube(String youtubeUrl) async {
    final resp = await _dio.post<Map<String, dynamic>>(
      '/extract-recipe',
      data: {
        'youtube_url': youtubeUrl,
        'mode': 'fast',
        'auto_save': true,
      },
    );
    return resp.data!;
  }

  Future<Map<String, dynamic>> extractFromText(String text, {String? title}) async {
    final resp = await _dio.post<Map<String, dynamic>>(
      '/extract-recipe-from-text',
      data: {
        'text': text,
        if (title != null && title.isNotEmpty) 'title': title,
      },
    );
    return resp.data!;
  }

  Future<int> saveTextRecipe(Recipe recipe, {bool isPublic = false}) async {
    final resp = await _dio.post<Map<String, dynamic>>(
      '/collections/text-recipe',
      data: {
        'recipe': recipe.toJson(),
        'is_public': isPublic,
      },
    );
    return resp.data!['collection_id'] as int;
  }

  // ── AI 채팅 ────────────────────────────────────────────────
  Future<String> aiChat(
    int collectionId,
    String message,
    List<Map<String, String>> history,
  ) async {
    final resp = await _dio.post<Map<String, dynamic>>(
      '/ai/chat',
      data: {
        'collection_id': collectionId,
        'message': message,
        'history': history,
      },
    );
    return resp.data!['reply'] as String;
  }

  Future<String> meokdangChat(
    String message,
    List<Map<String, String>> history, {
    String? userName,
  }) async {
    final resp = await _dio.post<Map<String, dynamic>>(
      '/ai/meokdang-chat',
      data: {
        'message': message,
        'history': history,
        if (userName != null) 'user_name': userName,
      },
    );
    return resp.data!['reply'] as String;
  }

  // ── 별점 설정 ─────────────────────────────────────────────
  Future<void> setRating(int collectionId, int rating) async {
    await _dio.put('/collections/$collectionId/rating',
        data: {'rating': rating});
  }

  // ── 요리 기록 ─────────────────────────────────────────────
  Future<Map<String, dynamic>> recordCooked(int collectionId, {int? rating}) async {
    final resp = await _dio.post<Map<String, dynamic>>(
      '/collections/$collectionId/cooked',
      data: {if (rating != null) 'rating': rating},
    );
    return resp.data!;
  }

  // ── 보관함 추가/해제 ──────────────────────────────────────
  Future<int> saveToCollection(int recipeId) async {
    final resp = await _dio.post<Map<String, dynamic>>(
      '/collections',
      data: {'recipe_id': recipeId},
    );
    return resp.data!['collection_id'] as int;
  }

  Future<void> removeFromCollection(int collectionId) async {
    await _dio.delete('/collections/$collectionId');
  }

  // ── 랜덤 레시피 ────────────────────────────────────────────
  Future<RecipePublicItem> getRandomRecipe({bool excludeCollected = false}) async {
    final resp = await _dio.get<Map<String, dynamic>>(
      '/recipes/random',
      queryParameters: excludeCollected ? {'exclude_collected': true} : {},
    );
    return RecipePublicItem.fromJson(resp.data!);
  }

  // ── 공개 레시피 단건 조회 ──────────────────────────────────
  Future<Recipe> getPublicRecipe(int recipeId) async {
    final resp = await _dio.get<Map<String, dynamic>>('/recipes/$recipeId');
    return Recipe.fromJson(resp.data!);
  }

  // ── 냉장고 파먹기 ──────────────────────────────────────────
  Future<List<FridgeSearchItem>> fridgeSearch(List<String> ingredients, {int limit = 10}) async {
    final resp = await _dio.post<List<dynamic>>(
      '/recipes/fridge-search',
      data: {'ingredients': ingredients, 'limit': limit},
    );
    return resp.data!.map((e) => FridgeSearchItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ── 마이페이지 ─────────────────────────────────────────────
  Future<Map<String, dynamic>> getTasteProfile() async {
    final resp = await _dio.get<Map<String, dynamic>>('/my/taste-profile');
    return resp.data!;
  }

  // ── 태그 목록 (내 컬렉션 태그) ────────────────────────────
  Future<List<Map<String, dynamic>>> getTags(String userId) async {
    final resp = await _dio.get<List<dynamic>>('/tags/$userId');
    return resp.data!
        .map((e) => e as Map<String, dynamic>)
        .toList();
  }
}

class FridgeSearchItem {
  final int id;
  final String title;
  final String? category;
  final String? cookingTime;
  final String? difficulty;
  final String? videoId;
  final String? channelName;
  final String? source;
  final int collectionCount;
  final double matchScore;
  final List<String> matchedIngredients;

  const FridgeSearchItem({
    required this.id,
    required this.title,
    this.category,
    this.cookingTime,
    this.difficulty,
    this.videoId,
    this.channelName,
    this.source,
    required this.collectionCount,
    required this.matchScore,
    required this.matchedIngredients,
  });

  factory FridgeSearchItem.fromJson(Map<String, dynamic> json) => FridgeSearchItem(
    id: json['id'] as int,
    title: json['title'] as String,
    category: json['category'] as String?,
    cookingTime: json['cooking_time'] as String?,
    difficulty: json['difficulty'] as String?,
    videoId: json['video_id'] as String?,
    channelName: json['channel_name'] as String?,
    source: json['source'] as String?,
    collectionCount: json['collection_count'] as int? ?? 0,
    matchScore: (json['match_score'] as num).toDouble(),
    matchedIngredients: (json['matched_ingredients'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList() ??
        [],
  );

  String? get thumbnailUrl =>
      videoId != null ? 'https://img.youtube.com/vi/$videoId/mqdefault.jpg' : null;
}

class PublicRecipesResult {
  final List<RecipePublicItem> items;
  final int total;
  final bool hasMore;
  const PublicRecipesResult({
    required this.items,
    required this.total,
    required this.hasMore,
  });
}
