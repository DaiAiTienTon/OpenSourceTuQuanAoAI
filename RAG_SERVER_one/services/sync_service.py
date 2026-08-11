"""
services/sync_service.py
Fetch dữ liệu từ .NET API → build / rebuild FAISS index cho user.

Thêm support data_type="rules": build index kiến thức phối đồ tĩnh
(không cần gọi API, dùng chung cho toàn bộ user).
"""
from __future__ import annotations
import logging
from typing import Literal

from services.api_client import (
    fetch_all_user_data, fetch_clothing_items,
    fetch_outfits, fetch_outfit_items, fetch_preferences, fetch_health_logs,
)
from services.vector_store import (
    build_documents, build_faiss_index, set_index, invalidate_cache,
)
from services.fashion_rules import build_rules_docs

logger = logging.getLogger("sync_service")

DataType = Literal["wardrobe", "preferences", "health", "rules", "all"]

# Key đặc biệt cho rules index (không theo user)
RULES_USER_KEY = "__global__"


async def sync_user(user_id: str, data_type: DataType, embedder) -> dict:
    """
    Rebuild FAISS index cho user theo data_type.
    Trả về {"status": "ok"|"error", "message": str}
    """
    uid = user_id.lower()
    logger.info(f"[sync] user={uid} type={data_type}")

    try:
        if data_type == "all":
            # User-specific indexes
            data = await fetch_all_user_data(uid)
            docs_map = build_documents(data)
            for name, docs in docs_map.items():
                _rebuild_one(uid, name, docs, embedder)
            # Cũng rebuild rules nếu chưa có
            _ensure_rules_index(embedder)

        elif data_type == "wardrobe":
            clothing = await fetch_clothing_items(uid)
            outfits  = await fetch_outfits(uid)
            oi_all   = await fetch_outfit_items()
            outfit_ids = {str(o["id"]) for o in outfits}
            outfit_items = [x for x in oi_all if str(x.get("outfitId","")) in outfit_ids]
            data = {
                "clothing": clothing, "outfits": outfits,
                "outfit_items": outfit_items, "preferences": None, "health": [],
            }
            docs_map = build_documents(data)
            _rebuild_one(uid, "wardrobe", docs_map["wardrobe"], embedder)

        elif data_type == "preferences":
            prefs = await fetch_preferences(uid)
            data = {
                "clothing": [], "outfits": [], "outfit_items": [],
                "preferences": prefs, "health": [],
            }
            docs_map = build_documents(data)
            _rebuild_one(uid, "preferences", docs_map["preferences"], embedder)

        elif data_type == "health":
            health = await fetch_health_logs(uid)
            data = {
                "clothing": [], "outfits": [], "outfit_items": [],
                "preferences": None, "health": health,
            }
            docs_map = build_documents(data)
            _rebuild_one(uid, "health", docs_map["health"], embedder)

        elif data_type == "rules":
            # Rules không phụ thuộc user_id, lưu dưới key __global__
            _rebuild_rules(embedder)

        else:
            return {"status": "error", "message": f"data_type không hợp lệ: {data_type}"}

        return {"status": "ok", "message": f"Đã sync {data_type} cho user {uid}"}

    except Exception as e:
        logger.exception(f"[sync] lỗi user={uid}: {e}")
        return {"status": "error", "message": str(e)}


def _rebuild_one(user_id: str, name: str, docs: list[str], embedder) -> None:
    """Rebuild 1 user-specific index."""
    invalidate_cache(user_id, name)
    index = build_faiss_index(docs, embedder)
    set_index(user_id, name, index, docs)
    logger.info(f"[sync] rebuilt '{name}' index cho {user_id} ({len(docs)} docs)")


def _rebuild_rules(embedder) -> None:
    """
    Rebuild rules index (global).
    Lưu dưới user_id = __global__ để tất cả user đều query được.
    """
    docs = build_rules_docs()
    invalidate_cache(RULES_USER_KEY, "rules")
    index = build_faiss_index(docs, embedder)
    set_index(RULES_USER_KEY, "rules", index, docs)
    logger.info(f"[sync] rebuilt 'rules' index global ({len(docs)} docs)")


def _ensure_rules_index(embedder) -> None:
    """Build rules index nếu chưa tồn tại (lazy init)."""
    from services.vector_store import get_index
    if get_index(RULES_USER_KEY, "rules") is None:
        _rebuild_rules(embedder)


# ─── Startup helper ───────────────────────────────────────────────────────────

async def warmup_rules_index(embedder) -> None:
    """
    Gọi từ startup event của FastAPI để đảm bảo rules index
    luôn sẵn sàng trước khi nhận request đầu tiên.
    
    Thêm vào main.py:
        @app.on_event("startup")
        async def startup():
            from services.sync_service import warmup_rules_index
            from dependencies import get_embedder_sync
            await warmup_rules_index(get_embedder_sync())
    """
    _ensure_rules_index(embedder)
    logger.info("[sync] rules index warmup done")