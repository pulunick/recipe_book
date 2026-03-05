<script lang="ts">
	import '../app.css';
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { page } from '$app/state';
	import { initAuth, isLoggedIn, getUser, signOut, openLoginModal } from '$lib/stores/auth.svelte';
	import { getAnalysis, dismissAnalysis } from '$lib/stores/analysis.svelte';
	import LoginModal from '$lib/components/LoginModal.svelte';
	import BottomNav from '$lib/components/BottomNav.svelte';
	import AddRecipeSheet from '$lib/components/AddRecipeSheet.svelte';

	let { children } = $props();

	let sheetOpen = $state(false);
	let showDropdown = $state(false);

	const loggedIn = $derived(isLoggedIn());
	const user = $derived(getUser());
	const analysis = $derived(getAnalysis());

	// 헤더 숨김 조건: OAuth 콜백
	const hideHeader = $derived(page.url.pathname.startsWith('/auth/callback'));

	onMount(() => {
		initAuth();
	});

	function handleClickOutside(e: MouseEvent) {
		const target = e.target as HTMLElement;
		if (!target.closest('.profile-area')) {
			showDropdown = false;
		}
	}

	async function handleSignOut() {
		showDropdown = false;
		await signOut();
		goto('/');
	}

	function handleGoToRecipe() {
		const path = analysis.navigateTo;
		dismissAnalysis();
		if (path) goto(path);
	}
</script>

<svelte:window onclick={handleClickOutside} />

<svelte:head>
	<link rel="preconnect" href="https://fonts.googleapis.com">
	<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin="anonymous">
	<link href="https://fonts.googleapis.com/css2?family=Nunito:wght@400;600;700&family=Nanum+Myeongjo&display=swap" rel="stylesheet">
</svelte:head>

<div class="app-shell">
	{#if !hideHeader}
		<header class="slim-header">
			<a href="/" class="logo">
				<img src="/logo.png" alt="해먹당" class="logo-img" />
			</a>
			<div class="header-right">
				{#if loggedIn && user}
					<div class="profile-area">
						<button class="avatar-btn" onclick={() => (showDropdown = !showDropdown)}>
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
		</header>
	{/if}

	<main class="page-content">
		{@render children()}
	</main>

	<BottomNav onAddClick={() => (sheetOpen = true)} />
</div>

<LoginModal />
<AddRecipeSheet open={sheetOpen} onClose={() => (sheetOpen = false)} />

<!-- 분석 완료 / 에러 팝업 -->
{#if analysis.status === 'done' || analysis.status === 'error'}
	<div class="analysis-popup" role="dialog" aria-live="polite">
		{#if analysis.status === 'done'}
			<div class="popup-icon done">✅</div>
			<div class="popup-body">
				<p class="popup-title">레시피 분석 완료!</p>
				{#if analysis.recipeTitle}
					<p class="popup-subtitle">{analysis.recipeTitle}</p>
				{/if}
			</div>
			<div class="popup-actions">
				<button class="popup-dismiss" onclick={dismissAnalysis}>닫기</button>
				<button class="popup-go" onclick={handleGoToRecipe}>보러 가기 →</button>
			</div>
		{:else}
			<div class="popup-icon error">❌</div>
			<div class="popup-body">
				<p class="popup-title">분석 실패</p>
				<p class="popup-subtitle">{analysis.error}</p>
			</div>
			<button class="popup-dismiss" onclick={dismissAnalysis}>닫기</button>
		{/if}
	</div>
{/if}

<style>
	/* 앱 셸: 전체 너비 */
	.app-shell {
		position: relative;
		width: 100%;
		min-height: 100dvh;
		background: var(--color-paper);
		display: flex;
		flex-direction: column;
	}

	/* 슬림 헤더 */
	.slim-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 0 16px;
		height: 48px;
		border-bottom: 1px solid var(--color-light-line);
		background: var(--color-paper);
		flex-shrink: 0;
		position: sticky;
		top: 0;
		z-index: 40;
	}

	.logo {
		display: flex;
		align-items: center;
		text-decoration: none;
	}

	.logo-img {
		height: 36px;
		width: auto;
	}

	.header-right {
		display: flex;
		align-items: center;
	}

	.login-btn {
		background: none;
		border: 1.5px solid var(--color-light-line);
		color: var(--color-soft-brown);
		padding: 0.35rem 1rem;
		border-radius: 8px;
		font-size: 0.85rem;
		font-weight: 500;
		font-family: inherit;
		cursor: pointer;
		transition: var(--transition);
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
		width: 30px;
		height: 30px;
		border-radius: 50%;
		border: 2px solid var(--color-light-line);
		object-fit: cover;
	}

	.avatar-fallback {
		display: flex;
		align-items: center;
		justify-content: center;
		background: var(--color-terracotta);
		color: #fff;
		font-size: 0.8rem;
		font-weight: 600;
	}

	.dropdown {
		position: absolute;
		top: calc(100% + 8px);
		right: 0;
		background: #fff;
		border-radius: 12px;
		box-shadow: 0 4px 20px rgba(0, 0, 0, 0.12);
		padding: 0.75rem;
		min-width: 160px;
		z-index: 100;
	}

	.dropdown-name {
		font-size: 0.82rem;
		color: var(--color-warm-brown);
		font-weight: 600;
		padding: 0.3rem 0.5rem;
		margin: 0 0 0.4rem;
		border-bottom: 1px solid var(--color-light-line);
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
		font-size: 0.88rem;
		color: var(--color-soft-brown);
		cursor: pointer;
		font-family: inherit;
	}

	.dropdown-item:hover {
		background: var(--color-paper);
		color: var(--color-terracotta);
	}

	/* 페이지 콘텐츠 */
	.page-content {
		flex: 1;
		/* 바텀 네비 높이만큼 하단 여백 */
		padding-bottom: calc(60px + env(safe-area-inset-bottom));
	}

	/* 분석 완료/에러 팝업 */
	.analysis-popup {
		position: fixed;
		bottom: calc(72px + env(safe-area-inset-bottom));
		left: 50%;
		transform: translateX(-50%);
		width: calc(100% - 32px);
		max-width: 420px;
		background: #fff;
		border-radius: 16px;
		box-shadow: 0 8px 32px rgba(0, 0, 0, 0.14);
		padding: 16px;
		display: flex;
		align-items: center;
		gap: 12px;
		z-index: 60;
		animation: popup-in 0.25s ease;
	}

	@keyframes popup-in {
		from { transform: translateX(-50%) translateY(12px); opacity: 0; }
		to { transform: translateX(-50%) translateY(0); opacity: 1; }
	}

	.popup-icon {
		font-size: 1.4rem;
		flex-shrink: 0;
	}

	.popup-body {
		flex: 1;
		min-width: 0;
	}

	.popup-title {
		font-size: 0.9rem;
		font-weight: 700;
		color: var(--color-warm-brown);
		margin-bottom: 2px;
	}

	.popup-subtitle {
		font-size: 0.78rem;
		color: var(--color-soft-brown);
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	.popup-actions {
		display: flex;
		gap: 8px;
		flex-shrink: 0;
	}

	.popup-dismiss {
		padding: 6px 12px;
		border-radius: 8px;
		border: 1.5px solid var(--color-light-line);
		background: none;
		font-size: 0.8rem;
		color: var(--color-soft-brown);
		font-family: inherit;
		cursor: pointer;
	}

	.popup-go {
		padding: 6px 14px;
		border-radius: 8px;
		border: none;
		background: var(--color-terracotta);
		color: #fff;
		font-size: 0.8rem;
		font-weight: 600;
		font-family: inherit;
		cursor: pointer;
		white-space: nowrap;
	}

	.popup-go:hover {
		background: #b5633f;
	}
</style>
