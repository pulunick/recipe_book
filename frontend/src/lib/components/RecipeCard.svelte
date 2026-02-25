<script lang="ts">
	import type { CollectionItem, FlavorProfile } from '$lib/types';

	interface Props {
		item: CollectionItem;
	}
	let { item }: Props = $props();

	const topFlavors = $derived.by(() => {
		const f = item.recipe.flavor;
		const entries: { label: string; score: number }[] = [
			{ label: '짠맛', score: f.saltiness },
			{ label: '단맛', score: f.sweetness },
			{ label: '매운맛', score: f.spiciness },
			{ label: '신맛', score: f.sourness },
			{ label: '기름기', score: f.oiliness }
		];
		return entries
			.filter(e => e.score >= 3)
			.sort((a, b) => b.score - a.score)
			.slice(0, 3);
	});

	const flavorColorMap: Record<string, string> = {
		'짠맛': 'var(--flavor-salty)',
		'단맛': 'var(--flavor-sweet)',
		'매운맛': 'var(--flavor-spicy)',
		'신맛': 'var(--flavor-sour)',
		'기름기': 'var(--flavor-oily)'
	};
</script>

<a href="/library/{item.id}" class="list-item">
	<div class="item-main">
		<div class="title-row">
			<h3 class="title">{item.recipe.title}</h3>
			{#if item.recipe.category}
				<span class="category-badge">{item.recipe.category}</span>
			{/if}
		</div>
		<div class="item-meta">
			<span class="flavor-tags">
				{#each topFlavors as { label, score }}
					<span class="flavor-tag" style:--tag-color={flavorColorMap[label]}>
						{label}{'●'.repeat(score)}
					</span>
				{/each}
			</span>
			<span class="date">{new Date(item.created_at).toLocaleDateString('ko-KR', { month: 'numeric', day: 'numeric' })} 저장</span>
		</div>
	</div>
	{#if item.custom_tip}
		<p class="memo">내 메모: "{item.custom_tip}"</p>
	{/if}
</a>

<style>
	.list-item {
		display: block;
		padding: 1.2rem 1.5rem;
		text-decoration: none;
		color: inherit;
		transition: background 0.15s;
		border-bottom: 1px dashed var(--color-light-line);
	}
	.list-item:hover {
		background: var(--color-cream);
	}

	.item-main {
		display: flex;
		flex-direction: column;
		gap: 0.4rem;
	}
	.title-row {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		flex-wrap: wrap;
	}
	.title {
		font-size: 1.05rem;
		font-weight: 600;
		color: var(--color-warm-brown);
	}
	.category-badge {
		font-size: 0.72rem;
		font-weight: 600;
		color: var(--color-terracotta);
		background: color-mix(in srgb, var(--color-terracotta) 12%, transparent);
		border-radius: 10px;
		padding: 0.15rem 0.5rem;
		white-space: nowrap;
	}
	.item-meta {
		display: flex;
		align-items: center;
		gap: 1rem;
		font-size: 0.85rem;
	}
	.flavor-tags {
		display: flex;
		gap: 0.5rem;
	}
	.flavor-tag {
		color: var(--tag-color);
		font-weight: 500;
		font-size: 0.8rem;
	}
	.date {
		color: var(--color-soft-brown);
	}
	.memo {
		margin-top: 0.4rem;
		font-family: var(--font-memo);
		font-size: 0.9rem;
		color: var(--color-soft-brown);
		font-style: italic;
	}
</style>
