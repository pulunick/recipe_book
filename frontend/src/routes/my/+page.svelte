<script lang="ts">
	// 마이페이지 — Phase 2 구현 예정
	import { getUser, signOut } from '$lib/stores/auth.svelte';
	import { goto } from '$app/navigation';

	const user = $derived(getUser());

	async function handleSignOut() {
		await signOut();
		goto('/');
	}
</script>

<svelte:head>
	<title>해먹당 — 마이</title>
</svelte:head>

<div class="my-page">
	{#if user}
		<div class="profile-section">
			{#if user.user_metadata?.avatar_url}
				<img src={user.user_metadata.avatar_url} alt="프로필" class="profile-avatar" />
			{:else}
				<div class="profile-avatar avatar-fallback">
					{(user.user_metadata?.full_name || user.email || '?').charAt(0)}
				</div>
			{/if}
			<p class="profile-name">{user.user_metadata?.full_name || '사용자'}</p>
			<p class="profile-email">{user.email}</p>
		</div>
	{/if}

	<div class="menu-section">
		<div class="stub-notice">
			<p>마이페이지 기능은 곧 출시됩니다.</p>
		</div>

		{#if user}
			<button class="signout-btn" onclick={handleSignOut}>로그아웃</button>
		{/if}
	</div>
</div>

<style>
	.my-page {
		padding: 24px 16px;
	}

	.profile-section {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 8px;
		padding: 24px 0 32px;
	}

	.profile-avatar {
		width: 72px;
		height: 72px;
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
		font-size: 1.6rem;
		font-weight: 700;
	}

	.profile-name {
		font-size: 1.1rem;
		font-weight: 700;
		color: var(--color-warm-brown);
	}

	.profile-email {
		font-size: 0.82rem;
		color: var(--color-soft-brown);
	}

	.menu-section {
		display: flex;
		flex-direction: column;
		gap: 12px;
	}

	.stub-notice {
		text-align: center;
		padding: 20px;
		background: var(--color-cream);
		border-radius: 12px;
		font-size: 0.875rem;
		color: var(--color-soft-brown);
	}

	.signout-btn {
		width: 100%;
		padding: 13px;
		background: none;
		border: 1.5px solid var(--color-light-line);
		border-radius: 12px;
		font-size: 0.95rem;
		font-weight: 500;
		color: var(--color-soft-brown);
		cursor: pointer;
		font-family: inherit;
		transition: var(--transition);
	}

	.signout-btn:hover {
		border-color: var(--color-muted-red);
		color: var(--color-muted-red);
	}
</style>
