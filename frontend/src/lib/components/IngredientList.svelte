<script lang="ts">
	import type { Ingredient } from '$lib/types';

	interface Props {
		ingredients: Ingredient[];
	}
	let { ingredients }: Props = $props();

	const grouped = $derived(
		ingredients.reduce<Record<string, Ingredient[]>>((acc, item) => {
			const cat = item.category || '기타';
			if (!acc[cat]) acc[cat] = [];
			acc[cat].push(item);
			return acc;
		}, {})
	);
</script>

<div class="ingredients-section">
	<div class="section-divider">
		<span class="divider-line"></span>
		<span class="divider-text">재료</span>
		<span class="divider-line"></span>
	</div>
	{#each Object.entries(grouped) as [category, items]}
		<div class="category-group">
			<h4 class="category-name">{category}</h4>
			<ul>
				{#each items as item}
					<li class="ingredient-row">
						<label class="check-label">
							<input type="checkbox" />
							<span class="check-box"></span>
							<span class="item-name">{item.name}</span>
							<span class="dotted-line"></span>
							<span class="item-amount">
								{item.amount ?? ''}{item.unit ?? ''}
							</span>
						</label>
					</li>
				{/each}
			</ul>
		</div>
	{/each}
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

	.category-group {
		margin-bottom: 1.2rem;
	}
	.category-name {
		font-size: 0.85rem;
		font-weight: 600;
		color: var(--color-soft-brown);
		margin-bottom: 0.5rem;
	}
	ul { list-style: none; }

	.ingredient-row {
		margin-bottom: 0.3rem;
	}
	.check-label {
		display: flex;
		align-items: center;
		gap: 0.6rem;
		cursor: pointer;
		padding: 0.35rem 0;
	}
	.check-label input { display: none; }
	.check-box {
		width: 18px;
		height: 18px;
		border: 2px solid var(--color-light-line);
		border-radius: 4px;
		flex-shrink: 0;
		position: relative;
		transition: var(--transition);
	}
	.check-label input:checked + .check-box {
		background: var(--color-sage);
		border-color: var(--color-sage);
	}
	.check-label input:checked + .check-box::after {
		content: '✓';
		position: absolute;
		inset: 0;
		display: flex;
		align-items: center;
		justify-content: center;
		color: white;
		font-size: 0.7rem;
		font-weight: 700;
	}
	.check-label input:checked ~ .item-name,
	.check-label input:checked ~ .item-amount {
		opacity: 0.5;
		text-decoration: line-through;
	}

	.item-name {
		font-weight: 500;
		white-space: nowrap;
	}
	.dotted-line {
		flex: 1;
		border-bottom: 1px dotted var(--color-light-line);
		min-width: 20px;
		margin: 0 0.3rem;
		align-self: flex-end;
		margin-bottom: 4px;
	}
	.item-amount {
		font-family: var(--font-number);
		font-weight: 600;
		font-size: 0.9rem;
		color: var(--color-soft-brown);
		white-space: nowrap;
	}
</style>
