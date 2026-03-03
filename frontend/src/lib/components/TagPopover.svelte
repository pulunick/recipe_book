<script lang="ts">
	import type { CollectionTag } from '$lib/types';

	interface Props {
		allTags: CollectionTag[];          // 유저가 가진 전체 태그 목록
		attachedTagIds: number[];          // 현재 레시피에 부착된 tag id 목록
		onclose: () => void;
		onattach: (tagId: number) => void;
		ondetach: (tagId: number) => void;
		oncreate: (name: string, color: string) => void;
	}

	let { allTags, attachedTagIds, onclose, onattach, ondetach, oncreate }: Props = $props();

	const TAG_COLORS = [
		{ hex: '#f28b82', label: '레드' },
		{ hex: '#fbbc04', label: '옐로우' },
		{ hex: '#34a853', label: '그린' },
		{ hex: '#4285f4', label: '블루' },
		{ hex: '#a8c7fa', label: '라이트블루' },
		{ hex: '#e6c9a8', label: '브라운' },
		{ hex: '#d3d3d3', label: '그레이' },
		{ hex: '#e8ddd4', label: '기본' }
	];

	let newTagName = $state('');
	let selectedColor = $state(TAG_COLORS[0].hex);

	function handleKeydown(e: KeyboardEvent) {
		if (e.key === 'Enter' && newTagName.trim()) {
			oncreate(newTagName.trim(), selectedColor);
			newTagName = '';
		}
		if (e.key === 'Escape') onclose();
	}

	function isAttached(tagId: number) {
		return attachedTagIds.includes(tagId);
	}

	function toggleTag(tagId: number) {
		if (isAttached(tagId)) ondetach(tagId);
		else onattach(tagId);
	}
</script>

<!-- 팝오버 외부 클릭 시 닫기용 배경 -->
<div
	class="popover-backdrop"
	role="presentation"
	onclick={onclose}
></div>

<div class="popover" role="dialog" aria-label="태그 추가">
	<p class="popover-title">태그 추가</p>

	<!-- 기존 태그 목록 -->
	{#if allTags.length > 0}
		<div class="existing-tags">
			{#each allTags as tag}
				<button
					type="button"
					class="tag-option"
					class:attached={isAttached(tag.id)}
					style:--tag-color={tag.color}
					onclick={() => toggleTag(tag.id)}
				>
					{isAttached(tag.id) ? '✓ ' : ''}{tag.name}
				</button>
			{/each}
		</div>
		<hr class="divider" />
	{/if}

	<!-- 새 태그 생성 -->
	<p class="create-label">새 태그 만들기</p>
	<input
		type="text"
		class="tag-input"
		placeholder="태그 이름 입력 후 Enter"
		bind:value={newTagName}
		onkeydown={handleKeydown}
		maxlength={20}
	/>

	<!-- 색상 선택 -->
	<div class="color-picker">
		{#each TAG_COLORS as c}
			<button
				type="button"
				class="color-swatch"
				class:selected={selectedColor === c.hex}
				style:background={c.hex}
				aria-label={c.label}
				onclick={() => (selectedColor = c.hex)}
			></button>
		{/each}
	</div>

	{#if newTagName.trim()}
		<button
			type="button"
			class="create-btn"
			onclick={() => { oncreate(newTagName.trim(), selectedColor); newTagName = ''; }}
		>
			"{newTagName}" 태그 만들기
		</button>
	{/if}
</div>

<style>
	.popover-backdrop {
		position: fixed;
		inset: 0;
		z-index: 100;
	}
	.popover {
		position: absolute;
		bottom: calc(100% + 8px);
		left: 0;
		z-index: 101;
		background: white;
		border: 1px solid var(--color-light-line);
		border-radius: 12px;
		padding: 1rem;
		width: 220px;
		box-shadow: 0 4px 20px rgba(0,0,0,0.12);
	}
	.popover-title {
		font-size: 0.8rem;
		font-weight: 700;
		color: var(--color-soft-brown);
		margin-bottom: 0.6rem;
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}
	.existing-tags {
		display: flex;
		flex-wrap: wrap;
		gap: 0.35rem;
		margin-bottom: 0.6rem;
	}
	.tag-option {
		font-size: 0.75rem;
		font-weight: 600;
		padding: 0.2rem 0.6rem;
		border-radius: 10px;
		border: 1px solid color-mix(in srgb, var(--tag-color) 30%, transparent);
		background: color-mix(in srgb, var(--tag-color) 15%, transparent);
		color: color-mix(in srgb, var(--tag-color) 80%, #333);
		transition: opacity 0.15s;
	}
	.tag-option.attached {
		background: color-mix(in srgb, var(--tag-color) 35%, transparent);
	}
	.tag-option:hover { opacity: 0.8; }

	.divider {
		border: none;
		border-top: 1px solid var(--color-light-line);
		margin: 0.6rem 0;
	}
	.create-label {
		font-size: 0.75rem;
		color: var(--color-soft-brown);
		margin-bottom: 0.4rem;
	}
	.tag-input {
		width: 100%;
		border: 1px solid var(--color-light-line);
		border-radius: 8px;
		padding: 0.4rem 0.6rem;
		font-size: 0.85rem;
		font-family: inherit;
		color: var(--color-warm-brown);
		background: var(--color-paper);
		outline: none;
	}
	.tag-input:focus { border-color: var(--color-terracotta); }

	.color-picker {
		display: flex;
		gap: 0.35rem;
		margin-top: 0.5rem;
		flex-wrap: wrap;
	}
	.color-swatch {
		width: 22px;
		height: 22px;
		border-radius: 50%;
		border: 2px solid transparent;
		padding: 0;
	}
	.color-swatch.selected {
		border-color: var(--color-warm-brown);
		outline: 2px solid white;
		outline-offset: -3px;
	}
	.color-swatch:hover { transform: scale(1.15); }

	.create-btn {
		margin-top: 0.6rem;
		width: 100%;
		background: var(--color-terracotta);
		color: white;
		border: none;
		border-radius: 8px;
		padding: 0.4rem 0.6rem;
		font-size: 0.8rem;
		font-weight: 600;
	}
	.create-btn:hover { background: #b5633f; }
</style>
