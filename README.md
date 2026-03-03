# 마레픽 — My Recipe Pick

유튜브 요리 영상 URL을 붙여넣으면 AI가 레시피를 깔끔하게 정리해주는 웹 서비스.

## 기술 스택

| 영역           | 기술                                     |
| -------------- | ---------------------------------------- |
| **프론트엔드** | SvelteKit (Svelte 5) + TypeScript        |
| **백엔드**     | FastAPI + Python 3.11                    |
| **AI**         | Google Gemini 2.5 Flash (음성/자막 분석) |
| **DB**         | Supabase (PostgreSQL)                    |
| **배포**       | Vercel (프론트) + Railway (백엔드)       |

## 로컬 실행

```bash
# 백엔드
cd backend
cp .env.example .env   # API 키 설정
pip install -r requirements.txt
uvicorn main:app --port 8000

# 프론트엔드
cd frontend
npm install
npm run dev
```

## 브랜치 전략 (GitHub Flow)

간결한 **GitHub Flow** 기반. 소규모 프로젝트에 적합.

```
main ─────────────────────────────────── (항상 배포 가능 상태)
  └─ feat/recipe-detail ──── PR ──→ merge
  └─ fix/cors-issue ──────── PR ──→ merge
  └─ deploy/vercel-setup ─── PR ──→ merge
```

### 규칙

| 규칙                  | 설명                                                            |
| --------------------- | --------------------------------------------------------------- |
| `main` 직접 커밋 금지 | 모든 변경은 브랜치 → PR → merge                                 |
| 브랜치 네이밍         | `feat/기능명`, `fix/버그명`, `deploy/배포작업`, `docs/문서작업` |
| PR merge 전           | `npm run check` (프론트), 빌드 성공 확인                        |
| merge 후              | 브랜치 삭제                                                     |

### 브랜치 종류

| 접두사      | 용도        | 예시                       |
| ----------- | ----------- | -------------------------- |
| `feat/`     | 새 기능     | `feat/recipe-detail-page`  |
| `fix/`      | 버그 수정   | `fix/cors-port-mismatch`   |
| `deploy/`   | 배포/인프라 | `deploy/vercel-adapter`    |
| `docs/`     | 문서        | `docs/api-guide`           |
| `refactor/` | 리팩토링    | `refactor/component-split` |

## 배포 구성

### 프론트엔드 → Vercel

- `frontend/` 디렉토리를 루트로 설정
- SvelteKit `@sveltejs/adapter-vercel` 사용
- 환경변수: `VITE_API_URL` = Railway 백엔드 URL

### 백엔드 → Railway

- `backend/Dockerfile` 기반 배포
- 환경변수: `GEMINI_API_KEY`, `SUPABASE_URL`, `SUPABASE_KEY`, `ALLOWED_ORIGINS`

### DB → Supabase

- 기존 Supabase 프로젝트 유지
- 스키마: `backend/init_db.sql` 참조

## 프로젝트 구조

```
recipe/
├── backend/          # FastAPI 서버
│   ├── main.py       # 엔드포인트 (extract-recipe, collections)
│   ├── ai_engine.py  # Gemini AI 연동
│   ├── schemas.py    # Pydantic 모델
│   ├── utils.py      # yt-dlp 유틸
│   └── Dockerfile
├── frontend/         # SvelteKit 앱
│   └── src/
│       ├── lib/
│       │   ├── types.ts          # 타입 정의
│       │   ├── api.ts            # API 호출 모듈
│       │   └── components/       # 7개 UI 컴포넌트
│       └── routes/
│           ├── +page.svelte      # 홈 (URL 입력 → 결과)
│           └── library/+page.svelte  # 내 레시피북
├── planner/          # 기획/설계 문서
├── prd/              # 디자인 에셋/시안
└── docker-compose.yml
```
