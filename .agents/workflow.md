# 에이전트 팀 워크플로우

> 이 워크플로우는 Claude Code 공식 Agent Teams 기능을 사용한다.
> `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` 활성화 필수.

## 팀 생성

리더(메인 세션)에게 자연어로 요청:

```
에이전트 팀을 만들어줘. 세 명의 팀원을 생성해:
- Planner: 기획/설계/코드리뷰 담당 (Opus 사용). 계획 승인을 요구해줘.
- Backend: FastAPI/DB 구현 담당 (Sonnet 사용)
- Frontend-QA: SvelteKit UI/QA 담당 (Sonnet 사용)
```

## 워크플로우 패턴

### 패턴 1: 새 기능 개발
```
사용자 → 리더: "로그인 기능 만들어줘"
리더 → Planner: 설계 요청 (계획 승인 모드)
Planner → .agents/specs/login.md 작성
Planner → 리더: 계획 승인 요청
리더 → 계획 승인
Planner → Backend: "인증 API 구현해줘" (직접 메시지)
Planner → Frontend-QA: "로그인 UI 구현해줘" (직접 메시지)
Backend ↔ Frontend-QA: API 계약 조율 (직접 메시지)
Backend → Planner: 구현 완료, 리뷰 요청
Frontend-QA → Planner: 구현 완료, 리뷰 요청
Planner → 리뷰 피드백 전달
```

### 패턴 2: 단일 영역 작업
```
사용자 → 리더: "헬스체크 엔드포인트 추가해줘"
리더 → Backend: 직접 작업 할당
Backend → 구현 완료 보고
```

### 패턴 3: 병렬 조사/리뷰
```
사용자 → 리더: "전체 코드 리뷰해줘"
리더 → 팀원 3명에게 각각 영역별 리뷰 할당
  Planner: 아키텍처/설계 리뷰
  Backend: 백엔드 코드 품질 리뷰
  Frontend-QA: 프론트엔드 코드 + QA 리뷰
팀원들 → 리더: 각자 결과 보고
리더 → 종합 리포트 작성
```

## 작업 관리

- 리더가 공유 작업 목록에 작업 생성
- 팀원들이 미할당 작업을 자체 청구
- 작업 종속성 자동 관리 (선행 작업 완료 시 후속 작업 차단 해제)
- 팀원당 5-6개 작업 유지 권장

## 파일 충돌 방지 규칙

| 팀원 | 수정 가능 | 수정 금지 |
|------|-----------|-----------|
| Planner | `.agents/specs/` | `backend/`, `frontend/` |
| Backend | `backend/`, SQL 파일 | `frontend/` |
| Frontend-QA | `frontend/` | `backend/` |

## 팀 정리

작업 완료 후:
1. 리더에게 팀원 종료 요청: "팀원들 종료해줘"
2. 모든 팀원 종료 확인 후: "팀 정리해줘"

> 반드시 리더를 통해 정리할 것. 팀원이 직접 정리하면 리소스가 비정상 상태로 남을 수 있음.
