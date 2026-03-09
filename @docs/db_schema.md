# 해먹당 — DB 스키마 명세서

*최종 수정: 2026-03-05 (v0.5.0)*

---

## 1. 개요

- **DBMS**: PostgreSQL (Supabase)
- **원칙**: 원본 레시피(공유)와 개인화 데이터(user_collections) 엄격 분리, JSONB 적극 활용

---

## 2. 테이블 상세

### 2.1 `recipes` (레시피 마스터, 공유 캐시)

| 컬럼 | 타입 | 설명 |
|------|------|------|
| `id` | bigint PK | 자동 증가 |
| `video_id` | text UNIQUE | 유튜브 영상 고유 ID (캐싱 키) |
| `video_url` | text | 영상 URL |
| `video_title` | text | 유튜브 영상 제목 |
| `channel_name` | text | 채널명 |
| `title` | text | 레시피 제목 (AI 추출) |
| `summary` | text | 요리 개요 |
| `ingredients` | jsonb | `Ingredient[]` (name, amount, unit, category) |
| `steps` | jsonb | `RecipeStep[]` (step_number, description, timer) |
| `flavor` | jsonb | `FlavorProfile` (saltiness, sweetness, spiciness, sourness, oiliness 각 1-5) |
| `tip` | text | AI 추출 꿀팁 |
| `category` | varchar(50) | 15개 카테고리 자동 분류 |
| `servings` | text | 인분 수 |
| `cooking_time` | text | 조리 시간 |
| `difficulty` | text | 난이도 |
| `is_public` | boolean DEFAULT true | 공개 여부 |
| `source` | varchar(20) DEFAULT 'youtube' | 출처 (youtube / text) |
| `collection_count` | integer DEFAULT 0 | 저장된 컬렉션 수 (캐싱, 트리거 자동 갱신) |
| `created_at` | timestamptz | 생성 일시 |

**인덱스:**
- `idx_recipes_title_trgm` — GIN pg_trgm (ILIKE 제목 검색)
- `idx_recipes_collection_count` — (collection_count DESC, created_at DESC) WHERE is_public

---

### 2.2 `user_collections` (개인 보관함)

| 컬럼 | 타입 | 설명 |
|------|------|------|
| `id` | bigint PK | |
| `user_id` | uuid FK→auth.users | Supabase Auth 사용자 ID |
| `recipe_id` | bigint FK→recipes | 레시피 참조 |
| `custom_tip` | text | 개인 메모 |
| `recipe_override` | jsonb DEFAULT NULL | 편집 데이터 (ingredients, steps, tip) |
| `is_favorite` | boolean DEFAULT false | 즐겨찾기 |
| `my_rating` | smallint | 별점 1-5, NULL=미평가 |
| `cooked_count` | integer DEFAULT 0 | 요리 횟수 |
| `last_cooked_at` | timestamptz | 마지막 요리 일시 |
| `category_override` | text | 카테고리 개인 오버라이드 |
| `created_at` | timestamptz | 저장 일시 |

**트리거:** `trg_collection_count` — INSERT/DELETE 시 `recipes.collection_count` 자동 +1/-1

---

### 2.3 `collection_tags` (태그 마스터)

| 컬럼 | 타입 | 설명 |
|------|------|------|
| `id` | bigint PK | |
| `user_id` | uuid FK→auth.users | 태그 소유자 |
| `name` | text | 태그 이름 |
| `color` | text | 헥스 색상 (예: #FF6B6B) |
| `created_at` | timestamptz | |

---

### 2.4 `collection_tag_items` (태그-컬렉션 연결)

| 컬럼 | 타입 | 설명 |
|------|------|------|
| `collection_id` | bigint FK→user_collections | |
| `tag_id` | bigint FK→collection_tags | |
| PK | (collection_id, tag_id) | 복합 기본키 |

---

## 3. RPC 함수

| 함수 | 설명 |
|------|------|
| `get_public_recipes_by_popularity` | `collection_count` 직접 정렬 (deprecated: JOIN 집계 방식 교체) |

---

## 4. recipe_override 구조 (JSONB)

```json
{
  "ingredients": [
    { "name": "김치", "amount": "200", "unit": "g", "category": "주재료", "note": "" }
  ],
  "steps": [
    { "order": 1, "description": "...", "timer_minutes": null, "note": "" }
  ],
  "tip": "나만의 꿀팁"
}
```

- `ingredients`: `IngredientOverride[]` (note 필드 추가)
- `steps`: `StepOverride[]` — `order`(순서), `timer_minutes`(분 단위 숫자), `note`
- 원본 `RecipeStep`의 `step_number` → override에서는 `order`로 매핑

---

## 5. 데이터 흐름

1. YouTube URL → `video_id` 추출 → `recipes` 캐시 조회
2. 캐시 미스 → Gemini 분석 → `recipes` INSERT → 반환
3. 캐시 히트 → DB에서 즉시 반환
4. 저장 → `user_collections` INSERT → `trg_collection_count` 트리거 → `recipes.collection_count++`
