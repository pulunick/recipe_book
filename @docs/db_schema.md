# 🗄️ 레시피 AI 데이터베이스 스키마 명세서 (Database Schema Design)

본 문서는 '입맛 저격 레시피 AI' 시스템의 데이터베이스 구조와 각 테이블의 상세 역할을 정의합니다.

---

## 1. 데이터베이스 개요

- **DBMS**: PostgreSQL (Supabase)
- **설계 원칙**:
  1. 원본 레시피(Canonical)와 유저 개인화(Personal) 데이터의 엄격한 분리
  2. 복잡한 구조체의 유연한 대응을 위한 `JSONB` 적극 활용
  3. 성능 최적화를 위한 유튜브 고유 ID(`video_id`) 기반 인덱싱

---

## 2. 테이블 상세 명세

### 2.1 recipes (레시피 마스터)

모든 사용자에게 공통으로 제공되는 원본 레시피 데이터입니다.

| 컬럼명        | 타입          | 설명                                         |
| :------------ | :------------ | :------------------------------------------- |
| `id`          | bigint (PK)   | 고유 레시피 ID (자동 생성)                   |
| `video_id`    | text (Unique) | 유튜브 영상의 고유 식별자 (예: U1RO-uEH0j4)  |
| `video_url`   | text (Unique) | 영상 전체 URL                                |
| `title`       | text          | 레시피 제목                                  |
| `summary`     | text          | 요리 개요 및 특징 요약                       |
| `ingredients` | jsonb         | 구조화된 재료 목록 (List[Ingredient])        |
| `steps`       | jsonb         | 구조화된 조리 순서 (List[RecipeStep])        |
| `flavor`      | jsonb         | 5대 맛 지표 (salt, sweet, spicy, sour, oily) |
| `tip`         | text          | 셰프의 원본 마무리 팁                        |
| `created_at`  | timestamp     | 데이터 생성 일시                             |

### 2.2 users (사용자)

서비스 이용자 정보입니다.

| 컬럼명       | 타입          | 설명                             |
| :----------- | :------------ | :------------------------------- |
| `id`         | uuid (PK)     | 유저 고유 ID (gen_random_uuid()) |
| `email`      | text (Unique) | 이메일 주소                      |
| `nickname`   | text          | 사용자 닉네임                    |
| `avatar_url` | text          | 프로필 이미지 URL                |
| `created_at` | timestamp     | 가입 일시                        |

### 2.3 user_collections (개인화 보관함)

유저가 저장한 레시피와 그에 따른 **개인용 커스텀 정보**를 관리합니다.

| 컬럼명                   | 타입        | 설명                                        |
| :----------------------- | :---------- | :------------------------------------------ |
| `id`                     | bigint (PK) | 보관함 레코드 ID                            |
| `user_id`                | uuid (FK)   | `users.id` 참조                             |
| `recipe_id`              | bigint (FK) | `recipes.id` 참조                           |
| `custom_tip`             | text        | 나만 볼 메모 (예: "고추장 1큰술 더 넣기")   |
| `ingredient_adjustments` | jsonb       | 제외 재료 정보 (예: {"excluded": ["고수"]}) |
| `created_at`             | timestamp   | 저장 일시                                   |

---

## 3. 기타 테이블 (확장용)

- **`categories`**: 레시피 카테고리 (한식, 양식, 10분 요리 등)
- **`recipe_categories`**: 레시피와 카테고리의 다대다(M:N) 관계 연결
- **`cooking_history`**: 사용자의 실제 요리 수행 기록 및 사진
- **`analysis_logs`**: AI 엔진의 분석 성공 여부 및 소요 시간 로그

---

## 4. 데이터 흐름의 특징

- **캐싱(Caching)**: 영상 분석 요청 시 `video_id` 인덱스를 통해 DB를 먼저 조회하여 중복 분석과 비용 발생을 방지합니다.
- **무결성(Integrity)**: `recipes`나 `users` 삭제 시 `ON DELETE CASCADE` 규칙에 의해 위 보관함 데이터는 자동으로 함께 정리됩니다.
- **확장성(Flexibility)**: 재료나 맛 지표가 `jsonb`로 저장되어 있어, 향후 앱에서 "내가 싫어하는 고수가 포함된 레시피 제외하기" 등의 복잡한 필터링이 가능합니다.
