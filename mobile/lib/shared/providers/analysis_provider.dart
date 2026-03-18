import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_service.dart';

enum AnalysisStatus { idle, analyzing, done, error }

class AnalysisState {
  final AnalysisStatus status;
  final int? collectionId;
  final String? recipeTitle;
  final String? errorMessage;

  const AnalysisState({
    this.status = AnalysisStatus.idle,
    this.collectionId,
    this.recipeTitle,
    this.errorMessage,
  });

  bool get isAnalyzing => status == AnalysisStatus.analyzing;
}

class AnalysisNotifier extends StateNotifier<AnalysisState> {
  AnalysisNotifier(this._api) : super(const AnalysisState());

  final ApiService _api;

  Future<void> startAnalysis(String url) async {
    if (state.isAnalyzing) return;
    state = const AnalysisState(status: AnalysisStatus.analyzing);

    try {
      final result = await _api.extractFromYoutube(url);

      final isRecipe = result['is_recipe'] as bool? ?? true;
      if (!isRecipe) {
        state = AnalysisState(
          status: AnalysisStatus.error,
          errorMessage: result['non_recipe_reason'] as String? ?? '요리 레시피 영상이 아니에요.',
        );
        return;
      }

      state = AnalysisState(
        status: AnalysisStatus.done,
        collectionId: result['collection_id'] as int?,
        recipeTitle: result['title'] as String?,
      );
    } catch (e) {
      final msg = e.toString();
      String errorMessage;
      if (msg.contains('NOT_RECIPE')) {
        errorMessage = '요리 레시피 영상이 아니에요.';
      } else if (msg.contains('INVALID_URL')) {
        errorMessage = '유효한 YouTube URL이 아니에요.';
      } else if (msg.contains('ACCESS_DENIED')) {
        errorMessage = '영상에 접근할 수 없어요.';
      } else if (msg.contains('SocketException') || msg.contains('connection')) {
        errorMessage = '네트워크 연결을 확인해주세요.';
      } else if (msg.contains('TimeoutException')) {
        errorMessage = '분석 시간이 초과됐어요. 다시 시도해주세요.';
      } else {
        errorMessage = '오류가 발생했어요. 다시 시도해주세요.';
      }
      state = AnalysisState(status: AnalysisStatus.error, errorMessage: errorMessage);
    }
  }

  void setDone({int? collectionId, String? recipeTitle}) {
    state = AnalysisState(
      status: AnalysisStatus.done,
      collectionId: collectionId,
      recipeTitle: recipeTitle,
    );
  }

  void dismiss() {
    state = const AnalysisState();
  }
}

final analysisProvider = StateNotifierProvider<AnalysisNotifier, AnalysisState>((ref) {
  return AnalysisNotifier(ref.watch(apiServiceProvider));
});
