<script lang="ts">
	import type { Ingredient } from '$lib/types';
	import { browser } from '$app/environment';

	interface Props {
		ingredients: Ingredient[];
		storageKey?: string;
		showCheckbox?: boolean;
		oncart?: () => void;
		cartLoading?: boolean;
	}
	let { ingredients, storageKey = '', showCheckbox = true, oncart, cartLoading = false }: Props = $props();

	const lsKey = $derived(storageKey ? `recipe_checked_${storageKey}` : '');
	let checkedItems: string[] = $state([]);

	// 페이지 로드 시 localStorage에서 복원
	$effect(() => {
		if (!lsKey || !browser) return;
		try {
			const stored = localStorage.getItem(lsKey);
			checkedItems = stored ? JSON.parse(stored) : [];
		} catch {
			checkedItems = [];
		}
	});

	function toggle(name: string) {
		if (checkedItems.includes(name)) {
			checkedItems = checkedItems.filter(n => n !== name);
		} else {
			checkedItems = [...checkedItems, name];
		}
		if (lsKey && browser) {
			try { localStorage.setItem(lsKey, JSON.stringify(checkedItems)); } catch {}
		}
	}

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
		{#if oncart}
			<span class="divider-text">재료</span>
			<button class="btn-cart" onclick={oncart} disabled={cartLoading}>
				{cartLoading ? '담는 중...' : '🛒 재료 담기'}
			</button>
		{:else}
			<span class="divider-line"></span>
			<span class="divider-text">재료</span>
			<span class="divider-line"></span>
		{/if}
	</div>
	{#each Object.entries(grouped) as [category, items]}
		<div class="category-group">
			<h4 class="category-name">{category}</h4>
			<ul>
				{#each items as item}
					<li class="ingredient-row">
						{#if showCheckbox}
							<label class="check-label">
								<input
									type="checkbox"
									checked={checkedItems.includes(item.name)}
									onchange={() => toggle(item.name)}
								/>
								<span class="check-box"></span>
								<span class="item-name">{item.name}</span>
								<span class="dotted-line"></span>
								<span class="item-amount">
									{item.amount ?? ''}{item.unit ?? ''}
								</span>
							</label>
						{:else}
							<div class="simple-row">
								<span class="item-name">{item.name}</span>
								<span class="dotted-line"></span>
								<span class="item-amount">
									{item.amount ?? ''}{item.unit ?? ''}
								</span>
							</div>
						{/if}
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
	.check-label, .simple-row {
		display: flex;
		align-items: center;
		gap: 0.6rem;
		padding: 0.35rem 0;
		min-height: 36px;
	}
	.check-label {
		cursor: pointer;
		min-height: 44px;
	}
	.check-label input { display: none; }
	.check-box {
		width: 20px;
		height: 20px;
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
		font-size: 0.75rem;
		font-weight: 700;
	}
	.check-label input:checked ~ .item-name,
	.check-label input:checked ~ .item-amount {
		opacity: 0.45;
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

	.btn-cart {
		margin-left: auto;
		font-size: 0.78rem;
		font-weight: 600;
		padding: 0 0.85rem;
		height: 28px;
		border: 1.5px solid var(--color-light-line);
		border-radius: 20px;
		background: none;
		color: var(--color-soft-brown);
		cursor: pointer;
		white-space: nowrap;
		display: inline-flex;
		align-items: center;
		font-family: inherit;
		transition: border-color 0.15s, color 0.15s;
		flex-shrink: 0;
	}
	.btn-cart:hover:not(:disabled) {
		border-color: var(--color-terracotta);
		color: var(--color-terracotta);
	}
	.btn-cart:disabled { opacity: 0.6; cursor: not-allowed; }
</style>
