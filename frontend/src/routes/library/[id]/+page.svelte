<script lang="ts">
	import { goto } from '$app/navigation';
	import type { PageData } from './$types';
	import FlavorProfile from '$lib/components/FlavorProfile.svelte';
	import IngredientList from '$lib/components/IngredientList.svelte';
	import StepTimeline from '$lib/components/StepTimeline.svelte';
	import Toast from '$lib/components/Toast.svelte';
	import { deleteFromCollection, updateCollection } from '$lib/api';

	let { data }: { data: PageData } = $props();
	const item = $derived(data.item);
	const recipe = $derived(data.item.recipe);

	// 삭제 상태
	let isConfirmingDelete = $state(false);
	let isDeleting = $state(false);

	// 메모 편집 상태
	let isEditingMemo = $state(false);
	let memoText = $state(data.item.custom_tip ?? '');
	let isSavingMemo = $state(false);

	// 토스트
	let showToast = $state(false);
	let toastMessage = $state('');

	function triggerToast(msg: string) {
		toastMessage = msg;
		showToast = true;
	}

	async function confirmDelete() {
		isDeleting = true;
		try {
			await deleteFromCollection(item.id);
			goto('/library');
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
</script>

<svelte:head>
	<title>{recipe.title} | 내 레시피북</title>
</svelte:head>

<main class="page-wrap">
	<section class="recipe-page">
		<div class="recipe-top-bar">
			<a href="/library" class="back-link">← 레시피북으로</a>
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
			<h1 class="recipe-title">{recipe.title}</h1>

			{#if recipe.summary}
				<p class="recipe-summary">{recipe.summary}</p>
			{/if}

			<FlavorProfile flavor={recipe.flavor} />

			<IngredientList ingredients={recipe.ingredients} />

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
	}
</style>
