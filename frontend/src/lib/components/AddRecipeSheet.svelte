<script lang="ts">
	import { goto } from '$app/navigation';
	import { isLoggedIn, openLoginModal } from '$lib/stores/auth.svelte';
	import { getAnalysis, startAnalysis } from '$lib/stores/analysis.svelte';

	interface Props {
		open: boolean;
		onClose: () => void;
	}
	let { open, onClose }: Props = $props();

	type SheetStep = 'menu' | 'youtube';
	let step = $state<SheetStep>('menu');
	let youtubeUrl = $state('');
	let errorMsg = $state('');

	const analysis = $derived(getAnalysis());

	const loggedIn = $derived(isLoggedIn());

	// 시트가 열릴 때마다 항상 메뉴 화면으로 초기화
	$effect(() => {
		if (open) {
			step = 'menu';
			youtubeUrl = '';
			errorMsg = '';
		}
	});

	function handleClose() {
		onClose();
	}

	function handleYoutubeSelect() {
		step = 'youtube';
		errorMsg = '';
	}

	function handleTextSelect() {
		if (!loggedIn) {
			handleClose();
			openLoginModal();
			return;
		}
		handleClose();
		goto('/write');
	}

	function getVideoId(url: string): string | null {
		const m = url.match(/(?:v=|\/|youtu\.be\/|embed\/|shorts\/)([0-9A-Za-z_-]{11})/);
		return m ? m[1] : null;
	}

	function handleAnalyze() {
		if (!youtubeUrl.trim()) {
			errorMsg = '유튜브 URL을 입력해주세요.';
			return;
		}
		if (!getVideoId(youtubeUrl)) {
			errorMsg = '올바른 유튜브 링크를 입력해주세요.';
			return;
		}

		// 즉시 시트 닫고 백그라운드에서 분석 시작
		const url = youtubeUrl.trim();
		handleClose();
		startAnalysis(url, loggedIn);
	}

	function handleKeydown(e: KeyboardEvent) {
		if (e.key === 'Escape') handleClose();
	}

	function handleBackdropClick(e: MouseEvent) {
		if ((e.target as HTMLElement).classList.contains('sheet-backdrop')) {
			handleClose();
		}
	}
</script>

<svelte:window onkeydown={handleKeydown} />

{#if open}
	<!-- svelte-ignore a11y_click_events_have_key_events -->
	<!-- svelte-ignore a11y_no_static_element_interactions -->
	<div class="sheet-backdrop" onclick={handleBackdropClick}>
		<div class="sheet" role="dialog" aria-modal="true" aria-label="레시피 추가">
			<div class="sheet-handle"></div>

			{#if step === 'menu'}
				<div class="sheet-content">
					<h2 class="sheet-title">레시피 추가</h2>
					<div class="menu-list">
						<!-- 유튜브 URL 분석 -->
						<button class="menu-item" onclick={handleYoutubeSelect}>
							<div class="menu-icon youtube-icon">
								<svg viewBox="0 0 24 24" fill="currentColor">
									<path d="M23.498 6.186a3.016 3.016 0 0 0-2.122-2.136C19.505 3.545 12 3.545 12 3.545s-7.505 0-9.377.505A3.017 3.017 0 0 0 .502 6.186C0 8.07 0 12 0 12s0 3.93.502 5.814a3.016 3.016 0 0 0 2.122 2.136c1.871.505 9.376.505 9.376.505s7.505 0 9.377-.505a3.015 3.015 0 0 0 2.122-2.136C24 15.93 24 12 24 12s0-3.93-.502-5.814zM9.545 15.568V8.432L15.818 12l-6.273 3.568z" />
								</svg>
							</div>
							<div class="menu-text">
								<p class="menu-name">유튜브 URL 분석</p>
								<p class="menu-desc">AI가 요리 영상에서 레시피를 자동 추출합니다</p>
							</div>
							<svg class="menu-arrow" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
								<polyline points="9 18 15 12 9 6" />
							</svg>
						</button>

						<!-- 텍스트로 직접 작성 -->
						<button class="menu-item" onclick={handleTextSelect}>
							<div class="menu-icon edit-icon">
								<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
									<path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7" />
									<path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z" />
								</svg>
							</div>
							<div class="menu-text">
								<p class="menu-name">직접 작성</p>
								<p class="menu-desc">나만의 레시피를 직접 입력합니다 (로그인 필요)</p>
							</div>
							<svg class="menu-arrow" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
								<polyline points="9 18 15 12 9 6" />
							</svg>
						</button>
					</div>
				</div>

			{:else if step === 'youtube'}
				<div class="sheet-content">
					<div class="sheet-header">
						<button class="back-btn" aria-label="뒤로" onclick={() => { step = 'menu'; errorMsg = ''; }}>
							<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
								<polyline points="15 18 9 12 15 6" />
							</svg>
						</button>
						<h2 class="sheet-title">유튜브 URL 분석</h2>
					</div>

					<p class="youtube-desc">
						유튜브 요리 영상 URL을 붙여넣으면<br />
						AI가 레시피를 자동으로 추출합니다
					</p>

					<div class="url-input-wrap">
						<input
							type="url"
							class="url-input"
							placeholder="https://www.youtube.com/watch?v=..."
							bind:value={youtubeUrl}
								onkeydown={(e) => e.key === 'Enter' && handleAnalyze()}
						/>
					</div>

					{#if errorMsg}
						<p class="error-msg">{errorMsg}</p>
					{/if}

					{#if !loggedIn}
						<p class="guest-notice">로그인 없이도 분석 가능합니다. 저장하려면 로그인하세요.</p>
					{/if}

					<button
						class="analyze-btn"
						onclick={handleAnalyze}
						disabled={analysis.status === 'analyzing' || !youtubeUrl.trim()}
					>
						{#if analysis.status === 'analyzing'}
							<span class="btn-spinner"></span>
							분석 중...
						{:else}
							분석하기
						{/if}
					</button>
				</div>
			{/if}
		</div>
	</div>
{/if}

<style>
	.sheet-backdrop {
		position: fixed;
		inset: 0;
		background: rgba(0, 0, 0, 0.45);
		z-index: 200;
		display: flex;
		align-items: flex-end;
		justify-content: center;
	}

	.sheet {
		width: 100%;
		max-width: 480px;
		background: #fff;
		border-radius: 20px 20px 0 0;
		padding-bottom: calc(16px + env(safe-area-inset-bottom));
		animation: slide-up 0.28s ease;
	}

	@keyframes slide-up {
		from { transform: translateY(100%); opacity: 0.6; }
		to { transform: translateY(0); opacity: 1; }
	}

	.sheet-handle {
		width: 40px;
		height: 4px;
		background: var(--color-light-line);
		border-radius: 2px;
		margin: 12px auto 0;
	}

	.sheet-content {
		padding: 16px 24px 8px;
	}

	.sheet-title {
		font-size: 1.1rem;
		font-weight: 700;
		color: var(--color-warm-brown);
		margin-bottom: 20px;
		text-align: center;
	}

	/* 메뉴 목록 */
	.menu-list {
		display: flex;
		flex-direction: column;
		gap: 10px;
	}

	.menu-item {
		display: flex;
		align-items: center;
		gap: 14px;
		padding: 14px 16px;
		background: var(--color-paper);
		border: 1px solid var(--color-light-line);
		border-radius: 14px;
		text-align: left;
		cursor: pointer;
		transition: background 0.15s, border-color 0.15s;
	}

	.menu-item:hover {
		background: var(--color-cream);
		border-color: var(--color-terracotta);
	}

	.menu-icon {
		width: 44px;
		height: 44px;
		border-radius: 12px;
		display: flex;
		align-items: center;
		justify-content: center;
		flex-shrink: 0;
	}

	.youtube-icon {
		background: #FF0000;
		color: #fff;
	}

	.youtube-icon svg {
		width: 22px;
		height: 22px;
	}

	.edit-icon {
		background: var(--color-cream);
		color: var(--color-warm-brown);
	}

	.edit-icon svg {
		width: 20px;
		height: 20px;
	}

	.menu-text {
		flex: 1;
		min-width: 0;
	}

	.menu-name {
		font-size: 0.95rem;
		font-weight: 600;
		color: var(--color-warm-brown);
		margin-bottom: 2px;
	}

	.menu-desc {
		font-size: 0.78rem;
		color: var(--color-soft-brown);
		line-height: 1.4;
	}

	.menu-arrow {
		width: 18px;
		height: 18px;
		color: var(--color-soft-brown);
		flex-shrink: 0;
	}

	/* 유튜브 입력 단계 */
	.sheet-header {
		display: flex;
		align-items: center;
		gap: 8px;
		margin-bottom: 16px;
	}

	.sheet-header .sheet-title {
		margin-bottom: 0;
		flex: 1;
	}

	.back-btn {
		background: none;
		border: none;
		padding: 4px;
		cursor: pointer;
		color: var(--color-soft-brown);
		display: flex;
		align-items: center;
	}

	.back-btn svg {
		width: 22px;
		height: 22px;
	}

	.youtube-desc {
		font-size: 0.875rem;
		color: var(--color-soft-brown);
		text-align: center;
		line-height: 1.6;
		margin-bottom: 20px;
	}

	.url-input-wrap {
		margin-bottom: 8px;
	}

	.url-input {
		width: 100%;
		padding: 12px 16px;
		border: 1.5px solid var(--color-light-line);
		border-radius: 12px;
		font-size: 0.9rem;
		font-family: inherit;
		color: var(--color-warm-brown);
		background: var(--color-paper);
		outline: none;
		transition: border-color 0.15s;
	}

	.url-input:focus {
		border-color: var(--color-terracotta);
	}

	.url-input::placeholder {
		color: var(--color-soft-brown);
		opacity: 0.6;
	}

	.error-msg {
		font-size: 0.82rem;
		color: var(--color-muted-red);
		margin-bottom: 8px;
	}

	.guest-notice {
		font-size: 0.78rem;
		color: var(--color-soft-brown);
		background: var(--color-cream);
		border-radius: 8px;
		padding: 8px 12px;
		margin-bottom: 12px;
		text-align: center;
	}

	.analyze-btn {
		width: 100%;
		padding: 14px;
		background: var(--color-terracotta);
		color: #fff;
		border: none;
		border-radius: 12px;
		font-size: 1rem;
		font-weight: 600;
		font-family: inherit;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 8px;
		transition: opacity 0.15s;
		margin-top: 4px;
	}

	.analyze-btn:disabled {
		opacity: 0.55;
		cursor: not-allowed;
	}

	.btn-spinner {
		width: 18px;
		height: 18px;
		border: 2.5px solid rgba(255, 255, 255, 0.4);
		border-top-color: #fff;
		border-radius: 50%;
		animation: spin 0.7s linear infinite;
		flex-shrink: 0;
	}

	@keyframes spin {
		to { transform: rotate(360deg); }
	}
</style>
