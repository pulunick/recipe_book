import type { Recipe, CollectionItem, CollectionTag, RecipeOverride, RecipePublicItem, CartGroup, RecipeAuthorUpdate } from './types';
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

export async function extractRecipe(url: string, forceRefresh = false, autoSave = false): Promise<Recipe> {
	const response = await fetch(`${API_BASE}/extract-recipe`, {
		method: 'POST',
		headers: getAuthHeaders(),
		body: JSON.stringify({ youtube_url: url, mode: 'fast', force_refresh: forceRefresh, auto_save: autoSave })
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

export async function checkCollection(recipeId: number): Promise<number | null> {
	const response = await fetch(`${API_BASE}/collections/check/${recipeId}`, {
		headers: getAuthHeaders()
	});
	const data = await handleResponse<{ my_collection_id: number | null }>(response);
	return data.my_collection_id;
}

export async function getCollectionItem(collectionId: number): Promise<CollectionItem> {
	const response = await fetch(`${API_BASE}/collections/item/${collectionId}`, {
		headers: getAuthHeaders()
	});
	return handleResponse<CollectionItem>(response);
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

export async function updateCollectionWithOverride(
	collectionId: number,
	customTip: string | null,
	recipeOverride: RecipeOverride | null
): Promise<void> {
	const response = await fetch(`${API_BASE}/collections/${collectionId}`, {
		method: 'PATCH',
		headers: getAuthHeaders(),
		body: JSON.stringify({
			custom_tip: customTip || null,
			recipe_override: recipeOverride
		})
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

export async function extractRecipeFromText(text: string, title?: string): Promise<Recipe> {
	const response = await fetch(`${API_BASE}/extract-recipe-from-text`, {
		method: 'POST',
		headers: getAuthHeaders(),
		body: JSON.stringify({ text, title: title || null })
	});
	return handleResponse<Recipe>(response);
}

export async function saveTextRecipe(recipe: Recipe, customTip?: string, isPublic = false): Promise<number> {
	const response = await fetch(`${API_BASE}/collections/text-recipe`, {
		method: 'POST',
		headers: getAuthHeaders(),
		body: JSON.stringify({ recipe, custom_tip: customTip || null, is_public: isPublic })
	});
	const data = await handleResponse<{ status: string; collection_id: number }>(response);
	return data.collection_id;
}

export async function updateTextRecipe(recipeId: number, data: RecipeAuthorUpdate): Promise<void> {
	const response = await fetch(`${API_BASE}/recipes/${recipeId}`, {
		method: 'PATCH',
		headers: getAuthHeaders(),
		body: JSON.stringify(data)
	});
	await handleResponse(response);
}

// --- 장바구니 ---

export async function getCart(): Promise<CartGroup[]> {
	const response = await fetch(`${API_BASE}/cart`, {
		headers: getAuthHeaders()
	});
	return handleResponse<CartGroup[]>(response);
}

export async function addCartFromCollection(collectionId: number): Promise<{ status: string; count: number }> {
	const response = await fetch(`${API_BASE}/cart/from-collection/${collectionId}`, {
		method: 'POST',
		headers: getAuthHeaders()
	});
	return handleResponse<{ status: string; count: number }>(response);
}

export async function toggleCartItem(itemId: number): Promise<{ is_checked: boolean }> {
	const response = await fetch(`${API_BASE}/cart/items/${itemId}/check`, {
		method: 'PUT',
		headers: getAuthHeaders()
	});
	return handleResponse<{ is_checked: boolean }>(response);
}

export async function deleteCartItem(itemId: number): Promise<void> {
	const response = await fetch(`${API_BASE}/cart/items/${itemId}`, {
		method: 'DELETE',
		headers: getAuthHeaders()
	});
	await handleResponse(response);
}

export async function deleteCheckedCartItems(): Promise<void> {
	const response = await fetch(`${API_BASE}/cart/checked`, {
		method: 'DELETE',
		headers: getAuthHeaders()
	});
	await handleResponse(response);
}

export async function clearCart(): Promise<void> {
	const response = await fetch(`${API_BASE}/cart`, {
		method: 'DELETE',
		headers: getAuthHeaders()
	});
	await handleResponse(response);
}

export async function getRecipeCategories(): Promise<string[]> {
	const response = await fetch(`${API_BASE}/recipes/categories`);
	return handleResponse<string[]>(response);
}

export interface PublicRecipesParams {
	category?: string;
	q?: string;
	page?: number;
	limit?: number;
	source?: string;
}

export async function getPublicRecipes(params: PublicRecipesParams = {}): Promise<RecipePublicItem[]> {
	const query = new URLSearchParams();
	if (params.category) query.set('category', params.category);
	if (params.q) query.set('q', params.q);
	if (params.page) query.set('page', String(params.page));
	if (params.limit) query.set('limit', String(params.limit));
	if (params.source) query.set('source', params.source);
	const response = await fetch(`${API_BASE}/recipes?${query.toString()}`, {
		headers: getAuthHeaders()
	});
	const data = await handleResponse<{ items: RecipePublicItem[]; total: number; has_more: boolean }>(response);
	return data.items;
}

export async function chatWithAi(
	collectionId: number,
	message: string,
	history: { role: string; content: string }[]
): Promise<string> {
	const response = await fetch(`${API_BASE}/ai/chat`, {
		method: 'POST',
		headers: { 'Content-Type': 'application/json', ...getAuthHeaders() },
		body: JSON.stringify({ collection_id: collectionId, message, history })
	});
	const data = await handleResponse<{ reply: string }>(response);
	return data.reply;
}
