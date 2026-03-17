import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_service.dart';
import '../../shared/models/collection_item.dart';
import '../../shared/providers/auth_provider.dart';

final myRecipesCategoryProvider = StateProvider<String?>((ref) => null);
final myRecipesSourceProvider = StateProvider<String?>((ref) => null);
final myRecipesQueryProvider = StateProvider<String?>((ref) => null);
final myRecipesFavoriteOnlyProvider = StateProvider<bool>((ref) => false);
final myRecipesTagIdProvider = StateProvider<int?>((ref) => null);

final myTagsProvider = FutureProvider<List<CollectionTag>>((ref) async {
  final userAsync = ref.watch(currentUserProvider);
  final user = userAsync.valueOrNull;
  if (user == null) return [];

  final raw = await ref.watch(apiServiceProvider).getTags(user.id);
  return raw
      .map((e) => CollectionTag.fromJson(e))
      .toList();
});

// 카테고리 목록 추출용 — source+q 필터만 적용 (category/tag 제외)
final myAllRecipesForCategoriesProvider = FutureProvider<List<CollectionListItem>>((ref) async {
  final userAsync = ref.watch(currentUserProvider);
  final user = userAsync.valueOrNull;
  if (user == null) return [];

  final source = ref.watch(myRecipesSourceProvider);
  final q = ref.watch(myRecipesQueryProvider);

  return ref.watch(apiServiceProvider).getMyCollections(
    user.id,
    source: source,
    q: q,
  );
});

final myRecipesProvider = FutureProvider<List<CollectionListItem>>((ref) async {
  final userAsync = ref.watch(currentUserProvider);
  final user = userAsync.valueOrNull;
  if (user == null) return [];

  final category = ref.watch(myRecipesCategoryProvider);
  final source = ref.watch(myRecipesSourceProvider);
  final q = ref.watch(myRecipesQueryProvider);
  final favoriteOnly = ref.watch(myRecipesFavoriteOnlyProvider);

  final tagId = ref.watch(myRecipesTagIdProvider);

  return ref.watch(apiServiceProvider).getMyCollections(
    user.id,
    category: category,
    source: source,
    q: q,
    isFavorite: favoriteOnly ? true : null,
    tagId: tagId,
  );
});
