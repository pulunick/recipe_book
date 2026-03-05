<script lang="ts">
	import { isModalOpen, closeLoginModal, getModalRedirect, signInWithGoogle } from '$lib/stores/auth.svelte';

	const open = $derived(isModalOpen());

	function handleBackdrop(e: MouseEvent) {
		if (e.target === e.currentTarget) closeLoginModal();
	}

	function handleGoogle() {
		const redirect = getModalRedirect();
		signInWithGoogle(redirect ?? undefined);
	}
</script>

{#if open}
	<!-- svelte-ignore a11y_click_events_have_key_events a11y_no_static_element_interactions -->
	<div class="backdrop" onclick={handleBackdrop}>
		<div class="modal-card">
			<button class="close-btn" onclick={closeLoginModal} aria-label="닫기">✕</button>

			<img src="/logo.png" alt="해먹당" class="modal-logo" />

			<button class="google-btn" onclick={handleGoogle}>
				<svg viewBox="0 0 24 24" width="20" height="20" style="flex-shrink:0">
					<path d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92a5.06 5.06 0 0 1-2.2 3.32v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.1z" fill="#4285F4"/>
					<path d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" fill="#34A853"/>
					<path d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z" fill="#FBBC05"/>
					<path d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z" fill="#EA4335"/>
				</svg>
				Google로 시작하기
			</button>

			<p class="modal-desc">로그인하면 레시피를 저장하고 관리할 수 있어요</p>
		</div>
	</div>
{/if}

<style>
	.backdrop {
		position: fixed;
		inset: 0;
		background: rgba(0, 0, 0, 0.45);
		display: flex;
		align-items: center;
		justify-content: center;
		z-index: 1000;
		padding: 1rem;
		backdrop-filter: blur(2px);
	}

	.modal-card {
		background: #fff;
		border-radius: 20px;
		box-shadow: 0 8px 40px rgba(0, 0, 0, 0.15);
		padding: 3rem 2.5rem 2.5rem;
		max-width: 380px;
		width: 100%;
		text-align: center;
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 1.4rem;
		position: relative;
	}

	.close-btn {
		position: absolute;
		top: 1rem;
		right: 1rem;
		background: none;
		border: none;
		font-size: 1.1rem;
		color: var(--color-soft-brown);
		cursor: pointer;
		padding: 0.25rem 0.5rem;
		border-radius: 6px;
		line-height: 1;
	}
	.close-btn:hover { background: var(--color-cream); }

	.modal-logo {
		height: 160px;
		width: auto;
	}

	.google-btn {
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 0.75rem;
		width: 100%;
		padding: 0.75rem 1.5rem;
		background: #fff;
		border: 1.5px solid #dadce0;
		border-radius: 8px;
		font-size: 0.95rem;
		font-weight: 500;
		color: #3c4043;
		cursor: pointer;
		transition: background 0.15s, box-shadow 0.15s;
		font-family: inherit;
	}
	.google-btn:hover {
		background: #f7f8f8;
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
	}

	.modal-desc {
		font-size: 0.875rem;
		color: var(--color-soft-brown);
		line-height: 1.7;
		margin: 0;
	}
</style>
