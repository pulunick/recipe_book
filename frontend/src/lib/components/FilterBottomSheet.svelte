<script lang="ts">
	import { isLoggedIn } from '$lib/stores/auth.svelte';

	interface FilterState {
		sort: string;
		difficulty: string;
		cookingTime: string;
		calorieRange: string;
		hideCollected: boolean;
	}

	interface Props {
		filter: FilterState;
		onapply: (f: FilterState) => void;
		onclose: () => void;
	}

	let { filter, onapply, onclose }: Props = $props();
	const loggedIn = $derived(isLoggedIn());

	// 로컬 복사본으로 편집 (적용 전까지 원본 유지)
	let local = $state<FilterState>({ ...filter });

	function reset() {
		local = { sort: 'popular', difficulty: '', cookingTime: '', calorieRange: '', hideCollected: false };
	}

	function apply() {
		onapply({ ...local });
		onclose();
	}

	const SORT_OPTIONS = [
		{ value: 'popular',  label: '인기순' },
		{ value: 'latest',   label: '최신순' },
		{ value: 'calories', label: '칼로리 낮은순' },
	];
	const DIFFICULTY_OPTIONS = [
		{ value: '', label: '전체' },
		{ value: '쉬움', label: '쉬움' },
		{ value: '보통', label: '보통' },
		{ value: '어려움', label: '어려움' },
	];
	const TIME_OPTIONS = [
		{ value: '', label: '전체' },
		{ value: '20', label: '20분 이하' },
		{ value: '60', label: '1시간 이하' },
		{ value: '61+', label: '1시간 초과' },
	];
	const CALORIE_OPTIONS = [
		{ value: '', label: '전체' },
		{ value: 'low', label: '500 이하' },
		{ value: 'mid', label: '500~800' },
		{ value: 'high', label: '800 초과' },
	];
</script>

<!-- 딤드 배경 -->
<div class="overlay" role="presentation" onclick={onclose}></div>

<div class="sheet" role="dialog" aria-modal="true" aria-label="필터 설정">
	<div class="sheet-header">
		<span class="sheet-title">필터 / 정렬</span>
		<button class="btn-reset" onclick={reset}>초기화</button>
	</div>

	<div class="sheet-body">
		<!-- 정렬 -->
		<div class="filter-section">
			<p class="section-label">정렬</p>
			<div class="chip-row">
				{#each SORT_OPTIONS as opt}
					<button
						class="filter-chip"
						class:active={local.sort === opt.value}
						onclick={() => local.sort = opt.value}
					>{opt.label}</button>
				{/each}
			</div>
		</div>

		<!-- 난이도 -->
		<div class="filter-section">
			<p class="section-label">난이도</p>
			<div class="chip-row">
				{#each DIFFICULTY_OPTIONS as opt}
					<button
						class="filter-chip"
						class:active={local.difficulty === opt.value}
						onclick={() => local.difficulty = opt.value}
					>{opt.label}</button>
				{/each}
			</div>
		</div>

		<!-- 조리시간 -->
		<div class="filter-section">
			<p class="section-label">조리시간</p>
			<div class="chip-row">
				{#each TIME_OPTIONS as opt}
					<button
						class="filter-chip"
						class:active={local.cookingTime === opt.value}
						onclick={() => local.cookingTime = opt.value}
					>{opt.label}</button>
				{/each}
			</div>
		</div>

		<!-- 칼로리 -->
		<div class="filter-section">
			<p class="section-label">칼로리 (1인분 기준)</p>
			<div class="chip-row">
				{#each CALORIE_OPTIONS as opt}
					<button
						class="filter-chip"
						class:active={local.calorieRange === opt.value}
						onclick={() => local.calorieRange = opt.value}
					>{opt.label}</button>
				{/each}
			</div>
		</div>

		<!-- 저장 숨기기 (로그인 시만) -->
		{#if loggedIn}
			<div class="filter-section toggle-section">
				<span class="section-label">이미 저장한 레시피 숨기기</span>
				<button
					class="toggle"
					class:on={local.hideCollected}
					onclick={() => local.hideCollected = !local.hideCollected}
					role="switch"
					aria-checked={local.hideCollected}
				>
					<span class="toggle-thumb"></span>
				</button>
			</div>
		{/if}
	</div>

	<div class="sheet-footer">
		<button class="btn-apply" onclick={apply}>적용하기</button>
	</div>
</div>

<style>
	.overlay {
		position: fixed;
		inset: 0;
		background: rgba(0, 0, 0, 0.4);
		z-index: 200;
	}

	.sheet {
		position: fixed;
		bottom: 0;
		left: 50%;
		transform: translateX(-50%);
		width: 100%;
		max-width: 480px;
		background: white;
		border-radius: 20px 20px 0 0;
		z-index: 201;
		display: flex;
		flex-direction: column;
		max-height: 85vh;
		animation: slideUp 0.22s ease-out;
	}

	@keyframes slideUp {
		from { transform: translateX(-50%) translateY(100%); }
		to   { transform: translateX(-50%) translateY(0); }
	}

	.sheet-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
		padding: 1.1rem 1.2rem 0.8rem;
		border-bottom: 1px solid var(--color-light-line);
		flex-shrink: 0;
	}

	.sheet-title {
		font-size: 1rem;
		font-weight: 700;
		color: var(--color-warm-brown);
	}

	.btn-reset {
		font-size: 0.82rem;
		color: var(--color-soft-brown);
		background: none;
		border: none;
		cursor: pointer;
		text-decoration: underline;
		padding: 0;
	}

	.sheet-body {
		overflow-y: auto;
		padding: 0.8rem 1.2rem;
		flex: 1;
	}

	.filter-section {
		margin-bottom: 1.2rem;
	}

	.section-label {
		font-size: 0.8rem;
		font-weight: 600;
		color: var(--color-soft-brown);
		margin-bottom: 0.55rem;
	}

	.chip-row {
		display: flex;
		flex-wrap: wrap;
		gap: 0.4rem;
	}

	.filter-chip {
		font-size: 0.82rem;
		font-weight: 500;
		padding: 0.35rem 0.85rem;
		border-radius: 20px;
		border: 1.5px solid var(--color-light-line);
		background: none;
		color: var(--color-soft-brown);
		cursor: pointer;
		font-family: inherit;
		transition: border-color 0.15s, background 0.15s, color 0.15s;
	}

	.filter-chip.active {
		border-color: var(--color-terracotta);
		background: var(--color-terracotta);
		color: white;
		font-weight: 600;
	}

	/* 토글 */
	.toggle-section {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 0.5rem 0;
		border-top: 1px solid var(--color-light-line);
	}

	.toggle {
		width: 44px;
		height: 24px;
		border-radius: 12px;
		border: none;
		background: var(--color-light-line);
		cursor: pointer;
		position: relative;
		transition: background 0.2s;
		flex-shrink: 0;
		padding: 0;
	}

	.toggle.on {
		background: var(--color-terracotta);
	}

	.toggle-thumb {
		position: absolute;
		top: 3px;
		left: 3px;
		width: 18px;
		height: 18px;
		border-radius: 50%;
		background: white;
		transition: transform 0.2s;
		box-shadow: 0 1px 3px rgba(0,0,0,0.2);
	}

	.toggle.on .toggle-thumb {
		transform: translateX(20px);
	}

	.sheet-footer {
		padding: 0.8rem 1.2rem calc(0.8rem + env(safe-area-inset-bottom));
		flex-shrink: 0;
		border-top: 1px solid var(--color-light-line);
	}

	.btn-apply {
		width: 100%;
		height: 48px;
		background: var(--color-terracotta);
		color: white;
		border: none;
		border-radius: 12px;
		font-size: 1rem;
		font-weight: 700;
		cursor: pointer;
		font-family: inherit;
		transition: opacity 0.15s;
	}

	.btn-apply:hover { opacity: 0.9; }
</style>
