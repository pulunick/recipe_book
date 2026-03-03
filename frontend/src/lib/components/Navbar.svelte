<script lang="ts">
	import { page } from '$app/state';
	import { triggerHomeReset } from '$lib/homeReset';

	interface Props {
		activePage: 'home' | 'my-recipes';
	}
	let { activePage }: Props = $props();

	function handleLogoClick(e: MouseEvent) {
		// 이미 홈(/)에 있을 때는 SvelteKit 네비게이션 대신 상태 직접 초기화
		if (page.url.pathname === '/') {
			e.preventDefault();
			triggerHomeReset();
		}
	}
</script>

<nav class="navbar">
	<a href="/" class="logo" onclick={handleLogoClick}>마레픽</a>
	<div class="nav-links">
		<a href="/my-recipes" class:active={activePage === 'my-recipes'}>내 레시피북</a>
		<button class="login-btn">로그인</button>
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
		font-weight: 700;
		font-size: 1.3rem;
		color: var(--color-warm-brown);
		letter-spacing: -0.5px;
	}
	.logo:hover { color: var(--color-terracotta); }
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
		background: none;
		border: 1.5px solid var(--color-light-line);
		color: var(--color-soft-brown);
		padding: 0.45rem 1.2rem;
		border-radius: 8px;
		font-size: 0.9rem;
		font-weight: 500;
	}
	.login-btn:hover {
		border-color: var(--color-terracotta);
		color: var(--color-terracotta);
	}

	@media (max-width: 767px) {
		.navbar { padding: 1rem var(--page-padding-mobile); }
	}
</style>
