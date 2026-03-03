# 태그 & 아카이빙 시스템 구현 명세서

> 설계 문서: `@docs/collection_tag_system.md`
> DB 마이그레이션: `backend/migrations/003_tag_system.sql`

---

## 1. DB 스키마 요약

### 변경된 테이블: `user_collections`
| 신규 컬럼 | 타입 | 기본값 | 설명 |
|-----------|------|--------|------|
| `is_favorite` | BOOLEAN | FALSE | 즐겨찾기 |
| `my_rating` | SMALLINT (1-5) | NULL | 내 별점 |
| `cooked_count` | INTEGER | 0 | 요리 횟수 |
| `last_cooked_at` | TIMESTAMPTZ | NULL | 마지막 요리 일시 |
| `category_override` | TEXT | NULL | 카테고리 수동 수정값 |

### 신규 테이블: `collection_tags`
유저별 커스텀 태그. `UNIQUE(user_id, name)`.
- `id`, `user_id` (FK users), `name`, `color` (hex, 기본 `#e8ddd4`), `created_at`

### 신규 테이블: `collection_tag_items`
보관함-태그 다대다 연결. PK = `(collection_id, tag_id)`.

---

## 2. Backend API 구현 (태스크 #2)

### 담당: Backend 팀원
### 파일: `backend/main.py` (또는 라우터 분리 시 `backend/routers/collections.py`, `backend/routers/tags.py`)

### 2.1 Pydantic 모델 추가 (`backend/schemas.py`)

```python
class CollectionTag(BaseModel):
    id: int
    user_id: str
    name: str
    color: str = "#e8ddd4"
    created_at: datetime | None = None

class TagCreate(BaseModel):
    user_id: str
    name: str
    color: str = "#e8ddd4"

class CollectionUpdate(BaseModel):
    custom_tip: str | None = None
    ingredient_adjustments: dict | None = None
    category_override: str | None = None

class RatingRequest(BaseModel):
    rating: int  # 1-5

class CookedRequest(BaseModel):
    rating: int | None = None  # 선택적 별점

class TagAssignRequest(BaseModel):
    tag_ids: list[int]

class CollectionItem(BaseModel):
    """GET /collections/{user_id} 응답 아이템"""
    id: int
    recipe_id: int
    title: str
    video_url: str | None
    video_id: str | None
    thumbnail_url: str | None  # 프론트에서 조립 가능하지만 편의상
    category: str | None       # category_override ?? recipes.category
    custom_tip: str | None
    is_favorite: bool
    my_rating: int | None
    cooked_count: int
    last_cooked_at: datetime | None
    tags: list[CollectionTag]
    created_at: datetime
```

### 2.2 API 엔드포인트

#### 즐겨찾기 토글
```
PUT /collections/{id}/favorite
```
- `is_favorite`를 `NOT is_favorite`로 토글
- 응답: `{ "is_favorite": true/false }`

#### 별점 설정
```
PUT /collections/{id}/rating
Body: { "rating": 4 }
```
- `my_rating` 업데이트
- 응답: `{ "my_rating": 4 }`

#### 만들어봤어요
```
POST /collections/{id}/cooked
Body: { "rating": 5 }  // 선택
```
- `cooked_count` += 1, `last_cooked_at` = now()
- `rating`이 있으면 `my_rating`도 업데이트
- 응답: `{ "cooked_count": 3, "last_cooked_at": "...", "my_rating": 5 }`

#### 카테고리 수동 변경
```
PUT /collections/{id}/category
Body: { "category": "한식" }
```
- `category_override` 업데이트
- 응답: `{ "category_override": "한식" }`

#### 태그 CRUD
```
GET    /tags/{user_id}           → list[CollectionTag]
POST   /tags                     → CollectionTag (body: TagCreate)
DELETE /tags/{id}                → { "deleted": true }
```

#### 태그 부착/해제
```
PUT /collections/{id}/tags
Body: { "tag_ids": [1, 2, 3] }
```
- 기존 연결 전체 삭제 후 새 `tag_ids`로 재연결 (replace 전략)
- 응답: `{ "tags": [...] }`

#### 컬렉션 목록 조회 (확장)
```
GET /collections/{user_id}
Query: ?category=한식&tag_id=3&is_favorite=true&min_rating=4&sort=last_cooked&q=된장
```
- JOIN: `user_collections` + `recipes` + `collection_tag_items` + `collection_tags`
- `category` 필터: `COALESCE(category_override, recipes.category)`
- `sort` 옵션: `saved_at`(기본), `last_cooked`, `rating`, `cooked_count`
- 응답: `list[CollectionItem]`

---

## 3. Frontend UI 구현 (태스크 #3)

### 담당: Frontend-QA 팀원
### 파일: `frontend/src/routes/my-recipes/+page.svelte` 및 관련 컴포넌트

### 3.1 목업 데이터 구조

Backend API가 준비되기 전에 아래 형태의 목업 데이터로 UI를 선행 개발:

```typescript
interface CollectionItem {
  id: number;
  recipe_id: number;
  title: string;
  video_url: string | null;
  video_id: string | null;
  category: string | null;
  custom_tip: string | null;
  is_favorite: boolean;
  my_rating: number | null;
  cooked_count: number;
  last_cooked_at: string | null;
  tags: { id: number; name: string; color: string }[];
  created_at: string;
}

interface CollectionTag {
  id: number;
  user_id: string;
  name: string;
  color: string;
}
```

### 3.2 구현할 컴포넌트

1. **레시피북 페이지** (`/my-recipes`)
   - 사이드바: 카테고리 필터, 태그 필터, 즐겨찾기
   - 모바일: 수평 스크롤 탭으로 전환
   - 레시피 카드 그리드

2. **레시피 카드** (`RecipeCard.svelte`)
   - 썸네일, 제목, 카테고리 뱃지, 태그 뱃지들
   - 즐겨찾기 별 아이콘 (원터치 토글)
   - 별점 표시, 요리 횟수
   - `[+태그]` 버튼

3. **태그 팝오버** (`TagPopover.svelte`)
   - 기존 태그 목록 (클릭 즉시 부착)
   - 검색 인풋 (없으면 엔터로 생성)
   - 색상 선택 (8색 원형 버튼)

4. **만들어봤어요 모달** (`CookedModal.svelte`)
   - 별점 입력 (1-5 별)
   - "나중에 입력할게요" / "저장" 버튼

### 3.3 태그 색상 상수

```typescript
const TAG_COLORS = [
  { name: '레드',       hex: '#f28b82' },
  { name: '옐로우',     hex: '#fbbc04' },
  { name: '그린',       hex: '#34a853' },
  { name: '블루',       hex: '#4285f4' },
  { name: '라이트블루', hex: '#a8c7fa' },
  { name: '브라운',     hex: '#e6c9a8' },
  { name: '그레이',     hex: '#d3d3d3' },
  { name: '기본',       hex: '#e8ddd4' },
];
```

---

## 4. 구현 순서

1. **태스크 #1** (Planner): DB 마이그레이션 SQL 작성 -- 완료
2. **태스크 #2** (Backend): API 엔드포인트 구현
3. **태스크 #3** (Frontend-QA): UI 컴포넌트 구현 (목업 데이터로 선행 가능)
4. **태스크 #4**: 통합 테스트 및 QA
