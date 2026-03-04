// See https://svelte.dev/docs/kit/types#app.d.ts
// for information about these interfaces
import type { Recipe } from '$lib/types';

declare global {
	namespace App {
		// interface Error {}
		// interface Locals {}
		// interface PageData {}
		interface PageState {
			recipe?: Recipe;
			sourceUrl?: string;
			justAdded?: boolean;
		}
		// interface Platform {}
	}
}

export {};
