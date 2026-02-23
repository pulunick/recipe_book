# 갭 분석 및 우선순위별 TODO

## 1. 현재 상태 요약

| 영역 | 완성도 | 요약 |
|------|--------|------|
| 백엔드 핵심 (AI 파이프라인) | **90%** | 레시피 추출 + 캐싱 + 에러 핸들링 작동 |
| 백엔드 보조 (보관함/인증) | **20%** | POST 저장만 구현, GET 조회 및 인증 미구현 |
| 프론트엔드 UI | **50%** | 3개 주요 화면 골격 존재, API 연동 미완성 |
| 프론트엔드 UX | **20%** | 반응형 미대응, 에러 처리 미흡, 접근성 미고려 |
| 데이터베이스 | **60%** | 스키마 7개 테이블 정의됨, 일부만 실제 사용 |
| 인프라 | **40%** | Docker Compose 존재, 프론트엔드 빌드 미연동 |
| 문서화 | **30%** | PRD 존재하나 코드와 불일치, API 문서 미정비 |

---

## 2. 갭 상세 분석

### 2.1 백엔드 갭

#### [GAP-B1] 보관함 조회 API 부재
- **현상**: 프론트엔드 `library/+page.svelte`에서 `GET /collections/{user_id}`를 호출하나 백엔드에 해당 엔드포인트가 없음
- **영향**: "나의 주방" 페이지가 완전히 작동하지 않음
- **해결**: `GET /collections/{user_id}` 엔드포인트 추가, 연관 레시피 데이터 JOIN 반환

#### [GAP-B2] 인증 시스템 미구현
- **현상**: `auth.py`에 스켈레톤만 존재 (모든 함수가 `None` 반환)
- **영향**: 사용자별 데이터 분리 불가, 현재 하드코딩된 UUID 사용
- **해결**: Supabase Auth JWT 검증 로직 구현

#### [GAP-B3] analysis_logs의 raw_response 미기록
- **현상**: `main.py:177`에서 `raw_response`에 항상 `None` 전달 (변수 초기화 후 갱신하지 않음)
- **영향**: AI 응답 원본 디버깅 불가
- **해결**: `ai_engine.py`에서 Gemini 원본 응답을 반환하거나 main.py에서 캡처

#### [GAP-B4] 보관함 삭제/수정 API 부재
- **현상**: 저장만 가능, 삭제/수정 불가
- **영향**: 사용자 경험 제한
- **해결**: `DELETE /collections/{id}`, `PATCH /collections/{id}` 추가

---

### 2.2 프론트엔드 갭

#### [GAP-F1] 저장하기 버튼 API 미연동
- **현상**: 결과 페이지의 "저장하기" 버튼이 `alert('저장되었습니다!')` 만 실행
- **영향**: 실제 보관함 저장 기능 작동하지 않음
- **해결**: `POST /collections` API 호출 연동

#### [GAP-F2] 에러 처리 미흡
- **현상**: API 에러 시 `response.ok` 체크만으로 단순 메시지 표시. 백엔드의 구조화된 `ErrorResponse`(error_code, message)를 활용하지 않음
- **영향**: 사용자에게 유의미한 에러 정보 미전달 (예: "멤버십 전용" vs "레시피 아님" 구분 불가)
- **해결**: 에러 응답 파싱 후 error_code별 분기 처리

#### [GAP-F3] 반응형 디자인 미대응
- **현상**: 고정 width 레이아웃 (result-container: `grid-template-columns: 450px 1fr`)
- **영향**: 모바일/태블릿에서 사용 불가
- **해결**: 미디어 쿼리 추가, 유연한 그리드 레이아웃

#### [GAP-F4] 나의 주방 페이지 미완성
- **현상**: 백엔드 API 없어 데이터 로드 불가, 카드에서 상세 보기 미연결
- **영향**: 보관함 기능 전체가 미작동
- **해결**: GAP-B1 해결 후 프론트엔드 연동

#### [GAP-F5] 로그인 기능 미구현
- **현상**: "로그인" 버튼이 UI에만 존재, 기능 없음
- **영향**: 사용자 식별 불가, 개인화 기능 사용 불가
- **해결**: GAP-B2 해결 후 Supabase Auth UI 연동

#### [GAP-F6] 카테고리 필터 미구현
- **현상**: 디자인 시안(prd/web design.png)에 카테고리 탭(전체/매운맛/국/찌개/파티/반찬)이 있으나 코드에 없음
- **영향**: 시안 대비 기능 누락
- **해결**: 카테고리 API 및 UI 구현

#### [GAP-F7] YouTube 썸네일 URL 파싱 취약
- **현상**: 결과 페이지에서 `new URL(youtubeUrl).searchParams.get('v')`로 썸네일 추출. `youtu.be/ID` 형식 URL에서는 실패
- **영향**: 단축 URL 사용 시 썸네일 미표시
- **해결**: video_id를 백엔드 응답의 `recipe.video_id`에서 가져오도록 변경

---

### 2.3 데이터베이스 갭

#### [GAP-D1] 미사용 테이블
- **현상**: `categories`, `recipe_categories`, `cooking_history`, `users` 테이블이 정의만 되고 API에서 전혀 사용되지 않음
- **영향**: 스키마와 실제 사용 사이에 괴리
- **해결**: 2단계 구현 시 순차 연동, 또는 현재 불필요한 테이블은 문서에 "예정" 표기

#### [GAP-D2] RLS 미적용
- **현상**: `init_db.sql`에서 RLS 정책이 주석 처리 상태
- **영향**: 모든 사용자가 모든 데이터에 접근 가능 (보안 취약)
- **해결**: 인증 구현 후 RLS 정책 활성화

---

### 2.4 인프라 갭

#### [GAP-I1] 프론트엔드 Docker 빌드 미설정
- **현상**: `docker-compose.yml`에서 프론트엔드를 `nginx:alpine`으로 소스 디렉토리 직접 서빙
- **영향**: SvelteKit 빌드 결과물이 아닌 소스가 노출됨 (프로덕션 사용 불가)
- **해결**: 프론트엔드 Dockerfile 추가 (Node.js 빌드 + nginx 서빙), 또는 adapter-node 사용

#### [GAP-I2] 환경변수 관리
- **현상**: 백엔드 API URL이 프론트엔드 코드에 `http://localhost:8000`으로 하드코딩
- **영향**: 환경별(dev/staging/prod) 배포 불가
- **해결**: SvelteKit 환경변수 (`$env/static/public` 또는 `$env/dynamic/public`) 활용

---

### 2.5 문서 갭

#### [GAP-DOC1] PRD와 실제 코드 불일치
- **현상**:
  - `prd/recipe_ai_spec.md`: Flutter → 실제 SvelteKit
  - `prd/recipe_ai_spec.md`: Gemini 1.5 Flash → 실제 2.5 Flash
  - `@docs/implemented_features.md`: "Vanilla JS" → 실제 Svelte 5
- **영향**: 새 팀원 혼란, 기획과 실제 사이 신뢰도 저하
- **해결**: 기존 PRD 문서에 변경 사항 주석 추가, 또는 이 planner/ 문서를 정본으로 지정

---

## 3. 우선순위별 TODO

### P0 — 즉시 해결 (기본 기능 작동에 필수)

| ID | 갭 | 담당 | 작업 내용 |
|----|----|------|-----------|
| T-01 | GAP-B1 | Backend | `GET /collections/{user_id}` 엔드포인트 구현 (레시피 JOIN 포함) |
| T-02 | GAP-F1 | Frontend | 결과 페이지 "저장하기" 버튼에 `POST /collections` API 연동 |
| T-03 | GAP-F4 | Frontend | 나의 주방 페이지 백엔드 연동 (T-01 완료 후) |
| T-04 | GAP-F2 | Frontend | API 에러 응답 파싱 및 error_code별 사용자 메시지 표시 |
| T-05 | GAP-F7 | Frontend | 썸네일 URL을 `recipe.video_id` 기반으로 수정 |

### P1 — 단기 개선 (사용자 경험 개선)

| ID | 갭 | 담당 | 작업 내용 |
|----|----|------|-----------|
| T-06 | GAP-F3 | Frontend | 반응형 CSS 추가 (모바일/태블릿 대응) |
| T-07 | GAP-B4 | Backend | 보관함 삭제 API (`DELETE /collections/{id}`) |
| T-08 | GAP-B3 | Backend | analysis_logs에 Gemini raw_response 기록 |
| T-09 | GAP-I2 | Frontend | API URL 환경변수화 (하드코딩 제거) |
| T-10 | GAP-I1 | Infra | 프론트엔드 Dockerfile 작성 (빌드 + nginx 서빙) |

### P2 — 중기 과제 (2단계 기능)

| ID | 갭 | 담당 | 작업 내용 |
|----|----|------|-----------|
| T-11 | GAP-B2 | Backend | Supabase Auth JWT 검증 구현 (`auth.py`) |
| T-12 | GAP-F5 | Frontend | 로그인/회원가입 UI + Supabase Auth SDK 연동 |
| T-13 | GAP-D2 | DB | RLS 정책 활성화 (인증 구현 후) |
| T-14 | GAP-F6 | Frontend | 카테고리 필터 UI + 백엔드 API |
| T-15 | GAP-D1 | Backend | categories, cooking_history 테이블 API 연동 |
| T-16 | GAP-DOC1 | Planner | 기존 PRD 문서 업데이트 또는 폐기 결정 |

---

## 4. 권장 실행 순서

```
[P0 단계] 기본 기능 완성
  T-01 (Backend: 보관함 조회 API)
    → T-03 (Frontend: 나의 주방 연동)
  T-02 (Frontend: 저장 API 연동)
  T-04 (Frontend: 에러 처리)
  T-05 (Frontend: 썸네일 수정)

[P1 단계] 사용자 경험 개선
  T-06 ~ T-10 (병렬 가능)

[P2 단계] 개인화 기반
  T-11 (Backend: 인증)
    → T-12 (Frontend: 로그인)
    → T-13 (DB: RLS)
  T-14 ~ T-16 (병렬 가능)
```

---

*이 문서는 초안이며, 팀 리뷰를 통해 수정될 예정입니다.*
*최종 수정: 2026-02-12*
