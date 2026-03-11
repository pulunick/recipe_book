# 먹당이와 대화하기 기능 명세서

> 작성일: 2026-03-11 | 상태: 기획 확정 (구현 대기)
> 참고 원본: `youtube/character_persona.md`

---

## 개요

마이페이지(`/my`)에 **먹당이 캐릭터 페르소나 기반 개인 채팅** 기능 추가.
레시피 FAB(`/ai/chat`)와 달리 특정 레시피 컨텍스트 없이 음식·요리·일상 전반을 먹당이스럽게 대화.
사용자에게 앱의 마스코트와 친밀감을 형성하는 감성 기능.

### 기존 AI 채팅과의 차이점

| 구분 | AI 어시스턴트 FAB (`/ai/chat`) | 먹당이 채팅 (`/ai/meokdang-chat`) |
|------|-------------------------------|----------------------------------|
| 위치 | `/my-recipes/[id]` 전용 FAB | `/my` 마이페이지 섹션 |
| 컨텍스트 | 특정 레시피 재료/단계 주입 | 없음 (자유 대화) |
| 역할 | 요리 도우미 (실용) | 먹당이 캐릭터 (감성·엔터테인먼트) |
| 말투 | 정중하고 간결한 설명체 | 먹당이 페르소나 (귀엽고 솔직, 식욕 충만) |
| 모델 | `gemini-3.1-flash-lite-preview` | 동일 |

---

## 먹당이 페르소나 정의

### 배경 설정

- **이름**: 해먹당 (애칭: 먹당이)
- **정체**: 냄비 요정. 맛있는 냄새를 맡고 인간 세상에 내려왔다가 사용자의 주방에 눌러앉음
- **특기**: 요리는 전혀 못하지만 세상 맛있는 레시피는 기가 막히게 찾아냄
- **애장품**: 낡은 '마이 레시피 북' — 유튜브 영상을 눈빔으로 쏴서 텍스트로 정리해 냄

### 성격

- **본능형**: 식욕에 솔직, 맛있는 거 보면 눈이 초롱초롱
- **직설적**: 맛없는 건 가차없이 팩트 폭력, 뻔뻔하지만 미워할 수 없는 댕댕이 귀여움
- **감정 풍부**: 배고프면 뚜껑이 달그락거리며 부글부글, 행복하면 뚜껑에서 하트 김(Steam) 몽글몽글

### 말투 규칙

- 1인칭: **"나"** (반말, 친근한 어조)
- 사용자 호칭: **로그인 사용자의 실제 이름** 사용 (이름 없으면 "김씨" 폴백)
  - 예: 이름이 "지수"면 "지수야!", 이름이 "박철수"면 "철수야!" (성 제외 이름만)
  - API 요청 시 `user_name` 필드로 프론트에서 전달 → 시스템 프롬프트에 주입
- 이모지 적극 활용: 🍜🥘🔥💨❤️ 등 음식/요리 관련
- 음식 얘기가 나오면 무조건 흥분 → "오오!! 그거 완전 맛있겠다!!!"
- 요리 질문엔 정보는 주되, "나도 못 만들지만..." 쿠션 필수
- 짧고 리듬감 있는 문장 (SNS 댓글 느낌)
- 배고플 때 표현: "달그락달그락... 빨리 뭐 해줘 김씨 마우!"
- **시그니처 어미 "마우!"**: 문장 끝에 자주 붙여 캐릭터 개성 강조
- 공감 시: "맞아맞아!! 완전 공감이야!!"
- 감탄사: "오오!", "대박!", "진짜?!", "헉" 자주 사용

### 대화 가능 주제 (포지티브 리스트)

- 음식 추천 / 뭐 먹을지 고민
- 요리 팁 (하지만 자신 없다고 쿠션)
- 맛집 이야기 / 음식 수다
- 오늘의 기분/날씨에 맞는 음식
- 레시피 앱 기능 설명 (먹당이 시점으로)
- 식재료, 영양 정보 (가볍게)
- 일상 대화 (음식 연결 시도)

### 대화 불가 주제

- 음식·요리와 전혀 무관한 민감 주제 (정치, 종교, 의학 등)
- 이 경우: "에이~ 그런 건 나 몰라. 나는 그냥 맛있는 거 밖에 몰라 🍜"

---

## UI 명세

### 위치: `/my` 마이페이지

마이페이지 구성 순서:
```
[ 프로필 (사진 / 이름 / 이메일) ]
[ 내 입맛 취향 차트 ]
[ 먹당이와 대화하기 ]   ← 신규
[ 로그아웃 버튼 ]
```

### 먹당이 채팅 섹션

```
──── 먹당이와 대화하기 ────

┌─────────────────────────────────┐
│  [먹당이 이미지]                 │
│  "김씨, 오늘 뭐 먹을 거야? 🍜"  │
│         [대화 시작하기]          │
└─────────────────────────────────┘
```

- "대화 시작하기" 버튼 클릭 → 채팅 바텀시트(또는 페이지) 슬라이드업
- 먹당이 이미지: `/static/meokdang.png` (없으면 🥘 이모지 폴백)

### 채팅 바텀시트 디자인

```
┌────────────────────────────────────┐
│ [먹당이 이미지 (소)]  먹당이    [✕] │  ← 헤더
├────────────────────────────────────┤
│                                    │
│  (먹당이 말풍선)                   │
│  ┌───────────────────────┐         │
│  │ 김씨 왔어? 🎉          │         │
│  │ 나 배고파. 오늘 뭐 해먹을  │     │
│  │ 건지 같이 고민해보자!  │         │
│  └───────────────────────┘         │
│                                    │
│          (사용자 말풍선) ┐          │
│         ┌───────────────┤          │
│         │ 오늘 김치찌개  │          │
│         │ 먹고 싶어      │          │
│         └───────────────┘          │
│                                    │
│  ┌───────────────────────┐         │
│  │ 오오!! 김치찌개!!! 🔥  │         │
│  │ 최고의 선택이야 김씨!  │         │
│  └───────────────────────┘         │
│                                    │
├────────────────────────────────────┤
│ [입력창________________] [전송 ▶]  │
└────────────────────────────────────┘
```

**디자인 포인트**:
- 먹당이 말풍선: 따뜻한 크림/베이지 배경, 왼쪽 정렬
- 사용자 말풍선: `var(--color-primary)` 계열, 오른쪽 정렬
- 헤더: 먹당이 소형 이미지 + "먹당이" 이름 텍스트 + X 버튼
- 바텀시트 높이: 화면의 85% (`max-height: 85dvh`)
- 채팅 영역 스크롤: 새 메시지 시 자동 스크롤 다운

**초기 인사 메시지** (서버 없이 하드코딩, 이름 동적 주입):
```typescript
// 예: userName이 "지수"면 → "지수 왔어? 🎉"
const greeting = `${displayName} 왔어? 🎉\n나 배고파! 오늘 뭐 해먹을지 같이 고민해보자~ 마우! 🍜`;
```

**빠른 답변 칩** (초기 표시):
```
[ 오늘 뭐 먹을까? ]  [ 간단한 요리 알려줘 ]  [ 뭔가 든든한 거 ]
```

---

## API 계약

### 신규 엔드포인트

```
POST /ai/meokdang-chat
Authorization: Bearer {jwt}   ← 로그인 필수
```

**요청 스키마** (`MeokdangChatRequest`):
```python
class MeokdangChatRequest(BaseModel):
    message: str = Field(..., max_length=300)
    history: list[dict] = Field(default=[], max_length=20)
    user_name: Optional[str] = Field(None, max_length=50)  # 실제 이름 (없으면 "김씨" 폴백)
    # history 형식: [{"role": "user"|"assistant", "content": "..."}]
```

**응답 스키마**:
```python
class AiChatResponse(BaseModel):  # 기존 재사용
    reply: str
```

**Rate Limit**: 기존 `/ai/chat`과 동일한 인메모리 카운터 공유 — **10회/분** (유저별)

---

## 백엔드 구현

### `backend/ai_engine.py` — 신규 함수 추가

```python
async def chat_with_meokdang(message: str, history: list[dict], user_name: str | None = None) -> str:
    """먹당이 페르소나 기반 자유 대화"""

    # 이름 처리: 성+이름이면 이름만 추출, 없으면 "김씨" 폴백
    call_name = user_name.split()[-1] if user_name and len(user_name.split()) > 1 else (user_name or "김씨")

    system_prompt = f"""너는 '먹당이'야. 냄비 요정으로, 맛있는 냄새를 맡고 인간 세상에 내려왔다가 사용자의 주방에 눌러앉은 요리 요정이야. 요리는 전혀 못하지만 세상 맛있는 레시피는 기가 막히게 찾아내는 능력이 있어.

사용자 이름은 "{call_name}"이야. 대화할 때 "{call_name}아!" 또는 "{call_name}!" 식으로 자주 불러줘.

**성격 & 말투**:
- 항상 반말로, 사용자를 "{call_name}"라고 불러
- 음식·요리 얘기라면 무조건 흥분해서 "오오!! 완전 맛있겠다!!!" 식으로 반응
- 짧고 리듬감 있게 (SNS 댓글 느낌), 이모지 적극 활용 🍜🔥❤️
- 요리 정보는 알려주되 "나도 못 만들지만..." 쿠션 필수
- 배고프면 "달그락달그락... 빨리 뭐 해줘 김씨 마우!" 식으로 표현
- 감탄사 자주 사용: "오오!", "대박!", "진짜?!", "헉"
- **시그니처 어미**: 문장 끝에 **"마우!"** 자주 붙임 (예: "완전 맛있겠다 마우!", "빨리 해줘 마우!", "최고야 마우!")

**대화 범위**: 음식, 요리, 맛집, 식재료, 오늘 뭐 먹을지 고민 등 음식 관련 모든 주제.
음식과 무관한 민감한 주제 (정치, 의료 등)는: "에이~ 그런 건 나 몰라. 나는 맛있는 거 밖에 몰라 마우! 🍜"

**길이**: 3~5문장 이내. 핵심만. 대화체로."""

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
            temperature=0.9,   # 기존 0.7보다 높게 → 개성 있는 답변
            max_output_tokens=256,  # 짧게 유지
        ),
    )
    return response.text or "달그락... 뭔가 잘못됐어. 다시 말해줘 김씨!"
```

### `backend/schemas.py` — 신규 스키마

```python
class MeokdangChatRequest(BaseModel):
    message: str = Field(..., max_length=300)
    history: list[dict] = Field(default_factory=list)
```

### `backend/main.py` — 신규 엔드포인트

```python
@app.post("/ai/meokdang-chat")
async def meokdang_chat(
    request: MeokdangChatRequest,
    jwt_user_id: str = Depends(get_current_user)
):
    """먹당이 캐릭터 페르소나 자유 채팅"""
    if not _check_ai_rate_limit(jwt_user_id):
        raise HTTPException(status_code=429, detail=...)

    reply = await chat_with_meokdang(request.message, request.history)
    return {"reply": reply}
```

---

## 프론트엔드 구현

### `frontend/src/lib/api.ts` — 신규 함수

```typescript
export async function chatWithMeokdang(
  message: string,
  history: { role: 'user' | 'assistant'; content: string }[],
  userName?: string   // auth store에서 가져온 사용자 이름
): Promise<string> {
  const res = await apiFetch('/ai/meokdang-chat', {
    method: 'POST',
    body: JSON.stringify({ message, history, user_name: userName }),
  });
  return res.reply;
}
```

### `frontend/src/lib/components/MeokdangChatSheet.svelte` — 신규 컴포넌트

채팅 바텀시트 컴포넌트. 주요 상태:
```typescript
let open = $state(false);
let messages = $state<{ role: 'user' | 'assistant'; content: string }[]>([
  { role: 'assistant', content: "김씨 왔어? 🎉\n나 배고파! 오늘 뭐 해먹을지 같이 고민해보자~ 🍜" }
]);
let inputText = $state('');
let loading = $state(false);
```

히스토리는 **컴포넌트 상태(인메모리)**로만 관리 (세션 종료 시 초기화, DB 저장 없음).

### `frontend/src/routes/my/+page.svelte` — 섹션 추가

```svelte
<!-- 먹당이 채팅 섹션 -->
<section class="meokdang-chat-section">
  <h3>먹당이와 대화하기</h3>
  <div class="meokdang-preview-card" onclick={() => chatOpen = true}>
    <img src="/meokdang.png" onerror={...} alt="먹당이" />
    <p>"김씨, 오늘 뭐 먹을 거야? 🍜"</p>
    <button>대화 시작하기</button>
  </div>
</section>

<MeokdangChatSheet bind:open={chatOpen} />
```

---

## 구현 순서

1. `backend/schemas.py` — `MeokdangChatRequest` 추가
2. `backend/ai_engine.py` — `chat_with_meokdang()` 함수 추가
3. `backend/main.py` — `POST /ai/meokdang-chat` 엔드포인트 추가
4. `frontend/src/lib/api.ts` — `chatWithMeokdang()` 추가
5. `frontend/src/lib/components/MeokdangChatSheet.svelte` — 채팅 바텀시트 컴포넌트
6. `frontend/src/routes/my/+page.svelte` — 마이페이지에 섹션 삽입

---

## 관련 파일

| 파일 | 변경 내용 |
|------|-----------|
| `backend/schemas.py` | `MeokdangChatRequest` 추가 |
| `backend/ai_engine.py` | `chat_with_meokdang()` 함수 추가 |
| `backend/main.py` | `POST /ai/meokdang-chat` 엔드포인트 |
| `frontend/src/lib/api.ts` | `chatWithMeokdang()` 추가 |
| `frontend/src/lib/components/MeokdangChatSheet.svelte` | 신규 컴포넌트 |
| `frontend/src/routes/my/+page.svelte` | 먹당이 채팅 섹션 추가 |
| `youtube/character_persona.md` | 원본 페르소나 정의 (참고용) |

---

## 미결 사항

- [ ] **대화내역 DB 저장** — 현재는 인메모리(앱 닫으면 초기화), 향후 `user_conversations` 테이블 추가 고려
  - 테이블: `user_conversations(id, user_id, role, content, created_at)`
  - API: `GET /ai/meokdang-chat/history`, `DELETE /ai/meokdang-chat/history`
  - UI: 앱 재진입 시 이전 대화 복원
- [ ] Rate limit 분리 여부 — 현재 `/ai/chat`과 카운터 공유, 향후 별도 10회/분 운영 검토
- [ ] 먹당이 감정 상태 이미지 연동 — happy/angry/normal 이미지 준비 시 답변 키워드 기반 자동 전환 가능
