import yt_dlp
import os
import re
import json
import base64
import tempfile
import urllib.request
import urllib.error
from logger import get_logger

logger = get_logger(__name__)

# YouTube 쿠키 파일 경로 (환경변수 YOUTUBE_COOKIES_B64에서 디코딩)
_COOKIES_PATH: str | None = None


def _init_cookies() -> str | None:
    """환경변수 YOUTUBE_COOKIES_B64(Base64)를 파일로 디코딩하여 경로 반환"""
    global _COOKIES_PATH
    if _COOKIES_PATH and os.path.exists(_COOKIES_PATH):
        return _COOKIES_PATH

    cookies_b64 = os.getenv("YOUTUBE_COOKIES_B64")
    if not cookies_b64:
        return None

    try:
        cookies_data = base64.b64decode(cookies_b64)
        fd, path = tempfile.mkstemp(suffix=".txt", prefix="yt_cookies_")
        with os.fdopen(fd, "wb") as f:
            f.write(cookies_data)
        _COOKIES_PATH = path
        logger.info("YouTube 쿠키 파일 생성: %s", path)
        return path
    except Exception as e:
        logger.warning("YouTube 쿠키 디코딩 실패: %s", e)
        return None


def _get_common_opts() -> dict:
    """yt-dlp 공통 옵션 반환 (쿠키 포함)"""
    opts: dict = {
        "extractor_args": {
            "youtube": {
                "player_client": ["mweb", "android"],
                "remote_components": ["ejs:github"],
            }
        },
    }
    cookies_path = _init_cookies()
    if cookies_path:
        opts["cookiefile"] = cookies_path
    return opts


def get_video_id_fallback(url: str) -> str | None:
    """URL에서 직접 Video ID를 추출하는 정규식 Fallback"""
    patterns = [
        r"(?:v=|\/)([0-9A-Za-z_-]{11}).*",
        r"youtu\.be\/([0-9A-Za-z_-]{11})",
        r"embed\/([0-9A-Za-z_-]{11})",
        r"shorts\/([0-9A-Za-z_-]{11})"
    ]
    for pattern in patterns:
        match = re.search(pattern, url)
        if match:
            return match.group(1)
    return None


def extract_video_id(url: str) -> tuple[str | None, str | None]:
    """
    YouTube URL에서 video_id를 추출합니다.
    정규식 우선, yt-dlp는 사용하지 않음 (봇 차단 회피).
    Returns: (video_id, error_detail)
    """
    video_id = get_video_id_fallback(url)
    if video_id:
        return video_id, None

    # 정규식 실패 시 yt-dlp fallback
    error_detail = None
    try:
        ydl_opts = {
            **_get_common_opts(),
            "quiet": True,
            "no_warnings": True,
            "extract_flat": True,
        }
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info_dict = ydl.extract_info(url, download=False, process=False)
            video_id = info_dict.get("id")
    except Exception as e:
        error_str = str(e)
        logger.warning("yt-dlp video ID 추출 실패: %s", error_str)

        if "members-only" in error_str.lower() or "membership" in error_str.lower():
            error_detail = "이 영상은 멤버십 전용 영상입니다. 공개된 영상만 분석할 수 있습니다."
        elif "private" in error_str.lower():
            error_detail = "이 영상은 비공개 영상입니다."
        elif "login" in error_str.lower():
            error_detail = "로그인이 필요한 영상입니다. (성인 인증 등)"

    return video_id, error_detail


# ============================================================
# YouTube oEmbed API — 메타데이터 (yt-dlp 불필요)
# ============================================================

def get_video_metadata(url: str) -> dict:
    """YouTube oEmbed API로 메타데이터 추출 (봇 차단 없음)"""
    video_id = get_video_id_fallback(url)
    metadata: dict = {"title": "", "description": "", "uploader": ""}

    # oEmbed API (API 키 불필요, 데이터센터에서도 동작)
    oembed_url = f"https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v={video_id}&format=json"
    try:
        req = urllib.request.Request(oembed_url, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read().decode())
            metadata["title"] = data.get("title", "")
            metadata["uploader"] = data.get("author_name", "")
            logger.info("oEmbed 메타데이터 성공: %s", metadata["title"])
    except Exception as e:
        logger.warning("oEmbed 메타데이터 실패: %s", e)

    # yt-dlp fallback (실패해도 진행)
    if not metadata["title"]:
        try:
            ydl_opts = {**_get_common_opts(), "quiet": True, "skip_download": True}
            with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                info = ydl.extract_info(url, download=False)
                metadata = info
                logger.info("yt-dlp 메타데이터 fallback 성공")
        except Exception as e:
            logger.warning("yt-dlp 메타데이터도 실패 (진행 계속): %s", e)

    return metadata


# ============================================================
# youtube-transcript-api — 자막 (yt-dlp 불필요)
# ============================================================

def download_subtitles(url: str, output_path: str = "subtitle") -> str | None:
    """youtube-transcript-api로 자막 추출 (봇 차단 없음)"""
    video_id = get_video_id_fallback(url)
    if not video_id:
        return None

    # 1차: youtube-transcript-api (쿠키 인증으로 클라우드 IP 차단 우회)
    try:
        from youtube_transcript_api import YouTubeTranscriptApi
        logger.info("Transcript API 시도 (video_id: %s)", video_id)

        # 쿠키 파일이 있으면 인증 모드로 생성
        cookies_path = _init_cookies()
        if cookies_path:
            logger.info("Transcript API 쿠키 인증 모드 (cookie_path: %s)", cookies_path)
            api = YouTubeTranscriptApi(cookie_path=cookies_path)
        else:
            logger.info("Transcript API 비인증 모드")
            api = YouTubeTranscriptApi()

        # 방법 1: 사용 가능한 자막 목록 먼저 확인
        try:
            transcript_list = api.list(video_id)
            available = [(t.language, t.language_code, t.is_generated) for t in transcript_list]
            logger.info("사용 가능한 자막: %s", available)
        except Exception as list_err:
            logger.warning("Transcript API 목록 조회 실패: %s", list_err)
            transcript_list = None

        # 방법 2: 직접 fetch 시도 (한국어/영어)
        transcript_text = None
        for lang in ["ko", "en"]:
            try:
                transcript = api.fetch(video_id, languages=[lang])
                lines = []
                for snippet in transcript.snippets:
                    lines.append(snippet.text)
                transcript_text = "\n".join(lines)
                logger.info("Transcript API fetch 성공 (%d자, 언어: %s)", len(transcript_text), lang)
                break
            except Exception as fetch_err:
                logger.info("Transcript API fetch 실패 (언어: %s): %s", lang, fetch_err)
                continue

        # 방법 3: 언어 미지정으로 시도
        if not transcript_text:
            try:
                logger.info("Transcript API 언어 미지정 fetch 시도")
                transcript = api.fetch(video_id)
                lines = []
                for snippet in transcript.snippets:
                    lines.append(snippet.text)
                transcript_text = "\n".join(lines)
                logger.info("Transcript API 언어 미지정 성공 (%d자)", len(transcript_text))
            except Exception as any_err:
                logger.warning("Transcript API 언어 미지정도 실패: %s", any_err)

        if transcript_text:
            return transcript_text
        else:
            logger.warning("Transcript API: 이 영상에 사용 가능한 자막 없음")

    except ImportError:
        logger.error("youtube-transcript-api 미설치! pip install youtube-transcript-api 필요")
    except Exception as e:
        logger.warning("Transcript API 전체 실패: %s (type: %s)", e, type(e).__name__)

    # 2차: yt-dlp fallback
    logger.info("yt-dlp 자막 추출 fallback 시도")
    return _download_subtitles_ytdlp(url, output_path)


def _download_subtitles_ytdlp(url: str, output_path: str) -> str | None:
    """yt-dlp로 자막 추출 (fallback)"""
    ydl_opts = {
        **_get_common_opts(),
        "quiet": True,
        "no_warnings": True,
        "skip_download": True,
        "writesubtitles": True,
        "writeautomaticsub": True,
        "subtitleslangs": ["ko", "en"],
        "subtitlesformat": "vtt",
        "outtmpl": output_path,
    }

    subtitle_files = []
    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(url, download=False)
            subs = info.get("subtitles", {})
            auto_subs = info.get("automatic_captions", {})

            target_lang = None
            is_auto = False
            for lang in ["ko", "en"]:
                if lang in subs:
                    target_lang = lang
                    break
            if not target_lang:
                for lang in ["ko", "en"]:
                    if lang in auto_subs:
                        target_lang = lang
                        is_auto = True
                        break

            if not target_lang:
                logger.info("자막 없음: 사용 가능한 자막이 없습니다.")
                return None

            if is_auto:
                ydl_opts["writesubtitles"] = False
            else:
                ydl_opts["writeautomaticsub"] = False
            ydl_opts["subtitleslangs"] = [target_lang]

            with yt_dlp.YoutubeDL(ydl_opts) as ydl2:
                ydl2.download([url])

        for ext in [f".{target_lang}.vtt", ".vtt"]:
            candidate = output_path + ext
            if os.path.exists(candidate):
                subtitle_files.append(candidate)
                break

        if not subtitle_files:
            return None

        vtt_path = subtitle_files[0]
        with open(vtt_path, "r", encoding="utf-8") as f:
            lines = f.readlines()

        text_lines = []
        seen = set()
        for line in lines:
            line = line.strip()
            if not line or line.startswith("WEBVTT") or line.startswith("Kind:") or line.startswith("Language:"):
                continue
            if re.match(r"\d{2}:\d{2}:\d{2}\.\d{3}\s*-->", line):
                continue
            if re.match(r"^\d+$", line):
                continue
            clean = re.sub(r"<[^>]+>", "", line)
            clean = clean.strip()
            if clean and clean not in seen:
                seen.add(clean)
                text_lines.append(clean)

        subtitle_text = "\n".join(text_lines)
        logger.info("yt-dlp 자막 추출 완료 (%d자)", len(subtitle_text))
        return subtitle_text if subtitle_text else None

    except Exception as e:
        logger.warning("yt-dlp 자막 추출 실패: %s", e)
        return None
    finally:
        for f in subtitle_files:
            try:
                if os.path.exists(f):
                    os.remove(f)
            except Exception:
                pass


# ============================================================
# 오디오 다운로드 (yt-dlp — precise 모드 전용)
# ============================================================

def download_audio(url: str, output_path: str = "audio.mp3") -> str:
    """유튜브 영상에서 오디오 추출하여 저장"""
    ydl_opts = {
        **_get_common_opts(),
        "format": "bestaudio/best",
        "postprocessors": [{
            "key": "FFmpegExtractAudio",
            "preferredcodec": "mp3",
            "preferredquality": "192",
        }],
        "outtmpl": output_path.replace(".mp3", ""),
        "quiet": True,
        "overwrites": True,
    }
    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        ydl.download([url])

    final_path = output_path
    if not os.path.exists(final_path) and os.path.exists(final_path + ".mp3"):
        final_path = final_path + ".mp3"

    return final_path
