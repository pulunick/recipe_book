import asyncio
import json
import os
import re
import time

import google.generativeai as genai
from dotenv import load_dotenv
from tenacity import retry, stop_after_attempt, wait_exponential, retry_if_exception_type

from schemas import Recipe
from logger import get_logger

load_dotenv()

logger = get_logger(__name__)

MAX_POLLING_SECONDS = 120

# --- 지연 초기화 (lazy init) ---
_model = None


def _get_model():
    global _model
    if _model is None:
        api_key = os.getenv("GEMINI_API_KEY")
        if not api_key:
            raise RuntimeError("GEMINI_API_KEY 환경변수가 설정되지 않았습니다.")
        genai.configure(api_key=api_key)
        _model = genai.GenerativeModel("gemini-2.5-flash")
        logger.info("Gemini 모델 초기화 완료")
    return _model


def _extract_json_from_text(text: str) -> dict:
    """Gemini 응답에서 JSON을 안전하게 추출"""
    # 1) ```json ... ``` 블록 추출
    md_match = re.search(r"```json\s*([\s\S]*?)```", text)
    if md_match:
        return json.loads(md_match.group(1).strip())

    # 2) ``` ... ``` 블록 추출
    code_match = re.search(r"```\s*([\s\S]*?)```", text)
    if code_match:
        return json.loads(code_match.group(1).strip())

    # 3) 첫 번째 { ... 마지막 } 추출
    brace_match = re.search(r"\{[\s\S]*\}", text)
    if brace_match:
        return json.loads(brace_match.group(0))

    raise ValueError("Gemini 응답에서 유효한 JSON을 찾을 수 없습니다.")


def _build_prompt(metadata: dict, subtitle_text: str | None = None, has_audio: bool = False) -> str:
    """분석 모드에 따라 프롬프트를 생성"""
    title = metadata.get("title", "")

    # 입력 소스 설명
    if has_audio and subtitle_text:
        source_desc = "제공된 [오디오 파일]과 [자막 텍스트], 그리고 메타데이터(제목, 설명)"
        fact_check = (
            "1. 오디오와 자막을 교차 검증하여 가장 정확한 정보를 추출하십시오.\n"
            "2. 오디오와 자막이 다를 경우, 오디오 내용을 우선하되 자막의 정확한 수치 정보를 참고하십시오.\n"
            "3. \"대충\", \"적당히\" 같은 표현은 \"10g\", \"약간\" 등으로 표준화하되, 뉘앙스를 최대한 살리십시오.\n"
            "4. **[중요]** 분석 결과, 해당 영상이 실제 요리 과정을 담은 '레시피 영상'이 아닌 경우(예: 단순히 음식을 먹는 영상, 뉴스, 노래, 브이로그 등), "
            "`is_recipe`를 `false`로 설정하고 그 이유를 `non_recipe_reason`에 구체적으로 적으십시오."
        )
    elif subtitle_text:
        source_desc = "제공된 [자막 텍스트]와 메타데이터(제목, 설명)"
        fact_check = (
            "1. 자막 텍스트의 내용을 최우선으로 반영하십시오. (정량, 재료명, 팁 등)\n"
            "2. \"대충\", \"적당히\" 같은 표현은 \"10g\", \"약간\" 등으로 표준화하되, 뉘앙스를 최대한 살리십시오.\n"
            "3. **[중요]** 자막 분석 결과, 해당 영상이 실제 요리 과정을 담은 '레시피 영상'이 아닌 경우(예: 단순히 음식을 먹는 영상, 뉴스, 노래, 브이로그 등), "
            "`is_recipe`를 `false`로 설정하고 그 이유를 `non_recipe_reason`에 구체적으로 적으십시오."
        )
    else:
        source_desc = "제공된 [오디오 파일]과 메타데이터(제목, 설명)"
        fact_check = (
            "1. 오디오 내용을 최우선으로 반영하십시오. (정량, 재료명, 팁 등)\n"
            "2. \"대충\", \"적당히\" 같은 표현은 \"10g\", \"약간\" 등으로 표준화하되, 오디오의 뉘앙스를 최대한 살리십시오.\n"
            "3. **[중요]** 오디오 분석 결과, 해당 영상이 실제 요리 과정을 담은 '레시피 영상'이 아닌 경우(예: 단순히 음식을 먹는 영상, 뉴스, 노래, 브이로그 등), "
            "`is_recipe`를 `false`로 설정하고 그 이유를 `non_recipe_reason`에 구체적으로 적으십시오."
        )

    # 자막 텍스트 섹션
    subtitle_section = ""
    if subtitle_text:
        subtitle_section = f"""
    [자막 텍스트]
    {subtitle_text}
    """

    prompt = f"""
    당신은 영상을 정밀하게 분석하여 데이터베이스에 저장할 구조화된 레시피 데이터를 추출하는 'AI 요리 데이터 분석가'입니다.
    {source_desc}를 바탕으로, 다음 규칙에 맞춰 완벽한 JSON 데이터를 생성하세요.
    {subtitle_section}
    [필수 지침 - Fact Check]
    {fact_check}
    이 경우 나머지 필드는 최소화하거나 비워두어도 됩니다.

    [데이터 구조화 가이드]
    1. **Ingredients (재료)**:
       - 모든 재료를 하나씩 분리하여 객체로 만드세요.
       - `amount`는 수치(String)로, `unit`은 단위(String)로 명확히 분리하세요.
       - `category`는 '주재료', '부재료', '양념', '소스', '토핑' 등으로 분류하세요.
    2. **Steps (조리 과정)**:
       - 각 단계를 순서대로 분리하세요.
       - `timer` 필드에는 "10분", "30초" 등 구체적인 시간이 언급된 경우에만 기입하세요.
    3. **Flavor (맛 분석)**:
       - `saltiness` (짠맛), `sweetness` (단맛), `spiciness` (매운맛), `sourness` (신맛), `oiliness` (기름짐)
       - 5가지 지표를 1~5점 척도로 평가하세요.

    [결과 포맷 (JSON)]
    {{{{
        "is_recipe": true,
        "non_recipe_reason": null,
        "title": "{title}",
        "summary": "서술형 요약문...",
        "ingredients": [
            {{{{
                "name": "돼지고기 목살",
                "amount": "450",
                "unit": "g",
                "category": "주재료"
            }}}}
        ],
        "steps": [
            {{{{
                "step_number": 1,
                "description": "냄비에 물 500ml를 넣고 끓입니다.",
                "timer": null
            }}}}
        ],
        "flavor": {{{{
            "saltiness": 3,
            "sweetness": 2,
            "spiciness": 4,
            "sourness": 1,
            "oiliness": 3
        }}}},
        "tip": "마지막에 참기름을 한 바퀴 두르면 풍미가 살아납니다."
    }}}}

    * 만약 레시피 영상이 아니면:
    {{{{
        "is_recipe": false,
        "non_recipe_reason": "추출 가능한 구체적인 조리 과정이 포함되어 있지 않습니다.",
        "title": "{title}",
        "summary": "...",
        "ingredients": [],
        "steps": [],
        "flavor": {{{{"saltiness": 1, "sweetness": 1, "spiciness": 1, "sourness": 1, "oiliness": 1}}}},
        "tip": null
    }}}}
    """
    return prompt


@retry(
    stop=stop_after_attempt(3),
    wait=wait_exponential(multiplier=2, min=4, max=30),
    retry=retry_if_exception_type((ConnectionError, TimeoutError)),
    before_sleep=lambda retry_state: logger.warning(
        "Gemini 재시도 %d/%d...", retry_state.attempt_number, 3
    ),
)
async def extract_recipe_with_gemini(
    url: str, video_id: str, metadata: dict,
    audio_path: str | None = None, subtitle_text: str | None = None
) -> Recipe:
    """Gemini에게 자막/오디오를 전달하여 레시피 구조화

    - 자막만: 텍스트 기반 빠른 분석
    - 오디오 + 자막: 멀티모달 교차 검증 (정밀 분석)
    - 오디오만: 기존 방식 (fallback)
    """

    model = _get_model()
    has_audio = audio_path is not None
    prompt = _build_prompt(metadata, subtitle_text, has_audio)

    if has_audio:
        # 오디오 업로드 및 처리 대기
        logger.info("Gemini 파일 업로드 시작...")
        audio_file = genai.upload_file(audio_path, mime_type="audio/mp3")

        poll_start = time.time()
        while audio_file.state.name == "PROCESSING":
            elapsed = time.time() - poll_start
            if elapsed > MAX_POLLING_SECONDS:
                raise TimeoutError(
                    f"Gemini 파일 처리 타임아웃 ({MAX_POLLING_SECONDS}초 초과)"
                )
            logger.info("오디오 파일 처리 중... (%.0f초 경과)", elapsed)
            await asyncio.sleep(3)
            audio_file = genai.get_file(audio_file.name)

        if audio_file.state.name == "FAILED":
            raise RuntimeError("Gemini 오디오 파일 처리 실패")

        logger.info("오디오 업로드 및 처리 완료")
        response = model.generate_content([prompt, audio_file])
    else:
        # 자막 텍스트만으로 분석 (빠른 모드)
        logger.info("자막 텍스트 기반 분석 시작...")
        response = model.generate_content([prompt])

    logger.info("Gemini 응답 수신 완료")

    parsed = _extract_json_from_text(response.text)
    result_recipe = Recipe(**parsed)
    result_recipe.video_id = video_id
    return result_recipe
