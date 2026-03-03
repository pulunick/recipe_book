import { getCollections, getTags } from '$lib/api';
import { error } from '@sveltejs/kit';
import type { PageLoad } from './$types';

export const load: PageLoad = async ({ params }) => {
	const id = parseInt(params.id);
	if (isNaN(id)) throw error(404, '레시피를 찾을 수 없습니다.');

	const [collections, allTags] = await Promise.all([getCollections(), getTags()]);
	const item = collections.find(c => c.id === id);
	if (!item) throw error(404, '레시피를 찾을 수 없습니다.');

	return { item, allTags };
};
