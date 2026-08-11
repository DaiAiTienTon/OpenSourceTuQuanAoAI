"""
routers/sync.py
POST /api/sync      — API server hoặc admin gọi để rebuild index
POST /api/sync/auto — tự động sync tất cả users (cron / admin)
"""
from __future__ import annotations
import logging
from fastapi import APIRouter, Depends, BackgroundTasks

from models.schemas import SyncRequest, SyncResponse
from services import sync_service
from dependencies import get_embedder, verify_api_key

router = APIRouter()
logger = logging.getLogger("sync")


@router.post("/sync", response_model=SyncResponse, dependencies=[Depends(verify_api_key)])
async def sync_user_data(
    req: SyncRequest,
    background_tasks: BackgroundTasks,
    embedder=Depends(get_embedder),
):
    """
    Rebuild FAISS index cho 1 user.
    API server của bạn gọi endpoint này sau mỗi lần user
    thêm/sửa/xóa quần áo, outfit, sức khoẻ, sở thích.
    
    Chạy ngay (synchronous) để đảm bảo index đã sẵn sàng khi trả về.
    """
    result = await sync_service.sync_user(req.user_id, req.data_type, embedder)
    return SyncResponse(
        user_id=req.user_id,
        data_type=req.data_type,
        status=result["status"],
        message=result["message"],
    )


@router.post("/sync/all", dependencies=[Depends(verify_api_key)])
async def sync_all_users(background_tasks: BackgroundTasks, embedder=Depends(get_embedder)):
    """
    Sync tất cả users từ API server.
    Dùng cho: lần đầu deploy, hoặc rebuild toàn bộ sau migration.
    Chạy nền (background task) — trả về ngay.
    """
    from services.api_client import _get

    async def _run():
        all_items = await _get("/api/ClothingItems")
        user_ids = list({str(i.get("userId","")) for i in all_items if i.get("userId")})
        logger.info(f"[sync/all] Bắt đầu sync {len(user_ids)} users")
        for uid in user_ids:
            result = await sync_service.sync_user(uid, "all", embedder)
            logger.info(f"[sync/all] {uid}: {result}")

    background_tasks.add_task(_run)
    return {"status": "started", "message": "Sync tất cả users đang chạy nền"}