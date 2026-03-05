<script lang="ts">
	import { goto } from '$app/navigation';
	import { page } from '$app/state';
	import { isLoggedIn, isLoading, openLoginModal } from '$lib/stores/auth.svelte';

	let { children } = $props();

	const loggedIn = $derived(isLoggedIn());
	const authLoading = $derived(isLoading());

	$effect(() => {
		if (!authLoading && !loggedIn) {
			openLoginModal(page.url.pathname);
			goto('/');
		}
	});
</script>

{#if authLoading}
	<div class="auth-loading">
		<div class="spinner"></div>
	</div>
{:else if loggedIn}
	{@render children()}
{/if}

<style>
	.auth-loading {
		display: flex;
		align-items: center;
		justify-content: center;
		min-height: calc(100dvh - 120px);
	}

	.spinner {
		width: 36px;
		height: 36px;
		border: 3px solid var(--color-cream);
		border-top-color: var(--color-soft-brown);
		border-radius: 50%;
		animation: spin 0.8s linear infinite;
	}

	@keyframes spin {
		to { transform: rotate(360deg); }
	}
</style>
