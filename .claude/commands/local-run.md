# 로컬 실행

해먹당 전체 스택을 로컬에서 실행한다. 배포 전 최종 검증용.

## Docker Compose 전체 실행 (권장)

```bash
cd /c/Users/user/Desktop/mini-project/recipe
docker compose up --build
```

- 백엔드: http://localhost:8000
- 프론트엔드: http://localhost:80
- API 문서: http://localhost:8000/docs

## 개별 실행 (개발 시)

### 프론트엔드 개발 서버
```bash
cd /c/Users/user/Desktop/mini-project/recipe/frontend
npm run dev
```
http://localhost:5173

### 백엔드 개발 서버
```bash
cd /c/Users/user/Desktop/mini-project/recipe/backend
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

## 환경변수 확인
Docker 실행 전 `backend/.env` 파일 존재 여부 확인:
```bash
ls /c/Users/user/Desktop/mini-project/recipe/backend/.env
```

필요한 변수:
- `GEMINI_API_KEY`
- `SUPABASE_URL`
- `SUPABASE_KEY`

## 주의사항
- Docker Desktop이 실행 중이어야 함
- 첫 빌드는 시간이 걸릴 수 있음 (ffmpeg 포함)
- 배포 승인은 직접 테스트 후 사용자가 결정
