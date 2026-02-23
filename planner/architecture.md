# 시스템 아키텍처

## 1. 전체 아키텍처 개요

시스템은 4개의 레이어로 구성된다.

```
[사용자]
   |
   v
[Frontend - SvelteKit]  :5173 (dev) / :80 (nginx)
   |
   v  (REST API)
[Backend - FastAPI]  :8000
   |         |
   v         v
[Supabase]  [Gemini 2.5 Flash]
(PostgreSQL)  (Google AI)
   ^
   |
[yt-dlp + FFmpeg]
(YouTube 오디오 추출)
```

---

## 2. 백엔드 모듈 구성 (`backend/`)

| 모듈 | 파일 | 역할 |
|------|------|------|
| **API 서버** | `main.py` | FastAPI 앱, 엔드포인트 정의, CORS, 전역 예외 핸들러 |
| **AI 엔진** | `ai_engine.py` | Gemini 2.5 Flash 연동, 오디오 업로드, 프롬프트 실행, JSON 파싱 |
| **스키마** | `schemas.py` | Pydantic v2 모델 (Recipe, Ingredient, RecipeStep, FlavorProfile, ErrorResponse 등) |
| **유틸리티** | `utils.py` | yt-dlp 래퍼 (video_id 추출, 오디오 다운로드, 메타데이터 조회) |
| **DB 클라이언트** | `database.py` | Supabase 클라이언트 팩토리 (환경변수 기반) |
| **인증** | `auth.py` | JWT 검증 스켈레톤 (TODO: Supabase Auth 연동) |
| **로깅** | `logger.py` | 커스텀 로거 설정 (stdout, 포맷 통일) |

### 의존성 관계
```
main.py
  ├── schemas.py      (Pydantic 모델)
  ├── utils.py         (yt-dlp 래퍼)
  ├── ai_engine.py     (Gemini 연동)
  │    └── schemas.py
  ├── database.py      (Supabase 클라이언트)
  └── logger.py        (로깅)

ai_engine.py
  ├── google.generativeai  (Gemini SDK)
  ├── tenacity             (재시도)
  └── schemas.py
```

### 환경변수 (`backend/.env`)
| 변수 | 용도 |
|------|------|
| `GEMINI_API_KEY` | Google Gemini API 인증 키 |
| `SUPABASE_URL` | Supabase 프로젝트 URL |
| `SUPABASE_KEY` | Supabase anon/service 키 |
| `ALLOWED_ORIGINS` | CORS 허용 도메인 (쉼표 구분) |

### 주요 의존성 (`requirements.txt`)
- `fastapi` >= 0.115.0
- `uvicorn` >= 0.32.0
- `google-generativeai` >= 0.8.0
- `yt-dlp` >= 2024.12.0
- `pydantic` >= 2.10.0
- `python-dotenv` >= 1.0.0
- `supabase` >= 2.11.0
- `tenacity` >= 9.0.0

---

## 3. 프론트엔드 구조 (`frontend/`)

### 기술 스택
- **SvelteKit** (Svelte 5, adapter-auto)
- **TypeScript**
- **Vite** 7.x

### 라우트 구조 (현재)
```
frontend/src/
├── app.css              # 글로벌 CSS (디자인 토큰, 폰트, 리셋)
├── app.html             # HTML 셸
├── app.d.ts             # SvelteKit 타입 선언
├── lib/
│   ├── index.ts         # 라이브러리 진입점 (비어있음)
│   └── assets/
│       └── favicon.svg
├── routes/
│   ├── +layout.svelte   # 글로벌 레이아웃 (폰트 로드, app.css import)
│   ├── +page.svelte     # 메인 페이지 (3개 상태 머신: IDLE/LOADING/RESULT)
│   └── library/
│       └── +page.svelte # 나의 주방 (보관함 목록)
```

### 라우트 구조 (새 디자인 목표)
```
frontend/src/
├── app.css              # 글로벌 CSS (레시피 북 디자인 토큰)
├── routes/
│   ├── +layout.svelte   # 글로벌 레이아웃 (Navbar 포함)
│   ├── +page.svelte     # 홈 (URL 입력 + 인라인 프로그레스)
│   ├── recipe/
│   │   └── [video_id]/
│   │       └── +page.svelte  # 레시피 페이지 (요리책 한 페이지)
│   └── library/
│       ├── +page.svelte      # 내 레시피북 (목차)
│       └── [id]/
│           └── +page.svelte  # 저장된 레시피 상세 (변형 노트 포함)
├── lib/
│   ├── components/      # 공통 컴포넌트
│   ├── stores/          # 상태 관리
│   └── api/             # API 호출 래퍼
```

### 디자인 토큰 (새 디자인 -- `app.css`)
| 변수 | 값 | 용도 |
|------|-----|------|
| `--color-paper` | `#FAF8F5` | 전체 배경 (종이) |
| `--color-cream` | `#F5F0E8` | 카드/섹션 배경 |
| `--color-warm-brown` | `#8B7355` | 주요 텍스트 |
| `--color-terracotta` | `#C4704B` | CTA 버튼, 강조 |
| `--color-sage` | `#8FA880` | 성공, 완료 체크 |
| `--font-header` | Pretendard | 제목용 |
| `--font-sub` | Nunito | 숫자/데이터 |
| `--font-body` | Pretendard | 본문 |
| `--font-memo` | Nanum Myeongjo | 꿀팁/메모 (제한적) |

### 이미지 에셋 (`static/assets/`) -- 현재
| 파일 | 용도 | 새 디자인 |
|------|------|-----------|
| `hero_main.png` | 랜딩 히어로 (고양이 셰프) | 제거 예정 |
| `visual_hero.png` | 대체 히어로 | 제거 예정 |
| `loading/cat.png` | 로딩 고양이 | 제거 예정 |
| `loading/bg.png` | 로딩 배경 | 제거 예정 |
| `loading/left_deco.png` | 로딩 왼쪽 데코 | 제거 예정 |
| `loading/right_deco.png` | 로딩 오른쪽 데코 | 제거 예정 |

> 새 디자인("레시피 북")은 캐릭터/이미지 에셋 없이 타이포그래피와 레이아웃으로 표현.

---

## 4. 데이터베이스 스키마

### 4.1 현재 스키마 (`init_db.sql`)

#### 테이블 관계도
```
users (UUID PK)
  |
  ├──< user_collections >── recipes (bigint PK)
  |     (N:M + 개인화)          |
  |                             ├──< recipe_categories >── categories
  |                             |     (N:M)
  └──< cooking_history >────────┘

analysis_logs (독립 -- 로그 전용)
```

#### 테이블 상세

**recipes (레시피 마스터)**
| 컬럼 | 타입 | 설명 |
|------|------|------|
| `id` | bigint (PK, auto) | 고유 ID |
| `title` | text NOT NULL | 레시피 제목 |
| `summary` | text | 요리 개요 |
| `ingredients` | jsonb | 구조화된 재료 목록 |
| `steps` | jsonb | 구조화된 조리 과정 |
| `flavor` | jsonb | 맛 5축 지표 |
| `tip` | text | 셰프 원본 팁 |
| `video_url` | text UNIQUE | 영상 URL |
| `video_id` | text UNIQUE | 영상 고유 ID (캐시 키) |
| `created_at` | timestamptz | 생성 일시 |

**users (사용자)**
| 컬럼 | 타입 | 설명 |
|------|------|------|
| `id` | uuid (PK) | 유저 고유 ID |
| `email` | text UNIQUE NOT NULL | 이메일 |
| `nickname` | text | 닉네임 |
| `avatar_url` | text | 프로필 이미지 URL |
| `created_at` | timestamptz | 가입 일시 |

**user_collections (개인화 보관함)**
| 컬럼 | 타입 | 설명 |
|------|------|------|
| `id` | bigint (PK, auto) | 레코드 ID |
| `user_id` | uuid (FK -> users) | 사용자 참조 |
| `recipe_id` | bigint (FK -> recipes) | 레시피 참조 |
| `custom_tip` | text | 개인 메모 |
| `ingredient_adjustments` | jsonb | 재료 가감 정보 |
| `created_at` | timestamptz | 저장 일시 |
| UNIQUE | (user_id, recipe_id) | 중복 저장 방지 |

**categories (카테고리)**
| 컬럼 | 타입 | 설명 |
|------|------|------|
| `id` | bigint (PK, auto) | 카테고리 ID |
| `name` | text UNIQUE NOT NULL | 이름 (한식, 양식 등) |
| `description` | text | 설명 |

**recipe_categories (레시피-카테고리 매핑)**
| 컬럼 | 타입 | 설명 |
|------|------|------|
| `recipe_id` | bigint (FK -> recipes) | 레시피 참조 |
| `category_id` | bigint (FK -> categories) | 카테고리 참조 |
| PK | (recipe_id, category_id) | 복합 키 |

**cooking_history (요리 기록) -- 현재**
| 컬럼 | 타입 | 설명 |
|------|------|------|
| `id` | bigint (PK, auto) | 기록 ID |
| `user_id` | uuid (FK -> users, SET NULL) | 사용자 참조 |
| `recipe_id` | bigint (FK -> recipes, CASCADE) | 레시피 참조 |
| `notes` | text | 피드백 메모 |
| `image_url` | text | 요리 사진 URL |
| `cooked_date` | timestamptz | 요리 일시 |

**analysis_logs (AI 분석 로그)**
| 컬럼 | 타입 | 설명 |
|------|------|------|
| `id` | bigint (PK, auto) | 로그 ID |
| `video_url` | text NOT NULL | 분석 대상 URL |
| `raw_response` | jsonb | Gemini 원본 응답 |
| `processing_time_ms` | integer | 처리 시간 (ms) |
| `success` | boolean | 성공 여부 |
| `created_at` | timestamptz | 기록 일시 |

#### CASCADE 규칙
- `recipes` 삭제 시: `recipe_categories`, `user_collections`, `cooking_history` 자동 삭제
- `users` 삭제 시: `user_collections` 자동 삭제, `cooking_history.user_id` NULL 설정
- `categories` 삭제 시: `recipe_categories` 자동 삭제

---

### 4.2 스키마 변경 방향 (2단계)

#### 변경 1: recipes 테이블에 카테고리 필드 추가

현재 카테고리는 별도 테이블(`categories`, `recipe_categories`)로 관리되고 있으나, AI가 레시피 분석 시 자동 제안하는 구조에서는 recipes 테이블에 직접 카테고리를 포함하는 것이 더 실용적이다.

**방안 A: recipes에 category 컬럼 추가 (단순)**
```sql
ALTER TABLE recipes ADD COLUMN category text;
-- 값 예시: '한식', '국/찌개', '양식' 등 (고정 목록에서 선택)
```

**방안 B: 기존 M:N 테이블 활용 (다중 카테고리)**
- `recipe_categories` 테이블을 활용하여 한 레시피에 여러 카테고리 부여
- 예: 김치찌개 -> '한식' + '국/찌개'

> 권장: **방안 A** (단순). AI가 1개 대표 카테고리를 제안하고 사용자가 확인. 초기에는 복잡한 다중 분류보다 단일 분류가 사용성에 유리.

#### 변경 2: cooking_history -> recipe_notes (나만의 변형 노트)

기존 `cooking_history` 테이블은 레시피 단위의 단순 메모만 가능했다. 이를 **재료별/단계별 세분화된 인라인 메모 + 요리 후기** 구조로 재설계한다.

**현재 문제**: `notes` 컬럼 하나에 레시피 전체 피드백만 저장 가능. "김치를 200g -> 300g으로 늘렸더니 좋았다" 같은 재료별 세부 메모를 구조화할 수 없음.

**제안 스키마: recipe_notes**
```sql
CREATE TABLE IF NOT EXISTS recipe_notes (
  id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  collection_id BIGINT REFERENCES user_collections(id) ON DELETE CASCADE,

  -- 메모 대상 (어떤 요소에 대한 메모인지)
  note_type TEXT NOT NULL,  -- 'ingredient' | 'step' | 'general' | 'review'
  target_index INT,         -- 재료/단계 인덱스 (null이면 전체)

  -- 메모 내용
  content TEXT NOT NULL,    -- 메모 본문

  -- 요리 후기용 추가 필드
  image_url TEXT,           -- 요리 사진 (review 타입일 때)

  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);
```

**note_type별 사용 예시**:

| note_type | target_index | content | 설명 |
|-----------|-------------|---------|------|
| `ingredient` | 0 | "설탕 -> 물엿으로 대체하니 더 촉촉함" | 첫번째 재료에 대한 메모 |
| `ingredient` | 3 | "고춧가루 2큰술 -> 1.5큰술이 우리 입맛에 딱" | 네번째 재료 양 조절 메모 |
| `step` | 1 | "중불에서 5분이 아니라 약불에서 7분이 더 나음" | 두번째 단계 메모 |
| `general` | null | "전체적으로 간이 좀 셌다. 다음엔 간장 줄이기" | 레시피 전체 메모 |
| `review` | null | "2번째 만들었는데 이번엔 딱 맞았다!" | 요리 후기 (날짜별 쌓임) |

**기존 cooking_history와의 관계**:
- `cooking_history` 테이블은 **recipe_notes (note_type='review')로 통합** 가능
- 또는 `cooking_history`는 유지하고, `recipe_notes`를 순수 메모 전용으로 분리
- 권장: **통합** (recipe_notes에 review 타입으로 요리 후기 포함)

#### 변경 3: Gemini 프롬프트 카테고리 목록 추가

`ai_engine.py`의 프롬프트에 고정 카테고리 목록을 추가하여 JSON 응답에 `category` 필드를 포함시킨다.

```
[결과 포맷 (JSON)]에 추가:
"category": "한식"  // 다음 목록에서 하나만 선택: 한식, 양식, 중식, 일식, 동남아, 국/찌개, 볶음, 구이, 찜, 반찬, 디저트, 음료, 간식, 다이어트, 간편식
```

`schemas.py`의 `Recipe` 모델에도 `category` 필드 추가:
```python
category: Optional[str] = Field(None, description="레시피 카테고리 (AI 제안)")
```

---

## 5. 데이터 흐름 (핵심 파이프라인)

### POST /extract-recipe 흐름
```
1. [클라이언트] YouTube URL 전송
       |
2. [main.py] extract_video_id() -- yt-dlp + regex fallback
       |
3. [main.py] DB 캐시 체크 (recipes 테이블, video_id 조회)
       |
       ├─ 캐시 히트 -> 즉시 Recipe 반환 (종료)
       |
4. [main.py] 접근 불가 체크 (멤버십/비공개/로그인 필요)
       |
5. [utils.py] get_video_metadata() -- 제목/설명 추출
       |
6. [utils.py] download_audio() -- MP3 다운로드
       |
7. [ai_engine.py] Gemini에 오디오 파일 업로드
       |
8. [ai_engine.py] 파일 처리 대기 (폴링, 최대 120초)
       |
9. [ai_engine.py] 멀티모달 프롬프트 실행 (오디오 + 텍스트)
       |                + 카테고리 고정 목록 포함 (신규)
       |
10. [ai_engine.py] JSON 파싱 + Recipe 모델 검증
       |              + category 필드 포함 (신규)
       |
11. [main.py] is_recipe 체크
       ├─ false -> NOT_RECIPE 에러 반환 (DB 미저장)
       |
12. [main.py] DB 저장 (recipes 테이블 INSERT)
       |
13. [main.py] Recipe 반환 (category 포함)
       |
    [finally] 임시 오디오 파일 삭제 + analysis_logs 기록
```

### 변형 노트 데이터 흐름 (2단계 신규)
```
1. [클라이언트] 저장된 레시피 상세 페이지에서 메모 작성
       |
2. [Backend] POST /notes -- recipe_notes 테이블에 저장
       |     (note_type, target_index, content)
       |
3. [클라이언트] 내 레시피북 상세 페이지에서 메모 조회
       |
4. [Backend] GET /collections/{id}/notes -- 해당 보관함의 모든 메모 반환
       |     재료별/단계별/전체/후기로 그룹핑
       |
5. [프론트엔드] 레시피 원본 위에 인라인 메모를 오버레이 표시
       (요리책에 연필로 끄적인 주석 느낌)
```

### 3단계 입맛 패턴 분석 흐름 (향후)
```
1. recipe_notes에 충분한 데이터 축적
       |
2. 패턴 분석 (Gemini 또는 자체 알고리즘)
       |  "설탕 -> 조청 대체 3회", "매운맛 감소 5회" 등
       |
3. taste_profiles 테이블에 사용자 선호 저장
       |
4. 새 레시피 조회 시 taste_profiles와 비교
       |
5. AI가 맞춤 제안 생성
       "설탕 대신 조청 쓰시면 좋을 것 같아요"
       "매운맛 3 -> 2로 줄이시면 입맛에 맞을 거예요"
```

---

## 6. Docker Compose 구성

```yaml
services:
  backend:     # Python 3.11-slim + ffmpeg, :8000
  frontend:    # nginx:alpine, :80
```

- 백엔드: `backend/.env`에서 환경변수 로드, 소스 볼륨 마운트
- 프론트엔드: nginx로 정적 파일 서빙 (현재 SvelteKit SSR이 아닌 정적 서빙)
- 프론트엔드가 백엔드에 의존 (`depends_on: backend`)

### 참고: 현재 docker-compose.yml의 프론트엔드 설정 이슈
현재 `nginx:alpine`으로 `frontend/` 디렉토리를 직접 서빙하는 구조인데, SvelteKit 빌드 결과물이 아닌 소스 디렉토리를 마운트하고 있어 실제 프로덕션 배포 시에는 빌드 스텝 추가 또는 Node.js 기반 서버로 변경이 필요하다.

---

*이 문서는 초안이며, 팀 리뷰를 통해 수정될 예정입니다.*
*최종 수정: 2026-02-12 (비전 구체화 반영 -- cooking_history 재설계, 카테고리 분류 방향)*
