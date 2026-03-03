# 새 기능 추가

새 기능 구현을 위한 표준 플로우를 실행한다.

## 플로우

### 1. 설계 문서 작성
기능 요구사항을 파악하고 `.agents/specs/{기능명}.md`에 명세 작성:
- 개요 및 목적
- DB 변경사항 (DDL 포함)
- API 엔드포인트 (요청/응답 스키마)
- UI 명세 (페이지/컴포넌트 구조)
- 구현 태스크 목록

### 2. 사용자 승인
설계 문서를 보여주고 승인을 받는다.

### 3. 팀 구성 (필요 시)
복잡한 기능이면 `/team` 스킬로 에이전트 팀을 구성한다.

### 4. DB 마이그레이션
SQL 작성 → 사용자 승인 → `/migrate` 스킬로 적용

### 5. 백엔드 구현
`backend/schemas.py`에 Pydantic 모델 추가, `backend/main.py`에 엔드포인트 추가

### 6. 프론트엔드 구현
SvelteKit 페이지/컴포넌트 작성, `$lib/api.ts` 함수 추가

### 7. 검증
`/check` 스킬로 타입 오류 확인

## 참고 아키텍처

- 설계 문서: `@docs/collection_tag_system.md` (태그 시스템 — 좋은 예시)
- DB 스키마: `@docs/db_schema.md`
- 구현 기능 목록: `@docs/implemented_features.md`
