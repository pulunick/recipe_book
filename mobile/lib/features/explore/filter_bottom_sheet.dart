import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'explore_provider.dart';

class FilterBottomSheet extends StatefulWidget {
  const FilterBottomSheet({
    super.key,
    required this.initial,
    required this.onApply,
  });

  final ExploreFilter initial;
  final ValueChanged<ExploreFilter> onApply;

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  late ExploreFilter _filter;
  final Set<String> _selectedTags = {};

  @override
  void initState() {
    super.initState();
    _filter = widget.initial;
  }

  void _reset() {
    setState(() {
      _filter = const ExploreFilter();
      _selectedTags.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: paperColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
            child: Row(
              children: [
                const Text(
                  '필터',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: darkColor),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _reset,
                  child: const Text('초기화', style: TextStyle(color: softBrownColor)),
                ),
              ],
            ),
          ),

          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 정렬
                  _SectionLabel('정렬'),
                  const SizedBox(height: 8),
                  _ChipGroup(
                    options: const [
                      ('latest', '최신순'),
                      ('popular', '인기순'),
                      ('rating', '평점순'),
                    ],
                    selected: _filter.sort,
                    onSelect: (v) => setState(() => _filter = _filter.copyWith(sort: v)),
                  ),

                  const Divider(height: 24),

                  // 난이도
                  _SectionLabel('난이도'),
                  const SizedBox(height: 8),
                  _ChipGroup(
                    options: const [
                      ('easy', '쉬움'),
                      ('medium', '보통'),
                      ('hard', '어려움'),
                    ],
                    selected: _filter.difficulty,
                    nullable: true,
                    onSelect: (v) {
                      final next = v == _filter.difficulty ? null : v;
                      setState(() => _filter = _filter.copyWith(difficulty: () => next));
                    },
                  ),

                  const Divider(height: 24),

                  // 조리 시간
                  _SectionLabel('조리 시간'),
                  const SizedBox(height: 8),
                  _ChipGroup(
                    options: const [
                      ('20', '20분 이하'),
                      ('60', '1시간 이하'),
                      ('61+', '1시간 초과'),
                    ],
                    selected: _filter.cookingTime,
                    nullable: true,
                    onSelect: (v) {
                      final next = v == _filter.cookingTime ? null : v;
                      setState(() => _filter = _filter.copyWith(cookingTime: () => next));
                    },
                  ),

                  const Divider(height: 24),

                  // 칼로리
                  _SectionLabel('칼로리'),
                  const SizedBox(height: 8),
                  _ChipGroup(
                    options: const [
                      ('low', '500kcal 이하'),
                      ('mid', '500~800kcal'),
                      ('high', '800kcal 이상'),
                    ],
                    selected: _filter.calorieRange,
                    nullable: true,
                    onSelect: (v) {
                      final next = v == _filter.calorieRange ? null : v;
                      setState(() => _filter = _filter.copyWith(calorieRange: () => next));
                    },
                  ),

                  const Divider(height: 24),

                  // 상황 태그
                  _SectionLabel('상황 태그'),
                  const SizedBox(height: 8),
                  _TagChipGroup(
                    tags: const ['간편식', '다이어트', '야식', '손님접대', '특별한날', '해장', '도시락', '아이반찬', '혼밥', '술안주', '브런치', '명절'],
                    selectedTags: _selectedTags,
                    onToggle: (tag) {
                      setState(() {
                        if (_selectedTags.contains(tag)) {
                          _selectedTags.remove(tag);
                        } else {
                          _selectedTags.add(tag);
                        }
                      });
                    },
                  ),

                  const Divider(height: 24),

                  // 저장 숨김
                  Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('저장한 레시피 숨기기',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: darkColor)),
                            Text('이미 보관한 레시피를 목록에서 숨겨요',
                                style: TextStyle(fontSize: 12, color: softBrownColor)),
                          ],
                        ),
                      ),
                      Switch(
                        value: _filter.hideCollected,
                        onChanged: (v) =>
                            setState(() => _filter = _filter.copyWith(hideCollected: v)),
                        activeColor: primaryColor,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 적용 버튼
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  widget.onApply(_filter);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: Text(
                  _filter.activeCount > 0 ? '적용 (${_filter.activeCount})' : '적용',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: darkColor),
    );
  }
}

class _ChipGroup extends StatelessWidget {
  const _ChipGroup({
    required this.options,
    required this.selected,
    required this.onSelect,
    this.nullable = false,
  });

  final List<(String, String)> options;
  final String? selected;
  final ValueChanged<String> onSelect;
  final bool nullable;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        final (value, label) = opt;
        final isSelected = selected == value;
        return GestureDetector(
          onTap: () => onSelect(value),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: isSelected ? primaryColor : creamColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? primaryColor : lightLineColor,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? Colors.white : darkColor,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── 상황 태그 칩 그룹 ────────────────────────────────────────
class _TagChipGroup extends StatelessWidget {
  const _TagChipGroup({
    required this.tags,
    required this.selectedTags,
    required this.onToggle,
  });

  final List<String> tags;
  final Set<String> selectedTags;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: tags.map((tag) {
        final isSelected = selectedTags.contains(tag);
        return GestureDetector(
          onTap: () => onToggle(tag),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: isSelected ? primaryColor : creamColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? primaryColor : lightLineColor,
              ),
            ),
            child: Text(
              tag,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? Colors.white : darkColor,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
