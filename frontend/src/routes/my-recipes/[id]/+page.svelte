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
	import { UtensilsCrossed, Star } from 'lucide-svelte';
	import AiAssistantFab from '$lib/components/AiAssistantFab.svelte';
	import type { RecipeOverride, IngredientOverride, StepOverride, RecipeStep, Ingredient, RecipeAuthorUpdate } from '$lib/types';
	import { getUser } from '$lib/stores/auth.svelte';
	import {
		extractRecipe,
		deleteFromCollection,
		updateCollection,
		updateCollectionWithOverride,
		updateTextRecipe,
		toggleFavorite,
		setRating,
		recordCooked,
		getTags,
		createTag,
		setCollectionTags,
		addCartFromCollection
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

	// 편집 모드 상태
	let isEditMode = $state(false);
	let isSavingEdit = $state(false);
	// 편집 중인 재료/단계 (원본을 복사해서 편집)
	let editIngredients = $state<IngredientOverride[]>([]);
	let editSteps = $state<StepOverride[]>([]);
	let editTip = $state<string>('');
	let editIsPublic = $state<boolean>(false);
	// 원본 복원 시 true로 설정
	let restoreOriginal = $state(false);

	// 편집 모드 진입: 현재 표시 중인 데이터(override 우선)로 초기화
	function enterEditMode() {
		const override = item.recipe_override;
		editIngredients = (override?.ingredients ?? recipe.ingredients ?? []).map((ing) => ({
			name: ing.name,
			amount: ing.amount ?? '',
			unit: ing.unit ?? '',
			category: ing.category,
			note: (ing as IngredientOverride).note ?? ''
		}));
		editSteps = (override?.steps ?? recipe.steps ?? []).map((s, i) => ({
			order: (s as StepOverride).order ?? (s as RecipeStep).step_number ?? i + 1,
			description: s.description,
			timer_minutes: (s as StepOverride).timer_minutes ?? null,
			note: (s as StepOverride).note ?? ''
		}));
		editTip = override?.tip ?? recipe.tip ?? '';
		editIsPublic = recipe.is_public ?? false;
		restoreOriginal = false;
		isEditMode = true;
	}

	function cancelEditMode() {
		isEditMode = false;
	}

	async function saveEdit() {
		isSavingEdit = true;
		try {
			if (isTextRecipeAuthor && !restoreOriginal) {
				// 텍스트 레시피 작성자 → recipes 테이블 직접 업데이트
				const updateData: RecipeAuthorUpdate = {
					ingredients: editIngredients.map(ing => ({
						name: ing.name,
						amount: ing.amount || null,
						unit: ing.unit || null,
						category: ing.category
					})),
					steps: editSteps.map((s, i) => ({
						step_number: s.order ?? i + 1,
						description: s.description,
						timer: s.timer_minutes != null ? `${s.timer_minutes}분` : null
					})),
					tip: editTip || null,
					is_public: editIsPublic
				};
				await updateTextRecipe(recipe.id!, updateData);
				item = {
					...item,
					recipe: {
						...recipe,
						ingredients: updateData.ingredients,
						steps: updateData.steps,
						tip: updateData.tip,
						is_public: editIsPublic
					},
					recipe_override: null
				};
				isEditMode = false;
				triggerToast('레시피가 업데이트됐어요.');
			} else {
				// YouTube 레시피 또는 비작성자 → recipe_override 사용
				let override: RecipeOverride | null = null;
				if (!restoreOriginal) {
					override = {
						ingredients: editIngredients,
						steps: editSteps,
						tip: editTip || undefined
					};
				}
				await updateCollectionWithOverride(item.id, item.custom_tip, override);
				item = { ...item, recipe_override: override };
				isEditMode = false;
				triggerToast(restoreOriginal ? '원본 레시피로 복원됐어요.' : '수정사항이 저장됐어요.');
			}
		} catch {
			triggerToast('저장 중 오류가 발생했습니다.');
		} finally {
			isSavingEdit = false;
		}
	}

	// 편집 모드에서 표시할 재료/단계 (override 있으면 override, 없으면 원본)
	const displayIngredients = $derived(
		isEditMode ? editIngredients : (item.recipe_override?.ingredients ?? recipe.ingredients)
	);
	const displaySteps = $derived.by((): RecipeStep[] => {
		const overrideSteps = item.recipe_override?.steps;
		if (overrideSteps) {
			return overrideSteps.map((s, i) => ({
				step_number: s.order ?? i + 1,
				description: s.description,
				timer: s.timer_minutes != null ? `${s.timer_minutes}분` : null
			}));
		}
		return recipe.steps ?? [];
	});
	const displayTip = $derived(
		isEditMode ? editTip : (item.recipe_override?.tip ?? recipe.tip)
	);
	const hasOverride = $derived(item.recipe_override != null);
	const isTextRecipeAuthor = $derived(recipe.source === 'text' && recipe.author_user_id === getUser()?.id);

	// 재료/단계 수정 여부 비교 (원본 대비)
	function isIngredientModified(idx: number): boolean {
		if (!item.recipe_override?.ingredients) return false;
		const orig = recipe.ingredients?.[idx];
		const ov = item.recipe_override.ingredients[idx];
		if (!orig || !ov) return true;
		return orig.name !== ov.name || (orig.amount ?? '') !== ov.amount || (orig.unit ?? '') !== ov.unit;
	}
	function isStepModified(idx: number): boolean {
		if (!item.recipe_override?.steps) return false;
		const orig = recipe.steps?.[idx];
		const ov = item.recipe_override.steps[idx];
		if (!orig || !ov) return true;
		return orig.description !== ov.description;
	}

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

	// 장바구니 담기 상태
	let isAddingToCart = $state(false);

	async function handleAddToCart() {
		isAddingToCart = true;
		try {
			const result = await addCartFromCollection(item.id);
			triggerToast(`재료 ${result.count}개를 장바구니에 담았어요! 🛒`);
		} catch (e) {
			triggerToast(e instanceof Error ? e.message : '장바구니 담기에 실패했습니다.');
		} finally {
			isAddingToCart = false;
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

	// 즐겨찾기 토글
	let isTogglingFavorite = $state(false);
	async function handleFavorite() {
		if (isTogglingFavorite) return;
		isTogglingFavorite = true;
		const prev = item.is_favorite;
		item = { ...item, is_favorite: !prev };
		try {
			await toggleFavorite(item.id);
		} catch {
			item = { ...item, is_favorite: prev };
			triggerToast('즐겨찾기 변경 중 오류가 발생했습니다.');
		} finally {
			isTogglingFavorite = false;
		}
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
				{#if !isEditMode}
					<div class="top-bar-actions">
						<button class="btn-top-action edit" onclick={enterEditMode}>레시피 수정</button>
						{#if recipe.video_id}
							<button class="btn-top-action reanalyze" onclick={handleReanalyze} disabled={isReanalyzing}>
								{isReanalyzing ? '분석 중...' : '다시 분석'}
							</button>
						{/if}
						{#if isConfirmingDelete}
							<span class="confirm-delete">
								정말?
								<button class="btn-confirm" onclick={confirmDelete} disabled={isDeleting}>
									{isDeleting ? '삭제 중' : '삭제'}
								</button>
								<button class="btn-cancel" onclick={() => isConfirmingDelete = false} disabled={isDeleting}>취소</button>
							</span>
						{:else}
							<button class="btn-top-action delete" onclick={() => isConfirmingDelete = true}>삭제</button>
						{/if}
					</div>
				{/if}
			</div>
		</div>

		{#if isEditMode}
			<div class="edit-banner">
				<span class="edit-banner-text">✎ 수정 중</span>
				{#if !isTextRecipeAuthor}
					<label class="restore-label">
						<input type="checkbox" bind:checked={restoreOriginal} />
						원본으로 복원
					</label>
				{/if}
				{#if isTextRecipeAuthor}
					<label class="public-toggle-label">
						<input type="checkbox" bind:checked={editIsPublic} />
						{editIsPublic ? '전체공개' : '나만보기'}
					</label>
				{/if}
				<div class="edit-banner-actions">
					<button class="btn-save-edit" onclick={saveEdit} disabled={isSavingEdit}>
						{isSavingEdit ? '저장 중...' : '변경 저장'}
					</button>
					<button class="btn-cancel-edit" onclick={cancelEditMode} disabled={isSavingEdit}>취소</button>
				</div>
			</div>
		{/if}

		<article class="recipe-card">
			<button
				class="btn-favorite"
				class:is-favorite={item.is_favorite}
				onclick={handleFavorite}
				disabled={isTogglingFavorite}
				aria-label={item.is_favorite ? '즐겨찾기 해제' : '즐겨찾기 추가'}
				title={item.is_favorite ? '즐겨찾기 해제' : '즐겨찾기 추가'}
			>
				<Star size={22} fill={item.is_favorite ? 'currentColor' : 'none'} />
			</button>

			<h1 class="recipe-title">{recipe.title}{recipe.channel_name ? ` - ${recipe.channel_name}` : ''}</h1>

			{#if recipe.source === 'text'}
				<span class="source-badge text-badge">✏ 직접 작성</span>
			{/if}

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

			<!-- 활동 블록: 별점 + 요리 기록 -->
			<div class="activity-block">
				<div class="activity-top">
					<div class="rating-area">
						<StarRating rating={item.my_rating} onchange={handleRating} />
						{#if item.my_rating}
							<span class="rating-label">{item.my_rating}점</span>
						{:else}
							<span class="rating-label muted">별점을 매겨보세요</span>
						{/if}
					</div>
					<button class="btn-cooked" onclick={handleCooked} disabled={isCooking}>
						{isCooking ? '기록 중...' : '오늘 요리했어요'} <UtensilsCrossed size={15} />
					</button>
				</div>
				{#if item.cooked_count > 0 || item.last_cooked_at}
					<div class="activity-stats">
						<span class="cooked-count">{item.cooked_count}회 요리</span>
						{#if item.last_cooked_at}
							<span class="last-cooked">· 마지막 {new Date(item.last_cooked_at).toLocaleDateString('ko-KR', { month: 'short', day: 'numeric' })}</span>
						{/if}
					</div>
				{/if}
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

			{#if recipe.flavor}
				<FlavorProfile flavor={recipe.flavor} />
			{/if}

			{#if isEditMode && !restoreOriginal}
				<!-- 재료 편집 모드 -->
				<div class="edit-section">
					<h3 class="edit-section-title">재료 수정</h3>
					{#each editIngredients as ing, i (i)}
						<div class="edit-ingredient-row" class:modified={isIngredientModified(i)}>
							{#if isIngredientModified(i)}
								<span class="modified-badge">수정됨</span>
							{/if}
							<div class="edit-ingredient-fields">
								<input
									class="edit-input name-input"
									bind:value={editIngredients[i].name}
									placeholder="재료명"
								/>
								<input
									class="edit-input amount-input"
									bind:value={editIngredients[i].amount}
									placeholder="수량"
								/>
								<input
									class="edit-input unit-input"
									bind:value={editIngredients[i].unit}
									placeholder="단위"
								/>
								<input
									class="edit-input note-input"
									bind:value={editIngredients[i].note}
									placeholder="메모 (선택)"
								/>
								<button
									class="btn-remove-row"
									onclick={() => { editIngredients = editIngredients.filter((_, idx) => idx !== i); }}
									aria-label="재료 삭제"
								>✕</button>
							</div>
						</div>
					{/each}
					<button
						class="btn-add-row"
						onclick={() => { editIngredients = [...editIngredients, { name: '', amount: '', unit: '', category: '기타', note: '' }]; }}
					>+ 재료 추가</button>
				</div>

				<!-- 단계 편집 모드 -->
				<div class="edit-section">
					<h3 class="edit-section-title">조리 단계 수정</h3>
					{#each editSteps as step, i (i)}
						<div class="edit-step-row" class:modified={isStepModified(i)}>
							<div class="edit-step-header">
								<span class="step-num">{step.order}단계</span>
								{#if isStepModified(i)}
									<span class="modified-badge">수정됨</span>
								{/if}
								<button
									class="btn-remove-row"
									onclick={() => { editSteps = editSteps.filter((_, idx) => idx !== i); }}
									aria-label="단계 삭제"
								>✕</button>
							</div>
							<textarea
								class="edit-textarea"
								bind:value={editSteps[i].description}
								placeholder="조리 단계 설명"
								rows="3"
							></textarea>
							<input
								class="edit-input note-input"
								bind:value={editSteps[i].note}
								placeholder="메모 (선택): 이 단계에서 주의할 점"
							/>
						</div>
					{/each}
					<button
						class="btn-add-row"
						onclick={() => { editSteps = [...editSteps, { order: editSteps.length + 1, description: '', note: '' }]; }}
					>+ 단계 추가</button>
				</div>

				<!-- 꿀팁 편집 -->
				<div class="edit-section">
					<h3 class="edit-section-title">꿀팁 수정</h3>
					<textarea
						class="edit-textarea"
						bind:value={editTip}
						placeholder="나만의 꿀팁 (비워두면 AI 꿀팁 표시)"
						rows="3"
					></textarea>
				</div>
			{:else}
				<!-- 뷰 모드: override 있으면 override 표시, 없으면 원본 -->
				{#if hasOverride && !isEditMode}
					<div class="override-notice">
						<span>수정된 버전을 보고 있어요</span>
						<button class="btn-restore-link" onclick={async () => { await updateCollectionWithOverride(item.id, item.custom_tip, null); item = { ...item, recipe_override: null }; triggerToast('원본 레시피로 복원됐어요.'); }}>
							원본으로 복원
						</button>
					</div>
				{/if}
				<div class="cart-btn-row">
					<button class="btn-add-cart-inline" onclick={handleAddToCart} disabled={isAddingToCart}>
						{isAddingToCart ? '담는 중...' : '🛒 재료 담기'}
					</button>
				</div>
				<IngredientList
					ingredients={displayIngredients as Ingredient[]}
					storageKey={recipe.video_id ?? String(recipe.id ?? '')}
				/>
				<StepTimeline steps={displaySteps} />

				{#if displayTip}
					<div class="tip-section">
						<div class="tip-card">
							<span class="tip-label">✦ 꿀팁</span>
							<p>{displayTip}</p>
						</div>
					</div>
				{/if}
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
				videoUrl={recipe.video_url ?? null}
				channelName={recipe.channel_name}
				videoTitle={recipe.video_title ?? null}
			/>
		</article>
	</section>
</main>

<ScrollToTop bottomOffset="calc(148px + env(safe-area-inset-bottom))" />

<Toast message={toastMessage} show={showToast} ondismiss={() => showToast = false} />

{#if recipe}
	<AiAssistantFab collectionId={item.id} recipe={recipe} />
{/if}

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
		align-items: flex-start;
		padding: 0.75rem 0;
		flex-wrap: wrap;
		gap: 0.4rem;
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
		flex-direction: column;
		align-items: flex-end;
		gap: 0.4rem;
	}

	.saved-date {
		font-size: 0.78rem;
		color: var(--color-soft-brown);
	}

	.top-bar-actions {
		display: flex;
		align-items: center;
		gap: 0.5rem;
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
		position: relative;
		background: white;
		border-radius: 12px;
		padding: 2.5rem;
		box-shadow: 0 2px 8px rgba(0,0,0,0.06);
	}

	.btn-favorite {
		position: absolute;
		top: 1.2rem;
		right: 1.2rem;
		background: none;
		border: none;
		padding: 6px;
		cursor: pointer;
		color: var(--color-light-line);
		border-radius: 50%;
		display: flex;
		align-items: center;
		justify-content: center;
		transition: color 0.18s, transform 0.15s;
	}
	.btn-favorite:hover {
		color: var(--color-terracotta);
		transform: scale(1.15);
	}
	.btn-favorite.is-favorite {
		color: var(--color-terracotta);
	}
	.btn-favorite:disabled {
		opacity: 0.5;
		cursor: not-allowed;
		transform: none;
	}

	.recipe-title {
		font-size: 1.8rem;
		margin-bottom: 0.5rem;
		text-align: center;
	}

	.source-badge {
		display: inline-block;
		font-size: 0.72rem;
		padding: 0.2rem 0.55rem;
		border-radius: 20px;
		margin-bottom: 0.5rem;
		font-weight: 600;
	}
	.text-badge {
		background: #e8f5e9;
		color: #2e7d32;
		border: 1px solid #c8e6c9;
	}

	.source-line {
		font-size: 0.82rem;
		color: var(--color-soft-brown);
		text-align: center;
		margin-bottom: 1.2rem;
		opacity: 0.8;
	}

	/* 활동 블록 */
	.activity-block {
		background: var(--color-cream);
		border-radius: 10px;
		padding: 0.8rem 1rem;
		margin-bottom: 1rem;
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
	}
	.activity-top {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 0.5rem;
	}
	.activity-stats {
		display: flex;
		align-items: center;
		gap: 0.4rem;
		padding-top: 0.4rem;
		border-top: 1px solid rgba(0,0,0,0.06);
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
	.btn-cooked {
		font-size: 0.82rem;
		background: var(--color-warm-yellow, #fff3cd);
		border: 1px solid color-mix(in srgb, var(--color-warm-yellow, #fff3cd) 70%, #a67c00);
		border-radius: 8px;
		padding: 0 0.8rem;
		height: 34px;
		cursor: pointer;
		font-weight: 600;
		font-family: inherit;
		color: var(--color-warm-brown);
		display: inline-flex;
		align-items: center;
		gap: 0.3rem;
		transition: background 0.15s;
	}
	.btn-cooked:hover {
		background: color-mix(in srgb, var(--color-warm-yellow, #fff3cd) 80%, #f5a623);
	}
	.btn-cooked:disabled { opacity: 0.6; cursor: not-allowed; }

	/* 재료 담기 버튼 (재료 섹션 위) */
	.cart-btn-row {
		display: flex;
		justify-content: flex-end;
		margin-bottom: 0.5rem;
	}
	.btn-add-cart-inline {
		font-size: 0.78rem;
		font-weight: 600;
		background: none;
		border: 1.5px solid var(--color-light-line);
		border-radius: 20px;
		padding: 0.3rem 0.85rem;
		cursor: pointer;
		font-family: inherit;
		color: var(--color-soft-brown);
		display: inline-flex;
		align-items: center;
		gap: 0.3rem;
		transition: border-color 0.15s, color 0.15s;
	}
	.btn-add-cart-inline:hover {
		border-color: var(--color-terracotta);
		color: var(--color-terracotta);
	}
	.btn-add-cart-inline:disabled { opacity: 0.6; cursor: not-allowed; }

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


	/* 상단 액션 버튼 통일 스타일 */
	.btn-top-action {
		height: 34px;
		padding: 0 0.9rem;
		font-size: 0.82rem;
		font-weight: 600;
		border-radius: 8px;
		border: 1.5px solid;
		cursor: pointer;
		font-family: inherit;
		display: inline-flex;
		align-items: center;
		transition: background 0.15s, color 0.15s;
	}
	.btn-top-action.edit { color: var(--color-terracotta); border-color: var(--color-terracotta); background: none; }
	.btn-top-action.edit:hover { background: var(--color-terracotta); color: white; }
	.btn-top-action.reanalyze { color: var(--color-soft-brown); border-color: var(--color-light-line); background: none; }
	.btn-top-action.reanalyze:hover:not(:disabled) { border-color: var(--color-soft-brown); color: var(--color-warm-brown); }
	.btn-top-action.reanalyze:disabled { opacity: 0.6; cursor: not-allowed; }
	.btn-top-action.delete { color: #c62828; border-color: #ef9a9a; background: none; }
	.btn-top-action.delete:hover { background: #ffebee; }

	/* 편집 배너 */
	.edit-banner {
		display: flex;
		align-items: center;
		gap: 1rem;
		padding: 0.7rem 1.2rem;
		background: color-mix(in srgb, var(--color-terracotta, #c0714f) 10%, white);
		border: 1px solid color-mix(in srgb, var(--color-terracotta, #c0714f) 30%, white);
		border-radius: 8px;
		margin-bottom: 1rem;
		flex-wrap: wrap;
	}
	.edit-banner-text {
		font-size: 0.9rem;
		font-weight: 700;
		color: var(--color-terracotta, #c0714f);
	}
	.restore-label {
		display: flex;
		align-items: center;
		gap: 0.4rem;
		font-size: 0.82rem;
		color: var(--color-soft-brown);
		cursor: pointer;
	}
	.public-toggle-label {
		display: flex;
		align-items: center;
		gap: 0.4rem;
		font-size: 0.82rem;
		font-weight: 600;
		color: var(--color-terracotta, #c0714f);
		cursor: pointer;
	}
	.edit-banner-actions {
		display: flex;
		gap: 0.5rem;
		margin-left: auto;
	}
	.btn-save-edit {
		font-size: 0.85rem;
		background: var(--color-terracotta, #c0714f);
		color: white;
		border: none;
		border-radius: 6px;
		padding: 0.4rem 1rem;
		cursor: pointer;
		font-weight: 600;
	}
	.btn-save-edit:disabled { opacity: 0.6; cursor: not-allowed; }
	.btn-cancel-edit {
		font-size: 0.85rem;
		background: none;
		border: 1px solid var(--color-light-line);
		border-radius: 6px;
		padding: 0.4rem 0.8rem;
		cursor: pointer;
		color: var(--color-soft-brown);
	}
	.btn-cancel-edit:disabled { opacity: 0.6; cursor: not-allowed; }

	/* 편집 섹션 */
	.edit-section {
		margin-top: 2rem;
	}
	.edit-section-title {
		font-size: 0.88rem;
		font-weight: 700;
		color: var(--color-soft-brown);
		letter-spacing: 0.04em;
		text-transform: uppercase;
		margin-bottom: 0.8rem;
		padding-bottom: 0.4rem;
		border-bottom: 1px solid var(--color-light-line);
	}

	/* 재료 편집 행 */
	.edit-ingredient-row {
		position: relative;
		margin-bottom: 0.5rem;
		padding: 0.5rem 0.6rem;
		border-radius: 6px;
		background: var(--color-cream);
	}
	.edit-ingredient-row.modified {
		border-left: 3px solid var(--color-terracotta, #c0714f);
	}
	.edit-ingredient-fields {
		display: flex;
		gap: 0.4rem;
		align-items: center;
		flex-wrap: wrap;
	}
	.edit-input {
		font-size: 0.88rem;
		padding: 0.35rem 0.6rem;
		border: 1px solid var(--color-light-line);
		border-radius: 5px;
		background: white;
		color: var(--color-warm-brown);
		font-family: inherit;
	}
	.edit-input:focus {
		outline: none;
		border-color: var(--color-terracotta, #c0714f);
	}
	.name-input { flex: 2; min-width: 80px; }
	.amount-input { flex: 1; min-width: 60px; }
	.unit-input { flex: 1; min-width: 50px; }
	.note-input { flex: 3; min-width: 100px; }

	/* 단계 편집 행 */
	.edit-step-row {
		margin-bottom: 1rem;
		padding: 0.8rem 0.8rem;
		border-radius: 6px;
		background: var(--color-cream);
	}
	.edit-step-row.modified {
		border-left: 3px solid var(--color-terracotta, #c0714f);
	}
	.edit-step-header {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		margin-bottom: 0.5rem;
	}
	.step-num {
		font-size: 0.78rem;
		font-weight: 700;
		color: var(--color-soft-brown);
	}
	.edit-textarea {
		width: 100%;
		padding: 0.6rem 0.7rem;
		border: 1px solid var(--color-light-line);
		border-radius: 5px;
		font-size: 0.92rem;
		line-height: 1.7;
		color: var(--color-warm-brown);
		background: white;
		resize: vertical;
		box-sizing: border-box;
		font-family: inherit;
		margin-bottom: 0.4rem;
	}
	.edit-textarea:focus {
		outline: none;
		border-color: var(--color-terracotta, #c0714f);
	}

	/* 수정됨 뱃지 */
	.modified-badge {
		font-size: 0.68rem;
		font-weight: 700;
		color: var(--color-terracotta, #c0714f);
		background: color-mix(in srgb, var(--color-terracotta, #c0714f) 12%, white);
		border-radius: 8px;
		padding: 0.1rem 0.45rem;
	}

	/* 행 추가/삭제 버튼 */
	.btn-add-row {
		font-size: 0.82rem;
		color: var(--color-terracotta, #c0714f);
		background: none;
		border: 1px dashed var(--color-terracotta, #c0714f);
		border-radius: 6px;
		padding: 0.35rem 0.8rem;
		cursor: pointer;
		margin-top: 0.3rem;
		transition: background 0.15s;
	}
	.btn-add-row:hover { background: color-mix(in srgb, var(--color-terracotta, #c0714f) 8%, white); }
	.btn-remove-row {
		font-size: 0.75rem;
		color: var(--color-muted-red, #c0392b);
		background: none;
		border: none;
		cursor: pointer;
		padding: 0.1rem 0.3rem;
		opacity: 0.6;
		margin-left: auto;
	}
	.btn-remove-row:hover { opacity: 1; }

	/* 원본 복원 알림 */
	.override-notice {
		display: flex;
		align-items: center;
		gap: 0.8rem;
		font-size: 0.82rem;
		color: var(--color-soft-brown);
		background: color-mix(in srgb, var(--color-terracotta, #c0714f) 8%, white);
		border: 1px solid color-mix(in srgb, var(--color-terracotta, #c0714f) 20%, white);
		border-radius: 6px;
		padding: 0.5rem 0.8rem;
		margin-bottom: 1rem;
	}
	.btn-restore-link {
		font-size: 0.8rem;
		color: var(--color-terracotta, #c0714f);
		background: none;
		border: none;
		cursor: pointer;
		text-decoration: underline;
		padding: 0;
	}

	@media (max-width: 767px) {
		.page-wrap { padding: 0 var(--page-padding-mobile); }
		.recipe-card { padding: 1.5rem; }
		.recipe-title { font-size: 1.4rem; }
		.back-link { min-height: 44px; display: flex; align-items: center; }
		.btn-top-action { height: 38px; }
		.btn-confirm { min-height: 40px; padding: 0.4rem 0.9rem; }
		.btn-cancel { min-height: 40px; padding: 0.4rem 0.9rem; }
		.btn-save { min-height: 44px; padding: 0.6rem 1.2rem; }
		.activity-block { gap: 0.6rem; }
		.btn-cooked { min-height: 40px; padding: 0.4rem 0.9rem; }
		.edit-ingredient-fields { flex-direction: column; }
		.name-input, .amount-input, .unit-input, .note-input { width: 100%; }
	}
</style>
