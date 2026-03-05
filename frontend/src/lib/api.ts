import type { Recipe, CollectionItem, CollectionTag } from './types';
import { getSession } from '$lib/stores/auth.svelte';

const API_BASE = import.meta.env.VITE_API_URL || 'http://localhost:8000';

const ERROR_MESSAGES: Record<string, string> = {
	INVALID_URL: '올바른 유튜브 링크를 입력해주세요.',
	NOT_RECIPE: '이 영상은 요리 레시피가 아닙니다.',
	ACCESS_DENIED: '비공개 또는 멤버십 전용 영상입니다.',
	EXTRACTION_FAILED: '레시피 추출 중 오류가 발생했습니다.',
	NO_DATA_AVAILABLE: '이 영상에서 자막과 오디오를 모두 가져올 수 없습니다. 자막이 있는 영상으로 다시 시도해주세요.',
	INTERNAL_ERROR: '서버 내부 오류가 발생했습니다.'
};

function getAuthHeaders(): Record<string, string> {
	const session = getSession();
	const headers: Record<string, string> = {
		'Content-Type': 'application/json'
	};
	if (session?.access_token) {
		headers['Authorization'] = `Bearer ${session.access_token}`;
	}
	return headers;
}

function getUserId(): string {
	const session = getSession();
	return session?.user?.id || '00000000-0000-0000-0000-000000000000';
}

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
		headers: getAuthHeaders(),
		body: JSON.stringify({ youtube_url: url, mode: 'fast', force_refresh: forceRefresh })
	});
	return handleResponse<Recipe>(response);
}

export async function saveToCollection(recipeId: number, customTip?: string): Promise<number> {
	const response = await fetch(`${API_BASE}/collections`, {
		method: 'POST',
		headers: getAuthHeaders(),
		body: JSON.stringify({
			user_id: getUserId(),
			recipe_id: recipeId,
			custom_tip: customTip || null
		})
	});
	const data = await handleResponse<{ status: string; collection_id: number }>(response);
	return data.collection_id;
}

export async function getCollections(): Promise<CollectionItem[]> {
	const userId = getUserId();
	const response = await fetch(`${API_BASE}/collections/${userId}`, {
		headers: getAuthHeaders()
	});
	return handleResponse<CollectionItem[]>(response);
}

export async function deleteFromCollection(collectionId: number): Promise<void> {
	const response = await fetch(`${API_BASE}/collections/${collectionId}`, {
		method: 'DELETE',
		headers: getAuthHeaders()
	});
	await handleResponse(response);
}

export async function updateCollection(collectionId: number, customTip: string): Promise<void> {
	const response = await fetch(`${API_BASE}/collections/${collectionId}`, {
		method: 'PATCH',
		headers: getAuthHeaders(),
		body: JSON.stringify({ custom_tip: customTip || null })
	});
	await handleResponse(response);
}

export async function toggleFavorite(collectionId: number): Promise<void> {
	const response = await fetch(`${API_BASE}/collections/${collectionId}/favorite`, {
		method: 'PUT',
		headers: getAuthHeaders()
	});
	await handleResponse(response);
}

export async function setRating(collectionId: number, rating: number): Promise<void> {
	const response = await fetch(`${API_BASE}/collections/${collectionId}/rating`, {
		method: 'PUT',
		headers: getAuthHeaders(),
		body: JSON.stringify({ rating })
	});
	await handleResponse(response);
}

export async function recordCooked(collectionId: number, rating?: number): Promise<void> {
	const response = await fetch(`${API_BASE}/collections/${collectionId}/cooked`, {
		method: 'POST',
		headers: getAuthHeaders(),
		body: JSON.stringify({ rating: rating ?? null })
	});
	await handleResponse(response);
}

export async function getTags(): Promise<CollectionTag[]> {
	const userId = getUserId();
	const response = await fetch(`${API_BASE}/tags/${userId}`, {
		headers: getAuthHeaders()
	});
	return handleResponse<CollectionTag[]>(response);
}

export async function createTag(name: string, color: string): Promise<CollectionTag> {
	const response = await fetch(`${API_BASE}/tags`, {
		method: 'POST',
		headers: getAuthHeaders(),
		body: JSON.stringify({ user_id: getUserId(), name, color })
	});
	return handleResponse<CollectionTag>(response);
}

export async function deleteTag(tagId: number): Promise<void> {
	const response = await fetch(`${API_BASE}/tags/${tagId}`, {
		method: 'DELETE',
		headers: getAuthHeaders()
	});
	await handleResponse(response);
}

export async function setCollectionTags(collectionId: number, tagIds: number[]): Promise<void> {
	const response = await fetch(`${API_BASE}/collections/${collectionId}/tags`, {
		method: 'PUT',
		headers: getAuthHeaders(),
		body: JSON.stringify({ tag_ids: tagIds })
	});
	await handleResponse(response);
}
