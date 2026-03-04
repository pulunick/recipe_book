<script lang="ts">
	import { fade } from 'svelte/transition';

	let visible = $state(false);

	$effect(() => {
		function onScroll() {
			visible = window.scrollY > 300;
		}
		window.addEventListener('scroll', onScroll, { passive: true });
		return () => window.removeEventListener('scroll', onScroll);
	});

	function scrollToTop() {
		window.scrollTo({ top: 0, behavior: 'smooth' });
	}
</script>

{#if visible}
	<button
		class="scroll-to-top"
		onclick={scrollToTop}
		aria-label="맨 위로 스크롤"
		transition:fade={{ duration: 200 }}
	>
		&#8593;
	</button>
{/if}

<style>
	.scroll-to-top {
		position: fixed;
		right: 1.5rem;
		bottom: 5rem;
		width: 44px;
		height: 44px;
		border-radius: 50%;
		border: 1px solid var(--color-light-line);
		background: white;
		box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
		font-size: 1.2rem;
		color: var(--color-warm-brown);
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		z-index: 40;
		transition: background 0.2s, box-shadow 0.2s;
	}
	.scroll-to-top:hover {
		background: var(--color-cream);
		box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
	}
</style>
