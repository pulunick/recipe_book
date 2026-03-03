# 배포 전 점검

프로덕션 배포 전 필수 확인 사항을 체크한다.

## 체크리스트

### 환경변수
- [ ] `backend/.env`에 `GEMINI_API_KEY`, `SUPABASE_URL`, `SUPABASE_KEY` 설정 확인
- [ ] 프론트엔드 `VITE_API_URL`이 프로덕션 백엔드 URL로 설정됐는지 확인

### 코드 품질
- [ ] `npm run check` — 타입 오류 없음
- [ ] `npm run build` — 빌드 성공
- [ ] `python -c "import main"` — 백엔드 임포트 성공

### DB
- [ ] 마이그레이션 파일이 모두 적용됐는지 확인
- [ ] `backend/migrations/` 파일 목록과 실제 DB 스키마 비교

### 보안
- [ ] `.env` 파일이 `.gitignore`에 포함됐는지 확인
- [ ] CORS 설정이 프로덕션 도메인을 허용하는지 확인 (`ALLOWED_ORIGINS` 환경변수)

## 실행

각 항목을 순서대로 검사하고 결과를 보고한다. 문제 발견 시 수정 방법을 제안한다.

## 현재 배포 환경

- 백엔드: Render (Docker)
- 프론트엔드: Vercel (SvelteKit adapter-auto)
- DB: Supabase (PostgreSQL)
- 참고: `RENDER_ENV_SETUP.md`
