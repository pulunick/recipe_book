# 레시피 데이터베이스 기능 명세

## 개요

YouTube 영상 분석 레시피 + 유저 직접 작성 레시피를 통합한 공개 레시피 데이터베이스.
검색, 필터, 추천 기능 포함.

## DB 스키마 변경

### recipes 테이블 추가 컬럼

```sql
ALTER TABLE recipes
  ADD COLUMN source         text    NOT NULL DEFAULT 'youtube',
  ADD COLUMN author_user_id uuid    REFERENCES auth.users(id) ON DELETE SET NULL,
  ADD COLUMN is_public      boolean NOT NULL DEFAULT true;
```

| 컬럼 | 타입 | 설명 |
|---|---|---|
| `source` | text | `'youtube'` 또는 `'user'` |
| `author_user_id` | uuid | 유저 작성 레시피의 작성자 ID (YouTube 레시피는 null) |
| `is_public` | boolean | 공개 여부 (기본 true) |

기존 레코드: `source='youtube'`, `author_user_id=null`, `is_public=true` 그대로 유지.

## 권한 규칙

| 레시피 타입 | 수정 | 삭제 | 공개/비공개 전환 |
|---|---|---|---|
| YouTube (AI 추출) | 불가 | 불가 | 불가 |
| 유저 작성 | author만 | author만 | author만 |

## 새 엔드포인트

```
POST   /recipes                        유저 레시피 직접 작성
PATCH  /recipes/{recipe_id}            유저 레시피 수정 (author 검증)
DELETE /recipes/{recipe_id}            유저 레시피 삭제 (author 검증)
PUT    /recipes/{recipe_id}/visibility 공개/비공개 전환 (is_public 토글)
GET    /recipes/public                 레시피 DB 전체 조회 (검색/필터/추천)
```

## 데이터 흐름

### 유저 레시피 작성
1. `POST /recipes` (JWT 필수)
2. `recipes` INSERT (`source='user'`, `author_user_id=JWT user_id`, `is_public=요청값`)
3. `user_collections` INSERT (자동 보관함 등록)
4. `recipe_id` 반환

### 레시피 DB 화면
- `GET /recipes/public` → `WHERE is_public = true` 전체 조회
- YouTube 레시피 + 공개 유저 레시피 통합 노출
- 검색(title), 카테고리 필터, 난이도 필터, 추천 정렬 지원 예정

## 미결 사항

- 추천 알고리즘 기준 (인기순? 저장수? 맛 프로파일 유사도?)
- 유저 레시피 작성 UI (홈에서 탭 전환? 별도 페이지?)
- 유저 레시피의 `ingredients`, `steps`, `flavor` 입력 폼 설계
