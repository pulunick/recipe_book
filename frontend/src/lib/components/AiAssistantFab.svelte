<script lang="ts">
	import { chatWithAi } from '$lib/api';
	import type { Recipe } from '$lib/types';

	interface Props {
		collectionId: number;
		recipe: Recipe;
	}
	let { collectionId, recipe }: Props = $props();

	let isOpen = $state(false);
	let messages = $state<{ role: 'user' | 'ai'; content: string }[]>([]);
	let inputText = $state('');
	let isLoading = $state(false);
	let fabImageError = $state(false);
	let chatEndEl = $state<HTMLDivElement | null>(null);

	const QUICK_CHIPS = ['재료 대체 추천해줘', '분량 반으로 줄이는 법', '이 레시피 칼로리 어때?'];

	function togglePanel() {
		isOpen = !isOpen;
	}

	async function sendMessage(text: string = inputText) {
		const msg = text.trim();
		if (!msg || isLoading) return;

		inputText = '';
		messages = [...messages, { role: 'user', content: msg }];
		isLoading = true;

		setTimeout(() => chatEndEl?.scrollIntoView({ behavior: 'smooth' }), 50);

		try {
			const history = messages
				.slice(0, -1)
				.map((m) => ({ role: m.role === 'user' ? 'user' : 'model', content: m.content }));
			const reply = await chatWithAi(collectionId, msg, history);
			messages = [...messages, { role: 'ai', content: reply }];
		} catch (e: unknown) {
			const errMsg = e instanceof Error ? e.message : '잠시 후 다시 시도해주세요.';
			messages = [...messages, { role: 'ai', content: errMsg }];
		} finally {
			isLoading = false;
			setTimeout(() => chatEndEl?.scrollIntoView({ behavior: 'smooth' }), 50);
		}
	}

	function handleKeydown(e: KeyboardEvent) {
		if (e.key === 'Enter' && !e.shiftKey) {
			e.preventDefault();
			sendMessage();
		}
	}
</script>

<!-- 채팅 패널 -->
{#if isOpen}
	<div class="chat-panel" role="dialog" aria-label="AI 요리 어시스턴트">
		<div class="panel-header">
			<div class="panel-title">
				<span class="panel-icon">✦</span>
				<div>
					<p class="panel-label">AI 요리 어시스턴트</p>
					<p class="panel-recipe">{recipe.title}</p>
				</div>
			</div>
			<button class="close-btn" onclick={togglePanel} aria-label="닫기">✕</button>
		</div>

		<div class="messages-area">
			{#if messages.length === 0}
				<p class="empty-hint">레시피에 대해 무엇이든 물어보세요 😊</p>
				<div class="quick-chips">
					{#each QUICK_CHIPS as chip}
						<button class="chip" onclick={() => sendMessage(chip)}>{chip}</button>
					{/each}
				</div>
			{:else}
				{#each messages as msg}
					<div class="message {msg.role}">
						<p>{msg.content}</p>
					</div>
				{/each}
				{#if isLoading}
					<div class="message ai">
						<span class="typing-dots"><span></span><span></span><span></span></span>
					</div>
				{/if}
				<div bind:this={chatEndEl}></div>
			{/if}
		</div>

		<div class="input-area">
			<textarea
				bind:value={inputText}
				onkeydown={handleKeydown}
				placeholder="질문을 입력하세요 (Enter 전송)"
				maxlength={300}
				rows={1}
				disabled={isLoading}
			></textarea>
			<button class="send-btn" onclick={() => sendMessage()} disabled={!inputText.trim() || isLoading}>
				→
			</button>
		</div>
	</div>
{/if}

<!-- FAB 버튼 — /static/meokdang.png 추가 시 자동으로 캐릭터 이미지로 전환 -->
<button class="fab" class:open={isOpen} onclick={togglePanel} aria-label="AI 요리 어시스턴트">
	{#if isOpen}
		<span class="fab-close">✕</span>
	{:else if !fabImageError}
		<!-- 먹당 캐릭터 이미지: /static/meokdang.png 파일 추가 시 활성화 -->
		<img
			src="/meokdang.png"
			alt="먹당"
			class="fab-character"
			onerror={() => (fabImageError = true)}
		/>
	{:else}
		<span class="fab-sparkle">✦</span>
	{/if}
</button>

<style>
	/* FAB 버튼 */
	.fab {
		position: fixed;
		bottom: calc(80px + env(safe-area-inset-bottom));
		right: 16px;
		width: 56px;
		height: 56px;
		border-radius: 50%;
		background: var(--color-terracotta);
		border: none;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		box-shadow: 0 4px 16px rgba(0, 0, 0, 0.18);
		z-index: 50;
		transition: transform 0.2s, background 0.2s;
		overflow: hidden;
		padding: 0;
	}
	.fab:hover { transform: scale(1.08); }
	.fab.open { background: var(--color-warm-brown); }

	.fab-character {
		width: 100%;
		height: 100%;
		object-fit: cover;
		border-radius: 50%;
	}
	.fab-sparkle,
	.fab-close {
		font-size: 1.3rem;
		color: #fff;
		line-height: 1;
	}

	/* 채팅 패널 */
	.chat-panel {
		position: fixed;
		bottom: calc(148px + env(safe-area-inset-bottom));
		right: 16px;
		width: min(360px, calc(100vw - 32px));
		height: 60vh;
		max-height: 520px;
		background: #fff;
		border-radius: 16px;
		box-shadow: 0 8px 32px rgba(0, 0, 0, 0.16);
		display: flex;
		flex-direction: column;
		z-index: 49;
		animation: panel-in 0.22s ease;
		overflow: hidden;
	}

	@keyframes panel-in {
		from { opacity: 0; transform: translateY(12px) scale(0.97); }
		to   { opacity: 1; transform: translateY(0) scale(1); }
	}

	.panel-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 12px 14px;
		border-bottom: 1px solid var(--color-light-line);
		flex-shrink: 0;
		background: var(--color-cream);
	}
	.panel-title {
		display: flex;
		align-items: center;
		gap: 8px;
	}
	.panel-icon {
		font-size: 1.1rem;
		color: var(--color-terracotta);
	}
	.panel-label {
		font-size: 0.8rem;
		font-weight: 700;
		color: var(--color-warm-brown);
	}
	.panel-recipe {
		font-size: 0.72rem;
		color: var(--color-soft-brown);
		white-space: nowrap;
		overflow: hidden;
		text-overflow: ellipsis;
		max-width: 200px;
	}
	.close-btn {
		background: none;
		border: none;
		font-size: 0.9rem;
		color: var(--color-soft-brown);
		cursor: pointer;
		padding: 4px;
		line-height: 1;
	}

	/* 메시지 영역 */
	.messages-area {
		flex: 1;
		overflow-y: auto;
		padding: 12px;
		display: flex;
		flex-direction: column;
		gap: 8px;
	}
	.empty-hint {
		font-size: 0.82rem;
		color: var(--color-soft-brown);
		text-align: center;
		margin-bottom: 10px;
	}
	.quick-chips {
		display: flex;
		flex-direction: column;
		gap: 6px;
	}
	.chip {
		background: var(--color-cream);
		border: 1.5px solid var(--color-light-line);
		border-radius: 10px;
		padding: 8px 12px;
		font-size: 0.8rem;
		color: var(--color-warm-brown);
		cursor: pointer;
		text-align: left;
		font-family: inherit;
		transition: border-color 0.15s;
	}
	.chip:hover { border-color: var(--color-terracotta); color: var(--color-terracotta); }

	.message {
		max-width: 80%;
		padding: 8px 12px;
		border-radius: 12px;
		font-size: 0.83rem;
		line-height: 1.55;
		white-space: pre-wrap;
		word-break: break-word;
	}
	.message p { margin: 0; }
	.message.user {
		align-self: flex-end;
		background: var(--color-terracotta);
		color: #fff;
		border-bottom-right-radius: 4px;
	}
	.message.ai {
		align-self: flex-start;
		background: var(--color-cream);
		color: var(--color-warm-brown);
		border-bottom-left-radius: 4px;
	}

	/* 타이핑 애니메이션 */
	.typing-dots {
		display: flex;
		gap: 4px;
		align-items: center;
		height: 16px;
	}
	.typing-dots span {
		width: 6px;
		height: 6px;
		border-radius: 50%;
		background: var(--color-soft-brown);
		animation: dot-bounce 1.2s infinite;
	}
	.typing-dots span:nth-child(2) { animation-delay: 0.2s; }
	.typing-dots span:nth-child(3) { animation-delay: 0.4s; }
	@keyframes dot-bounce {
		0%, 80%, 100% { transform: translateY(0); }
		40% { transform: translateY(-6px); }
	}

	/* 입력 영역 */
	.input-area {
		display: flex;
		align-items: flex-end;
		gap: 8px;
		padding: 10px 12px;
		border-top: 1px solid var(--color-light-line);
		flex-shrink: 0;
	}
	.input-area textarea {
		flex: 1;
		border: 1.5px solid var(--color-light-line);
		border-radius: 10px;
		padding: 8px 10px;
		font-size: 0.83rem;
		font-family: inherit;
		resize: none;
		outline: none;
		line-height: 1.4;
		max-height: 80px;
		overflow-y: auto;
		background: var(--color-cream);
	}
	.input-area textarea:focus { border-color: var(--color-terracotta); }
	.send-btn {
		width: 36px;
		height: 36px;
		border-radius: 50%;
		background: var(--color-terracotta);
		color: #fff;
		border: none;
		font-size: 1rem;
		cursor: pointer;
		flex-shrink: 0;
		display: flex;
		align-items: center;
		justify-content: center;
		transition: background 0.15s;
	}
	.send-btn:disabled { opacity: 0.4; cursor: not-allowed; }
	.send-btn:not(:disabled):hover { background: #b5633f; }
</style>
