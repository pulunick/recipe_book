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
    video_url: Optional[str] = Field(None, description="유튜브 영상 URL")
    video_id: Optional[str] = Field(None, description="유튜브 영상 고유 ID")


class CollectionRequest(BaseModel):
    user_id: str = Field(..., description="사용자 UUID")
    recipe_id: int = Field(..., description="레시피 고유 ID")
    custom_tip: Optional[str] = Field(None, description="개인 메모")
    ingredient_adjustments: Optional[Dict] = Field(None, description="재료 가감 (예: {excluded: ['고춧가루']})")
