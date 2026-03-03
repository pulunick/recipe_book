import os
import time
from datetime import datetime, timezone
from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import ValidationError

from schemas import (
    Recipe, CollectionRequest, CollectionUpdateRequest, ExtractRecipeRequest, ErrorResponse,
    TagCreate, CollectionTag, CollectionTagUpdate, RatingRequest, CookedRequest, CategoryOverrideRequest,
    CollectionListItem,
)
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
    allow_methods=["GET", "POST", "DELETE", "PATCH", "PUT"],
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
async def get_user_collections(
    user_id: str,
    category: str | None = None,
    tag_id: int | None = None,
    is_favorite: bool | None = None,
    min_rating: int | None = None,
    sort: str = "saved_at",
    q: str | None = None,
):
    """사용자 보관함 목록 조회 — 필터/정렬/검색 지원

    - category: 카테고리 필터 (AI 분류 또는 category_override 기준)
    - tag_id: 특정 태그가 부착된 컬렉션만
    - is_favorite: true면 즐겨찾기만
    - min_rating: 별점 이상 필터
    - sort: saved_at | last_cooked | rating | cooked_count
    - q: 레시피 제목 검색
    """
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

        query = (
            supabase.table("user_collections")
            .select("*, recipe:recipes(*), tags:collection_tag_items(tag:collection_tags(*))")
            .eq("user_id", user_id)
        )

        # 필터 적용
        if is_favorite is True:
            query = query.eq("is_favorite", True)
        if min_rating is not None:
            query = query.gte("my_rating", min_rating)
        if tag_id is not None:
            # collection_tag_items에 해당 tag_id가 있는 collection_id만 필터
            tag_collections = (
                supabase.table("collection_tag_items")
                .select("collection_id")
                .eq("tag_id", tag_id)
                .execute()
            )
            ids = [r["collection_id"] for r in (tag_collections.data or [])]
            if not ids:
                return []
            query = query.in_("id", ids)

        # 정렬 적용
        sort_map = {
            "saved_at": ("created_at", True),
            "last_cooked": ("last_cooked_at", True),
            "rating": ("my_rating", True),
            "cooked_count": ("cooked_count", True),
        }
        sort_col, sort_desc = sort_map.get(sort, ("created_at", True))
        query = query.order(sort_col, desc=sort_desc)

        result = query.execute()
        data = result.data or []

        # 카테고리 필터 (category_override 우선, 없으면 recipe.category)
        if category:
            filtered = []
            for item in data:
                effective_category = item.get("category_override") or (item.get("recipe") or {}).get("category")
                if effective_category == category:
                    filtered.append(item)
            data = filtered

        # 제목 검색 (레시피 title 기준)
        if q:
            q_lower = q.lower()
            data = [
                item for item in data
                if q_lower in ((item.get("recipe") or {}).get("title", "") or "").lower()
            ]

        return data

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


@app.delete("/collections/{collection_id}")
async def delete_from_collection(collection_id: int):
    """보관함에서 레시피 삭제"""
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

        supabase.table("user_collections").delete().eq("id", collection_id).execute()
        return {"status": "deleted"}

    except HTTPException:
        raise
    except Exception as e:
        logger.error("보관함 삭제 오류 (id: %s): %s", collection_id, e, exc_info=True)
        raise HTTPException(
            status_code=500,
            detail=ErrorResponse(
                error_code="DELETE_FAILED",
                message="보관함 삭제 중 오류가 발생했습니다.",
                detail=str(e),
            ).model_dump(),
        )


@app.patch("/collections/{collection_id}")
async def update_collection(collection_id: int, request: CollectionUpdateRequest):
    """보관함 메모(custom_tip) 수정"""
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

        supabase.table("user_collections").update({"custom_tip": request.custom_tip}).eq("id", collection_id).execute()
        return {"status": "updated"}

    except HTTPException:
        raise
    except Exception as e:
        logger.error("보관함 수정 오류 (id: %s): %s", collection_id, e, exc_info=True)
        raise HTTPException(
            status_code=500,
            detail=ErrorResponse(
                error_code="UPDATE_FAILED",
                message="보관함 수정 중 오류가 발생했습니다.",
                detail=str(e),
            ).model_dump(),
        )


# --- 즐겨찾기 토글 ---
@app.put("/collections/{collection_id}/favorite")
async def toggle_favorite(collection_id: int):
    """즐겨찾기 토글 — 현재 값 반전"""
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

        current = supabase.table("user_collections").select("is_favorite").eq("id", collection_id).execute()
        if not current.data:
            raise HTTPException(
                status_code=404,
                detail=ErrorResponse(error_code="NOT_FOUND", message="컬렉션을 찾을 수 없습니다.").model_dump(),
            )

        new_value = not current.data[0]["is_favorite"]
        supabase.table("user_collections").update({"is_favorite": new_value}).eq("id", collection_id).execute()
        return {"is_favorite": new_value}

    except HTTPException:
        raise
    except Exception as e:
        logger.error("즐겨찾기 토글 오류 (id: %s): %s", collection_id, e, exc_info=True)
        raise HTTPException(
            status_code=500,
            detail=ErrorResponse(
                error_code="UPDATE_FAILED",
                message="즐겨찾기 업데이트 중 오류가 발생했습니다.",
                detail=str(e),
            ).model_dump(),
        )


# --- 별점 설정 ---
@app.put("/collections/{collection_id}/rating")
async def set_rating(collection_id: int, request: RatingRequest):
    """별점 설정 (1~5)"""
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

        result = supabase.table("user_collections").update({"my_rating": request.rating}).eq("id", collection_id).execute()
        if not result.data:
            raise HTTPException(
                status_code=404,
                detail=ErrorResponse(error_code="NOT_FOUND", message="컬렉션을 찾을 수 없습니다.").model_dump(),
            )
        return {"my_rating": request.rating}

    except HTTPException:
        raise
    except Exception as e:
        logger.error("별점 설정 오류 (id: %s): %s", collection_id, e, exc_info=True)
        raise HTTPException(
            status_code=500,
            detail=ErrorResponse(
                error_code="UPDATE_FAILED",
                message="별점 설정 중 오류가 발생했습니다.",
                detail=str(e),
            ).model_dump(),
        )


# --- 만들어봤어요 기록 ---
@app.post("/collections/{collection_id}/cooked")
async def record_cooked(collection_id: int, request: CookedRequest):
    """요리 기록 — cooked_count +1, last_cooked_at 업데이트, 선택적 별점"""
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

        current = supabase.table("user_collections").select("cooked_count").eq("id", collection_id).execute()
        if not current.data:
            raise HTTPException(
                status_code=404,
                detail=ErrorResponse(error_code="NOT_FOUND", message="컬렉션을 찾을 수 없습니다.").model_dump(),
            )

        new_count = (current.data[0]["cooked_count"] or 0) + 1
        update_data: dict = {
            "cooked_count": new_count,
            "last_cooked_at": datetime.now(timezone.utc).isoformat(),
        }
        if request.rating is not None:
            update_data["my_rating"] = request.rating

        supabase.table("user_collections").update(update_data).eq("id", collection_id).execute()
        return {"cooked_count": new_count, "my_rating": request.rating}

    except HTTPException:
        raise
    except Exception as e:
        logger.error("요리 기록 오류 (id: %s): %s", collection_id, e, exc_info=True)
        raise HTTPException(
            status_code=500,
            detail=ErrorResponse(
                error_code="UPDATE_FAILED",
                message="요리 기록 중 오류가 발생했습니다.",
                detail=str(e),
            ).model_dump(),
        )


# --- 카테고리 수동 변경 ---
@app.put("/collections/{collection_id}/category")
async def override_category(collection_id: int, request: CategoryOverrideRequest):
    """카테고리 수동 변경 — category_override 설정 (None이면 AI 분류로 복원)"""
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

        result = supabase.table("user_collections").update({"category_override": request.category}).eq("id", collection_id).execute()
        if not result.data:
            raise HTTPException(
                status_code=404,
                detail=ErrorResponse(error_code="NOT_FOUND", message="컬렉션을 찾을 수 없습니다.").model_dump(),
            )
        return {"category_override": request.category}

    except HTTPException:
        raise
    except Exception as e:
        logger.error("카테고리 변경 오류 (id: %s): %s", collection_id, e, exc_info=True)
        raise HTTPException(
            status_code=500,
            detail=ErrorResponse(
                error_code="UPDATE_FAILED",
                message="카테고리 변경 중 오류가 발생했습니다.",
                detail=str(e),
            ).model_dump(),
        )


# --- 태그 목록 조회 ---
@app.get("/tags/{user_id}", response_model=list[CollectionTag])
async def get_user_tags(user_id: str):
    """사용자의 태그 목록 조회"""
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
            supabase.table("collection_tags")
            .select("*")
            .eq("user_id", user_id)
            .order("created_at", desc=False)
            .execute()
        )
        return result.data or []

    except HTTPException:
        raise
    except Exception as e:
        logger.error("태그 목록 조회 오류 (user_id: %s): %s", user_id, e, exc_info=True)
        raise HTTPException(
            status_code=500,
            detail=ErrorResponse(
                error_code="FETCH_FAILED",
                message="태그 목록 조회 중 오류가 발생했습니다.",
                detail=str(e),
            ).model_dump(),
        )


# --- 태그 생성 ---
@app.post("/tags", response_model=CollectionTag)
async def create_tag(request: TagCreate):
    """새 태그 생성"""
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

        result = supabase.table("collection_tags").insert(request.model_dump()).execute()
        if not result.data:
            raise HTTPException(
                status_code=400,
                detail=ErrorResponse(error_code="CREATE_FAILED", message="태그 생성에 실패했습니다.").model_dump(),
            )
        return result.data[0]

    except HTTPException:
        raise
    except Exception as e:
        # UNIQUE 제약 위반 (동일 이름 태그 중복)
        if "unique" in str(e).lower() or "duplicate" in str(e).lower():
            raise HTTPException(
                status_code=409,
                detail=ErrorResponse(
                    error_code="DUPLICATE_TAG",
                    message="동일한 이름의 태그가 이미 존재합니다.",
                ).model_dump(),
            )
        logger.error("태그 생성 오류: %s", e, exc_info=True)
        raise HTTPException(
            status_code=500,
            detail=ErrorResponse(
                error_code="CREATE_FAILED",
                message="태그 생성 중 오류가 발생했습니다.",
                detail=str(e),
            ).model_dump(),
        )


# --- 태그 삭제 ---
@app.delete("/tags/{tag_id}")
async def delete_tag(tag_id: int):
    """태그 삭제 (연결된 collection_tag_items는 CASCADE 자동 삭제)"""
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

        supabase.table("collection_tags").delete().eq("id", tag_id).execute()
        return {"deleted": True}

    except HTTPException:
        raise
    except Exception as e:
        logger.error("태그 삭제 오류 (id: %s): %s", tag_id, e, exc_info=True)
        raise HTTPException(
            status_code=500,
            detail=ErrorResponse(
                error_code="DELETE_FAILED",
                message="태그 삭제 중 오류가 발생했습니다.",
                detail=str(e),
            ).model_dump(),
        )


# --- 태그 부착/해제 (전체 덮어쓰기) ---
@app.put("/collections/{collection_id}/tags")
async def update_collection_tags(collection_id: int, request: CollectionTagUpdate):
    """컬렉션에 태그 부착/해제 — tag_ids로 전체 덮어쓰기"""
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

        # 기존 태그 연결 모두 삭제
        supabase.table("collection_tag_items").delete().eq("collection_id", collection_id).execute()

        # 새 태그 연결 삽입 후 태그 상세 정보 조회
        tags = []
        if request.tag_ids:
            items = [{"collection_id": collection_id, "tag_id": tid} for tid in request.tag_ids]
            supabase.table("collection_tag_items").insert(items).execute()
            tag_result = (
                supabase.table("collection_tags")
                .select("*")
                .in_("id", request.tag_ids)
                .execute()
            )
            tags = tag_result.data or []

        return {"tags": tags}

    except HTTPException:
        raise
    except Exception as e:
        logger.error("태그 부착 오류 (collection_id: %s): %s", collection_id, e, exc_info=True)
        raise HTTPException(
            status_code=500,
            detail=ErrorResponse(
                error_code="UPDATE_FAILED",
                message="태그 업데이트 중 오류가 발생했습니다.",
                detail=str(e),
            ).model_dump(),
        )


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
