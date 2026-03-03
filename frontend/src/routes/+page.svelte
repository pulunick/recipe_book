<script lang="ts">
	import { fade } from 'svelte/transition';
	import type { Recipe, PageStatus } from '$lib/types';
	import { extractRecipe, saveToCollection } from '$lib/api';
	import SearchBox from '$lib/components/SearchBox.svelte';
	import LoadingScreen from '$lib/components/LoadingScreen.svelte';
	import FlavorProfile from '$lib/components/FlavorProfile.svelte';
	import IngredientList from '$lib/components/IngredientList.svelte';
	import StepTimeline from '$lib/components/StepTimeline.svelte';
	import Toast from '$lib/components/Toast.svelte';

	let status: PageStatus = $state('IDLE');
	let recipe: Recipe | null = $state(null);
	let errorMessage = $state('');
	let saveStatus: '' | 'saving' | 'saved' | 'error' = $state('');
	let currentUrl = $state('');
	let currentVideoId: string | null = $state(null);
	let showToast = $state(false);

	function getVideoId(url: string): string | null {
		const m = url.match(/(?:v=|\/|youtu\.be\/|embed\/|shorts\/)([0-9A-Za-z_-]{11})/);
		return m ? m[1] : null;
	}

	async function handleAnalyze(url: string) {
		status = 'LOADING';
		errorMessage = '';
		saveStatus = '';
		currentUrl = url;
		currentVideoId = getVideoId(url);
		try {
			recipe = await extractRecipe(url);
			status = 'RESULT';
		} catch (e: unknown) {
			status = 'ERROR';
			errorMessage = e instanceof Error ? e.message : '알 수 없는 오류가 발생했습니다.';
		}
	}

	async function handleReanalyze() {
		if (!currentUrl) return;
		status = 'LOADING';
		saveStatus = '';
		try {
			recipe = await extractRecipe(currentUrl, true);
			status = 'RESULT';
		} catch (e: unknown) {
			status = 'ERROR';
			errorMessage = e instanceof Error ? e.message : '알 수 없는 오류가 발생했습니다.';
		}
	}

	async function handleSave() {
		if (!recipe?.id) return;
		saveStatus = 'saving';
		try {
			await saveToCollection(recipe.id);
			saveStatus = 'saved';
			showToast = true;
		} catch {
			saveStatus = 'error';
		}
	}

	function goHome() {
		status = 'IDLE';
		recipe = null;
		saveStatus = '';
		errorMessage = '';
		currentUrl = '';
		currentVideoId = null;
	}
</script>

<svelte:head>
	<title>마레픽 — AI 레시피 정리</title>
</svelte:head>

<main class="page-wrap">
	{#if status === 'IDLE' || status === 'ERROR'}
		<section class="home" in:fade>
			<div class="hero-text">
				<h1>유튜브 요리 영상의 레시피를<br />깔끔하게 정리해드려요</h1>
			</div>
			<SearchBox
				onsubmit={handleAnalyze}
				errorMessage={status === 'ERROR' ? errorMessage : ''}
			/>
			<p class="how-to">
				링크 붙여넣기 → 버튼 누르기<br />
				재료와 만드는 법이 한 페이지로 정리돼요
			</p>
		</section>

	{:else if status === 'LOADING'}
		<section class="home" in:fade>
			<SearchBox onsubmit={handleAnalyze} disabled={true} />
			<LoadingScreen videoId={currentVideoId} />
		</section>

	{:else if status === 'RESULT' && recipe}
		<section class="recipe-page" in:fade>
			<div class="recipe-top-bar">
				<button class="back-link" onclick={goHome}>← 새 레시피 정리</button>
				<div class="top-actions">
					<button class="reanalyze-btn" onclick={handleReanalyze}>
						다시 분석
					</button>
					<button
						class="save-btn"
						onclick={handleSave}
						disabled={saveStatus === 'saving' || saveStatus === 'saved'}
					>
						{#if saveStatus === 'saved'}추가됨 ✓
						{:else if saveStatus === 'saving'}추가 중...
						{:else if saveStatus === 'error'}다시 시도
						{:else}<span class="bookmark-icon" aria-hidden="true"></span>레시피북에 추가
						{/if}
					</button>
				</div>
			</div>

			<article class="recipe-card">
				<h1 class="recipe-title">{recipe.title}</h1>

				{#if recipe.summary}
					<p class="recipe-summary">{recipe.summary}</p>
				{/if}

				<FlavorProfile flavor={recipe.flavor} />
				<IngredientList
					ingredients={recipe.ingredients}
					storageKey={recipe.video_id ?? String(recipe.id ?? '')}
				/>
				<StepTimeline steps={recipe.steps} />

				{#if recipe.tip}
					<div class="tip-section">
						<div class="section-divider">
							<span class="divider-line"></span>
							<span class="divider-text">꿀팁</span>
							<span class="divider-line"></span>
						</div>
						<div class="tip-card">
							<p>{recipe.tip}</p>
						</div>
					</div>
				{/if}

				{#if recipe.video_url || recipe.video_id}
					<div class="video-link-area">
						<a
							href={recipe.video_url || `https://youtu.be/${recipe.video_id}`}
							target="_blank"
							rel="noopener noreferrer"
							class="video-link"
						>
							원본 영상 보기 →
						</a>
					</div>
				{/if}
			</article>

			<div class="recipe-bottom-bar">
				<button
					class="save-btn-bottom"
					onclick={handleSave}
					disabled={saveStatus === 'saving' || saveStatus === 'saved'}
				>
					{#if saveStatus === 'saved'}레시피북에 추가됨 ✓
					{:else if saveStatus === 'saving'}추가하는 중...
					{:else if saveStatus === 'error'}다시 시도
					{:else}<span class="bookmark-icon" aria-hidden="true"></span>내 레시피북에 추가
					{/if}
				</button>
			</div>
		</section>
	{/if}
</main>

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

	.home {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		min-height: calc(100vh - 200px);
		gap: 2rem;
		text-align: center;
	}
	.hero-text h1 {
		font-size: 1.8rem;
		font-weight: 700;
		color: var(--color-warm-brown);
		line-height: 1.5;
		letter-spacing: -0.5px;
	}
	.how-to {
		font-size: 0.95rem;
		color: var(--color-soft-brown);
		line-height: 1.8;
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
		background: none;
		border: none;
		color: var(--color-soft-brown);
		font-size: 0.9rem;
		font-weight: 500;
		padding: 0.5rem 0;
		flex-shrink: 0;
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
	.reanalyze-btn:hover {
		border-color: var(--color-soft-brown);
		color: var(--color-warm-brown);
	}

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
	}
	.save-btn:hover:not(:disabled), .save-btn-bottom:hover:not(:disabled) {
		background: #b5633f;
	}
	.save-btn:disabled, .save-btn-bottom:disabled {
		opacity: 0.6;
		cursor: default;
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
	.recipe-summary {
		color: var(--color-soft-brown);
		text-align: center;
		margin-bottom: 2rem;
		line-height: 1.7;
	}

	.tip-section { margin-top: 1.5rem; }
	.section-divider {
		display: flex;
		align-items: center;
		gap: 1rem;
		margin-bottom: 1.2rem;
	}
	.divider-line { flex: 1; height: 1px; background: var(--color-light-line); }
	.divider-text {
		font-size: 0.85rem;
		font-weight: 600;
		color: var(--color-soft-brown);
		white-space: nowrap;
	}
	.tip-card {
		background: var(--color-warm-yellow);
		padding: 1.2rem 1.5rem;
		border-radius: 10px;
		font-family: var(--font-memo);
		line-height: 1.8;
		color: var(--color-warm-brown);
	}

	.video-link-area {
		margin-top: 2rem;
		text-align: center;
		padding-top: 1.5rem;
		border-top: 1px solid var(--color-light-line);
	}
	.video-link { font-size: 0.9rem; color: var(--color-dusty-blue); }

	.recipe-bottom-bar {
		text-align: center;
		padding: 2rem 0;
	}
	.save-btn-bottom {
		padding: 0.9rem 2.5rem;
		font-size: 1.05rem;
		border-radius: 10px;
	}

	@media (max-width: 767px) {
		.page-wrap { padding: 0 var(--page-padding-mobile); }
		.hero-text h1 { font-size: 1.4rem; }
		.recipe-card {
			padding: 1.5rem;
			padding-bottom: 5rem; /* sticky 버튼에 가리지 않도록 */
		}
		.recipe-title { font-size: 1.4rem; }
		.recipe-top-bar { flex-wrap: wrap; }

		/* 모바일: 상단 저장 버튼 숨기고 하단 sticky만 노출 */
		.save-btn { display: none; }

		/* 모바일: 버튼 터치 영역 확보 */
		.back-link {
			min-height: 44px;
			display: flex;
			align-items: center;
		}
		.reanalyze-btn {
			min-height: 44px;
			padding: 0.6rem 1rem;
		}

		/* 모바일: 하단 sticky 저장 버튼 */
		.recipe-bottom-bar {
			position: sticky;
			bottom: 0;
			padding: 0.75rem 1rem;
			background: var(--color-paper);
			border-top: 1px solid var(--color-light-line);
			margin-left: calc(-1 * var(--page-padding-mobile));
			margin-right: calc(-1 * var(--page-padding-mobile));
			z-index: 50;
		}
		.save-btn-bottom {
			width: 100%;
			min-height: 52px;
			font-size: 1rem;
			border-radius: 8px;
			padding: 0.75rem 1rem;
		}
	}
</style>
