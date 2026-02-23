import yt_dlp
import os
import re
from logger import get_logger

logger = get_logger(__name__)

# yt-dlp 공통 옵션: JS challenge solver를 위한 remote-components 활성화
_YDL_COMMON_OPTS = {
    "extractor_args": {"youtube": {"remote_components": ["ejs:github"]}},
}


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
    Returns: (video_id, error_detail) — error_detail은 접근 불가 사유
    """
    video_id = None
    error_detail = None

    try:
        ydl_opts = {
            **_YDL_COMMON_OPTS,
            "quiet": True,
            "no_warnings": True,
            "force_generic_extractor": True,
            "extract_flat": True,
        }
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info_dict = ydl.extract_info(url, download=False, process=False)
            video_id = info_dict.get("id")
    except Exception as e:
        error_str = str(e)
        logger.warning("yt-dlp 메타데이터 추출 실패: %s", error_str)

        if "members-only" in error_str.lower() or "membership" in error_str.lower():
            error_detail = "이 영상은 멤버십 전용 영상입니다. 공개된 영상만 분석할 수 있습니다."
        elif "private" in error_str.lower():
            error_detail = "이 영상은 비공개 영상입니다."
        elif "login" in error_str.lower():
            error_detail = "로그인이 필요한 영상입니다. (성인 인증 등)"

        video_id = get_video_id_fallback(url)

    return video_id, error_detail


def download_audio(url: str, output_path: str = "audio.mp3") -> str:
    """유튜브 영상에서 오디오 추출하여 저장"""
    ydl_opts = {
        **_YDL_COMMON_OPTS,
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


def get_video_metadata(url: str) -> dict:
    """유튜브 영상 메타데이터만 추출"""
    ydl_opts = {**_YDL_COMMON_OPTS, "quiet": True, "skip_download": True}
    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        return ydl.extract_info(url, download=False)


def download_subtitles(url: str, output_path: str = "subtitle") -> str | None:
    """유튜브 영상에서 자막을 추출하여 순수 텍스트로 반환"""
    ydl_opts = {
        **_YDL_COMMON_OPTS,
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
            # 공식 자막 확인
            subs = info.get("subtitles", {})
            auto_subs = info.get("automatic_captions", {})

            # 공식 자막 우선, 없으면 자동생성 자막
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

            # 자막 다운로드
            if is_auto:
                ydl_opts["writesubtitles"] = False
            else:
                ydl_opts["writeautomaticsub"] = False
            ydl_opts["subtitleslangs"] = [target_lang]

            with yt_dlp.YoutubeDL(ydl_opts) as ydl2:
                ydl2.download([url])

        # VTT 파일 찾기
        for ext in [f".{target_lang}.vtt", ".vtt"]:
            candidate = output_path + ext
            if os.path.exists(candidate):
                subtitle_files.append(candidate)
                break

        if not subtitle_files:
            logger.warning("자막 파일을 찾을 수 없습니다.")
            return None

        # VTT → 순수 텍스트 변환 (타임스탬프, 헤더 제거)
        vtt_path = subtitle_files[0]
        with open(vtt_path, "r", encoding="utf-8") as f:
            lines = f.readlines()

        text_lines = []
        seen = set()
        for line in lines:
            line = line.strip()
            # WEBVTT 헤더, 빈 줄, 타임스탬프 라인 건너뛰기
            if not line or line.startswith("WEBVTT") or line.startswith("Kind:") or line.startswith("Language:"):
                continue
            if re.match(r"\d{2}:\d{2}:\d{2}\.\d{3}\s*-->", line):
                continue
            if re.match(r"^\d+$", line):
                continue
            # HTML 태그 제거
            clean = re.sub(r"<[^>]+>", "", line)
            clean = clean.strip()
            if clean and clean not in seen:
                seen.add(clean)
                text_lines.append(clean)

        subtitle_text = "\n".join(text_lines)
        logger.info("자막 추출 완료 (%d자, 언어: %s, 자동생성: %s)", len(subtitle_text), target_lang, is_auto)
        return subtitle_text if subtitle_text else None

    except Exception as e:
        logger.warning("자막 추출 실패: %s", e)
        return None
    finally:
        # 임시 자막 파일 정리
        for f in subtitle_files:
            try:
                if os.path.exists(f):
                    os.remove(f)
            except Exception:
                pass
