# 해먹당 (My Recipe Pick) — 프로젝트 가이드

> 유튜브 요리 영상 URL을 붙여넣으면 AI가 재료·조리 순서·맛 프로필을 자동으로 뽑아주는 서비스.

---

## 목차

1. [서비스 개요](#1-서비스-개요)
2. [기술 스택](#2-기술-스택)
3. [전체 구조 한눈에 보기](#3-전체-구조-한눈에-보기)
4. [백엔드 핵심 흐름](#4-백엔드-핵심-흐름)
5. [프론트엔드 구조](#5-프론트엔드-구조)
6. [데이터베이스 구조](#6-데이터베이스-구조)
7. [로컬 개발 환경 세팅](#7-로컬-개발-환경-세팅)
8. [배포 구조](#8-배포-구조)
9. [현재 구현 상태 및 남은 작업](#9-현재-구현-상태-및-남은-작업)
10. [주요 설계 결정 기록](#10-주요-설계-결정-기록)

---

## 1. 서비스 개요

### 무엇을 만드는가

사용자가 유튜브 요리 영상 URL을 붙여넣으면:

1. Google Gemini AI가 영상을 직접 보고 분석
2. 재료 목록, 조리 단계, 맛 프로필을 구조화된 JSON으로 추출
3. 결과를 내 레시피북에 저장해 언제든 다시 볼 수 있음

### 화면 흐름

```
홈 (URL 입력)
  → 분석 중 (로딩 화면)
    → 결과 (레시피 전체 표시 + 레시피북 저장 버튼)
      → 내 레시피북 (/library) - 저장된 목록
        → 레시피 상세 (/library/[id]) - 저장된 레시피 전체 보기
```

---

## 2. 기술 스택

| 영역                      | 기술                    | 이유                                         |
| ------------------------- | ----------------------- | -------------------------------------------- |
| **백엔드 언어**           | Python 3.11             | AI 라이브러리 생태계가 가장 풍부             |
| **백엔드 프레임워크**     | FastAPI                 | 비동기 지원, 자동 API 문서, 빠른 개발        |
| **AI 분석**               | Google Gemini 2.5 Flash | YouTube URL 직접 분석 가능 (다운로드 불필요) |
| **AI SDK**                | google-genai (신버전)   | YouTube URL 네이티브 지원                    |
| **데이터 검증**           | Pydantic v2             | AI 응답 JSON을 타입 안전하게 파싱            |
| **데이터베이스**          | Supabase (PostgreSQL)   | Auth 내장, 실시간 기능, 무료 시작 가능       |
| **프론트엔드 프레임워크** | SvelteKit               | 가볍고 빠름, Svelte 5 반응형 문법            |
| **프론트엔드 언어**       | TypeScript              | 타입 안전성                                  |
| **백엔드 배포**           | Render                  | 무료 플랜, GitHub 자동 배포                  |
| **프론트엔드 배포**       | Vercel                  | SvelteKit 최적화, GitHub 자동 배포           |

---

## 3. 전체 구조 한눈에 보기

```
사용자 브라우저
      │
      │  https://recipe-book-gray-five.vercel.app
      ▼
┌─────────────────────┐
│   Vercel (프론트)    │
│   SvelteKit         │
│   - 홈 (URL 입력)   │
│   - 결과 화면       │
│   - 내 레시피북     │
└──────────┬──────────┘
           │  HTTP API 요청
           ▼
┌─────────────────────┐
│   Render (백엔드)   │
│   FastAPI           │
│   - /extract-recipe │
│   - /collections    │
└──────────┬──────────┘
           │
    ┌──────┴──────┐
    │             │
    ▼             ▼
┌──────────┐  ┌──────────────┐
│ Supabase │  │ Google       │
│ (DB 캐시)│  │ Gemini AI    │
│ recipes  │  │ 2.5 Flash    │
│ table    │  │              │
└──────────┘  └──────────────┘
```

### 폴더 구조

```
recipe/
├── backend/
│   ├── main.py          ← API 엔드포인트 정의
│   ├── ai_engine.py     ← Gemini 연동 핵심 로직
│   ├── schemas.py       ← 데이터 구조 정의 (Pydantic)
│   ├── utils.py         ← YouTube 유틸리티 함수들
│   ├── database.py      ← Supabase 클라이언트
│   ├── logger.py        ← 로깅 설정
│   ├── init_db.sql      ← DB 테이블 생성 SQL
│   └── requirements.txt ← Python 패키지 목록
│
├── frontend/
│   └── src/
│       ├── lib/
│       │   ├── api.ts           ← 백엔드 API 호출 함수
│       │   ├── types.ts         ← TypeScript 타입 정의
│       │   └── components/
│       │       ├── Navbar.svelte
│       │       ├── SearchBox.svelte      ← URL 입력창
│       │       ├── LoadingScreen.svelte  ← 분석 중 화면
│       │       ├── FlavorProfile.svelte  ← 맛 프로필 점 그래프
│       │       ├── IngredientList.svelte ← 재료 목록
│       │       ├── StepTimeline.svelte   ← 조리 단계
│       │       └── RecipeCard.svelte     ← 레시피북 카드
│       └── routes/
│           ├── +layout.svelte           ← 공통 레이아웃 (Navbar)
│           ├── +page.svelte             ← 홈 (URL 입력 + 결과)
│           └── library/
│               ├── +page.svelte         ← 내 레시피북 목록
│               └── [id]/
│                   ├── +page.ts         ← 상세 페이지 데이터 로딩
│                   └── +page.svelte     ← 레시피 상세 페이지
│
├── docker-compose.yml
└── PROJECT_GUIDE.md     ← 이 문서
```

---

## 4. 백엔드 핵심 흐름

### 레시피 추출 API (`POST /extract-recipe`)

요청 한 번이 들어왔을 때 백엔드 안에서 일어나는 일:

```
1. URL 유효성 검사
   "https://www.youtube.com/watch?v=xxxxx" 형식인지 확인
   정규식으로 video_id(11자리) 추출

2. DB 캐시 확인 (Supabase)
   같은 video_id로 이미 분석한 결과가 있으면?
   → 즉시 반환 (Gemini 호출 없음, 빠름)
   없으면? → 3번으로

3. YouTube 메타데이터 가져오기
   YouTube oEmbed API로 영상 제목, 채널명 가져오기
   (이 API는 YouTube 공식 제공, 봇 차단 없음)

4. Gemini AI 분석
   "이 유튜브 영상의 레시피를 JSON으로 추출해줘"
   + 영상 URL을 Gemini에 직접 전달
   → Gemini(Google 서버)가 영상을 직접 보고 분석
   → 구조화된 JSON 반환

5. 결과 검증 (Pydantic)
   Gemini가 준 JSON이 우리 형식과 맞는지 자동 검증
   재료, 단계, 맛 점수 등이 다 있는지 확인

6. DB 저장 (Supabase)
   다음번에 같은 영상이 오면 빠르게 반환하기 위해 캐시 저장

7. 응답 반환
```

### 핵심: Gemini YouTube URL 직접 전달 방식

```python
# ai_engine.py 핵심 코드

response = await client.aio.models.generate_content(
    model="gemini-2.5-flash",
    contents=[
        prompt,                          # "레시피 JSON으로 뽑아줘" 지시문
        types.Part(
            file_data=types.FileData(
                file_uri="https://www.youtube.com/watch?v=xxxxx",
                mime_type="video/*",     # YouTube 영상이라고 명시
            )
        ),
    ],
)
```

**왜 이 방식인가?**

처음에는 yt-dlp로 영상 오디오를 다운로드한 뒤 Gemini에 업로드했습니다.
그런데 Render, Vercel 같은 클라우드 서버의 IP를 YouTube가 봇으로 인식해 차단하는 문제가 발생했습니다.

해결책: **URL만 넘기면 Gemini(Google 서버)가 직접 접근**합니다.
Google 서버가 YouTube(Google 소유)에 접근하므로 봇 차단이 없습니다.
덕분에 오디오 다운로드, ffmpeg, youtube-transcript-api 의존성이 모두 사라졌습니다.

### API 엔드포인트 목록

```
POST /extract-recipe
  요청: { youtube_url, mode("fast"/"precise"), force_refresh }
  응답: Recipe (제목, 재료, 단계, 맛 프로필, 꿀팁, 영상 ID)

POST /collections
  요청: { user_id, recipe_id, custom_tip }
  응답: { status: "success" }

GET /collections/{user_id}
  응답: CollectionItem[] (저장된 레시피 목록)

GET /health
  응답: 서버 상태 진단 정보
```

---

## 5. 프론트엔드 구조

### 페이지 구성

**홈 (`/`)**

- URL 입력 → 분석 요청 → 결과 표시가 한 페이지에서 이루어짐
- 상태 머신 방식: `IDLE → LOADING → RESULT / ERROR`
- "내 레시피북에 추가" 버튼으로 저장

**내 레시피북 (`/library`)**

- 저장된 레시피 카드 목록
- 각 카드: 제목, 맛 태그, 저장 날짜, 내 메모

**레시피 상세 (`/library/[id]`)**

- 저장된 레시피 전체 내용 표시
- 맛 프로필 + 재료 + 조리 단계 + 꿀팁 + 원본 영상 링크

### 주요 컴포넌트

```
FlavorProfile   : 짠맛/단맛/매운맛/신맛/기름기를 점 5개로 시각화
IngredientList  : 카테고리(주재료/부재료/양념)별로 묶어서 표시
StepTimeline    : 조리 단계를 번호 타임라인으로 표시
RecipeCard      : 레시피북 목록 아이템 (클릭 시 상세 이동)
LoadingScreen   : "AI가 분석 중..." 로딩 화면
SearchBox       : YouTube URL 입력 + 제출
```

### 데이터 타입 (`types.ts`)

```typescript
interface Recipe {
  id: number | null;
  title: string;
  summary: string;
  ingredients: Ingredient[]; // 재료 목록
  steps: RecipeStep[]; // 조리 단계
  flavor: FlavorProfile; // 맛 점수 (각 1~5)
  tip: string | null; // 꿀팁
  video_url: string | null;
  video_id: string | null;
}

interface FlavorProfile {
  saltiness: number; // 짠맛
  sweetness: number; // 단맛
  spiciness: number; // 매운맛
  sourness: number; // 신맛
  oiliness: number; // 기름기
}
```

---

## 6. 데이터베이스 구조

Supabase(PostgreSQL)를 사용합니다. 핵심 테이블 3개:

```sql
-- 레시피 캐시 (핵심 테이블)
-- video_id가 같으면 같은 영상 → 중복 분석 방지
recipes
  id            (자동 증가 숫자)
  title         (레시피 제목)
  summary       (요약 설명)
  ingredients   (재료 목록, JSON)
  steps         (조리 단계, JSON)
  flavor        (맛 점수, JSON)
  tip           (꿀팁)
  video_url     (유튜브 URL)
  video_id      (유튜브 영상 ID, 유니크 - 캐시 키)
  created_at

-- 사용자 레시피북
user_collections
  id
  user_id       (사용자 UUID)
  recipe_id     (recipes 테이블 참조)
  custom_tip    (내 메모)
  ingredient_adjustments  (재료 조정 기록, JSON)
  created_at

-- AI 분석 로그 (디버깅용)
analysis_logs
  video_url
  processing_time_ms  (분석 소요 시간)
  success
  created_at
```

---

## 7. 로컬 개발 환경 세팅

### 필요한 것

- Python 3.11 이상
- Node.js 18 이상
- Gemini API 키 ([Google AI Studio](https://aistudio.google.com)에서 발급, 무료)
- Supabase 프로젝트 ([supabase.com](https://supabase.com), 무료)

### 백엔드 실행

```bash
cd backend

# 환경변수 파일 만들기
# .env 파일을 만들고 아래 내용 입력
GEMINI_API_KEY=여기에_Gemini_키_입력
SUPABASE_URL=https://프로젝트ID.supabase.co
SUPABASE_KEY=여기에_Supabase_anon_키_입력

# 패키지 설치
pip install -r requirements.txt

# 서버 실행
uvicorn main:app --host 0.0.0.0 --port 8000
```

서버가 뜨면 `http://localhost:8000/docs` 에서 API 문서를 바로 볼 수 있습니다.

### 프론트엔드 실행

```bash
cd frontend

# 환경변수 파일 만들기
# .env.local 파일을 만들고 아래 내용 입력
VITE_API_URL=http://localhost:8000

# 패키지 설치
npm install

# 개발 서버 실행
npm run dev
```

`http://localhost:5173` 에서 확인할 수 있습니다.

### DB 초기화

Supabase 대시보드 → SQL Editor에서 `backend/init_db.sql` 내용을 실행하면 테이블이 생성됩니다.

---

## 8. 배포 구조

### 백엔드 — Render

- GitHub `main` 브랜치에 push하면 자동 배포
- `backend/` 디렉토리를 루트로 인식
- 환경변수 Render 대시보드에서 직접 설정:
  - `GEMINI_API_KEY`
  - `SUPABASE_URL`
  - `SUPABASE_KEY`

### 프론트엔드 — Vercel

- GitHub `main` 브랜치에 push하면 자동 배포
- `frontend/` 디렉토리를 루트로 인식
- 환경변수 Vercel 대시보드에서 설정:
  - `VITE_API_URL` = Render 백엔드 URL

### 배포 흐름

```
로컬에서 코드 수정
    → git push origin main
        → Render 자동 재배포 (약 3~5분)
        → Vercel 자동 재배포 (약 1~2분)
```

---

## 9. 현재 구현 상태 및 남은 작업

### 완료된 기능

- [x] YouTube URL → Gemini AI 레시피 추출
- [x] Supabase DB 캐싱 (같은 영상 재분석 방지)
- [x] 레시피 결과 화면 (재료 + 단계 + 맛 프로필 + 꿀팁)
- [x] 내 레시피북 저장 / 목록 조회
- [x] 레시피 상세 페이지 (`/library/[id]`)
- [x] 클라우드 배포 (Render + Vercel)
- [x] YouTube 봇 차단 해결 (Gemini URL 직접 전달 방식)
- [x] 요리가 아닌 영상 자동 걸러내기 (먹방, 브이로그 등)

### 남은 작업

- [ ] **로그인 (Auth)** — 현재 모든 사용자가 동일한 더미 UUID 사용
  - Supabase Auth (Google 소셜 로그인) 연동 예정
  - 로그인하면 내 레시피가 내 계정에만 저장됨

- [ ] **보안 (Supabase RLS)** — Auth 완료 후 진행
  - Row Level Security 활성화
  - 내 레시피는 나만 볼 수 있도록 DB 정책 설정

---

## 10. 주요 설계 결정 기록

> "왜 이렇게 만들었지?" 라는 질문에 대한 기록.

### YouTube 봇 차단 문제와 해결 과정

처음 설계: yt-dlp로 오디오 다운로드 → Gemini에 파일 업로드

문제: Render, Fly.io 같은 클라우드 서버의 IP를 YouTube가 데이터센터 봇으로 인식해 차단.
쿠키 인증을 시도했지만 쿠키가 만료되면 다시 차단되는 임시방편이었음.

최종 해결: Gemini 2.5 Flash가 YouTube URL을 직접 받아 분석하는 기능을 발견.
Google 서버(Gemini)가 YouTube(같은 Google 계열)에 접근하므로 봇 차단 없음.
오디오 다운로드, ffmpeg, youtube-transcript-api 의존성이 모두 제거됨.

### fast / precise 모드

초기에는 fast(자막 기반) / precise(오디오 기반) 두 모드로 나눴지만,
Gemini URL 직접 전달 방식으로 변경하면서 구분이 무의미해짐.
현재는 API 호환성을 위해 파라미터는 남겨두되, 내부적으로는 동일하게 동작.

### Supabase를 캐시 + DB로 동시 사용

같은 영상을 여러 명이 요청하면 Gemini를 반복 호출하는 비용 낭비가 생김.
video_id를 UNIQUE 키로 설정해 첫 분석 결과를 캐시처럼 저장.
두 번째 요청부터는 DB에서 즉시 반환 (응답 시간 30초 → 1초).

### SvelteKit + Svelte 5 선택

React보다 코드량이 적고 번들 크기가 작음.
Svelte 5의 `$state`, `$derived`, `$props` 반응형 문법이 직관적.
SvelteKit의 파일 기반 라우팅(폴더 구조 = URL 구조)이 명확함.
