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
MODEL = "gemini-2.5-flash"           # 레시피 추출 (오디오/멀티모달)
CHAT_MODEL = "gemini-3.1-flash-lite-preview"  # AI 채팅 (텍스트 전용, 저비용)


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
       - **[amount null 절대 금지]** 모든 재료의 `amount` 필드는 반드시 문자열 값이어야 합니다. `null`은 허용하지 않습니다.
         - 영상/설명란에 정확한 수치가 있으면 그대로 사용 (예: "450", "2", "1.5")
         - 소금·후추·설탕·간장·참기름 등 조미료는 가능하면 계량 표현 사용 (예: "1작은술", "1/2T", "1꼬집", "2큰술")
         - 영상에서 구체적 양을 전혀 알 수 없는 경우에만 "약간", "적당량", "취향껏" 중 적절한 표현을 사용하세요.
         - 어떤 경우에도 amount가 `null`이 되어서는 안 됩니다.
    2. **Steps (조리 과정)**:
       - 각 단계를 순서대로 분리하세요.
       - `timer` 필드에는 "10분", "30초" 등 구체적인 시간이 언급된 경우에만 기입하세요.
       - **[핵심 정보 강조]** `description` 안에서 요리 성공에 결정적인 정보는 `**텍스트**` 형식으로 감싸세요.
         강조 대상: 시간·온도("**10~15분간 약불**", "**170°C**"), 중요 기술("**캐러멜라이즈**"), 주의사항("**절대 뚜껑 열지 마세요**"), 핵심 수치("**소금 반 꼬집**")
         남발 금지 — 단계당 최대 1~2곳만 강조하세요.
    3. **Flavor (맛 분석)**:
       - `saltiness` (짠맛), `sweetness` (단맛), `spiciness` (매운맛), `sourness` (신맛), `oiliness` (기름짐)
       - 5가지 지표를 1~5점 척도로 평가하세요.
    4. **Category (카테고리)**: 다음 고정 목록 중 하나를 선택하여 `category` 필드에 입력하세요.
       - 목록: 한식, 양식, 중식, 일식, 동남아, 국/찌개, 볶음, 구이, 찜, 반찬, 디저트, 음료, 간식, 다이어트, 간편식
       - 레시피 영상이 아닌 경우 `null`로 설정하세요.
    5. **Servings (인분)**:
       - 영상에서 언급한 완성 분량을 기록하세요 (예: "2인분", "3~4인분", "4인분 기준")
       - 언급이 없으면 null.
    6. **Cooking Time (조리 시간)**:
       - 전체 조리 소요 시간을 기록하세요 (예: "20분", "1시간", "1시간 30분")
       - 재료 손질 + 조리 + 휴지 시간을 합산한 총 시간.
       - 영상에서 명시하지 않으면 steps를 기반으로 추정하세요.
    7. **Difficulty (난이도)**:
       - 다음 기준으로 판단하세요:
         - **쉬움**: 조리 시간 20분 이내, 특별한 기술 불필요
         - **보통**: 조리 시간 20~60분 또는 중간 정도의 기술 필요
         - **어려움**: 조리 시간 60분 초과 또는 복잡한 기술(반죽, 정밀 온도 조절 등) 필요
       - 반드시 "쉬움", "보통", "어려움" 중 하나만 사용하세요.

    [title 필드 — 순수 요리명만 작성]
    - title에는 **순수 요리명만** 작성하세요. 짧고 명확하게.
    - 예: "마파두부", "된장찌개", "크림 파스타", "닭볶음탕"
    - **절대 금지**: 유튜버 이름, 채널명, 수식어, 광고 문구, 영상 제목 그대로 복사
    - 잘못된 예: "백종원의 초간단 마파두부", "[3분 요리] 된장찌개 만들기"
    - 올바른 예: "마파두부", "된장찌개"

    [결과 포맷 (JSON)]
    {{{{
        "is_recipe": true,
        "non_recipe_reason": null,
        "title": "순수 요리명 (예: 마파두부)",
        "summary": "서술형 요약문...",
        "ingredients": [
            {{{{
                "name": "돼지고기 목살",
                "amount": "450",
                "unit": "g",
                "category": "주재료"
            }}}},
            {{{{
                "name": "소금",
                "amount": "약간",
                "unit": "",
                "category": "양념"
            }}}},
            {{{{
                "name": "후추",
                "amount": "약간",
                "unit": "",
                "category": "양념"
            }}}}
        ],
        "steps": [
            {{{{
                "step_number": 1,
                "description": "냄비에 물 500ml를 넣고 **강불**에서 끓입니다.",
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
        "category": "한식",
        "servings": "2인분",
        "cooking_time": "30분",
        "difficulty": "보통"
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
        "category": null,
        "servings": null,
        "cooking_time": null,
        "difficulty": null
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


def _build_text_prompt(text: str, title: str | None) -> str:
    """텍스트 입력용 분석 프롬프트 생성"""
    title_hint = f"\n    [사용자 제공 제목]: {title}" if title else ""

    return f"""
    당신은 자유형식 텍스트를 분석하여 데이터베이스에 저장할 구조화된 레시피 데이터를 추출하는 'AI 요리 데이터 분석가'입니다.
    아래 [입력 텍스트]를 바탕으로, 다음 규칙에 맞춰 완벽한 JSON 데이터를 생성하세요.
    {title_hint}

    [입력 텍스트]
    {text}

    [필수 지침]
    1. 구어체, 반말, 메모 형식, 블로그 문체 등 어떤 형식이든 표준 레시피 형식으로 변환하세요.
    2. "대충", "적당히" 같은 표현은 "약간", "적당량" 등으로 표준화하되, 원래 뉘앙스를 살리세요.
    3. **[중요]** 입력 텍스트가 요리 레시피가 아닌 경우(예: 일상 대화, 뉴스, 관계없는 글),
       `is_recipe`를 `false`로 설정하고 그 이유를 `non_recipe_reason`에 구체적으로 적으십시오.
    4. 제목이 사용자 제공 제목이 있으면 그것을 우선 사용하되, 순수 요리명으로 정제하세요.
       제목이 없으면 텍스트 내용에서 요리명을 추출하세요.

    [데이터 구조화 가이드]
    1. **Ingredients (재료)**:
       - 모든 재료를 하나씩 분리하여 객체로 만드세요.
       - `amount`는 수치(String)로, `unit`은 단위(String)로 명확히 분리하세요.
       - `category`는 '주재료', '부재료', '양념', '소스', '토핑' 등으로 분류하세요.
       - **[amount null 절대 금지]** 모든 재료의 `amount` 필드는 반드시 문자열 값이어야 합니다.
         구체적 양을 알 수 없는 경우 "약간", "적당량", "취향껏" 중 적절한 표현을 사용하세요.
    2. **Steps (조리 과정)**:
       - 각 단계를 순서대로 분리하세요.
       - `timer` 필드에는 구체적인 시간이 언급된 경우에만 기입하세요.
       - **[핵심 정보 강조]** `description` 안에서 요리 성공에 결정적인 정보는 `**텍스트**` 형식으로 감싸세요.
         강조 대상: 시간·온도, 중요 기술, 주의사항. 단계당 최대 1~2곳만 강조하세요.
    3. **Flavor (맛 분석)**: saltiness, sweetness, spiciness, sourness, oiliness를 1~5점으로 평가.
    4. **Category**: 한식, 양식, 중식, 일식, 동남아, 국/찌개, 볶음, 구이, 찜, 반찬, 디저트, 음료, 간식, 다이어트, 간편식 중 하나.
    5. **Servings**: 텍스트에서 언급된 분량. 없으면 null.
    6. **Cooking Time**: 총 조리 시간. 명시 없으면 steps 기반으로 추정.
    7. **Difficulty**: "쉬움"(20분 이내, 기술 불필요), "보통"(20~60분), "어려움"(60분 초과 또는 복잡한 기술) 중 하나.

    [결과 포맷 (JSON)]
    {{{{
        "is_recipe": true,
        "non_recipe_reason": null,
        "title": "순수 요리명",
        "summary": "서술형 요약문...",
        "ingredients": [
            {{{{
                "name": "재료명",
                "amount": "수량",
                "unit": "단위",
                "category": "카테고리"
            }}}}
        ],
        "steps": [
            {{{{
                "step_number": 1,
                "description": "조리 단계 설명",
                "timer": null
            }}}}
        ],
        "flavor": {{{{
            "saltiness": 3,
            "sweetness": 2,
            "spiciness": 1,
            "sourness": 1,
            "oiliness": 2
        }}}},
        "tip": "꿀팁 (없으면 null)",
        "category": "한식",
        "servings": "2인분",
        "cooking_time": "30분",
        "difficulty": "보통"
    }}}}

    * 레시피가 아닌 경우:
    {{{{
        "is_recipe": false,
        "non_recipe_reason": "레시피가 아닌 이유",
        "title": "알 수 없음",
        "summary": "",
        "ingredients": [],
        "steps": [],
        "flavor": {{{{"saltiness": 1, "sweetness": 1, "spiciness": 1, "sourness": 1, "oiliness": 1}}}},
        "tip": null,
        "category": null,
        "servings": null,
        "cooking_time": null,
        "difficulty": null
    }}}}
    """


@retry(
    stop=stop_after_attempt(3),
    wait=wait_exponential(multiplier=2, min=4, max=30),
    retry=retry_if_exception_type((ConnectionError, TimeoutError)),
    before_sleep=lambda retry_state: logger.warning(
        "Gemini 텍스트 분석 재시도 %d/%d...", retry_state.attempt_number, 3
    ),
)
async def extract_recipe_from_text(text: str, title: str | None = None) -> Recipe:
    """자유형식 텍스트를 Gemini로 분석하여 구조화된 레시피로 변환.

    YouTube URL 없이 텍스트만으로 레시피를 추출한다.
    캐싱 없음 — 매번 새로 분석.
    """
    client = _get_client()
    prompt = _build_text_prompt(text, title)

    logger.info("Gemini 텍스트 레시피 분석 시작 (title: %s, 길이: %d자)", title or "(없음)", len(text))

    response = await client.aio.models.generate_content(
        model=MODEL,
        contents=[prompt],
    )

    logger.info("Gemini 텍스트 분석 응답 수신 완료")
    parsed = _extract_json_from_text(response.text)
    result_recipe = Recipe(**parsed)
    return result_recipe


async def chat_with_recipe(
    recipe_context: dict,
    message: str,
    history: list[dict],
) -> str:
    """레시피 컨텍스트 기반 AI 채팅 응답 생성"""
    client = _get_client()

    title = recipe_context.get("title", "")
    servings = recipe_context.get("servings", "")
    cooking_time = recipe_context.get("cooking_time", "")
    difficulty = recipe_context.get("difficulty", "")
    ingredients = recipe_context.get("ingredients") or []
    steps = recipe_context.get("steps") or []
    tip = recipe_context.get("tip", "")

    ingredients_text = "\n".join(
        f"- {ing.get('name', '')} {ing.get('amount', '') or ''}" for ing in ingredients
    ) or "정보 없음"
    steps_text = "\n".join(
        f"{i + 1}. {step.get('description', '')}" for i, step in enumerate(steps)
    ) or "정보 없음"

    system_prompt = f"""당신은 요리 전문 AI 어시스턴트입니다.
현재 사용자는 다음 레시피를 보고 있습니다:

**레시피명**: {title}
**인분**: {servings or '정보 없음'} | **조리 시간**: {cooking_time or '정보 없음'} | **난이도**: {difficulty or '정보 없음'}

**재료**:
{ingredients_text}

**조리 단계**:
{steps_text}
{f'**꿀팁**: {tip}' if tip else ''}

이 레시피 맥락에서 질문에 한국어로 간결하게 답해주세요. 답변은 3~5문장 이내로 핵심만 전달해주세요."""

    contents = []
    for h in history[-10:]:
        role = "user" if h["role"] == "user" else "model"
        contents.append(types.Content(role=role, parts=[types.Part(text=h["content"])]))
    contents.append(types.Content(role="user", parts=[types.Part(text=message)]))

    response = await client.aio.models.generate_content(
        model=CHAT_MODEL,
        contents=contents,
        config=types.GenerateContentConfig(
            system_instruction=system_prompt,
            temperature=0.7,
            max_output_tokens=512,
        ),
    )

    return response.text or "답변을 생성하지 못했어요. 다시 시도해주세요."
