-- 005: recipes 테이블에 video_title 컬럼 추가
-- YouTube 영상의 원본 제목을 저장하기 위한 필드
-- 실행 전 사용자 승인 필요

ALTER TABLE recipes ADD COLUMN IF NOT EXISTS video_title TEXT;
