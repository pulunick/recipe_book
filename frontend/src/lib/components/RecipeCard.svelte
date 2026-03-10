<script lang="ts">
	import type { CollectionItem } from '$lib/types';
	import StarRating from './StarRating.svelte';

	interface Props {
		item: CollectionItem;
		onfavorite: (id: number) => void;
	}

	let { item, onfavorite }: Props = $props();

	const thumbUrl = $derived(
		item.recipe.video_id
			? `https://img.youtube.com/vi/${item.recipe.video_id}/mqdefault.jpg`
			: null
	);

	const displayCategory = $derived(item.category_override ?? item.recipe.category);
	const isRegular = $derived(item.cooked_count >= 3);

	// 태그 최대 2개 + 초과 수
	const visibleTags = $derived(item.tags.slice(0, 2));
	const extraTagCount = $derived(Math.max(0, item.tags.length - 2));
</script>

<article class="recipe-card">
	<!-- 카드 전체 링크 -->
	<a href="/my-recipes/{item.id}" class="card-link" aria-label="{item.recipe.title} 상세 보기"></a>

	<!-- 썸네일 -->
	<div class="thumb">
		{#if thumbUrl}
			<img src={thumbUrl} alt="{item.recipe.title} 썸네일" loading="lazy" />
		{:else}
			<div class="thumb-placeholder">🍳</div>
		{/if}

		<!-- 좌상단: 요리 시간만 -->
		{#if item.recipe.cooking_time}
			<span class="thumb-badge">⏱ {item.recipe.cooking_time}</span>
		{/if}

		<!-- 즐겨찾기 버튼 -->
		<button
			type="button"
			class="fav-btn"
			class:active={item.is_favorite}
			aria-label={item.is_favorite ? '즐겨찾기 해제' : '즐겨찾기 추가'}
			onclick={(e) => { e.stopPropagation(); onfavorite(item.id); }}
		>⭐</button>
	</div>

	<!-- 카드 본문 -->
	<div class="card-body">
		<h3 class="title">{item.recipe.title}</h3>

		{#if item.recipe.channel_name}
			<span class="channel-name">{item.recipe.channel_name}</span>
		{/if}

		<!-- 카테고리 + 단골 배지 -->
		<div class="badges">
			{#if displayCategory}
				<span class="category-badge">{displayCategory}</span>
			{/if}
			{#if isRegular}
				<span class="regular-badge">🏆 단골</span>
			{/if}
		</div>

		<!-- 태그 (최대 2개 + +N) -->
		{#if item.tags.length > 0}
			<div class="tags-row">
				{#each visibleTags as tag}
					<span class="tag-chip" style:background={tag.color + '33'} style:color={tag.color}>{tag.name}</span>
				{/each}
				{#if extraTagCount > 0}
					<span class="tag-extra">+{extraTagCount}</span>
				{/if}
			</div>
		{/if}

		<!-- 별점 -->
		<div class="card-meta">
			<StarRating rating={item.my_rating} size="sm" readonly />
		</div>
	</div>
</article>

<style>
	.recipe-card {
		background: white;
		border-radius: 12px;
		overflow: hidden;
		box-shadow: 0 2px 8px rgba(0,0,0,0.06);
		transition: box-shadow 0.2s, transform 0.2s;
		display: flex;
		flex-direction: column;
		position: relative;
		cursor: pointer;
	}
	.recipe-card:hover {
		box-shadow: 0 6px 20px rgba(0,0,0,0.1);
		transform: translateY(-2px);
	}

	.card-link {
		position: absolute;
		inset: 0;
		z-index: 1;
	}

	/* 썸네일 */
	.thumb {
		position: relative;
		aspect-ratio: 16 / 9;
		background: var(--color-cream);
		overflow: hidden;
		flex-shrink: 0;
	}
	.thumb img {
		width: 100%;
		height: 100%;
		object-fit: cover;
		display: block;
	}
	.thumb-placeholder {
		display: flex;
		align-items: center;
		justify-content: center;
		height: 100%;
		font-size: 2.5rem;
		color: var(--color-light-line);
	}

	/* 요리 시간 뱃지 */
	.thumb-badge {
		position: absolute;
		top: 0.4rem;
		left: 0.4rem;
		background: rgba(0,0,0,0.52);
		color: white;
		font-size: 0.68rem;
		font-weight: 600;
		padding: 0.15rem 0.45rem;
		border-radius: 20px;
		backdrop-filter: blur(4px);
		white-space: nowrap;
		z-index: 1;
	}

	/* 즐겨찾기 */
	.fav-btn {
		position: absolute;
		top: 0.5rem;
		right: 0.5rem;
		background: rgba(255,255,255,0.85);
		border: none;
		border-radius: 50%;
		width: 32px;
		height: 32px;
		display: flex;
		align-items: center;
		justify-content: center;
		font-size: 1rem;
		box-shadow: 0 1px 4px rgba(0,0,0,0.1);
		filter: grayscale(1);
		transition: filter 0.2s, transform 0.2s;
		z-index: 2;
	}
	.fav-btn.active { filter: grayscale(0); }
	.fav-btn:hover { transform: scale(1.15); }

	/* 카드 본문 */
	.card-body {
		padding: 0.75rem 0.85rem 0.7rem;
		display: flex;
		flex-direction: column;
		gap: 0.35rem;
		flex: 1;
		position: relative;
		z-index: 1;
		pointer-events: none;
	}
	.card-body .tags-row,
	.card-body .card-meta {
		pointer-events: auto;
	}

	.title {
		font-size: 0.9rem;
		font-weight: 600;
		color: var(--color-warm-brown);
		line-height: 1.4;
		display: -webkit-box;
		-webkit-line-clamp: 2;
		line-clamp: 2;
		-webkit-box-orient: vertical;
		overflow: hidden;
	}
	.recipe-card:hover .title { color: var(--color-terracotta); }

	.channel-name {
		font-size: 0.72rem;
		color: var(--color-soft-brown);
		opacity: 0.8;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	/* 배지 */
	.badges {
		display: flex;
		flex-wrap: wrap;
		gap: 0.25rem;
		min-height: 0;
	}
	.category-badge {
		font-size: 0.68rem;
		font-weight: 600;
		color: var(--color-terracotta);
		background: color-mix(in srgb, var(--color-terracotta) 12%, transparent);
		border-radius: 10px;
		padding: 0.1rem 0.4rem;
	}
	.regular-badge {
		font-size: 0.68rem;
		font-weight: 600;
		color: #8B6914;
		background: #FFF3CD;
		border-radius: 10px;
		padding: 0.1rem 0.4rem;
	}

	/* 태그 — 1줄 고정 */
	.tags-row {
		display: flex;
		flex-wrap: nowrap;
		gap: 0.25rem;
		align-items: center;
		overflow: hidden;
		height: 20px;
	}
	.tag-chip {
		font-size: 0.65rem;
		font-weight: 600;
		padding: 0.1rem 0.4rem;
		border-radius: 10px;
		white-space: nowrap;
		flex-shrink: 0;
	}
	.tag-extra {
		font-size: 0.65rem;
		color: var(--color-soft-brown);
		flex-shrink: 0;
	}

	/* 별점 */
	.card-meta {
		margin-top: auto;
		padding-top: 0.2rem;
	}
</style>
