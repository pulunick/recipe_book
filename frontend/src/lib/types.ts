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
	summary: string;
	ingredients: Ingredient[];
	steps: RecipeStep[];
	flavor: FlavorProfile;
	tip: string | null;
	category: string | null;
	video_url: string | null;
	video_id: string | null;
	video_title: string | null;
	channel_name: string | null;
	servings: string | null;
	cooking_time: string | null;
	difficulty: string | null;
}

export interface CollectionItem {
	id: number;
	recipe: Recipe;
	custom_tip: string | null;
	created_at: string;
	is_favorite: boolean;
	my_rating: number | null;
	cooked_count: number;
	last_cooked_at: string | null;
	category_override: string | null;
	tags: CollectionTag[];
}

export interface CollectionTag {
	id: number;
	name: string;
	color: string;
}

export type AnalysisMode = 'fast' | 'precise';

export type PageStatus = 'IDLE' | 'LOADING' | 'ERROR';
