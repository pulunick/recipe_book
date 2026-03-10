<script lang="ts">
	import { onMount } from 'svelte';
	import { isLoggedIn, openLoginModal } from '$lib/stores/auth.svelte';
	import {
		getCart,
		toggleCartItem,
		deleteCartItem,
		deleteCheckedCartItems,
		clearCart
	} from '$lib/api';
	import type { CartGroup, CartItem } from '$lib/types';

	const loggedIn = $derived(isLoggedIn());

	let groups = $state<CartGroup[]>([]);
	let isLoading = $state(true);
	let errorMsg = $state('');
	let isClearing = $state(false);
	let isClearingChecked = $state(false);

	// 접힌 그룹 추적 (collection_id 또는 recipe_title을 key로 사용)
	let collapsedGroups = $state<Set<string>>(new Set());

	const totalCount = $derived(groups.reduce((sum, g) => sum + g.items.length, 0));
	const checkedCount = $derived(groups.reduce((sum, g) => sum + g.items.filter(i => i.is_checked).length, 0));
	const uncheckedCount = $derived(totalCount - checkedCount);

	onMount(() => {
		if (loggedIn) {
			loadCart();
		} else {
			isLoading = false;
		}
	});

	async function loadCart() {
		isLoading = true;
		errorMsg = '';
		try {
			groups = await getCart();
		} catch (e) {
			errorMsg = e instanceof Error ? e.message : '장바구니를 불러오지 못했어요.';
		} finally {
			isLoading = false;
		}
	}

	function groupKey(group: CartGroup): string {
		return String(group.collection_id ?? group.recipe_title ?? '기타');
	}

	function toggleCollapse(group: CartGroup) {
		const key = groupKey(group);
		const next = new Set(collapsedGroups);
		if (next.has(key)) {
			next.delete(key);
		} else {
			next.add(key);
		}
		collapsedGroups = next;
	}

	function isCollapsed(group: CartGroup): boolean {
		return collapsedGroups.has(groupKey(group));
	}

	async function handleToggle(groupIdx: number, itemIdx: number) {
		const item = groups[groupIdx].items[itemIdx];
		groups[groupIdx].items[itemIdx] = { ...item, is_checked: !item.is_checked };
		try {
			await toggleCartItem(item.id);
		} catch {
			groups[groupIdx].items[itemIdx] = item;
		}
	}

	async function handleDelete(groupIdx: number, itemIdx: number) {
		const item = groups[groupIdx].items[itemIdx];
		const newItems = groups[groupIdx].items.filter((_, i) => i !== itemIdx);
		if (newItems.length === 0) {
			groups = groups.filter((_, i) => i !== groupIdx);
		} else {
			groups[groupIdx] = { ...groups[groupIdx], items: newItems };
		}
		try {
			await deleteCartItem(item.id);
		} catch {
			await loadCart();
		}
	}

	async function handleDeleteChecked() {
		isClearingChecked = true;
		try {
			await deleteCheckedCartItems();
			groups = groups
				.map(g => ({ ...g, items: g.items.filter(i => !i.is_checked) }))
				.filter(g => g.items.length > 0);
		} catch (e) {
			errorMsg = e instanceof Error ? e.message : '삭제 중 오류가 발생했습니다.';
		} finally {
			isClearingChecked = false;
		}
	}

	async function handleClearAll() {
		if (!confirm('장바구니를 모두 비울까요?')) return;
		isClearing = true;
		try {
			await clearCart();
			groups = [];
		} catch (e) {
			errorMsg = e instanceof Error ? e.message : '비우기 중 오류가 발생했습니다.';
		} finally {
			isClearing = false;
		}
	}

	function handleShopClick(mode: 'checked' | 'all') {
		const count = mode === 'checked' ? checkedCount : totalCount;
		alert(`${count}개 재료 구매 기능은 곧 출시 예정이에요! 🛍️`);
	}

	function formatAmount(item: CartItem): string {
		const parts: string[] = [];
		if (item.amount) parts.push(item.amount);
		if (item.unit) parts.push(item.unit);
		return parts.join(' ');
	}
</script>

<svelte:head>
	<title>장바구니 | 해먹당</title>
</svelte:head>

<div class="cart-page">
	<div class="cart-header">
		<h1 class="cart-title">장바구니</h1>
		{#if totalCount > 0}
			<div class="header-actions">
				{#if checkedCount > 0}
					<button class="btn-clear-checked" onclick={handleDeleteChecked} disabled={isClearingChecked}>
						{isClearingChecked ? '삭제 중...' : `선택 삭제 (${checkedCount})`}
					</button>
				{/if}
				<button class="btn-clear-all" onclick={handleClearAll} disabled={isClearing}>
					{isClearing ? '비우는 중...' : '전체 비우기'}
				</button>
			</div>
		{/if}
	</div>

	{#if !loggedIn}
		<div class="empty-state">
			<div class="empty-icon">🛒</div>
			<p class="empty-title">로그인이 필요해요</p>
			<p class="empty-desc">장바구니를 사용하려면 로그인해주세요.</p>
			<button class="btn-login" onclick={() => openLoginModal()}>로그인</button>
		</div>

	{:else if isLoading}
		<div class="loading-state">
			<span class="spinner"></span>
			<p>장바구니를 불러오는 중...</p>
		</div>

	{:else if errorMsg}
		<div class="error-state">
			<p class="error-msg">{errorMsg}</p>
			<button class="btn-retry" onclick={loadCart}>다시 시도</button>
		</div>

	{:else if groups.length === 0}
		<div class="empty-state">
			<div class="empty-icon">🛒</div>
			<p class="empty-title">장바구니가 비어있어요</p>
			<p class="empty-desc">레시피 상세 페이지에서 재료를 담아보세요.</p>
			<a href="/my-recipes" class="btn-goto-recipes">내 레시피 보러가기</a>
		</div>

	{:else}
		<div class="cart-summary">
			<span class="summary-text">총 <strong>{totalCount}개</strong> 재료</span>
			{#if checkedCount > 0}
				<span class="checked-badge">{checkedCount}개 체크됨</span>
			{/if}
		</div>

		<div class="groups">
			{#each groups as group, gi (groupKey(group))}
				{@const collapsed = isCollapsed(group)}
				<div class="group" class:collapsed>
					<!-- 그룹 헤더 (클릭 시 접기/펼치기) -->
					<button class="group-header" onclick={() => toggleCollapse(group)}>
						<span class="collapse-icon">{collapsed ? '▶' : '▼'}</span>
						<span class="group-title">{group.recipe_title ?? '기타'}</span>
						<span class="group-count">{group.items.length}개</span>
						{#if group.collection_id}
							<!-- 링크는 버튼 안에 있어 버블링 방지 -->
							<a
								href="/my-recipes/{group.collection_id}"
								class="group-link"
								onclick={(e) => e.stopPropagation()}
							>레시피 →</a>
						{/if}
					</button>

					{#if !collapsed}
						<ul class="ingredient-list">
							{#each group.items as item, ii (item.id)}
								<li class="ingredient-item" class:checked={item.is_checked}>
									<button
										class="check-btn"
										onclick={() => handleToggle(gi, ii)}
										aria-label={item.is_checked ? '체크 해제' : '체크'}
									>
										{#if item.is_checked}
											<svg viewBox="0 0 24 24" fill="currentColor">
												<path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41z" />
											</svg>
										{:else}
											<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
												<rect x="3" y="3" width="18" height="18" rx="3" />
											</svg>
										{/if}
									</button>

									<div class="ingredient-info">
										<span class="ingredient-name">{item.ingredient_name}</span>
										{#if item.amount || item.unit}
											<span class="ingredient-amount">{formatAmount(item)}</span>
										{/if}
									</div>

									<span class="ingredient-category">{item.category}</span>

									<button
										class="btn-delete-item"
										onclick={() => handleDelete(gi, ii)}
										aria-label="삭제"
									>
										<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
											<line x1="18" y1="6" x2="6" y2="18" />
											<line x1="6" y1="6" x2="18" y2="18" />
										</svg>
									</button>
								</li>
							{/each}
						</ul>
					{/if}
				</div>
			{/each}
		</div>

		<!-- 하단 여백 (shop-bar + BottomNav 가림 방지) -->
		<div style="height: 160px"></div>
	{/if}
</div>

<!-- 구매하러 가기 — sticky 하단 바 -->
{#if loggedIn && !isLoading && totalCount > 0}
	<div class="shop-bar">
		<div class="shop-bar-inner">
			<span class="shop-bar-label">
				{#if checkedCount > 0}
					체크 <strong>{checkedCount}</strong> / 전체 <strong>{totalCount}개</strong>
				{:else}
					전체 <strong>{totalCount}개</strong> 재료
				{/if}
			</span>
			<div class="shop-btn-group">
				{#if checkedCount > 0}
					<button class="btn-shop-secondary" onclick={() => handleShopClick('checked')}>
						선택만 구매
					</button>
				{/if}
				<button class="btn-shop" onclick={() => handleShopClick('all')}>
					🛍️ 전체 구매
				</button>
			</div>
		</div>
	</div>
{/if}

<style>
	.cart-page {
		max-width: 480px;
		margin: 0 auto;
		padding: 0 0 40px;
	}

	.cart-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 16px 20px 12px;
		position: sticky;
		top: 48px;
		background: var(--color-paper);
		z-index: 10;
		border-bottom: 1px solid var(--color-light-line);
	}

	.cart-title {
		font-size: 1.1rem;
		font-weight: 700;
		color: var(--color-warm-brown);
	}

	.header-actions {
		display: flex;
		gap: 8px;
		align-items: center;
	}

	.btn-clear-checked {
		font-size: 0.8rem;
		font-weight: 600;
		color: var(--color-terracotta);
		background: none;
		border: 1.5px solid var(--color-terracotta);
		border-radius: 8px;
		padding: 5px 10px;
		cursor: pointer;
		font-family: inherit;
	}
	.btn-clear-checked:disabled { opacity: 0.5; cursor: not-allowed; }

	.btn-clear-all {
		font-size: 0.8rem;
		color: var(--color-soft-brown);
		background: none;
		border: 1.5px solid var(--color-light-line);
		border-radius: 8px;
		padding: 5px 10px;
		cursor: pointer;
		font-family: inherit;
	}
	.btn-clear-all:disabled { opacity: 0.5; cursor: not-allowed; }

	/* 요약 */
	.cart-summary {
		padding: 10px 20px;
		display: flex;
		align-items: center;
		gap: 10px;
		font-size: 0.85rem;
	}

	.summary-text { color: var(--color-warm-brown); }
	.checked-badge {
		font-size: 0.78rem;
		color: var(--color-soft-brown);
		background: var(--color-cream);
		border-radius: 8px;
		padding: 2px 8px;
	}

	/* 그룹 */
	.groups {
		display: flex;
		flex-direction: column;
		gap: 12px;
		padding: 8px 16px 0;
	}

	.group {
		background: white;
		border-radius: 14px;
		overflow: hidden;
		box-shadow: 0 1px 4px rgba(0,0,0,0.06);
		transition: box-shadow 0.15s;
	}

	/* 그룹 헤더 (버튼) */
	.group-header {
		display: flex;
		align-items: center;
		gap: 8px;
		padding: 12px 16px;
		width: 100%;
		background: none;
		border: none;
		cursor: pointer;
		text-align: left;
		font-family: inherit;
		border-bottom: 1px solid var(--color-light-line);
		transition: background 0.1s;
	}
	.group.collapsed .group-header {
		border-bottom: none;
	}
	.group-header:hover { background: var(--color-paper); }

	.collapse-icon {
		font-size: 0.6rem;
		color: var(--color-soft-brown);
		flex-shrink: 0;
		width: 10px;
	}

	.group-title {
		font-size: 0.92rem;
		font-weight: 700;
		color: var(--color-warm-brown);
		flex: 1;
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
	}

	.group-count {
		font-size: 0.75rem;
		color: var(--color-soft-brown);
		background: var(--color-cream);
		border-radius: 8px;
		padding: 2px 7px;
		flex-shrink: 0;
	}

	.group-link {
		font-size: 0.75rem;
		color: var(--color-terracotta);
		text-decoration: none;
		flex-shrink: 0;
	}
	.group-link:hover { text-decoration: underline; }

	/* 재료 리스트 */
	.ingredient-list {
		list-style: none;
		margin: 0;
		padding: 0;
	}

	.ingredient-item {
		display: flex;
		align-items: center;
		gap: 10px;
		padding: 11px 16px;
		border-bottom: 1px solid var(--color-light-line);
		transition: background 0.1s;
	}
	.ingredient-item:last-child { border-bottom: none; }
	.ingredient-item.checked { background: var(--color-paper); }
	.ingredient-item.checked .ingredient-name {
		opacity: 0.4;
	}
	.ingredient-item.checked .ingredient-amount {
		opacity: 0.4;
	}

	.check-btn {
		background: none;
		border: none;
		padding: 0;
		cursor: pointer;
		width: 22px;
		height: 22px;
		color: var(--color-terracotta);
		flex-shrink: 0;
		display: flex;
		align-items: center;
	}
	.check-btn svg { width: 22px; height: 22px; }

	.ingredient-info {
		flex: 1;
		display: flex;
		align-items: baseline;
		gap: 6px;
		min-width: 0;
	}

	.ingredient-name {
		font-size: 0.9rem;
		color: var(--color-warm-brown);
		font-weight: 500;
		transition: opacity 0.15s;
	}

	.ingredient-amount {
		font-size: 0.8rem;
		color: var(--color-soft-brown);
		flex-shrink: 0;
		transition: opacity 0.15s;
	}

	.ingredient-category {
		font-size: 0.7rem;
		color: var(--color-soft-brown);
		background: var(--color-cream);
		border-radius: 6px;
		padding: 2px 6px;
		flex-shrink: 0;
	}

	.btn-delete-item {
		background: none;
		border: none;
		padding: 4px;
		cursor: pointer;
		color: var(--color-light-line);
		display: flex;
		align-items: center;
		flex-shrink: 0;
		transition: color 0.15s;
	}
	.btn-delete-item:hover { color: var(--color-soft-brown); }
	.btn-delete-item svg { width: 16px; height: 16px; }

	/* 하단 구매 바 */
	.shop-bar {
		position: fixed;
		bottom: calc(60px + env(safe-area-inset-bottom));
		left: 50%;
		transform: translateX(-50%);
		width: calc(100% - 32px);
		max-width: 448px;
		background: white;
		border-radius: 14px;
		box-shadow: 0 4px 20px rgba(0, 0, 0, 0.12);
		padding: 12px 16px;
		z-index: 30;
	}

	.shop-bar-inner {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 12px;
	}

	.shop-bar-label {
		font-size: 0.85rem;
		color: var(--color-soft-brown);
		flex-shrink: 0;
	}
	.shop-bar-label strong {
		color: var(--color-warm-brown);
	}

	.shop-btn-group {
		display: flex;
		gap: 8px;
		align-items: center;
		flex-shrink: 0;
	}

	.btn-shop-secondary {
		padding: 8px 14px;
		background: none;
		color: var(--color-terracotta);
		border: 1.5px solid var(--color-terracotta);
		border-radius: 10px;
		font-size: 0.85rem;
		font-weight: 600;
		font-family: inherit;
		cursor: pointer;
		white-space: nowrap;
		transition: background 0.15s, color 0.15s;
		height: 38px;
	}
	.btn-shop-secondary:hover {
		background: color-mix(in srgb, var(--color-terracotta) 10%, white);
	}

	.btn-shop {
		padding: 0 16px;
		background: var(--color-terracotta);
		color: white;
		border: none;
		border-radius: 10px;
		font-size: 0.88rem;
		font-weight: 700;
		font-family: inherit;
		cursor: pointer;
		white-space: nowrap;
		transition: opacity 0.15s;
		height: 38px;
	}
	.btn-shop:hover { opacity: 0.88; }

	/* 상태 화면 */
	.empty-state,
	.loading-state,
	.error-state {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		min-height: calc(100dvh - 180px);
		gap: 12px;
		text-align: center;
		padding: 24px;
	}

	.empty-icon { font-size: 3rem; line-height: 1; }
	.empty-title {
		font-size: 1.05rem;
		font-weight: 600;
		color: var(--color-warm-brown);
	}
	.empty-desc {
		font-size: 0.85rem;
		color: var(--color-soft-brown);
		line-height: 1.5;
	}

	.btn-login,
	.btn-goto-recipes {
		margin-top: 8px;
		padding: 10px 24px;
		background: var(--color-terracotta);
		color: white;
		border: none;
		border-radius: 10px;
		font-size: 0.9rem;
		font-weight: 600;
		font-family: inherit;
		cursor: pointer;
		text-decoration: none;
		display: inline-block;
	}

	.btn-retry {
		padding: 10px 24px;
		background: none;
		border: 1.5px solid var(--color-light-line);
		border-radius: 10px;
		font-size: 0.9rem;
		color: var(--color-soft-brown);
		font-family: inherit;
		cursor: pointer;
	}

	.error-msg {
		font-size: 0.88rem;
		color: var(--color-muted-red, #c0392b);
	}

	.loading-state {
		color: var(--color-soft-brown);
		font-size: 0.9rem;
		gap: 16px;
	}

	.spinner {
		width: 28px;
		height: 28px;
		border: 3px solid var(--color-light-line);
		border-top-color: var(--color-terracotta);
		border-radius: 50%;
		animation: spin 0.7s linear infinite;
	}

	@keyframes spin { to { transform: rotate(360deg); } }
</style>
