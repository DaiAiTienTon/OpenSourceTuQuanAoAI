"""
services/api_client.py
Gọi .NET API server để lấy dữ liệu thật của user.
"""
from __future__ import annotations
import os
import httpx
from typing import Any

API_BASE_URL = os.getenv("API_BASE_URL", "https://quanlytudoapi20260331080811-drdbemh7gkhkatbe.japaneast-01.azurewebsites.net")

# Timeout hợp lý cho Azure (cold-start có thể chậm)
_CLIENT = httpx.AsyncClient(base_url=API_BASE_URL, timeout=30.0)


async def _get(path: str) -> Any:
    """GET JSON từ API server, trả về parsed object hoặc []."""
    try:
        r = await _CLIENT.get(path)
        r.raise_for_status()
        return r.json()
    except Exception as e:
        print(f"[api_client] GET {path} lỗi: {e}")
        return []


# ─── Clothing items ───────────────────────────────────────────────────────────

async def fetch_clothing_items(user_id: str) -> list[dict]:
    """Lấy toàn bộ clothing items rồi lọc theo userId.
    
    NOTE: API hiện tại GET /api/ClothingItems trả về tất cả user.
    Nếu sau này bổ sung ?userId= thì chỉnh path ở đây.
    """
    all_items: list[dict] = await _get("/api/ClothingItems")
    return [i for i in all_items if str(i.get("userId", "")).lower() == user_id.lower()]


# ─── Outfits + items ──────────────────────────────────────────────────────────

async def fetch_outfits(user_id: str) -> list[dict]:
    all_outfits: list[dict] = await _get("/api/Outfits")
    return [o for o in all_outfits if str(o.get("userId", "")).lower() == user_id.lower()]


async def fetch_outfit_items() -> list[dict]:
    return await _get("/api/OutfitItems")


# ─── User preferences ─────────────────────────────────────────────────────────

async def fetch_preferences(user_id: str) -> dict | None:
    all_prefs: list[dict] = await _get("/api/UserPreferences")
    for p in all_prefs:
        if str(p.get("userId", "")).lower() == user_id.lower():
            return p
    return None


# ─── Health logs ──────────────────────────────────────────────────────────────

async def fetch_health_logs(user_id: str, limit: int = 7) -> list[dict]:
    """Lấy tối đa `limit` bản ghi sức khoẻ gần nhất của user."""
    all_logs: list[dict] = await _get("/api/HealthLogs")
    user_logs = [l for l in all_logs if str(l.get("userId", "")).lower() == user_id.lower()]
    # Sắp xếp ngày giảm dần, lấy N bản ghi gần nhất
    user_logs.sort(key=lambda x: x.get("logDate", ""), reverse=True)
    return user_logs[:limit]


# ─── Aggregate: lấy tất cả dữ liệu 1 user ────────────────────────────────────

async def fetch_all_user_data(user_id: str) -> dict:
    """Gọi song song các endpoint và ghép kết quả."""
    import asyncio

    clothing_task    = fetch_clothing_items(user_id)
    outfits_task     = fetch_outfits(user_id)
    outfit_items_task = fetch_outfit_items()
    prefs_task       = fetch_preferences(user_id)
    health_task      = fetch_health_logs(user_id)

    clothing, outfits, outfit_items, prefs, health = await asyncio.gather(
        clothing_task, outfits_task, outfit_items_task, prefs_task, health_task
    )

    # Ghép outfit → items (lọc theo outfitId của user)
    outfit_ids = {str(o["id"]) for o in outfits}
    user_outfit_items = [
        oi for oi in outfit_items
        if str(oi.get("outfitId", "")) in outfit_ids
    ]

    return {
        "clothing": clothing,
        "outfits": outfits,
        "outfit_items": user_outfit_items,
        "preferences": prefs,
        "health": health,
    }