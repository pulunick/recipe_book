<script lang="ts">
	interface Props {
		activePage: 'home' | 'my-recipes';
	}
	let { activePage }: Props = $props();
</script>

<nav class="navbar">
	<a href="/" class="logo">
		<img src="/logo.png" alt="해먹당" class="logo-img" />
	</a>
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
