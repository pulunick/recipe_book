<script lang="ts">
	interface Props {
		rating: number | null;      // 현재 별점 (null = 미평가)
		readonly?: boolean;         // 읽기 전용 모드
		size?: 'sm' | 'md';
		onchange?: (rating: number) => void;
	}

	let { rating, readonly = false, size = 'md', onchange }: Props = $props();

	let hovered = $state(0);

	function handleClick(star: number) {
		if (!readonly) onchange?.(star);
	}

	function displayRating(star: number) {
		const active = hovered > 0 ? hovered : (rating ?? 0);
		return star <= active ? 'filled' : 'empty';
	}
</script>

<span class="star-rating size-{size}">
	{#each [1, 2, 3, 4, 5] as star}
		<button
			type="button"
			class="star {displayRating(star)}"
			disabled={readonly}
			aria-label="{star}점"
			onclick={() => handleClick(star)}
			onmouseenter={() => !readonly && (hovered = star)}
			onmouseleave={() => (hovered = 0)}
		>★</button>
	{/each}
</span>

<style>
	.star-rating {
		display: inline-flex;
		gap: 1px;
	}
	.star {
		background: none;
		border: none;
		padding: 0;
		line-height: 1;
		font-family: inherit;
		transition: color 0.1s;
	}
	.size-md .star { font-size: 1.1rem; }
	.size-sm .star { font-size: 0.9rem; }

	.star.filled { color: #f5a623; }
	.star.empty  { color: var(--color-light-line); }

	.star:not(:disabled):hover { transform: scale(1.2); }
	.star:disabled { cursor: default; }
</style>
