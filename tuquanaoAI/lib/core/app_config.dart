/// Cấu hình trung tâm cho các API Endpoints và API Keys của ứng dụng.
/// Thay thế các thông tin bên dưới bằng URL và API key thực tế của bạn.
class AppConfig {
  AppConfig._();

  // ── 1. Backend Web API (.NET 8) ──────────────────────────────────────────
  static const String dotnetApiBaseUrl =
      'https://your-dotnet-api.azurewebsites.net/api';

  // ── 2. RAG AI Server (FastAPI) ──────────────────────────────────────────
  static const String ragServerBaseUrl = 'https://your-rag-server-url.com';
  static const String ragApiKey = 'YOUR_RAG_SECRET_KEY';

  // ── 3. Cloudflare Worker AI (Đánh giá outfit) ───────────────────────────
  static const String outfitEvalWorkerUrl =
      'https://your-evaluation-worker.workers.dev/';

  // ── 4. Cloudflare Worker AI (Benchmark Llama 3.1 8B) ────────────────────
  static const String cloudBenchmarkWorkerUrl =
      'https://your-benchmark-worker.workers.dev/';

  // ── 5. Weather APIs ─────────────────────────────────────────────────────
  static const String openWeatherMapApiKey = 'YOUR_OPENWEATHERMAP_API_KEY';
}
