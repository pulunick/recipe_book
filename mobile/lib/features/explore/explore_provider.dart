import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_service.dart';
import '../../shared/models/recipe_public_item.dart';

// ── 필터 상태 ─────────────────────────────────────────────
class ExploreFilter {
  final String sort;
  final String? difficulty;
  final String? cookingTime; // '20' | '60' | '61+'
  final String? calorieRange; // 'low' | 'mid' | 'high'
  final bool hideCollected;

  const ExploreFilter({
    this.sort = 'latest',
    this.difficulty,
    this.cookingTime,
    this.calorieRange,
    this.hideCollected = false,
  });

  int get activeCount =>
      (difficulty != null ? 1 : 0) +
      (cookingTime != null ? 1 : 0) +
      (calorieRange != null ? 1 : 0) +
      (hideCollected ? 1 : 0);

  ExploreFilter copyWith({
    String? sort,
    String? Function()? difficulty,
    String? Function()? cookingTime,
    String? Function()? calorieRange,
    bool? hideCollected,
  }) {
    return ExploreFilter(
      sort: sort ?? this.sort,
      difficulty: difficulty != null ? difficulty() : this.difficulty,
      cookingTime: cookingTime != null ? cookingTime() : this.cookingTime,
      calorieRange: calorieRange != null ? calorieRange() : this.calorieRange,
      hideCollected: hideCollected ?? this.hideCollected,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExploreFilter &&
          sort == other.sort &&
          difficulty == other.difficulty &&
          cookingTime == other.cookingTime &&
          calorieRange == other.calorieRange &&
          hideCollected == other.hideCollected;

  @override
  int get hashCode => Object.hash(sort, difficulty, cookingTime, calorieRange, hideCollected);
}

// ── 탐색 목록 상태 ─────────────────────────────────────────
class ExploreListState {
  final List<RecipePublicItem> items;
  final bool hasMore;
  final bool loadingMore;
  final int page;

  const ExploreListState({
    required this.items,
    this.hasMore = true,
    this.loadingMore = false,
    this.page = 1,
  });

  ExploreListState copyWith({
    List<RecipePublicItem>? items,
    bool? hasMore,
    bool? loadingMore,
    int? page,
  }) {
    return ExploreListState(
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      loadingMore: loadingMore ?? this.loadingMore,
      page: page ?? this.page,
    );
  }
}

// ── 필터 providers ─────────────────────────────────────────
final exploreCategoryProvider = StateProvider<String?>((ref) => null);
final exploreSourceProvider = StateProvider<String?>((ref) => null);
final exploreQueryProvider = StateProvider<String?>((ref) => null);
final exploreFilterProvider = StateProvider<ExploreFilter>((ref) => const ExploreFilter());

// ── 카테고리 목록 ──────────────────────────────────────────
final categoriesProvider = FutureProvider<List<String>>((ref) {
  return ref.watch(apiServiceProvider).getCategories();
});

// ── 탐색 목록 Notifier ─────────────────────────────────────
final exploreNotifierProvider =
    AsyncNotifierProvider<ExploreNotifier, ExploreListState>(ExploreNotifier.new);

class ExploreNotifier extends AsyncNotifier<ExploreListState> {
  @override
  Future<ExploreListState> build() async {
    // 필터 변경 시 자동 재빌드
    ref.watch(exploreCategoryProvider);
    ref.watch(exploreSourceProvider);
    ref.watch(exploreQueryProvider);
    ref.watch(exploreFilterProvider);

    return _fetchPage(1);
  }

  Future<ExploreListState> _fetchPage(int page) async {
    final category = ref.read(exploreCategoryProvider);
    final source = ref.read(exploreSourceProvider);
    final query = ref.read(exploreQueryProvider);
    final filter = ref.read(exploreFilterProvider);

    final maxTime = filter.cookingTime == '20'
        ? 20
        : filter.cookingTime == '60'
            ? 60
            : null;
    final minTime = filter.cookingTime == '61+' ? 60 : null;
    final maxCal = filter.calorieRange == 'low'
        ? 500
        : filter.calorieRange == 'mid'
            ? 800
            : null;
    final minCal = filter.calorieRange == 'mid'
        ? 500
        : filter.calorieRange == 'high'
            ? 800
            : null;

    final result = await ref.read(apiServiceProvider).getPublicRecipes(
      category: category,
      source: source,
      sort: filter.sort,
      q: query,
      page: page,
      difficulty: filter.difficulty,
      maxTime: maxTime,
      minTime: minTime,
      maxCalories: maxCal,
      minCalories: minCal,
      hideCollected: filter.hideCollected,
    );

    return ExploreListState(
      items: result.items,
      hasMore: result.hasMore,
      page: page,
    );
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.loadingMore) return;

    state = AsyncData(current.copyWith(loadingMore: true));

    try {
      final next = await _fetchPage(current.page + 1);
      state = AsyncData(ExploreListState(
        items: [...current.items, ...next.items],
        hasMore: next.hasMore,
        loadingMore: false,
        page: next.page,
      ));
    } catch (e) {
      state = AsyncData(current.copyWith(loadingMore: false));
    }
  }

  Future<void> toggleCollect(RecipePublicItem item) async {
    final current = state.valueOrNull;
    if (current == null) return;

    // 낙관적 UI 업데이트
    final updatedItems = current.items.map((r) {
      if (r.id != item.id) return r;
      return r.copyWith(myCollectionId: () => item.isCollected ? null : -1);
    }).toList();
    state = AsyncData(current.copyWith(items: updatedItems));

    try {
      if (item.isCollected) {
        await ref.read(apiServiceProvider).removeFromCollection(item.myCollectionId!);
      } else {
        final collectionId = await ref.read(apiServiceProvider).saveToCollection(item.id);
        final confirmed = current.items.map((r) {
          if (r.id != item.id) return r;
          return r.copyWith(myCollectionId: () => collectionId);
        }).toList();
        state = AsyncData(current.copyWith(items: confirmed));
      }
    } catch (_) {
      // 실패 시 롤백
      state = AsyncData(current.copyWith(items: current.items));
    }
  }
}
