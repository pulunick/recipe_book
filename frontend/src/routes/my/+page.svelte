<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { getUser, isLoggedIn, signOut, openLoginModal } from '$lib/stores/auth.svelte';
	import { getTasteProfile } from '$lib/api';
	import type { TasteProfileResponse } from '$lib/types';
	import MeokdangChatSheet from '$lib/components/MeokdangChatSheet.svelte';

	const user = $derived(getUser());
	const loggedIn = $derived(isLoggedIn());

	let tasteProfile = $state<TasteProfileResponse | null>(null);
	let tasteLoading = $state(false);
	let chatOpen = $state(false);

	// 비로그인 시 로그인 모달 유도
	onMount(async () => {
		if (!loggedIn) {
			openLoginModal('/my');
			return;
		}
		tasteLoading = true;
		try {
			tasteProfile = await getTasteProfile();
		} catch {
			// 로드 실패 시 null 유지 (placeholder 표시)
		} finally {
			tasteLoading = false;
		}
	});

	async function handleSignOut() {
		await signOut();
		goto('/');
	}

	// 맛 축 정보
	const FLAVOR_AXES = [
		{ key: 'saltiness' as const, label: '짠맛', color: 'var(--flavor-salty)' },
		{ key: 'sweetness' as const, label: '단맛', color: 'var(--flavor-sweet)' },
		{ key: 'spiciness' as const, label: '매운맛', color: 'var(--flavor-spicy)' },
		{ key: 'sourness' as const, label: '신맛', color: 'var(--flavor-sour)' },
		{ key: 'oiliness' as const, label: '기름진 맛', color: 'var(--flavor-oily)' },
	];

	// 이름에서 첫 번째 이름만 추출 (성 제외)
	function getDisplayName(): string {
		const fullName = user?.user_metadata?.full_name;
		if (!fullName) return '김씨';
		const parts = fullName.split(/\s+/);
		return parts.length > 1 ? parts[parts.length - 1] : fullName;
	}

	const PLACEHOLDER_WIDTHS = [60, 45, 75, 30, 50];
</script>

<svelte:head>
	<title>해먹당 — 마이</title>
</svelte:head>

<div class="my-page">
	{#if !loggedIn}
		<!-- 비로그인 상태 -->
		<div class="login-prompt">
			<div class="prompt-icon">
				<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
					<circle cx="12" cy="8" r="4"/>
					<path d="M4 20c0-4 3.6-7 8-7s8 3 8 7"/>
				</svg>
			</div>
			<p class="prompt-title">로그인이 필요해요</p>
			<p class="prompt-desc">로그인하면 입맛 분석, 요리 통계 등<br/>다양한 기능을 이용할 수 있어요.</p>
			<button class="btn-login" onclick={() => openLoginModal('/my')}>
				로그인하기
			</button>
		</div>
	{:else if user}
		<!-- 프로필 섹션 -->
		<div class="profile-section">
			<div class="profile-avatar-wrap">
				{#if user.user_metadata?.avatar_url}
					<img
						src={user.user_metadata.avatar_url}
						alt="프로필"
						class="profile-avatar"
					/>
				{:else}
					<div class="profile-avatar avatar-fallback">
						{(user.user_metadata?.full_name || user.email || '?').charAt(0)}
					</div>
				{/if}
			</div>
			<p class="profile-name">{user.user_metadata?.full_name || '사용자'}</p>
			<p class="profile-email">{user.email}</p>
		</div>

		<!-- 입맛 분석 차트 -->
		<section class="section">
			<div class="section-header">
				<h2 class="section-title">내 입맛 취향</h2>
			</div>

			{#if tasteLoading}
				<div class="taste-skeleton">
					{#each [80, 60, 90, 45, 70] as w}
						<div class="skeleton-bar-row">
							<div class="skeleton-label"></div>
							<div class="skeleton-track">
								<div class="skeleton-fill shimmer" style:width="{w}%"></div>
							</div>
						</div>
					{/each}
				</div>

			{:else if tasteProfile?.has_data && tasteProfile.profile}
				<!-- 데이터 있음: 실제 차트 -->
				<div class="taste-card">
					<div class="taste-bars">
						{#each FLAVOR_AXES as axis}
							{@const value = tasteProfile.profile![axis.key]}
							<div class="bar-row">
								<span class="bar-label">{axis.label}</span>
								<div class="bar-track">
									<div
										class="bar-fill"
										style:background={axis.color}
										style:width="{(value / 5) * 100}%"
									></div>
								</div>
								<span class="bar-value">{value.toFixed(1)}</span>
							</div>
						{/each}
					</div>

					<!-- 통계 칩 3종 -->
					<div class="stat-chips">
						<div class="stat-chip">
							<span class="stat-icon">⭐</span>
							<span class="stat-label">즐겨찾기</span>
							<span class="stat-value">{tasteProfile.favorite_count}개</span>
						</div>
						<div class="stat-chip">
							<span class="stat-icon">🍳</span>
							<span class="stat-label">총 요리</span>
							<span class="stat-value">{tasteProfile.total_cooked}회</span>
						</div>
						<div class="stat-chip">
							<span class="stat-icon">★</span>
							<span class="stat-label">평균 별점</span>
							<span class="stat-value">
								{tasteProfile.avg_rating != null ? tasteProfile.avg_rating.toFixed(1) : '-'}
							</span>
						</div>
					</div>

					{#if tasteProfile.top_category}
						<div class="top-category">
							<span class="top-label">자주 만드는 카테고리</span>
							<span class="top-value">{tasteProfile.top_category}</span>
						</div>
					{/if}
				</div>

			{:else}
				<!-- 데이터 부족: 안내 카드 -->
				<div class="taste-empty-card">
					<div class="taste-empty-bars">
						{#each FLAVOR_AXES as axis, i}
							<div class="bar-row">
								<span class="bar-label">{axis.label}</span>
								<div class="bar-track">
									<div
										class="bar-fill placeholder-blur"
										style:background={axis.color}
										style:width="{PLACEHOLDER_WIDTHS[i]}%"
									></div>
								</div>
							</div>
						{/each}
					</div>
					<p class="taste-empty-notice">
						레시피를 3개 이상 저장하고<br/>
						별점 또는 즐겨찾기를 남기면<br/>
						내 입맛을 분석해드릴게요.
					</p>
					{#if tasteProfile}
						<p class="taste-count-hint">현재 {tasteProfile.recipe_count}개 저장됨</p>
					{/if}
				</div>
			{/if}
		</section>

		<!-- 먹당이 채팅 -->
		<section class="section">
			<div class="section-header">
				<h2 class="section-title">먹당이와 대화하기</h2>
			</div>
			<div class="meokdang-preview-card">
				<div class="meokdang-avatar">
					<img
						src="/meokdang.png"
						alt="먹당이"
						class="meokdang-img"
						onerror={(e) => {
							const img = e.currentTarget as HTMLImageElement;
							img.style.display = 'none';
							const emoji = img.nextElementSibling as HTMLElement | null;
							if (emoji) emoji.removeAttribute('hidden');
						}}
					/>
					<span class="meokdang-emoji" hidden>🥘</span>
				</div>
				<p class="meokdang-greeting">"{getDisplayName()}~ 나랑 놀쟈 마우!!"</p>
				<button class="btn-chat-open" onclick={() => (chatOpen = true)}>
					대화 시작하기
				</button>
			</div>
		</section>

		<MeokdangChatSheet open={chatOpen} onclose={() => (chatOpen = false)} />

		<!-- 로그아웃 -->
		<div class="bottom-actions">
			<button class="signout-btn" onclick={handleSignOut}>로그아웃</button>
		</div>
	{/if}
</div>

<style>
	.my-page {
		padding: 24px 16px calc(90px + env(safe-area-inset-bottom));
		min-height: 100%;
	}

	/* 비로그인 상태 */
	.login-prompt {
		display: flex;
		flex-direction: column;
		align-items: center;
		padding: 64px 24px;
		text-align: center;
		gap: 12px;
	}

	.prompt-icon {
		width: 64px;
		height: 64px;
		color: var(--color-light-line);
		margin-bottom: 4px;
	}

	.prompt-icon svg {
		width: 100%;
		height: 100%;
	}

	.prompt-title {
		font-size: 1.1rem;
		font-weight: 700;
		color: var(--color-warm-brown);
	}

	.prompt-desc {
		font-size: 0.88rem;
		color: var(--color-soft-brown);
		line-height: 1.7;
	}

	.btn-login {
		margin-top: 8px;
		padding: 12px 32px;
		background: var(--color-terracotta);
		color: #fff;
		border: none;
		border-radius: 12px;
		font-size: 0.95rem;
		font-weight: 600;
		font-family: inherit;
		cursor: pointer;
		transition: background 0.15s;
	}

	.btn-login:hover {
		background: #b5633f;
	}

	/* 프로필 섹션 */
	.profile-section {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 8px;
		padding: 20px 0 28px;
	}

	.profile-avatar-wrap {
		position: relative;
	}

	.profile-avatar {
		width: 80px;
		height: 80px;
		border-radius: 50%;
		border: 2.5px solid var(--color-light-line);
		object-fit: cover;
	}

	.avatar-fallback {
		display: flex;
		align-items: center;
		justify-content: center;
		background: var(--color-terracotta);
		color: #fff;
		font-size: 1.8rem;
		font-weight: 700;
	}

	.profile-name {
		font-size: 1.1rem;
		font-weight: 700;
		color: var(--color-warm-brown);
		margin-top: 4px;
	}

	.profile-email {
		font-size: 0.82rem;
		color: var(--color-soft-brown);
	}

	/* 섹션 공통 */
	.section {
		margin-bottom: 20px;
	}

	.section-header {
		display: flex;
		align-items: center;
		gap: 8px;
		margin-bottom: 10px;
	}

	.section-title {
		font-size: 0.98rem;
		font-weight: 700;
		color: var(--color-warm-brown);
	}

	/* .section-badge, .coming-soon — 추후 재사용 가능 */

	/* 입맛 차트 스켈레톤 */
	.taste-skeleton {
		background: var(--color-cream);
		border: 1.5px solid var(--color-light-line);
		border-radius: 16px;
		padding: 18px;
		display: flex;
		flex-direction: column;
		gap: 12px;
	}

	.skeleton-bar-row {
		display: flex;
		align-items: center;
		gap: 10px;
	}

	.skeleton-label {
		width: 56px;
		height: 10px;
		background: var(--color-light-line);
		border-radius: 5px;
		flex-shrink: 0;
	}

	.skeleton-track {
		flex: 1;
		height: 8px;
		background: var(--color-light-line);
		border-radius: 4px;
		overflow: hidden;
	}

	.skeleton-fill {
		height: 100%;
		background: var(--color-soft-brown);
		border-radius: 4px;
		opacity: 0.2;
	}

	.shimmer {
		animation: shimmer 1.4s ease infinite;
	}

	@keyframes shimmer {
		0%, 100% { opacity: 0.2; }
		50% { opacity: 0.08; }
	}

	/* 입맛 차트 (데이터 있음) */
	.taste-card {
		background: #fff;
		border: 1.5px solid var(--color-light-line);
		border-radius: 16px;
		padding: 18px;
		display: flex;
		flex-direction: column;
		gap: 16px;
	}

	.taste-bars {
		display: flex;
		flex-direction: column;
		gap: 10px;
	}

	.bar-row {
		display: flex;
		align-items: center;
		gap: 10px;
	}

	.bar-label {
		font-size: 0.75rem;
		color: var(--color-soft-brown);
		width: 56px;
		flex-shrink: 0;
		text-align: right;
	}

	.bar-track {
		flex: 1;
		height: 8px;
		background: var(--color-cream);
		border-radius: 4px;
		overflow: hidden;
	}

	.bar-fill {
		height: 100%;
		border-radius: 4px;
		transition: width 0.6s cubic-bezier(0.4, 0, 0.2, 1);
	}

	.bar-value {
		font-size: 0.75rem;
		font-weight: 600;
		color: var(--color-warm-brown);
		width: 24px;
		text-align: right;
		flex-shrink: 0;
		font-family: var(--font-number);
	}

	/* 통계 칩 */
	.stat-chips {
		display: grid;
		grid-template-columns: repeat(3, 1fr);
		gap: 8px;
	}

	.stat-chip {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 3px;
		padding: 10px 6px;
		background: var(--color-cream);
		border-radius: 12px;
		text-align: center;
	}

	.stat-icon {
		font-size: 1rem;
		line-height: 1;
	}

	.stat-label {
		font-size: 0.68rem;
		color: var(--color-soft-brown);
	}

	.stat-value {
		font-size: 0.85rem;
		font-weight: 700;
		color: var(--color-warm-brown);
		font-family: var(--font-number);
	}

	/* 자주 만드는 카테고리 */
	.top-category {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 10px 14px;
		background: color-mix(in srgb, var(--color-terracotta) 8%, white);
		border-radius: 10px;
		border: 1px solid color-mix(in srgb, var(--color-terracotta) 20%, white);
	}

	.top-label {
		font-size: 0.78rem;
		color: var(--color-soft-brown);
	}

	.top-value {
		font-size: 0.88rem;
		font-weight: 700;
		color: var(--color-terracotta);
	}

	/* 입맛 차트 (데이터 부족) */
	.taste-empty-card {
		background: var(--color-cream);
		border: 1.5px solid var(--color-light-line);
		border-radius: 16px;
		padding: 18px;
		display: flex;
		flex-direction: column;
		gap: 14px;
	}

	.taste-empty-bars {
		display: flex;
		flex-direction: column;
		gap: 10px;
	}

	.placeholder-blur {
		opacity: 0.25;
		filter: blur(1px);
	}

	.taste-empty-notice {
		font-size: 0.82rem;
		color: var(--color-soft-brown);
		text-align: center;
		line-height: 1.7;
	}

	.taste-count-hint {
		font-size: 0.75rem;
		color: var(--color-soft-brown);
		text-align: center;
		opacity: 0.7;
	}

	/* 먹당이 채팅 카드 */
	.meokdang-preview-card {
		background: var(--color-cream);
		border: 1.5px solid var(--color-light-line);
		border-radius: 16px;
		padding: 20px 18px;
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 12px;
		text-align: center;
	}

	.meokdang-avatar {
		width: 56px;
		height: 56px;
		border-radius: 50%;
		overflow: hidden;
		background: var(--color-warm-yellow);
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.meokdang-img {
		width: 100%;
		height: 100%;
		object-fit: cover;
	}

	.meokdang-emoji {
		font-size: 2rem;
		line-height: 1;
	}

	.meokdang-greeting {
		font-size: 0.9rem;
		color: var(--color-warm-brown);
		font-weight: 500;
		line-height: 1.5;
	}

	.btn-chat-open {
		padding: 10px 28px;
		background: var(--color-terracotta);
		border: none;
		border-radius: 10px;
		font-size: 0.9rem;
		font-weight: 600;
		color: #fff;
		font-family: inherit;
		cursor: pointer;
		transition: background 0.15s;
	}

	.btn-chat-open:hover {
		background: #b5633f;
	}

	/* 하단 액션 */
	.bottom-actions {
		margin-top: 8px;
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
		transition: border-color 0.15s, color 0.15s;
	}

	.signout-btn:hover {
		border-color: var(--color-muted-red);
		color: var(--color-muted-red);
	}
</style>
