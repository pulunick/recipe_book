<script lang="ts">
	import { onMount } from 'svelte';
	import { browser } from '$app/environment';
	import { goto } from '$app/navigation';
	import { getPublicRecipes, getRecipeCategories, saveToCollection, removeFromCollection, getRandomRecipe } from '$lib/api';
	import { isLoggedIn, openLoginModal } from '$lib/stores/auth.svelte';
	import FilterBottomSheet from '$lib/components/FilterBottomSheet.svelte';
	import type { RecipePublicItem } from '$lib/types';

	const loggedIn = $derived(isLoggedIn());

	const DIFFICULTY_LABEL: Record<string, string> = {
		easy: '쉬움', medium: '보통', hard: '어려움'
	};

	let categories = $state<string[]>([]);

	let selectedCategory = $state('전체');
	let selectedSource = $state('');
	let searchQuery = $state('');
	let searchInput = $state('');

	interface FilterState {
		sort: string;
		difficulty: string;
		cookingTime: string;
		calorieRange: string;
		hideCollected: boolean;
	}
	const FILTER_KEY = 'explore_filter';
	function loadFilter(): FilterState {
		if (!browser) return { sort: 'latest', difficulty: '', cookingTime: '', calorieRange: '', hideCollected: false };
		try {
			const saved = localStorage.getItem(FILTER_KEY);
			return saved ? JSON.parse(saved) : { sort: 'latest', difficulty: '', cookingTime: '', calorieRange: '', hideCollected: false };
		} catch { return { sort: 'latest', difficulty: '', cookingTime: '', calorieRange: '', hideCollected: false }; }
	}
	let filter = $state<FilterState>(loadFilter());
	let showFilterSheet = $state(false);
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
			// 조리시간/칼로리 필터 변환
			const maxTime = filter.cookingTime === '20' ? 20 : filter.cookingTime === '60' ? 60 : undefined;
			const minTime = filter.cookingTime === '61+' ? 60 : undefined;
			const maxCal = filter.calorieRange === 'low' ? 500 : filter.calorieRange === 'mid' ? 800 : undefined;
			const minCal = filter.calorieRange === 'mid' ? 500 : filter.calorieRange === 'high' ? 800 : undefined;

			const params: Record<string, string | number | boolean> = { page, limit: LIMIT, sort: filter.sort };
			if (selectedCategory !== '전체') params.category = selectedCategory;
			if (searchQuery) params.q = searchQuery;
			if (selectedSource) params.source = selectedSource;
			if (filter.difficulty) params.difficulty = filter.difficulty;
			if (maxTime != null) params.max_time = maxTime;
			if (minTime != null) params.min_time = minTime;
			if (minCal != null) params.min_calories = minCal;
			if (maxCal != null) params.max_calories = maxCal;
			if (filter.hideCollected) params.hide_collected = true;

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

	// 보관함 추가 중인 recipe id 추적
	let addingIds = $state<Set<number>>(new Set());

	async function handleCollect(e: MouseEvent, item: RecipePublicItem) {
		e.preventDefault();
		e.stopPropagation();

		if (!loggedIn) {
			openLoginModal();
			return;
		}
		if (addingIds.has(item.id)) return;

		addingIds = new Set([...addingIds, item.id]);
		try {
			if (item.my_collection_id !== null) {
				// 보관함 해제
				await removeFromCollection(item.my_collection_id);
				recipes = recipes.map(r => r.id === item.id ? { ...r, my_collection_id: null } : r);
			} else {
				// 보관함 추가
				const collectionId = await saveToCollection(item.id);
				recipes = recipes.map(r => r.id === item.id ? { ...r, my_collection_id: collectionId } : r);
			}
		} finally {
			addingIds = new Set([...addingIds].filter(id => id !== item.id));
		}
	}

	$effect(() => {
		if (browser) localStorage.setItem(FILTER_KEY, JSON.stringify(filter));
	});

	const activeFilterCount = $derived(
		(filter.difficulty ? 1 : 0) +
		(filter.cookingTime ? 1 : 0) +
		(filter.calorieRange ? 1 : 0) +
		(filter.hideCollected ? 1 : 0)
	);

	// 오늘 뭐먹지
	let randomRecipe = $state<RecipePublicItem | null>(null);
	let randomLoading = $state(false);
	let randomError = $state('');
	let showRandomModal = $state(false);

	const DIFFICULTY_LABEL_MAP: Record<string, string> = {
		easy: '쉬움', medium: '보통', hard: '어려움'
	};

	async function handleRandomRecipe() {
		randomLoading = true;
		randomError = '';
		try {
			randomRecipe = await getRandomRecipe(loggedIn);
			showRandomModal = true;
		} catch (e) {
			randomError = e instanceof Error ? e.message : '추천을 불러오지 못했어요.';
		} finally {
			randomLoading = false;
		}
	}

	async function handleRandomCollect() {
		if (!randomRecipe) return;
		if (!loggedIn) { openLoginModal(); return; }
		try {
			const collectionId = await saveToCollection(randomRecipe.id);
			randomRecipe = { ...randomRecipe, my_collection_id: collectionId };
			// 메인 목록도 갱신
			recipes = recipes.map(r => r.id === randomRecipe!.id ? { ...r, my_collection_id: collectionId } : r);
		} catch { /* 무시 */ }
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
	<!-- 검색바 + 필터 버튼 -->
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
		<button class="btn-filter" class:has-filter={activeFilterCount > 0} onclick={() => showFilterSheet = true}>
			⚙ 필터{activeFilterCount > 0 ? ` ${activeFilterCount}` : ''}
		</button>
	</div>

	<!-- 출처 필터 칩 -->
	<div class="source-chips">
		<button class="chip source-chip" class:active={selectedSource === ''} onclick={() => { selectedSource = ''; fetchRecipes(true); }}>전체</button>
		<button class="chip source-chip" class:active={selectedSource === 'youtube'} onclick={() => { selectedSource = 'youtube'; fetchRecipes(true); }}>▶ YouTube</button>
		<button class="chip source-chip" class:active={selectedSource === 'text'} onclick={() => { selectedSource = 'text'; fetchRecipes(true); }}>✏ 직접 작성</button>
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

	<!-- 활성 필터 뱃지 -->
	{#if activeFilterCount > 0}
		<div class="active-filters">
			{#if filter.difficulty}
				<button class="active-badge" onclick={() => { filter.difficulty = ''; fetchRecipes(true); }}>{filter.difficulty} ✕</button>
			{/if}
			{#if filter.cookingTime}
				{@const timeLabel = filter.cookingTime === '20' ? '20분 이하' : filter.cookingTime === '60' ? '1시간 이하' : '1시간 초과'}
				<button class="active-badge" onclick={() => { filter.cookingTime = ''; fetchRecipes(true); }}>{timeLabel} ✕</button>
			{/if}
			{#if filter.calorieRange}
				{@const calLabel = filter.calorieRange === 'low' ? '500kcal↓' : filter.calorieRange === 'mid' ? '500~800kcal' : '800kcal↑'}
				<button class="active-badge" onclick={() => { filter.calorieRange = ''; fetchRecipes(true); }}>{calLabel} ✕</button>
			{/if}
			{#if filter.hideCollected}
				<button class="active-badge" onclick={() => { filter.hideCollected = false; fetchRecipes(true); }}>저장 숨김 ✕</button>
			{/if}
		</div>
	{/if}

	{#if showFilterSheet}
		<FilterBottomSheet
			{filter}
			onapply={(f) => { filter = f; if (browser) localStorage.setItem(FILTER_KEY, JSON.stringify(f)); fetchRecipes(true); }}
			onclose={() => showFilterSheet = false}
		/>
	{/if}

	<!-- 오늘 뭐먹지 / 냉장고 파먹기 배너 (검색 중일 때 숨김) -->
	{#if !searchQuery && selectedCategory === '전체' && activeFilterCount === 0}
		<div class="random-banner">
			<div class="banner-text">
				<span class="banner-icon">🎲</span>
				<div>
					<p class="banner-title">오늘 뭐 먹지?</p>
					<p class="banner-desc">기분에 맞는 레시피를 뽑아드려요</p>
				</div>
			</div>
			<button
				class="btn-random"
				onclick={handleRandomRecipe}
				disabled={randomLoading}
			>
				{#if randomLoading}
					<span class="random-spinner"></span>
				{:else}
					추천받기
				{/if}
			</button>
		</div>

		<div class="fridge-banner">
			<div class="banner-text">
				<span class="banner-icon">🧊</span>
				<div>
					<p class="banner-title">냉장고 파먹기</p>
					<p class="banner-desc">있는 재료로 뭘 만들 수 있을까?</p>
				</div>
			</div>
			<button class="btn-fridge" onclick={() => goto('/fridge')}>
				시작하기
			</button>
		</div>
	{/if}

	<!-- 오늘 뭐먹지 결과 모달 -->
	{#if showRandomModal && randomRecipe}
		<div
			class="modal-overlay"
			role="button"
			tabindex="-1"
			aria-label="모달 닫기"
			onclick={() => (showRandomModal = false)}
			onkeydown={(e) => e.key === 'Escape' && (showRandomModal = false)}
		></div>
		<div class="random-modal" role="dialog" aria-modal="true" aria-label="오늘의 추천">
			<div class="modal-header">
				<p class="modal-title">🎲 오늘의 추천</p>
				<button class="modal-close" onclick={() => (showRandomModal = false)} aria-label="닫기">
					<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
						<line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/>
					</svg>
				</button>
			</div>

			<a href="/recipe/{randomRecipe.video_id ?? randomRecipe.id}" class="modal-recipe-link" onclick={() => (showRandomModal = false)}>
				<div class="modal-thumb">
					{#if randomRecipe.video_id}
						<img src="https://img.youtube.com/vi/{randomRecipe.video_id}/mqdefault.jpg" alt={randomRecipe.title} />
					{:else}
						<div class="thumb-placeholder-sm">
							<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
								<path d="M14.752 11.168l-3.197-2.132A1 1 0 0 0 10 9.87v4.263a1 1 0 0 0 1.555.832l3.197-2.132a1 1 0 0 0 0-1.664z"/>
								<path d="M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0z"/>
							</svg>
						</div>
					{/if}
				</div>
				<div class="modal-recipe-info">
					<p class="modal-recipe-title">{randomRecipe.title}</p>
					<div class="modal-meta">
						{#if randomRecipe.cooking_time}
							<span class="modal-chip">
								<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>
								{randomRecipe.cooking_time}
							</span>
						{/if}
						{#if randomRecipe.difficulty}
							<span class="modal-chip">{DIFFICULTY_LABEL_MAP[randomRecipe.difficulty] ?? randomRecipe.difficulty}</span>
						{/if}
						{#if randomRecipe.calories}
							<span class="modal-chip calories">🔥 {randomRecipe.calories}kcal</span>
						{/if}
					</div>
					{#if randomRecipe.channel_name}
						<p class="modal-channel">{randomRecipe.channel_name}</p>
					{/if}
				</div>
			</a>

			<div class="modal-actions">
				<button class="btn-reroll" onclick={handleRandomRecipe} disabled={randomLoading}>
					{#if randomLoading}<span class="random-spinner sm"></span>{:else}다시 뽑기{/if}
				</button>
				{#if randomRecipe.my_collection_id !== null}
					<a href="/my-recipes/{randomRecipe.my_collection_id}" class="btn-collected">
						내 레시피 보러가기
					</a>
				{:else}
					<button class="btn-collect-random" onclick={handleRandomCollect}>
						내 레시피에 추가
					</button>
				{/if}
			</div>
		</div>
	{/if}

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
				{@const added = item.my_collection_id !== null}
				{@const adding = addingIds.has(item.id)}
				<article class="recipe-card">
					<a href="/recipe/{item.video_id ?? item.id}" class="card-link">
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
								{#if item.calories}
									<span class="meta-chip calories-chip">🔥 {item.calories}kcal</span>
								{/if}
							</div>
							{#if item.channel_name}
								<p class="card-channel">
									{#if item.source === "youtube"}<span class="source-icon yt">▶</span>{/if}
									{item.channel_name}
								</p>
							{:else if item.source === "text"}
								<p class="card-channel"><span class="source-icon txt">✏</span> 직접 작성</p>
							{/if}
						</div>
					</a>

					<!-- 보관함 추가/해제 버튼 -->
					<button
						class="btn-collect"
						class:is-added={added}
						onclick={(e) => handleCollect(e, item)}
						disabled={adding}
						aria-label={added ? '보관함 해제' : '내 레시피에 추가'}
						title={added ? '보관함 해제' : '내 레시피에 추가'}
					>
						{#if adding}
							<span class="collect-spinner"></span>
						{:else if added}
							<!-- 채워진 북마크 (보관 중) -->
							<svg viewBox="0 0 24 24" fill="currentColor" stroke="currentColor" stroke-width="2">
								<path d="M19 21l-7-5-7 5V5a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2z" />
							</svg>
						{:else}
							<!-- 빈 북마크 (미보관) -->
							<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
								<path d="M19 21l-7-5-7 5V5a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2z" />
							</svg>
						{/if}
					</button>
				</article>
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
		display: flex;
		align-items: center;
		gap: 8px;
	}

	.btn-filter {
		flex-shrink: 0;
		height: 44px;
		padding: 0 1rem;
		border: 1.5px solid var(--color-light-line);
		border-radius: 14px;
		background: none;
		color: var(--color-soft-brown);
		font-size: 0.82rem;
		font-weight: 600;
		cursor: pointer;
		font-family: inherit;
		white-space: nowrap;
		transition: border-color 0.15s, color 0.15s, background 0.15s;
	}
	.btn-filter.has-filter {
		border-color: var(--color-terracotta);
		color: var(--color-terracotta);
		background: color-mix(in srgb, var(--color-terracotta) 8%, white);
	}

	.active-filters {
		display: flex;
		flex-wrap: wrap;
		gap: 0.4rem;
		padding: 0 16px 8px;
	}
	.active-badge {
		font-size: 0.75rem;
		font-weight: 600;
		padding: 0.2rem 0.65rem;
		border-radius: 20px;
		border: 1.5px solid var(--color-terracotta);
		color: var(--color-terracotta);
		background: color-mix(in srgb, var(--color-terracotta) 8%, white);
		cursor: pointer;
		font-family: inherit;
	}

	.search-bar {
		flex: 1;
		display: flex;
		align-items: center;
		gap: 8px;
		background: var(--color-cream);
		border: 1.5px solid var(--color-light-line);
		border-radius: 14px;
		padding: 0 14px;
		height: 44px;
		transition: border-color 0.15s;
		min-width: 0;
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
	.source-chips {
		display: flex;
		gap: 8px;
		padding: 0 16px 0;
		margin-bottom: 6px;
		overflow-x: auto;
		scrollbar-width: none;
	}
	.source-chips::-webkit-scrollbar {
		display: none;
	}
	.source-chip { font-size: 0.78rem; }

	.source-icon {
		font-size: 0.7rem;
		margin-right: 2px;
	}
	.source-icon.yt { color: #f00; }
	.source-icon.txt { color: var(--color-terracotta); }

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

	/* 냉장고 파먹기 배너 */
	.fridge-banner {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 12px;
		margin: 0 16px 14px;
		padding: 14px 16px;
		background: linear-gradient(135deg,
			color-mix(in srgb, var(--color-terracotta) 12%, white),
			color-mix(in srgb, var(--color-warm-yellow) 30%, white)
		);
		border: 1.5px solid color-mix(in srgb, var(--color-terracotta) 20%, white);
		border-radius: 16px;
	}

	.btn-fridge {
		flex-shrink: 0;
		padding: 8px 16px;
		background: var(--color-terracotta);
		color: #fff;
		border: none;
		border-radius: 10px;
		font-size: 0.82rem;
		font-weight: 600;
		font-family: inherit;
		cursor: pointer;
		display: flex;
		align-items: center;
		gap: 6px;
		transition: background 0.15s, opacity 0.15s;
	}
	.btn-fridge:hover { background: #b5633f; }

	/* 오늘 뭐먹지 배너 */
	.random-banner {
		margin: 0 16px 14px;
		padding: 14px 16px;
		background: linear-gradient(135deg,
			color-mix(in srgb, var(--color-terracotta) 12%, white),
			color-mix(in srgb, var(--color-warm-yellow) 30%, white)
		);
		border: 1.5px solid color-mix(in srgb, var(--color-terracotta) 20%, white);
		border-radius: 16px;
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 12px;
	}

	.banner-text {
		display: flex;
		align-items: center;
		gap: 10px;
		min-width: 0;
	}

	.banner-icon {
		font-size: 1.6rem;
		flex-shrink: 0;
		line-height: 1;
	}

	.banner-title {
		font-size: 0.92rem;
		font-weight: 700;
		color: var(--color-warm-brown);
		line-height: 1.2;
	}

	.banner-desc {
		font-size: 0.75rem;
		color: var(--color-soft-brown);
		margin-top: 2px;
	}

	.btn-random {
		flex-shrink: 0;
		padding: 8px 16px;
		background: var(--color-terracotta);
		color: #fff;
		border: none;
		border-radius: 10px;
		font-size: 0.82rem;
		font-weight: 600;
		font-family: inherit;
		cursor: pointer;
		display: flex;
		align-items: center;
		gap: 6px;
		transition: background 0.15s, opacity 0.15s;
	}

	.btn-random:hover:not(:disabled) { background: #b5633f; }
	.btn-random:disabled { opacity: 0.6; cursor: not-allowed; }

	.random-spinner {
		width: 14px;
		height: 14px;
		border: 2px solid rgba(255,255,255,0.4);
		border-top-color: #fff;
		border-radius: 50%;
		animation: spin 0.7s linear infinite;
		flex-shrink: 0;
	}

	.random-spinner.sm {
		width: 12px;
		height: 12px;
	}

	/* 오늘 뭐먹지 모달 */
	.modal-overlay {
		position: fixed;
		inset: 0;
		background: rgba(0,0,0,0.45);
		z-index: 60;
		animation: fade-in 0.18s ease;
	}

	@keyframes fade-in {
		from { opacity: 0; }
		to { opacity: 1; }
	}

	.random-modal {
		position: fixed;
		bottom: 0;
		left: 50%;
		transform: translateX(-50%);
		width: calc(100% - 0px);
		max-width: 480px;
		background: var(--color-paper);
		border-radius: 20px 20px 0 0;
		z-index: 61;
		padding: 0 0 calc(16px + env(safe-area-inset-bottom));
		animation: slide-up 0.22s cubic-bezier(0.32, 0.72, 0, 1);
		overflow: hidden;
	}

	@keyframes slide-up {
		from { transform: translateX(-50%) translateY(100%); }
		to { transform: translateX(-50%) translateY(0); }
	}

	.modal-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 16px 16px 12px;
		border-bottom: 1px solid var(--color-light-line);
	}

	.modal-title {
		font-size: 1rem;
		font-weight: 700;
		color: var(--color-warm-brown);
	}

	.modal-close {
		width: 30px;
		height: 30px;
		border: none;
		background: none;
		color: var(--color-soft-brown);
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		border-radius: 50%;
		padding: 0;
		transition: background 0.15s;
	}

	.modal-close:hover { background: var(--color-cream); }
	.modal-close svg { width: 16px; height: 16px; }

	.modal-recipe-link {
		display: block;
		text-decoration: none;
		padding: 14px 16px;
	}

	.modal-thumb {
		width: 100%;
		aspect-ratio: 16/9;
		border-radius: 12px;
		overflow: hidden;
		background: var(--color-cream);
		margin-bottom: 12px;
	}

	.modal-thumb img {
		width: 100%;
		height: 100%;
		object-fit: cover;
	}

	.thumb-placeholder-sm {
		width: 100%;
		height: 100%;
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.thumb-placeholder-sm svg {
		width: 40px;
		height: 40px;
		color: var(--color-light-line);
	}

	.modal-recipe-info {
		display: flex;
		flex-direction: column;
		gap: 6px;
	}

	.modal-recipe-title {
		font-size: 1rem;
		font-weight: 700;
		color: var(--color-warm-brown);
		line-height: 1.3;
	}

	.modal-meta {
		display: flex;
		flex-wrap: wrap;
		gap: 5px;
	}

	.modal-chip {
		display: flex;
		align-items: center;
		gap: 3px;
		font-size: 0.75rem;
		color: var(--color-soft-brown);
		background: var(--color-cream);
		padding: 3px 8px;
		border-radius: 6px;
	}

	.modal-chip svg { width: 11px; height: 11px; }
	.modal-chip.calories { color: #b84c00; background: #fff0e6; font-weight: 600; }

	.modal-channel {
		font-size: 0.78rem;
		color: var(--color-soft-brown);
		opacity: 0.75;
	}

	.modal-actions {
		display: flex;
		gap: 10px;
		padding: 0 16px;
	}

	.btn-reroll {
		flex: 1;
		padding: 12px;
		background: none;
		border: 1.5px solid var(--color-light-line);
		border-radius: 12px;
		font-size: 0.9rem;
		font-weight: 600;
		color: var(--color-soft-brown);
		font-family: inherit;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 6px;
		transition: border-color 0.15s, color 0.15s;
	}

	.btn-reroll:hover:not(:disabled) {
		border-color: var(--color-terracotta);
		color: var(--color-terracotta);
	}

	.btn-reroll:disabled { opacity: 0.6; cursor: not-allowed; }

	.btn-collect-random {
		flex: 1;
		padding: 12px;
		background: var(--color-terracotta);
		border: none;
		border-radius: 12px;
		font-size: 0.9rem;
		font-weight: 600;
		color: #fff;
		font-family: inherit;
		cursor: pointer;
		transition: background 0.15s;
	}

	.btn-collect-random:hover { background: #b5633f; }

	.btn-collected {
		flex: 1;
		padding: 12px;
		background: var(--color-sage);
		border: none;
		border-radius: 12px;
		font-size: 0.9rem;
		font-weight: 600;
		color: #fff;
		text-decoration: none;
		text-align: center;
		display: block;
		transition: background 0.15s;
	}

	.btn-collected:hover { background: color-mix(in srgb, var(--color-sage) 85%, black); color: #fff; }

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
		position: relative;
		display: flex;
		flex-direction: column;
		border-radius: 14px;
		overflow: hidden;
		background: #fff;
		border: 1px solid var(--color-light-line);
		transition: box-shadow 0.15s, transform 0.15s;
	}

	.recipe-card:hover {
		box-shadow: 0 4px 16px rgba(0, 0, 0, 0.08);
		transform: translateY(-1px);
	}

	.card-link {
		display: flex;
		flex-direction: column;
		text-decoration: none;
		flex: 1;
	}

	/* 보관함 버튼 */
	.btn-collect {
		position: absolute;
		top: 6px;
		right: 6px;
		width: 30px;
		height: 30px;
		border-radius: 50%;
		border: none;
		background: rgba(255, 255, 255, 0.88);
		backdrop-filter: blur(4px);
		color: var(--color-soft-brown);
		display: flex;
		align-items: center;
		justify-content: center;
		cursor: pointer;
		padding: 0;
		transition: background 0.15s, color 0.15s, transform 0.15s;
		box-shadow: 0 1px 4px rgba(0,0,0,0.15);
	}
	.btn-collect svg { width: 15px; height: 15px; }
	.btn-collect:hover:not(:disabled) {
		background: white;
		color: var(--color-terracotta);
		transform: scale(1.1);
	}
	.btn-collect.is-added {
		background: var(--color-terracotta);
		color: white;
	}
	.btn-collect.is-added:hover:not(:disabled) {
		background: color-mix(in srgb, var(--color-terracotta) 85%, black);
		color: white;
	}
	.btn-collect:disabled { opacity: 0.6; cursor: not-allowed; }

	.collect-spinner {
		width: 13px;
		height: 13px;
		border: 2px solid rgba(0,0,0,0.15);
		border-top-color: var(--color-terracotta);
		border-radius: 50%;
		animation: spin 0.7s linear infinite;
		flex-shrink: 0;
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
	.meta-chip.calories-chip { color: #b84c00; background: #fff0e6; font-weight: 600; }

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
