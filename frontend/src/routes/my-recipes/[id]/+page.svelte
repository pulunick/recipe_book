<script lang="ts">
	import { goto } from '$app/navigation';
	import { page } from '$app/state';
	import { untrack, onMount } from 'svelte';
	import type { PageData } from './$types';
	import type { CollectionTag } from '$lib/types';
	import FlavorProfile from '$lib/components/FlavorProfile.svelte';
	import IngredientList from '$lib/components/IngredientList.svelte';
	import StepTimeline from '$lib/components/StepTimeline.svelte';
	import StarRating from '$lib/components/StarRating.svelte';
	import TagBadge from '$lib/components/TagBadge.svelte';
	import TagPopover from '$lib/components/TagPopover.svelte';
	import VideoCard from '$lib/components/VideoCard.svelte';
	import ScrollToTop from '$lib/components/ScrollToTop.svelte';
	import Toast from '$lib/components/Toast.svelte';
	import { UtensilsCrossed } from 'lucide-svelte';
	import {
		extractRecipe,
		deleteFromCollection,
		updateCollection,
		setRating,
		recordCooked,
		getTags,
		createTag,
		setCollectionTags
	} from '$lib/api';

	let { data }: { data: PageData } = $props();

	// 로컬 상태로 복사 (즉시 업데이트 반영, untrack으로 초기값 추적 경고 억제)
	let item = $state(untrack(() => data.item));
	const recipe = $derived(item.recipe);
	let allTags = $state<CollectionTag[]>(untrack(() => data.allTags ?? []));

	// 삭제 상태
	let isConfirmingDelete = $state(false);
	let isDeleting = $state(false);

	// 메모 편집 상태
	let isEditingMemo = $state(false);
	let memoText = $state(untrack(() => data.item.custom_tip ?? ''));

	// data props 변경 시 로컬 상태 동기화 (라우트 이동 대응)
	$effect(() => {
		item = data.item;
		allTags = data.allTags ?? [];
		memoText = data.item.custom_tip ?? '';
	});
	let isSavingMemo = $state(false);

	// 재분석 상태
	let isReanalyzing = $state(false);

	async function handleReanalyze() {
		const videoUrl = recipe.video_url ?? (recipe.video_id ? `https://www.youtube.com/watch?v=${recipe.video_id}` : null);
		if (!videoUrl) return;
		isReanalyzing = true;
		try {
			const updated = await extractRecipe(videoUrl, true);
			item = { ...item, recipe: updated };
			triggerToast('재분석 완료!');
		} catch (e) {
			triggerToast(e instanceof Error ? e.message : '재분석 중 오류가 발생했습니다.');
		} finally {
			isReanalyzing = false;
		}
	}

	// 요리 기록 상태
	let isCooking = $state(false);

	// 태그 팝오버 상태
	let showTagPopover = $state(false);

	// 토스트
	let showToast = $state(false);
	let toastMessage = $state('');

	function triggerToast(msg: string) {
		toastMessage = msg;
		showToast = true;
	}

	// 자동 저장으로 이동 시 "추가됐어요" 토스트
	onMount(() => {
		if (page.state.justAdded) {
			triggerToast('레시피북에 추가됐어요!');
		}
	});

	// 별점 변경
	async function handleRating(rating: number) {
		const prevRating = item.my_rating;
		item = { ...item, my_rating: rating };
		try {
			await setRating(item.id, rating);
		} catch {
			item = { ...item, my_rating: prevRating };
			triggerToast('별점 저장 중 오류가 발생했습니다.');
		}
	}

	// 요리 기록
	async function handleCooked() {
		isCooking = true;
		const prevCount = item.cooked_count;
		const prevDate = item.last_cooked_at;
		item = {
			...item,
			cooked_count: item.cooked_count + 1,
			last_cooked_at: new Date().toISOString()
		};
		try {
			await recordCooked(item.id);
			triggerToast('요리 기록이 추가되었습니다!');
		} catch {
			item = { ...item, cooked_count: prevCount, last_cooked_at: prevDate };
			triggerToast('기록 중 오류가 발생했습니다.');
		} finally {
			isCooking = false;
		}
	}

	// 태그 부착
	async function handleTagAttach(tagId: number) {
		const tag = allTags.find(t => t.id === tagId);
		if (!tag || item.tags.some(t => t.id === tagId)) return;
		item = { ...item, tags: [...item.tags, tag] };
		try {
			await setCollectionTags(item.id, item.tags.map(t => t.id));
		} catch {
			item = { ...item, tags: item.tags.filter(t => t.id !== tagId) };
			triggerToast('태그 부착 중 오류가 발생했습니다.');
		}
	}

	// 태그 해제
	async function handleTagDetach(tagId: number) {
		const prevTags = item.tags;
		item = { ...item, tags: item.tags.filter(t => t.id !== tagId) };
		try {
			await setCollectionTags(item.id, item.tags.map(t => t.id));
		} catch {
			item = { ...item, tags: prevTags };
			triggerToast('태그 해제 중 오류가 발생했습니다.');
		}
	}

	// 태그 생성 후 부착
	async function handleTagCreate(name: string, color: string) {
		try {
			const newTag = await createTag(name, color);
			allTags = [...allTags, newTag];
			await handleTagAttach(newTag.id);
			triggerToast(`"${name}" 태그가 추가됐어요`);
		} catch (e) {
			const msg = e instanceof Error ? e.message : '태그 생성에 실패했어요';
			triggerToast(msg);
		}
	}

	// 태그 제거 (뱃지에서)
	function handleTagRemove(tagId: number) {
		handleTagDetach(tagId);
	}

	async function confirmDelete() {
		isDeleting = true;
		try {
			await deleteFromCollection(item.id);
			goto('/my-recipes');
		} catch {
			isDeleting = false;
			isConfirmingDelete = false;
			triggerToast('삭제 중 오류가 발생했습니다.');
		}
	}

	async function saveMemo() {
		isSavingMemo = true;
		try {
			await updateCollection(item.id, memoText);
			item = { ...item, custom_tip: memoText || null };
			isEditingMemo = false;
			triggerToast('메모가 저장되었습니다.');
		} catch {
			triggerToast('저장 중 오류가 발생했습니다.');
		} finally {
			isSavingMemo = false;
		}
	}

	function cancelEdit() {
		memoText = item.custom_tip ?? '';
		isEditingMemo = false;
	}

	const attachedTagIds = $derived(item.tags.map(t => t.id));

	// 채널명 + 영상 제목 서브라인
	const sourceLineParts = $derived.by(() => {
		const parts: string[] = [];
		if (recipe.channel_name) parts.push(recipe.channel_name);
		if (recipe.video_title) parts.push(recipe.video_title);
		return parts;
	});
	const sourceLine = $derived(sourceLineParts.join(' \u00b7 '));
</script>

<svelte:head>
	<title>{recipe.title} | 내 레시피북</title>
</svelte:head>

<main class="page-wrap">
	<section class="recipe-page">
		<div class="recipe-top-bar">
			<a href="/my-recipes" class="back-link">← 레시피북으로</a>
			<div class="top-bar-right">
				<span class="saved-date">
					{new Date(item.created_at).toLocaleDateString('ko-KR', { year: 'numeric', month: 'long', day: 'numeric' })} 저장
				</span>
				<button class="btn-reanalyze" onclick={handleReanalyze} disabled={isReanalyzing}>
					{isReanalyzing ? '분석 중...' : '다시 분석'}
				</button>
				{#if isConfirmingDelete}
					<span class="confirm-delete">
						정말 삭제할까요?
						<button class="btn-confirm" onclick={confirmDelete} disabled={isDeleting}>
							{isDeleting ? '삭제 중...' : '삭제'}
						</button>
						<button class="btn-cancel" onclick={() => isConfirmingDelete = false} disabled={isDeleting}>취소</button>
					</span>
				{:else}
					<button class="btn-delete" onclick={() => isConfirmingDelete = true}>삭제</button>
				{/if}
			</div>
		</div>

		<article class="recipe-card">
			<h1 class="recipe-title">{recipe.title}{recipe.channel_name ? ` - ${recipe.channel_name}` : ''}</h1>

			{#if sourceLine}
				<p class="source-line">{sourceLine}</p>
			{/if}

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

			<!-- 별점 + 요리횟수 -->
			<div class="meta-row">
				<div class="rating-area">
					<StarRating rating={item.my_rating} onchange={handleRating} />
					{#if item.my_rating}
						<span class="rating-label">{item.my_rating}점</span>
					{:else}
						<span class="rating-label muted">별점을 매겨보세요</span>
					{/if}
				</div>

				<div class="cooked-area">
					<button class="btn-cooked" onclick={handleCooked} disabled={isCooking}>
						{isCooking ? '기록 중...' : '오늘 요리했어요'} <UtensilsCrossed size={16} />
					</button>
					<span class="cooked-count">{item.cooked_count}회 요리</span>
					{#if item.last_cooked_at}
						<span class="last-cooked">
							마지막: {new Date(item.last_cooked_at).toLocaleDateString('ko-KR', { month: 'short', day: 'numeric' })}
						</span>
					{/if}
				</div>
			</div>

			<!-- 태그 영역 -->
			<div class="tags-area">
				{#each item.tags as tag (tag.id)}
					<TagBadge {tag} removable onremove={handleTagRemove} />
				{/each}
				<div class="tag-add-wrap">
					<button class="btn-add-tag" onclick={() => showTagPopover = !showTagPopover}>
						+ 태그
					</button>
					{#if showTagPopover}
						<TagPopover
							{allTags}
							{attachedTagIds}
							onclose={() => showTagPopover = false}
							onattach={handleTagAttach}
							ondetach={handleTagDetach}
							oncreate={handleTagCreate}
						/>
					{/if}
				</div>
			</div>

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
					<div class="tip-card">
						<span class="tip-label">✦ 꿀팁</span>
						<p>{recipe.tip}</p>
					</div>
				</div>
			{/if}

			<div class="memo-section">
				<div class="memo-card">
					<div class="memo-card-header">
						<span class="memo-label">✎ 내 메모</span>
						{#if !isEditingMemo}
							<button
								class="btn-memo-edit"
								onclick={() => isEditingMemo = true}
							>
								{item.custom_tip ? '수정' : '+ 추가'}
							</button>
						{/if}
					</div>

					{#if isEditingMemo}
						<textarea
							class="memo-textarea"
							bind:value={memoText}
							placeholder="이 레시피에 대한 나만의 메모..."
							rows="3"
						></textarea>
						<div class="memo-actions">
							<button class="btn-save" onclick={saveMemo} disabled={isSavingMemo}>
								{isSavingMemo ? '저장 중...' : '저장'}
							</button>
							<button class="btn-cancel-memo" onclick={cancelEdit} disabled={isSavingMemo}>취소</button>
						</div>
					{:else if item.custom_tip}
						<p class="memo-text">{item.custom_tip}</p>
					{:else}
						<p class="empty-memo">아직 메모가 없어요</p>
					{/if}
				</div>
			</div>

			<VideoCard
				videoId={recipe.video_id}
				videoUrl={recipe.video_url}
				channelName={recipe.channel_name}
				videoTitle={recipe.video_title}
			/>
		</article>
	</section>
</main>

<ScrollToTop />

<Toast message={toastMessage} show={showToast} ondismiss={() => showToast = false} />

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
		flex-wrap: wrap;
		gap: 0.5rem;
	}

	.back-link {
		color: var(--color-soft-brown);
		font-size: 0.9rem;
		font-weight: 500;
		text-decoration: none;
	}
	.back-link:hover { color: var(--color-terracotta); }

	.top-bar-right {
		display: flex;
		align-items: center;
		gap: 0.8rem;
		flex-wrap: wrap;
	}

	.saved-date {
		font-size: 0.85rem;
		color: var(--color-soft-brown);
	}

	.btn-reanalyze {
		font-size: 0.82rem;
		color: var(--color-soft-brown);
		background: none;
		border: 1px solid var(--color-light-line);
		border-radius: 6px;
		padding: 0.3rem 0.7rem;
		cursor: pointer;
		transition: border-color 0.15s, color 0.15s;
	}
	.btn-reanalyze:hover:not(:disabled) {
		border-color: var(--color-soft-brown);
		color: var(--color-warm-brown);
	}
	.btn-reanalyze:disabled { opacity: 0.6; cursor: not-allowed; }

	.btn-delete {
		font-size: 0.82rem;
		color: var(--color-muted-red, #c0392b);
		background: none;
		border: 1px solid var(--color-muted-red, #c0392b);
		border-radius: 6px;
		padding: 0.3rem 0.7rem;
		cursor: pointer;
		transition: background 0.15s, color 0.15s;
	}
	.btn-delete:hover {
		background: var(--color-muted-red, #c0392b);
		color: white;
	}

	.confirm-delete {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		font-size: 0.85rem;
		color: var(--color-warm-brown);
	}

	.btn-confirm {
		font-size: 0.82rem;
		background: var(--color-muted-red, #c0392b);
		color: white;
		border: none;
		border-radius: 6px;
		padding: 0.3rem 0.7rem;
		cursor: pointer;
	}
	.btn-confirm:disabled { opacity: 0.6; cursor: not-allowed; }

	.btn-cancel {
		font-size: 0.82rem;
		background: none;
		border: 1px solid var(--color-light-line);
		border-radius: 6px;
		padding: 0.3rem 0.7rem;
		cursor: pointer;
		color: var(--color-soft-brown);
	}
	.btn-cancel:disabled { opacity: 0.6; cursor: not-allowed; }

	.recipe-card {
		background: white;
		border-radius: 12px;
		padding: 2.5rem;
		box-shadow: 0 2px 8px rgba(0,0,0,0.06);
	}

	.recipe-title {
		font-size: 1.8rem;
		margin-bottom: 0.5rem;
		text-align: center;
	}

	.source-line {
		font-size: 0.82rem;
		color: var(--color-soft-brown);
		text-align: center;
		margin-bottom: 1.2rem;
		opacity: 0.8;
	}

	/* 별점 + 요리횟수 메타 영역 */
	.meta-row {
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 2rem;
		flex-wrap: wrap;
		margin-bottom: 1rem;
		padding: 0.8rem 0;
		border-bottom: 1px solid var(--color-light-line);
	}

	.rating-area {
		display: flex;
		align-items: center;
		gap: 0.5rem;
	}
	.rating-label {
		font-size: 0.82rem;
		color: var(--color-warm-brown);
		font-weight: 600;
	}
	.rating-label.muted {
		color: var(--color-soft-brown);
		font-weight: 400;
		opacity: 0.7;
	}

	.cooked-area {
		display: flex;
		align-items: center;
		gap: 0.6rem;
		flex-wrap: wrap;
	}
	.btn-cooked {
		font-size: 0.82rem;
		background: var(--color-warm-yellow, #fff3cd);
		border: 1px solid color-mix(in srgb, var(--color-warm-yellow, #fff3cd) 70%, #a67c00);
		border-radius: 8px;
		padding: 0.35rem 0.8rem;
		cursor: pointer;
		font-weight: 600;
		color: var(--color-warm-brown);
		transition: background 0.15s;
	}
	.btn-cooked:hover {
		background: color-mix(in srgb, var(--color-warm-yellow, #fff3cd) 80%, #f5a623);
	}
	.btn-cooked:disabled { opacity: 0.6; cursor: not-allowed; }

	.cooked-count {
		font-size: 0.82rem;
		font-weight: 600;
		color: var(--color-warm-brown);
	}
	.last-cooked {
		font-size: 0.75rem;
		color: var(--color-soft-brown);
	}

	/* 태그 영역 */
	.tags-area {
		display: flex;
		align-items: center;
		justify-content: center;
		flex-wrap: wrap;
		gap: 0.4rem;
		margin-bottom: 1.2rem;
	}
	.tags-area :global(.tag-badge) {
		font-size: 0.88rem;
		padding: 0.3rem 0.75rem;
	}
	.tag-add-wrap {
		position: relative;
	}
	.btn-add-tag {
		font-size: 0.88rem;
		font-weight: 600;
		padding: 0.3rem 0.75rem;
		border-radius: 10px;
		border: 1px dashed var(--color-light-line);
		background: none;
		color: var(--color-soft-brown);
		cursor: pointer;
		transition: border-color 0.15s, color 0.15s;
	}
	.btn-add-tag:hover {
		border-color: var(--color-terracotta);
		color: var(--color-terracotta);
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

	/* 꿀팁 */
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

	/* 내 메모 */
	.memo-section { margin-top: 2rem; }
	.memo-card {
		border-left: 4px solid var(--color-dusty-blue);
		background: var(--color-cream);
		padding: 1rem 1.2rem;
		border-radius: 0 8px 8px 0;
	}
	.memo-card-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		margin-bottom: 0.5rem;
	}
	.memo-label {
		font-size: 0.75rem;
		font-weight: 700;
		color: var(--color-dusty-blue);
		letter-spacing: 0.06em;
	}
	.btn-memo-edit {
		font-size: 0.72rem;
		font-weight: 600;
		color: var(--color-dusty-blue);
		background: none;
		border: 1px solid var(--color-dusty-blue);
		border-radius: 10px;
		padding: 0.15rem 0.6rem;
		cursor: pointer;
		opacity: 0.7;
		transition: opacity 0.15s;
	}
	.btn-memo-edit:hover { opacity: 1; }
	.memo-text {
		margin: 0;
		line-height: 1.75;
		color: var(--color-warm-brown);
		font-size: 0.95rem;
		font-style: italic;
	}
	.empty-memo {
		margin: 0;
		font-size: 0.88rem;
		color: var(--color-soft-brown);
		opacity: 0.55;
	}
	.memo-textarea {
		width: 100%;
		padding: 0.7rem 0.8rem;
		border: 1px solid var(--color-light-line);
		border-radius: 6px;
		font-size: 0.95rem;
		line-height: 1.75;
		color: var(--color-warm-brown);
		background: white;
		resize: vertical;
		box-sizing: border-box;
		font-family: inherit;
	}
	.memo-textarea:focus {
		outline: none;
		border-color: var(--color-dusty-blue);
	}

	.memo-actions {
		display: flex;
		gap: 0.5rem;
		margin-top: 0.6rem;
		justify-content: flex-end;
	}

	.btn-save {
		font-size: 0.85rem;
		background: var(--color-sage, #7a9e7e);
		color: white;
		border: none;
		border-radius: 6px;
		padding: 0.4rem 1rem;
		cursor: pointer;
	}
	.btn-save:disabled { opacity: 0.6; cursor: not-allowed; }

	.btn-cancel-memo {
		font-size: 0.85rem;
		background: none;
		border: 1px solid var(--color-light-line);
		border-radius: 6px;
		padding: 0.4rem 0.8rem;
		cursor: pointer;
		color: var(--color-soft-brown);
	}
	.btn-cancel-memo:disabled { opacity: 0.6; cursor: not-allowed; }


	@media (max-width: 767px) {
		.page-wrap { padding: 0 var(--page-padding-mobile); }
		.recipe-card { padding: 1.5rem; }
		.recipe-title { font-size: 1.4rem; }
		.back-link { min-height: 44px; display: flex; align-items: center; }
		.btn-delete { min-height: 40px; padding: 0.4rem 0.9rem; }
		.btn-confirm { min-height: 40px; padding: 0.4rem 0.9rem; }
		.btn-cancel { min-height: 40px; padding: 0.4rem 0.9rem; }
		.btn-save { min-height: 44px; padding: 0.6rem 1.2rem; }
		.meta-row { gap: 1rem; }
		.btn-cooked { min-height: 40px; padding: 0.4rem 0.9rem; }
	}
</style>
