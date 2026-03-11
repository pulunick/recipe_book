# 해먹당 v0.7.0 기능 기획 명세서

> 작성일: 2026-03-10 | 작성자: Planner | 상태: 기획 확정 (구현 대기)

---

## 전체 우선순위

| 순위 | 기능 | 난이도 | Sprint |
|------|------|--------|--------|
| **1위** | 레시피 분화 (source 구분 표시) | 쉬움 | A |
| **2위** | 칼로리 정보 | 쉬움 | A |
| **3위** | 입맛 분석 차트 (마이페이지) | 보통 | B |
| **4위** | 냉장고 파먹기 | 어려움 | C |

---

## 기능 1. 레시피 분화 (source 구분 표시)

> 난이도: 쉬움 | DB 변경: 없음 | Sprint A

### 개요
`recipes.source` 컬럼('youtube' / 'text')이 이미 존재. 프론트 조건부 렌더링 + API 파라미터 추가만으로 구현 가능.

### DB 변경사항
없음. `recipes.source VARCHAR` 컬럼 기존 존재.

단, `search_public_recipes` RPC 함수에 `p_source` 파라미터 추가:
```sql
CREATE OR REPLACE FUNCTION search_public_recipes(
  search_q TEXT,
  p_category TEXT DEFAULT '',
  p_sort TEXT DEFAULT 'latest',
  p_limit INT DEFAULT 20,
  p_offset INT DEFAULT 0,
  p_source TEXT DEFAULT ''   -- 신규: 'youtube' | 'text' | ''(전체)
)
-- 내부 WHERE 조건 추가:
-- AND (p_source = '' OR source = p_source)
```

### API 계약
**`GET /recipes`** — `source` 쿼리 파라미터 추가 (선택):
```
GET /recipes?source=youtube
GET /recipes?source=text
```

**`GET /collections/{user_id}`** — `source` 파라미터 추가 (Python 레벨 필터):
```
GET /collections/{user_id}?source=youtube
```

**`RecipePublicItem` 스키마** — `source: Optional[str] = None` 필드 추가 필요.

### UI 명세

**source 뱃지 디자인**:
| source | 텍스트 | 아이콘 | 색상 |
|--------|--------|--------|------|
| `youtube` | YouTube | ▶ | 빨간 배경 15% |
| `text` | 직접 작성 | ✏ | terracotta 배경 15% |

**적용 위치**:
1. 내 레시피 카드 — 채널명 앞 아이콘 또는 "직접 작성" 뱃지
2. 내 레시피 필터 칩 (`/my-recipes`): `[ 전체 ] [ ▶ YouTube ] [ ✏ 직접 작성 ]`
3. 탐색 탭 필터 칩 (`/`): 동일 패턴
4. 레시피 상세 (`/my-recipes/[id]`): 직접 작성 레시피에 "✏ 내가 직접 작성한 레시피" 표시

---

## 기능 2. 칼로리 정보

> 난이도: 쉬움 | DB 변경: 컬럼 1개 | Sprint A

### 개요
AI 분석 시 Gemini가 재료 목록으로 1인분 칼로리를 추정. AI 추정치임을 명시하여 표시.

### DB 변경사항
```sql
ALTER TABLE recipes
  ADD COLUMN IF NOT EXISTS calories_kcal INTEGER;

COMMENT ON COLUMN recipes.calories_kcal
  IS '1인분 기준 추정 칼로리 (kcal). AI 추정치, NULL 허용';
```

### API 계약
**`schemas.py` Recipe 모델** 필드 추가:
```python
calories_kcal: Optional[int] = Field(None, description="1인분 기준 추정 칼로리 (kcal)")
```

**AI 프롬프트 추가 지침** (`ai_engine.py`):
```
"calories_kcal": 완성된 요리의 1인분 기준 칼로리를 정수(kcal)로 추정.
재료 종류·분량·조리법 종합. 불확실한 경우 보수적으로 추정. 반드시 정수.
```

JSON 응답 포맷:
```json
{ "calories_kcal": 420 }
```

기존 `GET /collections/item/{id}` 응답에 자동 포함 (recipes.* 조회).

### UI 명세
**위치**: `/my-recipes/[id]` — 맛 프로파일 섹션 직전

**디자인**:
```
[ 🔥 약 420 kcal  (1인분 기준 · AI 추정) ]
```
- 크림색 칩, `font-size: 0.85rem`, `color: var(--color-warm-brown)`
- NULL이면 표시 안 함 (구버전 레시피 대응)
- 편집 모드에서 숫자 직접 수정 가능

---

## 기능 3. 입맛 분석 차트 (마이페이지)

> 난이도: 보통 | DB 변경: 없음 | Sprint B

### 개요
즐겨찾기(`is_favorite`) + 별점(`my_rating`) + 요리횟수(`cooked_count`) 가중치로 FlavorProfile 5축 평균 산출.

**가중치 공식**:
```
가중치 = (my_rating * 2) + (is_favorite * 3) + (cooked_count * 1)
취향 점수(축별) = Σ(flavor[축] * 가중치) / Σ(가중치)
최소 데이터: 컬렉션 3개 이상 (미만 시 안내)
```

### DB 변경사항
없음. 백엔드 API 집계 쿼리로 처리.

### API 계약
**신규 엔드포인트**:
```
GET /my/taste-profile
Authorization: Bearer {jwt}
```

**응답 스키마** (`TasteProfileResponse`):
```python
class TasteProfileResponse(BaseModel):
    has_data: bool
    recipe_count: int
    profile: Optional[dict]   # {saltiness, sweetness, spiciness, sourness, oiliness} float
    top_category: Optional[str]
    favorite_count: int
    total_cooked: int
    avg_rating: Optional[float]
```

**응답 예시**:
```json
{
  "has_data": true,
  "recipe_count": 12,
  "profile": { "saltiness": 3.8, "sweetness": 2.1, "spiciness": 4.2, "sourness": 1.5, "oiliness": 3.0 },
  "top_category": "한식",
  "favorite_count": 4,
  "total_cooked": 23,
  "avg_rating": 3.7
}
```

### UI 명세
**위치**: `/my` 마이페이지

```
[ 프로필 사진 | 이름 | 이메일 ]

──── 내 입맛 취향 ────
[ FlavorProfile 차트 (float 지원) ]
  짠맛  ████████░░  3.8
  단맛  ████░░░░░░  2.1
  ...

[ 통계 칩 3종 ]
  즐겨찾기 4개  |  총 요리 23회  |  평균 별점 ★3.7

──── 자주 만드는 카테고리 ────
  1위: 한식  2위: 국/찌개  3위: 볶음

[ 로그아웃 버튼 ]
```

**데이터 부족 시**: "레시피를 3개 이상 저장하고 별점/즐겨찾기를 남기면 취향 분석이 시작됩니다." 안내 카드.

---

## 기능 4. 냉장고 파먹기

> 난이도: 어려움 | DB 변경: RPC 함수 1개 | Sprint C

### 개요
보유 재료 입력 → PostgreSQL RPC로 `ingredients` JSONB 매칭 → 만들 수 있는 레시피 목록 반환.

### DB 변경사항
```sql
CREATE OR REPLACE FUNCTION search_recipes_by_ingredients(
  p_ingredients TEXT[],
  p_limit INT DEFAULT 10,
  p_public_only BOOLEAN DEFAULT TRUE
)
RETURNS TABLE (
  id BIGINT, title TEXT, category TEXT, cooking_time VARCHAR,
  difficulty VARCHAR, servings VARCHAR, video_id TEXT,
  channel_name TEXT, source VARCHAR, collection_count INT,
  match_score NUMERIC, matched_ingredients TEXT[]
)
LANGUAGE plpgsql STABLE AS $$
BEGIN
  RETURN QUERY
  WITH ingredient_match AS (
    SELECT r.id, r.title, r.category, r.cooking_time, r.difficulty,
           r.servings, r.video_id, r.channel_name, r.source, r.collection_count,
           ARRAY(
             SELECT elem->>'name'
             FROM jsonb_array_elements(r.ingredients) AS elem
             WHERE EXISTS (
               SELECT 1 FROM unnest(p_ingredients) AS inp
               WHERE LENGTH(inp) >= 2
                 AND ((elem->>'name') ILIKE '%' || inp || '%'
                      OR inp ILIKE '%' || (elem->>'name') || '%')
             )
           ) AS matched_names,
           jsonb_array_length(r.ingredients) AS total_count
    FROM recipes r
    WHERE (p_public_only = FALSE OR r.is_public = TRUE)
      AND r.ingredients IS NOT NULL
      AND jsonb_array_length(r.ingredients) > 0
  ),
  scored AS (
    SELECT im.*,
           ROUND(
             CASE WHEN im.total_count = 0 THEN 0
             ELSE (array_length(im.matched_names, 1)::NUMERIC / im.total_count) * 100
             END, 1
           ) AS match_score
    FROM ingredient_match im
    WHERE array_length(im.matched_names, 1) > 0
  )
  SELECT s.id, s.title, s.category, s.cooking_time, s.difficulty,
         s.servings, s.video_id, s.channel_name, s.source,
         s.collection_count, s.match_score, s.matched_names
  FROM scored s
  WHERE s.match_score >= 30
  ORDER BY s.match_score DESC, s.collection_count DESC
  LIMIT p_limit;
END;
$$;
```

### API 계약
```
POST /recipes/fridge-search
Authorization: 선택 (비로그인도 공개 레시피 검색 가능)
```

**요청**:
```json
{ "ingredients": ["김치", "돼지고기", "두부"], "limit": 10 }
```

**응답**: `FridgeSearchResultItem[]` (match_score, matched_ingredients 포함)

### UI 명세
**진입점**: 탐색(`/`) 탭 내 별도 배치 예정 — **바텀시트 아닌 다른 UI 방식 검토 필요** (미결)
> ❗ 탐색 탭 바텀시트 배치 방식은 기각. 별도 라우트(`/fridge`) 또는 독립 섹션으로 배치 방향 검토.

**재료 입력 → 결과 목록** 플로우:
1. 재료 입력 (칩 태그 형태, 최대 15개, Enter로 추가)
2. 추천 재료 칩: 김치, 돼지고기, 두부, 계란, 양파, 파, 마늘, 간장
3. 결과 카드: 기존 RecipePublicItem + 매칭 점수 프로그레스 바

---

## 관련 파일

| 파일 | 변경 내용 |
|------|-----------|
| `backend/schemas.py` | Recipe.calories_kcal, TasteProfileResponse, FridgeSearchRequest, RecipePublicItem.source |
| `backend/main.py` | GET /my/taste-profile, POST /recipes/fridge-search, GET /recipes source 파라미터 |
| `backend/ai_engine.py` | 칼로리 추정 프롬프트 추가 |
| `frontend/src/routes/+page.svelte` | source 필터 칩, 냉장고 파먹기 진입점 |
| `frontend/src/routes/my-recipes/+page.svelte` | source 필터 칩 |
| `frontend/src/routes/my-recipes/[id]/+page.svelte` | 칼로리 칩, source 뱃지 |
| `frontend/src/routes/my/+page.svelte` | 마이페이지 완성 (입맛 분석 차트) |
