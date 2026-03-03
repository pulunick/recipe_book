<script lang="ts">
	import { onMount } from 'svelte';
	import { fade } from 'svelte/transition';
	import type { CollectionItem, CollectionTag } from '$lib/types';
	import { getCollections, getTags, toggleFavorite, setRating, setCollectionTags, createTag } from '$lib/api';
	import RecipeCard from '$lib/components/RecipeCard.svelte';

	let collections: CollectionItem[] = $state([]);
	let allTags: CollectionTag[] = $state([]);
	let loading = $state(true);
	let error = $state('');
	// 'all' | 'favorites' | 카테고리명 | 'tag:{id}'
	let selectedFilter = $state('all');

	onMount(async () => {
		try {
			const [cols, tags] = await Promise.all([getCollections(), getTags()]);
			collections = cols;
			allTags = tags;
		} catch (e: unknown) {
			error = e instanceof Error ? e.message : '보관함을 불러오지 못했습니다.';
		} finally {
			loading = false;
		}
	});

	const categories = $derived.by(() => {
		const cats = collections
			.map(c => c.category_override ?? c.recipe.category)
			.filter((c): c is string => Boolean(c));
		return Array.from(new Set(cats));
	});

	const favoriteCount = $derived(collections.filter(c => c.is_favorite).length);

	const filteredCollections = $derived.by(() => {
		if (selectedFilter === 'favorites') return collections.filter(c => c.is_favorite);
		if (selectedFilter.startsWith('tag:')) {
			const tagId = Number(selectedFilter.slice(4));
			return collections.filter(c => c.tags.some(t => t.id === tagId));
		}
		if (selectedFilter !== 'all') {
			return collections.filter(c => (c.category_override ?? c.recipe.category) === selectedFilter);
		}
		return collections;
	});

	/* ── 핸들러 ── */
	async function handleFavorite(id: number) {
		// 낙관적 업데이트
		collections = collections.map(c => c.id === id ? { ...c, is_favorite: !c.is_favorite } : c);
		try {
			await toggleFavorite(id);
		} catch {
			// 실패 시 롤백
			collections = collections.map(c => c.id === id ? { ...c, is_favorite: !c.is_favorite } : c);
		}
	}

	async function handleRate(collectionId: number, rating: number) {
		collections = collections.map(c => c.id === collectionId ? { ...c, my_rating: rating } : c);
		try { await setRating(collectionId, rating); } catch { /* 무시 */ }
	}

	async function handleTagAttach(collectionId: number, tagId: number) {
		const tag = allTags.find(t => t.id === tagId);
		if (!tag) return;
		collections = collections.map(c => {
			if (c.id !== collectionId || c.tags.some(t => t.id === tagId)) return c;
			return { ...c, tags: [...c.tags, tag] };
		});
		const item = collections.find(c => c.id === collectionId);
		if (item) await setCollectionTags(collectionId, item.tags.map(t => t.id)).catch(() => {});
	}

	async function handleTagDetach(collectionId: number, tagId: number) {
		collections = collections.map(c =>
			c.id !== collectionId ? c : { ...c, tags: c.tags.filter(t => t.id !== tagId) }
		);
		const item = collections.find(c => c.id === collectionId);
		if (item) await setCollectionTags(collectionId, item.tags.map(t => t.id)).catch(() => {});
	}

	async function handleTagCreate(collectionId: number, name: string, color: string) {
		try {
			const newTag = await createTag(name, color);
			allTags = [...allTags, newTag];
			await handleTagAttach(collectionId, newTag.id);
		} catch { /* 무시 */ }
	}
</script>

<svelte:head>
	<title>보관함 | 입맛 저격 레시피 AI</title>
</svelte:head>

<main class="page-wrap">
	<header class="library-header">
		<h1>보관함</h1>
		{#if !loading && !error && collections.length > 0}
			<p class="count">{collections.length}개의 레시피가 저장되어 있어요</p>
		{/if}
	</header>

	{#if loading}
		<div class="status-area">
			<p>불러오는 중...</p>
		</div>
	{:else if error}
		<div class="status-area error">
			<p>문제가 생겼어요</p>
			<p class="detail">{error}</p>
		</div>
	{:else if collections.length === 0}
		<div class="empty-book" in:fade>
			<h2>아직 레시피북이 비어있어요</h2>
			<p>유튜브 요리 영상 링크를<br />붙여넣으면 첫 레시피가 생겨요</p>
			<a href="/" class="cta-btn">첫 레시피 정리하러 가기</a>
		</div>
	{:else}
		<!-- 필터 탭: 전체 / 즐겨찾기 / 카테고리들 / 태그들 -->
		<div class="filter-tabs" in:fade>
			<button
				class="tab-btn"
				class:active={selectedFilter === 'all'}
				onclick={() => (selectedFilter = 'all')}
			>전체 <span class="tab-count">{collections.length}</span></button>

			{#if favoriteCount > 0}
				<button
					class="tab-btn"
					class:active={selectedFilter === 'favorites'}
					onclick={() => (selectedFilter = 'favorites')}
				>⭐ 즐겨찾기 <span class="tab-count">{favoriteCount}</span></button>
			{/if}

			{#each categories as cat}
				<button
					class="tab-btn"
					class:active={selectedFilter === cat}
					onclick={() => (selectedFilter = cat)}
				>{cat} <span class="tab-count">{collections.filter(c => (c.category_override ?? c.recipe.category) === cat).length}</span></button>
			{/each}

			{#each allTags as tag}
				<button
					class="tab-btn tag-tab"
					class:active={selectedFilter === `tag:${tag.id}`}
					style:--tag-color={tag.color}
					onclick={() => (selectedFilter = `tag:${tag.id}`)}
				>{tag.name}</button>
			{/each}
		</div>

		{#if filteredCollections.length === 0}
			<div class="status-area" in:fade>
				<p>이 필터에 해당하는 레시피가 없어요</p>
			</div>
		{:else}
			<div class="recipe-grid" in:fade>
				{#each filteredCollections as item (item.id)}
					<RecipeCard
						{item}
						{allTags}
						onfavorite={handleFavorite}
						ontagattach={handleTagAttach}
						ontagdetach={handleTagDetach}
						ontagcreate={handleTagCreate}
						onrate={handleRate}
					/>
				{/each}
			</div>
		{/if}
	{/if}
</main>

<style>
	.page-wrap {
		max-width: 1100px;
		margin: 0 auto;
		padding: 0 var(--page-padding-desktop);
		min-height: calc(100vh - 80px);
	}
	.library-header {
		padding: 2rem 0 1rem;
	}
	.library-header h1 {
		font-size: 1.8rem;
		margin-bottom: 0.3rem;
	}
	.count {
		font-size: 0.95rem;
		color: var(--color-soft-brown);
	}

	/* 필터 탭 */
	.filter-tabs {
		display: flex;
		gap: 0.4rem;
		margin-bottom: 1.2rem;
		overflow-x: auto;
		-webkit-overflow-scrolling: touch;
		padding-bottom: 0.3rem;
	}
	.filter-tabs::-webkit-scrollbar { display: none; }

	.tab-btn {
		flex-shrink: 0;
		display: inline-flex;
		align-items: center;
		gap: 0.3rem;
		padding: 0.35rem 0.9rem;
		border-radius: 20px;
		border: 1px solid var(--color-light-line);
		background: white;
		font-size: 0.85rem;
		color: var(--color-soft-brown);
		white-space: nowrap;
		transition: background 0.15s, color 0.15s, border-color 0.15s;
	}
	.tab-btn:hover {
		background: var(--color-cream);
		border-color: var(--color-soft-brown);
	}
	.tab-btn.active {
		background: var(--color-terracotta);
		color: white;
		border-color: var(--color-terracotta);
		font-weight: 600;
	}
	.tab-count {
		font-size: 0.72rem;
		background: rgba(255,255,255,0.3);
		padding: 0.05rem 0.35rem;
		border-radius: 8px;
	}
	.tab-btn:not(.active) .tab-count {
		background: var(--color-light-line);
		color: var(--color-soft-brown);
	}

	/* 태그 탭: 활성 시 태그 색상 적용 */
	.tab-btn.tag-tab.active {
		background: color-mix(in srgb, var(--tag-color) 80%, transparent);
		border-color: var(--tag-color);
		color: white;
	}

	/* 카드 그리드 */
	.recipe-grid {
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(220px, 1fr));
		gap: 1.2rem;
		padding-bottom: 3rem;
	}

	.status-area {
		text-align: center;
		padding: 5rem 0;
		color: var(--color-soft-brown);
	}
	.status-area.error p:first-child {
		font-weight: 600;
		color: var(--color-muted-red);
		margin-bottom: 0.3rem;
	}
	.detail { font-size: 0.9rem; }

	.empty-book {
		text-align: center;
		padding: 6rem 0;
		color: var(--color-soft-brown);
	}
	.empty-book h2 {
		font-size: 1.3rem;
		margin-bottom: 0.8rem;
		color: var(--color-warm-brown);
	}
	.empty-book p {
		line-height: 1.7;
		margin-bottom: 1.5rem;
	}
	.cta-btn {
		display: inline-block;
		background: var(--color-terracotta);
		color: white;
		padding: 0.8rem 2rem;
		border-radius: 10px;
		font-weight: 600;
		text-decoration: none;
	}
	.cta-btn:hover {
		background: #b5633f;
		color: white;
	}

	@media (max-width: 767px) {
		.page-wrap { padding: 0 var(--page-padding-mobile); }
		.library-header h1 { font-size: 1.5rem; }
		.recipe-grid {
			grid-template-columns: 1fr;
		}
	}
</style>
