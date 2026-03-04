<script lang="ts">
	import type { CollectionItem, CollectionTag } from '$lib/types';
	import StarRating from './StarRating.svelte';
	import TagBadge from './TagBadge.svelte';

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
</script>

<article class="recipe-card">
	<!-- 카드 전체 링크 (absolute overlay) -->
	<a href="/my-recipes/{item.id}" class="card-link" aria-label="{item.recipe.title} 상세 보기"></a>

	<!-- 썸네일 영역 -->
	<div class="thumb">
		{#if thumbUrl}
			<img src={thumbUrl} alt="{item.recipe.title} 썸네일" loading="lazy" />
		{:else}
			<div class="thumb-placeholder">🍳</div>
		{/if}

		<!-- 좌상단 메타 오버레이 -->
		{#if item.recipe.cooking_time || item.recipe.difficulty || item.recipe.servings}
			<div class="thumb-meta">
				{#if item.recipe.cooking_time}
					<span class="thumb-badge">🍳 {item.recipe.cooking_time}</span>
				{/if}
				{#if item.recipe.difficulty}
					<span class="thumb-badge">{item.recipe.difficulty}</span>
				{/if}
				{#if item.recipe.servings}
					<span class="thumb-badge">👥 {item.recipe.servings}</span>
				{/if}
			</div>
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
		<!-- 제목: 순수 요리명 -->
		<h3 class="title">{item.recipe.title}</h3>

		{#if item.recipe.channel_name}
			<span class="channel-name">{item.recipe.channel_name}</span>
		{/if}

		<!-- 카테고리 + 단골 뱃지 -->
		<div class="badges">
			{#if displayCategory}
				<span class="category-badge">{displayCategory}</span>
			{/if}
			{#if isRegular}
				<span class="regular-badge">단골 레시피 🏆</span>
			{/if}
		</div>

		<!-- 태그 목록 (읽기 전용) -->
		{#if item.tags.length > 0}
			<div class="tags-row">
				{#each item.tags as tag}
					<TagBadge {tag} removable={false} />
				{/each}
			</div>
		{/if}

		<!-- 별점 + 요리 횟수 + 날짜 -->
		<div class="card-meta">
			<div class="meta-left">
				<StarRating
					rating={item.my_rating}
					size="sm"
					readonly
				/>
				{#if item.cooked_count > 0}
					<span class="cooked-count">🍳 {item.cooked_count}회</span>
				{/if}
			</div>
			<span class="saved-date">
				{new Date(item.created_at).toLocaleDateString('ko-KR', { month: 'numeric', day: 'numeric' })} 저장
			</span>
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

	/* 카드 전체 링크 */
	.card-link {
		position: absolute;
		inset: 0;
		z-index: 0;
	}

	/* 썸네일 */
	.thumb {
		position: relative;
		aspect-ratio: 16 / 9;
		background: var(--color-cream);
		overflow: hidden;
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

	/* 좌상단 메타 오버레이 */
	.thumb-meta {
		position: absolute;
		top: 0.4rem;
		left: 0.4rem;
		display: flex;
		flex-direction: row;
		gap: 0.25rem;
		z-index: 1;
	}
	.thumb-badge {
		display: inline-block;
		background: rgba(0,0,0,0.52);
		color: white;
		font-size: 0.7rem;
		font-weight: 600;
		padding: 0.15rem 0.45rem;
		border-radius: 20px;
		backdrop-filter: blur(4px);
		white-space: nowrap;
	}

	/* 즐겨찾기 버튼 */
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
		z-index: 1;
	}
	.fav-btn.active { filter: grayscale(0); }
	.fav-btn:hover { transform: scale(1.15); }

	/* 카드 본문 */
	.card-body {
		padding: 0.9rem 1rem 0.8rem;
		display: flex;
		flex-direction: column;
		gap: 0.45rem;
		flex: 1;
		position: relative;
		z-index: 1;
		pointer-events: none;
	}

	/* 카드 본문 내 인터랙션 필요한 요소만 살리기 */
	.card-body .tags-row,
	.card-body .card-meta {
		pointer-events: auto;
	}

	.title {
		font-size: 0.95rem;
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
		font-size: 0.75rem;
		color: var(--color-soft-brown);
		opacity: 0.8;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	/* 뱃지 */
	.badges {
		display: flex;
		flex-wrap: wrap;
		gap: 0.3rem;
	}
	.category-badge {
		font-size: 0.7rem;
		font-weight: 600;
		color: var(--color-terracotta);
		background: color-mix(in srgb, var(--color-terracotta) 12%, transparent);
		border-radius: 10px;
		padding: 0.1rem 0.45rem;
	}
	.regular-badge {
		font-size: 0.7rem;
		font-weight: 600;
		color: #8B6914;
		background: #FFF3CD;
		border-radius: 10px;
		padding: 0.1rem 0.45rem;
	}

	/* 태그 행 */
	.tags-row {
		display: flex;
		flex-wrap: wrap;
		gap: 0.3rem;
		align-items: center;
		min-height: 22px;
	}
/* 메타 정보 */
	.card-meta {
		display: flex;
		align-items: center;
		justify-content: space-between;
		margin-top: auto;
		padding-top: 0.3rem;
	}
	.meta-left {
		display: flex;
		align-items: center;
		gap: 0.5rem;
	}
	.cooked-count {
		font-size: 0.78rem;
		color: var(--color-soft-brown);
	}
	.saved-date {
		font-size: 0.72rem;
		color: var(--color-soft-brown);
	}
</style>
