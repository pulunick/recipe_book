<script lang="ts">
	import { onMount } from 'svelte';
	import { getPublicRecipes, getRecipeCategories } from '$lib/api';
	import type { RecipePublicItem } from '$lib/types';

	const DIFFICULTY_LABEL: Record<string, string> = {
		easy: '쉬움', medium: '보통', hard: '어려움'
	};

	let categories = $state<string[]>([]);

	let selectedCategory = $state('전체');
	let searchQuery = $state('');
	let searchInput = $state('');
	let recipes = $state<RecipePublicItem[]>([]);
	let loading = $state(true);
	let error = $state('');
	let page = $state(1);
	let hasMore = $state(true);
	let loadingMore = $state(false);

	const LIMIT = 20;

	async function fetchRecipes(reset = false) {
		if (reset) {
			page = 1;
			recipes = [];
			hasMore = true;
			loading = true;
			error = '';
		}
		try {
			const params: Record<string, string | number> = { page, limit: LIMIT };
			if (selectedCategory !== '전체') params.category = selectedCategory;
			if (searchQuery) params.q = searchQuery;

			const data = await getPublicRecipes(params);
			if (reset) {
				recipes = data;
			} else {
				recipes = [...recipes, ...data];
			}
			hasMore = data.length === LIMIT;
		} catch (e: unknown) {
			error = e instanceof Error ? e.message : '레시피를 불러오지 못했습니다.';
		} finally {
			loading = false;
			loadingMore = false;
		}
	}

	async function loadMore() {
		if (loadingMore || !hasMore) return;
		loadingMore = true;
		page += 1;
		await fetchRecipes(false);
	}

	function handleCategoryChange(cat: string) {
		selectedCategory = cat;
		fetchRecipes(true);
	}

	function handleSearchSubmit() {
		searchQuery = searchInput.trim();
		fetchRecipes(true);
	}

	function handleSearchKeydown(e: KeyboardEvent) {
		if (e.key === 'Enter') handleSearchSubmit();
	}

	function clearSearch() {
		searchInput = '';
		searchQuery = '';
		fetchRecipes(true);
	}

	// 썸네일 URL (video_id 있으면 유튜브 썸네일)
	function getThumbnail(item: RecipePublicItem): string | null {
		if (item.video_id) return `https://img.youtube.com/vi/${item.video_id}/mqdefault.jpg`;
		return null;
	}

	onMount(async () => {
		const [_, cats] = await Promise.all([
			fetchRecipes(true),
			getRecipeCategories().catch(() => [])
		]);
		categories = cats;
	});
</script>

<svelte:head>
	<title>해먹당 — 탐색</title>
</svelte:head>

<div class="explore-page">
	<!-- 검색바 -->
	<div class="search-bar-wrap">
		<div class="search-bar">
			<svg class="search-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
				<circle cx="11" cy="11" r="8" />
				<line x1="21" y1="21" x2="16.65" y2="16.65" />
			</svg>
			<input
				type="text"
				placeholder="레시피 또는 재료 검색..."
				class="search-input"
				bind:value={searchInput}
				onkeydown={handleSearchKeydown}
			/>
			{#if searchInput}
				<button class="clear-btn" aria-label="검색어 지우기" onclick={clearSearch}>
					<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
						<line x1="18" y1="6" x2="6" y2="18" /><line x1="6" y1="6" x2="18" y2="18" />
					</svg>
				</button>
			{/if}
		</div>
	</div>

	<!-- 카테고리 칩 -->
	<div class="category-chips">
		<button
			class="chip"
			class:active={selectedCategory === '전체'}
			onclick={() => handleCategoryChange('전체')}
		>전체</button>
		{#each categories as cat}
			<button
				class="chip"
				class:active={selectedCategory === cat}
				onclick={() => handleCategoryChange(cat)}
			>
				{cat}
			</button>
		{/each}
	</div>

	<!-- 검색 결과 레이블 -->
	{#if searchQuery}
		<p class="result-label">
			<span class="result-keyword">"{searchQuery}"</span> 검색 결과
			{#if !loading}
				<span class="result-count">({recipes.length}개)</span>
			{/if}
		</p>
	{/if}

	<!-- 로딩 -->
	{#if loading}
		<div class="skeleton-grid">
			{#each Array(6) as _}
				<div class="skeleton-card">
					<div class="skeleton-thumb"></div>
					<div class="skeleton-body">
						<div class="skeleton-line wide"></div>
						<div class="skeleton-line short"></div>
					</div>
				</div>
			{/each}
		</div>

	<!-- 에러 -->
	{:else if error}
		<div class="error-state">
			<p>{error}</p>
			<button class="retry-btn" onclick={() => fetchRecipes(true)}>다시 시도</button>
		</div>

	<!-- 결과 없음 -->
	{:else if recipes.length === 0}
		<div class="empty-state">
			<div class="empty-icon">
				<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
					<circle cx="11" cy="11" r="8" /><line x1="21" y1="21" x2="16.65" y2="16.65" />
				</svg>
			</div>
			<p class="empty-title">레시피가 없어요</p>
			<p class="empty-desc">
				{searchQuery ? '다른 검색어를 입력해보세요.' : '아래 [+] 버튼으로 첫 레시피를 추가해보세요.'}
			</p>
		</div>

	<!-- 카드 그리드 -->
	{:else}
		<div class="recipe-grid">
			{#each recipes as item (item.id)}
				<a href="/recipe/{item.video_id ?? item.id}" class="recipe-card">
					<div class="card-thumb">
						{#if getThumbnail(item)}
							<img src={getThumbnail(item)!} alt={item.title} loading="lazy" />
						{:else}
							<div class="thumb-placeholder">
								<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
									<path d="M14.752 11.168l-3.197-2.132A1 1 0 0 0 10 9.87v4.263a1 1 0 0 0 1.555.832l3.197-2.132a1 1 0 0 0 0-1.664z"/>
									<path d="M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0z"/>
								</svg>
							</div>
						{/if}
						{#if item.category}
							<span class="category-badge">{item.category}</span>
						{/if}
					</div>
					<div class="card-body">
						<p class="card-title">{item.title}</p>
						<div class="card-meta">
							{#if item.cooking_time}
								<span class="meta-chip">
									<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
										<circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/>
									</svg>
									{item.cooking_time}
								</span>
							{/if}
							{#if item.difficulty}
								<span class="meta-chip">{DIFFICULTY_LABEL[item.difficulty] ?? item.difficulty}</span>
							{/if}
						</div>
						{#if item.channel_name}
							<p class="card-channel">{item.channel_name}</p>
						{/if}
					</div>
				</a>
			{/each}
		</div>

		<!-- 더 보기 버튼 -->
		{#if hasMore}
			<div class="load-more-wrap">
				<button class="load-more-btn" onclick={loadMore} disabled={loadingMore}>
					{#if loadingMore}
						<span class="btn-spinner"></span>
						불러오는 중...
					{:else}
						더 보기
					{/if}
				</button>
			</div>
		{/if}
	{/if}
</div>

<style>
	.explore-page {
		padding: 12px 0 8px;
	}

	/* 검색바 */
	.search-bar-wrap {
		padding: 0 16px;
		margin-bottom: 12px;
	}

	.search-bar {
		display: flex;
		align-items: center;
		gap: 8px;
		background: var(--color-cream);
		border: 1.5px solid var(--color-light-line);
		border-radius: 14px;
		padding: 10px 14px;
		transition: border-color 0.15s;
	}

	.search-bar:focus-within {
		border-color: var(--color-terracotta);
	}

	.search-icon {
		width: 17px;
		height: 17px;
		color: var(--color-soft-brown);
		flex-shrink: 0;
	}

	.search-input {
		flex: 1;
		background: none;
		border: none;
		outline: none;
		font-size: 0.92rem;
		color: var(--color-warm-brown);
		font-family: inherit;
		min-width: 0;
	}

	.search-input::placeholder {
		color: var(--color-soft-brown);
		opacity: 0.65;
	}

	.clear-btn {
		background: none;
		border: none;
		padding: 2px;
		cursor: pointer;
		color: var(--color-soft-brown);
		display: flex;
		align-items: center;
		flex-shrink: 0;
	}

	.clear-btn svg {
		width: 16px;
		height: 16px;
	}

	/* 카테고리 칩 */
	.category-chips {
		display: flex;
		gap: 8px;
		padding: 0 16px;
		overflow-x: auto;
		scrollbar-width: none;
		margin-bottom: 14px;
	}

	.category-chips::-webkit-scrollbar {
		display: none;
	}

	.chip {
		flex-shrink: 0;
		padding: 6px 14px;
		border-radius: 20px;
		border: 1.5px solid var(--color-light-line);
		background: #fff;
		color: var(--color-soft-brown);
		font-size: 0.82rem;
		font-weight: 500;
		font-family: inherit;
		cursor: pointer;
		transition: background 0.15s, border-color 0.15s, color 0.15s;
	}

	.chip.active {
		background: var(--color-terracotta);
		border-color: var(--color-terracotta);
		color: #fff;
	}

	/* 검색 결과 레이블 */
	.result-label {
		padding: 0 16px;
		font-size: 0.82rem;
		color: var(--color-soft-brown);
		margin-bottom: 10px;
	}

	.result-keyword {
		font-weight: 600;
		color: var(--color-warm-brown);
	}

	.result-count {
		color: var(--color-terracotta);
		font-weight: 600;
	}

	/* 스켈레톤 로딩 */
	.skeleton-grid {
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(180px, 1fr));
		gap: 12px;
		padding: 0 16px;
	}

	.skeleton-card {
		border-radius: 14px;
		overflow: hidden;
		background: var(--color-cream);
	}

	.skeleton-thumb {
		width: 100%;
		aspect-ratio: 16/9;
		background: var(--color-light-line);
		animation: shimmer 1.4s ease infinite;
	}

	.skeleton-body {
		padding: 10px;
		display: flex;
		flex-direction: column;
		gap: 6px;
	}

	.skeleton-line {
		height: 12px;
		border-radius: 6px;
		background: var(--color-light-line);
		animation: shimmer 1.4s ease infinite;
	}

	.skeleton-line.wide { width: 85%; }
	.skeleton-line.short { width: 50%; }

	@keyframes shimmer {
		0%, 100% { opacity: 1; }
		50% { opacity: 0.5; }
	}

	/* 에러 */
	.error-state {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 12px;
		padding: 48px 24px;
		text-align: center;
		font-size: 0.875rem;
		color: var(--color-soft-brown);
	}

	.retry-btn {
		padding: 8px 20px;
		background: var(--color-terracotta);
		color: #fff;
		border: none;
		border-radius: 10px;
		font-size: 0.875rem;
		font-family: inherit;
		cursor: pointer;
	}

	/* 빈 상태 */
	.empty-state {
		display: flex;
		flex-direction: column;
		align-items: center;
		padding: 56px 24px;
		text-align: center;
		gap: 10px;
	}

	.empty-icon {
		width: 56px;
		height: 56px;
		color: var(--color-light-line);
	}

	.empty-icon svg {
		width: 100%;
		height: 100%;
	}

	.empty-title {
		font-size: 1rem;
		font-weight: 600;
		color: var(--color-warm-brown);
	}

	.empty-desc {
		font-size: 0.85rem;
		color: var(--color-soft-brown);
		line-height: 1.6;
	}

	/* 레시피 그리드 */
	.recipe-grid {
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(180px, 1fr));
		gap: 12px;
		padding: 0 16px;
	}

	.recipe-card {
		display: flex;
		flex-direction: column;
		border-radius: 14px;
		overflow: hidden;
		background: #fff;
		border: 1px solid var(--color-light-line);
		text-decoration: none;
		transition: box-shadow 0.15s, transform 0.15s;
	}

	.recipe-card:hover {
		box-shadow: 0 4px 16px rgba(0, 0, 0, 0.08);
		transform: translateY(-1px);
	}

	.card-thumb {
		position: relative;
		width: 100%;
		aspect-ratio: 16/9;
		overflow: hidden;
		background: var(--color-cream);
	}

	.card-thumb img {
		width: 100%;
		height: 100%;
		object-fit: cover;
	}

	.thumb-placeholder {
		width: 100%;
		height: 100%;
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.thumb-placeholder svg {
		width: 32px;
		height: 32px;
		color: var(--color-light-line);
	}

	.category-badge {
		position: absolute;
		bottom: 6px;
		left: 6px;
		background: rgba(0, 0, 0, 0.55);
		color: #fff;
		font-size: 0.68rem;
		font-weight: 600;
		padding: 2px 7px;
		border-radius: 6px;
		backdrop-filter: blur(4px);
	}

	.card-body {
		padding: 10px;
		display: flex;
		flex-direction: column;
		gap: 5px;
	}

	.card-title {
		font-size: 0.85rem;
		font-weight: 600;
		color: var(--color-warm-brown);
		line-height: 1.35;
		/* 2줄 말줄임 */
		display: -webkit-box;
		-webkit-line-clamp: 2;
		line-clamp: 2;
		-webkit-box-orient: vertical;
		overflow: hidden;
	}

	.card-meta {
		display: flex;
		flex-wrap: wrap;
		gap: 4px;
	}

	.meta-chip {
		display: flex;
		align-items: center;
		gap: 3px;
		font-size: 0.7rem;
		color: var(--color-soft-brown);
		background: var(--color-paper);
		padding: 2px 6px;
		border-radius: 5px;
	}

	.meta-chip svg {
		width: 11px;
		height: 11px;
	}

	.card-channel {
		font-size: 0.72rem;
		color: var(--color-soft-brown);
		opacity: 0.75;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	/* 더 보기 */
	.load-more-wrap {
		display: flex;
		justify-content: center;
		padding: 20px 16px 8px;
	}

	.load-more-btn {
		display: flex;
		align-items: center;
		gap: 8px;
		padding: 10px 28px;
		background: none;
		border: 1.5px solid var(--color-light-line);
		border-radius: 10px;
		font-size: 0.875rem;
		font-weight: 500;
		color: var(--color-soft-brown);
		font-family: inherit;
		cursor: pointer;
		transition: border-color 0.15s, color 0.15s;
	}

	.load-more-btn:hover:not(:disabled) {
		border-color: var(--color-terracotta);
		color: var(--color-terracotta);
	}

	.load-more-btn:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}

	.btn-spinner {
		width: 14px;
		height: 14px;
		border: 2px solid var(--color-light-line);
		border-top-color: var(--color-terracotta);
		border-radius: 50%;
		animation: spin 0.7s linear infinite;
		flex-shrink: 0;
	}

	@keyframes spin {
		to { transform: rotate(360deg); }
	}
</style>
