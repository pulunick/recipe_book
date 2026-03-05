# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

"해먹당 (My Recipe Pick)" — a system that extracts structured recipe data from YouTube cooking videos using Gemini multimodal AI (audio analysis). Users paste a YouTube URL, the backend downloads audio, sends it to Gemini for analysis, and returns structured recipe JSON (ingredients, steps, flavor profile). Results are cached in Supabase to avoid redundant AI calls.

## Language Rule

모든 응답, 문서화, 주석 및 설명은 **한국어**로 작성. 코드 변수명과 기술 용어는 영어 병용 가능.

## Commands

### Backend (FastAPI + Python 3.11)

```bash
# Run locally
cd backend
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8000

# Docker (from project root)
docker compose up backend
```

### Frontend (SvelteKit + Svelte 5 + TypeScript)

```bash
cd frontend
npm install
npm run dev          # dev server
npm run build        # production build
npm run check        # svelte-check type checking
```

### Full Stack (Docker Compose)

```bash
docker compose up          # backend on :8000, frontend (nginx) on :80
```

## Architecture

### Backend (`backend/`)

- **main.py** — FastAPI app with two endpoints:
  - `POST /extract-recipe` — core flow: extract video ID → check Supabase cache → download audio via yt-dlp → Gemini analysis → validate with Pydantic → save to DB → return Recipe
  - `POST /collections` — save recipe to user's personal collection with custom tips and ingredient adjustments
- **ai_engine.py** — Gemini 2.5 Flash integration. Uploads audio file, sends multimodal prompt (audio + text), parses JSON response into `Recipe` model. Includes `is_recipe` check to reject non-cooking videos.
- **schemas.py** — Pydantic v2 models: `Recipe`, `Ingredient`, `RecipeStep`, `FlavorProfile`, `CollectionRequest`. Flavor uses 5 axes (saltiness, sweetness, spiciness, sourness, oiliness) scored 1–5.
- **utils.py** — yt-dlp wrappers: `download_audio()`, `get_video_metadata()`, `get_video_id_fallback()` (regex fallback for video ID extraction)
- **database.py** — Supabase client factory from env vars (`SUPABASE_URL`, `SUPABASE_KEY`)
- **init_db.sql** — Full schema: `recipes`, `users`, `user_collections`, `categories`, `recipe_categories`, `cooking_history`, `analysis_logs`

### Frontend (`frontend/`)

SvelteKit project (Svelte 5, adapter-auto).

#### 레이아웃 구조
- `max-width: 480px` 중앙 고정 (데스크탑도 모바일 앱 형태)
- 슬림 헤더: 로고(좌) + 로그인/프로필(우)만 표시
- 바텀 네비게이션 5탭: `탐색(홈) | 내레시피 | [+] | 장바구니 | 마이`
- [+] 중앙 버튼 → AddRecipeSheet (유튜브 분석 / 텍스트 작성 선택)
- AI 어시스턴트 FAB: `/my-recipes/[id]` 전용 (요리 질문, 재료 대체, 단위 변환)

#### 라우팅
| 경로 | 페이지 | 비로그인 |
|------|--------|----------|
| `/` | 탐색(홈) — 공개 레시피 | 허용 |
| `/my-recipes` | 내 레시피 서랍 | 로그인 필요 |
| `/my-recipes/[id]` | 레시피 상세 + AI FAB | 로그인 필요 |
| `/my-recipes/[id]/cook` | 쿠킹 모드 (BottomNav 숨김) | 로그인 필요 |
| `/cart` | 장바구니 | 로그인 필요 |
| `/my` | 마이페이지 | 로그인 필요 |
| `/recipe/[id]` | 임시 분석 결과 | 허용 |
| `/auth/callback` | OAuth 콜백 | — |

#### 주요 컴포넌트
- **BottomNav.svelte** — 하단 고정 네비게이션 (쿠킹 모드에서 숨김)
- **AddRecipeSheet.svelte** — [+] 탭 바텀시트 (YouTube 분석 / 텍스트 작성)
- **AiAssistantFab.svelte** — AI 어시스턴트 플로팅 버튼 + 채팅 패널

상세 명세: `.agents/specs/navigation-spec.md`

### Database (Supabase / PostgreSQL)

- `recipes` table is the canonical cache — keyed by `video_id` (unique). `ingredients`, `steps`, `flavor` stored as JSONB.
- `user_collections` links users to recipes with personal customization (`custom_tip`, `ingredient_adjustments`).
- Cascade deletes on foreign keys.

### Data Flow

1. YouTube URL → extract `video_id` (yt-dlp, regex fallback)
2. Check `recipes` table by `video_id` (cache hit → return immediately)
3. Cache miss → download audio (mp3 via yt-dlp + ffmpeg) → upload to Gemini
4. Gemini returns structured JSON → Pydantic validation → save to `recipes` → return
5. Temp audio files are always cleaned up in `finally` block

## Environment Variables (`backend/.env`)

- `GEMINI_API_KEY` — Google Gemini API key
- `SUPABASE_URL` — Supabase project URL
- `SUPABASE_KEY` — Supabase anon/service key

## Key Rules

- **CUD/DDL operations require explicit user approval** before execution. Show the SQL/code and explain impact first.
- `supabase-prod` is read-only — never write to production.
- Non-recipe videos (먹방, vlogs, music) are detected by Gemini via `is_recipe` flag and rejected without DB storage.
- Backend requires **ffmpeg** as a system dependency (installed in Docker image).

## Agent Team

> **실험적 기능**: 에이전트 팀은 기본적으로 비활성화되어 있다.
> `.claude/settings.json`에서 `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`로 활성화 완료.
> 세션 재개, 작업 조율, 종료 동작 관련 알려진 제한 사항이 있다.

### 팀 구성

병렬 작업이 필요한 경우, 리더(메인 세션)에게 다음과 같이 자연어로 팀 생성을 요청한다:

```
에이전트 팀을 만들어줘. 세 명의 팀원을 생성해:
- Planner: 기획/설계/코드리뷰 담당 (Opus 사용)
- Backend: FastAPI/DB 구현 담당 (Sonnet 4.6 사용)
- Frontend-QA: SvelteKit UI/QA 담당 (Sonnet 4.6 사용)
```

### 팀원 역할

| 팀원            | 모델       | 역할                     | 담당 범위                                 |
| --------------- | ---------- | ------------------------ | ----------------------------------------- |
| **Planner**     | Opus       | 기획, 설계, 코드 리뷰    | 로드맵, 설계 문서, API 계약, DB 설계 방향 |
| **Backend**     | Sonnet 4.6 | FastAPI, DB, Python 구현 | `backend/` 전체, SQL                      |
| **Frontend-QA** | Sonnet 4.6 | SvelteKit UI, QA 검증    | `frontend/` 전체                          |

각 팀원의 상세 역할 정의는 `.agents/` 디렉토리 참조. 팀원들은 이 CLAUDE.md를 자동으로 로드한다.

### 팀 운영 원칙

- **직접 통신**: 팀원끼리 메일박스를 통해 직접 메시지를 주고받는다
- **공유 작업 목록**: 리더가 작업을 생성하면 팀원들이 자체 청구하여 진행
- **파일 충돌 방지**: 각 팀원은 자기 담당 파일만 수정 (Backend→`backend/`, Frontend-QA→`frontend/`)
- **계획 승인**: 복잡한 작업은 Planner에게 계획 승인을 요구한 후 구현 진행
- **DDL/CUD 작업**: 반드시 사용자 승인 후 실행
- **설계 문서**: Planner가 `.agents/specs/`에 기능 명세를 작성하면 다른 팀원이 참조

### 제한 사항

- 세션 재개(`/resume`) 시 in-process 팀원이 복원되지 않음 → 새 팀원 생성 필요
- 작업 상태가 지연될 수 있음 → 리더가 수동으로 상태 확인
- 팀원 종료가 느릴 수 있음
- 세션당 하나의 팀만 운영 가능
- 분할 창 모드는 tmux 또는 iTerm2 필요 (Windows Terminal 미지원)
