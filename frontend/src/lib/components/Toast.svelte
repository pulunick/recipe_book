<script lang="ts">
	import { fly } from 'svelte/transition';

	interface Props {
		message: string;
		show: boolean;
		ondismiss: () => void;
	}
	let { message, show, ondismiss }: Props = $props();

	$effect(() => {
		if (show) {
			const timer = setTimeout(ondismiss, 3000);
			return () => clearTimeout(timer);
		}
	});
</script>

{#if show}
	<div class="toast" transition:fly={{ y: 16, duration: 220 }}>
		<span class="icon">✓</span>
		{message}
	</div>
{/if}

<style>
	.toast {
		position: fixed;
		bottom: 2rem;
		left: 50%;
		transform: translateX(-50%);
		background: var(--color-sage);
		color: white;
		padding: 0.75rem 1.6rem;
		border-radius: 30px;
		font-weight: 600;
		font-size: 0.95rem;
		z-index: 200;
		box-shadow: 0 4px 16px rgba(0,0,0,0.15);
		display: flex;
		align-items: center;
		gap: 0.5rem;
		white-space: nowrap;
	}
	.icon { font-size: 1rem; }
</style>
