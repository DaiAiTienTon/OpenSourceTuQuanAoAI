"""
routers/suggest.py

POST /api/suggest         — client gửi context → nhận gợi ý outfit.
POST /api/suggest/compare — chạy nhiều tổ hợp data_sources song song,
                            trả về để so sánh chất lượng (ablation).
"""
from __future__ import annotations
import asyncio
import logging
from fastapi import APIRouter, Depends, HTTPException

from models.schemas import (
    SuggestRequest, SuggestResponse,
    CompareRequest, CompareResponse, CompareSuggestion,
    DataSource,
)
from services.vector_store import query_index
from services import llm_service
from dependencies import get_embedder, verify_api_key

router = APIRouter()
logger = logging.getLogger("suggest")

# Thứ tự ưu tiên đầy đủ
ALL_SOURCES: tuple[DataSource, ...] = ("wardrobe", "preferences", "health", "rules")

# Label tiếng Việt dùng trong context prompt
_SECTION_LABELS: dict[str, str] = {
    "wardrobe":    "Tủ đồ hiện có",
    "preferences": "Sở thích & phong cách",
    "health":      "Sức khoẻ gần đây",
    "rules":       "Kiến thức phối đồ",
}

# 5 chế độ mặc định cho /compare
_DEFAULT_MODES: list[tuple[DataSource, ...]] = [
    ("wardrobe",),
    ("preferences",),
    ("health",),
    ("wardrobe", "rules"),
    ("wardrobe", "preferences", "health", "rules"),
]

_MODE_LABELS: dict[tuple, str] = {
    ("wardrobe",):                                        "wardrobe_only",
    ("preferences",):                                     "preferences_only",
    ("health",):                                          "health_only",
    ("wardrobe", "rules"):                                "wardrobe_plus_rules",
    ("wardrobe", "preferences", "health", "rules"):       "all_sources",
    ("wardrobe", "preferences", "health"):                "all_no_rules",
}


# ─── Helpers ─────────────────────────────────────────────────────────────────

def _build_user_query(req: SuggestRequest | CompareRequest) -> str:
    """Ghép các thông tin từ request thành câu query."""
    parts: list[str] = []
    if req.occasion:
        parts.append(f"dịp {req.occasion}")
    if req.destination:
        parts.append(f"đến {req.destination}")
    if req.weather:
        w = req.weather
        if w.temperature is not None:
            parts.append(f"thời tiết {w.temperature}°C")
        if w.condition:
            parts.append(w.condition)
    if req.additional_note:
        parts.append(req.additional_note)
    return " ".join(parts) if parts else "gợi ý trang phục hàng ngày"


def _build_context(
    results_map: dict[str, list[str]]
) -> tuple[str, list[str]]:
    """Gộp kết quả retrieve từ các index thành context string."""
    context_lines: list[str] = []
    used: list[str] = []

    for name, docs in results_map.items():
        if docs:
            label = _SECTION_LABELS.get(name, name)
            context_lines.append(f"[{label}]")
            for d in docs:
                context_lines.append(f"• {d}")
                used.append(d)

    return "\n".join(context_lines), used


async def _suggest_for_sources(
    user_id: str,
    query: str,
    sources: tuple[DataSource, ...],
    embedder,
    top_k: int = 4,
    min_score: float = 0.05,
) -> tuple[str, list[str]]:
    """
    Core: query các index theo `sources`, build context, gọi LLM.
    Trả về (suggestion, context_used).
    Raise HTTPException nếu hoàn toàn không có dữ liệu.
    """
    results_map: dict[str, list[str]] = {}
    for name in sources:
        results_map[name] = query_index(
            user_id, name, query, embedder,
            top_k=top_k, min_score=min_score,
        )

    context, used = _build_context(results_map)

    if not used:
        raise HTTPException(
            status_code=404,
            detail=(
                f"Chưa có dữ liệu cho user {user_id} "
                f"với sources={list(sources)}. "
                "Vui lòng gọi POST /api/sync trước."
            ),
        )

    suggestion, used_llm = llm_service.generate(context, query)
    logger.info(
        f"[suggest] user={user_id} sources={sources} "
        f"llm={used_llm} context_docs={len(used)}"
    )
    return suggestion, used


# ─── POST /api/suggest ────────────────────────────────────────────────────────

@router.post(
    "/suggest",
    response_model=SuggestResponse,
    dependencies=[Depends(verify_api_key)],
)
async def suggest_outfit(req: SuggestRequest, embedder=Depends(get_embedder)):
    user_id = req.user_id.lower()
    query   = _build_user_query(req)

    # Chọn sources: nếu client truyền vào thì dùng, không thì dùng tất cả
    sources: tuple[DataSource, ...] = (
        tuple(req.data_sources) if req.data_sources else ALL_SOURCES
    )

    logger.info(f"[suggest] user={user_id} sources={sources} query='{query}'")

    suggestion, used = await _suggest_for_sources(
        user_id, query, sources, embedder
    )

    return SuggestResponse(
        user_id=req.user_id,
        suggestion=suggestion,
        context_used=used,
        data_sources_used=list(sources),
    )


# ─── POST /api/suggest/compare ───────────────────────────────────────────────

@router.post(
    "/suggest/compare",
    response_model=CompareResponse,
    dependencies=[Depends(verify_api_key)],
    summary="Chạy nhiều tổ hợp data_sources song song để so sánh chất lượng gợi ý",
)
async def compare_suggest(req: CompareRequest, embedder=Depends(get_embedder)):
    """
    Ablation endpoint: chạy suggest với nhiều tổ hợp data_sources khác nhau
    cùng 1 lần, trả về để client/admin so sánh.

    Ví dụ request:
    {
      "user_id": "abc-123",
      "occasion": "work",
      "weather": {"temperature": 30, "condition": "sunny"},
      "compare_modes": [
        ["wardrobe"],
        ["wardrobe", "preferences"],
        ["wardrobe", "preferences", "health", "rules"]
      ]
    }
    """
    user_id = req.user_id.lower()
    query   = _build_user_query(req)

    # Chuẩn hoá danh sách modes
    if req.compare_modes:
        modes = [tuple(m) for m in req.compare_modes]
    else:
        modes = list(_DEFAULT_MODES)

    logger.info(f"[compare] user={user_id} modes={modes} query='{query}'")

    # Chạy song song tất cả modes
    async def _run_one(sources: tuple) -> CompareSuggestion:
        label = _MODE_LABELS.get(sources) or "+".join(sources)
        try:
            suggestion, used = await _suggest_for_sources(
                user_id, query, sources, embedder
            )
            return CompareSuggestion(
                label=label,
                data_sources=list(sources),
                suggestion=suggestion,
                context_used=used,
            )
        except HTTPException as e:
            return CompareSuggestion(
                label=label,
                data_sources=list(sources),
                suggestion="",
                error=e.detail,
            )
        except Exception as e:
            logger.exception(f"[compare] lỗi sources={sources}: {e}")
            return CompareSuggestion(
                label=label,
                data_sources=list(sources),
                suggestion="",
                error=str(e),
            )

    results = await asyncio.gather(*[_run_one(m) for m in modes])

    return CompareResponse(user_id=req.user_id, results=list(results))