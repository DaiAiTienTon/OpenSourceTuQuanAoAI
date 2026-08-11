# 👗 OpenSourceTuQuanAoAI — Hệ Thống Quản Lý Tủ Đồ & Gợi Ý Trang Phục Thông Minh (StyleAI Ecosystem)

> **StyleAI** là hệ sinh thái nguồn mở toàn diện kết hợp giữa **Mobile Application (Flutter)**, **Backend Service (.NET 8 Web API)** và **Hệ thống AI/RAG (Python FastAPI + FAISS + SLM/LLM)** nhằm giúp người dùng quản lý tủ đồ cá nhân, theo dõi nhật ký sức khỏe, kết hợp thời tiết thực tế và đề xuất trang phục (outfit) tối ưu theo thời gian thực.

---

## 🎨 Tải Mô Hình AI Cho Đổi Màu Sắc & Giao Diện Động (Dynamic Theme)

Để sử dụng tính năng **tự động thay đổi màu sắc & giao diện động (Dynamic Theme)** dựa trên thể trạng, thời tiết và tâm trạng chạy hoàn toàn **Offline**, bạn có thể tải các file mô hình SLM dạng `.gguf` tại đường dẫn dưới đây:

👉 **[Link Tải Mô Hình AI (.gguf) trên Google Drive](https://drive.google.com/drive/folders/1jWAdrrL-bBF8mO-OS0BMY1Pxm898-Hot)**

### 📥 Hướng dẫn cài đặt mô hình vào ứng dụng:
1. Tải file mô hình (ví dụ: `SmolLM2-360M-Instruct-Q4_K_M.gguf` hoặc `qwen2.5-0.5b-instruct-q4_k_m.gguf`) từ Google Drive ở trên.
2. Đặt file vào thư mục: `tuquanaoAI/assets/models/`
3. Hoặc import trực tiếp từ màn hình **Cài đặt trong ứng dụng** (File được lưu vào thư mục `imported_models/` riêng của thiết bị).

---

## 🏗️ Kiến Trúc Hệ Thống (System Architecture)

```mermaid
graph TD
    User([📱 Người dùng / App Flutter]) -->|HTTPS / JWT| NetAPI[⚙️ ASP.NET Core Web API (Azure)]
    User -->|HTTPS / JSON| RAGServer[🐍 Python FastAPI RAG Server]
    User -->|OpenWeatherMap / Open-Meteo| WeatherAPI[🌤️ Weather APIs]
    User -->|Anthropic REST API| ClaudeAPI[🤖 Anthropic Claude API]
    User -->|Local Inference via llamadart| LocalAI[🧠 GGUF Local SLM (Gemma/SmolLM)]
    NetAPI -->|Database Queries| SQLDB[(🛢️ SQL Server Database)]
    NetAPI -->|Webhook Sync| RAGServer
    RAGServer -->|Vector Search| FAISS[(🔍 FAISS Vector Store)]
```

---

## 🤖 Chi Tiết Tích Hợp AI & Gọi API Trong Mã Nguồn Dart (`tuquanaoAI`)

Ứng dụng Flutter kết hợp linh hoạt giữa **Local AI (Offline)**, **Cloud AI (Anthropic Claude)**, **RAG Server (FastAPI)** và **Dịch Vụ Bên Ngoài (Weather & .NET API)**:

### 1. 🧠 Chạy AI Offline Đổi Màu Giao Diện (`gemma_theme_service.dart`)
- **Vị trí file:** `tuquanaoAI/lib/service/gemma_theme_service.dart`
- **Công nghệ & Cơ chế:** 
  - Sử dụng thư viện `llamadart` (C++ bindings của `llama.cpp`) chạy trực tiếp file mô hình `.gguf` trên phần cứng điện thoại.
  - Tự động phát hiện (discover) tất cả các file mô hình `.gguf` trong `assets/models/` hoặc từ bộ nhớ máy (`imported_models/`).
  - Xây dựng **Context theo thời gian thực** (`ThemeContext`): giờ trong ngày, nhiệt độ, tình trạng thời tiết, nhịp tim, giờ ngủ, sở thích cá nhân.
  - Sử dụng cú pháp ràng buộc **GBNF (GGML BNF Grammar)** buộc mô hình chỉ xuất ra định dạng JSON chứa 1 trong 10 bảng màu chuẩn (`ocean`, `forest`, `sunset`, `warm_orange`, `dark_blue`, `lavender`, `mint`, `rose`, `golden_morning`, `rainy_evening`).

### 2. 🤖 Gợi Ý & Đánh Giá Trang Phục Qua Cloud AI (`ai_repository.dart`)
- **Vị trí file:** `tuquanaoAI/lib/repositories/ai_repository.dart`
- **Công nghệ & API:**
  - Kết nối trực tiếp tới REST API của **Anthropic Claude** (`https://api.anthropic.com/v1/messages`) với model `claude-sonnet-4-20250514`.
  - **`suggestOutfit()`**: Truyền danh sách đồ trong tủ (áo, quần/váy), địa điểm, sức khỏe, thời tiết để Claude AI gợi ý outfit phù hợp nhất kèm giải thích ngắn gọn.
  - **`evaluateOutfit()`**: Cho phép người dùng chọn 1 combo đồ, gửi sang Claude AI để chấm điểm độ phù hợp (thang điểm 1 - 10) và nhận xét chi tiết về màu sắc, kiểu dáng.

### 3. ⚡ Hệ Thống RAG Trả Lời Thông Minh (`rag_service.dart`)
- **Vị trí file:** `tuquanaoAI/lib/service/rag_service.dart`
- **Công nghệ & API:**
  - Kết nối tới **Python FastAPI RAG Server** qua các endpoint `/api/suggest`, `/api/sync`, `/health`.
  - **`suggestOutfit()`**: Gửi yêu cầu gợi ý có tích hợp tìm kiếm Vector từ kho dữ liệu cá nhân hóa (FAISS) kết hợp bộ quy tắc thời trang tĩnh.
  - **Cơ chế Tự Động Phục Hồi (Auto-sync & Retry):** Nếu server phản hồi lỗi `404` (chưa có chỉ mục vector), service sẽ tự động kích hoạt `syncUser()` rồi gửi lại yêu cầu gợi ý.

### 4. 🌤️ Dịch Vụ Thời Tiết Hai Nguồn Dữ Liệu (`Weather_service.dart`)
- **Vị trí file:** `tuquanaoAI/lib/service/Weather_service.dart`
- **Công nghệ & API:**
  - Lấy tọa độ thực tế của người dùng qua thư viện `geolocator`.
  - **Nguồn chính (Primary):** **OpenWeatherMap API** (`api.openweathermap.org`) trả về nhiệt độ, độ ẩm, tốc độ gió và mã thời tiết.
  - **Nguồn dự phòng (Fallback Auto-switch):** Khi OpenWeatherMap lỗi (hết quota `429` hoặc sai key `401`), dịch vụ tự động chuyển sang **Open-Meteo API** (miễn phí, không cần key) kết hợp **OpenStreetMap Nominatim Reverse Geocoding** để giải mã vị trí thành tên thành phố/quận huyện.

### 5. ⚙️ Quản Lý Kết Nối Backend .NET (`api_client.dart`)
- **Vị trí file:** `tuquanaoAI/lib/api/api_client.dart`
- **Công nghệ & API:**
  - Đóng vai trò làm HTTP Client trung tâm kết nối tới **ASP.NET Core 8 Web API** triển khai trên **Azure App Service**.
  - Tự động đính kèm mã xác thực **JWT Bearer Token** vào HTTP Headers (`Authorization: Bearer <token>`) lấy từ `SharedPreferences`.

---

## ✨ Summary Tính Năng Hệ Thống

- 👕 **Quản Lý Tủ Đồ Số:** Lưu trữ thông minh danh mục áo, quần, váy, giày dép và phụ kiện.
- 🎨 **Giao Diện Động Đổi Màu Theo Thể Trạng (Local AI):** Tự thay đổi màu sắc giao diện theo thời tiết và thể trạng thông qua mô hình SLM nhẹ chạy trực tiếp trên máy.
- 🌤️ **Gợi Ý Theo Thời Tiết & Thể Trạng:** Tự động điều chỉnh phong cách mặc đồ dựa trên nhiệt độ môi trường, chỉ số nhịp tim và chất lượng giấc ngủ.
- 🔍 **RAG Vector Search:** Kết hợp tìm kiếm vector chính xác cao từ tủ đồ thực tế của người dùng và bộ quy tắc phối đồ.

---

## 📁 Cấu Trúc Dự Án (Repository Structure)

```text
OpenSourceTuQuanAoAI/
├── tuquanaoAI/               # 📱 Ứng dụng Flutter Mobile App
│   ├── lib/
│   │   ├── api/              # ApiClient kết nối .NET 8 Web API (Azure)
│   │   ├── core/             # Định nghĩa Theme & Palette màu ứng dụng
│   │   ├── repositories/     # AIRepository kết nối Anthropic Claude API
│   │   ├── service/          # GemmaThemeService (Local AI), RagService, WeatherService
│   │   └── viewmodels/       # Provider State Management ViewModels
│   ├── assets/models/        # Chứa file mô hình AI local (.gguf)
│   └── pubspec.yaml          # Quản lý thư viện Flutter
├── quan_ly_tu_do_API_one/    # ⚙️ ASP.NET Core Backend API
│   ├── quan_ly_tu_do_API/    # Controllers, Models, Data (EF Core), Services
│   └── quan_ly_tu_do_API.sln # Solution file
├── RAG_SERVER_one/           # 🧠 Python FastAPI RAG Server
│   ├── main.py               # Entry point FastAPI Server
│   ├── routers/              # API Endpoints (/api/suggest, /api/sync)
│   ├── services/             # Vector Store (FAISS), Embedder, LLM Service
│   └── requirements.txt      # Thư viện Python
├── LICENSE                   # Giấy phép nguồn mở MIT
└── README.md                 # Hướng dẫn chi tiết dự án
```

---

## 🚀 Hướng Dẫn Cài Đặt & Vận Hành (Getting Started)

### Yêu Cầu Tiền Đề (Prerequisites)
- **Flutter SDK:** `>= 3.10.x`
- **.NET SDK:** `>= 8.0`
- **Python:** `>= 3.10`
- **SQL Server / LocalDB**

---

### 1. Khởi Động Backend API (.NET 8)

1. Di chuyển vào thư mục dự án:
   ```bash
   cd quan_ly_tu_do_API_one/quan_ly_tu_do_API
   ```
2. Cấu hình chuỗi kết nối SQL Server trong `appsettings.json`:
   ```json
   "ConnectionStrings": {
     "DefaultConnection": "Server=YOUR_SERVER;Database=QuanLyTuDoDb;Trusted_Connection=True;TrustServerCertificate=True;"
   }
   ```
3. Cập nhật Database & Khởi chạy server:
   ```bash
   dotnet ef database update
   dotnet run
   ```

---

### 2. Khởi Động RAG AI Server (Python FastAPI)

1. Di chuyển vào thư mục RAG Server:
   ```bash
   cd RAG_SERVER_one
   ```
2. Tạo và kích hoạt môi trường ảo Python:
   ```bash
   python -m venv venv
   # Windows:
   .\venv\Scripts\activate
   # Linux/macOS:
   source venv/bin/activate
   ```
3. Cài đặt thư viện & Khởi chạy server:
   ```bash
   pip install -r requirements.txt
   uvicorn main:app --host 0.0.0.0 --port 8000 --reload
   ```

---

### 3. Khởi Động Ứng Dụng Mobile (Flutter)

1. Di chuyển vào thư mục ứng dụng Flutter:
   ```bash
   cd tuquanaoAI
   ```
2. Tải các gói phụ thuộc & Chạy app:
   ```bash
   flutter pub get
   flutter run
   ```

---

## 📜 Giấy Phép (License)

Dự án được phân phối dưới giấy phép **MIT License**. Xem chi tiết tại tệp [LICENSE](LICENSE).