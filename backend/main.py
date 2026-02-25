import os
import time
from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import ValidationError

from schemas import Recipe, CollectionRequest, ExtractRecipeRequest, ErrorResponse
from utils import extract_video_id, get_video_metadata
from ai_engine import extract_recipe_with_gemini
from database import get_supabase_client
from logger import get_logger

logger = get_logger(__name__)

app = FastAPI(
    title="Recipe AI Extraction API",
    responses={
        400: {"model": ErrorResponse},
        403: {"model": ErrorResponse},
        422: {"model": ErrorResponse},
        500: {"model": ErrorResponse},
    },
)

# --- CORS 설정 (환경변수 기반) ---
allowed_origins = os.getenv("ALLOWED_ORIGINS", "http://localhost:5173,http://localhost:5174,http://localhost:5175,http://localhost:80,https://recipe-book-gray-five.vercel.app")
origins = [o.strip() for o in allowed_origins.split(",") if o.strip()]

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["GET", "POST"],
    allow_headers=["Content-Type", "Authorization"],
)


# --- 전역 예외 핸들러 ---
@app.exception_handler(ValidationError)
async def pydantic_validation_handler(_request: Request, exc: ValidationError):
    return JSONResponse(
        status_code=422,
        content=ErrorResponse(
            error_code="VALIDATION_ERROR",
            message="요청 데이터가 올바르지 않습니다.",
            detail=str(exc),
        ).model_dump(),
    )


@app.exception_handler(Exception)
async def global_exception_handler(_request: Request, exc: Exception):
    logger.error("처리되지 않은 예외: %s", exc, exc_info=True)
    return JSONResponse(
        status_code=500,
        content=ErrorResponse(
            error_code="INTERNAL_ERROR",
            message="서버 내부 오류가 발생했습니다.",
            detail=str(exc),
        ).model_dump(),
    )


# --- 엔드포인트 ---
@app.get("/")
async def root():
    return {"message": "Recipe AI Extraction API is running!"}


@app.get("/health")
async def health_check():
    """서버 상태 및 쿠키 설정 진단"""
    from utils import _init_cookies
    cookies_b64 = os.getenv("YOUTUBE_COOKIES_B64")
    cookies_path = _init_cookies()
    cookies_file_exists = os.path.exists(cookies_path) if cookies_path else False
    cookies_file_size = os.path.getsize(cookies_path) if cookies_file_exists else 0
    return {
        "status": "ok",
        "cookies_env_set": cookies_b64 is not None,
        "cookies_env_length": len(cookies_b64) if cookies_b64 else 0,
        "cookies_file_path": cookies_path,
        "cookies_file_exists": cookies_file_exists,
        "cookies_file_size": cookies_file_size,
    }


@app.post("/extract-recipe", response_model=Recipe)
async def extract_recipe(request: ExtractRecipeRequest):
    start_time = time.time()
    success = False

    try:
        youtube_url = request.youtube_url
        logger.info("레시피 추출 요청 수신: %s (모드: %s)", youtube_url, request.mode)
        supabase = get_supabase_client()

        # 1. Video ID 추출 (정규식 우선, yt-dlp fallback)
        video_id, error_detail = extract_video_id(youtube_url)

        if not video_id:
            raise HTTPException(
                status_code=400,
                detail=ErrorResponse(
                    error_code="INVALID_URL",
                    message=error_detail or "유효한 유튜브 ID를 찾을 수 없습니다.",
                ).model_dump(),
            )

        if error_detail:
            raise HTTPException(
                status_code=403,
                detail=ErrorResponse(
                    error_code="ACCESS_DENIED",
                    message=error_detail,
                ).model_dump(),
            )

        # 2. 캐시 체크 (force_refresh=True면 건너뜀)
        if supabase and not request.force_refresh:
            try:
                existing = supabase.table("recipes").select("*").eq("video_id", video_id).execute()
                if existing.data:
                    logger.info("DB 캐시 히트 (video_id: %s)", video_id)
                    return Recipe(**existing.data[0])
            except Exception as db_err:
                logger.warning("DB 조회 실패: %s", db_err)
        elif request.force_refresh:
            logger.info("force_refresh=True → 캐시 무시, 재분석 시작 (video_id: %s)", video_id)

        # 3. 메타데이터 조회 (oEmbed API — 봇 차단 없음)
        metadata = get_video_metadata(youtube_url)

        # 4. Gemini YouTube URL 직접 분석 (다운로드 없음, 봇 차단 없음)
        logger.info("Gemini 분석 시작 (video_id: %s)", video_id)
        recipe = await extract_recipe_with_gemini(youtube_url, video_id, metadata)
        recipe.video_url = youtube_url

        if not recipe.is_recipe:
            logger.info("레시피 영상 아님: %s", recipe.non_recipe_reason)
            raise HTTPException(
                status_code=400,
                detail=ErrorResponse(
                    error_code="NOT_RECIPE",
                    message=f"레시피 영상이 아닙니다: {recipe.non_recipe_reason}",
                ).model_dump(),
            )

        # 5. DB 저장
        if supabase:
            try:
                recipe_data = recipe.model_dump(exclude={"id", "is_recipe", "non_recipe_reason"})
                recipe_data["video_url"] = youtube_url
                recipe_data["video_id"] = video_id
                if request.force_refresh:
                    result = supabase.table("recipes").upsert(recipe_data, on_conflict="video_id").execute()
                    logger.info("DB upsert 완료 (video_id: %s)", video_id)
                else:
                    result = supabase.table("recipes").insert(recipe_data).execute()
                if result.data:
                    recipe.id = result.data[0]["id"]
                    logger.info("DB 저장 완료 (recipe_id: %s)", recipe.id)
            except Exception as db_err:
                logger.warning("DB 저장 실패: %s", db_err)

        success = True
        return recipe

    except HTTPException:
        raise
    except Exception as e:
        logger.error("레시피 추출 중 오류: %s", e, exc_info=True)
        raise HTTPException(
            status_code=500,
            detail=ErrorResponse(
                error_code="EXTRACTION_FAILED",
                message="레시피 추출 중 오류가 발생했습니다.",
                detail=str(e),
            ).model_dump(),
        )
    finally:
        # analysis_logs 기록
        processing_time_ms = int((time.time() - start_time) * 1000)
        try:
            supabase = get_supabase_client()
            if supabase:
                supabase.table("analysis_logs").insert({
                    "video_url": request.youtube_url,
                    "raw_response": None,
                    "processing_time_ms": processing_time_ms,
                    "success": success,
                }).execute()
        except Exception as log_err:
            logger.warning("analysis_logs 기록 실패: %s", log_err)


@app.get("/collections/{user_id}")
async def get_user_collections(user_id: str):
    """사용자 보관함 목록 조회 — user_collections + recipes JOIN"""
    try:
        supabase = get_supabase_client()
        if not supabase:
            raise HTTPException(
                status_code=500,
                detail=ErrorResponse(
                    error_code="DB_CONNECTION_FAILED",
                    message="데이터베이스 연결에 실패했습니다.",
                ).model_dump(),
            )

        result = (
            supabase.table("user_collections")
            .select("*, recipe:recipes(*)")
            .eq("user_id", user_id)
            .order("created_at", desc=True)
            .execute()
        )

        return result.data or []

    except HTTPException:
        raise
    except Exception as e:
        logger.error("보관함 조회 오류 (user_id: %s): %s", user_id, e, exc_info=True)
        raise HTTPException(
            status_code=500,
            detail=ErrorResponse(
                error_code="COLLECTION_FETCH_FAILED",
                message="보관함 조회 중 오류가 발생했습니다.",
                detail=str(e),
            ).model_dump(),
        )


@app.post("/collections")
async def save_to_collection(request: CollectionRequest):
    try:
        supabase = get_supabase_client()
        if not supabase:
            raise HTTPException(
                status_code=500,
                detail=ErrorResponse(
                    error_code="DB_CONNECTION_FAILED",
                    message="데이터베이스 연결에 실패했습니다.",
                ).model_dump(),
            )

        data = request.model_dump()
        result = supabase.table("user_collections").upsert(data).execute()

        if not result.data:
            raise HTTPException(
                status_code=400,
                detail=ErrorResponse(
                    error_code="SAVE_FAILED",
                    message="보관함 저장에 실패했습니다.",
                ).model_dump(),
            )

        return {"status": "success", "message": "보관함에 저장되었습니다."}
    except HTTPException:
        raise
    except Exception as e:
        logger.error("보관함 저장 오류: %s", e, exc_info=True)
        raise HTTPException(
            status_code=500,
            detail=ErrorResponse(
                error_code="INTERNAL_ERROR",
                message="보관함 저장 중 오류가 발생했습니다.",
                detail=str(e),
            ).model_dump(),
        )


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
