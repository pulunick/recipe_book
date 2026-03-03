import json
import os
import re

from google import genai
from google.genai import types
from dotenv import load_dotenv
from tenacity import retry, stop_after_attempt, wait_exponential, retry_if_exception_type

from schemas import Recipe
from logger import get_logger

load_dotenv()

logger = get_logger(__name__)

# 지연 초기화
_client: genai.Client | None = None
MODEL = "gemini-2.5-flash-preview-04-17"


def _get_client() -> genai.Client:
    global _client
    if _client is None:
        api_key = os.getenv("GEMINI_API_KEY")
        if not api_key:
            raise RuntimeError("GEMINI_API_KEY 환경변수가 설정되지 않았습니다.")
        _client = genai.Client(api_key=api_key)
        logger.info("Gemini 클라이언트 초기화 완료 (SDK: google-genai)")
    return _client


def _extract_json_from_text(text: str) -> dict:
    """Gemini 응답에서 JSON을 안전하게 추출"""
    md_match = re.search(r"```json\s*([\s\S]*?)```", text)
    if md_match:
        return json.loads(md_match.group(1).strip())

    code_match = re.search(r"```\s*([\s\S]*?)```", text)
    if code_match:
        return json.loads(code_match.group(1).strip())

    brace_match = re.search(r"\{[\s\S]*\}", text)
    if brace_match:
        return json.loads(brace_match.group(0))

    raise ValueError("Gemini 응답에서 유효한 JSON을 찾을 수 없습니다.")


def _build_prompt(metadata: dict) -> str:
    """분석 프롬프트 생성"""
    title = metadata.get("title", "")
    description = metadata.get("description", "")

    description_section = ""
    if description and len(description.strip()) > 20:
        description_section = f"""
    [영상 설명란 (Description)] ← 재료명·수치의 최우선 출처
    {description.strip()}
    """

    return f"""
    당신은 영상을 정밀하게 분석하여 데이터베이스에 저장할 구조화된 레시피 데이터를 추출하는 'AI 요리 데이터 분석가'입니다.
    첨부된 [YouTube 영상]과 메타데이터(제목, 설명)를 바탕으로, 다음 규칙에 맞춰 완벽한 JSON 데이터를 생성하세요.
    {description_section}
    [소스별 우선순위 - 반드시 준수]
    - **재료명·수치**: [영상 설명란]에 명시된 값이 있으면 그것을 절대 기준으로 사용. 설명란이 없거나 해당 재료가 없을 때만 영상에서 추출.
    - **조리 순서(steps)**: 영상 기준. 설명란보다 훨씬 상세하므로 영상 우선.
    - **팁(tip)**: 영상에서 추출. 설명란의 추가 메모가 있으면 병합.

    [필수 지침 - Fact Check]
    1. 영상 내용을 최우선으로 반영하십시오. (정량, 재료명, 팁 등)
    2. "대충", "적당히" 같은 표현은 "10g", "약간" 등으로 표준화하되, 뉘앙스를 최대한 살리십시오.
    3. **[중요]** 분석 결과, 해당 영상이 실제 요리 과정을 담은 '레시피 영상'이 아닌 경우(예: 단순히 음식을 먹는 영상, 뉴스, 노래, 브이로그 등),
       `is_recipe`를 `false`로 설정하고 그 이유를 `non_recipe_reason`에 구체적으로 적으십시오.

    [데이터 구조화 가이드]
    1. **Ingredients (재료)**:
       - 모든 재료를 하나씩 분리하여 객체로 만드세요.
       - `amount`는 수치(String)로, `unit`은 단위(String)로 명확히 분리하세요.
       - `category`는 '주재료', '부재료', '양념', '소스', '토핑' 등으로 분류하세요.
       - **[간장 종류 구분]** 간장류는 반드시 정확히 구분하세요: '간장', '진간장', '국간장', '양조간장', '조선간장' 등을 혼용하지 마세요.
       - **[수량 정확도]** 수량은 절대 반올림하거나 범위로 표현하지 마세요. "1.3T", "45g" 등 정확한 수치를 말했다면 그대로 기록하세요.
       - **[중복 재료 합산]** 동일한 재료가 여러 단계에서 나뉘어 사용되더라도 ingredients 목록에는 하나로 합산하여 표시하세요.
    2. **Steps (조리 과정)**:
       - 각 단계를 순서대로 분리하세요.
       - `timer` 필드에는 "10분", "30초" 등 구체적인 시간이 언급된 경우에만 기입하세요.
    3. **Flavor (맛 분석)**:
       - `saltiness` (짠맛), `sweetness` (단맛), `spiciness` (매운맛), `sourness` (신맛), `oiliness` (기름짐)
       - 5가지 지표를 1~5점 척도로 평가하세요.
    4. **Category (카테고리)**: 다음 고정 목록 중 하나를 선택하여 `category` 필드에 입력하세요.
       - 목록: 한식, 양식, 중식, 일식, 동남아, 국/찌개, 볶음, 구이, 찜, 반찬, 디저트, 음료, 간식, 다이어트, 간편식
       - 레시피 영상이 아닌 경우 `null`로 설정하세요.

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
        "tip": "마지막에 참기름을 한 바퀴 두르면 풍미가 살아납니다.",
        "category": "한식"
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
        "tip": null,
        "category": null
    }}}}
    """


@retry(
    stop=stop_after_attempt(3),
    wait=wait_exponential(multiplier=2, min=4, max=30),
    retry=retry_if_exception_type((ConnectionError, TimeoutError)),
    before_sleep=lambda retry_state: logger.warning(
        "Gemini 재시도 %d/%d...", retry_state.attempt_number, 3
    ),
)
async def extract_recipe_with_gemini(
    url: str, video_id: str, metadata: dict
) -> Recipe:
    """YouTube URL을 Gemini에 직접 전달하여 레시피 구조화.

    오디오 다운로드·자막 추출 없이 Google 서버가 YouTube에 직접 접근하므로
    클라우드 배포 환경에서도 봇 차단 없이 동작한다.
    """
    client = _get_client()
    prompt = _build_prompt(metadata)

    # video_id로 정규화된 URL 사용 (shorts/youtu.be 등 모든 형식 통일)
    canonical_url = f"https://www.youtube.com/watch?v={video_id}"
    logger.info("Gemini YouTube URL 분석 시작 (video_id: %s)", video_id)

    response = await client.aio.models.generate_content(
        model=MODEL,
        contents=[
            prompt,
            types.Part(
                file_data=types.FileData(
                    file_uri=canonical_url,
                    mime_type="video/*",
                )
            ),
        ],
    )

    logger.info("Gemini 응답 수신 완료")
    parsed = _extract_json_from_text(response.text)
    result_recipe = Recipe(**parsed)
    result_recipe.video_id = video_id
    return result_recipe
