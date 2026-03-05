import re
from pydantic import BaseModel, Field, field_validator
from typing import List, Dict, Optional


class ExtractRecipeRequest(BaseModel):
    youtube_url: str = Field(..., description="유튜브 영상 URL")
    mode: str = Field("fast", description="분석 모드: 'fast'(빠른 분석) 또는 'precise'(정밀 분석)")
    force_refresh: bool = Field(False, description="캐시 무시하고 강제 재분석")

    @field_validator("youtube_url")
    @classmethod
    def validate_youtube_url(cls, v: str) -> str:
        v = v.strip()
        pattern = r"(https?://)?(www\.)?(youtube\.com|youtu\.be|m\.youtube\.com)/.+"
        if not re.match(pattern, v):
            raise ValueError("유효한 유튜브 URL이 아닙니다.")
        return v

    @field_validator("mode")
    @classmethod
    def validate_mode(cls, v: str) -> str:
        if v not in ("fast", "precise"):
            raise ValueError("mode는 'fast' 또는 'precise'만 가능합니다.")
        return v


class ErrorResponse(BaseModel):
    error_code: str = Field(..., description="에러 코드 (예: INVALID_URL, NOT_RECIPE)")
    message: str = Field(..., description="사용자 친화적 메시지")
    detail: Optional[str] = Field(None, description="개발자용 상세 정보")


class Ingredient(BaseModel):
    name: str = Field(..., description="재료명 (예: 김치)")
    amount: Optional[str] = Field(None, description="수량 (예: 1/2, 100)")
    unit: Optional[str] = Field(None, description="단위 (예: 포기, g, ml, 개)")
    category: str = Field(..., description="재료 카테고리 (예: 주재료, 부재료, 양념, 육수)")


class RecipeStep(BaseModel):
    step_number: int
    description: str = Field(..., description="조리 단계 설명")
    timer: Optional[str] = Field(None, description="타이머 시간 (예: 10분, 30초)")


class FlavorProfile(BaseModel):
    saltiness: int = Field(..., ge=1, le=5, description="짠맛 점수 (1~5)")
    sweetness: int = Field(..., ge=1, le=5, description="단맛 점수 (1~5)")
    spiciness: int = Field(..., ge=1, le=5, description="매운맛 점수 (1~5)")
    sourness: int = Field(..., ge=1, le=5, description="신맛 점수 (1~5)")
    oiliness: int = Field(..., ge=1, le=5, description="기름진 정도 (1~5)")


class Recipe(BaseModel):
    id: Optional[int] = Field(None, description="DB 연동용 ID")
    is_recipe: bool = Field(True, description="요리 레시피 영상 여부")
    non_recipe_reason: Optional[str] = Field(None, description="레시피가 아닐 경우 그 이유")
    title: str = Field(..., description="레시피 제목")
    summary: str = Field(..., description="요리 개요 및 특징 (서론)")
    ingredients: List[Ingredient] = Field(..., description="구조화된 재료 목록")
    steps: List[RecipeStep] = Field(..., description="구조화된 조리 순서")
    flavor: FlavorProfile
    tip: Optional[str] = Field(None, description="마무리 꿀팁 및 보관법")
    servings: Optional[str] = Field(None, description="몇 인분 (예: '2인분', '4인분')")
    cooking_time: Optional[str] = Field(None, description="총 조리 시간 (예: '30분', '1시간 30분')")
    difficulty: Optional[str] = Field(None, description="난이도: '쉬움', '보통', '어려움' 중 하나")
    category: Optional[str] = Field(None, description="레시피 카테고리 (예: 한식, 양식, 국/찌개 등)")
    video_url: Optional[str] = Field(None, description="유튜브 영상 URL")
    video_id: Optional[str] = Field(None, description="유튜브 영상 고유 ID")
    video_title: Optional[str] = Field(None, description="유튜브 영상 원본 제목")
    channel_name: Optional[str] = Field(None, description="유튜브 채널명")


class CollectionRequest(BaseModel):
    user_id: str = Field(..., description="사용자 UUID")
    recipe_id: int = Field(..., description="레시피 고유 ID")
    custom_tip: Optional[str] = Field(None, description="개인 메모")
    ingredient_adjustments: Optional[Dict] = Field(None, description="재료 가감 (예: {excluded: ['고춧가루']})")


class CollectionUpdateRequest(BaseModel):
    custom_tip: Optional[str] = Field(None, description="수정할 개인 메모")
    recipe_override: Optional[Dict] = Field(
        None,
        description="재료/단계 수정본 (ingredients, steps, tip 키 포함 가능). None이면 원본 사용.",
    )


# --- 태그 관련 스키마 ---

class TagCreate(BaseModel):
    user_id: str = Field(..., description="사용자 UUID")
    name: str = Field(..., min_length=1, max_length=30, description="태그 이름")
    color: str = Field("#e8ddd4", description="태그 색상 (hex)")

    @field_validator("color")
    @classmethod
    def validate_color(cls, v: str) -> str:
        allowed = {
            "#f28b82", "#fbbc04", "#34a853", "#4285f4",
            "#a8c7fa", "#e6c9a8", "#d3d3d3", "#e8ddd4",
        }
        if v not in allowed:
            raise ValueError(f"허용되지 않는 색상입니다. 허용 색상: {allowed}")
        return v


class CollectionTag(BaseModel):
    id: int
    user_id: str
    name: str
    color: str
    created_at: Optional[str] = None


# 하위 호환성을 위한 별칭
Tag = CollectionTag


class CollectionTagUpdate(BaseModel):
    tag_ids: List[int] = Field(..., description="부착할 태그 ID 목록 (전체 덮어쓰기)")


# --- 즐겨찾기 / 별점 / 요리 기록 스키마 ---

class RatingRequest(BaseModel):
    rating: int = Field(..., ge=1, le=5, description="별점 (1~5)")


class CookedRequest(BaseModel):
    rating: Optional[int] = Field(None, ge=1, le=5, description="선택적 별점 (1~5)")


class CategoryOverrideRequest(BaseModel):
    category: Optional[str] = Field(None, description="수동 변경할 카테고리 (None이면 AI 분류로 복원)")


# --- 보관함 목록 응답 스키마 ---

class CollectionListItem(BaseModel):
    id: int
    user_id: str
    recipe_id: int
    custom_tip: Optional[str] = None
    ingredient_adjustments: Optional[Dict] = None
    is_favorite: bool = False
    my_rating: Optional[int] = None
    cooked_count: int = 0
    last_cooked_at: Optional[str] = None
    category_override: Optional[str] = None
    created_at: Optional[str] = None
    recipe: Optional[Dict] = None
    tags: Optional[List[CollectionTag]] = None
