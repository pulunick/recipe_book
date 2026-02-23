<script lang="ts">
	import type { RecipeStep } from '$lib/types';

	interface Props {
		steps: RecipeStep[];
	}
	let { steps }: Props = $props();
</script>

<div class="steps-section">
	<div class="section-divider">
		<span class="divider-line"></span>
		<span class="divider-text">만드는 법</span>
		<span class="divider-line"></span>
	</div>
	<ol class="step-list">
		{#each steps as step}
			<li class="step-item">
				<div class="step-header">
					<span class="step-number">{step.step_number}.</span>
					{#if step.timer}
						<span class="timer-badge">{step.timer}</span>
					{/if}
				</div>
				<p class="step-desc">{step.description}</p>
			</li>
		{/each}
	</ol>
</div>

<style>
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

	.step-list {
		list-style: none;
		counter-reset: none;
	}
	.step-item {
		margin-bottom: 1.5rem;
		padding-left: 0.5rem;
	}
	.step-header {
		display: flex;
		align-items: center;
		gap: 0.8rem;
		margin-bottom: 0.4rem;
	}
	.step-number {
		font-weight: 700;
		font-size: 1.1rem;
		color: var(--color-terracotta);
	}
	.timer-badge {
		font-family: var(--font-number);
		font-size: 0.8rem;
		font-weight: 600;
		background: var(--color-terracotta);
		color: white;
		padding: 0.2rem 0.7rem;
		border-radius: 20px;
	}
	.step-desc {
		color: var(--color-warm-brown);
		line-height: 1.7;
		padding-left: 1.2rem;
	}
</style>
