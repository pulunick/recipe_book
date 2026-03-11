<script lang="ts">
	import { goto } from '$app/navigation';
	import { fridgeSearch, saveToCollection } from '$lib/api';
	import { isLoggedIn, openLoginModal } from '$lib/stores/auth.svelte';
	import type { FridgeSearchResultItem } from '$lib/types';

	const loggedIn = $derived(isLoggedIn());

	const DIFFICULTY_LABEL: Record<string, string> = {
		easy: '쉬움', medium: '보통', hard: '어려움'
	};

	const RECOMMENDED_INGREDIENTS = [
		'김치', '돼지고기', '두부', '계란', '양파', '파', '마늘', '간장',
		'고추장', '감자', '당근', '버섯', '치즈', '소시지', '참치캔', '라면'
	];

	let ingredients = $state<string[]>([]);
	let inputValue = $state('');
	let results = $state<FridgeSearchResultItem[]>([]);
	let searched = $state(false);
	let loading = $state(false);
	let error = $state('');

	// 보관함 추가 중인 id 추적
	let hasMeokdangImg = $state(true);

	// 보관함 추가 중인 id 추적
	let addingIds = $state<Set<number>>(new Set());
	// 보관함에 추가된 id → collection_id 매핑
	let collectedMap = $state<Map<number, number>>(new Map());

	function addIngredient(value: string) {
		const trimmed = value.trim();
		if (trimmed.length < 2) return;
		if (ingredients.length >= 15) return;
		if (ingredients.includes(trimmed)) return;
		ingredients = [...ingredients, trimmed];
	}

	function removeIngredient(name: string) {
		ingredients = ingredients.filter(i => i !== name);
	}

	function handleInputKeydown(e: KeyboardEvent) {
		if (e.key === 'Enter' || e.key === ',') {
			e.preventDefault();
			const val = inputValue.replace(/,$/, '');
			addIngredient(val);
			inputValue = '';
		} else if (e.key === 'Backspace' && inputValue === '' && ingredients.length > 0) {
			ingredients = ingredients.slice(0, -1);
		}
	}

	function handleInputInput() {
		if (inputValue.endsWith(',')) {
			const val = inputValue.slice(0, -1);
			addIngredient(val);
			inputValue = '';
		}
	}

	function toggleRecommended(name: string) {
		if (ingredients.includes(name)) return;
		addIngredient(name);
	}

	async function handleSearch() {
		if (ingredients.length === 0 || loading) return;
		loading = true;
		error = '';
		searched = false;
		results = [];
		try {
			results = await fridgeSearch(ingredients, 10);
			searched = true;
		} catch (e: unknown) {
			error = e instanceof Error ? e.message : '검색 중 오류가 발생했습니다.';
			searched = true;
		} finally {
			loading = false;
		}
	}

	async function handleCollect(e: MouseEvent, item: FridgeSearchResultItem) {
		e.preventDefault();
		e.stopPropagation();

		const existingId = collectedMap.get(item.id);
		if (existingId !== undefined) {
			goto(`/my-recipes/${existingId}`);
			return;
		}
		if (!loggedIn) {
			openLoginModal();
			return;
		}
		if (addingIds.has(item.id)) return;

		addingIds = new Set([...addingIds, item.id]);
		try {
			const collectionId = await saveToCollection(item.id);
			collectedMap = new Map([...collectedMap, [item.id, collectionId]]);
		} finally {
			addingIds = new Set([...addingIds].filter(id => id !== item.id));
		}
	}

	function getThumbnail(item: FridgeSearchResultItem): string | null {
		if (item.video_id) return `https://img.youtube.com/vi/${item.video_id}/mqdefault.jpg`;
		return null;
	}

	function getCardHref(item: FridgeSearchResultItem): string {
		return `/recipe/${item.video_id ?? item.id}`;
	}
</script>

<svelte:head>
	<title>냉장고 파먹기 — 해먹당</title>
</svelte:head>

<div class="fridge-page">
	<!-- 상단 바 -->
	<div class="top-bar">
		<button class="btn-back" onclick={() => goto('/')} aria-label="뒤로가기">
			<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
				<polyline points="15 18 9 12 15 6" />
			</svg>
		</button>
		<h1 class="page-title">냉장고 파먹기</h1>
	</div>

	<!-- 안내 영역 -->
	<div class="intro">
		<div class="intro-icon">
			{#if hasMeokdangImg}
				<img
					src="/meokdang.png"
					alt="먹당"
					class="meokdang-img"
					onerror={() => { hasMeokdangImg = false; }}
				/>
			{:else}
				<span class="fallback-emoji">🧊</span>
			{/if}
		</div>
		<p class="intro-text">냉장고에 있는 재료를 입력하면</p>
		<p class="intro-text">만들 수 있는 레시피를 찾아드려요</p>
	</div>

	<!-- 재료 입력 영역 -->
	<div class="input-section">
		<p class="section-label">재료 입력</p>
		<div class="chip-input-wrap">
			{#each ingredients as name}
				<span class="ingredient-chip">
					{name}
					<button class="chip-remove" onclick={() => removeIngredient(name)} aria-label="{name} 삭제">
						<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
							<line x1="18" y1="6" x2="6" y2="18" /><line x1="6" y1="6" x2="18" y2="18" />
						</svg>
					</button>
				</span>
			{/each}
			{#if ingredients.length < 15}
				<input
					type="text"
					class="ingredient-input"
					placeholder={ingredients.length === 0 ? '재료 입력 후 Enter...' : '재료 추가...'}
					bind:value={inputValue}
					onkeydown={handleInputKeydown}
					oninput={handleInputInput}
				/>
			{/if}
		</div>
		{#if ingredients.length >= 15}
			<p class="input-hint warn">최대 15개까지 입력할 수 있어요.</p>
		{:else}
			<p class="input-hint">Enter 또는 쉼표(,)로 추가 · Backspace로 마지막 삭제</p>
		{/if}
	</div>

	<!-- 추천 재료 -->
	<div class="recommend-section">
		<p class="section-label">추천 재료</p>
		<div class="recommend-chips">
			{#each RECOMMENDED_INGREDIENTS as name}
				{@const isAdded = ingredients.includes(name)}
				<button
					class="recommend-chip"
					class:added={isAdded}
					onclick={() => toggleRecommended(name)}
					disabled={isAdded || ingredients.length >= 15}
					aria-pressed={isAdded}
				>
					{name}
				</button>
			{/each}
		</div>
	</div>

	<!-- 검색 버튼 -->
	<div class="search-btn-wrap">
		<button
			class="btn-search"
			onclick={handleSearch}
			disabled={ingredients.length === 0 || loading}
		>
			{#if loading}
				<span class="search-spinner"></span>
				검색 중...
			{:else}
				레시피 찾기 ({ingredients.length})
			{/if}
		</button>
	</div>

	<!-- 결과 영역 -->
	<div class="results-section">
		{#if loading}
			<!-- 스켈레톤 로딩 -->
			{#each Array(3) as _}
				<div class="skeleton-card">
					<div class="skeleton-thumb"></div>
					<div class="skeleton-body">
						<div class="skeleton-line wide"></div>
						<div class="skeleton-line short"></div>
						<div class="skeleton-progress"></div>
					</div>
				</div>
			{/each}

		{:else if error}
			<div class="state-box">
				<span class="state-emoji">😔</span>
				<p class="state-title">오류가 발생했어요</p>
				<p class="state-desc">{error}</p>
				<button class="btn-retry" onclick={handleSearch}>다시 시도</button>
			</div>

		{:else if !searched}
			<!-- 검색 전 빈 상태 -->
			<div class="state-box">
				<span class="state-emoji">🥕</span>
				<p class="state-title">재료를 입력해보세요</p>
				<p class="state-desc">냉장고에 있는 재료로 만들 수 있는<br />레시피를 찾아드려요</p>
			</div>

		{:else if results.length === 0}
			<!-- 결과 없음 -->
			<div class="state-box">
				<span class="state-emoji">🧊</span>
				<p class="state-title">일치하는 레시피가 없어요</p>
				<p class="state-desc">재료를 줄이거나 다른 재료를 입력해보세요.</p>
			</div>

		{:else}
			<!-- 결과 헤더 -->
			<p class="result-count-label">
				<strong>{results.length}개</strong>의 레시피를 찾았어요
			</p>

			<!-- 결과 카드 리스트 -->
			{#each results as item (item.id)}
				{@const collected = collectedMap.has(item.id)}
				{@const adding = addingIds.has(item.id)}
				<article class="result-card">
					<a href={getCardHref(item)} class="card-link">
						<!-- 썸네일 -->
						<div class="result-thumb">
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

						<!-- 카드 본문 -->
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
								<p class="card-channel">
									{#if item.source === 'youtube'}<span class="source-icon-yt">▶</span>{/if}
									{item.channel_name}
								</p>
							{:else if item.source === 'text'}
								<p class="card-channel"><span class="source-icon-txt">✏</span> 직접 작성</p>
							{/if}

							<!-- 매칭 점수 -->
							<div class="match-section">
								<div class="match-bar-wrap">
									<div
										class="match-bar-fill"
										style="width: {Math.min(100, Math.round(item.match_score))}%"
									></div>
								</div>
								<span class="match-score-label">{Math.round(item.match_score)}% 매칭</span>
							</div>

							<!-- 일치 재료 칩 -->
							{#if item.matched_ingredients.length > 0}
								<div class="matched-chips">
									<span class="matched-label">일치:</span>
									{#each item.matched_ingredients as ing}
										<span class="matched-chip">{ing}</span>
									{/each}
								</div>
							{/if}
						</div>
					</a>

					<!-- 보관함 추가 버튼 -->
					<button
						class="btn-collect"
						class:is-added={collected}
						onclick={(e) => handleCollect(e, item)}
						disabled={adding}
						aria-label={collected ? '내 레시피 보러가기' : '내 레시피에 추가'}
					>
						{#if adding}
							<span class="collect-spinner"></span>
						{:else if collected}
							<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
								<polyline points="20 6 9 17 4 12" />
							</svg>
						{:else}
							<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
								<path d="M19 21l-7-5-7 5V5a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2z" />
							</svg>
						{/if}
					</button>
				</article>
			{/each}
		{/if}
	</div>
</div>

<style>
	.fridge-page {
		padding: 0 0 calc(80px + env(safe-area-inset-bottom));
	}

	/* 상단 바 */
	.top-bar {
		display: flex;
		align-items: center;
		gap: 4px;
		padding: 12px 16px 8px;
	}

	.btn-back {
		width: 36px;
		height: 36px;
		border: none;
		background: none;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		border-radius: 50%;
		color: var(--color-warm-brown);
		transition: background 0.15s;
		flex-shrink: 0;
	}
	.btn-back:hover { background: var(--color-cream); }
	.btn-back svg { width: 20px; height: 20px; }

	.page-title {
		font-size: 1.05rem;
		font-weight: 700;
		color: var(--color-warm-brown);
		margin: 0;
	}

	/* 안내 영역 */
	.intro {
		display: flex;
		flex-direction: column;
		align-items: center;
		padding: 16px 16px 20px;
		text-align: center;
	}

	.intro-icon {
		font-size: 3rem;
		line-height: 1;
		margin-bottom: 10px;
	}

	.meokdang-img {
		width: 64px;
		height: 64px;
		object-fit: contain;
	}

	.fallback-emoji {
		font-size: 3rem;
		line-height: 1;
	}

	.intro-text {
		font-size: 0.88rem;
		color: var(--color-soft-brown);
		line-height: 1.6;
		margin: 0;
	}

	/* 섹션 레이블 */
	.section-label {
		font-size: 0.82rem;
		font-weight: 700;
		color: var(--color-soft-brown);
		margin: 0 0 8px;
		text-transform: uppercase;
		letter-spacing: 0.04em;
	}

	/* 재료 입력 */
	.input-section {
		padding: 0 16px 16px;
	}

	.chip-input-wrap {
		display: flex;
		flex-wrap: wrap;
		gap: 6px;
		align-items: center;
		min-height: 44px;
		padding: 8px 12px;
		border: 1.5px solid var(--color-light-line);
		border-radius: 14px;
		background: var(--color-cream);
		transition: border-color 0.15s;
		cursor: text;
	}

	.chip-input-wrap:focus-within {
		border-color: var(--color-terracotta);
	}

	.ingredient-chip {
		display: inline-flex;
		align-items: center;
		gap: 4px;
		padding: 4px 8px 4px 10px;
		background: var(--color-terracotta);
		color: #fff;
		border-radius: 20px;
		font-size: 0.82rem;
		font-weight: 600;
	}

	.chip-remove {
		width: 16px;
		height: 16px;
		border: none;
		background: rgba(255,255,255,0.3);
		border-radius: 50%;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 0;
		flex-shrink: 0;
		transition: background 0.15s;
	}
	.chip-remove:hover { background: rgba(255,255,255,0.5); }
	.chip-remove svg { width: 9px; height: 9px; stroke: #fff; }

	.ingredient-input {
		flex: 1;
		min-width: 120px;
		border: none;
		background: none;
		outline: none;
		font-size: 0.88rem;
		color: var(--color-warm-brown);
		font-family: inherit;
	}

	.ingredient-input::placeholder {
		color: var(--color-soft-brown);
		opacity: 0.6;
	}

	.input-hint {
		font-size: 0.72rem;
		color: var(--color-soft-brown);
		opacity: 0.65;
		margin: 5px 0 0;
	}
	.input-hint.warn { color: #c0392b; opacity: 1; font-weight: 600; }

	/* 추천 재료 */
	.recommend-section {
		padding: 0 16px 20px;
	}

	.recommend-chips {
		display: flex;
		flex-wrap: wrap;
		gap: 7px;
	}

	.recommend-chip {
		padding: 6px 13px;
		border-radius: 20px;
		border: 1.5px solid var(--color-light-line);
		background: #fff;
		color: var(--color-soft-brown);
		font-size: 0.82rem;
		font-weight: 500;
		font-family: inherit;
		cursor: pointer;
		transition: background 0.15s, border-color 0.15s, color 0.15s, opacity 0.15s;
	}

	.recommend-chip:hover:not(:disabled) {
		border-color: var(--color-terracotta);
		color: var(--color-terracotta);
	}

	.recommend-chip.added,
	.recommend-chip:disabled {
		background: var(--color-light-line);
		color: var(--color-soft-brown);
		opacity: 0.5;
		cursor: not-allowed;
		border-color: transparent;
	}

	/* 검색 버튼 */
	.search-btn-wrap {
		padding: 0 16px 24px;
	}

	.btn-search {
		width: 100%;
		padding: 14px;
		background: var(--color-terracotta);
		color: #fff;
		border: none;
		border-radius: 14px;
		font-size: 1rem;
		font-weight: 700;
		font-family: inherit;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 8px;
		transition: background 0.15s, opacity 0.15s;
	}
	.btn-search:hover:not(:disabled) { background: #b5633f; }
	.btn-search:disabled { opacity: 0.45; cursor: not-allowed; }

	.search-spinner {
		width: 16px;
		height: 16px;
		border: 2px solid rgba(255,255,255,0.4);
		border-top-color: #fff;
		border-radius: 50%;
		animation: spin 0.7s linear infinite;
		flex-shrink: 0;
	}

	/* 결과 영역 */
	.results-section {
		padding: 0 16px;
		display: flex;
		flex-direction: column;
		gap: 12px;
	}

	/* 빈 상태 / 결과 없음 */
	.state-box {
		display: flex;
		flex-direction: column;
		align-items: center;
		padding: 48px 24px;
		text-align: center;
		gap: 8px;
	}

	.state-emoji {
		font-size: 2.8rem;
		line-height: 1;
		display: block;
		margin-bottom: 4px;
	}

	.state-title {
		font-size: 1rem;
		font-weight: 700;
		color: var(--color-warm-brown);
		margin: 0;
	}

	.state-desc {
		font-size: 0.85rem;
		color: var(--color-soft-brown);
		line-height: 1.6;
		margin: 0;
	}

	.btn-retry {
		margin-top: 8px;
		padding: 9px 22px;
		background: var(--color-terracotta);
		color: #fff;
		border: none;
		border-radius: 10px;
		font-size: 0.88rem;
		font-family: inherit;
		cursor: pointer;
		transition: background 0.15s;
	}
	.btn-retry:hover { background: #b5633f; }

	/* 결과 헤더 */
	.result-count-label {
		font-size: 0.85rem;
		color: var(--color-soft-brown);
		margin: 0 0 4px;
	}
	.result-count-label strong {
		color: var(--color-terracotta);
		font-weight: 700;
	}

	/* 결과 카드 */
	.result-card {
		position: relative;
		border: 1px solid var(--color-light-line);
		border-radius: 14px;
		background: #fff;
		overflow: hidden;
		transition: box-shadow 0.15s;
	}
	.result-card:hover { box-shadow: 0 4px 16px rgba(0,0,0,0.08); }

	.card-link {
		display: flex;
		gap: 12px;
		text-decoration: none;
		padding: 12px;
	}

	.result-thumb {
		position: relative;
		width: 100px;
		min-width: 100px;
		aspect-ratio: 16/9;
		border-radius: 10px;
		overflow: hidden;
		background: var(--color-cream);
		align-self: flex-start;
	}

	.result-thumb img {
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
		width: 24px;
		height: 24px;
		color: var(--color-light-line);
	}

	.category-badge {
		position: absolute;
		bottom: 4px;
		left: 4px;
		background: rgba(0,0,0,0.55);
		color: #fff;
		font-size: 0.62rem;
		font-weight: 600;
		padding: 2px 5px;
		border-radius: 4px;
	}

	.card-body {
		flex: 1;
		min-width: 0;
		display: flex;
		flex-direction: column;
		gap: 5px;
	}

	.card-title {
		font-size: 0.88rem;
		font-weight: 600;
		color: var(--color-warm-brown);
		line-height: 1.35;
		display: -webkit-box;
		-webkit-line-clamp: 2;
		line-clamp: 2;
		-webkit-box-orient: vertical;
		overflow: hidden;
		margin: 0;
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
	.meta-chip svg { width: 10px; height: 10px; }

	.card-channel {
		font-size: 0.72rem;
		color: var(--color-soft-brown);
		opacity: 0.75;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
		margin: 0;
	}
	.source-icon-yt { color: #f00; font-size: 0.65rem; margin-right: 2px; }
	.source-icon-txt { color: var(--color-terracotta); font-size: 0.65rem; margin-right: 2px; }

	/* 매칭 점수 */
	.match-section {
		display: flex;
		align-items: center;
		gap: 8px;
		margin-top: 2px;
	}

	.match-bar-wrap {
		flex: 1;
		height: 6px;
		background: var(--color-light-line);
		border-radius: 3px;
		overflow: hidden;
	}

	.match-bar-fill {
		height: 100%;
		background: var(--color-terracotta);
		border-radius: 3px;
		transition: width 0.4s ease;
	}

	.match-score-label {
		font-size: 0.72rem;
		font-weight: 700;
		color: var(--color-terracotta);
		white-space: nowrap;
		flex-shrink: 0;
	}

	/* 일치 재료 칩 */
	.matched-chips {
		display: flex;
		flex-wrap: wrap;
		gap: 4px;
		align-items: center;
	}

	.matched-label {
		font-size: 0.68rem;
		color: var(--color-soft-brown);
		font-weight: 600;
		flex-shrink: 0;
	}

	.matched-chip {
		font-size: 0.68rem;
		font-weight: 500;
		color: var(--color-terracotta);
		background: color-mix(in srgb, var(--color-terracotta) 10%, white);
		padding: 2px 7px;
		border-radius: 10px;
		border: 1px solid color-mix(in srgb, var(--color-terracotta) 25%, white);
	}

	/* 보관함 추가 버튼 */
	.btn-collect {
		position: absolute;
		top: 8px;
		right: 8px;
		width: 30px;
		height: 30px;
		border-radius: 50%;
		border: none;
		background: rgba(255,255,255,0.88);
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
	.btn-collect svg { width: 14px; height: 14px; }
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
	}
	.btn-collect:disabled { opacity: 0.6; cursor: not-allowed; }

	.collect-spinner {
		width: 13px;
		height: 13px;
		border: 2px solid rgba(0,0,0,0.15);
		border-top-color: var(--color-terracotta);
		border-radius: 50%;
		animation: spin 0.7s linear infinite;
	}

	/* 스켈레톤 */
	.skeleton-card {
		display: flex;
		gap: 12px;
		padding: 12px;
		border: 1px solid var(--color-light-line);
		border-radius: 14px;
		background: #fff;
	}

	.skeleton-thumb {
		width: 100px;
		min-width: 100px;
		aspect-ratio: 16/9;
		border-radius: 10px;
		background: var(--color-light-line);
		animation: shimmer 1.4s ease infinite;
	}

	.skeleton-body {
		flex: 1;
		display: flex;
		flex-direction: column;
		gap: 8px;
		justify-content: center;
	}

	.skeleton-line {
		height: 12px;
		border-radius: 6px;
		background: var(--color-light-line);
		animation: shimmer 1.4s ease infinite;
	}
	.skeleton-line.wide { width: 80%; }
	.skeleton-line.short { width: 45%; }

	.skeleton-progress {
		height: 6px;
		border-radius: 3px;
		width: 70%;
		background: var(--color-light-line);
		animation: shimmer 1.4s ease infinite;
	}

	@keyframes shimmer {
		0%, 100% { opacity: 1; }
		50% { opacity: 0.45; }
	}

	@keyframes spin {
		to { transform: rotate(360deg); }
	}
</style>
