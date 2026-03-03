-- 006: recipes 테이블에 channel_name 컬럼 추가
-- YouTube 채널명(uploader)을 저장하기 위한 필드
-- 실행 전 사용자 승인 필요

ALTER TABLE recipes ADD COLUMN IF NOT EXISTS channel_name TEXT;
