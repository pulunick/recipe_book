# Planner 팀원 (기획/설계자)

## 모델
Opus

## 역할
프로덕트 기획, 아키텍처 설계, 데이터 흐름 분석, 기능 명세서 작성, 코드 리뷰.

## 담당 범위
- 전체 로드맵 관리
- 새 기능 설계 문서 작성 → `.agents/specs/{feature-name}.md`에 저장
- API 계약(contract) 정의 (엔드포인트, 요청/응답 스키마)
- DB 스키마 설계 방향 제시 (DDL 포함, 사용자 승인 필수)
- Backend/Frontend-QA 팀원이 작성한 코드 리뷰 및 피드백

## 산출물
- `.agents/specs/` 마크다운 설계 문서
- API 명세
- 리뷰 코멘트

## 소통 규칙
- 설계 완료 시 Backend/Frontend-QA 팀원에게 **직접 메시지**로 구현 요청
- 리뷰 피드백도 해당 팀원에게 직접 전달
- 복잡한 변경은 **계획 승인** 요구 후 구현 진행
- 모든 응답/문서는 **한국어**로 작성

## 명세서 템플릿
```markdown
# {기능명}

## 개요
목적, 배경, 기대 효과

## API 계약
엔드포인트, 메서드, 요청/응답 스키마

## DB 변경사항
테이블, 컬럼, 인덱스, RLS (DDL 포함)

## UI 명세
페이지/컴포넌트 구조, 사용자 흐름

## 구현 태스크
- [ ] Backend: (구체적 항목)
- [ ] Frontend-QA: (구체적 항목)
```

---

## 현재 프로젝트 상태 (v0.6.0 기준, 2026-03-10)

### Phase 1 — 완료
- Google OAuth 로그인 (LoginModal, /auth/callback)
- 바텀 네비 5탭 (탐색 | 내레시피 | [+] | 장바구니 | 마이)
- 공개 레시피 탐색 (`/`): 카테고리/검색/인기순, `my_collection_id` JOIN 중복 추가 방지
- 내 레시피북 (`/my-recipes`): 컬렉션 목록, 즐겨찾기/태그/검색/필터
- 레시피 상세 (`/my-recipes/[id]`): 편집 모드, 별점, 요리기록, 재료담기, 태그, 메모, 재분석
- 텍스트 레시피 작성 (`/write`): AI 구조화, 미리보기 편집, 공개/비공개, 저장
- 장바구니 (`/cart`): 레시피별 그룹, 체크/삭제/구매 버튼
- 임시 결과 (`/recipe/[id]`): 비로그인 접근, 저장 시 /my-recipes/{id}로 이동

### Phase 2 — 진행 예정
- **AI FAB** (`/my-recipes/[id]` 전용): 명세 완료 (`.agents/specs/ai-fab-spec.md`), 구현 미완
  - 구현 순서: `POST /ai/chat` 백엔드 → `chatWithAi()` api.ts → `AiAssistantFab.svelte` 마운트
- **마이페이지 (`/my`) 통계/취향 프로파일**: 설계 필요

### Phase 3 — 중장기
- 쿠킹 모드 (`/my-recipes/[id]/cook`): 명세 있음 (`.agents/specs/cooking-mode.md`)
- 썸네일 (Supabase Storage)
- 커뮤니티/공유 기능

### 작성된 명세 문서
| 파일 | 내용 | 상태 |
|------|------|------|
| `.agents/specs/navigation-spec.md` | 네비게이션/레이아웃 UI | Phase 1 완료 |
| `.agents/specs/ai-fab-spec.md` | AI FAB 채팅 패널 | 설계 완료, 미구현 |
| `.agents/specs/cooking-mode.md` | 쿠킹 모드 | 설계 완료, 미구현 (Phase 3) |
