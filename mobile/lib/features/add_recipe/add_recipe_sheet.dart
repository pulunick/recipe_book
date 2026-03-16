import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_service.dart';
import '../../core/theme.dart';

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
  final _titleController = TextEditingController();
  final _textController = TextEditingController();
  bool _isLoading = false;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _urlController.dispose();
    _titleController.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _analyzeYoutube() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() => _errorMsg = 'YouTube URL을 입력해주세요.');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });
    try {
      final result = await ref.read(apiServiceProvider).extractFromYoutube(url);
      if (!mounted) return;

      final isRecipe = result['is_recipe'] as bool? ?? true;
      if (!isRecipe) {
        setState(() {
          _isLoading = false;
          _errorMsg = result['non_recipe_reason'] as String? ?? '요리 레시피 영상이 아니에요.';
        });
        return;
      }

      final collectionId = result['collection_id'] as int?;
      Navigator.of(context).pop();
      if (collectionId != null) widget.onSaved?.call(collectionId);
      _showSuccess('레시피가 저장됐어요!');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMsg = _parseError(e);
      });
    }
  }

  Future<void> _analyzeText() async {
    final text = _textController.text.trim();
    if (text.length < 50) {
      setState(() => _errorMsg = '레시피 내용을 50자 이상 입력해주세요. (현재 ${text.length}자)');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });
    try {
      final recipe = await ref
          .read(apiServiceProvider)
          .extractFromText(text, title: _titleController.text.trim());
      final collectionId = await ref.read(apiServiceProvider).saveTextRecipe(recipe);
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onSaved?.call(collectionId);
      _showSuccess('레시피가 저장됐어요!');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMsg = _parseError(e);
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

  void _showSuccess(String message) {
    // 시트가 닫힌 후 루트 context에서 스낵바 표시
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final messenger = ScaffoldMessenger.maybeOf(
        Navigator.of(context, rootNavigator: true).context,
      );
      messenger?.showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: primaryColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: paperColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
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
          const SizedBox(height: 16),
          const Text(
            '레시피 추가',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: darkColor),
          ),
          const SizedBox(height: 16),

          // 탭 바
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: creamColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.circular(10),
              ),
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
            height: 260,
            child: TabBarView(
              controller: _tabController,
              children: [
                _YoutubeTab(
                  controller: _urlController,
                  isLoading: _isLoading,
                  errorMsg: _tabController.index == 0 ? _errorMsg : null,
                  onAnalyze: _analyzeYoutube,
                ),
                _TextTab(
                  titleController: _titleController,
                  textController: _textController,
                  isLoading: _isLoading,
                  errorMsg: _tabController.index == 1 ? _errorMsg : null,
                  onAnalyze: _analyzeText,
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

class _TextTab extends StatelessWidget {
  const _TextTab({
    required this.titleController,
    required this.textController,
    required this.isLoading,
    required this.errorMsg,
    required this.onAnalyze,
  });
  final TextEditingController titleController;
  final TextEditingController textController;
  final bool isLoading;
  final String? errorMsg;
  final VoidCallback onAnalyze;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          TextField(
            controller: titleController,
            enabled: !isLoading,
            decoration: InputDecoration(
              hintText: '제목 (선택 — 없으면 AI가 자동 생성)',
              hintStyle: TextStyle(color: softBrownColor.withAlpha(150), fontSize: 13),
              filled: true,
              fillColor: creamColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: TextField(
              controller: textController,
              enabled: !isLoading,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              decoration: InputDecoration(
                hintText: '재료와 조리 순서를 입력하세요.\nAI가 구조화해서 저장해요. (50자 이상)',
                hintStyle: TextStyle(color: softBrownColor.withAlpha(150), fontSize: 13),
                filled: true,
                fillColor: creamColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(16),
                errorText: errorMsg,
              ),
            ),
          ),
          const SizedBox(height: 12),
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
                  : const Text('AI로 구조화 저장', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}
