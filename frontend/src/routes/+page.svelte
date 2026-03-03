<script lang="ts">
	import { goto } from '$app/navigation';
	import type { PageStatus } from '$lib/types';
	import { extractRecipe } from '$lib/api';
	import SearchBox from '$lib/components/SearchBox.svelte';
	import LoadingScreen from '$lib/components/LoadingScreen.svelte';

	let status: PageStatus = $state('IDLE');
	let errorMessage = $state('');
	let currentVideoId: string | null = $state(null);

	function getVideoId(url: string): string | null {
		const m = url.match(/(?:v=|\/|youtu\.be\/|embed\/|shorts\/)([0-9A-Za-z_-]{11})/);
		return m ? m[1] : null;
	}

	async function handleAnalyze(url: string) {
		status = 'LOADING';
		errorMessage = '';
		currentVideoId = getVideoId(url);
		try {
			const recipe = await extractRecipe(url);
			// 분석 완료 → 결과 페이지로 이동 (recipe와 sourceUrl을 state로 전달)
			await goto(`/recipe/${recipe.video_id ?? recipe.id}`, {
				state: { recipe, sourceUrl: url }
			});
		} catch (e: unknown) {
			status = 'ERROR';
			errorMessage = e instanceof Error ? e.message : '알 수 없는 오류가 발생했습니다.';
		}
	}
</script>

<svelte:head>
	<title>마레픽 — AI 레시피 정리</title>
</svelte:head>

<main class="page-wrap">
	<section class="home">
		<div class="hero-text">
			<h1>유튜브 요리 영상의 레시피를<br />깔끔하게 정리해드려요</h1>
		</div>
		<SearchBox
			onsubmit={handleAnalyze}
			disabled={status === 'LOADING'}
			errorMessage={status === 'ERROR' ? errorMessage : ''}
		/>
		{#if status === 'LOADING'}
			<LoadingScreen videoId={currentVideoId} />
		{:else}
			<p class="how-to">
				링크 붙여넣기 → 버튼 누르기<br />
				재료와 만드는 법이 한 페이지로 정리돼요
			</p>
		{/if}
	</section>
</main>

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

	@media (max-width: 767px) {
		.page-wrap { padding: 0 var(--page-padding-mobile); }
		.hero-text h1 { font-size: 1.4rem; }
	}
</style>
