"""
services/vector_store.py
Quản lý FAISS index riêng cho từng user.

Mỗi user có tối đa 4 index: wardrobe | preferences | health | rules
Rules index được lưu dưới user_id = __global__ (dùng chung cho tất cả user).
"""
from __future__ import annotations
import os
import json
import numpy as np
import faiss
from pathlib import Path
from typing import NamedTuple

VECTOR_STORE_DIR = Path(os.getenv("VECTOR_STORE_DIR", "./store"))
VECTOR_STORE_DIR.mkdir(parents=True, exist_ok=True)

# Key đặc biệt cho rules index (không phụ thuộc user)
_RULES_USER_KEY = "__global__"


# ─── Text builder: chuyển JSON thô → đoạn text embed ─────────────────────────

def _clothing_to_text(item: dict) -> str:
    parts = [item.get("name", "")]
    if item.get("description"):
        parts.append(item["description"])
    if item.get("category"):
        parts.append(f"loại: {item['category']}")
    if item.get("color"):
        parts.append(f"màu: {item['color']}")
    if item.get("season"):
        parts.append(f"mùa: {item['season']}")
    return ", ".join(parts)


def _outfit_to_text(outfit: dict, outfit_items: list[dict], clothing_map: dict) -> str:
    name = outfit.get("name", "")
    occasion = outfit.get("occasion", "")
    items_txt = []
    for oi in outfit_items:
        if str(oi.get("outfitId")) == str(outfit.get("id")):
            cid = str(oi.get("clothingItemId", ""))
            c = clothing_map.get(cid)
            if c:
                items_txt.append(f"{oi.get('role','')}: {c.get('name','')}")
    combo = " | ".join(items_txt) if items_txt else "không có chi tiết"
    return f"Outfit '{name}' dịp {occasion}: {combo}"


def _pref_to_text(pref: dict) -> str:
    parts = []
    if pref.get("stylePreference"):
        parts.append(f"phong cách: {pref['stylePreference']}")
    if pref.get("hobbies"):
        try:
            hobbies = json.loads(pref["hobbies"])
        except Exception:
            hobbies = [pref["hobbies"]]
        parts.append(f"sở thích: {', '.join(hobbies)}")
    if pref.get("defaultLocation"):
        parts.append(f"khu vực: {pref['defaultLocation']}")
    return " | ".join(parts) if parts else "không có thông tin sở thích"


def _health_to_text(log: dict) -> str:
    parts = [f"ngày {log.get('logDate','?')}"]
    if log.get("weight"):
        parts.append(f"cân nặng {log['weight']}kg")
    if log.get("heartRate"):
        parts.append(f"nhịp tim {log['heartRate']}bpm")
    if log.get("sleepHours"):
        parts.append(f"ngủ {log['sleepHours']}h")
    if log.get("notes"):
        parts.append(log["notes"])
    return ", ".join(parts)


# ─── Build documents từ dữ liệu raw ──────────────────────────────────────────

def build_documents(data: dict) -> dict[str, list[str]]:
    """
    Trả về dict 3 key: wardrobe | preferences | health
    mỗi key là list[str] — các đoạn text sẽ được embed.
    (rules được build riêng qua fashion_rules.build_rules_docs)
    """
    clothing = data.get("clothing", [])
    outfits  = data.get("outfits", [])
    outfit_items = data.get("outfit_items", [])
    prefs    = data.get("preferences")
    health   = data.get("health", [])

    clothing_map = {str(c["id"]): c for c in clothing}

    wardrobe_docs: list[str] = []
    for c in clothing:
        wardrobe_docs.append(_clothing_to_text(c))
    for o in outfits:
        wardrobe_docs.append(_outfit_to_text(o, outfit_items, clothing_map))

    pref_docs: list[str] = []
    if prefs:
        pref_docs.append(_pref_to_text(prefs))

    health_docs: list[str] = [_health_to_text(l) for l in health]

    return {
        "wardrobe":    wardrobe_docs or ["không có dữ liệu tủ đồ"],
        "preferences": pref_docs     or ["không có dữ liệu sở thích"],
        "health":      health_docs   or ["không có dữ liệu sức khoẻ"],
    }


# ─── FAISS helpers ────────────────────────────────────────────────────────────

class UserIndex(NamedTuple):
    index: faiss.Index
    docs: list[str]


def _user_dir(user_id: str) -> Path:
    d = VECTOR_STORE_DIR / user_id
    d.mkdir(parents=True, exist_ok=True)
    return d


def _index_path(user_id: str, name: str) -> tuple[Path, Path]:
    d = _user_dir(user_id)
    return d / f"{name}.faiss", d / f"{name}.json"


def _save_index(user_id: str, name: str, index: faiss.Index, docs: list[str]) -> None:
    faiss_p, json_p = _index_path(user_id, name)
    faiss.write_index(index, str(faiss_p))
    json_p.write_text(json.dumps(docs, ensure_ascii=False), encoding="utf-8")


def _load_index(user_id: str, name: str) -> UserIndex | None:
    faiss_p, json_p = _index_path(user_id, name)
    if not faiss_p.exists() or not json_p.exists():
        return None
    index = faiss.read_index(str(faiss_p))
    docs  = json.loads(json_p.read_text(encoding="utf-8"))
    return UserIndex(index=index, docs=docs)


# ─── Cache trong RAM ──────────────────────────────────────────────────────────

_INDEX_CACHE: dict[tuple[str, str], UserIndex] = {}
_MAX_CACHE = 50


def _cache_key(user_id: str, name: str) -> tuple[str, str]:
    return (user_id.lower(), name)


def get_index(user_id: str, name: str) -> UserIndex | None:
    """
    Lấy index theo user_id + name.
    Đặc biệt: nếu name == "rules", luôn tra theo _RULES_USER_KEY
    thay vì user_id cụ thể (rules là global).
    """
    resolved_uid = _RULES_USER_KEY if name == "rules" else user_id.lower()
    key = _cache_key(resolved_uid, name)
    if key in _INDEX_CACHE:
        return _INDEX_CACHE[key]
    idx = _load_index(resolved_uid, name)
    if idx:
        if len(_INDEX_CACHE) >= _MAX_CACHE:
            _INDEX_CACHE.pop(next(iter(_INDEX_CACHE)))
        _INDEX_CACHE[key] = idx
    return idx


def set_index(user_id: str, name: str, index: faiss.Index, docs: list[str]) -> None:
    key = _cache_key(user_id.lower(), name)
    ui = UserIndex(index=index, docs=docs)
    _INDEX_CACHE[key] = ui
    _save_index(user_id.lower(), name, index, docs)


def invalidate_cache(user_id: str, name: str | None = None) -> None:
    """Xoá cache sau khi rebuild index."""
    if name:
        _INDEX_CACHE.pop(_cache_key(user_id, name), None)
    else:
        for n in ("wardrobe", "preferences", "health", "rules"):
            _INDEX_CACHE.pop(_cache_key(user_id, n), None)


# ─── Build index từ docs ──────────────────────────────────────────────────────

def build_faiss_index(docs: list[str], embedder) -> faiss.Index:
    vecs = embedder.encode(docs, normalize_embeddings=True).astype(np.float32)
    dim = vecs.shape[1]
    index = faiss.IndexFlatIP(dim)
    index.add(vecs)
    return index


# ─── Query ────────────────────────────────────────────────────────────────────

def query_index(
    user_id: str, name: str, query: str, embedder,
    top_k: int = 4, min_score: float = 0.1,
) -> list[str]:
    """
    Query 1 index.
    Nếu name == "rules": tự động dùng global index thay vì user-specific.
    """
    idx = get_index(user_id, name)
    if idx is None:
        return []
    q_vec = embedder.encode([query], normalize_embeddings=True).astype(np.float32)
    scores, indices = idx.index.search(q_vec, top_k)
    results = []
    for score, i in zip(scores[0], indices[0]):
        if i >= 0 and score >= min_score:
            results.append(idx.docs[i])
    return results