"""
models/schemas.py
Pydantic schemas cho request / response của RAG server.
"""
from __future__ import annotations
from typing import Optional, Literal
from pydantic import BaseModel, Field


# ─── Request từ client ────────────────────────────────────────────────────────

class WeatherInfo(BaseModel):
    temperature: Optional[float] = None          # °C
    condition: Optional[str] = None              # "sunny", "rainy", "cloudy", ...
    humidity: Optional[float] = None             # %


# Các nguồn dữ liệu hợp lệ để query
DataSource = Literal["wardrobe", "preferences", "health", "rules"]


class SuggestRequest(BaseModel):
    user_id: str = Field(..., description="UUID của user")
    weather: Optional[WeatherInfo] = None
    occasion: Optional[str] = None               # work | school | sport | outing | home
    destination: Optional[str] = None            # "văn phòng", "trường học", ...
    additional_note: Optional[str] = None        # ghi chú thêm của user

    # --- MỚI: kiểm soát nguồn dữ liệu ---
    data_sources: Optional[list[DataSource]] = Field(
        default=None,
        description=(
            "Chọn subset nguồn dữ liệu để query. "
            "None = dùng tất cả (wardrobe + preferences + health + rules). "
            "Ví dụ: ['wardrobe'] chỉ dùng tủ đồ; ['wardrobe','rules'] dùng tủ đồ + luật phối đồ."
        )
    )


# ─── Response cho client ──────────────────────────────────────────────────────

class SuggestResponse(BaseModel):
    user_id: str
    suggestion: str
    context_used: list[str] = []                 # debug: các đoạn context được dùng
    data_sources_used: list[str] = []            # MỚI: để biết dùng nguồn nào


# ─── So sánh nhiều chế độ cùng lúc ──────────────────────────────────────────

class CompareSuggestion(BaseModel):
    """Kết quả của 1 chế độ trong compare."""
    label: str                                   # vd: "wardrobe_only", "all_sources"
    data_sources: list[str]
    suggestion: str
    context_used: list[str] = []
    error: Optional[str] = None                  # nếu thiếu dữ liệu


class CompareRequest(BaseModel):
    """
    Gọi suggest với nhiều tổ hợp data_sources khác nhau cùng lúc.
    Dùng để ablation: xem nguồn nào đóng góp nhiều nhất.
    """
    user_id: str
    weather: Optional[WeatherInfo] = None
    occasion: Optional[str] = None
    destination: Optional[str] = None
    additional_note: Optional[str] = None

    # Danh sách các tổ hợp muốn so sánh.
    # Mặc định: so sánh 5 chế độ chuẩn.
    compare_modes: Optional[list[list[DataSource]]] = Field(
        default=None,
        description=(
            "Mỗi phần tử là 1 tổ hợp data_sources. "
            "None = chạy 5 chế độ mặc định: "
            "wardrobe_only | preferences_only | health_only | wardrobe+rules | all."
        )
    )


class CompareResponse(BaseModel):
    user_id: str
    results: list[CompareSuggestion]


# ─── Request sync từ API server / admin ──────────────────────────────────────

class SyncRequest(BaseModel):
    """
    API server gọi endpoint này sau mỗi thay đổi để RAG server
    rebuild vector index cho user.
    """
    user_id: str
    data_type: str = Field(
        ...,
        description=(
            "Loại dữ liệu cần sync: "
            "'wardrobe' | 'preferences' | 'health' | 'rules' | 'all'"
        )
    )


class SyncResponse(BaseModel):
    user_id: str
    data_type: str
    status: str                                  # "ok" | "error"
    message: str = ""