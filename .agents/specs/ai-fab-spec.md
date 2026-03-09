# AI 어시스턴트 FAB 명세

> 작성일: 2026-03-09 | 상태: 설계 완료 (미구현)
> 구현 우선순위: Phase 2

---

## 1. 개요

`/my-recipes/[id]` 레시피 상세 페이지 전용 AI 채팅 플로팅 버튼.
현재 보고 있는 레시피를 컨텍스트로 삼아 Gemini에게 요리 관련 질문을 할 수 있는 인라인 어시스턴트.

### 핵심 use case
- 조리 단계 중 궁금한 것 즉시 질문 ("불 세기가 애매한데 어느 정도가 중불이야?")
- 재료 대체 ("돼지고기 없으면 뭐 써도 돼?")
- 단위 변환 ("1컵이 ml로 얼마야?")
- 분량 조절 ("4인분을 2인분으로 줄이면 간장은 얼마나?")
- 응용 팁 ("이 레시피에서 칼로리 낮추려면?")

---

## 2. UI/UX 명세

### 2.1 FAB 버튼
- 위치: 화면 우하단 고정 (`position: fixed; bottom: 88px; right: 16px`) — 바텀 네비(56px) + 여유(32px)
- 쿠킹 모드(`/cook`)에서는 바텀 네비 없으므로 `bottom: 24px`
- 크기: 56×56px, 원형
- 아이콘: `Sparkles` (lucide-svelte) 또는 chef hat 계열
- 색상: `var(--color-terracotta)` 배경 + white 아이콘
- 채팅 패널 열린 상태: X 아이콘으로 전환 (닫기)

### 2.2 채팅 패널
- **형태**: 화면 하단에서 슬라이드업하는 바텀시트 (모바일) 또는 FAB 위에 붙는 카드 패널 (width: 320px, 데스크탑)
- **높이**: 바텀시트 기준 60vh (스크롤 가능)
- **구성**:
  ```
  ┌────────────────────────────┐
  │  ✦ AI 요리 어시스턴트        │
  │  [레시피명] 기준으로 답해드려요 │
  ├────────────────────────────┤
  │  [메시지 목록 스크롤 영역]     │
  │  user: 돼지고기 대체재?       │
  │  AI: 닭가슴살이나 두부를...   │
  ├────────────────────────────┤
  │  [입력창          ] [전송]   │
  └────────────────────────────┘
  ```
- 패널 열릴 때 **추천 질문 칩** 3개 표시 (첫 대화 전에만):
  - "재료 대체 추천해줘"
  - "분량 반으로 줄이는 법"
  - "이 레시피 칼로리 어때?"

### 2.3 메시지 스타일
- 유저 메시지: 우측 정렬, `var(--color-terracotta)` 배경, white 텍스트
- AI 응답: 좌측 정렬, `var(--color-cream)` 배경, warm-brown 텍스트
- AI 응답 로딩 중: 점 세 개 애니메이션 (`...`)
- 타임스탬프: 생략 (불필요)
- 메시지 최대 너비: 80%

---

## 3. 기능 명세

### 3.1 컨텍스트 주입
AI에게 전달하는 레시피 컨텍스트 (시스템 프롬프트에 포함):
- 레시피 제목
- 재료 목록 (현재 표시 중인 것 — override 우선)
- 조리 단계 (현재 표시 중인 것 — override 우선)
- 꿀팁 (있으면)
- 인분, 조리 시간, 난이도

컨텍스트를 받아서 질문에 답하도록 시스템 프롬프트 설계:
```
당신은 요리 전문 AI 어시스턴트입니다.
현재 사용자는 다음 레시피를 보고 있습니다:
[레시피 정보]
이 레시피 맥락에서 질문에 한국어로 간결하게 답해주세요.
```

### 3.2 대화 범위
- **단일 세션 유지**: 페이지를 떠나면 초기화 (DB 저장 안 함)
- **대화 이력 전달**: 이전 메시지도 Gemini에 넘겨 문맥 유지 (최근 10턴 한도)
- **스트리밍**: Phase 2 초기엔 단순 응답(non-streaming), 이후 SSE 스트리밍 전환 고려

### 3.3 입력 제한
- 메시지 최대 길이: 300자
- 전송 조건: 빈 문자열 불가, AI 응답 대기 중 재전송 불가 (버튼 비활성화)
- Enter로 전송, Shift+Enter로 줄바꿈

---

## 4. 백엔드 API 설계

### 엔드포인트
```
POST /ai/chat
Authorization: Bearer <token>  (로그인 필요)
```

### 요청 바디
```json
{
  "collection_id": 42,
  "message": "돼지고기 대신 뭐 써도 돼?",
  "history": [
    {"role": "user", "content": "..."},
    {"role": "model", "content": "..."}
  ]
}
```
- `collection_id`: 레시피 컨텍스트 조회용 (백엔드에서 직접 DB 조회)
- `history`: 최근 최대 10턴 (클라이언트에서 관리, 서버로 전달)

### 응답 (non-streaming)
```json
{
  "reply": "닭가슴살이나 두부를 사용하시면 됩니다. 두부는..."
}
```

### 백엔드 처리 흐름
1. JWT 검증 → `user_id` 추출
2. `collection_id`로 user_collections + recipe JOIN 조회 (소유권 확인 포함)
3. 레시피 데이터 → 시스템 프롬프트 구성 (recipe_override 우선 적용)
4. `history` + 새 메시지 → Gemini `gemini-2.5-flash` text 호출
5. 응답 반환

### Rate Limiting
- 10회/분, 100회/일 per user
- 초과 시 429 + 한국어 메시지: "AI 질문 횟수를 초과했습니다. 잠시 후 다시 시도해주세요."

---

## 5. 프론트 컴포넌트 설계

### 파일
- `frontend/src/lib/components/AiAssistantFab.svelte`

### Props
```typescript
interface Props {
  collectionId: number;
  recipe: Recipe;            // 현재 표시 중인 레시피 (override 반영본)
  recipeOverride: RecipeOverride | null;
}
```

### 내부 상태
```typescript
let isOpen = $state(false);
let messages = $state<{ role: 'user' | 'ai'; content: string }[]>([]);
let inputText = $state('');
let isLoading = $state(false);
```

### API 함수 (`api.ts`에 추가)
```typescript
export async function chatWithAi(
  collectionId: number,
  message: string,
  history: { role: string; content: string }[]
): Promise<string>
```

### 마운트 조건
`/my-recipes/[id]/+page.svelte`에서만 렌더링:
```svelte
<AiAssistantFab
  collectionId={item.id}
  recipe={recipe}
  recipeOverride={item.recipe_override}
/>
```

---

## 6. 에러 처리

| 상황 | 처리 |
|------|------|
| 네트워크 오류 | 메시지 영역에 인라인 에러 표시 ("잠시 후 다시 시도해주세요") |
| Rate limit (429) | 서버 메시지 그대로 표시 |
| 401 Unauthorized | 로그인 안내 토스트 |
| 빈 응답 | "답변을 생성하지 못했어요. 다시 시도해주세요." |

---

## 7. 수익화 고려 (미래)

- AI FAB 채팅 자체는 Gemini 2.5 Flash 텍스트만 사용 → 비용 낮음
- 비용 핵심은 레시피 추출(YouTube 오디오 multimodal)
- **추천 수익 모델**: 구독제
  - 무료: 레시피 추출 월 N회 + AI FAB 월 M회
  - 프리미엄: 무제한 추출 + AI FAB 무제한
- **자연스러운 수익 연계**: 장바구니 "구매하러 가기" → 쿠팡/컬리 파트너스 링크 (추후)
- Rate limiting이 현재 남용 방지 역할을 겸하고 있어, 구독 도입 전까지는 현행 유지

---

## 8. 구현 순서 (나중에 작업할 때)

1. `backend/main.py` — `POST /ai/chat` 엔드포인트 추가
2. `frontend/src/lib/api.ts` — `chatWithAi()` 함수 추가
3. `frontend/src/lib/components/AiAssistantFab.svelte` — 컴포넌트 구현
4. `frontend/src/routes/my-recipes/[id]/+page.svelte` — FAB 마운트
5. (선택) 쿠킹 모드 `/cook`에도 FAB 추가
