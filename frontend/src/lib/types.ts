export interface Ingredient {
	name: string;
	amount: string | null;
	unit: string | null;
	category: string;
}

export interface RecipeStep {
	step_number: number;
	description: string;
	timer: string | null;
}

export interface FlavorProfile {
	saltiness: number;
	sweetness: number;
	spiciness: number;
	sourness: number;
	oiliness: number;
}

export interface Recipe {
	id: number | null;
	title: string;
	summary?: string | null;
	ingredients?: Ingredient[];
	steps?: RecipeStep[];
	flavor?: FlavorProfile | null;
	tip?: string | null;
	category: string | null;
	video_url?: string | null;
	video_id: string | null;
	video_title?: string | null;
	channel_name: string | null;
	servings: string | null;
	cooking_time: string | null;
	difficulty: string | null;
	source?: string | null;
	author_user_id?: string | null;
	is_public?: boolean | null;
	collection_id?: number | null;
	calories?: number | null;
	cooking_time_minutes?: number | null;
}

export interface IngredientOverride {
	name: string;
	amount: string;
	unit: string;
	category: string;
	note?: string;
}

export interface StepOverride {
	order: number;
	description: string;
	timer_minutes?: number | null;
	note?: string;
}

export interface RecipeOverride {
	ingredients?: IngredientOverride[];
	steps?: StepOverride[];
	tip?: string;
}

export interface CollectionItem {
	id: number;
	recipe: Recipe;
	custom_tip: string | null;
	recipe_override: RecipeOverride | null;
	created_at: string;
	is_favorite: boolean;
	my_rating: number | null;
	cooked_count: number;
	last_cooked_at: string | null;
	category_override: string | null;
	tags: CollectionTag[];
}

export interface RecipeAuthorUpdate {
	title?: string;
	summary?: string;
	ingredients?: Ingredient[];
	steps?: RecipeStep[];
	tip?: string | null;
	servings?: string | null;
	cooking_time?: string | null;
	difficulty?: string | null;
	is_public?: boolean;
}

export interface CollectionTag {
	id: number;
	name: string;
	color: string;
}

// --- 장바구니 ---
export interface CartItem {
	id: number;
	collection_id: number | null;
	recipe_title: string | null;
	ingredient_name: string;
	amount: string | null;
	unit: string | null;
	category: string;
	is_checked: boolean;
	created_at: string;
}

export interface CartGroup {
	collection_id: number | null;
	recipe_title: string | null;
	items: CartItem[];
}

export type AnalysisMode = 'fast' | 'precise';

export type PageStatus = 'IDLE' | 'LOADING' | 'ERROR';

// --- 입맛 분석 ---
export interface TasteProfileResponse {
	has_data: boolean;
	recipe_count: number;
	profile: FlavorProfile | null;  // float 값 (1.0~5.0)
	top_category: string | null;
	favorite_count: number;
	total_cooked: number;
	avg_rating: number | null;
}

export interface RecipePublicItem {
	id: number;
	title: string;
	summary: string;
	category: string | null;
	cooking_time: string | null;
	difficulty: string | null;
	servings: string | null;
	video_id: string | null;
	channel_name: string | null;
	created_at: string;
	my_collection_id: number | null;
	source: string | null;  // 'youtube' | 'text'
	calories: number | null;
	cooking_time_minutes: number | null;
}

// --- 냉장고 파먹기 ---
export interface FridgeSearchResultItem {
	id: number;
	title: string;
	category?: string;
	cooking_time?: string;
	difficulty?: string;
	video_id?: string;
	channel_name?: string;
	source?: string;
	collection_count: number;
	match_score: number;
	matched_ingredients: string[];
}
