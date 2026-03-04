<script lang="ts">
	import type { RecipeStep } from '$lib/types';
	import { Timer } from 'lucide-svelte';

	interface Props {
		steps: RecipeStep[];
	}
	let { steps }: Props = $props();

	// 완료된 단계 추적 (클릭으로 토글)
	let completed = $state<Set<number>>(new Set());

	// **텍스트** → <mark> 변환
	function renderStep(text: string): string {
		return text.replace(/\*\*(.+?)\*\*/g, '<mark class="step-highlight">$1</mark>');
	}

	function toggleStep(n: number) {
		const next = new Set(completed);
		next.has(n) ? next.delete(n) : next.add(n);
		completed = next;
	}

	const doneCount = $derived(completed.size);
</script>

<div class="steps-section">
	<div class="section-header">
		<span class="section-title">만드는 법</span>
		<span class="step-progress">
			{#if doneCount > 0}
				{doneCount}/{steps.length} 완료
			{:else}
				{steps.length}단계
			{/if}
		</span>
	</div>

	<ol class="step-list">
		{#each steps as step (step.step_number)}
			{@const done = completed.has(step.step_number)}
			<li class="step-item" class:done>
				<button
					class="step-num-btn"
					onclick={() => toggleStep(step.step_number)}
					aria-label="{step.step_number}단계 {done ? '완료 취소' : '완료'}"
				>
					{#if done}
						<span class="step-check">✓</span>
					{:else}
						<span class="step-num">{step.step_number}</span>
					{/if}
				</button>

				<div class="step-body">
					{#if step.timer}
						<span class="timer-badge"><Timer size={14} /> {step.timer}</span>
					{/if}
					<p class="step-desc">{@html renderStep(step.description)}</p>
				</div>
			</li>
		{/each}
	</ol>
</div>

<style>
	.steps-section { margin-top: 2rem; }

	.section-header {
		display: flex;
		align-items: baseline;
		gap: 0.6rem;
		margin-bottom: 1.4rem;
	}
	.section-title {
		font-size: 0.85rem;
		font-weight: 700;
		color: var(--color-soft-brown);
	}
	.step-progress {
		font-size: 0.75rem;
		color: var(--color-terracotta);
		font-weight: 600;
	}

	/* 타임라인 컨테이너 */
	.step-list {
		list-style: none;
		padding: 0;
		margin: 0;
		position: relative;
	}
	/* 좌측 수직 연결선 */
	.step-list::before {
		content: '';
		position: absolute;
		left: 15px;
		top: 16px;
		bottom: 16px;
		width: 2px;
		background: var(--color-light-line);
		border-radius: 2px;
	}

	.step-item {
		display: flex;
		gap: 1rem;
		margin-bottom: 1.5rem;
		position: relative;
		align-items: flex-start;
	}
	.step-item:last-child { margin-bottom: 0; }

	/* 원형 번호 배지 (타임라인 연결선 위에 표시) */
	.step-num-btn {
		flex-shrink: 0;
		width: 32px;
		height: 32px;
		border-radius: 50%;
		border: 2px solid var(--color-terracotta);
		background: white;
		display: flex;
		align-items: center;
		justify-content: center;
		cursor: pointer;
		position: relative;
		z-index: 1;
		transition: background 0.18s, border-color 0.18s;
	}
	.step-num-btn:hover {
		background: var(--color-cream);
	}
	.step-num {
		font-size: 0.82rem;
		font-weight: 700;
		color: var(--color-terracotta);
		line-height: 1;
	}
	.step-check {
		font-size: 0.82rem;
		font-weight: 700;
		color: white;
		line-height: 1;
	}

	/* 완료 상태 */
	.step-item.done .step-num-btn {
		background: var(--color-terracotta);
		border-color: var(--color-terracotta);
	}

	.step-body {
		flex: 1;
		padding-top: 0.3rem;
	}

	.timer-badge {
		display: inline-flex;
		align-items: center;
		gap: 0.25rem;
		font-size: 0.75rem;
		font-weight: 600;
		background: color-mix(in srgb, var(--color-terracotta) 10%, transparent);
		color: var(--color-terracotta);
		padding: 0.15rem 0.55rem;
		border-radius: 10px;
		margin-bottom: 0.35rem;
	}

	.step-desc {
		margin: 0;
		color: var(--color-warm-brown);
		line-height: 1.75;
		font-size: 0.95rem;
		transition: opacity 0.2s;
	}
	:global(.step-highlight) {
		background: color-mix(in srgb, var(--color-terracotta) 14%, transparent);
		color: var(--color-terracotta);
		font-weight: 700;
		border-radius: 3px;
		padding: 0 2px;
	}
	.step-item.done .step-desc {
		opacity: 0.35;
		text-decoration: line-through;
		text-decoration-color: var(--color-soft-brown);
	}
</style>
