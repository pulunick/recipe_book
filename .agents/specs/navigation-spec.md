# 네비게이션 및 레이아웃 UI 재구성 명세

> 작성일: 2026-03-05 | 최종 수정: 2026-03-10 | 상태: 확정 (Phase 1 구현 완료)

## 1. 전체 레이아웃 구조

### 1.1 Max-Width 제한
- 전체 앱을 `max-width: 480px`로 중앙 고정
- 데스크탑에서도 모바일 앱처럼 보이도록 함
- 적용 위치: `+layout.svelte`의 최상위 래퍼
- 배경: 좌우 여백은 `bg-gray-100` 또는 유사한 중립색

### 1.2 헤더 슬림화
- **기존**: 로고 + 검색바 + 여러 버튼
- **변경**: 로고(좌측) + 로그인/프로필 버튼(우측)만 표시
- 높이: ~48px (슬림)
- 로그인 상태: 프로필 아바타 아이콘 (클릭 시 `/my` 이동)
- 비로그인 상태: "로그인" 텍스트 버튼 (클릭 시 LoginModal 오픈)
- YouTube URL 입력은 헤더에서 제거 → [+] 탭의 바텀시트로 이동

## 2. 바텀 네비게이션 (BottomNav)

### 2.1 탭 구성

| 순서 | 아이콘 | 라벨 | 라우트 | 설명 |
|------|--------|------|--------|------|
| 1 | Compass/Home | 탐색 | `/` | 공개 레시피 탐색 (홈) |
| 2 | Book | 내레시피 | `/my-recipes` | 개인 레시피 서랍 |
| 3 | **[+]** (강조) | — | (바텀시트) | 레시피 추가 액션 |
| 4 | ShoppingCart | 장바구니 | `/cart` | 장바구니 |
| 5 | User | 마이 | `/my` | 마이페이지 |

### 2.2 컴포넌트 스펙: `BottomNav.svelte`
- 위치: `frontend/src/lib/components/BottomNav.svelte`
- 고정: 화면 하단 `position: fixed; bottom: 0`
- max-width: 부모와 동일하게 480px
- 높이: ~60px + safe-area-inset-bottom
- 활성 탭: 브랜드 컬러(`#FF6B35` 또는 기존 primary) 하이라이트
- 중앙 [+] 버튼: 원형, 살짝 위로 돌출, 배경색 primary

### 2.3 숨김 조건
- `/my-recipes/[id]/cook` (쿠킹 모드): BottomNav 완전 숨김
- 키보드 열림 시 (모바일): 숨김 처리 고려

### 2.4 비로그인 접근 처리

| 탭 | 비로그인 동작 |
|----|---------------|
| 탐색 | 자유 접근 (공개 레시피) |
| 내레시피 | LoginModal 표시 → 로그인 후 이동 |
| [+] | 바텀시트는 열림 → YouTube 분석은 비로그인도 가능 (결과는 `/recipe/[id]` 임시 페이지에 표시), 텍스트 작성은 로그인 필요 |
| 장바구니 | LoginModal 표시 |
| 마이 | LoginModal 표시 |

## 3. 레시피 추가 바텀시트 (AddRecipeSheet)

### 3.1 컴포넌트: `AddRecipeSheet.svelte`
- 위치: `frontend/src/lib/components/AddRecipeSheet.svelte`
- 트리거: BottomNav 중앙 [+] 버튼 탭
- UI: 하단에서 슬라이드업 하는 반투명 오버레이 + 시트

### 3.2 시트 내 옵션
1. **유튜브 URL 분석**
   - 아이콘: YouTube 로고/Play 아이콘
   - 설명: "유튜브 요리 영상 URL을 붙여넣으면 AI가 레시피를 추출합니다"
   - 탭 시: URL 입력 필드 표시 → 분석 시작
   - 비로그인 허용: 분석 결과는 `/recipe/[id]` 임시 페이지에 표시
   - 로그인 상태: 분석 완료 → 자동 저장 → `/my-recipes/[id]`로 이동

2. **텍스트로 직접 작성**
   - 아이콘: 연필/Edit 아이콘
   - 설명: "나만의 레시피를 직접 작성합니다"
   - 탭 시: 레시피 작성 폼으로 이동 (추후 구현)
   - 로그인 필수: 비로그인 시 LoginModal 표시

### 3.3 동작 흐름 (YouTube 분석)
1. [+] 탭 → 바텀시트 오픈
2. "유튜브 URL 분석" 선택
3. URL 입력 필드 표시 + "분석하기" 버튼
4. 분석 중: 로딩 애니메이션 (시트 내부)
5. 분석 완료:
   - 로그인 상태 → 자동 저장 → `/my-recipes/[id]` 이동
   - 비로그인 → `/recipe/[id]` 임시 결과 페이지 이동 (저장 안 됨, "로그인하면 저장됩니다" 안내)

## 4. AI 어시스턴트 FAB

### 4.1 표시 조건
- `/my-recipes/[id]` 레시피 상세 페이지에서만 표시
- 로그인 상태에서만 표시

### 4.2 컴포넌트: `AiAssistantFab.svelte`
- 위치: `frontend/src/lib/components/AiAssistantFab.svelte`
- UI: 화면 우하단 플로팅 버튼 (BottomNav 위)
- 아이콘: 스파클/별 모양 (AI 느낌)
- 크기: 56px 원형
- 색상: 그라디언트 또는 브랜드 보조색

### 4.3 기능 목록
FAB 탭 시 채팅 패널 슬라이드업:

1. **요리 질문 답변**: 해당 레시피에 대한 자유 질문
2. **재료 대체 제안**: "두부 대신 뭘 쓸 수 있을까?" 등
3. **단위 변환**: g ↔ 스푼, ml ↔ 컵 등 요리 단위 변환
4. **레시피 수정 연계**: AI 제안 → "적용하기" 버튼 → recipe_override에 반영

### 4.4 채팅 패널 스펙
- 하단 시트 형태 (높이: 화면 60~80%)
- 상단: 레시피 제목 + 닫기 버튼
- 중앙: 채팅 메시지 리스트 (AI 응답 + 사용자 입력)
- 하단: 텍스트 입력 + 전송 버튼
- 빠른 질문 칩: ["재료 대체", "단위 변환", "조리 팁"] (첫 화면에 표시)

### 4.5 백엔드 연동
- 엔드포인트: `POST /ai-assistant` (신규, 추후 구현)
- 요청: `{ recipe_id, message, conversation_history }`
- 응답: `{ reply, suggested_override? }`
- suggested_override가 있으면 "적용하기" 버튼 표시

## 5. 라우팅 구조

### 5.1 전체 라우트 맵

| 경로 | 페이지 | BottomNav | 설명 |
|------|--------|-----------|------|
| `/` | 탐색(홈) | 표시 | 공개 레시피 탐색 (hemogry 스타일) |
| `/my-recipes` | 내 레시피 | 표시 | 개인 레시피 서랍 (로그인 필요) |
| `/my-recipes/[id]` | 레시피 상세 | 표시 | 상세 보기 + 편집 모드 + AI FAB |
| `/my-recipes/[id]/cook` | 쿠킹 모드 | 숨김 | 전체 화면 쿠킹 UI |
| `/cart` | 장바구니 | 표시 | 장보기 목록 (로그인 필요) |
| `/my` | 마이페이지 | 표시 | 프로필, 설정 등 (로그인 필요) |
| `/recipe/[id]` | 임시 결과 | 표시 | 비로그인 분석 결과 보기 |
| `/auth/callback` | OAuth 콜백 | 숨김 | Supabase OAuth 처리 |

### 5.2 기존 라우트 변경사항
- `/` (홈): YouTube URL 입력 UI 제거 → 공개 레시피 탐색 페이지로 변경
- `/my-recipes`: 기존 유지 (바텀 네비에서 접근)
- `/my-recipes/[id]`: 기존 유지 + AI FAB 추가
- `/recipe/[id]`: 기존 유지 (비로그인 분석 결과용)

### 5.3 신규 라우트
- `/cart`: 장바구니 (Phase 2에서 구현)
- `/my`: 마이페이지 (Phase 2에서 구현)

## 6. 탐색(홈) 페이지 (`/`)

### 6.1 핵심 컨셉
- hemogry.com 스타일의 공개 레시피 탐색
- 카테고리별 필터링 + 검색
- 인기/최신 레시피 카드 그리드

### 6.2 UI 구성
1. **검색바**: 상단 고정, 레시피명/재료 검색
2. **카테고리 칩**: 한식, 중식, 일식, 양식, 간식, 음료 등
3. **레시피 카드 그리드**: 2열, 이미지 + 제목 + 조리시간 + 난이도
4. **무한 스크롤** 또는 페이지네이션

### 6.3 데이터 소스
- `recipes` 테이블에서 `is_public = true` 조건으로 조회
- (DB에 `is_public` 컬럼 추가 필요 — 별도 마이그레이션)

## 7. 구현 우선순위 (Phase)

### Phase 1 — 완료 (v0.6.0 기준)
- [x] 레이아웃 변경: max-width 480px + 헤더 슬림화
- [x] BottomNav 컴포넌트 구현 (5탭, `/[id]/cook`에서 숨김)
- [x] AddRecipeSheet 컴포넌트 구현 (YouTube 분석 / 텍스트 작성)
- [x] `/` 홈 페이지 탐색 페이지로 전환 (카테고리/검색/인기순, `my_collection_id` JOIN)
- [x] 비로그인 분석 결과 → `/recipe/[id]` 임시 결과 페이지 흐름
- [x] `/my-recipes` 내 레시피북 (필터/태그/즐겨찾기/검색)
- [x] `/my-recipes/[id]` 레시피 상세 (편집 모드, 별점, 요리기록, 장바구니, 태그, 메모, 재분석)
- [x] `/write` 텍스트 레시피 작성 (AI 구조화, 미리보기 편집, 공개/비공개)
- [x] `/cart` 장바구니 (레시피별 그룹, 체크/삭제/구매 버튼)
- [x] `checkCollection()` API — 탐색 탭에서 저장 여부 확인 후 버튼 상태 표시
- [x] `get_current_user_optional` — `/recipes` 비로그인 접근 허용
- [x] `IngredientList` `showCheckbox` prop — `/recipe/[id]`에서 체크박스 숨김
- [x] `StepTimeline` 마지막 연결선 제거
- [x] `/my-recipes/[id]` 상단 바 레이아웃 개선, 버튼 높이 통일

### Phase 2 — 진행 예정
- [ ] AI 어시스턴트 FAB + 채팅 패널 (`.agents/specs/ai-fab-spec.md` 참조)
  - `POST /ai/chat` 백엔드 → `chatWithAi()` api.ts → `AiAssistantFab.svelte`
- [ ] `/my` 마이페이지 — 통계 / 취향 프로파일
- [ ] 탐색 탭 고도화 — source 필터 칩 ("전체 | 유튜브 | 직접 작성")

### Phase 3 — 중장기
- [ ] 쿠킹 모드 (`/my-recipes/[id]/cook`, `.agents/specs/cooking-mode.md` 참조)
- [ ] 썸네일 기능 (Supabase Storage)
- [ ] 커뮤니티/공유 기능
