<script lang="ts">
	import type { AnalysisMode } from '$lib/types';
	import { onMount } from 'svelte';

	interface Props {
		mode: AnalysisMode;
	}
	let { mode }: Props = $props();

	const steps = $derived(
		mode === 'fast'
			? [
				'영상 정보를 확인했어요',
				'자막을 읽고 있어요',
				'재료와 순서를 정리하는 중...',
				'거의 다 됐어요!'
			]
			: [
				'영상 정보를 확인했어요',
				'영상을 듣고 있어요',
				'자막과 교차 검증하는 중...',
				'재료와 순서를 정리하는 중...',
				'거의 다 됐어요!'
			]
	);

	let currentStep = $state(0);

	onMount(() => {
		const interval = setInterval(() => {
			if (currentStep < steps.length - 1) {
				currentStep++;
			}
		}, mode === 'fast' ? 3000 : 5000);

		return () => clearInterval(interval);
	});
</script>

<div class="progress-area">
	<h2>레시피를 정리하고 있어요...</h2>
	<ul class="step-list">
		{#each steps as step, i}
			<li class:done={i < currentStep} class:active={i === currentStep} class:pending={i > currentStep}>
				<span class="indicator">
					{#if i < currentStep}✓{:else if i === currentStep}›{:else}·{/if}
				</span>
				<span class="text">{step}</span>
			</li>
		{/each}
	</ul>
	<p class="hint">보통 30초에서 1분 정도 걸려요</p>
</div>

<style>
	.progress-area {
		text-align: center;
		padding: 3rem 0;
	}
	h2 {
		font-size: 1.4rem;
		margin-bottom: 2rem;
		color: var(--color-warm-brown);
	}
	.step-list {
		list-style: none;
		display: inline-flex;
		flex-direction: column;
		gap: 0.8rem;
		text-align: left;
		margin-bottom: 2rem;
	}
	.step-list li {
		display: flex;
		align-items: center;
		gap: 0.7rem;
		font-size: 1rem;
		transition: all 0.3s ease;
	}
	.indicator {
		width: 24px;
		height: 24px;
		display: flex;
		align-items: center;
		justify-content: center;
		font-weight: 700;
		font-size: 0.9rem;
		border-radius: 50%;
		flex-shrink: 0;
	}
	.done .indicator {
		background: var(--color-sage);
		color: white;
	}
	.done .text {
		color: var(--color-soft-brown);
	}
	.active .indicator {
		background: var(--color-terracotta);
		color: white;
		animation: pulse 1.5s infinite;
	}
	.active .text {
		color: var(--color-warm-brown);
		font-weight: 600;
	}
	.pending .indicator {
		background: var(--color-light-line);
		color: var(--color-soft-brown);
	}
	.pending .text {
		color: var(--color-light-line);
	}
	@keyframes pulse {
		0%, 100% { transform: scale(1); }
		50% { transform: scale(1.1); }
	}
	.hint {
		font-size: 0.9rem;
		color: var(--color-soft-brown);
	}
</style>
