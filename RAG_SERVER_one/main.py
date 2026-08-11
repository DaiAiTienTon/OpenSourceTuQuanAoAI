"""
main.py — RAG Fashion Assistant Server
Khởi động: uvicorn main:app --host 0.0.0.0 --port 8000 --reload
"""
from __future__ import annotations
import logging
import asyncio
from contextlib import asynccontextmanager

from dotenv import load_dotenv
load_dotenv()   # load .env trước mọi import khác

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from routers import suggest, sync
from dependencies import preload_embedder, get_embedder_sync
from services import llm_service

# ─── Logging ──────────────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(name)s] %(levelname)s: %(message)s",
    datefmt="%H:%M:%S",
)
logger = logging.getLogger("main")


# ─── Lifespan (startup / shutdown) ───────────────────────────────────────────
@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("═" * 50)
    logger.info("  RAG Fashion Assistant Server — starting up")
    logger.info("═" * 50)

    # 1. Load embedder vào RAM
    preload_embedder()

    # 2. Load LLM vào RAM (chạy trong thread pool để không block event loop)
    await asyncio.get_event_loop().run_in_executor(None, llm_service.load_llm)

    # 3. Warmup rules index (kiến thức phối đồ tĩnh, dùng chung cho tất cả user).
    #    Build 1 lần từ fashion_rules.py, không cần gọi API ngoài.
    from services.sync_service import warmup_rules_index
    await warmup_rules_index(get_embedder_sync())

    logger.info("  Server sẵn sàng ✓")
    logger.info("═" * 50)

    yield   # ← server đang chạy

    logger.info("Server shutting down...")


# ─── App ──────────────────────────────────────────────────────────────────────
app = FastAPI(
    title="RAG Fashion Assistant",
    description=(
        "Server RAG gợi ý outfit dựa trên tủ đồ, sở thích và sức khoẻ của người dùng.\n\n"
        "**Luồng sử dụng cơ bản:**\n"
        "1. Gọi `POST /api/sync` để đồng bộ dữ liệu user từ .NET API server.\n"
        "2. Gọi `POST /api/suggest` để nhận gợi ý outfit.\n\n"
        "**Kiểm chứng chất lượng (ablation):**\n"
        "- Dùng field `data_sources` trong `/api/suggest` để chọn subset nguồn dữ liệu "
        "(wardrobe | preferences | health | rules).\n"
        "- Hoặc gọi `POST /api/suggest/compare` để chạy nhiều tổ hợp song song "
        "và so sánh kết quả trong 1 request duy nhất.\n\n"
        "**Nguồn dữ liệu:**\n"
        "- `wardrobe` — tủ đồ và outfit đã lưu của user (từ .NET API).\n"
        "- `preferences` — sở thích phong cách và màu sắc của user (từ .NET API).\n"
        "- `health` — nhật ký sức khoẻ gần nhất của user (từ .NET API).\n"
        "- `rules` — kiến thức phối đồ tĩnh (build sẵn lúc startup, không cần API)."
    ),
    version="1.1.0",
    lifespan=lifespan,
)

# ─── CORS ─────────────────────────────────────────────────────────────────────
# Production: thay allow_origins=["*"] bằng domain cụ thể của .NET API và frontend
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ─── Routers ──────────────────────────────────────────────────────────────────
app.include_router(suggest.router, prefix="/api", tags=["Suggest"])
app.include_router(sync.router,    prefix="/api", tags=["Sync"])


# ─── Health check (không cần API key) ────────────────────────────────────────
@app.get("/health", tags=["Health"])
async def health():
    from services.vector_store import get_index
    from services.sync_service import RULES_USER_KEY
    return {
        "status":        "ok",
        "llm_ready":     llm_service.is_ready(),
        "rules_index":   get_index(RULES_USER_KEY, "rules") is not None,
        "version":       "1.1.0",
    }


@app.get("/", tags=["Health"])
async def root():
    return {
        "message": "RAG Fashion Assistant Server đang chạy",
        "docs":    "/docs",
    }