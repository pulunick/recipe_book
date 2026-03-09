# 해먹당 — 구현 기능 명세서 (Implemented Features)

현재 시스템에서 구현 완료된 핵심 기능. *최종 수정: 2026-03-05 (v0.5.0)*

---

## 1. 핵심 기능

### 1.1 AI 레시피 분석 (POST /extract-recipe)
- Gemini 2.5 Flash 유튜브 URL 직접 분석 (오디오 없이 URL만 전달)
- 구조화 출력: 재료(이름/수량/단위/카테고리), 조리 단계(타이머 포함), 맛 5축(짠/단/맵/신/기름), 꿀팁, 15개 카테고리 자동 분류
- `is_recipe` 플래그로 먹방·브이로그 자동 거절
- `video_id` 기반 캐싱 (동일 영상 재분석 방지)
- `force_refresh=true`로 강제 재분석 가능

### 1.2 Google OAuth 로그인
- Supabase Auth Google Provider 연동
- `signInWithOAuth` → `/auth/callback` → 페이지 이동
- 미인증 접근 시 로그인 모달 + 홈 redirect

### 1.3 백엔드 JWT 인증
- `/collections/*`, `/tags/*` 엔드포인트에 `Depends(get_current_user)` 적용
- `Authorization: Bearer <Supabase JWT>` 헤더 필수

### 1.4 개인 레시피북 (user_collections)
- 레시피 저장/삭제
- 커스텀 메모 (`custom_tip`)
- **레시피 편집 모드** (`recipe_override` JSONB): 재료/단계/꿀팁 인라인 수정, 수정 항목 강조, 원본 복원
- 즐겨찾기 (`is_favorite`)
- 별점 (`my_rating` 1-5)
- 요리 기록 (`cooked_count`, `last_cooked_at`), "단골 레시피 🏆" 뱃지
- 컬러 태그 시스템 (`collection_tags`, `collection_tag_items`)

### 1.5 공개 레시피 탐색 (GET /recipes)
- 전체 공개 레시피 목록 (인기순/최신순)
- 카테고리 필터, 제목+재료 검색 (`q` 파라미터)
- 페이지네이션 (`page`)
- 카테고리 목록 DB 동적 조회 (`GET /recipes/categories`)

---

## 2. UI/UX

- **바텀 네비게이션 5탭**: 탐색 / 내레시피 / [+] / 장바구니 / 마이
- **AddRecipeSheet**: + 버튼 → 바텀시트 [유튜브 URL 분석 / 직접 작성]
- **백그라운드 분석**: 분석 중 앱 탐색 가능, 완료 시 팝업 알림
- **RecipeCard**: 썸네일, 재료 미리보기 접기/펼치기, 즐겨찾기 버튼, 카테고리 뱃지
- **StepTimeline**: 클릭으로 완료 체크, 타이머 배지
- **IngredientList**: 체크박스, 체크 항목 하단 자동 이동
- **FlavorProfile**: 레이더 차트 (5축)
- **VideoCard**: 원본 영상 유튜브 썸네일 카드
- **ScrollToTop**: 300px 이상 스크롤 시 우측 하단 ↑ 버튼
- **Toast**: 작업 완료/오류 알림
- 브랜드 컬러: Terracotta, Cream, Soft Brown, Dusty Blue

---

## 3. 기술 스택

| 구분 | 기술 |
|------|------|
| Backend | Python 3.11, FastAPI |
| AI | Gemini 2.5 Flash (URL 직접 분석) |
| Media | yt-dlp (메타데이터), FFmpeg |
| Database | PostgreSQL (Supabase), JSONB |
| Frontend | SvelteKit 5, Svelte 5 Runes, TypeScript |
| Auth | Supabase Auth (Google OAuth) |
| Infrastructure | Docker Compose, Railway (백엔드), Vercel (프론트) |

---

## 4. 성능 최적화

- `collection_count` 컬럼 캐싱 + 트리거 자동 갱신 (인기순 집계 쿼리 제거)
- `pg_trgm` GIN 인덱스 (제목 ILIKE 검색 최적화)
- 목록 API: 카드에 필요한 컬럼만 fetch (steps/flavor 제외)
- 상세 페이지: `GET /collections/item/{id}` 단일 호출 (전체 컬렉션 재fetch 제거)
