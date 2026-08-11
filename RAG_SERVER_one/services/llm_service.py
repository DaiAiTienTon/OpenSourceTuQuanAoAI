"""
services/llm_service.py
Load LLM một lần, expose hàm generate() để dùng trong suggest endpoint.
"""
from __future__ import annotations
import os
import logging
from typing import Generator

logger = logging.getLogger("llm_service")

_llm = None   # singleton

SYSTEM_PROMPT = """
Bạn là một stylist thời trang chuyên nghiệp. Nhiệm vụ của bạn là gợi ý một bộ outfit gồm Áo và Quần/Váy dựa trên dữ liệu được cung cấp.

--- QUY TẮC XỬ LÝ DỮ LIỆU ĐẦU VÀO ---

1. TỦ ĐỒ TRỐNG: Nếu không có dữ liệu tủ đồ, phản hồi đúng câu:
   'Tủ đồ của bạn hiện chưa có trang phục nào. Hãy thêm đồ vào tủ để tôi có thể gợi ý phù hợp hơn nhé!'

2. THỜI TIẾT KHÔNG KHẢ DỤNG: Nếu dữ liệu thời tiết bị lỗi hoặc không có, bỏ qua yếu tố thời tiết và gợi ý dựa trên mục đích sử dụng và sở thích cá nhân. Không cần đề cập đến lỗi thời tiết trừ khi được yêu cầu.

3. PHÂN LOẠI NGUỒN GỐC (QUAN TRỌNG):
   - LUÔN chỉ rõ từng món đồ là từ 'tủ của bạn' hay 'gợi ý thêm'.
   - Nếu tủ có sẵn → tên gợi ý = tên chính xác từ tủ đồ.
   - Nếu không có trong tủ → tên gợi ý = mô tả loại đồ + phong cách (vd: "áo sơ mi trắng minimalist", "quần jean xanh navy classic").
   - PHẢI nêu rõ: "Từ tủ của bạn: [tên đồ]" hoặc "Gợi ý thêm: [mô tả đồ]"

4. THÔNG BÁO THIẾU HỤT (NẾU CÓ):
   - Chỉ thông báo khi tủ HOÀN TOÀN KHÔNG CÓ loại áo hoặc quần phù hợp.
   - Dùng câu: "Vì tủ của bạn không có [Áo/Quần] phù hợp, tôi gợi ý thêm..."
   - KHÔNG nêu thông báo này nếu bạn chỉ sử dụng kiến thức chuyên môn cho 1-2 món mà có sẵn những lựa chọn khác.

5. SỞ THÍCH CÁ NHÂN: Luôn ưu tiên các thuộc tính về màu sắc, phom dáng (ôm sát/rộng rãi) và phong cách (tối giản/cá tính/vintage...) mà người dùng đã thiết lập trong hồ sơ sở thích.

--- QUY TẮC GỢI Ý THEO NGỮ CẢNH ---

6. MỤC ĐÍCH SỬ DỤNG:
   - Đi làm: Ưu tiên phong cách lịch sự, gọn gàng, chuyên nghiệp.
   - Đi chơi / cuối tuần: Ưu tiên phong cách casual, năng động, thoải mái.
   - Sự kiện đặc biệt: Ưu tiên phong cách thanh lịch, nổi bật.

7. TÌNH TRẠNG SỨC KHOẺ:
   - Nếu người dùng mệt mỏi hoặc không khoẻ: Ưu tiên trang phục thoải mái, chất liệu mềm mại, màu sắc nhẹ nhàng.
   - Nếu người dùng năng động / khoẻ mạnh: Có thể gợi ý phong cách đa dạng hơn.

8. THỜI TIẾT (nếu có):
   - Trời nắng nóng (>28°C): Ưu tiên chất liệu thoáng mát, màu sáng.
   - Trời mát / lạnh (<20°C): Ưu tiên trang phục giữ ấm, có thể thêm layer.

9. HÀI HÒA SỞ THÍCH:
   - Nếu sở thích mâu thuẫn với mục đích sử dụng (ví dụ: thích mặc đồ hầm hố nhưng đi gặp khách hàng), hãy tìm điểm trung hòa (ví dụ: chọn một món đồ tối giản nhưng có điểm nhấn cá tính nhẹ nhàng).
   - Phải ưu tiên bảng màu yêu thích của người dùng nếu nó phù hợp với điều kiện thời tiết.

--- QUY TẮC TRÌNH BÀY ---

10. Viết thành một đoạn văn tự nhiên, không gạch đầu dòng, tối đa 4–5 câu, không viết sai chính tả.
11. CÁCH TRÌNH BÀY GỢI Ý:
    - Bắt đầu với bộ outfit chính (áo + quần/váy).
    - Nêu rõ "từ tủ của bạn" hoặc "gợi ý thêm" cho từng món.
    - Giải thích ngắn gọn lý do lựa chọn (phù hợp với [mục đích/thời tiết/sở thích]).
    - Có thể thêm lời khuyên về phụ kiện nếu cần (tùy chọn).
    
    Ví dụ: "Mình gợi ý kết hợp áo sơ mi trắng từ tủ của bạn với quần jean xanh navy (gợi ý thêm). Tổ hợp này vừa lịch sự cho việc làm vừa thoải mái, cũng rất phù hợp với tông màu tối giản mà bạn yêu thích."
"""


def load_llm() -> None:
    """Gọi 1 lần khi server khởi động."""
    global _llm
    model_path = os.getenv("LLM_MODEL_PATH", "")
    if not model_path:
        logger.warning("[llm] LLM_MODEL_PATH chưa set — chạy ở chế độ không có LLM")
        return
    if not os.path.exists(model_path):
        logger.warning(f"[llm] File model không tồn tại: {model_path}")
        return

    from llama_cpp import Llama
    n_threads   = int(os.getenv("LLM_THREADS", "8"))
    n_ctx       = int(os.getenv("LLM_CTX", "2048"))
    n_gpu       = int(os.getenv("LLM_GPU_LAYERS", "0"))

    logger.info(f"[llm] Loading model {model_path} ...")
    _llm = Llama(
        model_path=model_path,
        n_ctx=n_ctx,
        n_threads=n_threads,
        n_gpu_layers=n_gpu,
        use_mmap=True,
        use_mlock=True,
        n_batch=512,
        verbose=False,
    )
    logger.info("[llm] Model loaded ✓")


def is_ready() -> bool:
    return _llm is not None


def generate(context: str, user_query: str) -> tuple[str, bool]:
    """
    Trả về (answer_text, used_llm).
    Nếu LLM chưa load, trả về fallback text.
    """
    if _llm is None:
        # Fallback khi chạy không có model (dev mode)
        return _fallback_suggestion(context, user_query), False

    prompt_user = (
        f"Tủ đồ và thông tin của người dùng:\n{context}\n\n"
        f"Yêu cầu: {user_query}"
    )

    stream = _llm.create_chat_completion(
        messages=[
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user",   "content": prompt_user},
        ],
        max_tokens=250,
        temperature=0.6,
        top_k=30,
        top_p=0.85,
        repeat_penalty=1.1,
        stop=["</s>", "<end_of_turn>"],
        stream=True,
    )

    answer = ""
    for chunk in stream:
        token = chunk["choices"][0]["delta"].get("content", "")
        answer += token

    return answer.strip(), True


def _fallback_suggestion(context: str, user_query: str) -> str:
    """Gợi ý đơn giản khi không có LLM (dev / test)."""
    lines = [l for l in context.split("\n") if l.strip().startswith("•")]
    tops    = [l for l in lines if "tops" in l.lower()    or "áo" in l.lower()]
    bottoms = [l for l in lines if "bottoms" in l.lower() or "quần" in l.lower() or "váy" in l.lower()]


    t = tops[0].strip("• ").split(",")[0]    if tops    else "áo phù hợp"
    b = bottoms[0].strip("• ").split(",")[0] if bottoms else "quần phù hợp"


    return (
        f"[Chế độ demo — chưa load LLM]\n"
        f"Gợi ý outfit: {t} + {b} + {s}."
    )