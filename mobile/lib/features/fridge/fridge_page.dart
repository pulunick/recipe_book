import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_service.dart';
import '../../core/theme.dart';
import '../../shared/providers/auth_provider.dart';

const _kRecommended = [
  '김치', '돼지고기', '두부', '계란', '양파', '파', '마늘', '간장',
  '고추장', '감자', '당근', '버섯', '치즈', '소시지', '참치캔', '라면',
];

const _kDifficultyLabel = {'easy': '쉬움', 'medium': '보통', 'hard': '어려움'};

class FridgePage extends ConsumerStatefulWidget {
  const FridgePage({super.key});

  @override
  ConsumerState<FridgePage> createState() => _FridgePageState();
}

class _FridgePageState extends ConsumerState<FridgePage> {
  final _inputController = TextEditingController();
  final _inputFocus = FocusNode();
  final List<String> _ingredients = [];

  bool _loading = false;
  bool _searched = false;
  String _error = '';
  List<FridgeSearchItem> _results = [];

  // 보관함 추가 중인 id
  final Set<int> _addingIds = {};
  // 보관함 추가 완료 id → collection_id
  final Map<int, int> _collectedMap = {};

  @override
  void dispose() {
    _inputController.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  void _addIngredient(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed.length < 1) return;
    if (_ingredients.length >= 15) return;
    if (_ingredients.contains(trimmed)) return;
    setState(() => _ingredients.add(trimmed));
  }

  void _removeIngredient(String name) =>
      setState(() => _ingredients.remove(name));

  void _onSubmit(String value) {
    final cleaned = value.replaceAll(',', '').trim();
    if (cleaned.isNotEmpty) _addIngredient(cleaned);
    _inputController.clear();
  }

  void _onChanged(String value) {
    if (value.endsWith(',')) {
      final cleaned = value.replaceAll(',', '').trim();
      if (cleaned.isNotEmpty) _addIngredient(cleaned);
      _inputController.clear();
    }
  }

  Future<void> _search() async {
    if (_ingredients.isEmpty || _loading) return;
    setState(() {
      _loading = true;
      _error = '';
      _searched = false;
      _results = [];
    });
    try {
      final results = await ref.read(apiServiceProvider).fridgeSearch(_ingredients);
      setState(() {
        _results = results;
        _searched = true;
      });
    } catch (e) {
      setState(() {
        _error = '검색 중 오류가 발생했어요.';
        _searched = true;
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _handleCollect(FridgeSearchItem item) async {
    final existingId = _collectedMap[item.id];
    if (existingId != null) {
      context.push('/my-recipes/$existingId');
      return;
    }

    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) {
      context.push('/login');
      return;
    }
    if (_addingIds.contains(item.id)) return;

    setState(() => _addingIds.add(item.id));
    try {
      final collectionId = await ref.read(apiServiceProvider).saveToCollection(item.id);
      setState(() => _collectedMap[item.id] = collectionId);
    } catch (_) {
      // 실패 무시
    } finally {
      setState(() => _addingIds.remove(item.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: paperColor,
      body: SafeArea(
        child: Column(
          children: [
            // 상단 바
            _TopBar(),

            // 스크롤 영역
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 40),
                children: [
                  // 안내 영역
                  _IntroSection(),

                  // 재료 입력
                  _IngredientInputSection(
                    ingredients: _ingredients,
                    controller: _inputController,
                    focusNode: _inputFocus,
                    onSubmit: _onSubmit,
                    onChanged: _onChanged,
                    onRemove: _removeIngredient,
                  ),

                  // 추천 재료
                  _RecommendSection(
                    ingredients: _ingredients,
                    onTap: _addIngredient,
                  ),

                  // 검색 버튼
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _ingredients.isEmpty || _loading ? null : _search,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: primaryColor.withAlpha(100),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                              )
                            : Text(
                                '레시피 찾기 (${_ingredients.length})',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                              ),
                      ),
                    ),
                  ),

                  // 결과 영역
                  if (_loading)
                    _SkeletonList()
                  else if (_error.isNotEmpty)
                    _StateBox(
                      emoji: '😔',
                      title: '오류가 발생했어요',
                      desc: _error,
                      action: TextButton(onPressed: _search, child: const Text('다시 시도')),
                    )
                  else if (!_searched)
                    _StateBox(
                      emoji: '🥕',
                      title: '재료를 입력해보세요',
                      desc: '냉장고에 있는 재료로 만들 수 있는\n레시피를 찾아드려요',
                    )
                  else if (_results.isEmpty)
                    const _StateBox(
                      emoji: '🧊',
                      title: '일치하는 레시피가 없어요',
                      desc: '재료를 줄이거나 다른 재료를 입력해보세요.',
                    )
                  else
                    _ResultList(
                      results: _results,
                      addingIds: _addingIds,
                      collectedMap: _collectedMap,
                      onCollect: _handleCollect,
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

// ── 상단 바 ─────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 8, 16, 8),
      decoration: const BoxDecoration(
        color: paperColor,
        border: Border(bottom: BorderSide(color: lightLineColor)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: warmBrownColor),
          ),
          const Text(
            '냉장고 파먹기',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: warmBrownColor),
          ),
        ],
      ),
    );
  }
}

// ── 안내 영역 ───────────────────────────────────────────────
class _IntroSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: Color(0xFFF5E6C8),
              shape: BoxShape.circle,
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/images/meokdang.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    const Center(child: Text('🧊', style: TextStyle(fontSize: 32))),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text('냉장고에 있는 재료를 입력하면',
              style: TextStyle(fontSize: 13, color: softBrownColor, height: 1.6)),
          const Text('만들 수 있는 레시피를 찾아드려요',
              style: TextStyle(fontSize: 13, color: softBrownColor, height: 1.6)),
        ],
      ),
    );
  }
}

// ── 재료 입력 섹션 ──────────────────────────────────────────
class _IngredientInputSection extends StatelessWidget {
  const _IngredientInputSection({
    required this.ingredients,
    required this.controller,
    required this.focusNode,
    required this.onSubmit,
    required this.onChanged,
    required this.onRemove,
  });

  final List<String> ingredients;
  final TextEditingController controller;
  final FocusNode focusNode;
  final void Function(String) onSubmit;
  final void Function(String) onChanged;
  final void Function(String) onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('재료 입력',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: softBrownColor,
                  letterSpacing: 0.5)),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => focusNode.requestFocus(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: creamColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: lightLineColor, width: 1.5),
              ),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ...ingredients.map((name) => _IngredientChip(
                        label: name,
                        onRemove: () => onRemove(name),
                      )),
                  if (ingredients.length < 15)
                    IntrinsicWidth(
                      child: TextField(
                        controller: controller,
                        focusNode: focusNode,
                        onSubmitted: onSubmit,
                        onChanged: onChanged,
                        decoration: InputDecoration(
                          hintText: ingredients.isEmpty ? '재료 입력 후 Enter...' : '재료 추가...',
                          hintStyle: TextStyle(
                              color: softBrownColor.withAlpha(140), fontSize: 13),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 4),
                        ),
                        style: const TextStyle(fontSize: 13, color: warmBrownColor),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            ingredients.length >= 15
                ? '최대 15개까지 입력할 수 있어요.'
                : 'Enter 또는 쉼표(,)로 추가',
            style: TextStyle(
              fontSize: 11,
              color: ingredients.length >= 15 ? Colors.red : softBrownColor.withAlpha(160),
              fontWeight: ingredients.length >= 15 ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

class _IngredientChip extends StatelessWidget {
  const _IngredientChip({required this.label, required this.onRemove});
  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: primaryColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 14,
              height: 14,
              decoration:
                  BoxDecoration(color: Colors.white.withAlpha(76), shape: BoxShape.circle),
              child: const Icon(Icons.close, size: 9, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 추천 재료 섹션 ──────────────────────────────────────────
class _RecommendSection extends StatelessWidget {
  const _RecommendSection({required this.ingredients, required this.onTap});
  final List<String> ingredients;
  final void Function(String) onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('추천 재료',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: softBrownColor,
                  letterSpacing: 0.5)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: _kRecommended.map((name) {
              final isAdded = ingredients.contains(name);
              final disabled = isAdded || ingredients.length >= 15;
              return GestureDetector(
                onTap: disabled ? null : () => onTap(name),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
                  decoration: BoxDecoration(
                    color: isAdded ? lightLineColor : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isAdded ? Colors.transparent : lightLineColor,
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    name,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isAdded
                          ? softBrownColor.withAlpha(120)
                          : softBrownColor,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ── 스켈레톤 ────────────────────────────────────────────────
class _SkeletonList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: List.generate(
          3,
          (_) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: lightLineColor),
            ),
            child: Row(
              children: [
                Container(
                  width: 100,
                  height: 56,
                  decoration: BoxDecoration(
                    color: lightLineColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                          height: 12,
                          width: double.infinity,
                          decoration: BoxDecoration(
                              color: lightLineColor, borderRadius: BorderRadius.circular(6))),
                      const SizedBox(height: 8),
                      Container(
                          height: 10,
                          width: 100,
                          decoration: BoxDecoration(
                              color: lightLineColor, borderRadius: BorderRadius.circular(5))),
                      const SizedBox(height: 8),
                      Container(
                          height: 6,
                          decoration: BoxDecoration(
                              color: lightLineColor, borderRadius: BorderRadius.circular(3))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── 상태 박스 (빈 상태/에러) ────────────────────────────────
class _StateBox extends StatelessWidget {
  const _StateBox({required this.emoji, required this.title, required this.desc, this.action});
  final String emoji;
  final String title;
  final String desc;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 44)),
          const SizedBox(height: 12),
          Text(title,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, color: warmBrownColor)),
          const SizedBox(height: 8),
          Text(desc,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: softBrownColor, height: 1.6)),
          if (action != null) ...[const SizedBox(height: 12), action!],
        ],
      ),
    );
  }
}

// ── 결과 리스트 ─────────────────────────────────────────────
class _ResultList extends StatelessWidget {
  const _ResultList({
    required this.results,
    required this.addingIds,
    required this.collectedMap,
    required this.onCollect,
  });

  final List<FridgeSearchItem> results;
  final Set<int> addingIds;
  final Map<int, int> collectedMap;
  final Future<void> Function(FridgeSearchItem) onCollect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 13, color: softBrownColor),
              children: [
                TextSpan(
                  text: '${results.length}개',
                  style: const TextStyle(color: primaryColor, fontWeight: FontWeight.w700),
                ),
                const TextSpan(text: '의 레시피를 찾았어요'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ...results.map((item) => _ResultCard(
                item: item,
                isAdding: addingIds.contains(item.id),
                isCollected: collectedMap.containsKey(item.id),
                onCollect: () => onCollect(item),
              )),
        ],
      ),
    );
  }
}

// ── 결과 카드 ────────────────────────────────────────────────
class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.item,
    required this.isAdding,
    required this.isCollected,
    required this.onCollect,
  });

  final FridgeSearchItem item;
  final bool isAdding;
  final bool isCollected;
  final VoidCallback onCollect;

  @override
  Widget build(BuildContext context) {
    final score = item.matchScore.clamp(0, 100).round();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: lightLineColor),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 썸네일
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 100,
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: item.thumbnailUrl != null
                          ? CachedNetworkImage(
                              imageUrl: item.thumbnailUrl!,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(color: creamColor),
                              errorWidget: (_, __, ___) => _thumbPlaceholder(),
                            )
                          : _thumbPlaceholder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // 카드 본문
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 카테고리 배지
                      if (item.category != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(140),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(item.category!,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                        ),

                      // 제목
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: warmBrownColor,
                            height: 1.35),
                      ),
                      const SizedBox(height: 4),

                      // 메타 칩
                      Wrap(
                        spacing: 4,
                        children: [
                          if (item.cookingTime != null)
                            _MetaChip(
                                icon: Icons.timer_outlined, label: item.cookingTime!),
                          if (item.difficulty != null)
                            _MetaChip(
                                label: _kDifficultyLabel[item.difficulty] ??
                                    item.difficulty!),
                        ],
                      ),
                      if (item.channelName != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          item.channelName!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11, color: softBrownColor.withAlpha(191)),
                        ),
                      ],

                      const SizedBox(height: 6),

                      // 매칭 점수 바
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: score / 100,
                                backgroundColor: lightLineColor,
                                color: primaryColor,
                                minHeight: 6,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('$score% 매칭',
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: primaryColor)),
                        ],
                      ),

                      // 일치 재료 칩
                      if (item.matchedIngredients.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            const Text('일치:',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: softBrownColor)),
                            ...item.matchedIngredients.map((ing) => Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: primaryColor.withAlpha(25),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: primaryColor.withAlpha(64)),
                                  ),
                                  child: Text(ing,
                                      style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                          color: primaryColor)),
                                )),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // 보관함 버튼 공간 확보
                const SizedBox(width: 32),
              ],
            ),
          ),

          // 보관함 버튼 (우상단)
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: isAdding ? null : onCollect,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: isCollected ? primaryColor : Colors.white.withAlpha(224),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withAlpha(38), blurRadius: 4, offset: const Offset(0, 1)),
                  ],
                ),
                child: isAdding
                    ? Padding(
                        padding: const EdgeInsets.all(7),
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: isCollected ? Colors.white : primaryColor),
                      )
                    : Icon(
                        isCollected ? Icons.check : Icons.bookmark_border,
                        size: 15,
                        color: isCollected ? Colors.white : softBrownColor,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _thumbPlaceholder() => Container(
        color: creamColor,
        child: Center(
          child: Icon(Icons.play_circle_outline,
              size: 28, color: softBrownColor.withAlpha(100)),
        ),
      );
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({this.icon, required this.label});
  final IconData? icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: paperColor, borderRadius: BorderRadius.circular(5)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: softBrownColor),
            const SizedBox(width: 2),
          ],
          Text(label, style: const TextStyle(fontSize: 10, color: softBrownColor)),
        ],
      ),
    );
  }
}
