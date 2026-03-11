<script lang="ts">
	import { tick } from 'svelte';
	import { chatWithMeokdang } from '$lib/api';
	import { getUser } from '$lib/stores/auth.svelte';

	interface Props {
		open: boolean;
		onclose: () => void;
	}

	let { open, onclose }: Props = $props();

	const user = $derived(getUser());

	// 이름에서 성 제외 이름만 추출
	function getDisplayName(): string {
		const fullName = user?.user_metadata?.full_name?.trim();
		if (!fullName) return '김씨';
		const parts = fullName.split(/\s+/);
		if (parts.length > 1) {
			// 공백 포함 이름 (예: "김 진형", "Kim Jinhyeong") → 마지막 파트
			return parts[parts.length - 1];
		}
		// 한국어 이름 (공백 없음, 예: "김진형") → 첫 글자(성) 제외
		if (/^[가-힣]{2,4}$/.test(fullName)) {
			return fullName.slice(1);
		}
		return fullName;
	}

	type Message = { role: 'user' | 'assistant'; content: string };

	// 초기 인사 메시지는 displayName이 결정된 후 동적으로 설정
	let messages = $state<Message[]>([]);
	let inputText = $state('');
	let loading = $state(false);
	let chatListEl = $state<HTMLElement | null>(null);

	// open 될 때마다 초기 메시지 설정
	$effect(() => {
		if (open && messages.length === 0) {
			const name = getDisplayName();
			messages = [
				{
					role: 'assistant',
					content: `${name} 왔네 마우!\n뭔 얘기 하러 왔어? 나랑 놀자!!! 마우!!`
				}
			];
		}
	});

	// 새 메시지 추가 시 자동 스크롤
	$effect(() => {
		if (messages.length > 0) {
			tick().then(() => {
				if (chatListEl) {
					chatListEl.scrollTop = chatListEl.scrollHeight;
				}
			});
		}
	});

	async function handleSend() {
		const text = inputText.trim();
		if (!text || loading) return;

		inputText = '';
		messages = [...messages, { role: 'user', content: text }];
		loading = true;

		try {
			const history = messages.slice(0, -1).map(m => ({
				role: m.role,
				content: m.content
			}));
			const reply = await chatWithMeokdang(text, history, user?.user_metadata?.full_name);
			messages = [...messages, { role: 'assistant', content: reply }];
		} catch (e) {
			const errMsg = e instanceof Error && e.message.includes('429')
				? '달그락달그락... 잠깐만! 너무 빨리 말하면 나 못 따라가 마우!'
				: '달그락... 뭔가 잘못됐어. 다시 말해줘 마우!';
			messages = [...messages, { role: 'assistant', content: errMsg }];
		} finally {
			loading = false;
		}
	}

	function handleKeydown(e: KeyboardEvent) {
		if (e.key === 'Enter' && !e.shiftKey) {
			e.preventDefault();
			handleSend();
		}
	}

	function handleOverlayClick(e: MouseEvent) {
		if (e.target === e.currentTarget) onclose();
	}

	function resetChat() {
		const name = getDisplayName();
		messages = [
			{
				role: 'assistant',
				content: `${name} 왔네 마우!\n뭔 얘기 하러 왔어? 나 여기 있었어~`
			}
		];
		inputText = '';
	}

	// 빠른 답변 칩 (초기 메시지만 있을 때 표시)
	const QUICK_REPLIES = ['뭐해?', '심심해', '오늘 하루 어땠어?'];

	function sendQuickReply(text: string) {
		inputText = text;
		handleSend();
	}
</script>

{#if open}
	<!-- 오버레이 -->
	<div
		class="overlay"
		role="button"
		tabindex="-1"
		aria-label="채팅 닫기"
		onclick={handleOverlayClick}
		onkeydown={(e) => e.key === 'Escape' && onclose()}
	></div>

	<!-- 바텀시트 -->
	<div class="sheet" role="dialog" aria-modal="true" aria-label="먹당이 채팅">
		<!-- 헤더 -->
		<div class="sheet-header">
			<div class="header-left">
				<div class="avatar-wrap">
					<img
						src="/meokdang.png"
						alt="먹당이"
						class="avatar-img"
						onerror={(e) => {
							const img = e.currentTarget as HTMLImageElement;
							img.style.display = 'none';
							const emoji = img.nextElementSibling as HTMLElement | null;
							if (emoji) emoji.removeAttribute('hidden');
						}}
					/>
					<span class="avatar-emoji" hidden>🥘</span>
				</div>
				<span class="header-title">먹당이</span>
			</div>
			<div class="header-right">
				<button class="reset-btn" onclick={resetChat} aria-label="대화 초기화" title="대화 초기화">
					<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2">
						<path d="M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8"/>
						<path d="M3 3v5h5"/>
					</svg>
				</button>
				<button class="close-btn" onclick={onclose} aria-label="닫기">
					<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
						<line x1="18" y1="6" x2="6" y2="18"/>
						<line x1="6" y1="6" x2="18" y2="18"/>
					</svg>
				</button>
			</div>
		</div>

		<!-- 채팅 목록 -->
		<div class="chat-list" bind:this={chatListEl}>
			{#each messages as msg (msg)}
				<div class="msg-row" class:user={msg.role === 'user'} class:assistant={msg.role === 'assistant'}>
					{#if msg.role === 'assistant'}
						<div class="msg-avatar">
							<img
								src="/meokdang.png"
								alt="먹당이"
								class="msg-avatar-img"
								onerror={(e) => {
									const img = e.currentTarget as HTMLImageElement;
									img.style.display = 'none';
									const span = img.nextElementSibling as HTMLElement | null;
									if (span) span.removeAttribute('hidden');
								}}
							/>
							<span class="msg-avatar-emoji" hidden>🥘</span>
						</div>
					{/if}
					<div class="bubble">
						{#each msg.content.split('\n') as line, i}
							{#if i > 0}<br/>{/if}{line}
						{/each}
					</div>
				</div>
			{/each}

			{#if loading}
				<div class="msg-row assistant">
					<div class="msg-avatar">
						<span class="msg-avatar-emoji">🥘</span>
					</div>
					<div class="bubble typing">
						<span class="dot"></span>
						<span class="dot"></span>
						<span class="dot"></span>
					</div>
				</div>
			{/if}
		</div>

		<!-- 빠른 답변 칩 (메시지 1개일 때만) -->
		{#if messages.length === 1 && !loading}
			<div class="quick-replies">
				{#each QUICK_REPLIES as qr}
					<button class="quick-chip" onclick={() => sendQuickReply(qr)}>{qr}</button>
				{/each}
			</div>
		{/if}

		<!-- 입력창 -->
		<div class="input-bar">
			<input
				type="text"
				class="chat-input"
				placeholder="먹당이에게 말해봐요..."
				bind:value={inputText}
				onkeydown={handleKeydown}
				disabled={loading}
				maxlength={300}
			/>
			<button
				class="send-btn"
				onclick={handleSend}
				disabled={!inputText.trim() || loading}
				aria-label="전송"
			>
				{#if loading}
					<span class="send-spinner"></span>
				{:else}
					<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2">
						<line x1="22" y1="2" x2="11" y2="13"/>
						<polygon points="22 2 15 22 11 13 2 9 22 2"/>
					</svg>
				{/if}
			</button>
		</div>
	</div>
{/if}

<style>
	.overlay {
		position: fixed;
		inset: 0;
		background: rgba(0, 0, 0, 0.45);
		z-index: 60;
		animation: fade-in 0.2s ease;
	}

	@keyframes fade-in {
		from { opacity: 0; }
		to { opacity: 1; }
	}

	.sheet {
		position: fixed;
		bottom: 0;
		left: 50%;
		transform: translateX(-50%);
		width: 100%;
		max-width: 480px;
		max-height: 85dvh;
		background: var(--color-paper);
		border-radius: 20px 20px 0 0;
		z-index: 61;
		display: flex;
		flex-direction: column;
		animation: slide-up 0.25s cubic-bezier(0.32, 0.72, 0, 1);
		overflow: hidden;
	}

	@keyframes slide-up {
		from { transform: translateX(-50%) translateY(100%); }
		to { transform: translateX(-50%) translateY(0); }
	}

	/* 헤더 */
	.sheet-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 16px 16px 12px;
		border-bottom: 1px solid var(--color-light-line);
		flex-shrink: 0;
	}

	.header-left {
		display: flex;
		align-items: center;
		gap: 10px;
	}

	.avatar-wrap {
		width: 32px;
		height: 32px;
		border-radius: 50%;
		overflow: hidden;
		background: var(--color-warm-yellow);
		display: flex;
		align-items: center;
		justify-content: center;
		flex-shrink: 0;
	}

	.avatar-img {
		width: 100%;
		height: 100%;
		object-fit: cover;
	}

	.avatar-emoji {
		font-size: 1.2rem;
		line-height: 1;
	}

	.header-title {
		font-size: 1rem;
		font-weight: 700;
		color: var(--color-warm-brown);
	}

	.header-right {
		display: flex;
		align-items: center;
		gap: 4px;
	}

	.reset-btn, .close-btn {
		width: 32px;
		height: 32px;
		border: none;
		background: none;
		color: var(--color-soft-brown);
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		border-radius: 50%;
		transition: background 0.15s;
		padding: 0;
	}

	.reset-btn:hover, .close-btn:hover { background: var(--color-cream); }
	.reset-btn svg, .close-btn svg { width: 18px; height: 18px; }

	/* 채팅 목록 */
	.chat-list {
		flex: 1;
		overflow-y: auto;
		padding: 16px;
		display: flex;
		flex-direction: column;
		gap: 10px;
		overscroll-behavior: contain;
	}

	.msg-row {
		display: flex;
		align-items: flex-end;
		gap: 8px;
		max-width: 85%;
	}

	.msg-row.assistant {
		align-self: flex-start;
	}

	.msg-row.user {
		align-self: flex-end;
		flex-direction: row-reverse;
	}

	.msg-avatar {
		width: 28px;
		height: 28px;
		border-radius: 50%;
		overflow: hidden;
		background: var(--color-warm-yellow);
		display: flex;
		align-items: center;
		justify-content: center;
		flex-shrink: 0;
	}

	.msg-avatar-img {
		width: 100%;
		height: 100%;
		object-fit: cover;
	}

	.msg-avatar-emoji {
		font-size: 1rem;
		line-height: 1;
	}

	.bubble {
		padding: 10px 14px;
		border-radius: 16px;
		font-size: 0.88rem;
		line-height: 1.55;
		white-space: pre-wrap;
		word-break: break-word;
	}

	.msg-row.assistant .bubble {
		background: #fff;
		border: 1px solid var(--color-light-line);
		border-bottom-left-radius: 4px;
		color: var(--color-warm-brown);
	}

	.msg-row.user .bubble {
		background: var(--color-terracotta);
		color: #fff;
		border-bottom-right-radius: 4px;
	}

	/* 타이핑 애니메이션 */
	.bubble.typing {
		display: flex;
		align-items: center;
		gap: 4px;
		padding: 12px 16px;
	}

	.dot {
		width: 7px;
		height: 7px;
		border-radius: 50%;
		background: var(--color-soft-brown);
		animation: bounce 1.2s ease infinite;
		flex-shrink: 0;
	}

	.dot:nth-child(2) { animation-delay: 0.2s; }
	.dot:nth-child(3) { animation-delay: 0.4s; }

	@keyframes bounce {
		0%, 60%, 100% { transform: translateY(0); opacity: 0.4; }
		30% { transform: translateY(-5px); opacity: 1; }
	}

	/* 빠른 답변 칩 */
	.quick-replies {
		display: flex;
		gap: 8px;
		padding: 8px 16px;
		overflow-x: auto;
		scrollbar-width: none;
		flex-shrink: 0;
	}

	.quick-replies::-webkit-scrollbar { display: none; }

	.quick-chip {
		flex-shrink: 0;
		padding: 7px 14px;
		border: 1.5px solid var(--color-terracotta);
		border-radius: 20px;
		background: none;
		color: var(--color-terracotta);
		font-size: 0.8rem;
		font-weight: 600;
		font-family: inherit;
		cursor: pointer;
		white-space: nowrap;
		transition: background 0.15s, color 0.15s;
	}

	.quick-chip:hover {
		background: var(--color-terracotta);
		color: #fff;
	}

	/* 입력창 */
	.input-bar {
		display: flex;
		align-items: center;
		gap: 8px;
		padding: 12px 16px calc(12px + env(safe-area-inset-bottom));
		border-top: 1px solid var(--color-light-line);
		background: var(--color-paper);
		flex-shrink: 0;
	}

	.chat-input {
		flex: 1;
		height: 42px;
		padding: 0 14px;
		border: 1.5px solid var(--color-light-line);
		border-radius: 21px;
		background: var(--color-cream);
		font-size: 0.9rem;
		color: var(--color-warm-brown);
		font-family: inherit;
		outline: none;
		transition: border-color 0.15s;
	}

	.chat-input:focus { border-color: var(--color-terracotta); }
	.chat-input::placeholder { color: var(--color-soft-brown); opacity: 0.6; }
	.chat-input:disabled { opacity: 0.6; }

	.send-btn {
		width: 42px;
		height: 42px;
		border-radius: 50%;
		border: none;
		background: var(--color-terracotta);
		color: #fff;
		display: flex;
		align-items: center;
		justify-content: center;
		flex-shrink: 0;
		cursor: pointer;
		transition: background 0.15s, opacity 0.15s;
	}

	.send-btn:disabled {
		opacity: 0.45;
		cursor: not-allowed;
	}

	.send-btn:hover:not(:disabled) { background: #b5633f; }
	.send-btn svg { width: 18px; height: 18px; }

	.send-spinner {
		width: 16px;
		height: 16px;
		border: 2px solid rgba(255,255,255,0.4);
		border-top-color: #fff;
		border-radius: 50%;
		animation: spin 0.7s linear infinite;
	}

	@keyframes spin {
		to { transform: rotate(360deg); }
	}
</style>
