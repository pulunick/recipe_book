<script lang="ts">
	import { page } from '$app/state';
	import { isLoggedIn, isLoading, openLoginModal } from '$lib/stores/auth.svelte';

	let { children } = $props();

	const loggedIn = $derived(isLoggedIn());
	const authLoading = $derived(isLoading());

	$effect(() => {
		if (!authLoading && !loggedIn) {
			openLoginModal(page.url.pathname);
		}
	});
</script>

{#if authLoading}
	<div class="auth-loading">
		<p>확인 중...</p>
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
		color: var(--color-soft-brown);
		font-size: 1rem;
	}
</style>
