<script lang="ts">
	import type { CollectionItem, CollectionTag } from '$lib/types';
	import StarRating from './StarRating.svelte';
	import TagBadge from './TagBadge.svelte';
	import TagPopover from './TagPopover.svelte';

	interface Props {
		item: CollectionItem;
		allTags: CollectionTag[];
		onfavorite: (id: number) => void;
		ontagattach: (collectionId: number, tagId: number) => void;
		ontagdetach: (collectionId: number, tagId: number) => void;
		ontagcreate: (collectionId: number, name: string, color: string) => void;
		onrate: (collectionId: number, rating: number) => void;
	}

	let { item, allTags, onfavorite, ontagattach, ontagdetach, ontagcreate, onrate }: Props = $props();

	let showTagPopover = $state(false);

	const thumbUrl = $derived(
		item.recipe.video_id
			? `https://img.youtube.com/vi/${item.recipe.video_id}/mqdefault.jpg`
			: null
	);

	const displayCategory = $derived(item.category_override ?? item.recipe.category);

	const isRegular = $derived(item.cooked_count >= 3);
</script>

<article class="recipe-card">
	<!-- 썸네일 영역 -->
	<a href="/library/{item.id}" class="thumb-link" tabindex="-1" aria-hidden="true">
		<div class="thumb">
			{#if thumbUrl}
				<img src={thumbUrl} alt="{item.recipe.title} 썸네일" loading="lazy" />
			{:else}
				<div class="thumb-placeholder">🍳</div>
			{/if}
			<!-- 즐겨찾기 버튼 -->
			<button
				type="button"
				class="fav-btn"
				class:active={item.is_favorite}
				aria-label={item.is_favorite ? '즐겨찾기 해제' : '즐겨찾기 추가'}
				onclick={(e) => { e.preventDefault(); onfavorite(item.id); }}
			>⭐</button>
		</div>
	</a>

	<!-- 카드 본문 -->
	<div class="card-body">
		<!-- 제목 -->
		<a href="/library/{item.id}" class="title-link">
			<h3 class="title">{item.recipe.title}</h3>
		</a>

		<!-- 카테고리 + 단골 뱃지 -->
		<div class="badges">
			{#if displayCategory}
				<span class="category-badge">{displayCategory}</span>
			{/if}
			{#if isRegular}
				<span class="regular-badge">단골 레시피 🏆</span>
			{/if}
		</div>

		<!-- 태그 목록 -->
		<div class="tags-row">
			{#each item.tags as tag}
				<TagBadge {tag} removable={false} />
			{/each}

			<!-- +태그 버튼 + 팝오버 -->
			<div class="tag-add-wrap">
				<button
					type="button"
					class="add-tag-btn"
					onclick={() => (showTagPopover = !showTagPopover)}
				>+태그</button>

				{#if showTagPopover}
					<TagPopover
						{allTags}
						attachedTagIds={item.tags.map(t => t.id)}
						onclose={() => (showTagPopover = false)}
						onattach={(tagId) => ontagattach(item.id, tagId)}
						ondetach={(tagId) => ontagdetach(item.id, tagId)}
						oncreate={(name, color) => { ontagcreate(item.id, name, color); showTagPopover = false; }}
					/>
				{/if}
			</div>
		</div>

		<!-- 별점 + 요리 횟수 + 날짜 -->
		<div class="card-meta">
			<div class="meta-left">
				<StarRating
					rating={item.my_rating}
					size="sm"
					onchange={(r) => onrate(item.id, r)}
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
	}
	.recipe-card:hover {
		box-shadow: 0 6px 20px rgba(0,0,0,0.1);
		transform: translateY(-2px);
	}

	/* 썸네일 */
	.thumb-link { display: block; }
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
	}

	.title-link { text-decoration: none; }
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
	.title-link:hover .title { color: var(--color-terracotta); }

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
	.tag-add-wrap {
		position: relative;
	}
	.add-tag-btn {
		font-size: 0.7rem;
		font-weight: 600;
		padding: 0.1rem 0.45rem;
		border-radius: 10px;
		border: 1px dashed var(--color-soft-brown);
		background: none;
		color: var(--color-soft-brown);
	}
	.add-tag-btn:hover {
		border-color: var(--color-terracotta);
		color: var(--color-terracotta);
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
