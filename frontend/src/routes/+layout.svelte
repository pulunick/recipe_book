<script lang="ts">
	import '../app.css';
	import { onMount } from 'svelte';
	import Navbar from '$lib/components/Navbar.svelte';
	import LoginModal from '$lib/components/LoginModal.svelte';
	import { page } from '$app/state';
	import { initAuth } from '$lib/stores/auth.svelte';

	let { children } = $props();

	onMount(() => {
		initAuth();
	});

	const activePage = $derived(
		page.url.pathname.startsWith('/my-recipes') ? 'my-recipes' as const : 'home' as const
	);
</script>

<svelte:head>
	<link rel="preconnect" href="https://fonts.googleapis.com">
	<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin="anonymous">
	<link href="https://fonts.googleapis.com/css2?family=Nunito:wght@400;600;700&family=Nanum+Myeongjo&display=swap" rel="stylesheet">
</svelte:head>

<Navbar {activePage} />
<LoginModal />
{@render children()}
