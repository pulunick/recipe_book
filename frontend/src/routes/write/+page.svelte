<script lang="ts">
	import { goto } from '$app/navigation';
	import { extractRecipeFromText, saveTextRecipe } from '$lib/api';
	import IngredientList from '$lib/components/IngredientList.svelte';
	import StepTimeline from '$lib/components/StepTimeline.svelte';
	import FlavorProfile from '$lib/components/FlavorProfile.svelte';
	import type { Recipe } from '$lib/types';

	type Step = 'input' | 'preview';
	let step = $state<Step>('input');

	let title = $state('');
	let text = $state('');
	let isAnalyzing = $state(false);
	let isSaving = $state(false);
	let errorMsg = $state('');
	let recipe = $state<Recipe | null>(null);

	const MIN_LENGTH = 50;
	const textLength = $derived(text.length);
	const canAnalyze = $derived(textLength >= MIN_LENGTH && !isAnalyzing);

	async function handleAnalyze() {
		if (!canAnalyze) return;
		isAnalyzing = true;
		errorMsg = '';
		try {
			recipe = await extractRecipeFromText(text, title || undefined);
			step = 'preview';
		} catch (e) {
			errorMsg = e instanceof Error ? e.message : '분석 중 오류가 발생했습니다.';
		} finally {
			isAnalyzing = false;
		}
	}

	async function handleSave() {
		if (!recipe) return;
		isSaving = true;
		errorMsg = '';
		try {
			const collectionId = await saveTextRecipe(recipe);
			goto(`/my-recipes/${collectionId}`, { state: { justAdded: true } });
		} catch (e) {
			errorMsg = e instanceof Error ? e.message : '저장 중 오류가 발생했습니다.';
			isSaving = false;
		}
	}

	function handleBack() {
		if (step === 'preview') {
			step = 'input';
			errorMsg = '';
		} else {
			goto('/my-recipes');
		}
	}
</script>

<svelte:head>
	<title>레시피 작성 | 해먹당</title>
</svelte:head>

<div class="write-page">
	<div class="write-header">
		<button class="back-btn" onclick={handleBack} aria-label="뒤로">
			<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
				<polyline points="15 18 9 12 15 6" />
			</svg>
		</button>
		<h1 class="write-title">
			{step === 'input' ? '레시피 작성' : '미리보기'}
		</h1>
		{#if step === 'preview'}
			<button class="save-btn-header" onclick={handleSave} disabled={isSaving}>
				{isSaving ? '저장 중...' : '저장'}
			</button>
		{/if}
	</div>

	<div class="write-body">
		{#if step === 'input'}
			<div class="input-section">
				<p class="input-guide">
					레시피를 자유롭게 입력하세요.<br />
					구어체, 메모, 블로그 글 무엇이든 괜찮아요.
				</p>

				<div class="field">
					<label class="field-label" for="recipe-title">제목 <span class="optional">(선택)</span></label>
					<input
						id="recipe-title"
						class="field-input"
						type="text"
						placeholder="예: 엄마 김치찌개 레시피"
						maxlength="100"
						bind:value={title}
					/>
				</div>

				<div class="field">
					<label class="field-label" for="recipe-text">
						레시피 내용 <span class="char-count" class:warn={textLength < MIN_LENGTH}>{textLength}자</span>
					</label>
					<textarea
						id="recipe-text"
						class="field-textarea"
						placeholder="재료와 만드는 방법을 입력해주세요. (최소 50자)&#10;&#10;예시)&#10;재료: 돼지고기 200g, 김치 반 포기, 두부 한 모&#10;1. 냄비에 기름 두르고 돼지고기 볶기&#10;2. 김치 넣고 같이 볶다가 물 2컵 추가&#10;..."
						rows="14"
						maxlength="5000"
						bind:value={text}
					></textarea>
					<p class="char-hint">{textLength} / 5000자 (최소 {MIN_LENGTH}자)</p>
				</div>

				{#if errorMsg}
					<p class="error-msg">{errorMsg}</p>
				{/if}

				<button
					class="analyze-btn"
					onclick={handleAnalyze}
					disabled={!canAnalyze}
				>
					{#if isAnalyzing}
						<span class="btn-spinner"></span>
						AI가 레시피를 분석 중...
					{:else}
						AI로 레시피 변환하기
					{/if}
				</button>

				{#if isAnalyzing}
					<p class="analyzing-hint">보통 10~20초 정도 걸려요</p>
				{/if}
			</div>

		{:else if step === 'preview' && recipe}
			<div class="preview-section">
				<div class="preview-notice">
					<span class="notice-icon">✨</span>
					<span>AI가 구조화한 결과예요. 저장 후 편집할 수 있어요.</span>
				</div>

				<div class="preview-card">
					<h2 class="preview-recipe-title">{recipe.title}</h2>

					{#if recipe.servings || recipe.cooking_time || recipe.difficulty}
						<div class="meta-chips">
							{#if recipe.servings}<span class="meta-chip">👥 {recipe.servings}</span>{/if}
							{#if recipe.cooking_time}<span class="meta-chip">⏱ {recipe.cooking_time}</span>{/if}
							{#if recipe.difficulty}<span class="meta-chip">{recipe.difficulty}</span>{/if}
						</div>
					{/if}

					{#if recipe.summary}
						<p class="preview-summary">{recipe.summary}</p>
					{/if}

					{#if recipe.flavor}
						<FlavorProfile flavor={recipe.flavor} />
					{/if}

					{#if recipe.ingredients && recipe.ingredients.length > 0}
						<IngredientList ingredients={recipe.ingredients} storageKey="write-preview" />
					{/if}

					{#if recipe.steps && recipe.steps.length > 0}
						<StepTimeline steps={recipe.steps} />
					{/if}

					{#if recipe.tip}
						<div class="tip-card">
							<span class="tip-label">✦ 꿀팁</span>
							<p>{recipe.tip}</p>
						</div>
					{/if}
				</div>

				{#if errorMsg}
					<p class="error-msg">{errorMsg}</p>
				{/if}

				<div class="preview-actions">
					<button class="btn-rewrite" onclick={() => { step = 'input'; errorMsg = ''; }}>
						다시 작성
					</button>
					<button class="btn-save" onclick={handleSave} disabled={isSaving}>
						{isSaving ? '저장 중...' : '내 레시피에 저장 →'}
					</button>
				</div>
			</div>
		{/if}
	</div>
</div>

<style>
	.write-page {
		max-width: 480px;
		margin: 0 auto;
		min-height: 100dvh;
		display: flex;
		flex-direction: column;
	}

	/* 헤더 */
	.write-header {
		display: flex;
		align-items: center;
		gap: 8px;
		padding: 0 16px;
		height: 52px;
		border-bottom: 1px solid var(--color-light-line);
		background: var(--color-paper);
		position: sticky;
		top: 48px; /* slim-header 높이 */
		z-index: 10;
		flex-shrink: 0;
	}

	.back-btn {
		background: none;
		border: none;
		padding: 4px;
		cursor: pointer;
		color: var(--color-soft-brown);
		display: flex;
		align-items: center;
		flex-shrink: 0;
	}
	.back-btn svg { width: 24px; height: 24px; }

	.write-title {
		flex: 1;
		font-size: 1rem;
		font-weight: 700;
		color: var(--color-warm-brown);
	}

	.save-btn-header {
		font-size: 0.9rem;
		font-weight: 700;
		color: var(--color-terracotta);
		background: none;
		border: none;
		padding: 6px 4px;
		cursor: pointer;
		font-family: inherit;
	}
	.save-btn-header:disabled { opacity: 0.5; cursor: not-allowed; }

	/* 본문 */
	.write-body {
		flex: 1;
		overflow-y: auto;
	}

	/* 입력 단계 */
	.input-section {
		padding: 20px 20px 40px;
		display: flex;
		flex-direction: column;
		gap: 20px;
	}

	.input-guide {
		font-size: 0.88rem;
		color: var(--color-soft-brown);
		line-height: 1.6;
		background: var(--color-cream);
		border-radius: 10px;
		padding: 12px 16px;
	}

	.field {
		display: flex;
		flex-direction: column;
		gap: 6px;
	}

	.field-label {
		font-size: 0.82rem;
		font-weight: 700;
		color: var(--color-soft-brown);
		display: flex;
		align-items: center;
		gap: 6px;
	}

	.optional {
		font-size: 0.75rem;
		font-weight: 400;
		opacity: 0.7;
	}

	.char-count {
		font-size: 0.75rem;
		font-weight: 600;
		color: var(--color-terracotta);
		margin-left: auto;
	}
	.char-count.warn { color: var(--color-soft-brown); opacity: 0.6; }

	.field-input {
		width: 100%;
		padding: 12px 14px;
		border: 1.5px solid var(--color-light-line);
		border-radius: 10px;
		font-size: 0.95rem;
		font-family: inherit;
		color: var(--color-warm-brown);
		background: white;
		box-sizing: border-box;
		transition: border-color 0.15s;
	}
	.field-input:focus { outline: none; border-color: var(--color-terracotta); }

	.field-textarea {
		width: 100%;
		padding: 12px 14px;
		border: 1.5px solid var(--color-light-line);
		border-radius: 10px;
		font-size: 0.9rem;
		line-height: 1.7;
		font-family: inherit;
		color: var(--color-warm-brown);
		background: white;
		resize: vertical;
		box-sizing: border-box;
		transition: border-color 0.15s;
	}
	.field-textarea:focus { outline: none; border-color: var(--color-terracotta); }
	.field-textarea::placeholder { color: var(--color-soft-brown); opacity: 0.55; }

	.char-hint {
		font-size: 0.75rem;
		color: var(--color-soft-brown);
		opacity: 0.6;
		text-align: right;
	}

	.error-msg {
		font-size: 0.85rem;
		color: var(--color-muted-red, #c0392b);
		background: #fdf0f0;
		border-radius: 8px;
		padding: 10px 14px;
	}

	.analyze-btn {
		width: 100%;
		padding: 15px;
		background: var(--color-terracotta);
		color: white;
		border: none;
		border-radius: 12px;
		font-size: 1rem;
		font-weight: 700;
		font-family: inherit;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 8px;
		transition: opacity 0.15s;
	}
	.analyze-btn:disabled { opacity: 0.5; cursor: not-allowed; }

	.analyzing-hint {
		font-size: 0.8rem;
		color: var(--color-soft-brown);
		text-align: center;
		opacity: 0.7;
	}

	.btn-spinner {
		width: 18px;
		height: 18px;
		border: 2.5px solid rgba(255, 255, 255, 0.4);
		border-top-color: #fff;
		border-radius: 50%;
		animation: spin 0.7s linear infinite;
		flex-shrink: 0;
	}
	@keyframes spin { to { transform: rotate(360deg); } }

	/* 미리보기 단계 */
	.preview-section {
		padding: 16px 16px 40px;
		display: flex;
		flex-direction: column;
		gap: 16px;
	}

	.preview-notice {
		display: flex;
		align-items: center;
		gap: 8px;
		font-size: 0.82rem;
		color: var(--color-soft-brown);
		background: var(--color-cream);
		border-radius: 10px;
		padding: 10px 14px;
	}
	.notice-icon { font-size: 1rem; }

	.preview-card {
		background: white;
		border-radius: 16px;
		padding: 20px;
		box-shadow: 0 2px 8px rgba(0,0,0,0.06);
	}

	.preview-recipe-title {
		font-size: 1.3rem;
		font-weight: 700;
		color: var(--color-warm-brown);
		margin-bottom: 10px;
		text-align: center;
	}

	.meta-chips {
		display: flex;
		justify-content: center;
		flex-wrap: wrap;
		gap: 6px;
		margin-bottom: 14px;
	}
	.meta-chip {
		font-size: 0.8rem;
		color: var(--color-soft-brown);
		background: var(--color-cream);
		border-radius: 12px;
		padding: 3px 10px;
	}

	.preview-summary {
		font-size: 0.9rem;
		color: var(--color-soft-brown);
		text-align: center;
		line-height: 1.6;
		margin-bottom: 16px;
	}

	.tip-card {
		margin-top: 20px;
		border-left: 4px solid var(--color-terracotta);
		background: var(--color-cream);
		padding: 12px 14px;
		border-radius: 0 8px 8px 0;
	}
	.tip-label {
		display: block;
		font-size: 0.72rem;
		font-weight: 700;
		color: var(--color-terracotta);
		letter-spacing: 0.06em;
		margin-bottom: 6px;
	}
	.tip-card p {
		margin: 0;
		font-size: 0.9rem;
		line-height: 1.7;
		color: var(--color-warm-brown);
	}

	.preview-actions {
		display: flex;
		gap: 10px;
	}

	.btn-rewrite {
		flex: 1;
		padding: 14px;
		border: 1.5px solid var(--color-light-line);
		border-radius: 12px;
		background: none;
		font-size: 0.95rem;
		font-weight: 600;
		font-family: inherit;
		color: var(--color-soft-brown);
		cursor: pointer;
		transition: border-color 0.15s;
	}
	.btn-rewrite:hover { border-color: var(--color-soft-brown); }

	.btn-save {
		flex: 2;
		padding: 14px;
		background: var(--color-terracotta);
		color: white;
		border: none;
		border-radius: 12px;
		font-size: 0.95rem;
		font-weight: 700;
		font-family: inherit;
		cursor: pointer;
		transition: opacity 0.15s;
	}
	.btn-save:disabled { opacity: 0.55; cursor: not-allowed; }
</style>
