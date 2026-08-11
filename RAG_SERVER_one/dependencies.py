"""
dependencies.py
FastAPI dependencies dùng chung: embedder singleton, xác thực API key.
"""
from __future__ import annotations
import os
import logging
from fastapi import Header, HTTPException, status

logger = logging.getLogger("dependencies")

_embedder = None


def get_embedder():
    """Trả về embedder singleton (load lần đầu tiên được gọi)."""
    global _embedder
    if _embedder is None:
        from sentence_transformers import SentenceTransformer
        model_name = os.getenv("EMBED_MODEL", "all-MiniLM-L6-v2")
        logger.info(f"[embedder] Loading {model_name} ...")
        _embedder = SentenceTransformer(model_name, device="cpu")
        logger.info("[embedder] Ready ✓")
    return _embedder


def get_embedder_sync():
    """
    Alias đồng bộ của get_embedder() — dùng trong startup/warmup
    khi không có FastAPI Depends context.
    """
    return get_embedder()


def preload_embedder() -> None:
    """Gọi khi startup để embedder sẵn sàng trước request đầu tiên."""
    get_embedder()


RAG_API_KEY = os.getenv("RAG_API_KEY", "")


async def verify_api_key(x_rag_key: str = Header(default="")) -> None:
    """
    Kiểm tra header X-Rag-Key.
    Nếu RAG_API_KEY chưa set trong .env → bỏ qua (chế độ dev).
    """
    if not RAG_API_KEY:
        return   # dev mode: không cần key
    if x_rag_key != RAG_API_KEY:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="API key không hợp lệ. Cần header: X-Rag-Key: <key>",
        )