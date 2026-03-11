<script lang="ts">
	import { onMount, tick } from 'svelte';
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
	import Toast from '$lib/components/Toast.svelte';

	/* ── 목업 데이터 (백엔드 연동 전) ── */
	const MOCK_COLLECTIONS: CollectionItem[] = [
		{
			id: 1,
			recipe: { id: 1, title: '된장찌개 황금 레시피', summary: '구수하고 깊은 맛', ingredients: [], steps: [], flavor: { saltiness: 4, sweetness: 1, spiciness: 2, sourness: 1, oiliness: 2 }, tip: null, category: '한식', video_url: null, video_id: 'dQw4w9WgXcQ', video_title: null, channel_name: null, servings: null, cooking_time: null, difficulty: null },
			custom_tip: '된장 조금 덜 넣는 게 맛있음',
			recipe_override: null,
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
			recipe: { id: 2, title: '간단 파스타 10분 완성', summary: '바쁜 날을 위한 빠른 파스타', ingredients: [], steps: [], flavor: { saltiness: 3, sweetness: 2, spiciness: 1, sourness: 3, oiliness: 4 }, tip: null, category: '양식', video_url: null, video_id: 'abc1234abcd', video_title: null, channel_name: null, servings: null, cooking_time: null, difficulty: null },
			custom_tip: null,
			recipe_override: null,
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
			recipe: { id: 3, title: '떡볶이 매운맛 버전', summary: '진짜 매운 떡볶이', ingredients: [], steps: [], flavor: { saltiness: 3, sweetness: 4, spiciness: 5, sourness: 1, oiliness: 2 }, tip: null, category: '분식', video_url: null, video_id: 'xyz9876xyzw', video_title: null, channel_name: null, servings: null, cooking_time: null, difficulty: null },
			custom_tip: '물 조금 더 추가',
			recipe_override: null,
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
			recipe: { id: 4, title: '오이 무침 다이어트 반찬', summary: '상큼하고 칼로리 낮은 반찬', ingredients: [], steps: [], flavor: { saltiness: 2, sweetness: 2, spiciness: 2, sourness: 4, oiliness: 1 }, tip: null, category: '한식', video_url: null, video_id: 'mnb3210mnba', video_title: null, channel_name: null, servings: null, cooking_time: null, difficulty: null },
			custom_tip: null,
			recipe_override: null,
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
	let selectedSource = $state('');
	let useMock = $state(false);
	let toastMsg = $state('');
	let toastType = $state<'success' | 'error'>('success');
	let showToast = $state(false);

	function showToastMsg(msg: string, type: 'success' | 'error' = 'success') {
		toastMsg = msg;
		toastType = type;
		showToast = true;
	}

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

		// 제목 + 재료명 검색
		if (searchQuery.trim()) {
			const q = searchQuery.trim().toLowerCase();
			result = result.filter(c => {
				if (c.recipe.title.toLowerCase().includes(q)) return true;
				return (c.recipe.ingredients ?? []).some(ing => ing.name.toLowerCase().includes(q));
			});
		}

		// 필터 (전체 / 즐겨찾기 / 카테고리)
		if (selectedFilter === 'favorites') {
			result = result.filter(c => c.is_favorite);
		} else if (selectedFilter !== 'all') {
			result = result.filter(c => (c.category_override ?? c.recipe.category) === selectedFilter);
		}

		// 소스 필터 (youtube / text)
		if (selectedSource) {
			result = result.filter(c => c.recipe.source === selectedSource);
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
				showToastMsg(`"${name}" 태그가 추가됐어요`);
			} catch (e) {
				const msg = e instanceof Error ? e.message : '태그 생성에 실패했어요';
				showToastMsg(msg, 'error');
				return;
			}
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

	// 모바일 탭 active 스크롤
	$effect(() => {
		// 의존성 추적
		selectedFilter;
		selectedTagId;
		tick().then(() => {
			const activeTab = document.querySelector('.mobile-tabs .mobile-tab.active') as HTMLElement | null;
			activeTab?.scrollIntoView({ behavior: 'smooth', inline: 'center', block: 'nearest' });
		});
	});
</script>

<svelte:head>
	<title>내 레시피북 | 해먹당</title>
</svelte:head>

<Toast message={toastMsg} show={showToast} type={toastType} ondismiss={() => (showToast = false)} />

<div class="page-wrap">
	<!-- ── 검색바 헤더 ── -->
	<div class="search-header">
		<div class="search-bar">
			<svg class="search-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
				<circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/>
			</svg>
			<input
				type="search"
				class="search-input"
				placeholder="내 레시피 검색..."
				bind:value={searchQuery}
			/>
		</div>
	</div>

	<!-- ── 소스 필터 칩 ── -->
	<div class="source-chips">
		<button class="source-chip" class:active={selectedSource === ''} onclick={() => (selectedSource = '')}>전체</button>
		<button class="source-chip" class:active={selectedSource === 'youtube'} onclick={() => (selectedSource = selectedSource === 'youtube' ? '' : 'youtube')}>▶ YouTube</button>
		<button class="source-chip" class:active={selectedSource === 'text'} onclick={() => (selectedSource = selectedSource === 'text' ? '' : 'text')}>✏ 직접 작성</button>
	</div>

	<!-- ── 필터 탭 ── -->
	<div class="filter-tabs">
		<button
			class="filter-tab"
			class:active={selectedFilter === 'all' && selectedTagId === null}
			onclick={() => selectFilter('all')}
		>전체 <span class="tab-count">{collections.length}</span></button>
		<button
			class="filter-tab"
			class:active={selectedFilter === 'favorites'}
			onclick={() => selectFilter('favorites')}
		>⭐ 즐겨찾기</button>
		{#each categories as cat}
			<button
				class="filter-tab"
				class:active={selectedFilter === cat && selectedTagId === null}
				onclick={() => selectFilter(cat)}
			>{cat}</button>
		{/each}
		{#each allTags as tag}
			<button
				class="filter-tab tag-tab"
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

	<!-- ── 콘텐츠 영역 ── -->
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
			<button class="reset-btn" onclick={() => { selectedFilter = 'all'; selectedTagId = null; selectedSource = ''; searchQuery = ''; }}>
				필터 초기화
			</button>
		</div>
	{:else}
		<div class="card-grid" in:fade>
			{#each filteredCollections as item (item.id)}
				<RecipeCard
					{item}
					onfavorite={handleFavorite}
				/>
			{/each}
		</div>
	{/if}
</div>

<style>
	.page-wrap {
		display: flex;
		flex-direction: column;
		padding: 0 12px calc(90px + env(safe-area-inset-bottom));
	}

	/* ── 검색바 ── */
	.search-header {
		position: sticky;
		top: 0;
		background: var(--color-paper);
		z-index: 10;
		padding: 12px 16px;
	}
	.search-bar {
		display: flex;
		align-items: center;
		gap: 8px;
		background: var(--color-cream);
		border: 1.5px solid var(--color-light-line);
		border-radius: 14px;
		padding: 0 14px;
		height: 44px;
		transition: border-color 0.15s;
		width: 100%;
	}
	.search-bar:focus-within { border-color: var(--color-terracotta); }
	.search-icon {
		width: 17px;
		height: 17px;
		color: var(--color-soft-brown);
		flex-shrink: 0;
	}
	.search-input {
		flex: 1;
		border: none;
		background: transparent;
		font-size: 0.92rem;
		font-family: inherit;
		color: var(--color-warm-brown);
		outline: none;
		min-width: 0;
	}

	/* ── 소스 칩 ── */
	.source-chips {
		display: flex;
		gap: 0.4rem;
		padding: 0 0 8px;
		overflow-x: auto;
		scrollbar-width: none;
	}
	.source-chips::-webkit-scrollbar {
		display: none;
	}
	.source-chip {
		flex-shrink: 0;
		padding: 6px 14px;
		border-radius: 20px;
		border: 1.5px solid var(--color-light-line);
		background: #fff;
		font-size: 0.82rem;
		font-weight: 500;
		font-family: inherit;
		color: var(--color-soft-brown);
		cursor: pointer;
		transition: background 0.15s, border-color 0.15s, color 0.15s;
		white-space: nowrap;
	}
	.source-chip.active {
		background: var(--color-terracotta);
		border-color: var(--color-terracotta);
		color: #fff;
	}

	/* ── 필터 탭 ── */
	.filter-tabs {
		display: flex;
		gap: 0.4rem;
		overflow-x: auto;
		-webkit-overflow-scrolling: touch;
		padding: 0 0 8px;
		margin-bottom: 12px;
		scrollbar-width: none;
	}
	.filter-tabs::-webkit-scrollbar { display: none; }

	.filter-tab {
		flex-shrink: 0;
		display: flex;
		align-items: center;
		gap: 0.3rem;
		padding: 6px 14px;
		border-radius: 20px;
		border: 1.5px solid var(--color-light-line);
		background: #fff;
		font-size: 0.82rem;
		font-weight: 500;
		font-family: inherit;
		color: var(--color-soft-brown);
		white-space: nowrap;
		cursor: pointer;
		transition: background 0.15s, border-color 0.15s, color 0.15s;
	}
	.filter-tab.active {
		background: var(--color-terracotta);
		color: white;
		border-color: var(--color-terracotta);
	}
	.filter-tab.tag-tab.active {
		background: color-mix(in srgb, var(--tag-color) 80%, transparent);
		border-color: var(--tag-color);
	}
	.tab-count {
		font-size: 0.72rem;
		background: rgba(255,255,255,0.25);
		border-radius: 10px;
		padding: 0 0.3rem;
		min-width: 18px;
		text-align: center;
	}
	.filter-tab:not(.active) .tab-count {
		background: var(--color-light-line);
		color: var(--color-soft-brown);
	}

	/* 목업 배너 */
	.mock-notice {
		font-size: 0.78rem;
		color: var(--color-soft-brown);
		background: var(--color-cream);
		border: 1px dashed var(--color-light-line);
		border-radius: 8px;
		padding: 0.4rem 0.8rem;
		margin-bottom: 12px;
		text-align: center;
	}

	/* ── 카드 그리드 ── */
	.card-grid {
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(160px, 1fr));
		gap: 10px;
	}

	/* 상태 */
	.status-center {
		text-align: center;
		padding: 5rem 0;
		color: var(--color-soft-brown);
		display: flex;
		flex-direction: column;
		align-items: center;
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
		font-family: inherit;
		cursor: pointer;
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
		font-size: 1.2rem;
		margin-bottom: 0.8rem;
		color: var(--color-warm-brown);
	}
	.empty-state p { line-height: 1.7; margin-bottom: 1.5rem; font-size: 0.9rem; }
	.cta-btn {
		display: inline-block;
		background: var(--color-terracotta);
		color: white;
		padding: 0.65rem 1.8rem;
		border-radius: 10px;
		font-weight: 600;
		font-size: 0.9rem;
	}
	.cta-btn:hover { background: #b5633f; color: white; }
</style>
