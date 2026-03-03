# 코드 품질 검사

프론트엔드 타입 검사 및 빌드 검증을 실행한다.

## 실행 순서

### 1. 프론트엔드 타입 체크
```bash
cd /c/Users/user/Desktop/mini-project/recipe/frontend && npm run check
```
svelte-check로 TypeScript 오류 및 Svelte 컴포넌트 타입 오류를 검출한다.

### 2. 프론트엔드 빌드 테스트
```bash
cd /c/Users/user/Desktop/mini-project/recipe/frontend && npm run build
```
프로덕션 빌드가 성공하는지 확인한다.

### 3. 백엔드 임포트 검증
```bash
cd /c/Users/user/Desktop/mini-project/recipe/backend && python -c "import main; print('OK')"
```
FastAPI 앱이 정상적으로 임포트되는지 확인한다.

## 오류 발생 시

오류 내용을 분석하고 수정 방법을 제안한다. 명확한 오류라면 직접 수정한다.
