# 에이전트 팀 구성

이 프로젝트의 표준 에이전트 팀을 구성한다.

## 팀 구성원

| 팀원 | 모델 | 역할 |
|------|------|------|
| Planner | Opus | 기획·설계·코드리뷰, `.agents/specs/` 문서 작성 |
| Backend | Sonnet | FastAPI·DB·Python — `backend/` 전담 |
| Frontend-QA | Sonnet | SvelteKit UI·QA — `frontend/` 전담 |

## 실행

TeamCreate로 팀을 생성하고, 각 팀원을 Task 도구로 스폰한다.

팀 이름은 현재 작업 내용을 반영하여 지정한다 (예: `recipe-tag-impl`, `recipe-auth`).

## 팀 운영 원칙

1. Planner가 `.agents/specs/{기능명}.md`에 설계 문서 작성 후 구현 시작
2. Backend는 `backend/` 만, Frontend-QA는 `frontend/` 만 수정
3. DDL/CUD 작업은 반드시 사용자 승인 후 실행
4. 팀원 간 소통은 SendMessage 도구 사용 (텍스트 출력은 전달 안 됨)
5. 태스크 완료 시 TaskUpdate로 completed 처리 필수
6. 세션 재개 시 기존 팀원은 소멸 → 새 팀원 생성 필요

## 참고 파일

- 팀원 역할 상세: `.agents/planner.md`, `.agents/backend.md`, `.agents/frontend-qa.md`
- 워크플로우: `.agents/workflow.md`
- 설계 문서: `.agents/specs/`
