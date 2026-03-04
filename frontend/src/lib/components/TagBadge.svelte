<script lang="ts">
	import type { CollectionTag } from '$lib/types';
	import { X } from 'lucide-svelte';

	interface Props {
		tag: CollectionTag;
		removable?: boolean;
		onremove?: (tagId: number) => void;
	}

	let { tag, removable = false, onremove }: Props = $props();
</script>

<span class="tag-badge" style:--tag-color={tag.color}>
	{tag.name}
	{#if removable}
		<button
			type="button"
			class="remove-btn"
			aria-label="{tag.name} 태그 제거"
			onclick={() => onremove?.(tag.id)}
		><X size={12} /></button>
	{/if}
</span>

<style>
	.tag-badge {
		display: inline-flex;
		align-items: center;
		gap: 0.25rem;
		font-size: 0.72rem;
		font-weight: 600;
		padding: 0.15rem 0.5rem;
		border-radius: 10px;
		background: color-mix(in srgb, var(--tag-color) 18%, transparent);
		color: color-mix(in srgb, var(--tag-color) 80%, #333);
		border: 1px solid color-mix(in srgb, var(--tag-color) 30%, transparent);
		white-space: nowrap;
	}
	.remove-btn {
		background: none;
		border: none;
		padding: 0;
		font-size: 0.9rem;
		line-height: 1;
		color: inherit;
		opacity: 0.6;
		display: flex;
		align-items: center;
	}
	.remove-btn:hover { opacity: 1; }
</style>
