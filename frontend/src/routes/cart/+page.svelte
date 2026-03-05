<script lang="ts">
	// 장바구니 페이지 — Phase 2 구현 예정
</script>

<svelte:head>
	<title>해먹당 — 장바구니</title>
</svelte:head>

<div class="stub-page">
	<div class="stub-icon">
		<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
			<circle cx="9" cy="21" r="1" />
			<circle cx="20" cy="21" r="1" />
			<path d="M1 1h4l2.68 13.39a2 2 0 0 0 2 1.61h9.72a2 2 0 0 0 2-1.61L23 6H6" />
		</svg>
	</div>
	<p class="stub-title">장바구니</p>
	<p class="stub-desc">장보기 목록 기능은 곧 출시됩니다.</p>
</div>

<style>
	.stub-page {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		min-height: calc(100dvh - 120px);
		gap: 12px;
		text-align: center;
		padding: 24px;
	}

	.stub-icon {
		width: 64px;
		height: 64px;
		color: var(--color-light-line);
	}

	.stub-icon svg {
		width: 100%;
		height: 100%;
	}

	.stub-title {
		font-size: 1.1rem;
		font-weight: 600;
		color: var(--color-warm-brown);
	}

	.stub-desc {
		font-size: 0.875rem;
		color: var(--color-soft-brown);
	}
</style>
