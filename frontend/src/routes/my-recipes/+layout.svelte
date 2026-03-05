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
		min-height: calc(100vh - 120px);
	}

	.spinner {
		width: 40px;
		height: 40px;
		border: 3px solid var(--color-cream, #f5f0eb);
		border-top-color: var(--color-soft-brown, #8b6f47);
		border-radius: 50%;
		animation: spin 0.8s linear infinite;
	}

	@keyframes spin {
		to { transform: rotate(360deg); }
	}
</style>
