import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_service.dart';
import '../../core/theme.dart';
import '../../shared/models/recipe.dart';

const _kDifficulties = ['쉬움', '보통', '어려움'];

class AddRecipeSheet extends ConsumerStatefulWidget {
  const AddRecipeSheet({super.key, this.onSaved});
  final void Function(int collectionId)? onSaved;

  @override
  ConsumerState<AddRecipeSheet> createState() => _AddRecipeSheetState();
}

class _AddRecipeSheetState extends ConsumerState<AddRecipeSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _urlController = TextEditingController();
  bool _isLoadingYoutube = false;
  String? _errorMsgYoutube;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _analyzeYoutube() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() => _errorMsgYoutube = 'YouTube URL을 입력해주세요.');
      return;
    }
    setState(() {
      _isLoadingYoutube = true;
      _errorMsgYoutube = null;
    });
    try {
      final result = await ref.read(apiServiceProvider).extractFromYoutube(url);
      if (!mounted) return;

      final isRecipe = result['is_recipe'] as bool? ?? true;
      if (!isRecipe) {
        setState(() {
          _isLoadingYoutube = false;
          _errorMsgYoutube = result['non_recipe_reason'] as String? ?? '요리 레시피 영상이 아니에요.';
        });
        return;
      }

      final collectionId = result['collection_id'] as int?;
      final recipeTitle = result['title'] as String?;
      Navigator.of(context).pop();
      if (collectionId != null) widget.onSaved?.call(collectionId);
      _showPopup(success: true, title: recipeTitle, collectionId: collectionId);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingYoutube = false;
        _errorMsgYoutube = _parseError(e);
      });
    }
  }

  String _parseError(Object e) {
    final msg = e.toString();
    if (msg.contains('NOT_RECIPE')) return '요리 레시피 영상이 아니에요.';
    if (msg.contains('INVALID_URL')) return '유효한 YouTube URL이 아니에요.';
    if (msg.contains('ACCESS_DENIED')) return '영상에 접근할 수 없어요.';
    if (msg.contains('SocketException') || msg.contains('connection')) return '네트워크 연결을 확인해주세요.';
    if (msg.contains('TimeoutException')) return '분석 시간이 초과됐어요. 다시 시도해주세요.';
    return '오류가 발생했어요. 다시 시도해주세요.';
  }

  void _showPopup({required bool success, String? title, int? collectionId}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final overlay = Navigator.of(context, rootNavigator: true).overlay;
      if (overlay == null) return;

      late OverlayEntry entry;
      entry = OverlayEntry(
        builder: (ctx) => _AnalysisPopup(
          success: success,
          recipeTitle: title,
          onDismiss: () => entry.remove(),
          onGoTo: success && collectionId != null
              ? () {
                  entry.remove();
                  ctx.push('/my-recipes/$collectionId');
                }
              : null,
        ),
      );
      overlay.insert(entry);

      // 5초 후 자동 닫기
      Future.delayed(const Duration(seconds: 5), () {
        if (entry.mounted) entry.remove();
      });
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
            decoration: BoxDecoration(color: lightLineColor, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          const Text(
            '레시피 추가',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: warmBrownColor),
          ),
          const SizedBox(height: 16),

          // 탭 바
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(color: creamColor, borderRadius: BorderRadius.circular(12)),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(10)),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              unselectedLabelColor: softBrownColor,
              labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: '🎬 YouTube 분석'),
                Tab(text: '✏️ 직접 작성'),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 탭 내용
          SizedBox(
            height: 340,
            child: TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _YoutubeTab(
                  controller: _urlController,
                  isLoading: _isLoadingYoutube,
                  errorMsg: _errorMsgYoutube,
                  onAnalyze: _analyzeYoutube,
                ),
                _TextWriteTab(
                  onSaved: (collectionId, title) {
                    Navigator.of(context).pop();
                    widget.onSaved?.call(collectionId);
                    _showPopup(success: true, title: title, collectionId: collectionId);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ── YouTube 탭 ──────────────────────────────────────────────
class _YoutubeTab extends StatelessWidget {
  const _YoutubeTab({
    required this.controller,
    required this.isLoading,
    required this.errorMsg,
    required this.onAnalyze,
  });
  final TextEditingController controller;
  final bool isLoading;
  final String? errorMsg;
  final VoidCallback onAnalyze;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            enabled: !isLoading,
            decoration: InputDecoration(
              hintText: 'https://youtube.com/watch?v=...',
              hintStyle: TextStyle(color: softBrownColor.withAlpha(150), fontSize: 13),
              prefixIcon: const Icon(Icons.link, color: softBrownColor, size: 20),
              filled: true,
              fillColor: creamColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            keyboardType: TextInputType.url,
          ),
          if (errorMsg != null) ...[
            const SizedBox(height: 8),
            Text(errorMsg!, style: const TextStyle(color: Colors.red, fontSize: 12)),
          ],
          const SizedBox(height: 12),
          const Text(
            '유튜브 요리 영상 URL을 붙여넣으면\nAI가 재료와 레시피를 자동으로 추출해요.',
            style: TextStyle(fontSize: 12, color: softBrownColor, height: 1.5),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: isLoading ? null : onAnalyze,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    )
                  : const Text('분석 시작', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 직접 작성 탭 (input → preview → save) ──────────────────
class _TextWriteTab extends ConsumerStatefulWidget {
  const _TextWriteTab({required this.onSaved});
  final void Function(int collectionId, String? title) onSaved;

  @override
  ConsumerState<_TextWriteTab> createState() => _TextWriteTabState();
}

class _TextWriteTabState extends ConsumerState<_TextWriteTab> {
  final _titleCtrl = TextEditingController();
  final _textCtrl = TextEditingController();
  bool _isAnalyzing = false;
  bool _isSaving = false;
  String? _error;

  // 미리보기 단계
  bool _showPreview = false;
  Recipe? _recipe;

  // 편집용 mutable state
  late TextEditingController _editTitleCtrl;
  late TextEditingController _editSummaryCtrl;
  late TextEditingController _editServingsCtrl;
  late TextEditingController _editCookingTimeCtrl;
  late TextEditingController _editTipCtrl;
  String? _editDifficulty;
  List<Map<String, String?>> _editIngredients = [];
  List<String> _editSteps = [];
  bool _isPublic = false;

  @override
  void initState() {
    super.initState();
    _editTitleCtrl = TextEditingController();
    _editSummaryCtrl = TextEditingController();
    _editServingsCtrl = TextEditingController();
    _editCookingTimeCtrl = TextEditingController();
    _editTipCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _textCtrl.dispose();
    _editTitleCtrl.dispose();
    _editSummaryCtrl.dispose();
    _editServingsCtrl.dispose();
    _editCookingTimeCtrl.dispose();
    _editTipCtrl.dispose();
    super.dispose();
  }

  Future<void> _analyze() async {
    final text = _textCtrl.text.trim();
    if (text.length < 50) {
      setState(() => _error = '레시피 내용을 50자 이상 입력해주세요. (현재 ${text.length}자)');
      return;
    }
    setState(() { _isAnalyzing = true; _error = null; });
    try {
      final recipeMap = await ref.read(apiServiceProvider)
          .extractFromText(text, title: _titleCtrl.text.trim());
      final recipe = Recipe.fromJson(recipeMap);
      _initEditState(recipe);
      setState(() {
        _recipe = recipe;
        _showPreview = true;
        _isAnalyzing = false;
      });
    } catch (e) {
      setState(() {
        _error = '분석 중 오류가 발생했어요.';
        _isAnalyzing = false;
      });
    }
  }

  void _initEditState(Recipe r) {
    _editTitleCtrl.text = r.title;
    _editSummaryCtrl.text = r.summary ?? '';
    _editServingsCtrl.text = r.servings ?? '';
    _editCookingTimeCtrl.text = r.cookingTime ?? '';
    _editTipCtrl.text = r.tip ?? '';
    _editDifficulty = r.difficulty;
    _editIngredients = r.ingredients
        .map((i) => {'name': i.name, 'amount': i.amount, 'unit': i.unit, 'category': i.category})
        .toList();
    _editSteps = r.steps.map((s) => s.description).toList();
    _isPublic = false;
  }

  Future<void> _save() async {
    if (_recipe == null) return;
    setState(() { _isSaving = true; _error = null; });
    try {
      // 편집된 내용으로 Recipe 재구성
      final edited = Recipe(
        title: _editTitleCtrl.text.trim().isNotEmpty ? _editTitleCtrl.text.trim() : _recipe!.title,
        summary: _editSummaryCtrl.text.trim(),
        servings: _editServingsCtrl.text.trim(),
        cookingTime: _editCookingTimeCtrl.text.trim(),
        difficulty: _editDifficulty,
        tip: _editTipCtrl.text.trim(),
        ingredients: _editIngredients
            .where((i) => (i['name'] ?? '').isNotEmpty)
            .map((i) => Ingredient(
                  name: i['name']!,
                  amount: i['amount'],
                  unit: i['unit'],
                  category: i['category'] ?? '기타',
                ))
            .toList(),
        steps: _editSteps
            .asMap()
            .entries
            .where((e) => e.value.trim().isNotEmpty)
            .map((e) => RecipeStep(stepNumber: e.key + 1, description: e.value.trim()))
            .toList(),
        flavor: _recipe!.flavor,
        source: 'text',
      );
      final collectionId = await ref.read(apiServiceProvider).saveTextRecipe(edited, isPublic: _isPublic);
      if (!mounted) return;
      widget.onSaved(collectionId, edited.title);
    } catch (e) {
      setState(() {
        _error = '저장 중 오류가 발생했어요.';
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_showPreview) return _buildInputStep();
    return _buildPreviewStep();
  }

  // ── 입력 단계 ────────────────────────────────────────────
  Widget _buildInputStep() {
    final textLen = _textCtrl.text.length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _titleCtrl,
            enabled: !_isAnalyzing,
            decoration: InputDecoration(
              hintText: '제목 (선택 — 없으면 AI가 자동 생성)',
              hintStyle: TextStyle(color: softBrownColor.withAlpha(150), fontSize: 13),
              filled: true,
              fillColor: creamColor,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: TextField(
              controller: _textCtrl,
              enabled: !_isAnalyzing,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: '재료와 조리 순서를 입력하세요.\n구어체·메모 무엇이든 괜찮아요. (50자 이상)',
                hintStyle: TextStyle(color: softBrownColor.withAlpha(150), fontSize: 13),
                filled: true,
                fillColor: creamColor,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.all(16),
                errorText: _error,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$textLen / 5000자',
                  style: TextStyle(
                      fontSize: 11,
                      color: textLen < 50 ? softBrownColor.withAlpha(160) : primaryColor)),
              if (_isAnalyzing)
                const Text('보통 10~20초 걸려요',
                    style: TextStyle(fontSize: 11, color: softBrownColor)),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: (textLen < 50 || _isAnalyzing) ? null : _analyze,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: _isAnalyzing
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    )
                  : const Text('AI로 레시피 변환하기',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  // ── 미리보기/편집 단계 ───────────────────────────────────
  Widget _buildPreviewStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 안내 배너
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: creamColor, borderRadius: BorderRadius.circular(10)),
            child: const Row(
              children: [
                Text('✏️', style: TextStyle(fontSize: 14)),
                SizedBox(width: 8),
                Expanded(
                  child: Text('AI가 변환한 결과예요. 저장 전에 바로 수정할 수 있어요.',
                      style: TextStyle(fontSize: 12, color: softBrownColor)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 제목
          TextField(
            controller: _editTitleCtrl,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: warmBrownColor),
            decoration: InputDecoration(
              hintText: '레시피 제목',
              border: const UnderlineInputBorder(
                  borderSide: BorderSide(color: lightLineColor, width: 1.5)),
              focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: primaryColor, width: 1.5)),
              enabledBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: lightLineColor, width: 1.5)),
              contentPadding: const EdgeInsets.only(bottom: 6),
              hintStyle:
                  TextStyle(color: softBrownColor.withAlpha(140), fontWeight: FontWeight.normal),
            ),
          ),
          const SizedBox(height: 14),

          // 기본 정보 (인분/시간/난이도)
          Row(
            children: [
              Expanded(
                child: _MetaField(
                    label: '인분', controller: _editServingsCtrl, hint: '예: 2인분'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetaField(
                    label: '시간', controller: _editCookingTimeCtrl, hint: '예: 30분'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('난이도',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: softBrownColor,
                            letterSpacing: 0.5)),
                    const SizedBox(height: 4),
                    Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: paperColor,
                        border: Border.all(color: lightLineColor, width: 1.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          value: _editDifficulty,
                          isExpanded: true,
                          style: const TextStyle(fontSize: 12, color: warmBrownColor),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('-')),
                            ..._kDifficulties.map((d) =>
                                DropdownMenuItem(value: d, child: Text(d))),
                          ],
                          onChanged: (v) => setState(() => _editDifficulty = v),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 요약
          _EditSection(
            label: '한 줄 소개',
            child: TextField(
              controller: _editSummaryCtrl,
              maxLines: 3,
              style: const TextStyle(fontSize: 13, color: warmBrownColor),
              decoration: _inputDeco(hint: '레시피 한 줄 소개'),
            ),
          ),
          const SizedBox(height: 14),

          // 재료
          _EditSection(
            label: '재료',
            action: TextButton(
              onPressed: () => setState(() => _editIngredients.add(
                  {'name': null, 'amount': null, 'unit': null, 'category': '기타'})),
              child: const Text('+ 추가',
                  style: TextStyle(fontSize: 12, color: primaryColor)),
            ),
            child: Column(
              children: _editIngredients.asMap().entries.map((entry) {
                final i = entry.key;
                final ing = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: _ingInput(
                            value: ing['name'] ?? '',
                            hint: '재료명',
                            onChanged: (v) => setState(() => _editIngredients[i]['name'] = v)),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        flex: 2,
                        child: _ingInput(
                            value: ing['amount'] ?? '',
                            hint: '수량',
                            onChanged: (v) => setState(() => _editIngredients[i]['amount'] = v)),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        flex: 2,
                        child: _ingInput(
                            value: ing['unit'] ?? '',
                            hint: '단위',
                            onChanged: (v) => setState(() => _editIngredients[i]['unit'] = v)),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () => setState(() => _editIngredients.removeAt(i)),
                        child: const Icon(Icons.close, size: 18, color: lightLineColor),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),

          // 조리 순서
          _EditSection(
            label: '만드는 법',
            action: TextButton(
              onPressed: () => setState(() => _editSteps.add('')),
              child: const Text('+ 추가',
                  style: TextStyle(fontSize: 12, color: primaryColor)),
            ),
            child: Column(
              children: _editSteps.asMap().entries.map((entry) {
                final i = entry.key;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        margin: const EdgeInsets.only(top: 8, right: 8),
                        decoration: const BoxDecoration(
                            color: primaryColor, shape: BoxShape.circle),
                        child: Center(
                          child: Text('${i + 1}',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: TextEditingController(text: entry.value)
                            ..selection = TextSelection.collapsed(offset: entry.value.length),
                          maxLines: null,
                          onChanged: (v) => _editSteps[i] = v,
                          style: const TextStyle(fontSize: 13, color: warmBrownColor),
                          decoration: _inputDeco(hint: '조리 단계 설명'),
                        ),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () => setState(() => _editSteps.removeAt(i)),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: const Icon(Icons.close, size: 18, color: lightLineColor),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),

          // 꿀팁
          _EditSection(
            label: '꿀팁 (선택)',
            child: TextField(
              controller: _editTipCtrl,
              maxLines: 3,
              style: const TextStyle(fontSize: 13, color: warmBrownColor),
              decoration: _inputDeco(hint: '보관법, 변형 레시피, 주의사항 등'),
            ),
          ),
          const SizedBox(height: 14),

          // 공개 여부 토글
          GestureDetector(
            onTap: () => setState(() => _isPublic = !_isPublic),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(color: Colors.black.withAlpha(15), blurRadius: 4, offset: const Offset(0, 1))
                ],
              ),
              child: Row(
                children: [
                  // 토글 스위치
                  Container(
                    width: 44,
                    height: 26,
                    decoration: BoxDecoration(
                      color: _isPublic ? primaryColor : lightLineColor,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: AnimatedAlign(
                      duration: const Duration(milliseconds: 200),
                      alignment: _isPublic ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        width: 20,
                        height: 20,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isPublic ? '탐색 탭에 공개' : '나만 보기 (비공개)',
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700, color: warmBrownColor),
                        ),
                        Text(
                          _isPublic ? '다른 사용자들도 이 레시피를 볼 수 있어요' : '나만 볼 수 있어요',
                          style: const TextStyle(fontSize: 11, color: softBrownColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                  color: const Color(0xFFFDF0F0), borderRadius: BorderRadius.circular(8)),
              child: Text(_error!, style: const TextStyle(fontSize: 12, color: Color(0xFFC0392B))),
            ),
          ],

          const SizedBox(height: 16),

          // 액션 버튼
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isSaving
                      ? null
                      : () => setState(() {
                            _showPreview = false;
                            _error = null;
                          }),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: lightLineColor, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    foregroundColor: softBrownColor,
                  ),
                  child: const Text('다시 작성', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : const Text('내 레시피에 저장 →',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  InputDecoration _inputDeco({required String hint}) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: softBrownColor.withAlpha(140), fontSize: 13),
        filled: true,
        fillColor: paperColor,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: lightLineColor, width: 1.5)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: lightLineColor, width: 1.5)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: primaryColor, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
      );

  Widget _ingInput(
          {required String value, required String hint, required void Function(String) onChanged}) =>
      TextFormField(
        initialValue: value,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 12, color: warmBrownColor),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: softBrownColor.withAlpha(140), fontSize: 12),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: lightLineColor, width: 1.5)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: lightLineColor, width: 1.5)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: primaryColor, width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          isDense: true,
        ),
      );
}

// ── 편집 섹션 공통 ───────────────────────────────────────────
class _EditSection extends StatelessWidget {
  const _EditSection({required this.label, required this.child, this.action});
  final String label;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label.toUpperCase(),
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: softBrownColor,
                    letterSpacing: 0.5)),
            if (action != null) action!,
          ],
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

// ── 메타 필드 ────────────────────────────────────────────────
class _MetaField extends StatelessWidget {
  const _MetaField(
      {required this.label, required this.controller, required this.hint});
  final String label;
  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: softBrownColor,
                letterSpacing: 0.5)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          style: const TextStyle(fontSize: 12, color: warmBrownColor),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: softBrownColor.withAlpha(140), fontSize: 12),
            filled: true,
            fillColor: paperColor,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: lightLineColor, width: 1.5)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: lightLineColor, width: 1.5)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: primaryColor, width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            isDense: true,
          ),
        ),
      ],
    );
  }
}

// ── 분석 완료 팝업 (Overlay) ─────────────────────────────────
class _AnalysisPopup extends StatefulWidget {
  const _AnalysisPopup({
    required this.success,
    this.recipeTitle,
    required this.onDismiss,
    this.onGoTo,
  });
  final bool success;
  final String? recipeTitle;
  final VoidCallback onDismiss;
  final VoidCallback? onGoTo;

  @override
  State<_AnalysisPopup> createState() => _AnalysisPopupState();
}

class _AnalysisPopupState extends State<_AnalysisPopup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 250));
    _slide = Tween(begin: 12.0, end: 0.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Positioned(
      bottom: 72 + bottomInset,
      left: 16,
      right: 16,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, child) => Opacity(
          opacity: _fade.value,
          child: Transform.translate(
            offset: Offset(0, _slide.value),
            child: child,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withAlpha(36),
                    blurRadius: 32,
                    offset: const Offset(0, 8)),
              ],
            ),
            child: Row(
              children: [
                Text(widget.success ? '✅' : '❌',
                    style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.success ? '레시피 분석 완료!' : '분석 실패',
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: warmBrownColor),
                      ),
                      if (widget.recipeTitle != null)
                        Text(
                          widget.recipeTitle!,
                          style: const TextStyle(
                              fontSize: 12, color: softBrownColor),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (widget.success && widget.onGoTo != null) ...[
                  _popupBtn(
                      label: '닫기',
                      onTap: widget.onDismiss,
                      isPrimary: false),
                  const SizedBox(width: 6),
                  _popupBtn(
                      label: '보러 가기 →',
                      onTap: widget.onGoTo!,
                      isPrimary: true),
                ] else
                  _popupBtn(
                      label: '닫기',
                      onTap: widget.onDismiss,
                      isPrimary: false),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _popupBtn(
          {required String label,
          required VoidCallback onTap,
          required bool isPrimary}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: isPrimary ? primaryColor : Colors.transparent,
            border: isPrimary
                ? null
                : Border.all(color: lightLineColor, width: 1.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isPrimary ? Colors.white : softBrownColor,
            ),
          ),
        ),
      );
}
