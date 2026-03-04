<script lang="ts">
	import { page } from '$app/stores';
</script>

<svelte:head>
	<title>오류 | 해먹당</title>
</svelte:head>

<main class="error-page">
	<div class="error-box">
		<div class="error-code">{$page.status}</div>
		<h1 class="error-title">
			{#if $page.status === 404}
				페이지를 찾을 수 없어요
			{:else if $page.status === 500}
				서버에 문제가 생겼어요
			{:else}
				문제가 생겼어요
			{/if}
		</h1>
		<p class="error-message">
			{$page.error?.message || '알 수 없는 오류가 발생했습니다.'}
		</p>
		<div class="actions">
			<a href="/" class="home-btn">홈으로 돌아가기</a>
			<a href="/my-recipes" class="library-btn">내 레시피북</a>
		</div>
	</div>
</main>

<style>
	.error-page {
		display: flex;
		align-items: center;
		justify-content: center;
		min-height: calc(100vh - 80px);
		padding: 2rem;
	}

	.error-box {
		text-align: center;
		max-width: 400px;
	}

	.error-code {
		font-size: 5rem;
		font-weight: 700;
		color: var(--color-light-line);
		line-height: 1;
		margin-bottom: 1rem;
	}

	.error-title {
		font-size: 1.4rem;
		color: var(--color-warm-brown);
		margin-bottom: 0.8rem;
	}

	.error-message {
		font-size: 0.95rem;
		color: var(--color-soft-brown);
		line-height: 1.7;
		margin-bottom: 2rem;
	}

	.actions {
		display: flex;
		gap: 0.8rem;
		justify-content: center;
		flex-wrap: wrap;
	}

	.home-btn {
		background: var(--color-terracotta);
		color: white;
		padding: 0.75rem 1.8rem;
		border-radius: 10px;
		font-weight: 600;
		text-decoration: none;
		font-size: 0.95rem;
	}
	.home-btn:hover { background: #b5633f; color: white; }

	.library-btn {
		background: none;
		border: 1.5px solid var(--color-light-line);
		color: var(--color-soft-brown);
		padding: 0.75rem 1.8rem;
		border-radius: 10px;
		font-weight: 500;
		text-decoration: none;
		font-size: 0.95rem;
	}
	.library-btn:hover {
		border-color: var(--color-soft-brown);
		color: var(--color-warm-brown);
	}
</style>
