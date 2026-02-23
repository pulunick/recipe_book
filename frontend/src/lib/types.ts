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
	video_url: string | null;
	video_id: string | null;
}

export interface CollectionItem {
	id: number;
	recipe: Recipe;
	custom_tip: string | null;
	created_at: string;
}

export type AnalysisMode = 'fast' | 'precise';

export type PageStatus = 'IDLE' | 'LOADING' | 'RESULT' | 'ERROR';
