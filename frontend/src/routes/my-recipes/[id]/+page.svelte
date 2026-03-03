<script lang="ts">
	import { goto } from '$app/navigation';
	import { untrack } from 'svelte';
	import type { PageData } from './$types';
	import type { CollectionTag } from '$lib/types';
	import FlavorProfile from '$lib/components/FlavorProfile.svelte';
	import IngredientList from '$lib/components/IngredientList.svelte';
	import StepTimeline from '$lib/components/StepTimeline.svelte';
	import StarRating from '$lib/components/StarRating.svelte';
	import TagBadge from '$lib/components/TagBadge.svelte';
	import TagPopover from '$lib/components/TagPopover.svelte';
	import Toast from '$lib/components/Toast.svelte';
	import {
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
						{isCooking ? '기록 중...' : '오늘 요리했어요 🍳'}
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

			<div class="tip-section">
				<div class="section-divider">
					<span class="divider-line"></span>
					<span class="divider-text">내 메모</span>
					<span class="divider-line"></span>
				</div>
				{#if isEditingMemo}
					<textarea
						class="memo-textarea"
						bind:value={memoText}
						placeholder="이 레시피에 대한 나만의 메모를 남겨보세요..."
						rows="4"
					></textarea>
					<div class="memo-actions">
						<button class="btn-save" onclick={saveMemo} disabled={isSavingMemo}>
							{isSavingMemo ? '저장 중...' : '저장'}
						</button>
						<button class="btn-cancel-memo" onclick={cancelEdit} disabled={isSavingMemo}>취소</button>
					</div>
				{:else}
					<div class="tip-card memo">
						{#if item.custom_tip}
							<p>{item.custom_tip}</p>
						{:else}
							<p class="empty-memo">메모를 남겨보세요.</p>
						{/if}
					</div>
					<button class="btn-edit-memo" onclick={() => isEditingMemo = true}>
						{item.custom_tip ? '메모 수정' : '메모 추가'}
					</button>
				{/if}
			</div>

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
	.tag-add-wrap {
		position: relative;
	}
	.btn-add-tag {
		font-size: 0.72rem;
		font-weight: 600;
		padding: 0.15rem 0.5rem;
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
	.empty-memo {
		color: var(--color-soft-brown);
		opacity: 0.6;
	}

	.memo-textarea {
		width: 100%;
		padding: 1rem;
		border: 1px solid var(--color-light-line);
		border-radius: 10px;
		font-family: var(--font-memo);
		font-size: 0.95rem;
		line-height: 1.8;
		color: var(--color-warm-brown);
		background: var(--color-cream);
		resize: vertical;
		box-sizing: border-box;
	}
	.memo-textarea:focus {
		outline: none;
		border-color: var(--color-soft-brown);
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

	.btn-edit-memo {
		margin-top: 0.6rem;
		font-size: 0.82rem;
		background: none;
		border: none;
		color: var(--color-dusty-blue);
		cursor: pointer;
		padding: 0;
		text-decoration: underline;
		text-underline-offset: 2px;
	}
	.btn-edit-memo:hover { color: var(--color-soft-brown); }

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
		.back-link { min-height: 44px; display: flex; align-items: center; }
		.btn-delete { min-height: 40px; padding: 0.4rem 0.9rem; }
		.btn-confirm { min-height: 40px; padding: 0.4rem 0.9rem; }
		.btn-cancel { min-height: 40px; padding: 0.4rem 0.9rem; }
		.btn-save { min-height: 44px; padding: 0.6rem 1.2rem; }
		.meta-row { gap: 1rem; }
		.btn-cooked { min-height: 40px; padding: 0.4rem 0.9rem; }
	}
</style>
