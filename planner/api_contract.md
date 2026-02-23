# API 엔드포인트 명세

## 1. 개요

- **Base URL**: `http://localhost:8000` (개발), Docker 배포 시 `:8000`
- **Content-Type**: `application/json`
- **인증**: 현재 미구현 (2단계에서 `Authorization: Bearer <JWT>` 추가 예정)
- **CORS**: `ALLOWED_ORIGINS` 환경변수로 설정 (기본: `http://localhost:5173,http://localhost:80`)

---

## 2. 현재 구현된 엔드포인트

### 2.1 `GET /` — 헬스체크

서버 상태 확인용.

**Response** `200 OK`

```json
{
  "message": "Recipe AI Extraction API is running!"
}
```

---

### 2.2 `POST /extract-recipe` — 레시피 추출

YouTube URL로부터 AI 기반 레시피 데이터를 추출한다.

#### Request

```json
{
  "youtube_url": "https://www.youtube.com/watch?v=VIDEO_ID"
}
```

| 필드          | 타입   | 필수 | 설명                                                      |
| ------------- | ------ | ---- | --------------------------------------------------------- |
| `youtube_url` | string | O    | 유효한 YouTube URL (youtube.com, youtu.be, m.youtube.com) |

#### Validation

- URL 형식 검증: `(https?://)?(www\.)?(youtube\.com|youtu\.be|m\.youtube\.com)/.+`

#### Response `200 OK` — 성공 (Recipe)

```json
{
  "id": 1,
  "is_recipe": true,
  "non_recipe_reason": null,
  "title": "김치찌개 만들기",
  "summary": "돼지고기 목살을 활용한 깊은 맛의 김치찌개입니다...",
  "ingredients": [
    {
      "name": "김치",
      "amount": "200",
      "unit": "g",
      "category": "주재료"
    },
    {
      "name": "돼지고기 목살",
      "amount": "150",
      "unit": "g",
      "category": "주재료"
    }
  ],
  "steps": [
    {
      "step_number": 1,
      "description": "김치를 적당한 크기로 썰어 준비합니다.",
      "timer": null
    },
    {
      "step_number": 2,
      "description": "냄비에 참기름을 두르고 돼지고기를 볶습니다.",
      "timer": "3분"
    }
  ],
  "flavor": {
    "saltiness": 4,
    "sweetness": 1,
    "spiciness": 3,
    "sourness": 2,
    "oiliness": 3
  },
  "tip": "묵은지를 사용하면 더 깊은 맛을 낼 수 있습니다.",
  "video_url": "https://www.youtube.com/watch?v=VIDEO_ID",
  "video_id": "VIDEO_ID"
}
```

#### Response 스키마 상세

**Recipe**
| 필드 | 타입 | 설명 |
|------|------|------|
| `id` | int / null | DB ID (캐시 히트 시 존재, 새 추출 시 저장 후 설정) |
| `is_recipe` | bool | 항상 true (false면 400 에러로 반환) |
| `non_recipe_reason` | string / null | 레시피 아닌 경우 사유 |
| `title` | string | 레시피 제목 |
| `summary` | string | 요리 개요 |
| `ingredients` | Ingredient[] | 재료 목록 |
| `steps` | RecipeStep[] | 조리 과정 |
| `flavor` | FlavorProfile | 맛 5축 지표 |
| `tip` | string / null | 전문가 팁 |
| `video_url` | string / null | YouTube URL |
| `video_id` | string / null | YouTube 영상 ID |

**Ingredient**
| 필드 | 타입 | 설명 |
|------|------|------|
| `name` | string | 재료명 |
| `amount` | string / null | 수량 |
| `unit` | string / null | 단위 |
| `category` | string | 카테고리 (주재료, 부재료, 양념, 소스, 토핑 등) |

**RecipeStep**
| 필드 | 타입 | 설명 |
|------|------|------|
| `step_number` | int | 순서 번호 |
| `description` | string | 조리 설명 |
| `timer` | string / null | 타이머 (예: "10분", "30초") |

**FlavorProfile**
| 필드 | 타입 | 범위 | 설명 |
|------|------|------|------|
| `saltiness` | int | 1-5 | 짠맛 |
| `sweetness` | int | 1-5 | 단맛 |
| `spiciness` | int | 1-5 | 매운맛 |
| `sourness` | int | 1-5 | 신맛 |
| `oiliness` | int | 1-5 | 기름진 정도 |

#### 에러 응답

모든 에러는 다음 구조를 따른다:

```json
{
  "error_code": "ERROR_CODE",
  "message": "사용자 친화적 메시지",
  "detail": "개발자용 상세 정보 (선택)"
}
```

| HTTP 상태 | error_code          | 발생 조건                               |
| --------- | ------------------- | --------------------------------------- |
| `400`     | `INVALID_URL`       | 유효한 YouTube URL이 아닌 경우          |
| `400`     | `NOT_RECIPE`        | AI 분석 결과 레시피 영상이 아닌 경우    |
| `403`     | `ACCESS_DENIED`     | 멤버십 전용 / 비공개 / 로그인 필요 영상 |
| `422`     | `VALIDATION_ERROR`  | Pydantic 모델 검증 실패                 |
| `500`     | `EXTRACTION_FAILED` | 레시피 추출 중 예상치 못한 오류         |
| `500`     | `INTERNAL_ERROR`    | 서버 내부 오류                          |

---

### 2.3 `POST /collections` — 보관함 저장

사용자의 개인 보관함에 레시피를 저장한다.

#### Request

```json
{
  "user_id": "00000000-0000-0000-0000-000000000000",
  "recipe_id": 1,
  "custom_tip": "고추장 1큰술 더 넣으면 맛있음",
  "ingredient_adjustments": {
    "excluded": ["고수"],
    "scale": 0.8
  }
}
```

| 필드                     | 타입          | 필수 | 설명           |
| ------------------------ | ------------- | ---- | -------------- |
| `user_id`                | string (UUID) | O    | 사용자 ID      |
| `recipe_id`              | int           | O    | 레시피 ID      |
| `custom_tip`             | string / null | X    | 개인 메모      |
| `ingredient_adjustments` | object / null | X    | 재료 가감 정보 |

#### Response `200 OK`

```json
{
  "status": "success",
  "message": "보관함에 저장되었습니다."
}
```

#### 에러 응답

| HTTP 상태 | error_code             | 발생 조건                    |
| --------- | ---------------------- | ---------------------------- |
| `500`     | `DB_CONNECTION_FAILED` | Supabase 연결 실패           |
| `400`     | `SAVE_FAILED`          | 저장 실패 (데이터 반환 없음) |
| `500`     | `INTERNAL_ERROR`       | 서버 내부 오류               |

#### 동작 특성

- `upsert` 사용: 같은 (user_id, recipe_id) 쌍이 있으면 업데이트

---

## 3. 미구현이지만 필요한 엔드포인트

### 3.1 `GET /collections/{user_id}` — 보관함 조회 (P0)

> 프론트엔드 `library/+page.svelte`에서 이미 호출 중이나 백엔드에 없음.

**우선순위**: P0 (즉시 구현 필요)

#### 예상 Request

```
GET /collections/00000000-0000-0000-0000-000000000000
```

#### 예상 Response `200 OK`

```json
[
  {
    "id": 1,
    "user_id": "00000000-...",
    "recipe_id": 1,
    "custom_tip": "고추장 더 넣기",
    "ingredient_adjustments": null,
    "created_at": "2026-02-12T00:00:00Z",
    "recipe": {
      "id": 1,
      "title": "김치찌개",
      "summary": "...",
      "video_id": "VIDEO_ID"
    }
  }
]
```

**참고**: 프론트엔드에서 `item.recipe.title` 형태로 접근하므로, 보관함 데이터에 연관된 레시피 정보도 함께 반환해야 한다. Supabase의 `select("*, recipe:recipes(*)")` 문법 활용 가능.

---

### 3.2 `DELETE /collections/{collection_id}` — 보관함 삭제 (P1)

**우선순위**: P1 (나의 주방 페이지 완성 시 필요)

---

### 3.3 `GET /recipes/{recipe_id}` — 개별 레시피 조회 (P1)

**우선순위**: P1 (보관함에서 레시피 상세 보기 시 필요)

---

### 3.4 인증 관련 엔드포인트 (P2)

> `auth.py`에 스켈레톤 존재. Supabase Auth 연동 시 구현 예정.

| 엔드포인트                     | 설명                                                              |
| ------------------------------ | ----------------------------------------------------------------- |
| 미정 (Supabase Auth 직접 사용) | 회원가입/로그인은 프론트엔드에서 Supabase Auth SDK 직접 호출 가능 |
| `GET /me`                      | 현재 로그인 사용자 정보 반환 (JWT 검증)                           |

**참고**: Supabase Auth를 사용하면 별도 회원가입/로그인 API 없이 프론트엔드에서 직접 처리 가능. 백엔드는 JWT 검증(`require_auth` dependency)만 담당.

---

### 3.5 카테고리 관련 (P2)

| 엔드포인트                      | 설명                   |
| ------------------------------- | ---------------------- |
| `GET /categories`               | 카테고리 목록 조회     |
| `POST /recipes/{id}/categories` | 레시피에 카테고리 태깅 |

---

## 4. 공통 에러 구조

### ErrorResponse 모델

```python
class ErrorResponse(BaseModel):
    error_code: str    # 프로그래밍용 에러 코드
    message: str       # 사용자 친화적 메시지 (한국어)
    detail: str | None # 개발자용 상세 정보
```

### 전체 에러 코드 목록

| error_code             | HTTP | 설명                           |
| ---------------------- | ---- | ------------------------------ |
| `INVALID_URL`          | 400  | YouTube URL 형식 오류          |
| `NOT_RECIPE`           | 400  | 레시피 영상이 아님             |
| `ACCESS_DENIED`        | 403  | 접근 불가 영상 (멤버십/비공개) |
| `VALIDATION_ERROR`     | 422  | 요청 데이터 형식 오류          |
| `DB_CONNECTION_FAILED` | 500  | DB 연결 실패                   |
| `SAVE_FAILED`          | 400  | 보관함 저장 실패               |
| `EXTRACTION_FAILED`    | 500  | AI 추출 중 오류                |
| `INTERNAL_ERROR`       | 500  | 서버 내부 오류                 |

---

_이 문서는 초안이며, 팀 리뷰를 통해 수정될 예정입니다._
_최종 수정: 2026-02-12_
