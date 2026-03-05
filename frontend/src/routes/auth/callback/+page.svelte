<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { page } from '$app/state';
	import { supabase } from '$lib/supabase';

	onMount(async () => {
		const { error } = await supabase.auth.getSession();
		if (error) {
			await goto('/login?error=auth_failed');
			return;
		}
		const redirect = page.url.searchParams.get('redirect') || '/my-recipes';
		await goto(redirect);
	});
</script>

<div class="callback-loading">
	<p>로그인 처리 중...</p>
</div>

<style>
	.callback-loading {
		display: flex;
		align-items: center;
		justify-content: center;
		min-height: calc(100vh - 120px);
		color: var(--color-soft-brown);
		font-size: 1rem;
	}
</style>
