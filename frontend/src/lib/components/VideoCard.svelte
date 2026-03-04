<script lang="ts">
	interface Props {
		videoId: string | null;
		videoUrl: string | null;
		channelName: string | null;
		videoTitle: string | null;
	}

	let { videoId, videoUrl, channelName, videoTitle }: Props = $props();

	const href = $derived(videoUrl || (videoId ? `https://youtu.be/${videoId}` : ''));
	const thumbSrc = $derived(videoId ? `https://img.youtube.com/vi/${videoId}/mqdefault.jpg` : '');
</script>

{#if href}
	<a class="video-card" {href} target="_blank" rel="noopener noreferrer">
		<div class="video-thumb">
			{#if thumbSrc}
				<img src={thumbSrc} alt="영상 썸네일" loading="lazy" />
			{:else}
				<div class="thumb-placeholder">&#9654;</div>
			{/if}
		</div>
		<div class="video-info">
			<span class="video-label">&#9654; 원본 영상</span>
			{#if channelName}
				<span class="video-channel">{channelName}</span>
			{/if}
			{#if videoTitle}
				<span class="video-title">{videoTitle}</span>
			{/if}
		</div>
		<span class="video-arrow" aria-hidden="true">&rarr;</span>
	</a>
{/if}

<style>
	.video-card {
		display: flex;
		align-items: center;
		gap: 1rem;
		margin-top: 2rem;
		padding: 0.8rem;
		border: 1px solid var(--color-light-line);
		border-radius: 10px;
		text-decoration: none;
		color: inherit;
		transition: border-color 0.2s, background 0.2s;
	}
	.video-card:hover {
		border-color: var(--color-soft-brown);
		background: var(--color-cream);
	}

	.video-thumb {
		flex-shrink: 0;
		width: 120px;
		aspect-ratio: 16 / 9;
		border-radius: 6px;
		overflow: hidden;
		background: var(--color-cream);
	}
	.video-thumb img {
		width: 100%;
		height: 100%;
		object-fit: cover;
		display: block;
	}
	.thumb-placeholder {
		display: flex;
		align-items: center;
		justify-content: center;
		height: 100%;
		font-size: 1.5rem;
		color: var(--color-soft-brown);
	}

	.video-info {
		flex: 1;
		display: flex;
		flex-direction: column;
		gap: 0.2rem;
		min-width: 0;
	}
	.video-label {
		font-size: 0.72rem;
		font-weight: 600;
		color: var(--color-soft-brown);
		letter-spacing: 0.04em;
	}
	.video-channel {
		font-size: 0.82rem;
		font-weight: 600;
		color: var(--color-warm-brown);
	}
	.video-title {
		font-size: 0.8rem;
		color: var(--color-soft-brown);
		display: -webkit-box;
		-webkit-line-clamp: 2;
		line-clamp: 2;
		-webkit-box-orient: vertical;
		overflow: hidden;
		line-height: 1.4;
	}

	.video-arrow {
		flex-shrink: 0;
		font-size: 1.2rem;
		color: var(--color-soft-brown);
		transition: transform 0.2s;
	}
	.video-card:hover .video-arrow {
		transform: translateX(3px);
	}

	@media (max-width: 767px) {
		.video-thumb {
			width: 90px;
		}
		.video-card {
			gap: 0.7rem;
			padding: 0.6rem;
		}
	}
</style>
