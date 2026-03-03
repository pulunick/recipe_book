<script lang="ts">
	import { onMount } from 'svelte';
	import { fade } from 'svelte/transition';
	import type { CollectionItem, CollectionTag } from '$lib/types';
	import {
		getCollections,
		getTags,
		createTag,
		toggleFavorite,
		setRating,
		setCollectionTags
	} from '$lib/api';
	import RecipeCard from '$lib/components/RecipeCard.svelte';

	/* ── 목업 데이터 (백엔드 연동 전) ── */
	const MOCK_COLLECTIONS: CollectionItem[] = [
		{
			id: 1,
			recipe: { id: 1, title: '된장찌개 황금 레시피', summary: '구수하고 깊은 맛', ingredients: [], steps: [], flavor: { saltiness: 4, sweetness: 1, spiciness: 2, sourness: 1, oiliness: 2 }, tip: null, category: '한식', video_url: null, video_id: 'dQw4w9WgXcQ' },
			custom_tip: '된장 조금 덜 넣는 게 맛있음',
			created_at: '2025-12-01T09:00:00Z',
			is_favorite: true,
			my_rating: 4,
			cooked_count: 5,
			last_cooked_at: '2025-12-20T18:00:00Z',
			category_override: null,
			tags: [{ id: 1, name: '손님초대', color: '#34a853' }, { id: 2, name: '주말요리', color: '#4285f4' }]
		},
		{
			id: 2,
			recipe: { id: 2, title: '간단 파스타 10분 완성', summary: '바쁜 날을 위한 빠른 파스타', ingredients: [], steps: [], flavor: { saltiness: 3, sweetness: 2, spiciness: 1, sourness: 3, oiliness: 4 }, tip: null, category: '양식', video_url: null, video_id: 'abc1234abcd' },
			custom_tip: null,
			created_at: '2025-11-15T12:00:00Z',
			is_favorite: false,
			my_rating: 3,
			cooked_count: 2,
			last_cooked_at: '2025-11-20T19:00:00Z',
			category_override: null,
			tags: [{ id: 3, name: '10분요리', color: '#fbbc04' }]
		},
		{
			id: 3,
			recipe: { id: 3, title: '떡볶이 매운맛 버전', summary: '진짜 매운 떡볶이', ingredients: [], steps: [], flavor: { saltiness: 3, sweetness: 4, spiciness: 5, sourness: 1, oiliness: 2 }, tip: null, category: '분식', video_url: null, video_id: 'xyz9876xyzw' },
			custom_tip: '물 조금 더 추가',
			created_at: '2025-10-05T14:00:00Z',
			is_favorite: true,
			my_rating: 5,
			cooked_count: 8,
			last_cooked_at: '2025-12-25T18:30:00Z',
			category_override: null,
			tags: [{ id: 2, name: '주말요리', color: '#4285f4' }]
		},
		{
			id: 4,
			recipe: { id: 4, title: '오이 무침 다이어트 반찬', summary: '상큼하고 칼로리 낮은 반찬', ingredients: [], steps: [], flavor: { saltiness: 2, sweetness: 2, spiciness: 2, sourness: 4, oiliness: 1 }, tip: null, category: '한식', video_url: null, video_id: 'mnb3210mnba' },
			custom_tip: null,
			created_at: '2025-09-12T10:00:00Z',
			is_favorite: false,
			my_rating: null,
			cooked_count: 1,
			last_cooked_at: null,
			category_override: null,
			tags: [{ id: 4, name: '다이어트', color: '#f28b82' }]
		}
	];

	const MOCK_TAGS: CollectionTag[] = [
		{ id: 1, name: '손님초대', color: '#34a853' },
		{ id: 2, name: '주말요리', color: '#4285f4' },
		{ id: 3, name: '10분요리', color: '#fbbc04' },
		{ id: 4, name: '다이어트', color: '#f28b82' }
	];

	/* ── 상태 ── */
	let collections: CollectionItem[] = $state([]);
	let allTags: CollectionTag[] = $state([]);
	let loading = $state(true);
	let error = $state('');
	let searchQuery = $state('');
	let selectedFilter = $state<'all' | 'favorites' | string>('all');
	let selectedTagId = $state<number | null>(null);
	let useMock = $state(false);

	/* ── 마운트 시 실제 API 호출, 실패 시 목업 폴백 ── */
	onMount(async () => {
		try {
			const [cols, tags] = await Promise.all([getCollections(), getTags()]);
			collections = cols;
			allTags = tags;
		} catch {
			// 백엔드 연결 실패 시 목업으로 폴백
			collections = MOCK_COLLECTIONS;
			allTags = MOCK_TAGS;
			useMock = true;
		} finally {
			loading = false;
		}
	});

	/* ── 파생 상태 ── */
	const categories = $derived.by(() => {
		const cats = collections
			.map(c => c.category_override ?? c.recipe.category)
			.filter((c): c is string => Boolean(c));
		return Array.from(new Set(cats));
	});

	const filteredCollections = $derived.by(() => {
		let result = collections;

		// 검색
		if (searchQuery.trim()) {
			const q = searchQuery.trim().toLowerCase();
			result = result.filter(c => c.recipe.title.toLowerCase().includes(q));
		}

		// 필터 (전체 / 즐겨찾기 / 카테고리)
		if (selectedFilter === 'favorites') {
			result = result.filter(c => c.is_favorite);
		} else if (selectedFilter !== 'all') {
			result = result.filter(c => (c.category_override ?? c.recipe.category) === selectedFilter);
		}

		// 태그 필터
		if (selectedTagId !== null) {
			result = result.filter(c => c.tags.some(t => t.id === selectedTagId));
		}

		return result;
	});

	const favoriteCount = $derived(collections.filter(c => c.is_favorite).length);

	/* ── 이벤트 핸들러 ── */
	async function handleFavorite(id: number) {
		collections = collections.map(c =>
			c.id === id ? { ...c, is_favorite: !c.is_favorite } : c
		);
		if (!useMock) {
			try { await toggleFavorite(id); }
			catch { /* 실패 시 롤백 */ collections = collections.map(c => c.id === id ? { ...c, is_favorite: !c.is_favorite } : c); }
		}
	}

	async function handleRate(collectionId: number, rating: number) {
		collections = collections.map(c =>
			c.id === collectionId ? { ...c, my_rating: rating } : c
		);
		if (!useMock) {
			try { await setRating(collectionId, rating); } catch { /* 무시 */ }
		}
	}

	async function handleTagAttach(collectionId: number, tagId: number) {
		const tag = allTags.find(t => t.id === tagId);
		if (!tag) return;
		collections = collections.map(c => {
			if (c.id !== collectionId || c.tags.some(t => t.id === tagId)) return c;
			return { ...c, tags: [...c.tags, tag] };
		});
		if (!useMock) {
			const item = collections.find(c => c.id === collectionId);
			if (item) await setCollectionTags(collectionId, item.tags.map(t => t.id)).catch(() => {});
		}
	}

	async function handleTagDetach(collectionId: number, tagId: number) {
		collections = collections.map(c => {
			if (c.id !== collectionId) return c;
			return { ...c, tags: c.tags.filter(t => t.id !== tagId) };
		});
		if (!useMock) {
			const item = collections.find(c => c.id === collectionId);
			if (item) await setCollectionTags(collectionId, item.tags.map(t => t.id)).catch(() => {});
		}
	}

	async function handleTagCreate(collectionId: number, name: string, color: string) {
		// 태그 생성 후 부착
		let newTag: CollectionTag;
		if (useMock) {
			newTag = { id: Date.now(), name, color };
			allTags = [...allTags, newTag];
		} else {
			try {
				newTag = await createTag(name, color);
				allTags = [...allTags, newTag];
			} catch { return; }
		}
		await handleTagAttach(collectionId, newTag.id);
	}

	function selectFilter(filter: 'all' | 'favorites' | string) {
		selectedFilter = filter;
		selectedTagId = null;
	}

	function selectTag(tagId: number) {
		selectedTagId = selectedTagId === tagId ? null : tagId;
		selectedFilter = 'all';
	}
</script>

<svelte:head>
	<title>내 레시피북 | 입맛 저격 레시피 AI</title>
</svelte:head>

<div class="page-layout">
	<!-- ── 데스크탑 사이드바 ── -->
	<aside class="sidebar">
		<div class="sidebar-section">
			<p class="sidebar-label">레시피 보기</p>
			<button
				class="sidebar-item"
				class:active={selectedFilter === 'all' && selectedTagId === null}
				onclick={() => selectFilter('all')}
			>
				전체 <span class="count-badge">{collections.length}</span>
			</button>
			<button
				class="sidebar-item fav-item"
				class:active={selectedFilter === 'favorites'}
				onclick={() => selectFilter('favorites')}
			>
				⭐ 즐겨찾기 <span class="count-badge">{favoriteCount}</span>
			</button>
		</div>

		{#if categories.length > 0}
			<div class="sidebar-section">
				<p class="sidebar-label">카테고리</p>
				{#each categories as cat}
					<button
						class="sidebar-item"
						class:active={selectedFilter === cat && selectedTagId === null}
						onclick={() => selectFilter(cat)}
					>
						{cat}
						<span class="count-badge">
							{collections.filter(c => (c.category_override ?? c.recipe.category) === cat).length}
						</span>
					</button>
				{/each}
			</div>
		{/if}

		{#if allTags.length > 0}
			<div class="sidebar-section">
				<p class="sidebar-label">내 태그</p>
				{#each allTags as tag}
					<button
						class="sidebar-tag"
						class:active={selectedTagId === tag.id}
						style:--tag-color={tag.color}
						onclick={() => selectTag(tag.id)}
					>
						<span class="tag-dot" style:background={tag.color}></span>
						{tag.name}
					</button>
				{/each}
			</div>
		{/if}
	</aside>

	<!-- ── 메인 콘텐츠 ── -->
	<main class="main-content">
		<!-- 상단 헤더 -->
		<div class="content-header">
			<h1 class="page-title">내 레시피북</h1>
			<div class="header-actions">
				<input
					type="search"
					class="search-input"
					placeholder="레시피 검색..."
					bind:value={searchQuery}
				/>
			</div>
		</div>

		<!-- 모바일 수평 탭 -->
		<div class="mobile-tabs">
			<button
				class="mobile-tab"
				class:active={selectedFilter === 'all' && selectedTagId === null}
				onclick={() => selectFilter('all')}
			>전체</button>
			<button
				class="mobile-tab"
				class:active={selectedFilter === 'favorites'}
				onclick={() => selectFilter('favorites')}
			>⭐ 즐겨찾기</button>
			{#each categories as cat}
				<button
					class="mobile-tab"
					class:active={selectedFilter === cat && selectedTagId === null}
					onclick={() => selectFilter(cat)}
				>{cat}</button>
			{/each}
			{#each allTags as tag}
				<button
					class="mobile-tab tag-tab"
					class:active={selectedTagId === tag.id}
					style:--tag-color={tag.color}
					onclick={() => selectTag(tag.id)}
				>{tag.name}</button>
			{/each}
		</div>

		{#if useMock}
			<div class="mock-notice">
				⚠️ 서버에 연결할 수 없어 샘플 데이터를 표시 중입니다
			</div>
		{/if}

		<!-- 콘텐츠 영역 -->
		{#if loading}
			<div class="status-center">불러오는 중...</div>
		{:else if error}
			<div class="status-center error">{error}</div>
		{:else if collections.length === 0}
			<div class="empty-state" in:fade>
				<p class="empty-icon">📖</p>
				<h2>아직 레시피북이 비어있어요</h2>
				<p>유튜브 요리 영상 링크를 붙여넣으면 첫 레시피가 생겨요</p>
				<a href="/" class="cta-btn">첫 레시피 정리하러 가기</a>
			</div>
		{:else if filteredCollections.length === 0}
			<div class="status-center" in:fade>
				<p>조건에 맞는 레시피가 없어요</p>
				<button class="reset-btn" onclick={() => { selectedFilter = 'all'; selectedTagId = null; searchQuery = ''; }}>
					필터 초기화
				</button>
			</div>
		{:else}
			<div class="card-grid" in:fade>
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
	</main>
</div>

<style>
	/* 전체 레이아웃: 사이드바 + 메인 */
	.page-layout {
		display: grid;
		grid-template-columns: 200px 1fr;
		gap: 2rem;
		max-width: 1100px;
		margin: 0 auto;
		padding: 2rem var(--page-padding-desktop);
		min-height: calc(100vh - 80px);
		align-items: start;
	}

	/* ── 사이드바 ── */
	.sidebar {
		position: sticky;
		top: 1.5rem;
		display: flex;
		flex-direction: column;
		gap: 1.5rem;
	}
	.sidebar-section {
		display: flex;
		flex-direction: column;
		gap: 0.15rem;
	}
	.sidebar-label {
		font-size: 0.7rem;
		font-weight: 700;
		text-transform: uppercase;
		letter-spacing: 0.8px;
		color: var(--color-soft-brown);
		padding: 0 0.5rem;
		margin-bottom: 0.3rem;
	}
	.sidebar-item {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 0.4rem 0.5rem;
		border-radius: 8px;
		border: none;
		background: none;
		font-size: 0.9rem;
		color: var(--color-soft-brown);
		text-align: left;
		width: 100%;
	}
	.sidebar-item:hover { background: var(--color-cream); color: var(--color-warm-brown); }
	.sidebar-item.active {
		background: color-mix(in srgb, var(--color-terracotta) 12%, transparent);
		color: var(--color-terracotta);
		font-weight: 600;
	}
	.count-badge {
		font-size: 0.75rem;
		background: var(--color-light-line);
		color: var(--color-soft-brown);
		padding: 0.05rem 0.4rem;
		border-radius: 10px;
	}
	.sidebar-item.active .count-badge {
		background: color-mix(in srgb, var(--color-terracotta) 20%, transparent);
		color: var(--color-terracotta);
	}
	.sidebar-tag {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		padding: 0.35rem 0.5rem;
		border-radius: 8px;
		border: none;
		background: none;
		font-size: 0.88rem;
		color: var(--color-soft-brown);
		text-align: left;
		width: 100%;
	}
	.sidebar-tag:hover { background: var(--color-cream); color: var(--color-warm-brown); }
	.sidebar-tag.active {
		background: color-mix(in srgb, var(--tag-color) 15%, transparent);
		color: color-mix(in srgb, var(--tag-color) 80%, #333);
		font-weight: 600;
	}
	.tag-dot {
		width: 10px;
		height: 10px;
		border-radius: 50%;
		flex-shrink: 0;
	}

	/* ── 메인 콘텐츠 ── */
	.main-content { min-width: 0; }

	.content-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		margin-bottom: 1.2rem;
		gap: 1rem;
	}
	.page-title {
		font-size: 1.6rem;
		font-weight: 700;
		white-space: nowrap;
	}
	.search-input {
		border: 1px solid var(--color-light-line);
		border-radius: 8px;
		padding: 0.45rem 0.8rem;
		font-size: 0.875rem;
		font-family: inherit;
		color: var(--color-warm-brown);
		background: white;
		outline: none;
		width: 200px;
	}
	.search-input:focus { border-color: var(--color-terracotta); }

	/* 모바일 탭 (데스크탑에선 숨김) */
	.mobile-tabs { display: none; }

	/* 목업 배너 */
	.mock-notice {
		font-size: 0.78rem;
		color: var(--color-soft-brown);
		background: var(--color-cream);
		border: 1px dashed var(--color-light-line);
		border-radius: 8px;
		padding: 0.4rem 0.8rem;
		margin-bottom: 1rem;
		text-align: center;
	}

	/* 카드 그리드 */
	.card-grid {
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(220px, 1fr));
		gap: 1.2rem;
	}

	/* 상태 */
	.status-center {
		text-align: center;
		padding: 5rem 0;
		color: var(--color-soft-brown);
	}
	.status-center.error { color: var(--color-muted-red); }
	.reset-btn {
		margin-top: 1rem;
		background: none;
		border: 1px solid var(--color-light-line);
		border-radius: 8px;
		padding: 0.4rem 1rem;
		font-size: 0.85rem;
		color: var(--color-soft-brown);
	}
	.reset-btn:hover { border-color: var(--color-soft-brown); }

	/* 빈 상태 */
	.empty-state {
		text-align: center;
		padding: 5rem 0;
		color: var(--color-soft-brown);
	}
	.empty-icon { font-size: 3rem; margin-bottom: 1rem; }
	.empty-state h2 {
		font-size: 1.3rem;
		margin-bottom: 0.8rem;
		color: var(--color-warm-brown);
	}
	.empty-state p { line-height: 1.7; margin-bottom: 1.5rem; }
	.cta-btn {
		display: inline-block;
		background: var(--color-terracotta);
		color: white;
		padding: 0.75rem 2rem;
		border-radius: 10px;
		font-weight: 600;
	}
	.cta-btn:hover { background: #b5633f; color: white; }

	/* ── 모바일 반응형 ── */
	@media (max-width: 767px) {
		.page-layout {
			grid-template-columns: 1fr;
			padding: 1rem var(--page-padding-mobile);
			gap: 0;
		}

		/* 사이드바 → 숨김 (탭으로 대체) */
		.sidebar { display: none; }

		/* 모바일 탭 노출 */
		.mobile-tabs {
			display: flex;
			gap: 0.4rem;
			overflow-x: auto;
			-webkit-overflow-scrolling: touch;
			padding-bottom: 0.5rem;
			margin-bottom: 1rem;
		}
		.mobile-tabs::-webkit-scrollbar { display: none; }

		.mobile-tab {
			flex-shrink: 0;
			padding: 0.35rem 0.9rem;
			border-radius: 20px;
			border: 1px solid var(--color-light-line);
			background: white;
			font-size: 0.82rem;
			color: var(--color-soft-brown);
			white-space: nowrap;
		}
		.mobile-tab:hover { background: var(--color-cream); }
		.mobile-tab.active {
			background: var(--color-terracotta);
			color: white;
			border-color: var(--color-terracotta);
			font-weight: 600;
		}
		.mobile-tab.tag-tab.active {
			background: color-mix(in srgb, var(--tag-color) 80%, transparent);
			border-color: var(--tag-color);
			color: white;
		}

		.content-header { flex-wrap: wrap; }
		.search-input { width: 100%; }
		.page-title { font-size: 1.4rem; }

		/* 카드 그리드: 모바일 1열 */
		.card-grid {
			grid-template-columns: 1fr;
		}
	}
</style>
