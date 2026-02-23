<script lang="ts">
	import type { FlavorProfile } from '$lib/types';

	interface Props {
		flavor: FlavorProfile;
	}
	let { flavor }: Props = $props();

	const axes: { key: keyof FlavorProfile; label: string; color: string }[] = [
		{ key: 'saltiness', label: '짠맛', color: 'var(--flavor-salty)' },
		{ key: 'sweetness', label: '단맛', color: 'var(--flavor-sweet)' },
		{ key: 'spiciness', label: '매운맛', color: 'var(--flavor-spicy)' },
		{ key: 'sourness', label: '신맛', color: 'var(--flavor-sour)' },
		{ key: 'oiliness', label: '기름기', color: 'var(--flavor-oily)' }
	];
</script>

<div class="flavor-section">
	<div class="section-divider">
		<span class="divider-line"></span>
		<span class="divider-text">맛 한눈에 보기</span>
		<span class="divider-line"></span>
	</div>
	<div class="flavor-grid">
		{#each axes as { key, label, color }}
			{@const score = Math.min(5, Math.max(0, Math.round(flavor[key] || 0)))}
			<div class="flavor-row">
				<span class="flavor-label">{label}</span>
				<div class="dots">
					{#each { length: 5 } as _, i}
						<span
							class="dot"
							class:filled={i < score}
							style:--dot-color={color}
						></span>
					{/each}
				</div>
			</div>
		{/each}
	</div>
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

	.flavor-grid {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 0.6rem 2rem;
	}
	.flavor-row {
		display: flex;
		align-items: center;
		gap: 0.8rem;
	}
	.flavor-label {
		width: 50px;
		font-size: 0.9rem;
		font-weight: 500;
		color: var(--color-soft-brown);
	}
	.dots { display: flex; gap: 4px; }
	.dot {
		width: 10px;
		height: 10px;
		border-radius: 50%;
		background: var(--color-light-line);
		transition: background 0.2s;
	}
	.dot.filled {
		background: var(--dot-color);
	}

	@media (max-width: 480px) {
		.flavor-grid {
			grid-template-columns: 1fr;
		}
	}
</style>
