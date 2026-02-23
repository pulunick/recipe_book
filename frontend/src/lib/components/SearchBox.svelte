<script lang="ts">
	import type { AnalysisMode } from '$lib/types';

	interface Props {
		onsubmit: (url: string, mode: AnalysisMode) => void;
		errorMessage?: string;
		disabled?: boolean;
	}
	let { onsubmit, errorMessage = '', disabled = false }: Props = $props();

	let url = $state('');
	let mode: AnalysisMode = $state('fast');

	function handleSubmit() {
		if (!url.trim() || disabled) return;
		onsubmit(url.trim(), mode);
	}
</script>

<div class="url-input-area">
	<div class="input-wrap">
		<input
			type="url"
			bind:value={url}
			placeholder="유튜브 링크를 여기에 붙여넣으세요"
			onkeydown={(e) => e.key === 'Enter' && handleSubmit()}
			{disabled}
		/>
		<button class="submit-btn" onclick={handleSubmit} {disabled}>
			레시피 정리하기
		</button>
	</div>
	<div class="mode-select">
		<label class:active={mode === 'fast'}>
			<input type="radio" bind:group={mode} value="fast" />
			빠른 정리
		</label>
		<label class:active={mode === 'precise'}>
			<input type="radio" bind:group={mode} value="precise" />
			꼼꼼한 정리
		</label>
	</div>
	{#if errorMessage}
		<div class="error-notice">
			<p>문제가 생겼어요</p>
			<p class="error-detail">{errorMessage}</p>
		</div>
	{/if}
</div>

<style>
	.url-input-area {
		width: 100%;
		max-width: 600px;
		margin: 0 auto;
	}
	.input-wrap {
		display: flex;
		gap: 0.5rem;
		background: white;
		border: 2px solid var(--color-light-line);
		border-radius: 12px;
		padding: 6px;
		transition: border-color 0.2s;
	}
	.input-wrap:focus-within {
		border-color: var(--color-terracotta);
	}
	.input-wrap input {
		flex: 1;
		border: none;
		outline: none;
		padding: 0.9rem 1rem;
		font-size: 1rem;
		color: var(--color-warm-brown);
		background: transparent;
		min-width: 0;
	}
	.input-wrap input::placeholder {
		color: var(--color-soft-brown);
		opacity: 0.6;
	}
	.submit-btn {
		background: var(--color-terracotta);
		color: white;
		border: none;
		padding: 0.9rem 1.5rem;
		border-radius: 8px;
		font-size: 1rem;
		font-weight: 600;
		white-space: nowrap;
	}
	.submit-btn:hover:not(:disabled) {
		background: #b5633f;
	}
	.submit-btn:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.mode-select {
		display: flex;
		justify-content: center;
		gap: 1rem;
		margin-top: 0.8rem;
	}
	.mode-select label {
		display: flex;
		align-items: center;
		gap: 0.3rem;
		font-size: 0.9rem;
		color: var(--color-soft-brown);
		cursor: pointer;
		padding: 0.3rem 0.6rem;
		border-radius: 6px;
		transition: var(--transition);
	}
	.mode-select label.active {
		color: var(--color-terracotta);
		font-weight: 600;
	}
	.mode-select input[type="radio"] {
		accent-color: var(--color-terracotta);
	}

	.error-notice {
		margin-top: 1rem;
		padding: 1rem;
		background: #fdf2f2;
		border: 1px solid #f0d0d0;
		border-radius: 10px;
		text-align: center;
	}
	.error-notice p:first-child {
		font-weight: 600;
		color: var(--color-muted-red);
		margin-bottom: 0.3rem;
	}
	.error-detail {
		font-size: 0.9rem;
		color: var(--color-soft-brown);
	}

	@media (max-width: 767px) {
		.input-wrap {
			flex-direction: column;
		}
		.submit-btn {
			width: 100%;
		}
	}
</style>
