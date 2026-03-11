<script lang="ts">
	import { goto } from '$app/navigation';
	import { extractRecipeFromText, saveTextRecipe } from '$lib/api';
	import FlavorProfile from '$lib/components/FlavorProfile.svelte';
	import type { Recipe, Ingredient, RecipeStep } from '$lib/types';

	type Step = 'input' | 'preview';
	let step = $state<Step>('input');

	let title = $state('');
	let text = $state('');
	let isAnalyzing = $state(false);
	let isSaving = $state(false);
	let errorMsg = $state('');
	let recipe = $state<Recipe | null>(null);

	// 공개 여부
	let isPublic = $state(false);

	const MIN_LENGTH = 50;
	const textLength = $derived(text.length);
	const canAnalyze = $derived(textLength >= MIN_LENGTH && !isAnalyzing);

	const CATEGORIES = ['주재료', '부재료', '양념', '육수', '기타'];
	const DIFFICULTIES = ['쉬움', '보통', '어려움'];

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
			const collectionId = await saveTextRecipe(recipe, undefined, isPublic);
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

	// --- 재료 편집 ---
	function addIngredient() {
		if (!recipe) return;
		recipe = {
			...recipe,
			ingredients: [...(recipe.ingredients ?? []), { name: '', amount: null, unit: null, category: '기타' }]
		};
	}

	function removeIngredient(i: number) {
		if (!recipe) return;
		recipe = { ...recipe, ingredients: (recipe.ingredients ?? []).filter((_, idx) => idx !== i) };
	}

	function updateIngredient(i: number, field: keyof Ingredient, value: string) {
		if (!recipe?.ingredients) return;
		const updated = recipe.ingredients.map((ing, idx) =>
			idx === i ? { ...ing, [field]: value || null } : ing
		);
		recipe = { ...recipe, ingredients: updated };
	}

	// --- 단계 편집 ---
	function addStep() {
		if (!recipe) return;
		const steps = recipe.steps ?? [];
		recipe = {
			...recipe,
			steps: [...steps, { step_number: steps.length + 1, description: '', timer: null }]
		};
	}

	function removeStep(i: number) {
		if (!recipe) return;
		const updated = (recipe.steps ?? [])
			.filter((_, idx) => idx !== i)
			.map((s, idx) => ({ ...s, step_number: idx + 1 }));
		recipe = { ...recipe, steps: updated };
	}

	function updateStep(i: number, value: string) {
		if (!recipe?.steps) return;
		recipe = {
			...recipe,
			steps: recipe.steps.map((s, idx) => idx === i ? { ...s, description: value } : s)
		};
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
			{step === 'input' ? '레시피 작성' : 'AI 변환 결과'}
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
						placeholder="제목이 없으면 AI가 자동으로 생성해드려요."
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
					<span class="notice-icon">✏️</span>
					<span>AI가 변환한 결과예요. 저장 전에 바로 수정할 수 있어요.</span>
				</div>

				<div class="preview-card">
					<!-- 제목 -->
					<input
						class="edit-title"
						type="text"
						bind:value={recipe.title}
						placeholder="레시피 제목"
						maxlength="100"
					/>

					<!-- 기본 정보 -->
					<div class="meta-edit-row">
						<div class="meta-field">
							<label class="meta-label" for="edit-servings">인분</label>
							<input id="edit-servings" class="meta-input" type="text" bind:value={recipe.servings} placeholder="예: 2인분" />
						</div>
						<div class="meta-field">
							<label class="meta-label" for="edit-cooking-time">시간</label>
							<input id="edit-cooking-time" class="meta-input" type="text" bind:value={recipe.cooking_time} placeholder="예: 30분" />
						</div>
						<div class="meta-field">
							<label class="meta-label" for="edit-difficulty">난이도</label>
							<select id="edit-difficulty" class="meta-select" bind:value={recipe.difficulty}>
								<option value={null}>-</option>
								{#each DIFFICULTIES as d}
									<option value={d}>{d}</option>
								{/each}
							</select>
						</div>
					</div>

					<!-- 요약 -->
					<div class="edit-section">
						<p class="edit-section-label">한 줄 소개</p>
						<textarea
							class="edit-summary"
							bind:value={recipe.summary}
							placeholder="레시피 한 줄 소개"
							rows="4"
						></textarea>
					</div>

					<!-- 맛 프로파일 (읽기 전용) -->
					{#if recipe.flavor}
						<FlavorProfile flavor={recipe.flavor} />
					{/if}

					<!-- 재료 -->
					<div class="edit-section">
						<div class="edit-section-header">
							<p class="edit-section-label">재료</p>
							<button class="btn-add-row" onclick={addIngredient}>+ 추가</button>
						</div>
						<div class="ingredients-edit">
							{#each (recipe.ingredients ?? []) as ing, i (i)}
								<div class="ing-row">
									<input
										class="ing-input ing-name"
										type="text"
										value={ing.name}
										placeholder="재료명"
										oninput={(e) => updateIngredient(i, 'name', (e.target as HTMLInputElement).value)}
									/>
									<input
										class="ing-input ing-amount"
										type="text"
										value={ing.amount ?? ''}
										placeholder="수량"
										oninput={(e) => updateIngredient(i, 'amount', (e.target as HTMLInputElement).value)}
									/>
									<input
										class="ing-input ing-unit"
										type="text"
										value={ing.unit ?? ''}
										placeholder="단위"
										oninput={(e) => updateIngredient(i, 'unit', (e.target as HTMLInputElement).value)}
									/>
									<select
										class="ing-select"
										value={ing.category}
										onchange={(e) => updateIngredient(i, 'category', (e.target as HTMLSelectElement).value)}
									>
										{#each CATEGORIES as c}
											<option value={c}>{c}</option>
										{/each}
									</select>
									<button class="btn-remove-row" onclick={() => removeIngredient(i)} aria-label="삭제">×</button>
								</div>
							{/each}
						</div>
					</div>

					<!-- 조리 순서 -->
					<div class="edit-section">
						<div class="edit-section-header">
							<p class="edit-section-label">만드는 법</p>
							<button class="btn-add-row" onclick={addStep}>+ 추가</button>
						</div>
						<div class="steps-edit">
							{#each (recipe.steps ?? []) as s, i (i)}
								<div class="step-row">
									<span class="step-num">{i + 1}</span>
									<textarea
										class="step-textarea"
										value={s.description}
										placeholder="조리 단계 설명"
										rows="2"
										oninput={(e) => updateStep(i, (e.target as HTMLTextAreaElement).value)}
									></textarea>
									<button class="btn-remove-row" onclick={() => removeStep(i)} aria-label="삭제">×</button>
								</div>
							{/each}
						</div>
					</div>

					<!-- 꿀팁 -->
					<div class="edit-section">
						<p class="edit-section-label">꿀팁 <span class="optional">(선택)</span></p>
						<textarea
							class="edit-tip"
							bind:value={recipe.tip}
							placeholder="보관법, 변형 레시피, 주의사항 등"
							rows="3"
						></textarea>
					</div>
				</div>

				<!-- 공개 여부 토글 -->
				<label class="public-toggle">
					<div class="toggle-switch" class:on={isPublic}>
						<input type="checkbox" bind:checked={isPublic} />
						<span class="toggle-knob"></span>
					</div>
					<div class="toggle-text">
						<span class="toggle-label">{isPublic ? '탐색 탭에 공개' : '나만 보기 (비공개)'}</span>
						<span class="toggle-desc">{isPublic ? '다른 사용자들도 이 레시피를 볼 수 있어요' : '나만 볼 수 있어요'}</span>
					</div>
				</label>

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
		min-height: 100svh;
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
		top: 48px;
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

	/* 미리보기/편집 단계 */
	.preview-section {
		padding: 16px 16px 48px;
		display: flex;
		flex-direction: column;
		gap: 14px;
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
		padding: 18px 16px;
		box-shadow: 0 2px 8px rgba(0,0,0,0.06);
		display: flex;
		flex-direction: column;
		gap: 16px;
	}

	/* 제목 편집 */
	.edit-title {
		width: 100%;
		font-size: 1.2rem;
		font-weight: 700;
		color: var(--color-warm-brown);
		border: none;
		border-bottom: 1.5px solid var(--color-light-line);
		border-radius: 0;
		padding: 4px 0 8px;
		font-family: inherit;
		background: transparent;
		box-sizing: border-box;
		transition: border-color 0.15s;
	}
	.edit-title:focus { outline: none; border-bottom-color: var(--color-terracotta); }

	/* 기본 정보 편집 */
	.meta-edit-row {
		display: flex;
		gap: 8px;
	}

	.meta-field {
		flex: 1;
		display: flex;
		flex-direction: column;
		gap: 4px;
	}

	.meta-label {
		font-size: 0.7rem;
		font-weight: 700;
		color: var(--color-soft-brown);
		text-transform: uppercase;
		letter-spacing: 0.04em;
	}

	.meta-input,
	.meta-select {
		width: 100%;
		padding: 7px 8px;
		border: 1.5px solid var(--color-light-line);
		border-radius: 8px;
		font-size: 0.82rem;
		font-family: inherit;
		color: var(--color-warm-brown);
		background: var(--color-paper);
		box-sizing: border-box;
		transition: border-color 0.15s;
	}
	.meta-input:focus,
	.meta-select:focus { outline: none; border-color: var(--color-terracotta); }

	/* 섹션 공통 */
	.edit-section {
		display: flex;
		flex-direction: column;
		gap: 8px;
	}

	.edit-section-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
	}

	.edit-section-label {
		font-size: 0.78rem;
		font-weight: 700;
		color: var(--color-soft-brown);
		text-transform: uppercase;
		letter-spacing: 0.05em;
		margin: 0;
	}

	.btn-add-row {
		font-size: 0.75rem;
		font-weight: 600;
		color: var(--color-terracotta);
		background: none;
		border: none;
		padding: 0;
		cursor: pointer;
		font-family: inherit;
	}

	/* 요약 */
	.edit-summary,
	.edit-tip {
		width: 100%;
		padding: 10px 12px;
		border: 1.5px solid var(--color-light-line);
		border-radius: 10px;
		font-size: 0.88rem;
		line-height: 1.6;
		font-family: inherit;
		color: var(--color-warm-brown);
		background: var(--color-paper);
		resize: vertical;
		box-sizing: border-box;
		transition: border-color 0.15s;
	}
	.edit-summary { min-height: 90px; }
	.edit-tip { min-height: 80px; }
	.edit-summary:focus,
	.edit-tip:focus { outline: none; border-color: var(--color-terracotta); }

	/* 재료 편집 */
	.ingredients-edit {
		display: flex;
		flex-direction: column;
		gap: 6px;
	}

	.ing-row {
		display: grid;
		grid-template-columns: 1fr 60px 52px 72px 28px;
		gap: 4px;
		align-items: center;
	}

	.ing-input,
	.ing-select {
		padding: 7px 8px;
		border: 1.5px solid var(--color-light-line);
		border-radius: 8px;
		font-size: 0.82rem;
		font-family: inherit;
		color: var(--color-warm-brown);
		background: white;
		box-sizing: border-box;
		min-width: 0;
		transition: border-color 0.15s;
	}
	.ing-input:focus,
	.ing-select:focus { outline: none; border-color: var(--color-terracotta); }

	/* 단계 편집 */
	.steps-edit {
		display: flex;
		flex-direction: column;
		gap: 8px;
	}

	.step-row {
		display: grid;
		grid-template-columns: 26px 1fr 28px;
		gap: 6px;
		align-items: flex-start;
	}

	.step-num {
		width: 26px;
		height: 26px;
		background: var(--color-terracotta);
		color: white;
		border-radius: 50%;
		font-size: 0.75rem;
		font-weight: 700;
		display: flex;
		align-items: center;
		justify-content: center;
		flex-shrink: 0;
		margin-top: 6px;
	}

	.step-textarea {
		padding: 8px 10px;
		border: 1.5px solid var(--color-light-line);
		border-radius: 8px;
		font-size: 0.88rem;
		line-height: 1.6;
		font-family: inherit;
		color: var(--color-warm-brown);
		background: white;
		resize: vertical;
		box-sizing: border-box;
		min-height: 72px;
		transition: border-color 0.15s;
	}
	.step-textarea:focus { outline: none; border-color: var(--color-terracotta); }

	.btn-remove-row {
		background: none;
		border: none;
		padding: 0;
		cursor: pointer;
		color: var(--color-light-line);
		font-size: 1.1rem;
		line-height: 1;
		transition: color 0.15s;
		margin-top: 6px;
	}
	.btn-remove-row:hover { color: var(--color-soft-brown); }

	/* 공개 여부 토글 */
	.public-toggle {
		display: flex;
		align-items: center;
		gap: 14px;
		background: white;
		border-radius: 14px;
		padding: 14px 16px;
		box-shadow: 0 1px 4px rgba(0,0,0,0.06);
		cursor: pointer;
	}

	.toggle-switch {
		position: relative;
		width: 44px;
		height: 26px;
		flex-shrink: 0;
	}
	.toggle-switch input { opacity: 0; width: 0; height: 0; position: absolute; }

	.toggle-knob {
		position: absolute;
		inset: 0;
		background: var(--color-light-line);
		border-radius: 13px;
		transition: background 0.2s;
		cursor: pointer;
	}
	.toggle-knob::after {
		content: '';
		position: absolute;
		top: 3px;
		left: 3px;
		width: 20px;
		height: 20px;
		background: white;
		border-radius: 50%;
		transition: transform 0.2s;
		box-shadow: 0 1px 3px rgba(0,0,0,0.2);
	}
	.toggle-switch.on .toggle-knob { background: var(--color-terracotta); }
	.toggle-switch.on .toggle-knob::after { transform: translateX(18px); }

	.toggle-text {
		display: flex;
		flex-direction: column;
		gap: 2px;
	}
	.toggle-label {
		font-size: 0.9rem;
		font-weight: 700;
		color: var(--color-warm-brown);
	}
	.toggle-desc {
		font-size: 0.75rem;
		color: var(--color-soft-brown);
	}

	/* 하단 액션 */
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
