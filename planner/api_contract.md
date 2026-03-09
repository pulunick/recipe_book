# API 엔드포인트 명세

*최종 수정: 2026-03-05 (v0.5.0)*

---

## 1. 개요

- **Base URL**: `http://localhost:8000` (개발) / Railway (프로덕션)
- **Content-Type**: `application/json`
- **인증**: `Authorization: Bearer <Supabase JWT>` (인증 필요 엔드포인트)
- **CORS**: `ALLOWED_ORIGINS` 환경변수 (기본: localhost:5180, Vercel 프로덕션 URL)

---

## 2. 레시피 추출

### `POST /extract-recipe` — 유튜브 URL 레시피 분석

**인증**: 불필요 (미인증 허용)

**Request**
```json
{
  "youtube_url": "https://www.youtube.com/watch?v=VIDEO_ID",
  "mode": "fast",
  "force_refresh": false
}
```

**Response `200`**
```json
{
  "id": 1,
  "title": "김치찌개 만들기",
  "summary": "...",
  "ingredients": [{ "name": "김치", "amount": "200", "unit": "g", "category": "주재료" }],
  "steps": [{ "step_number": 1, "description": "...", "timer": "3분" }],
  "flavor": { "saltiness": 4, "sweetness": 1, "spiciness": 3, "sourness": 2, "oiliness": 3 },
  "tip": "...",
  "category": "국/찌개",
  "video_url": "...",
  "video_id": "VIDEO_ID",
  "video_title": "...",
  "channel_name": "..."
}
```

**에러**
| HTTP | error_code | 조건 |
|------|-----------|------|
| 400 | `INVALID_URL` | YouTube URL 형식 오류 |
| 400 | `NOT_RECIPE` | 레시피 영상 아님 |
| 403 | `ACCESS_DENIED` | 비공개/멤버십 영상 |
| 500 | `NO_DATA_AVAILABLE` | 자막·오디오 모두 없음 |
| 500 | `EXTRACTION_FAILED` | AI 추출 오류 |

---

### `POST /extract-recipe-from-text` — 텍스트 레시피 변환

**인증**: 불필요

**Request**
```json
{ "text": "재료: 달걀 2개...\n조리법: 1. 팬에..." }
```

**Response**: 위 `/extract-recipe`와 동일 (DB 저장 없음, `id: null`)

---

## 3. 공개 레시피 탐색

### `GET /recipes` — 공개 레시피 목록

**인증**: 불필요

**Query Parameters**
| 파라미터 | 타입 | 설명 |
|----------|------|------|
| `sort` | string | `recent`(기본) / `popular` |
| `category` | string | 카테고리 필터 |
| `q` | string | 제목 + 재료명 검색 |
| `page` | int | 페이지 (기본 1) |
| `limit` | int | 페이지당 개수 (기본 20) |

**Response `200`**
```json
{
  "items": [
    {
      "id": 1, "title": "...", "summary": "...", "category": "국/찌개",
      "cooking_time": "30분", "difficulty": "쉬움", "servings": "2인분",
      "video_id": "...", "channel_name": "...", "created_at": "...",
      "collection_count": 42
    }
  ],
  "total": 100,
  "has_more": true
}
```

---

### `GET /recipes/categories` — 카테고리 목록

**인증**: 불필요

**Response `200`**: `["국/찌개", "한식", ...]` (실제 사용 카테고리 빈도순)

---

## 4. 사용자 보관함 (인증 필수)

### `POST /collections` — 보관함 저장

**Request**
```json
{ "user_id": "uuid", "recipe_id": 1, "custom_tip": "..." }
```

**Response `200`**: `{ "status": "success", "collection_id": 5 }`

---

### `GET /collections/{user_id}` — 보관함 목록

카드 표시에 필요한 컬럼만 포함 (steps/flavor 제외, ingredients 포함).

**Response `200`**: `CollectionItem[]`

---

### `GET /collections/item/{collection_id}` — 단일 아이템 상세 ✅ v0.5.0 신규

전체 recipe 데이터 포함 (상세 페이지용).

**Response `200`**: `CollectionItem` (recipe 전체 포함)

**에러**: 403 (타인의 컬렉션 접근 시)

---

### `DELETE /collections/{collection_id}` — 보관함 삭제

**Response `200`**: `{ "status": "deleted" }`

---

### `PATCH /collections/{collection_id}` — 보관함 수정

**Request**
```json
{
  "custom_tip": "...",
  "recipe_override": {
    "ingredients": [{ "name": "...", "amount": "...", "unit": "...", "category": "...", "note": "" }],
    "steps": [{ "order": 1, "description": "...", "timer_minutes": null, "note": "" }],
    "tip": "..."
  }
}
```
`recipe_override: null` 전송 시 원본으로 복원.

**Response `200`**: `{ "status": "updated" }`

---

### `PUT /collections/{collection_id}/favorite` — 즐겨찾기 토글

**Response `200`**: `{ "status": "ok", "is_favorite": true }`

---

### `PUT /collections/{collection_id}/rating` — 별점 설정

**Request**: `{ "rating": 4 }` (1-5)

**Response `200`**: `{ "status": "ok" }`

---

### `POST /collections/{collection_id}/cooked` — 요리 기록

**Request**: `{ "rating": 4 }` (optional)

**Response `200`**: `{ "status": "ok", "cooked_count": 3 }`

---

## 5. 태그 (인증 필수)

### `GET /tags/{user_id}` — 태그 목록

**Response `200`**: `[{ "id": 1, "name": "자주 해먹음", "color": "#FF6B6B" }]`

---

### `POST /tags` — 태그 생성

**Request**: `{ "user_id": "uuid", "name": "...", "color": "#FF6B6B" }`

**Response `200`**: `{ "id": 1, "name": "...", "color": "..." }`

---

### `DELETE /tags/{tag_id}` — 태그 삭제

**Response `200`**: `{ "status": "deleted" }`

---

### `PUT /collections/{collection_id}/tags` — 태그 일괄 설정

**Request**: `{ "tag_ids": [1, 3] }`

**Response `200`**: `{ "status": "ok" }`

---

## 6. CollectionItem 스키마

```typescript
interface CollectionItem {
  id: number;
  recipe: Recipe;            // 상세 페이지: full / 목록: 카드용 컬럼만
  custom_tip: string | null;
  recipe_override: RecipeOverride | null;
  is_favorite: boolean;
  my_rating: number | null;  // 1-5
  cooked_count: number;
  last_cooked_at: string | null;
  category_override: string | null;
  tags: CollectionTag[];
  created_at: string;
}
```
