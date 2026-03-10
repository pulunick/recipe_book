from typing import Optional
from fastapi import Header, HTTPException
from database import get_supabase_client
from logger import get_logger

logger = get_logger(__name__)


async def get_current_user_optional(authorization: Optional[str] = Header(None)) -> Optional[str]:
    """인증 토큰이 있으면 user_id 반환, 없거나 유효하지 않으면 None 반환 (비로그인 허용 엔드포인트용)."""
    if not authorization or not authorization.startswith("Bearer "):
        return None
    token = authorization.split(" ", 1)[1]
    supabase = get_supabase_client()
    if not supabase:
        return None
    try:
        response = supabase.auth.get_user(token)
        return response.user.id if response.user else None
    except Exception:
        return None


async def get_current_user(authorization: Optional[str] = Header(None)) -> str:
    """Authorization 헤더에서 Supabase JWT를 검증하고 user_id를 반환한다."""
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=401,
            detail={"error_code": "UNAUTHORIZED", "message": "로그인이 필요합니다."},
        )

    token = authorization.split(" ", 1)[1]
    supabase = get_supabase_client()
    if not supabase:
        raise HTTPException(
            status_code=500,
            detail={"error_code": "DB_CONNECTION_FAILED", "message": "서버 오류가 발생했습니다."},
        )

    try:
        response = supabase.auth.get_user(token)
        if not response.user:
            raise HTTPException(
                status_code=401,
                detail={"error_code": "INVALID_TOKEN", "message": "유효하지 않은 인증 토큰입니다."},
            )
        return response.user.id
    except HTTPException:
        raise
    except Exception as e:
        logger.warning("JWT 검증 실패: %s", e)
        raise HTTPException(
            status_code=401,
            detail={"error_code": "INVALID_TOKEN", "message": "인증 토큰 검증에 실패했습니다."},
        )
