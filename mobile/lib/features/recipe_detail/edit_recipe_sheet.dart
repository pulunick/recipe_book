import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_service.dart';
import '../../core/theme.dart';
import '../../shared/models/collection_item.dart';
import '../../shared/models/recipe.dart';

class EditRecipeSheet extends ConsumerStatefulWidget {
  const EditRecipeSheet({super.key, required this.item, required this.onSaved});
  final CollectionItem item;
  final VoidCallback onSaved;

  @override
  ConsumerState<EditRecipeSheet> createState() => _EditRecipeSheetState();
}

class _EditRecipeSheetState extends ConsumerState<EditRecipeSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final TextEditingController _tipController;
  late final TextEditingController _titleController;
  late final TextEditingController _summaryController;

  // 재료 편집용
  late List<_IngredientRow> _ingredients;
  // 단계 편집용
  late List<_StepRow> _steps;

  bool _isSaving = false;

  Recipe get _recipe => widget.item.recipe;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // 현재 값으로 초기화 (override 우선)
    final override = widget.item.recipeOverride;
    _tipController = TextEditingController(
      text: widget.item.customTip ?? '',
    );
    _titleController = TextEditingController(
      text: (override?['title'] as String?) ?? _recipe.title,
    );
    _summaryController = TextEditingController(
      text: (override?['summary'] as String?) ?? _recipe.summary ?? '',
    );

    final overrideIngredients = override?['ingredients'] as List?;
    _ingredients = overrideIngredients != null
        ? overrideIngredients
            .map((e) => _IngredientRow.fromJson(e as Map<String, dynamic>))
            .toList()
        : _recipe.ingredients
            .map((ing) => _IngredientRow(
                  name: ing.name,
                  amount: [ing.amount, ing.unit].whereType<String>().join(' '),
                  category: ing.category,
                ))
            .toList();

    final overrideSteps = override?['steps'] as List?;
    _steps = overrideSteps != null
        ? overrideSteps
            .map((e) => _StepRow.fromJson(e as Map<String, dynamic>))
            .toList()
        : _recipe.steps
            .map((s) => _StepRow(description: s.description, timer: s.timer))
            .toList();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _tipController.dispose();
    _titleController.dispose();
    _summaryController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final override = <String, dynamic>{
        'title': _titleController.text.trim(),
        'summary': _summaryController.text.trim(),
        'ingredients': _ingredients
            .where((r) => r.name.trim().isNotEmpty)
            .map((r) => r.toJson())
            .toList(),
        'steps': _steps
            .asMap()
            .entries
            .where((e) => e.value.description.trim().isNotEmpty)
            .map((e) => {
                  'step_number': e.key + 1,
                  'description': e.value.description.trim(),
                  if (e.value.timer != null && e.value.timer!.isNotEmpty)
                    'timer': e.value.timer,
                })
            .toList(),
      };

      await ref.read(apiServiceProvider).patchCollection(
            widget.item.id,
            customTip: _tipController.text.trim(),
            recipeOverride: override,
          );

      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onSaved();
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('저장 중 오류가 발생했어요.')),
      );
    }
  }

  Future<void> _restoreOriginal() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('원본으로 복원'),
        content: const Text('모든 수정 내용이 삭제되고 원본 레시피로 돌아갑니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('복원', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isSaving = true);
    try {
      await ref.read(apiServiceProvider).patchCollection(
            widget.item.id,
            customTip: '',
            clearOverride: true,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onSaved();
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: paperColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // 핸들 + 헤더
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: lightLineColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('레시피 편집',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: darkColor)),
                    const Spacer(),
                    TextButton(
                      onPressed: _isSaving ? null : _restoreOriginal,
                      child: const Text('원본 복원', style: TextStyle(color: softBrownColor, fontSize: 13)),
                    ),
                    const SizedBox(width: 4),
                    ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      child: _isSaving
                          ? const SizedBox(width: 16, height: 16,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('저장', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 탭 바
          Container(
            margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            decoration: BoxDecoration(
              color: creamColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(10)),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              unselectedLabelColor: softBrownColor,
              labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              dividerColor: Colors.transparent,
              tabs: const [Tab(text: '기본 정보'), Tab(text: '재료'), Tab(text: '조리 순서')],
            ),
          ),

          // 탭 내용
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _BasicTab(
                  tipController: _tipController,
                  titleController: _titleController,
                  summaryController: _summaryController,
                ),
                _IngredientsTab(
                  rows: _ingredients,
                  onChanged: () => setState(() {}),
                ),
                _StepsTab(
                  rows: _steps,
                  onChanged: () => setState(() {}),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 기본 정보 탭 ───────────────────────────────────────────────
class _BasicTab extends StatelessWidget {
  const _BasicTab({
    required this.tipController,
    required this.titleController,
    required this.summaryController,
  });
  final TextEditingController tipController;
  final TextEditingController titleController;
  final TextEditingController summaryController;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FieldLabel('제목'),
          const SizedBox(height: 6),
          _EditField(controller: titleController, hintText: '레시피 제목'),
          const SizedBox(height: 16),
          _FieldLabel('요약'),
          const SizedBox(height: 6),
          _EditField(controller: summaryController, hintText: '레시피 요약', maxLines: 4),
          const SizedBox(height: 16),
          _FieldLabel('나만의 팁'),
          const SizedBox(height: 6),
          _EditField(controller: tipController, hintText: '개인 메모나 꿀팁을 입력하세요.', maxLines: 4),
        ],
      ),
    );
  }
}

// ── 재료 탭 ────────────────────────────────────────────────────
class _IngredientsTab extends StatelessWidget {
  const _IngredientsTab({required this.rows, required this.onChanged});
  final List<_IngredientRow> rows;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            itemCount: rows.length,
            separatorBuilder: (context, i) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final row = rows[i];
              return Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: _EditField(
                      initialValue: row.name,
                      hintText: '재료명',
                      onChanged: (v) { row.name = v; onChanged(); },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: _EditField(
                      initialValue: row.amount,
                      hintText: '양 (예: 200g)',
                      onChanged: (v) { row.amount = v; onChanged(); },
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () { rows.removeAt(i); onChanged(); },
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.remove_circle_outline, color: softBrownColor, size: 20),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextButton.icon(
            onPressed: () { rows.add(_IngredientRow()); onChanged(); },
            icon: const Icon(Icons.add, color: primaryColor, size: 18),
            label: const Text('재료 추가', style: TextStyle(color: primaryColor)),
          ),
        ),
      ],
    );
  }
}

// ── 조리 순서 탭 ───────────────────────────────────────────────
class _StepsTab extends StatelessWidget {
  const _StepsTab({required this.rows, required this.onChanged});
  final List<_StepRow> rows;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            itemCount: rows.length,
            separatorBuilder: (context, i) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final row = rows[i];
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 26, height: 26,
                    margin: const EdgeInsets.only(top: 10, right: 10),
                    decoration: const BoxDecoration(color: primaryColor, shape: BoxShape.circle),
                    child: Center(
                      child: Text('${i + 1}',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  Expanded(
                    child: _EditField(
                      initialValue: row.description,
                      hintText: '조리 방법을 입력하세요.',
                      maxLines: 3,
                      onChanged: (v) { row.description = v; onChanged(); },
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () { rows.removeAt(i); onChanged(); },
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.remove_circle_outline, color: softBrownColor, size: 20),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextButton.icon(
            onPressed: () { rows.add(_StepRow()); onChanged(); },
            icon: const Icon(Icons.add, color: primaryColor, size: 18),
            label: const Text('단계 추가', style: TextStyle(color: primaryColor)),
          ),
        ),
      ],
    );
  }
}

// ── 공통 위젯 ──────────────────────────────────────────────────
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: softBrownColor),
  );
}

class _EditField extends StatelessWidget {
  const _EditField({
    this.controller,
    this.initialValue,
    required this.hintText,
    this.maxLines = 1,
    this.onChanged,
  });
  final TextEditingController? controller;
  final String? initialValue;
  final String hintText;
  final int maxLines;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      initialValue: controller == null ? initialValue : null,
      maxLines: maxLines,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 14, color: darkColor),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: softBrownColor.withAlpha(150), fontSize: 13),
        filled: true,
        fillColor: creamColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
    );
  }
}

// ── 데이터 클래스 ──────────────────────────────────────────────
class _IngredientRow {
  _IngredientRow({this.name = '', this.amount = '', this.category = '기타'});
  String name;
  String amount;
  String category;

  factory _IngredientRow.fromJson(Map<String, dynamic> json) => _IngredientRow(
        name: json['name'] as String? ?? '',
        amount: [json['amount'], json['unit']].whereType<String>().join(' '),
        category: json['category'] as String? ?? '기타',
      );

  Map<String, dynamic> toJson() => {
        'name': name.trim(),
        'amount': amount.trim().isEmpty ? null : amount.trim(),
        'unit': null,
        'category': category,
      };
}

class _StepRow {
  _StepRow({this.description = '', this.timer});
  String description;
  String? timer;

  factory _StepRow.fromJson(Map<String, dynamic> json) => _StepRow(
        description: json['description'] as String? ?? '',
        timer: json['timer'] as String?,
      );
}
