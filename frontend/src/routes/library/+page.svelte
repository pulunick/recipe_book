<script lang="ts">
	import { onMount } from 'svelte';
	import { fade } from 'svelte/transition';
	import type { CollectionItem } from '$lib/types';
	import { getCollections } from '$lib/api';
	import RecipeCard from '$lib/components/RecipeCard.svelte';

	let collections: CollectionItem[] = $state([]);
	let loading = $state(true);
	let error = $state('');

	onMount(async () => {
		try {
			collections = await getCollections();
		} catch (e: unknown) {
			error = e instanceof Error ? e.message : '보관함을 불러오지 못했습니다.';
		} finally {
			loading = false;
		}
	});
</script>

<svelte:head>
	<title>내 레시피북 | 입맛 저격 레시피 AI</title>
</svelte:head>

<main class="page-wrap">
	<header class="library-header">
		<h1>내 레시피북</h1>
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
		<div class="recipe-list" in:fade>
			{#each collections as item (item.id)}
				<RecipeCard {item} />
			{/each}
		</div>
	{/if}
</main>

<style>
	.page-wrap {
		max-width: var(--recipe-max-width, 720px);
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

	.recipe-list {
		background: white;
		border-radius: 12px;
		box-shadow: 0 2px 8px rgba(0,0,0,0.06);
		overflow: hidden;
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
	}
</style>
