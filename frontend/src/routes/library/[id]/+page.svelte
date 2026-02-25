<script lang="ts">
	import type { PageData } from './$types';
	import FlavorProfile from '$lib/components/FlavorProfile.svelte';
	import IngredientList from '$lib/components/IngredientList.svelte';
	import StepTimeline from '$lib/components/StepTimeline.svelte';

	let { data }: { data: PageData } = $props();
	const item = $derived(data.item);
	const recipe = $derived(data.item.recipe);
</script>

<main class="page-wrap">
	<section class="recipe-page">
		<div class="recipe-top-bar">
			<a href="/library" class="back-link">← 레시피북으로</a>
			<span class="saved-date">
				{new Date(item.created_at).toLocaleDateString('ko-KR', { year: 'numeric', month: 'long', day: 'numeric' })} 저장
			</span>
		</div>

		<article class="recipe-card">
			<h1 class="recipe-title">{recipe.title}</h1>

			{#if recipe.summary}
				<p class="recipe-summary">{recipe.summary}</p>
			{/if}

			<FlavorProfile flavor={recipe.flavor} />

			<IngredientList ingredients={recipe.ingredients} />

			<StepTimeline steps={recipe.steps} />

			{#if item.custom_tip}
				<div class="tip-section">
					<div class="section-divider">
						<span class="divider-line"></span>
						<span class="divider-text">내 메모</span>
						<span class="divider-line"></span>
					</div>
					<div class="tip-card memo">
						<p>{item.custom_tip}</p>
					</div>
				</div>
			{/if}

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
	</section>
</main>

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
	}

	.back-link {
		color: var(--color-soft-brown);
		font-size: 0.9rem;
		font-weight: 500;
		text-decoration: none;
	}
	.back-link:hover { color: var(--color-terracotta); }

	.saved-date {
		font-size: 0.85rem;
		color: var(--color-soft-brown);
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
	.divider-line {
		flex: 1;
		height: 1px;
		background: var(--color-light-line);
	}
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
	.tip-card.memo {
		background: var(--color-cream);
		font-style: italic;
	}

	.video-link-area {
		margin-top: 2rem;
		text-align: center;
		padding-top: 1.5rem;
		border-top: 1px solid var(--color-light-line);
	}
	.video-link {
		font-size: 0.9rem;
		color: var(--color-dusty-blue);
	}

	@media (max-width: 767px) {
		.page-wrap { padding: 0 var(--page-padding-mobile); }
		.recipe-card { padding: 1.5rem; }
		.recipe-title { font-size: 1.4rem; }
		.recipe-top-bar { flex-wrap: wrap; gap: 0.5rem; }
	}
</style>
