-- 004_guest_user.sql
-- 로그인 없이 사용하는 MVP 개발용 게스트 유저 추가
-- collection_tags.user_id FK(→ users.id) 만족을 위해 필요

INSERT INTO users (id, email, nickname)
VALUES ('00000000-0000-0000-0000-000000000000', 'guest@recipe-ai.app', '게스트')
ON CONFLICT (id) DO NOTHING;
