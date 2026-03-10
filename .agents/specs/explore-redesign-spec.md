# 탐색 탭 리디자인 명세서

> 작성일: 2026-03-10
> 상태: 설계 확정 → 구현 대기

---

## 목표

현재 탐색 탭은 검색 + 카테고리 필터만 존재해 사용성이 낮음.
아래 3가지 기능을 추가하여 사용자가 레시피를 더 잘 발견하고 선택할 수 있도록 개선.

1. **필터 + 정렬** — 난이도/조리시간/칼로리 필터, 인기/최신/칼로리 정렬
2. **오늘 뭐먹지** — 랜덤 추천 진입점
3. **개인화 (1단계)** — 저장한 레시피 숨기기 토글

> 커뮤니티(작성자 검색, 팔로우 등)는 Phase 3 장기 플랜으로 보류.
> 취향 기반 추천(taste_profile)은 마이페이지 작업 이후 2단계로 연동.

---

## 화면 레이아웃

```
┌─────────────────────────────────────┐
│ [🔍 레시피 또는 재료 검색...] [⚙ 필터] │  ← 검색바 + 필터 버튼
├─────────────────────────────────────┤
│ [전체] [▶YouTube] [✏직접작성]        │  ← 출처 칩 (현재 유지)
│ [전체] [한식] [양식] [중식] ...       │  ← 카테고리 칩 (현재 유지)
├─────────────────────────────────────┤
│ ┌───────────────────────────────┐   │
│ │  🎲 오늘 뭐 먹지?             │   │  ← 오늘 뭐먹지 배너
│ │     [랜덤 추천받기]           │   │
│ └───────────────────────────────┘   │
├─────────────────────────────────────┤
│ [필터 적용 중 뱃지들] 인기순▼        │  ← 활성 필터 표시 + 정렬 (필터 적용 시만 노출)
├─────────────────────────────────────┤
│ [카드] [카드]                        │
│ [카드] [카드]                        │  ← 레시피 그리드 (현재 유지)
│ ...                                 │
└─────────────────────────────────────┘
```

---

## 기능 1: 필터 + 정렬

### UI — 필터 버튼 + 바텀시트

- 검색바 우측에 `⚙ 필터` 버튼 배치
- 필터가 1개 이상 적용 중이면 버튼에 뱃지 표시 (예: `⚙ 필터 3`)
- 버튼 클릭 시 바텀시트(BottomSheet) 슬라이드업

### 바텀시트 내용

```
┌──────────────────────────────┐
│ 필터 / 정렬            [초기화] │
├──────────────────────────────┤
│ 정렬                          │
│ ● 인기순  ○ 최신순  ○ 칼로리순 │
├──────────────────────────────┤
│ 난이도                        │
│ [전체] [쉬움] [보통] [어려움]  │
├──────────────────────────────┤
│ 조리시간                      │
│ [전체] [20분↓] [1시간↓] [1시간↑] │
├──────────────────────────────┤
│ 칼로리 (1인분 기준)            │
│ [전체] [500↓] [500~800] [800↑] │
├──────────────────────────────┤
│ (로그인 시만 표시)             │
│ 이미 저장한 레시피 숨기기 [토글] │
├──────────────────────────────┤
│        [적용하기]              │
└──────────────────────────────┘
```

### 활성 필터 표시

필터 1개 이상 적용 시 카테고리 칩 아래에 활성 필터 뱃지 + 현재 정렬 표시:
```
[쉬움 ✕] [20분↓ ✕] [저장 숨김 ✕]    인기순▼
```
- 뱃지 클릭 시 해당 필터만 해제
- 정렬 텍스트 클릭 시 바텀시트 재오픈

### 프론트엔드 상태

```typescript
interface FilterState {
  sort: 'popular' | 'latest' | 'calories';
  difficulty: '' | '쉬움' | '보통' | '어려움';
  cookingTime: '' | '20' | '60' | '61+';  // 분 기준
  calorieRange: '' | 'low' | 'mid' | 'high';  // 500↓ / 500~800 / 800↑
  hideCollected: boolean;  // 로그인 시만 유효
}
```

### 백엔드 변경 — search_public_recipes RPC

현재 파라미터: `search_q, p_category, p_sort, p_limit, p_offset, p_source`

추가 파라미터:
```sql
p_difficulty    TEXT    DEFAULT NULL,   -- '쉬움' | '보통' | '어려움'
p_max_time      INT     DEFAULT NULL,   -- 분 단위 (20, 60)
p_min_time      INT     DEFAULT NULL,   -- 61분 이상 필터용
p_min_calories  INT     DEFAULT NULL,
p_max_calories  INT     DEFAULT NULL,
p_user_id       UUID    DEFAULT NULL,   -- hideCollected 용
p_hide_collected BOOL   DEFAULT FALSE
```

정렬 옵션 추가:
- `'popular'` → `ORDER BY collection_count DESC`
- `'latest'` → `ORDER BY created_at DESC`
- `'calories'` → `ORDER BY calories ASC NULLS LAST`

조리시간 필터: `cooking_time_minutes INTEGER` 컬럼 신규 추가 (확정)
→ DB ALTER + AI 프롬프트 수정 + 기존 데이터 마이그레이션 필요
→ 기존 레코드: `cooking_time` TEXT에서 파싱하여 `cooking_time_minutes` 일괄 업데이트
→ 신규 분석 시: AI가 직접 정수(분)로 반환

> **DB 작업 목록 (사용자 승인 완료)**
> 1. `ALTER TABLE recipes ADD COLUMN cooking_time_minutes INTEGER;`
> 2. 기존 데이터 마이그레이션 UPDATE (TEXT → 분 단위 정수)
> 3. `search_public_recipes` RPC 수정

---

## 기능 2: 오늘 뭐먹지

### UI

탐색 탭 카테고리 칩 아래, 레시피 그리드 위에 배너 카드 배치:

```
┌─────────────────────────────────┐
│ 🎲  오늘 뭐 먹지?               │
│     기분에 맞는 레시피를 뽑아드려요  │
│              [랜덤 추천받기]    │
└─────────────────────────────────┘
```

- 버튼 클릭 → API 호출 → 결과 모달 표시

### 결과 모달

```
┌──────────────────────────────┐
│ 🎲 오늘의 추천                │
│                        [✕]   │
├──────────────────────────────┤
│ [썸네일 이미지]               │
│ 제목                          │
│ ⏱ 30분  · 보통  · 🔥 450kcal │
│ 채널명                        │
├──────────────────────────────┤
│  [다시 뽑기]  [내 레시피에 추가] │
└──────────────────────────────┘
```

- 로그인 상태: 내가 이미 저장한 레시피 제외하고 뽑기 (기본값)
- 비로그인: 전체 중 랜덤

### 백엔드 — GET /recipes/random

```
GET /recipes/random?exclude_collected=true
```

응답: `RecipePublicItem` 단건

구현: `SELECT * FROM recipes WHERE is_public=true ORDER BY RANDOM() LIMIT 1`
로그인 시 `AND id NOT IN (SELECT recipe_id FROM user_collections WHERE user_id=...)`

---

## 기능 3: 개인화 1단계 (저장 숨기기)

- 필터 바텀시트 내 "이미 저장한 레시피 숨기기" 토글 (로그인 시만 표시)
- 토글 ON 시 `hideCollected: true` → RPC에 `p_hide_collected=true, p_user_id=...` 전달
- 비로그인 상태에서 토글 시 로그인 모달 표시

> **취향 기반 추천 (개인화 2단계)** — 마이페이지 taste_profile 구현 이후 연동
> 구현 시 탐색 탭 상단에 "나를 위한 추천" 가로 스크롤 섹션 추가 예정

---

## 커뮤니티 (장기 보류)

> Phase 3 범위. 아래 항목은 설계만 메모.

- 직접 작성 레시피에 작성자 닉네임 표시 (users 테이블에 nickname 컬럼 필요)
- 작성자 이름으로 검색/필터
- 작성자 프로필 페이지 (`/user/[id]`)
- 팔로우 / 피드

DB 설계 필요:
```sql
ALTER TABLE users ADD COLUMN nickname TEXT;
ALTER TABLE users ADD COLUMN avatar_url TEXT;
CREATE TABLE follows (follower_id UUID, following_id UUID, created_at TIMESTAMPTZ);
```

---

## 구현 순서

### Phase 1 — 필터 + 정렬
1. `search_public_recipes` RPC 수정 (파라미터 추가)
2. `GET /recipes` 엔드포인트에 새 파라미터 연결
3. `FilterBottomSheet.svelte` 컴포넌트 신규 작성
4. `+page.svelte` 필터 상태 연결 + 활성 필터 뱃지 표시

### Phase 2 — 오늘 뭐먹지
1. `GET /recipes/random` 엔드포인트 추가
2. `api.ts`에 `getRandomRecipe()` 추가
3. 오늘 뭐먹지 배너 + 결과 모달 UI

### Phase 3 — 개인화 1단계
- Phase 1 필터 바텀시트에 "저장 숨기기" 토글 포함 (Phase 1과 동시 구현 가능)

---

## 미결 사항

- [x] `cooking_time_minutes` 컬럼 추가 — B안(정수 컬럼) 확정
- [x] 랜덤 추천 결과 — 모달 팝업 확정
- [x] 오늘 뭐먹지 배너 — 지금은 심플(텍스트+버튼), 추후 먹당 일러스트 추가 예정
- [ ] 필터 상태 저장 — localStorage(비로그인) / users.preferences JSONB(로그인, 기기 간 동기화)
