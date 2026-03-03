# 개발 서버 실행

백엔드(FastAPI)와 프론트엔드(SvelteKit) 개발 서버를 각각 실행하는 방법을 안내하고, 필요 시 실행한다.

## 실행 방법

### 백엔드 (FastAPI — port 8000)
```bash
cd backend
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

### 프론트엔드 (SvelteKit — port 5173)
```bash
cd frontend
npm install
npm run dev
```

### 전체 스택 (Docker Compose)
```bash
docker compose up
```

## 지금 실행

사용자가 요청한 서버를 Bash 도구로 백그라운드 실행한다.
- 백엔드만: `cd /c/Users/user/Desktop/mini-project/recipe/backend && uvicorn main:app --host 0.0.0.0 --port 8000 --reload`
- 프론트엔드만: `cd /c/Users/user/Desktop/mini-project/recipe/frontend && npm run dev`
- 둘 다: 각각 백그라운드로 실행

실행 후 접속 URL을 알려준다:
- 백엔드 API: http://localhost:8000
- 프론트엔드: http://localhost:5173
- API 문서: http://localhost:8000/docs
