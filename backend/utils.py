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

def _fetch_video_description(video_id: str) -> str | None:
    """YouTube 페이지 HTML에서 description 직접 스크래핑.
    oEmbed는 description을 제공하지 않아 별도 파싱 필요.
    """
    try:
        url = f"https://www.youtube.com/watch?v={video_id}"
        req = urllib.request.Request(url, headers={
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            "Accept-Language": "ko-KR,ko;q=0.9,en;q=0.8",
        })
        with urllib.request.urlopen(req, timeout=10) as resp:
            html = resp.read().decode("utf-8", errors="ignore")

        # ytInitialPlayerResponse에 포함된 shortDescription 추출
        match = re.search(r'"shortDescription":"((?:[^"\\]|\\.)*)"', html)
        if match:
            desc = match.group(1)
            desc = desc.replace("\\n", "\n").replace('\\"', '"').replace("\\\\", "\\")
            logger.info("YouTube 페이지 description 추출 성공 (%d자)", len(desc))
            return desc
    except Exception as e:
        logger.warning("YouTube description 스크래핑 실패: %s", e)
    return None


def get_video_metadata(url: str) -> dict:
    """YouTube 메타데이터 추출.
    - title/uploader: oEmbed API (봇 차단 없음)
    - description: 페이지 HTML 직접 파싱 (oEmbed는 제공 안 함)
    - 둘 다 실패 시 yt-dlp fallback
    """
    video_id = get_video_id_fallback(url)
    metadata: dict = {"title": "", "description": "", "uploader": ""}

    # 1) oEmbed API — title, uploader
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

    # 2) description 별도 스크래핑
    if video_id:
        desc = _fetch_video_description(video_id)
        if desc:
            metadata["description"] = desc

    # 3) yt-dlp fallback — title 없을 때만, description도 보완
    if not metadata["title"]:
        try:
            ydl_opts = {**_get_common_opts(), "quiet": True, "skip_download": True}
            with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                info = ydl.extract_info(url, download=False)
                metadata["title"] = info.get("title", metadata["title"])
                metadata["uploader"] = info.get("uploader", metadata["uploader"])
                if not metadata["description"] and info.get("description"):
                    metadata["description"] = info.get("description", "")
                logger.info("yt-dlp 메타데이터 fallback 성공")
        except Exception as e:
            logger.warning("yt-dlp 메타데이터도 실패 (진행 계속): %s", e)

    return metadata
