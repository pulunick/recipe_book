"""
인증 모듈 스켈레톤 — 2단계 Supabase Auth 통합 시 구현 예정

사용 예시:
    from auth import require_auth

    @app.post("/protected")
    async def protected_endpoint(user = Depends(require_auth)):
        ...
"""

from fastapi import Depends, HTTPException, Request


async def get_current_user(request: Request) -> dict | None:
    """
    Authorization 헤더에서 Supabase JWT를 검증하고 사용자 정보를 반환합니다.
    TODO: 2단계에서 Supabase Auth JWT 검증 로직 구현
    """
    # authorization = request.headers.get("Authorization")
    # if not authorization or not authorization.startswith("Bearer "):
    #     return None
    # token = authorization.split(" ", 1)[1]
    # ... Supabase JWT 검증 ...
    return None


async def require_auth(user: dict | None = Depends(get_current_user)) -> dict:
    """
    인증 필수 엔드포인트용 의존성.
    TODO: 2단계에서 활성화
    """
    if user is None:
        raise HTTPException(status_code=401, detail="로그인이 필요합니다.")
    return user
