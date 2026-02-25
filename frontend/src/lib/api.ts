import type { Recipe, CollectionItem } from './types';

const API_BASE = import.meta.env.VITE_API_URL || 'http://localhost:8000';

const ERROR_MESSAGES: Record<string, string> = {
	INVALID_URL: '올바른 유튜브 링크를 입력해주세요.',
	NOT_RECIPE: '이 영상은 요리 레시피가 아닙니다.',
	ACCESS_DENIED: '비공개 또는 멤버십 전용 영상입니다.',
	EXTRACTION_FAILED: '레시피 추출 중 오류가 발생했습니다.',
	NO_DATA_AVAILABLE: '이 영상에서 자막과 오디오를 모두 가져올 수 없습니다. 자막이 있는 영상으로 다시 시도해주세요.',
	INTERNAL_ERROR: '서버 내부 오류가 발생했습니다.'
};

async function handleResponse<T>(response: Response): Promise<T> {
	if (!response.ok) {
		const body = await response.json().catch(() => ({}));
		const code = body?.error_code || body?.detail?.error_code || '';
		const serverMsg = body?.message || body?.detail?.message || '';
		throw new Error(ERROR_MESSAGES[code] || serverMsg || '알 수 없는 오류가 발생했습니다.');
	}
	return response.json();
}

export async function extractRecipe(url: string, forceRefresh = false): Promise<Recipe> {
	const response = await fetch(`${API_BASE}/extract-recipe`, {
		method: 'POST',
		headers: { 'Content-Type': 'application/json' },
		body: JSON.stringify({ youtube_url: url, mode: 'fast', force_refresh: forceRefresh })
	});
	return handleResponse<Recipe>(response);
}

export async function saveToCollection(recipeId: number, customTip?: string): Promise<void> {
	const response = await fetch(`${API_BASE}/collections`, {
		method: 'POST',
		headers: { 'Content-Type': 'application/json' },
		body: JSON.stringify({
			user_id: '00000000-0000-0000-0000-000000000000',
			recipe_id: recipeId,
			custom_tip: customTip || null
		})
	});
	await handleResponse(response);
}

export async function getCollections(userId = '00000000-0000-0000-0000-000000000000'): Promise<CollectionItem[]> {
	const response = await fetch(`${API_BASE}/collections/${userId}`);
	return handleResponse<CollectionItem[]>(response);
}

export async function deleteFromCollection(collectionId: number): Promise<void> {
	const response = await fetch(`${API_BASE}/collections/${collectionId}`, {
		method: 'DELETE'
	});
	await handleResponse(response);
}

export async function updateCollection(collectionId: number, customTip: string): Promise<void> {
	const response = await fetch(`${API_BASE}/collections/${collectionId}`, {
		method: 'PATCH',
		headers: { 'Content-Type': 'application/json' },
		body: JSON.stringify({ custom_tip: customTip || null })
	});
	await handleResponse(response);
}
