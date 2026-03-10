# 해먹당 업데이트 로그

---

## v0.6.0 — 2026-03-10

### 새 기능
- **중복 추가 방지**: 탐색/레시피 상세 모두 이미 저장한 레시피는 "내 레시피 보러가기 →" 버튼으로 전환
- **IngredientList `showCheckbox` prop**: `/recipe/[id]` 임시 결과 페이지에서 체크박스 숨김
- **즐겨찾기 버튼**: `/my-recipes/[id]` 레시피 카드 우상단에 별 버튼 (즉시 토글)
- **텍스트 레시피 작성자 직접 수정**: `PATCH /recipes/{id}` 로 recipes 테이블 직접 업데이트 (비작성자는 recipe_override 방식 유지)

### UX 개선
- **StepTimeline**: 마지막 단계 아래 연결선 제거 (`::after` 방식으로 변경)
- **ScrollToTop**: `bottom: calc(80px + safe-area)` 으로 올려 BottomNav/[+] 버튼과 겹침 해소
- **장바구니**: 체크 시 취소선 제거 (opacity 처리만), "체크 삭제" → "선택 삭제" 용어 통일, 하단 여백 확보
- **장바구니 구매 버튼**: "선택만 구매" + "전체 구매" 두 버튼 분리, 높이 통일
- **/my-recipes/[id] 상단 바**: 패딩 축소, 저장 날짜/버튼 세로 분리, 삭제 버튼 정렬 개선
- **버튼 높이 통일**: "오늘 요리했어요" + "재료 담기" 버튼 `height: 34px` 통일
- **검색창 height 고정**: `height: 44px` 고정으로 입력 시 늘어나는 현상 방지
- **헤더 아바타 정렬**: `display: flex` 추가로 세로 중앙 정렬

### 백엔드
- `GET /collections/check/{recipe_id}`: 이미 저장 여부 확인 신규 엔드포인트
- `get_current_user_optional`: 비로그인도 `/recipes` 접근 가능 (로그인 시 `my_collection_id` 반환)
- `GET /recipes` 응답에 `my_collection_id` JOIN 추가

---

## v0.5.0 — 2026-03-05

### 새 기능
- **바텀 네비게이션 5탭**: 탐색 / 내레시피 / [+] / 장바구니 / 마이 구조
- **백그라운드 분석**: 유튜브 분석 중에도 앱 탐색 가능, 완료 시 팝업 알림
- **레시피 추가 시트**: + 버튼 → 바텀시트 [유튜브 URL 분석 / 직접 작성] 선택
- **탐색 카테고리 DB 연동**: 하드코딩 제거, 실제 분석된 카테고리 동적 로드
- **제목 + 재료 검색**: 탐색/내레시피 모두 제목과 재료명 동시 검색 지원

### 성능 개선
- **상세 페이지 로딩 대폭 개선**: 전체 컬렉션 재fetch → 단일 아이템 API(`GET /collections/item/{id}`) 호출로 변경
- **목록 API 응답 크기 감소**: `recipe:recipes(*)` → 카드에 필요한 컬럼만 선택 (steps/flavor 제외)
- **DB 인덱스 추가**: pg_trgm GIN 인덱스(ILIKE 검색), collection_count 인덱스

### 백엔드
- `GET /collections/item/{id}`: 단일 컬렉션 상세 API (full recipe 포함)
- `GET /recipes`: q(검색), category(필터), page(페이지네이션) 파라미터 추가 — 이전엔 파라미터 무시됨
- `GET /recipes/categories`: DB RPC 기반 카테고리 목록 (실제 사용 카테고리 빈도순)
- slowapi rate limiting 완전 제거

### DB
- `recipes.collection_count INTEGER` 컬럼 추가
- `trg_collection_count` 트리거: user_collections INSERT/DELETE 시 collection_count 자동 갱신
- `get_public_recipes_by_popularity` RPC: JOIN 집계 → collection_count 직접 정렬로 교체
- `idx_recipes_title_trgm` (GIN pg_trgm), `idx_recipes_collection_count` 인덱스 추가

---

## v0.4.0 — 2026-03-04

### 새 기능
- **원본 영상 카드**: 레시피 페이지 하단의 "원본 영상 보기 →" 텍스트 링크가 유튜브 썸네일을 활용한 카드로 교체됨
- **재료 미리보기**: 레시피 목록 카드에서 "재료 N개" 버튼으로 재료 목록을 접고 펼 수 있음
- **맨 위로 버튼**: 레시피 상세 페이지에서 스크롤을 300px 이상 내리면 우측 하단에 "↑" 버튼 표시

### 개선
- **태그 삭제**: 레시피 목록의 태그 뱃지에서 직접 × 버튼으로 태그 제거 가능
- **별점 표시 전용**: 레시피 목록 카드의 별점은 보기 전용으로 변경

### 버그 수정
- **태그 팝오버 클리핑** 수정
- **태그 팝오버 방향** 수정 (위→아래)
- **AI 재료 양 표현**: 조미료 양 null → "약간", "1작은술" 등으로 표시

---

## v0.3.0 — 2026-02-xx

### 새 기능
- **레시피 편집 모드**: recipe_override JSONB, 재료/단계/꿀팁 인라인 수정, 수정 항목 강조
- **Google OAuth 로그인**: Supabase Auth 연동, /auth/callback 라우트
- **백엔드 JWT 인증**: 모든 /collections/*, /tags/* 엔드포인트에 인증 적용
- **태그 시스템**: 컬러 태그 생성 및 부착, 태그별 필터링
- **별점 & 요리 횟수**: 별점 1~5점, "오늘 요리했어요 🍳" 버튼
- **즐겨찾기**: 레시피 카드 썸네일 ⭐ 버튼
- **단골 레시피 뱃지**: 요리 횟수 3회 이상 시 "단골 레시피 🏆"
- **카테고리 자동 분류**: AI가 15개 카테고리로 자동 분류

---

## v0.2.0 — 2026-01-xx

### 새 기능
- **내 레시피북**: 저장한 레시피 목록 페이지 (`/my-recipes`)
- **레시피 상세**: 저장된 레시피 상세 페이지 (`/my-recipes/[id]`)
- **맛 프로필 차트**: 짠맛/단맛/매운맛/신맛/기름짐 5가지 축

---

## v0.1.0 — 2025-12-xx

- **최초 출시**: 유튜브 URL 입력 → Gemini AI 분석 → 재료/조리법 정리
- Gemini 2.5 Flash 유튜브 URL 직접 분석 방식 (봇 차단 해결)
- Supabase 캐싱 (동일 영상 재분석 방지)
