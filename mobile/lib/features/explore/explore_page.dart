import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/api_service.dart';
import '../../core/theme.dart';
import '../../shared/models/recipe_public_item.dart';
import '../../shared/widgets/recipe_card.dart';
import 'explore_provider.dart';
import 'filter_bottom_sheet.dart';

class ExplorePage extends ConsumerStatefulWidget {
  const ExplorePage({super.key});

  @override
  ConsumerState<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends ConsumerState<ExplorePage> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  // 보관함 토글 중인 recipe id 세트
  final Set<int> _collectingIds = {};

  // 오늘 뭐먹지
  bool _randomLoading = false;

  // 상황 태그
  final Set<String> _selectedTags = {};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(exploreNotifierProvider.notifier).loadMore();
    }
  }

  void _onSearch(String value) {
    ref.read(exploreQueryProvider.notifier).state =
        value.trim().isEmpty ? null : value.trim();
  }

  Future<void> _toggleCollect(RecipePublicItem item) async {
    final isLoggedIn = Supabase.instance.client.auth.currentUser != null;
    if (!isLoggedIn) {
      if (mounted) context.push('/login');
      return;
    }

    if (_collectingIds.contains(item.id)) return;
    setState(() => _collectingIds.add(item.id));
    try {
      await ref.read(exploreNotifierProvider.notifier).toggleCollect(item);
    } finally {
      if (mounted) setState(() => _collectingIds.remove(item.id));
    }
  }

  Future<void> _fetchRandom() async {
    setState(() => _randomLoading = true);
    try {
      final isLoggedIn = Supabase.instance.client.auth.currentUser != null;
      final recipe = await ref.read(apiServiceProvider).getRandomRecipe(
        excludeCollected: isLoggedIn,
      );
      if (mounted) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => _RandomModal(
            recipe: recipe,
            apiService: ref.read(apiServiceProvider),
            onReroll: () {
              Navigator.pop(context);
              _fetchRandom();
            },
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('추천을 불러오지 못했어요.')),
        );
      }
    } finally {
      if (mounted) setState(() => _randomLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(exploreFilterProvider);
    final query = ref.watch(exploreQueryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Image.asset('assets/images/logo.png', height: 28),
      ),
      body: RefreshIndicator(
        color: primaryColor,
        onRefresh: () async => ref.invalidate(exploreNotifierProvider),
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // 검색바 + 필터 버튼
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: _onSearch,
                        onSubmitted: _onSearch,
                        decoration: InputDecoration(
                          hintText: '레시피 또는 재료 검색...',
                          prefixIcon: const Icon(Icons.search, color: softBrownColor, size: 20),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    _onSearch('');
                                  },
                                )
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 필터 버튼
                    GestureDetector(
                      onTap: () => showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => FilterBottomSheet(
                          initial: filter,
                          onApply: (f) =>
                              ref.read(exploreFilterProvider.notifier).state = f,
                        ),
                      ),
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: filter.activeCount > 0
                              ? primaryColor.withAlpha(20)
                              : Colors.transparent,
                          border: Border.all(
                            color: filter.activeCount > 0
                                ? primaryColor
                                : lightLineColor,
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.tune,
                              size: 16,
                              color: filter.activeCount > 0 ? primaryColor : softBrownColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              filter.activeCount > 0
                                  ? '필터 ${filter.activeCount}'
                                  : '필터',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: filter.activeCount > 0 ? primaryColor : softBrownColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 활성 필터 배지
            if (filter.activeCount > 0)
              SliverToBoxAdapter(
                child: _ActiveFilterBadges(
                  filter: filter,
                  onRemove: (updated) =>
                      ref.read(exploreFilterProvider.notifier).state = updated,
                ),
              ),

            // 소스 필터 칩
            SliverToBoxAdapter(
              child: _SourceFilterChips(),
            ),

            // 카테고리 칩
            SliverToBoxAdapter(
              child: _CategoryChips(),
            ),

            // 빠른 접근 상황 태그 칩
            SliverToBoxAdapter(
              child: _TagChips(
                selectedTags: _selectedTags,
                onToggle: (tag) {
                  setState(() {
                    if (_selectedTags.contains(tag)) {
                      _selectedTags.remove(tag);
                    } else {
                      _selectedTags.add(tag);
                    }
                  });
                  // TODO: 태그 필터 API 연동 시 여기에 추가
                },
              ),
            ),

            // 오늘 뭐먹지 + 냉장고 파먹기 배너 (검색/필터 없을 때만)
            if (query == null && filter.activeCount == 0) ...[
              SliverToBoxAdapter(
                child: _RandomBanner(
                  loading: _randomLoading,
                  onTap: _fetchRandom,
                ),
              ),
              SliverToBoxAdapter(
                child: _FridgeBanner(
                  onTap: () {
                    // TODO: 냉장고 파먹기 라우팅
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('냉장고 파먹기 기능은 곧 출시 예정이에요!')),
                    );
                  },
                ),
              ),
            ],

            // 검색 결과 레이블
            if (query != null && query.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: _SearchResultLabel(query: query),
                ),
              ),

            // 레시피 그리드
            _RecipeGrid(
              collectingIds: _collectingIds,
              onCollect: _toggleCollect,
            ),

            // 로딩 더보기 인디케이터
            SliverToBoxAdapter(
              child: _LoadMoreIndicator(),
            ),
          ],
        ),
      ),

    );
  }
}

// ── 활성 필터 배지 ─────────────────────────────────────────
class _ActiveFilterBadges extends StatelessWidget {
  const _ActiveFilterBadges({required this.filter, required this.onRemove});
  final ExploreFilter filter;
  final ValueChanged<ExploreFilter> onRemove;

  @override
  Widget build(BuildContext context) {
    final badges = <(String, ExploreFilter)>[];

    if (filter.difficulty != null) {
      final label = {'easy': '쉬움', 'medium': '보통', 'hard': '어려움'}[filter.difficulty] ?? filter.difficulty!;
      badges.add((label, filter.copyWith(difficulty: () => null)));
    }
    if (filter.cookingTime != null) {
      final label = {'20': '20분 이하', '60': '1시간 이하', '61+': '1시간 초과'}[filter.cookingTime] ?? filter.cookingTime!;
      badges.add((label, filter.copyWith(cookingTime: () => null)));
    }
    if (filter.calorieRange != null) {
      final label = {'low': '500kcal↓', 'mid': '500~800kcal', 'high': '800kcal↑'}[filter.calorieRange] ?? filter.calorieRange!;
      badges.add((label, filter.copyWith(calorieRange: () => null)));
    }
    if (filter.hideCollected) {
      badges.add(('저장 숨김', filter.copyWith(hideCollected: false)));
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: badges.map((b) {
          final (label, updated) = b;
          return GestureDetector(
            onTap: () => onRemove(updated),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: primaryColor.withAlpha(20),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: primaryColor, width: 1.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600, color: primaryColor)),
                  const SizedBox(width: 4),
                  const Icon(Icons.close, size: 13, color: primaryColor),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── 소스 필터 칩 ───────────────────────────────────────────
class _SourceFilterChips extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(exploreSourceProvider);
    final options = [
      (null, '전체'),
      ('youtube', '▶ YouTube'),
      ('text', '✏ 직접 작성'),
    ];

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        itemCount: options.length,
        separatorBuilder: (ctx, i) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final (value, label) = options[i];
          final isSelected = selected == value;
          return FilterChip(
            label: Text(label, style: const TextStyle(fontSize: 13)),
            selected: isSelected,
            onSelected: (_) =>
                ref.read(exploreSourceProvider.notifier).state = value,
            selectedColor: primaryColor,
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : softBrownColor,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: isSelected ? primaryColor : lightLineColor,
                width: 1.5,
              ),
            ),
            showCheckmark: false,
            padding: const EdgeInsets.symmetric(horizontal: 4),
          );
        },
      ),
    );
  }
}

// ── 카테고리 칩 ────────────────────────────────────────────
class _CategoryChips extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final selected = ref.watch(exploreCategoryProvider);

    return categoriesAsync.when(
      loading: () => const SizedBox(height: 44),
      error: (err, st) => const SizedBox.shrink(),
      data: (categories) => SizedBox(
        height: 44,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          itemCount: categories.length + 1,
          separatorBuilder: (ctx, i) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final label = i == 0 ? '전체' : categories[i - 1];
            final value = i == 0 ? null : categories[i - 1];
            final isSelected = selected == value;
            return FilterChip(
              label: Text(label, style: const TextStyle(fontSize: 13)),
              selected: isSelected,
              onSelected: (_) =>
                  ref.read(exploreCategoryProvider.notifier).state = value,
              selectedColor: primaryColor,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : softBrownColor,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? primaryColor : lightLineColor,
                  width: 1.5,
                ),
              ),
              showCheckmark: false,
              padding: const EdgeInsets.symmetric(horizontal: 4),
            );
          },
        ),
      ),
    );
  }
}

// ── 오늘 뭐먹지 배너 ──────────────────────────────────────
class _RandomBanner extends StatelessWidget {
  const _RandomBanner({required this.loading, required this.onTap});
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              primaryColor.withAlpha(30),
              const Color(0xFFF5E6C8).withAlpha(120),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          border: Border.all(color: primaryColor.withAlpha(50), width: 1.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Text('🎲', style: TextStyle(fontSize: 26)),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('오늘 뭐 먹지?',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700, color: warmBrownColor)),
                  SizedBox(height: 2),
                  Text('기분에 맞는 레시피를 뽑아드려요',
                      style: TextStyle(fontSize: 12, color: softBrownColor)),
                ],
              ),
            ),
            SizedBox(
              height: 36,
              child: ElevatedButton(
                onPressed: loading ? null : onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                child: loading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('추천받기', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 검색 결과 레이블 ──────────────────────────────────────
class _SearchResultLabel extends ConsumerWidget {
  const _SearchResultLabel({required this.query});
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(exploreNotifierProvider).valueOrNull;
    final count = state?.items.length;
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 13, color: softBrownColor),
        children: [
          TextSpan(
            text: '"$query"',
            style: const TextStyle(fontWeight: FontWeight.w600, color: warmBrownColor),
          ),
          const TextSpan(text: ' 검색 결과'),
          if (count != null)
            TextSpan(
              text: ' (${count}개)',
              style: const TextStyle(
                  fontWeight: FontWeight.w600, color: primaryColor),
            ),
        ],
      ),
    );
  }
}

// ── 레시피 그리드 ──────────────────────────────────────────
class _RecipeGrid extends ConsumerWidget {
  const _RecipeGrid({
    required this.collectingIds,
    required this.onCollect,
  });

  final Set<int> collectingIds;
  final void Function(RecipePublicItem) onCollect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stateAsync = ref.watch(exploreNotifierProvider);

    return stateAsync.when(
      loading: () => SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        sliver: SliverGrid(
          delegate: SliverChildBuilderDelegate(
            (context, i) => const _SkeletonCard(),
            childCount: 6,
          ),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.70,
          ),
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
                const Text('네트워크 오류', style: TextStyle(color: softBrownColor)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(exploreNotifierProvider),
                  child: const Text('다시 시도'),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (state) {
        if (state.items.isEmpty) {
          return const SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(60),
                child: Column(
                  children: [
                    Text('🍽️', style: TextStyle(fontSize: 48)),
                    SizedBox(height: 12),
                    Text('레시피가 없어요',
                        style: TextStyle(color: softBrownColor)),
                  ],
                ),
              ),
            ),
          );
        }
        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                final recipe = state.items[i];
                return RecipeCard(
                  recipe: recipe,
                  isCollecting: collectingIds.contains(recipe.id),
                  onCollect: () => onCollect(recipe),
                  onTap: () {
                    // 공개 레시피는 /recipe/{id} 또는 보관 시 /my-recipes/{id}
                    if (recipe.isCollected && recipe.myCollectionId != null && recipe.myCollectionId! > 0) {
                      context.push('/my-recipes/${recipe.myCollectionId}');
                    } else {
                      // 비로그인 / 미보관: 일단 탐색 상세 (추후 구현)
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('내 레시피에 추가한 뒤 볼 수 있어요.')),
                      );
                    }
                  },
                );
              },
              childCount: state.items.length,
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.70,
            ),
          ),
        );
      },
    );
  }
}

// ── 무한 스크롤 로딩 인디케이터 ─────────────────────────────
class _LoadMoreIndicator extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(exploreNotifierProvider).valueOrNull;
    if (state == null || !state.loadingMore) return const SizedBox(height: 80);
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Center(child: CircularProgressIndicator(color: primaryColor)),
    );
  }
}

// ── 오늘 뭐먹지 결과 모달 ─────────────────────────────────
class _RandomModal extends StatefulWidget {
  const _RandomModal({
    required this.recipe,
    required this.apiService,
    required this.onReroll,
  });

  final RecipePublicItem recipe;
  final ApiService apiService;
  final VoidCallback onReroll;

  @override
  State<_RandomModal> createState() => _RandomModalState();
}

class _RandomModalState extends State<_RandomModal> {
  late RecipePublicItem _recipe;
  bool _collecting = false;

  @override
  void initState() {
    super.initState();
    _recipe = widget.recipe;
  }

  Future<void> _collect() async {
    final isLoggedIn = Supabase.instance.client.auth.currentUser != null;
    if (!isLoggedIn) {
      Navigator.pop(context);
      context.push('/login');
      return;
    }
    setState(() => _collecting = true);
    try {
      final collectionId = await widget.apiService.saveToCollection(_recipe.id);
      setState(() {
        _recipe = _recipe.copyWith(myCollectionId: () => collectionId);
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _collecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: paperColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewPadding.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 핸들
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: lightLineColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // 헤더
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            child: Row(
              children: [
                const Text('🎲 오늘의 추천',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold, color: darkColor)),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: softBrownColor),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // 썸네일
          if (_recipe.thumbnailUrl != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    _recipe.thumbnailUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (ctx, e, st) => Container(color: creamColor),
                  ),
                ),
              ),
            ),

          // 정보
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_recipe.title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold, color: darkColor)),
                if (_recipe.channelName != null) ...[
                  const SizedBox(height: 4),
                  Text(_recipe.channelName!,
                      style: const TextStyle(fontSize: 13, color: softBrownColor)),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: [
                    if (_recipe.cookingTimeMinutes != null)
                      _ModalChip(
                          icon: Icons.timer_outlined,
                          label: '${_recipe.cookingTimeMinutes}분'),
                    if (_recipe.difficulty != null)
                      _ModalChip(
                          label:
                              {'easy': '쉬움', 'medium': '보통', 'hard': '어려움'}[_recipe.difficulty] ??
                                  _recipe.difficulty!),
                    if (_recipe.calories != null)
                      _ModalChip(label: '🔥 ${_recipe.calories}kcal', isCalorie: true),
                  ],
                ),
              ],
            ),
          ),

          // 버튼
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onReroll,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: lightLineColor),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('다시 뽑기',
                        style: TextStyle(color: softBrownColor)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _recipe.isCollected
                      ? ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            if (_recipe.myCollectionId != null && _recipe.myCollectionId! > 0) {
                              context.push('/my-recipes/${_recipe.myCollectionId}');
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6B9E6B),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('내 레시피 보러가기'),
                        )
                      : ElevatedButton(
                          onPressed: _collecting ? null : _collect,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _collecting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Text('내 레시피에 추가'),
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

class _ModalChip extends StatelessWidget {
  const _ModalChip({this.icon, required this.label, this.isCalorie = false});
  final IconData? icon;
  final String label;
  final bool isCalorie;

  @override
  Widget build(BuildContext context) {
    final color = isCalorie ? const Color(0xFFB84C00) : softBrownColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isCalorie ? const Color(0xFFFFF0E6) : creamColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 3),
          ],
          Text(label, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }
}

// ── 상황 태그 칩 ─────────────────────────────────────────
class _TagChips extends StatelessWidget {
  const _TagChips({required this.selectedTags, required this.onToggle});
  final Set<String> selectedTags;
  final ValueChanged<String> onToggle;

  static const _quickTags = ['간편식', '특별한날', '야식', '다이어트', '해장'];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _quickTags.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final tag = _quickTags[i];
          final isSelected = selectedTags.contains(tag);
          return GestureDetector(
            onTap: () => onToggle(tag),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected ? primaryColor : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? primaryColor : lightLineColor,
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Text(
                  '#$tag',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? Colors.white : softBrownColor,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── 냉장고 파먹기 배너 ──────────────────────────────────
class _FridgeBanner extends StatelessWidget {
  const _FridgeBanner({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              primaryColor.withAlpha(30),
              const Color(0xFFF5E6C8).withAlpha(120),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          border: Border.all(color: primaryColor.withAlpha(50), width: 1.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Text('🧊', style: TextStyle(fontSize: 26)),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('냉장고 파먹기',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700, color: darkColor)),
                  SizedBox(height: 2),
                  Text('있는 재료로 뭘 만들 수 있을까?',
                      style: TextStyle(fontSize: 12, color: softBrownColor)),
                ],
              ),
            ),
            SizedBox(
              height: 36,
              child: ElevatedButton(
                onPressed: onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                child: const Text('시작하기', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 스켈레톤 카드 (로딩 중 표시) ─────────────────────────
class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: creamColor,
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 썸네일 스켈레톤
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(color: lightLineColor),
          ),
          // 텍스트 스켈레톤
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 12,
                  width: double.infinity * 0.85,
                  decoration: BoxDecoration(
                    color: lightLineColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 6),
                FractionallySizedBox(
                  widthFactor: 0.5,
                  alignment: Alignment.centerLeft,
                  child: Container(
                    height: 12,
                    decoration: BoxDecoration(
                      color: lightLineColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
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
