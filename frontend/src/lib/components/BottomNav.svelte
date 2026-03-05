<script lang="ts">
	import { page } from '$app/state';
	import { goto } from '$app/navigation';
	import { isLoggedIn, openLoginModal } from '$lib/stores/auth.svelte';
	import { getAnalysis } from '$lib/stores/analysis.svelte';

	interface Props {
		onAddClick: () => void;
	}
	let { onAddClick }: Props = $props();

	const analysis = $derived(getAnalysis());
	const analyzing = $derived(analysis.status === 'analyzing');

	const currentPath = $derived(page.url.pathname);
	const loggedIn = $derived(isLoggedIn());

	// 바텀 네비 숨김 조건: 쿠킹 모드, OAuth 콜백
	const hidden = $derived(
		currentPath.includes('/cook') || currentPath.startsWith('/auth/callback')
	);

	function isActive(path: string): boolean {
		if (path === '/') return currentPath === '/';
		return currentPath.startsWith(path);
	}

	function handleNavClick(path: string, requiresAuth = false) {
		if (requiresAuth && !loggedIn) {
			openLoginModal(path);
			return;
		}
		goto(path);
	}
</script>

{#if !hidden}
	<nav class="bottom-nav">
		<!-- 탐색 -->
		<button
			class="nav-item"
			class:active={isActive('/')}
			onclick={() => handleNavClick('/')}
			aria-label="탐색"
		>
			<svg class="nav-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
				<circle cx="12" cy="12" r="10" />
				<polygon points="16.24 7.76 14.12 14.12 7.76 16.24 9.88 9.88 16.24 7.76" />
			</svg>
			<span class="nav-label">탐색</span>
		</button>

		<!-- 내 레시피 -->
		<button
			class="nav-item"
			class:active={isActive('/my-recipes')}
			onclick={() => handleNavClick('/my-recipes', true)}
			aria-label="내 레시피"
		>
			<svg class="nav-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
				<path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20" />
				<path d="M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z" />
			</svg>
			<span class="nav-label">내 레시피</span>
		</button>

		<!-- 중앙 + 버튼 (분석 중이면 스피너) -->
		<button class="nav-item add-btn" onclick={onAddClick} aria-label={analyzing ? '분석 중' : '레시피 추가'}>
			<div class="add-circle" class:pulsing={analyzing}>
				{#if analyzing}
					<span class="add-spinner"></span>
				{:else}
					<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" class="add-icon">
						<line x1="12" y1="5" x2="12" y2="19" />
						<line x1="5" y1="12" x2="19" y2="12" />
					</svg>
				{/if}
			</div>
		</button>

		<!-- 장바구니 -->
		<button
			class="nav-item"
			class:active={isActive('/cart')}
			onclick={() => handleNavClick('/cart', true)}
			aria-label="장바구니"
		>
			<svg class="nav-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
				<circle cx="9" cy="21" r="1" />
				<circle cx="20" cy="21" r="1" />
				<path d="M1 1h4l2.68 13.39a2 2 0 0 0 2 1.61h9.72a2 2 0 0 0 2-1.61L23 6H6" />
			</svg>
			<span class="nav-label">장바구니</span>
		</button>

		<!-- 마이 -->
		<button
			class="nav-item"
			class:active={isActive('/my')}
			onclick={() => handleNavClick('/my', true)}
			aria-label="마이"
		>
			<svg class="nav-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
				<path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2" />
				<circle cx="12" cy="7" r="4" />
			</svg>
			<span class="nav-label">마이</span>
		</button>
	</nav>
{/if}

<style>
	.bottom-nav {
		position: fixed;
		bottom: 0;
		left: 0;
		right: 0;
		width: 100%;
		height: calc(60px + env(safe-area-inset-bottom));
		padding-bottom: env(safe-area-inset-bottom);
		background: #fff;
		border-top: 1px solid var(--color-light-line);
		display: flex;
		align-items: center;
		justify-content: space-around;
		z-index: 50;
		box-shadow: 0 -2px 12px rgba(0, 0, 0, 0.06);
	}

	.nav-item {
		flex: 1;
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		gap: 3px;
		height: 60px;
		background: none;
		border: none;
		padding: 0;
		color: var(--color-soft-brown);
		cursor: pointer;
		transition: color 0.15s;
	}

	.nav-item.active {
		color: var(--color-terracotta);
	}

	.nav-icon {
		width: 22px;
		height: 22px;
	}

	.nav-label {
		font-size: 0.65rem;
		font-weight: 500;
		line-height: 1;
	}

	/* 중앙 + 버튼 */
	.add-btn {
		flex: 1;
		position: relative;
		justify-content: flex-start;
		padding-top: 0;
	}

	.add-circle {
		width: 52px;
		height: 52px;
		border-radius: 50%;
		background: var(--color-terracotta);
		display: flex;
		align-items: center;
		justify-content: center;
		box-shadow: 0 4px 14px rgba(196, 112, 75, 0.4);
		margin-top: -16px;
		transition: transform 0.15s, box-shadow 0.15s;
	}

	.add-btn:active .add-circle {
		transform: scale(0.93);
		box-shadow: 0 2px 8px rgba(196, 112, 75, 0.3);
	}

	.add-icon {
		width: 22px;
		height: 22px;
		color: #fff;
	}

	/* 분석 중 스피너 */
	.add-circle.pulsing {
		animation: pulse-glow 1.5s ease infinite;
	}

	.add-spinner {
		width: 22px;
		height: 22px;
		border: 2.5px solid rgba(255, 255, 255, 0.35);
		border-top-color: #fff;
		border-radius: 50%;
		animation: spin 0.7s linear infinite;
		display: block;
	}

	@keyframes spin {
		to { transform: rotate(360deg); }
	}

	@keyframes pulse-glow {
		0%, 100% { box-shadow: 0 4px 14px rgba(196, 112, 75, 0.4); }
		50% { box-shadow: 0 4px 22px rgba(196, 112, 75, 0.75); }
	}
</style>
