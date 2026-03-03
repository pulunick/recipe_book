# DB 마이그레이션 실행

`backend/migrations/` 디렉토리의 SQL 파일을 Supabase에 적용한다.

## 마이그레이션 파일 목록 확인

`backend/migrations/` 디렉토리의 파일을 읽고 적용되지 않은 마이그레이션을 찾는다.

## 실행 절차

1. `backend/migrations/` 에서 SQL 파일 목록을 보여준다
2. 적용할 파일 내용을 Read 도구로 읽어 사용자에게 미리 보여준다
3. **사용자 승인을 받은 후** `supabase-recipes` MCP 도구로 SQL을 실행한다
4. 성공/실패 결과를 알린다

## 주의사항
- DDL/DML은 반드시 사용자 승인 후 실행 (CLAUDE.md 규칙)
- `supabase-prod`는 읽기 전용 — 절대 쓰기 불가
- 마이그레이션은 순서대로 실행 (001 → 002 → 003)

## 현재 대기 중인 마이그레이션

`backend/migrations/003_tag_system.sql` — 태그 & 아카이빙 시스템 DB 변경사항
- user_collections 컬럼 추가 (is_favorite, my_rating, cooked_count, last_cooked_at, category_override)
- collection_tags 테이블 신규 생성
- collection_tag_items 테이블 신규 생성
- 인덱스 6개 추가
