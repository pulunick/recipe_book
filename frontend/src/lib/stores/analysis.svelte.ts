import { extractRecipe, saveToCollection } from '$lib/api';

export type AnalysisStatus = 'idle' | 'analyzing' | 'done' | 'error';

interface AnalysisState {
	status: AnalysisStatus;
	recipeTitle: string | null;
	navigateTo: string | null;
	error: string;
}

let state = $state<AnalysisState>({
	status: 'idle',
	recipeTitle: null,
	navigateTo: null,
	error: ''
});

export function getAnalysis() {
	return state;
}

export function dismissAnalysis() {
	state.status = 'idle';
	state.recipeTitle = null;
	state.navigateTo = null;
	state.error = '';
}

export async function startAnalysis(url: string, loggedIn: boolean) {
	if (state.status === 'analyzing') return;

	state.status = 'analyzing';
	state.recipeTitle = null;
	state.navigateTo = null;
	state.error = '';

	try {
		// 로그인 상태면 auto_save=true — 서버가 분석+저장을 한 번에 처리
		const recipe = await extractRecipe(url, false, loggedIn);
		state.recipeTitle = recipe.title;

		if (loggedIn) {
			if (recipe.collection_id) {
				// auto_save 성공: 서버가 반환한 collection_id 바로 사용
				state.navigateTo = `/my-recipes/${recipe.collection_id}`;
			} else if (recipe.id) {
				// fallback: auto_save 실패 시 별도 저장
				const collectionId = await saveToCollection(recipe.id);
				state.navigateTo = `/my-recipes/${collectionId}`;
			} else {
				state.navigateTo = `/recipe/${recipe.video_id ?? recipe.id}`;
			}
		} else {
			state.navigateTo = `/recipe/${recipe.video_id ?? recipe.id}`;
		}

		state.status = 'done';
	} catch (e: unknown) {
		state.error = e instanceof Error ? e.message : '알 수 없는 오류가 발생했습니다.';
		state.status = 'error';
	}
}
