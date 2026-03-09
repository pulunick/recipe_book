import os
import time
from datetime import datetime, timezone
from fastapi import FastAPI, HTTPException, Request, Depends
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import ValidationError

from schemas import (
    Recipe, CollectionRequest, CollectionUpdateRequest, ExtractRecipeRequest, ErrorResponse,
    TagCreate, CollectionTag, CollectionTagUpdate, RatingRequest, CookedRequest, CategoryOverrideRequest,
    CollectionListItem, RecipePublicItem, RecipesListResponse, ExtractRecipeFromTextRequest,
    SaveTextRecipeRequest, CartItemResponse, CartGroupResponse, RecipeAuthorUpdateRequest,
)
from utils import extract_video_id, get_video_metadata
from ai_engine import extract_recipe_with_gemini, extract_recipe_from_text
from database import get_supabase_client
from auth import get_current_user
from logger import get_logger

logger = get_logger(__name__)

async def _verify_collection_owner(collection_id: int, user_id: str, supabase) -> None:
    """컬렉션 소유권 검증 — 본인 소유가 아니면 403"""
    result = supabase.table("user_collections").select("user_id").eq("id", collection_id).execute()
    if not result.data:
        raise HTTPException(
            status_code=404,
            detail=ErrorResponse(error_code="NOT_FOUND", message="컬렉션을 찾을 수 없습니다.").model_dump(),
        )
    if result.data[0]["user_id"] != user_id:
        raise HTTPException(
            status_code=403,
            detail=ErrorResponse(error_code="FORBIDDEN", message="접근 권한이 없습니다.").model_dump(),
        )


app = FastAPI(
    title="해먹당 API",
    responses={
        400: {"model": ErrorResponse},
        403: {"model": ErrorResponse},
        422: {"model": ErrorResponse},
        500: {"model": ErrorResponse},
    },
)

# --- CORS 설정 (환경변수 기반) ---
allowed_origins = os.getenv("ALLOWED_ORIGINS", "http://localhost:5173,http://localhost:5174,http://localhost:5175,http://localhost:5180,http://localhost:80,https://recipe-book-gray-five.vercel.app")
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
async def extract_recipe(request: Request, body: ExtractRecipeRequest):
    start_time = time.time()
    success = False

    try:
        youtube_url = body.youtube_url
        logger.info("레시피 추출 요청 수신: %s (모드: %s)", youtube_url, body.mode)
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
        if supabase and not body.force_refresh:
            try:
                existing = supabase.table("recipes").select("*").eq("video_id", video_id).execute()
                if existing.data:
                    logger.info("DB 캐시 히트 (video_id: %s)", video_id)
                    return Recipe(**existing.data[0])
            except Exception as db_err:
                logger.warning("DB 조회 실패: %s", db_err)
        elif body.force_refresh:
            logger.info("force_refresh=True → 캐시 무시, 재분석 시작 (video_id: %s)", video_id)

        # 3. 메타데이터 조회 (oEmbed API — 봇 차단 없음)
        metadata = get_video_metadata(youtube_url)

        # 4. Gemini YouTube URL 직접 분석 (다운로드 없음, 봇 차단 없음)
        logger.info("Gemini 분석 시작 (video_id: %s)", video_id)
        recipe = await extract_recipe_with_gemini(youtube_url, video_id, metadata)
        recipe.video_url = youtube_url
        recipe.video_title = metadata.get("title") or None
        recipe.channel_name = metadata.get("uploader") or None

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
                if body.force_refresh:
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
                    "video_url": body.youtube_url,
                    "raw_response": None,
                    "processing_time_ms": processing_time_ms,
                    "success": success,
                }).execute()
        except Exception as log_err:
            logger.warning("analysis_logs 기록 실패: %s", log_err)


@app.get("/collections/{user_id}")
async def get_user_collections(
    user_id: str,
    jwt_user_id: str = Depends(get_current_user),
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
        if user_id != jwt_user_id:
            raise HTTPException(
                status_code=403,
                detail=ErrorResponse(error_code="FORBIDDEN", message="접근 권한이 없습니다.").model_dump(),
            )
        supabase = get_supabase_client()
        if not supabase:
            raise HTTPException(
                status_code=500,
                detail=ErrorResponse(
                    error_code="DB_CONNECTION_FAILED",
                    message="데이터베이스 연결에 실패했습니다.",
                ).model_dump(),
            )

        # recipe는 카드/검색에 필요한 컬럼만 선택 (steps/flavor 제외, ingredients는 재료 검색용 포함)
        RECIPE_CARD_COLS = "id,title,category,cooking_time,difficulty,servings,video_id,channel_name,ingredients"
        query = (
            supabase.table("user_collections")
            .select(f"*, recipe:recipes({RECIPE_CARD_COLS}), tags:collection_tag_items(tag:collection_tags(*))")
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

        # tags 중첩 구조 평탄화: [{ tag: {...} }] → [{...}]
        for item in data:
            raw_tags = item.get("tags") or []
            item["tags"] = [t["tag"] for t in raw_tags if t.get("tag")]

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


@app.get("/collections/item/{collection_id}")
async def get_collection_item(collection_id: int, jwt_user_id: str = Depends(get_current_user)):
    """단일 컬렉션 상세 조회 — 레시피 전체 데이터 포함 (상세 페이지용)"""
    try:
        supabase = get_supabase_client()
        if not supabase:
            raise HTTPException(
                status_code=500,
                detail=ErrorResponse(error_code="DB_CONNECTION_FAILED", message="데이터베이스 연결에 실패했습니다.").model_dump(),
            )

        result = (
            supabase.table("user_collections")
            .select("*, recipe:recipes(*), tags:collection_tag_items(tag:collection_tags(*))")
            .eq("id", collection_id)
            .single()
            .execute()
        )
        if not result.data:
            raise HTTPException(
                status_code=404,
                detail=ErrorResponse(error_code="NOT_FOUND", message="컬렉션을 찾을 수 없습니다.").model_dump(),
            )

        item = result.data
        if item["user_id"] != jwt_user_id:
            raise HTTPException(
                status_code=403,
                detail=ErrorResponse(error_code="FORBIDDEN", message="접근 권한이 없습니다.").model_dump(),
            )

        # tags 중첩 구조 평탄화
        raw_tags = item.get("tags") or []
        item["tags"] = [t["tag"] for t in raw_tags if t.get("tag")]
        return item

    except HTTPException:
        raise
    except Exception as e:
        logger.error("컬렉션 상세 조회 오류 (id: %s): %s", collection_id, e, exc_info=True)
        raise HTTPException(
            status_code=500,
            detail=ErrorResponse(error_code="FETCH_FAILED", message="컬렉션 조회 중 오류가 발생했습니다.", detail=str(e)).model_dump(),
        )


@app.post("/collections")
async def save_to_collection(request: CollectionRequest, jwt_user_id: str = Depends(get_current_user)):
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
        data["user_id"] = jwt_user_id
        result = supabase.table("user_collections").upsert(data).execute()

        if not result.data:
            raise HTTPException(
                status_code=400,
                detail=ErrorResponse(
                    error_code="SAVE_FAILED",
                    message="보관함 저장에 실패했습니다.",
                ).model_dump(),
            )

        collection_id = result.data[0]["id"]
        return {"status": "success", "collection_id": collection_id}
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
async def delete_from_collection(collection_id: int, jwt_user_id: str = Depends(get_current_user)):
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

        await _verify_collection_owner(collection_id, jwt_user_id, supabase)
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
async def update_collection(collection_id: int, request: CollectionUpdateRequest, jwt_user_id: str = Depends(get_current_user)):
    """보관함 메모(custom_tip) 및 레시피 수정본(recipe_override) 업데이트"""
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

        await _verify_collection_owner(collection_id, jwt_user_id, supabase)

        update_data: dict = {}
        if request.custom_tip is not None:
            update_data["custom_tip"] = request.custom_tip
        # recipe_override는 None 전달 시 원본 복원, 값 전달 시 수정본 저장
        if "recipe_override" in request.model_fields_set:
            update_data["recipe_override"] = request.recipe_override

        if update_data:
            supabase.table("user_collections").update(update_data).eq("id", collection_id).execute()

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
async def toggle_favorite(collection_id: int, jwt_user_id: str = Depends(get_current_user)):
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

        current = supabase.table("user_collections").select("user_id,is_favorite").eq("id", collection_id).execute()
        if not current.data:
            raise HTTPException(
                status_code=404,
                detail=ErrorResponse(error_code="NOT_FOUND", message="컬렉션을 찾을 수 없습니다.").model_dump(),
            )
        if current.data[0]["user_id"] != jwt_user_id:
            raise HTTPException(
                status_code=403,
                detail=ErrorResponse(error_code="FORBIDDEN", message="접근 권한이 없습니다.").model_dump(),
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
async def set_rating(collection_id: int, request: RatingRequest, jwt_user_id: str = Depends(get_current_user)):
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

        await _verify_collection_owner(collection_id, jwt_user_id, supabase)
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
async def record_cooked(collection_id: int, request: CookedRequest, jwt_user_id: str = Depends(get_current_user)):
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

        current = supabase.table("user_collections").select("user_id,cooked_count").eq("id", collection_id).execute()
        if not current.data:
            raise HTTPException(
                status_code=404,
                detail=ErrorResponse(error_code="NOT_FOUND", message="컬렉션을 찾을 수 없습니다.").model_dump(),
            )
        if current.data[0]["user_id"] != jwt_user_id:
            raise HTTPException(
                status_code=403,
                detail=ErrorResponse(error_code="FORBIDDEN", message="접근 권한이 없습니다.").model_dump(),
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
async def override_category(collection_id: int, request: CategoryOverrideRequest, jwt_user_id: str = Depends(get_current_user)):
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

        await _verify_collection_owner(collection_id, jwt_user_id, supabase)
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
async def get_user_tags(user_id: str, jwt_user_id: str = Depends(get_current_user)):
    """사용자의 태그 목록 조회"""
    try:
        if user_id != jwt_user_id:
            raise HTTPException(
                status_code=403,
                detail=ErrorResponse(error_code="FORBIDDEN", message="접근 권한이 없습니다.").model_dump(),
            )
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
async def create_tag(request: TagCreate, jwt_user_id: str = Depends(get_current_user)):
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

        data = request.model_dump()
        data["user_id"] = jwt_user_id
        result = supabase.table("collection_tags").insert(data).execute()
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
async def delete_tag(tag_id: int, jwt_user_id: str = Depends(get_current_user)):
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

        tag = supabase.table("collection_tags").select("user_id").eq("id", tag_id).execute()
        if tag.data and tag.data[0]["user_id"] != jwt_user_id:
            raise HTTPException(
                status_code=403,
                detail=ErrorResponse(error_code="FORBIDDEN", message="접근 권한이 없습니다.").model_dump(),
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
async def update_collection_tags(collection_id: int, request: CollectionTagUpdate, jwt_user_id: str = Depends(get_current_user)):
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

        await _verify_collection_owner(collection_id, jwt_user_id, supabase)
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


# --- 텍스트 → 레시피 변환 ---
@app.post("/extract-recipe-from-text", response_model=Recipe)
async def extract_recipe_from_text_endpoint(request: Request, body: ExtractRecipeFromTextRequest):
    """자유형식 텍스트를 AI가 구조화된 레시피로 변환 (캐싱 없음, 매번 새로 분석)

    - 구어체, 메모, 블로그 복붙 등 모든 텍스트 형식 지원
    - 50자 미만이거나 레시피와 무관한 텍스트는 거부
    - 변환 결과는 DB에 저장되지 않음 — 프론트에서 확인 후 수동 저장
    """
    try:
        logger.info("텍스트 레시피 변환 요청 (길이: %d자, 제목: %s)", len(body.text), body.title or "(없음)")

        recipe = await extract_recipe_from_text(body.text, body.title)

        if not recipe.is_recipe:
            logger.info("레시피 텍스트 아님: %s", recipe.non_recipe_reason)
            raise HTTPException(
                status_code=400,
                detail=ErrorResponse(
                    error_code="NOT_RECIPE",
                    message=f"레시피 내용이 아닙니다: {recipe.non_recipe_reason}",
                ).model_dump(),
            )

        # DB 저장은 하지 않음 — 프론트에서 편집 후 /collections로 별도 저장
        # source 필드는 DB 저장 시점에 'text'로 기록 (collections 저장 흐름에서 처리)
        return recipe

    except HTTPException:
        raise
    except Exception as e:
        logger.error("텍스트 레시피 변환 중 오류: %s", e, exc_info=True)
        raise HTTPException(
            status_code=500,
            detail=ErrorResponse(
                error_code="EXTRACTION_FAILED",
                message="레시피 변환 중 오류가 발생했습니다.",
                detail=str(e),
            ).model_dump(),
        )


# --- 텍스트 레시피 저장 ---
@app.post("/collections/text-recipe")
async def save_text_recipe(request: SaveTextRecipeRequest, jwt_user_id: str = Depends(get_current_user)):
    """분석된 텍스트 레시피를 recipes 테이블에 저장 후 컬렉션에 추가

    - source='text', is_public=False 로 recipes 저장 (탐색 탭에 노출 안 됨)
    - video_id 없음 (텍스트 레시피는 캐싱 키 없음)
    - Flutter 앱에서도 동일 엔드포인트 사용 가능
    """
    try:
        supabase = get_supabase_client()
        if not supabase:
            raise HTTPException(
                status_code=500,
                detail=ErrorResponse(error_code="DB_CONNECTION_FAILED", message="데이터베이스 연결에 실패했습니다.").model_dump(),
            )

        # 저장 불필요 or 오염 방지 필드 제거
        recipe_data = {k: v for k, v in request.recipe.items() if k not in ("id", "is_recipe", "non_recipe_reason")}
        recipe_data["source"] = "text"
        recipe_data["is_public"] = request.is_public
        recipe_data["author_user_id"] = jwt_user_id
        recipe_data["video_id"] = None
        recipe_data["video_url"] = None

        recipe_result = supabase.table("recipes").insert(recipe_data).execute()
        if not recipe_result.data:
            raise HTTPException(
                status_code=500,
                detail=ErrorResponse(error_code="SAVE_FAILED", message="레시피 저장에 실패했습니다.").model_dump(),
            )
        recipe_id = recipe_result.data[0]["id"]

        collection_result = supabase.table("user_collections").insert({
            "user_id": jwt_user_id,
            "recipe_id": recipe_id,
            "custom_tip": request.custom_tip,
        }).execute()
        if not collection_result.data:
            raise HTTPException(
                status_code=500,
                detail=ErrorResponse(error_code="SAVE_FAILED", message="컬렉션 저장에 실패했습니다.").model_dump(),
            )
        collection_id = collection_result.data[0]["id"]
        logger.info("텍스트 레시피 저장 완료 (recipe_id: %s, collection_id: %s)", recipe_id, collection_id)
        return {"status": "success", "collection_id": collection_id, "recipe_id": recipe_id}

    except HTTPException:
        raise
    except Exception as e:
        logger.error("텍스트 레시피 저장 오류: %s", e, exc_info=True)
        raise HTTPException(
            status_code=500,
            detail=ErrorResponse(error_code="INTERNAL_ERROR", message="레시피 저장 중 오류가 발생했습니다.", detail=str(e)).model_dump(),
        )


# --- 텍스트 레시피 원본 수정 (작성자 전용) ---
@app.patch("/recipes/{recipe_id}")
async def update_text_recipe(recipe_id: int, request: RecipeAuthorUpdateRequest, jwt_user_id: str = Depends(get_current_user)):
    """텍스트 레시피 원본 수정 — author_user_id가 요청자와 일치할 때만 허용.
    탐색 탭에 공개된 경우 수정본이 즉시 반영됨.
    """
    try:
        supabase = get_supabase_client()
        if not supabase:
            raise HTTPException(
                status_code=500,
                detail=ErrorResponse(error_code="DB_CONNECTION_FAILED", message="데이터베이스 연결에 실패했습니다.").model_dump(),
            )

        # 소유권 + source 확인
        result = supabase.table("recipes").select("author_user_id,source").eq("id", recipe_id).execute()
        if not result.data:
            raise HTTPException(
                status_code=404,
                detail=ErrorResponse(error_code="NOT_FOUND", message="레시피를 찾을 수 없습니다.").model_dump(),
            )

        recipe_row = result.data[0]
        if recipe_row.get("source") != "text":
            raise HTTPException(
                status_code=400,
                detail=ErrorResponse(error_code="NOT_TEXT_RECIPE", message="텍스트 레시피만 원본 수정이 가능합니다.").model_dump(),
            )
        if recipe_row.get("author_user_id") != jwt_user_id:
            raise HTTPException(
                status_code=403,
                detail=ErrorResponse(error_code="FORBIDDEN", message="레시피 작성자만 수정할 수 있습니다.").model_dump(),
            )

        # 변경된 필드만 업데이트
        update_data = {k: v for k, v in request.model_dump().items() if v is not None}
        if not update_data:
            return {"status": "no_changes"}

        supabase.table("recipes").update(update_data).eq("id", recipe_id).execute()
        logger.info("텍스트 레시피 원본 수정 완료 (recipe_id: %s)", recipe_id)
        return {"status": "updated"}

    except HTTPException:
        raise
    except Exception as e:
        logger.error("레시피 원본 수정 오류 (id: %s): %s", recipe_id, e, exc_info=True)
        raise HTTPException(
            status_code=500,
            detail=ErrorResponse(error_code="UPDATE_FAILED", message="레시피 수정 중 오류가 발생했습니다.", detail=str(e)).model_dump(),
        )


# --- 탐색 탭: 공개 레시피 목록 ---
@app.get("/recipes", response_model=RecipesListResponse)
async def get_public_recipes(
    request: Request,
    sort: str = "recent",
    limit: int = 20,
    page: int = 1,
    q: str | None = None,
    category: str | None = None,
):
    """공개 레시피 목록 조회 — 탐색 탭용 (인증 불필요)

    - sort: recent (최신순) | popular (보관함 저장 수 기준)
    - limit: 페이지당 항목 수 (기본 20)
    - page: 페이지 번호 (기본 1)
    - q: 레시피 제목 또는 재료명 검색
    - category: 카테고리 필터
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

        offset = (page - 1) * limit

        query = (
            supabase.table("recipes")
            .select(
                "id, title, summary, category, cooking_time, difficulty, servings, video_id, channel_name, created_at, collection_count",
                count="exact",
            )
            .eq("is_public", True)
        )

        # 카테고리 필터
        if category:
            query = query.eq("category", category)

        # 제목 + 재료 검색 (ingredients는 JSONB → ::text 캐스팅으로 포함 여부 확인)
        if q:
            safe_q = q.replace("%", "\\%").replace("_", "\\_")
            query = query.or_(f"title.ilike.%{safe_q}%,ingredients::text.ilike.%{safe_q}%")

        # 정렬
        if sort == "popular":
            query = query.order("collection_count", desc=True).order("created_at", desc=True)
        else:
            query = query.order("created_at", desc=True)

        result = query.range(offset, offset + limit - 1).execute()

        items = result.data or []
        total = result.count if result.count is not None else len(items)

        return RecipesListResponse(
            items=items,
            total=total,
            has_more=(offset + limit) < total,
        )

    except HTTPException:
        raise
    except Exception as e:
        logger.error("공개 레시피 목록 조회 오류: %s", e, exc_info=True)
        raise HTTPException(
            status_code=500,
            detail=ErrorResponse(
                error_code="FETCH_FAILED",
                message="레시피 목록 조회 중 오류가 발생했습니다.",
                detail=str(e),
            ).model_dump(),
        )


# --- 탐색 탭: 카테고리 목록 ---
@app.get("/recipes/categories", response_model=list[str])
async def get_recipe_categories():
    """공개 레시피에 실제 사용된 카테고리 목록 (빈도 순)"""
    supabase = get_supabase_client()
    result = supabase.rpc("get_recipe_categories").execute()
    if result.data:
        return [row["category"] for row in result.data]
    return []


# ==============================
# 장바구니 엔드포인트
# ==============================

@app.get("/cart", response_model=list[CartGroupResponse])
async def get_cart(jwt_user_id: str = Depends(get_current_user)):
    """내 장바구니 목록 (레시피별 그룹화)"""
    try:
        supabase = get_supabase_client()
        if not supabase:
            raise HTTPException(
                status_code=500,
                detail=ErrorResponse(error_code="DB_CONNECTION_FAILED", message="데이터베이스 연결에 실패했습니다.").model_dump(),
            )

        result = (
            supabase.table("cart_items")
            .select("*")
            .eq("user_id", jwt_user_id)
            .order("created_at", desc=False)   # 그룹 내 재료 순서 유지
            .execute()
        )
        items = result.data or []

        # 레시피별 그룹화 (collection_id 기준, 없으면 recipe_title 기준)
        groups: dict = {}
        for row in items:
            key = row.get("collection_id") or row.get("recipe_title") or "기타"
            if key not in groups:
                groups[key] = {
                    "collection_id": row.get("collection_id"),
                    "recipe_title": row.get("recipe_title"),
                    "items": [],
                    "_max_created_at": "",
                }
            groups[key]["items"].append(row)
            row_ts = row.get("created_at") or ""
            if row_ts > groups[key]["_max_created_at"]:
                groups[key]["_max_created_at"] = row_ts

        # 최근 담은 그룹이 위로 오도록 정렬 (DESC)
        sorted_groups = sorted(groups.values(), key=lambda g: g["_max_created_at"], reverse=True)
        for g in sorted_groups:
            g.pop("_max_created_at", None)

        return sorted_groups

    except HTTPException:
        raise
    except Exception as e:
        logger.error("장바구니 조회 오류: %s", e, exc_info=True)
        raise HTTPException(
            status_code=500,
            detail=ErrorResponse(error_code="FETCH_FAILED", message="장바구니 조회 중 오류가 발생했습니다.", detail=str(e)).model_dump(),
        )


@app.post("/cart/from-collection/{collection_id}")
async def add_cart_from_collection(collection_id: int, jwt_user_id: str = Depends(get_current_user)):
    """레시피 컬렉션의 재료를 장바구니에 추가 (기존 항목 교체)"""
    try:
        supabase = get_supabase_client()
        if not supabase:
            raise HTTPException(
                status_code=500,
                detail=ErrorResponse(error_code="DB_CONNECTION_FAILED", message="데이터베이스 연결에 실패했습니다.").model_dump(),
            )

        # 소유권 확인 + 레시피 조회
        result = (
            supabase.table("user_collections")
            .select("*, recipe:recipes(title, ingredients)")
            .eq("id", collection_id)
            .single()
            .execute()
        )
        if not result.data:
            raise HTTPException(
                status_code=404,
                detail=ErrorResponse(error_code="NOT_FOUND", message="컬렉션을 찾을 수 없습니다.").model_dump(),
            )

        col = result.data
        if col["user_id"] != jwt_user_id:
            raise HTTPException(
                status_code=403,
                detail=ErrorResponse(error_code="FORBIDDEN", message="접근 권한이 없습니다.").model_dump(),
            )

        recipe = col.get("recipe") or {}
        recipe_title = recipe.get("title", "")

        # recipe_override 재료 우선, 없으면 원본 재료
        override = col.get("recipe_override") or {}
        ingredients = override.get("ingredients") or recipe.get("ingredients") or []

        if not ingredients:
            raise HTTPException(
                status_code=400,
                detail=ErrorResponse(error_code="NO_INGREDIENTS", message="재료 정보가 없습니다.").model_dump(),
            )

        # 기존 이 컬렉션의 장바구니 항목 삭제 (교체)
        supabase.table("cart_items").delete().eq("user_id", jwt_user_id).eq("collection_id", collection_id).execute()

        # 새 항목 삽입
        rows = [
            {
                "user_id": jwt_user_id,
                "collection_id": collection_id,
                "recipe_title": recipe_title,
                "ingredient_name": ing.get("name", ""),
                "amount": ing.get("amount"),
                "unit": ing.get("unit"),
                "category": ing.get("category") or "기타",
                "is_checked": False,
            }
            for ing in ingredients
            if ing.get("name")
        ]

        supabase.table("cart_items").insert(rows).execute()
        logger.info("장바구니 추가 완료 (collection_id: %s, 재료 수: %d)", collection_id, len(rows))
        return {"status": "added", "count": len(rows)}

    except HTTPException:
        raise
    except Exception as e:
        logger.error("장바구니 추가 오류 (collection_id: %s): %s", collection_id, e, exc_info=True)
        raise HTTPException(
            status_code=500,
            detail=ErrorResponse(error_code="INTERNAL_ERROR", message="장바구니 추가 중 오류가 발생했습니다.", detail=str(e)).model_dump(),
        )


@app.put("/cart/items/{item_id}/check")
async def toggle_cart_item(item_id: int, jwt_user_id: str = Depends(get_current_user)):
    """장바구니 아이템 체크/언체크 토글"""
    try:
        supabase = get_supabase_client()
        if not supabase:
            raise HTTPException(
                status_code=500,
                detail=ErrorResponse(error_code="DB_CONNECTION_FAILED", message="데이터베이스 연결에 실패했습니다.").model_dump(),
            )

        current = supabase.table("cart_items").select("user_id,is_checked").eq("id", item_id).execute()
        if not current.data:
            raise HTTPException(
                status_code=404,
                detail=ErrorResponse(error_code="NOT_FOUND", message="장바구니 항목을 찾을 수 없습니다.").model_dump(),
            )
        if current.data[0]["user_id"] != jwt_user_id:
            raise HTTPException(
                status_code=403,
                detail=ErrorResponse(error_code="FORBIDDEN", message="접근 권한이 없습니다.").model_dump(),
            )

        new_value = not current.data[0]["is_checked"]
        supabase.table("cart_items").update({"is_checked": new_value}).eq("id", item_id).execute()
        return {"is_checked": new_value}

    except HTTPException:
        raise
    except Exception as e:
        logger.error("장바구니 체크 토글 오류 (item_id: %s): %s", item_id, e, exc_info=True)
        raise HTTPException(
            status_code=500,
            detail=ErrorResponse(error_code="UPDATE_FAILED", message="체크 업데이트 중 오류가 발생했습니다.", detail=str(e)).model_dump(),
        )


@app.delete("/cart/items/{item_id}")
async def delete_cart_item(item_id: int, jwt_user_id: str = Depends(get_current_user)):
    """장바구니 개별 아이템 삭제"""
    try:
        supabase = get_supabase_client()
        if not supabase:
            raise HTTPException(
                status_code=500,
                detail=ErrorResponse(error_code="DB_CONNECTION_FAILED", message="데이터베이스 연결에 실패했습니다.").model_dump(),
            )

        item = supabase.table("cart_items").select("user_id").eq("id", item_id).execute()
        if item.data and item.data[0]["user_id"] != jwt_user_id:
            raise HTTPException(
                status_code=403,
                detail=ErrorResponse(error_code="FORBIDDEN", message="접근 권한이 없습니다.").model_dump(),
            )

        supabase.table("cart_items").delete().eq("id", item_id).eq("user_id", jwt_user_id).execute()
        return {"deleted": True}

    except HTTPException:
        raise
    except Exception as e:
        logger.error("장바구니 항목 삭제 오류 (item_id: %s): %s", item_id, e, exc_info=True)
        raise HTTPException(
            status_code=500,
            detail=ErrorResponse(error_code="DELETE_FAILED", message="삭제 중 오류가 발생했습니다.", detail=str(e)).model_dump(),
        )


@app.delete("/cart/checked")
async def delete_checked_cart_items(jwt_user_id: str = Depends(get_current_user)):
    """체크된 장바구니 항목 모두 삭제"""
    try:
        supabase = get_supabase_client()
        if not supabase:
            raise HTTPException(
                status_code=500,
                detail=ErrorResponse(error_code="DB_CONNECTION_FAILED", message="데이터베이스 연결에 실패했습니다.").model_dump(),
            )

        supabase.table("cart_items").delete().eq("user_id", jwt_user_id).eq("is_checked", True).execute()
        return {"deleted": True}

    except HTTPException:
        raise
    except Exception as e:
        logger.error("체크 항목 삭제 오류: %s", e, exc_info=True)
        raise HTTPException(
            status_code=500,
            detail=ErrorResponse(error_code="DELETE_FAILED", message="삭제 중 오류가 발생했습니다.", detail=str(e)).model_dump(),
        )


@app.delete("/cart")
async def clear_cart(jwt_user_id: str = Depends(get_current_user)):
    """장바구니 전체 비우기"""
    try:
        supabase = get_supabase_client()
        if not supabase:
            raise HTTPException(
                status_code=500,
                detail=ErrorResponse(error_code="DB_CONNECTION_FAILED", message="데이터베이스 연결에 실패했습니다.").model_dump(),
            )

        supabase.table("cart_items").delete().eq("user_id", jwt_user_id).execute()
        return {"cleared": True}

    except HTTPException:
        raise
    except Exception as e:
        logger.error("장바구니 비우기 오류: %s", e, exc_info=True)
        raise HTTPException(
            status_code=500,
            detail=ErrorResponse(error_code="DELETE_FAILED", message="장바구니 비우기 중 오류가 발생했습니다.", detail=str(e)).model_dump(),
        )


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
