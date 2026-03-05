<script lang="ts">
	import { getUser, isLoggedIn, signOut, openLoginModal } from '$lib/stores/auth.svelte';

	interface Props {
		activePage: 'home' | 'my-recipes';
	}
	let { activePage }: Props = $props();

	let showDropdown = $state(false);
	const user = $derived(getUser());
	const loggedIn = $derived(isLoggedIn());

	function toggleDropdown() {
		showDropdown = !showDropdown;
	}

	function handleClickOutside(event: MouseEvent) {
		const target = event.target as HTMLElement;
		if (!target.closest('.profile-area')) {
			showDropdown = false;
		}
	}

	async function handleSignOut() {
		showDropdown = false;
		await signOut();
	}
</script>

<svelte:window onclick={handleClickOutside} />

<nav class="navbar">
	<a href="/" class="logo">
		<img src="/logo.png" alt="해먹당" class="logo-img" />
	</a>
	<div class="nav-links">
		<a href="/my-recipes" class:active={activePage === 'my-recipes'}>내 레시피북</a>
		{#if loggedIn && user}
			<div class="profile-area">
				<button class="avatar-btn" onclick={toggleDropdown}>
					{#if user.user_metadata?.avatar_url}
						<img src={user.user_metadata.avatar_url} alt="프로필" class="avatar" />
					{:else}
						<div class="avatar avatar-fallback">
							{(user.user_metadata?.full_name || user.email || '?').charAt(0)}
						</div>
					{/if}
				</button>
				{#if showDropdown}
					<div class="dropdown">
						<p class="dropdown-name">{user.user_metadata?.full_name || user.email}</p>
						<button class="dropdown-item" onclick={handleSignOut}>로그아웃</button>
					</div>
				{/if}
			</div>
		{:else}
			<button class="login-btn" onclick={() => openLoginModal()}>로그인</button>
		{/if}
	</div>
</nav>

<style>
	.navbar {
		display: flex;
		justify-content: space-between;
		align-items: center;
		max-width: 960px;
		margin: 0 auto;
		padding: 1.2rem var(--page-padding-desktop);
		border-bottom: 1px solid var(--color-light-line);
	}
	.logo {
		display: flex;
		align-items: center;
	}
	.logo-img {
		height: 64px;
		width: auto;
	}
	.logo:hover { opacity: 0.85; }
	.nav-links {
		display: flex;
		align-items: center;
		gap: 1.5rem;
	}
	.nav-links a {
		color: var(--color-soft-brown);
		font-weight: 500;
		font-size: 0.95rem;
	}
	.nav-links a.active {
		color: var(--color-terracotta);
		font-weight: 600;
	}
	.login-btn {
		display: inline-block;
		background: none;
		border: 1.5px solid var(--color-light-line);
		color: var(--color-soft-brown);
		padding: 0.45rem 1.2rem;
		border-radius: 8px;
		font-size: 0.9rem;
		font-weight: 500;
		font-family: inherit;
		text-decoration: none;
		cursor: pointer;
	}
	.login-btn:hover {
		border-color: var(--color-terracotta);
		color: var(--color-terracotta);
	}

	/* 프로필 영역 */
	.profile-area {
		position: relative;
	}
	.avatar-btn {
		background: none;
		border: none;
		padding: 0;
		cursor: pointer;
		border-radius: 50%;
	}
	.avatar {
		width: 32px;
		height: 32px;
		border-radius: 50%;
		border: 2px solid var(--color-light-line);
		object-fit: cover;
		transition: border-color 0.15s;
	}
	.avatar-btn:hover .avatar {
		border-color: var(--color-terracotta);
	}
	.avatar-fallback {
		display: flex;
		align-items: center;
		justify-content: center;
		background: var(--color-terracotta);
		color: #fff;
		font-size: 0.85rem;
		font-weight: 600;
	}

	/* 드롭다운 */
	.dropdown {
		position: absolute;
		top: calc(100% + 8px);
		right: 0;
		background: #fff;
		border-radius: 12px;
		box-shadow: 0 4px 20px rgba(0, 0, 0, 0.12);
		padding: 0.75rem;
		min-width: 180px;
		z-index: 100;
	}
	.dropdown-name {
		font-size: 0.85rem;
		color: var(--color-warm-brown);
		font-weight: 600;
		padding: 0.4rem 0.5rem;
		margin: 0;
		border-bottom: 1px solid var(--color-light-line);
		margin-bottom: 0.4rem;
		word-break: break-all;
	}
	.dropdown-item {
		display: block;
		width: 100%;
		text-align: left;
		background: none;
		border: none;
		padding: 0.5rem;
		border-radius: 8px;
		font-size: 0.9rem;
		color: var(--color-soft-brown);
		cursor: pointer;
	}
	.dropdown-item:hover {
		background: var(--color-paper);
		color: var(--color-terracotta);
	}

	@media (max-width: 767px) {
		.navbar { padding: 1rem var(--page-padding-mobile); }
	}
</style>
