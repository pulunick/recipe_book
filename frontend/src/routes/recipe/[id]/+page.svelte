<script lang="ts">
	import { goto } from '$app/navigation';
	import { page } from '$app/state';
	import { onMount } from 'svelte';
	import type { Recipe } from '$lib/types';
	import { extractRecipe, saveToCollection, checkCollection } from '$lib/api';
	import { isLoggedIn, openLoginModal } from '$lib/stores/auth.svelte';
	import FlavorProfile from '$lib/components/FlavorProfile.svelte';
	import IngredientList from '$lib/components/IngredientList.svelte';
	import StepTimeline from '$lib/components/StepTimeline.svelte';
	import VideoCard from '$lib/components/VideoCard.svelte';
	import ScrollToTop from '$lib/components/ScrollToTop.svelte';
	import Toast from '$lib/components/Toast.svelte';

	// navigation state에서 recipe와 sourceUrl 가져오기
	let recipe = $state<Recipe | null>(page.state.recipe ?? null);
	let sourceUrl = $state<string>(page.state.sourceUrl ?? '');
	let saveStatus = $state<'' | 'saving' | 'saved' | 'error'>('');
	let savedCollectionId = $state<number | null>(null);
	let isReanalyzing = $state(false);
	let showToast = $state(false);
	let pageLoading = $state(false);

	onMount(async () => {
		if (recipe) {
			// navigation state로 온 경우: 이미 저장 여부 백그라운드 체크
			if (isLoggedIn() && recipe.id) {
				checkCollection(recipe.id).then(id => {
					if (id !== null) { savedCollectionId = id; saveStatus = 'saved'; }
				}).catch(() => {});
			}
			return;
		}

		const id = page.params.id;
		if (id && /^[a-zA-Z0-9_-]{11}$/.test(id)) {
			pageLoading = true;
			const url = `https://www.youtube.com/watch?v=${id}`;
			try {
				recipe = await extractRecipe(url);
				sourceUrl = url;
				// 로그인 상태면 이미 저장 여부 확인
				if (isLoggedIn() && recipe?.id) {
					checkCollection(recipe.id).then(id => {
						if (id !== null) { savedCollectionId = id; saveStatus = 'saved'; }
					}).catch(() => {});
				}
			} catch {
				goto('/');
			} finally {
				pageLoading = false;
			}
		} else {
			goto('/');
		}
	});

	async function handleSave() {
		if (!recipe?.id) return;
		if (!isLoggedIn()) {
			openLoginModal(`/?save_recipe_id=${recipe.id}`);
			return;
		}
		if (saveStatus === 'saved' && savedCollectionId) {
			goto(`/my-recipes/${savedCollectionId}`, { state: { justAdded: true } });
			return;
		}
		saveStatus = 'saving';
		try {
			const collectionId = await saveToCollection(recipe.id);
			savedCollectionId = collectionId;
			saveStatus = 'saved';
			showToast = true;
		} catch {
			saveStatus = 'error';
		}
	}

	async function handleReanalyze() {
		if (!sourceUrl) return;
		isReanalyzing = true;
		saveStatus = '';
		try {
			recipe = await extractRecipe(sourceUrl, true);
		} catch {
			// 실패 시 기존 결과 유지
		} finally {
			isReanalyzing = false;
		}
	}

	const displayTitle = $derived(
		recipe ? `${recipe.title}${recipe.channel_name ? ` - ${recipe.channel_name}` : ''}` : ''
	);
</script>

<svelte:head>
	<title>{displayTitle} | 해먹당</title>
</svelte:head>

{#if pageLoading}
<div class="page-loading">
	<span class="loading-spinner"></span>
	<p>레시피 불러오는 중...</p>
</div>
{:else if recipe}
<main class="page-wrap">
	<section class="recipe-page">
		<div class="recipe-top-bar">
			<a href="/" class="back-link">← 새 레시피 정리</a>
			<div class="top-actions">
				{#if sourceUrl}
					<button class="reanalyze-btn" onclick={handleReanalyze} disabled={isReanalyzing}>
						{isReanalyzing ? '분석 중...' : '다시 분석'}
					</button>
				{/if}
				<button
					class="save-btn"
					class:is-saved={saveStatus === 'saved'}
					onclick={handleSave}
					disabled={saveStatus === 'saving'}
				>
					{#if saveStatus === 'saved'}내 레시피 보러가기 →
					{:else if saveStatus === 'saving'}추가 중...
					{:else if saveStatus === 'error'}다시 시도
					{:else}<span class="bookmark-icon" aria-hidden="true"></span>레시피북에 추가
					{/if}
				</button>
			</div>
		</div>

		<article class="recipe-card">
			<h1 class="recipe-title">{displayTitle}</h1>

			{#if recipe.servings || recipe.cooking_time || recipe.difficulty}
				<div class="recipe-meta-chips">
					{#if recipe.servings}
						<span class="meta-chip">👥 {recipe.servings}</span>
					{/if}
					{#if recipe.cooking_time}
						<span class="meta-chip">⏱ {recipe.cooking_time}</span>
					{/if}
					{#if recipe.difficulty}
						<span class="meta-chip difficulty-{recipe.difficulty === '쉬움' ? 'easy' : recipe.difficulty === '보통' ? 'medium' : 'hard'}">{recipe.difficulty}</span>
					{/if}
				</div>
			{/if}

			{#if recipe.summary}
				<p class="recipe-summary">{recipe.summary}</p>
			{/if}

			{#if recipe.flavor}
				<FlavorProfile flavor={recipe.flavor} />
			{/if}
			{#if recipe.ingredients?.length}
				<IngredientList
					ingredients={recipe.ingredients}
					storageKey={recipe.video_id ?? String(recipe.id ?? '')}
					showCheckbox={false}
				/>
			{/if}
			{#if recipe.steps?.length}
				<StepTimeline steps={recipe.steps} />
			{/if}

			{#if recipe.tip}
				<div class="tip-section">
					<div class="tip-card">
						<span class="tip-label">✦ 꿀팁</span>
						<p>{recipe.tip}</p>
					</div>
				</div>
			{/if}

			<VideoCard
				videoId={recipe.video_id}
				videoUrl={recipe.video_url ?? null}
				channelName={recipe.channel_name}
				videoTitle={recipe.video_title ?? null}
			/>
		</article>

		<div class="recipe-bottom-bar">
			<button
				class="save-btn-bottom"
				class:is-saved={saveStatus === 'saved'}
				onclick={handleSave}
				disabled={saveStatus === 'saving'}
			>
				{#if saveStatus === 'saved'}내 레시피 보러가기 →
				{:else if saveStatus === 'saving'}추가하는 중...
				{:else if saveStatus === 'error'}다시 시도
				{:else}<span class="bookmark-icon" aria-hidden="true"></span>내 레시피북에 추가
				{/if}
			</button>
		</div>
	</section>
</main>
{/if}

<ScrollToTop />

<Toast
	message="레시피북에 추가됐어요!"
	show={showToast}
	ondismiss={() => (showToast = false)}
/>

<style>
	.page-wrap {
		max-width: 960px;
		margin: 0 auto;
		padding: 0 var(--page-padding-desktop);
		min-height: calc(100vh - 80px);
	}

	.recipe-page {
		max-width: var(--recipe-max-width);
		margin: 0 auto;
		padding-bottom: 4rem;
	}

	.recipe-top-bar {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 1.5rem 0;
		gap: 0.5rem;
	}

	.back-link {
		color: var(--color-soft-brown);
		font-size: 0.9rem;
		font-weight: 500;
		text-decoration: none;
	}
	.back-link:hover { color: var(--color-terracotta); }

	.top-actions {
		display: flex;
		gap: 0.6rem;
		align-items: center;
	}

	.reanalyze-btn {
		background: none;
		border: 1.5px solid var(--color-light-line);
		color: var(--color-soft-brown);
		padding: 0.5rem 1rem;
		border-radius: 8px;
		font-size: 0.85rem;
		font-weight: 500;
	}
	.reanalyze-btn:hover:not(:disabled) {
		border-color: var(--color-soft-brown);
		color: var(--color-warm-brown);
	}
	.reanalyze-btn:disabled { opacity: 0.6; cursor: not-allowed; }

	.bookmark-icon {
		display: inline-block;
		width: 14px;
		height: 18px;
		background: white;
		clip-path: polygon(0 0, 100% 0, 100% 85%, 50% 100%, 0 85%);
		margin-right: 0.4rem;
		vertical-align: middle;
		position: relative;
		top: -1px;
	}

	.save-btn, .save-btn-bottom {
		background: var(--color-terracotta);
		color: white;
		border: none;
		padding: 0.6rem 1.2rem;
		border-radius: 8px;
		font-size: 0.9rem;
		font-weight: 600;
		cursor: pointer;
		font-family: inherit;
		transition: background 0.15s;
	}
	.save-btn:hover:not(:disabled), .save-btn-bottom:hover:not(:disabled) {
		background: #b5633f;
	}
	.save-btn.is-saved, .save-btn-bottom.is-saved {
		background: var(--color-sage, #7a9e7e);
	}
	.save-btn.is-saved:hover, .save-btn-bottom.is-saved:hover {
		background: #5f8463;
	}
	.save-btn:disabled, .save-btn-bottom:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}

	.recipe-card {
		background: white;
		border-radius: 12px;
		padding: 2.5rem;
		box-shadow: 0 2px 8px rgba(0,0,0,0.06);
	}

	.recipe-title {
		font-size: 1.8rem;
		margin-bottom: 1rem;
		text-align: center;
	}

	.recipe-meta-chips {
		display: flex;
		justify-content: center;
		flex-wrap: wrap;
		gap: 0.5rem;
		margin-bottom: 1.2rem;
	}
	.meta-chip {
		font-size: 0.82rem;
		font-weight: 500;
		color: var(--color-soft-brown);
		background: var(--color-cream);
		border-radius: 12px;
		padding: 0.25rem 0.7rem;
	}
	.meta-chip.difficulty-easy { color: #1e7e34; background: #d4edda; font-weight: 600; }
	.meta-chip.difficulty-medium { color: #856404; background: #fff3cd; font-weight: 600; }
	.meta-chip.difficulty-hard { color: #a94442; background: #fde8e8; font-weight: 600; }

	.recipe-summary {
		color: var(--color-soft-brown);
		text-align: center;
		margin-bottom: 2rem;
		line-height: 1.7;
	}

	.tip-section { margin-top: 2rem; }

	.tip-card {
		border-left: 4px solid var(--color-terracotta);
		background: var(--color-cream);
		padding: 1rem 1.2rem;
		border-radius: 0 8px 8px 0;
	}
	.tip-label {
		display: block;
		font-size: 0.75rem;
		font-weight: 700;
		color: var(--color-terracotta);
		letter-spacing: 0.06em;
		margin-bottom: 0.45rem;
	}
	.tip-card p {
		margin: 0;
		line-height: 1.75;
		color: var(--color-warm-brown);
		font-size: 0.95rem;
	}

	.recipe-bottom-bar {
		text-align: center;
		padding: 1.5rem 0;
	}
	.save-btn-bottom {
		padding: 0.9rem 2.5rem;
		font-size: 1.05rem;
		border-radius: 10px;
	}

	@media (max-width: 767px) {
		.page-wrap { padding: 0 var(--page-padding-mobile); }
		/* 고정 버튼 바(약 80px) + 간격(8px) + 바텀 네비(60px) 만큼 하단 여백 */
		.recipe-page { padding-bottom: calc(148px + env(safe-area-inset-bottom)); }
		.recipe-card {
			padding: 1.5rem;
			padding-bottom: 2rem;
		}
		.recipe-title { font-size: 1.4rem; }
		.recipe-top-bar { flex-wrap: wrap; }
		.save-btn { display: none; }
		.back-link { min-height: 44px; display: flex; align-items: center; }
		.reanalyze-btn { min-height: 44px; padding: 0.6rem 1rem; }
		.recipe-bottom-bar {
			position: fixed;
			left: 0;
			right: 0;
			bottom: calc(60px + env(safe-area-inset-bottom));
			padding: 0.75rem 1rem;
			background: var(--color-paper);
			box-shadow: 0 -4px 16px rgba(0, 0, 0, 0.1);
			z-index: 49;
		}
		.save-btn-bottom {
			width: 100%;
			min-height: 52px;
			font-size: 1rem;
			border-radius: 8px;
			padding: 0.75rem 1rem;
		}
	}

	.page-loading {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		gap: 12px;
		min-height: 60vh;
		color: var(--color-soft-brown);
		font-size: 0.9rem;
	}

	.loading-spinner {
		width: 32px;
		height: 32px;
		border: 3px solid var(--color-light-line);
		border-top-color: var(--color-terracotta);
		border-radius: 50%;
		animation: spin 0.7s linear infinite;
		display: block;
	}

	@keyframes spin {
		to { transform: rotate(360deg); }
	}
</style>
