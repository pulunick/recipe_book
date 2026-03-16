import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../shared/models/recipe.dart';
import '../recipe_detail/recipe_detail_page.dart';

class CookingModePage extends ConsumerStatefulWidget {
  const CookingModePage({super.key, required this.collectionId});
  final int collectionId;

  @override
  ConsumerState<CookingModePage> createState() => _CookingModePageState();
}

class _CookingModePageState extends ConsumerState<CookingModePage> {
  int _currentStep = 0;
  final Set<int> _checkedIngredients = {};

  // 타이머
  Timer? _timer;
  int _timerSeconds = 0;
  bool _timerRunning = false;

  @override
  void initState() {
    super.initState();
    // 화면 항상 켜짐
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _timer?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _startTimer(int seconds) {
    _timer?.cancel();
    setState(() {
      _timerSeconds = seconds;
      _timerRunning = true;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_timerSeconds <= 0) {
        t.cancel();
        setState(() => _timerRunning = false);
        _onTimerDone();
      } else {
        setState(() => _timerSeconds--);
      }
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() => _timerRunning = false);
  }

  void _resetTimer(int seconds) {
    _timer?.cancel();
    setState(() {
      _timerSeconds = seconds;
      _timerRunning = false;
    });
  }

  void _onTimerDone() {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('타이머 완료! ⏰'),
        content: const Text('시간이 됐어요. 다음 단계로 넘어가볼까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  int? _parseTimerSeconds(String? timerText) {
    if (timerText == null) return null;
    final minuteMatch = RegExp(r'(\d+)\s*분').firstMatch(timerText);
    final secondMatch = RegExp(r'(\d+)\s*초').firstMatch(timerText);
    int total = 0;
    if (minuteMatch != null) total += int.parse(minuteMatch.group(1)!) * 60;
    if (secondMatch != null) total += int.parse(secondMatch.group(1)!);
    return total > 0 ? total : null;
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final itemAsync = ref.watch(collectionItemProvider(widget.collectionId));

    return itemAsync.when(
      loading: () => const Scaffold(
        backgroundColor: darkColor,
        body: Center(child: CircularProgressIndicator(color: primaryColor)),
      ),
      error: (e, st) => Scaffold(
        backgroundColor: darkColor,
        appBar: AppBar(backgroundColor: darkColor, foregroundColor: Colors.white),
        body: const Center(
          child: Text('불러올 수 없어요', style: TextStyle(color: Colors.white)),
        ),
      ),
      data: (item) {
        final ov = item.recipeOverride;
        final recipe = ov == null ? item.recipe : _applyOverride(item.recipe, ov);
        final steps = recipe.steps;
        final ingredients = recipe.ingredients;

        if (steps.isEmpty) {
          return Scaffold(
            backgroundColor: darkColor,
            appBar: AppBar(
              backgroundColor: darkColor,
              foregroundColor: Colors.white,
              title: const Text('쿠킹 모드'),
            ),
            body: const Center(
              child: Text('조리 순서가 없어요.', style: TextStyle(color: Colors.white60)),
            ),
          );
        }

        final step = steps[_currentStep];
        final timerSecs = _parseTimerSeconds(step.timer);
        final isLast = _currentStep == steps.length - 1;

        return Scaffold(
          backgroundColor: const Color(0xFF1A1A1A),
          body: SafeArea(
            child: Column(
              children: [
                // 상단 바
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.white70),
                      ),
                      Expanded(
                        child: Text(
                          recipe.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      // 재료 보기 버튼
                      IconButton(
                        onPressed: () => _showIngredients(context, ingredients),
                        icon: const Icon(Icons.list_alt_outlined, color: Colors.white70),
                        tooltip: '재료 목록',
                      ),
                    ],
                  ),
                ),

                // 진행 바
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: List.generate(steps.length, (i) {
                      return Expanded(
                        child: Container(
                          height: 4,
                          margin: EdgeInsets.only(right: i < steps.length - 1 ? 4 : 0),
                          decoration: BoxDecoration(
                            color: i <= _currentStep ? primaryColor : Colors.white24,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_currentStep + 1} / ${steps.length}',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),

                // 메인 단계 내용
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // 단계 번호
                        Container(
                          width: 52,
                          height: 52,
                          decoration: const BoxDecoration(
                            color: primaryColor,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${step.stepNumber}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        // 조리 설명
                        Text(
                          step.description,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            height: 1.7,
                            fontWeight: FontWeight.w400,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        // 타이머
                        if (timerSecs != null) ...[
                          const SizedBox(height: 32),
                          _TimerWidget(
                            totalSeconds: timerSecs,
                            remainingSeconds: _timerRunning || _timerSeconds > 0
                                ? _timerSeconds
                                : timerSecs,
                            isRunning: _timerRunning,
                            formatTime: _formatTime,
                            onStart: () => _startTimer(
                              _timerSeconds > 0 ? _timerSeconds : timerSecs,
                            ),
                            onPause: _pauseTimer,
                            onReset: () => _resetTimer(timerSecs),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // 하단 네비게이션
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: Row(
                    children: [
                      // 이전 버튼
                      if (_currentStep > 0)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              _timer?.cancel();
                              setState(() {
                                _currentStep--;
                                _timerSeconds = 0;
                                _timerRunning = false;
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white70,
                              side: const BorderSide(color: Colors.white24),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text('이전', style: TextStyle(fontSize: 16)),
                          ),
                        ),
                      if (_currentStep > 0) const SizedBox(width: 12),

                      // 다음/완료 버튼
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () {
                            if (isLast) {
                              _showComplete(context);
                            } else {
                              _timer?.cancel();
                              setState(() {
                                _currentStep++;
                                _timerSeconds = 0;
                                _timerRunning = false;
                              });
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isLast ? const Color(0xFF4CAF50) : primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            isLast ? '🎉 완료!' : '다음 단계',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showIngredients(BuildContext context, List<Ingredient> ingredients) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2A2A2A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            const Text('재료 목록', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                itemCount: ingredients.length,
                itemBuilder: (context, i) {
                  final ing = ingredients[i];
                  final checked = _checkedIngredients.contains(i);
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: GestureDetector(
                      onTap: () {
                        setModalState(() {
                          setState(() {
                            if (checked) { _checkedIngredients.remove(i); }
                            else { _checkedIngredients.add(i); }
                          });
                        });
                      },
                      child: Icon(
                        checked ? Icons.check_circle : Icons.radio_button_unchecked,
                        color: checked ? primaryColor : Colors.white38,
                      ),
                    ),
                    title: Text(
                      ing.name,
                      style: TextStyle(
                        color: checked ? Colors.white38 : Colors.white,
                        decoration: checked ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    trailing: Text(
                      [ing.amount, ing.unit].whereType<String>().join(' '),
                      style: const TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showComplete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('요리 완성! 🎉'),
        content: const Text('맛있게 드세요! 별점을 남겨보시겠어요?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).pop();
            },
            child: const Text('나중에'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
            child: const Text('확인', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Recipe _applyOverride(Recipe base, Map<String, dynamic> ov) {
    final overrideIngredients = ov['ingredients'] as List?;
    final overrideSteps = ov['steps'] as List?;
    return Recipe(
      id: base.id,
      title: ov['title'] as String? ?? base.title,
      summary: base.summary,
      ingredients: overrideIngredients != null
          ? overrideIngredients.map((e) => Ingredient.fromJson(e as Map<String, dynamic>)).toList()
          : base.ingredients,
      steps: overrideSteps != null
          ? overrideSteps.map((e) => RecipeStep.fromJson(e as Map<String, dynamic>)).toList()
          : base.steps,
      tip: base.tip,
      category: base.category,
      cookingTimeMinutes: base.cookingTimeMinutes,
      calories: base.calories,
      servings: base.servings,
      difficulty: base.difficulty,
      videoId: base.videoId,
      channelName: base.channelName,
      source: base.source,
      flavor: base.flavor,
      cookingTime: base.cookingTime,
    );
  }
}

// ── 타이머 위젯 ───────────────────────────────────────────────
class _TimerWidget extends StatelessWidget {
  const _TimerWidget({
    required this.totalSeconds,
    required this.remainingSeconds,
    required this.isRunning,
    required this.formatTime,
    required this.onStart,
    required this.onPause,
    required this.onReset,
  });

  final int totalSeconds;
  final int remainingSeconds;
  final bool isRunning;
  final String Function(int) formatTime;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final progress = totalSeconds > 0 ? remainingSeconds / totalSeconds : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 100,
                height: 100,
                child: CircularProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.white12,
                  color: primaryColor,
                  strokeWidth: 6,
                ),
              ),
              Text(
                formatTime(remainingSeconds),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: onReset,
                icon: const Icon(Icons.refresh, color: Colors.white54),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: isRunning ? onPause : onStart,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  elevation: 0,
                ),
                child: Text(
                  isRunning ? '일시정지' : '시작',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
